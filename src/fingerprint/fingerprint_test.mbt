///|
fn sample_peaks() -> Array[@spectrum.SpectralPeak] {
  [
    { frame: 0, bin: 2, time: 0.0, frequency: 200.0, magnitude: 1.0, },
    { frame: 1, bin: 5, time: 0.1, frequency: 500.0, magnitude: 0.8, },
    { frame: 3, bin: 3, time: 0.3, frequency: 300.0, magnitude: 0.7, },
    { frame: 8, bin: 7, time: 0.8, frequency: 700.0, magnitude: 0.6, },
  ]
}

///|
test "fingerprint is deterministic" {
  let config = try! @fingerprint.HashConfig::new(
    fan_out=3,
    min_delta_frames=1,
    max_delta_frames=10,
    max_frequency_distance=8,
  )
  let first = try! @fingerprint.fingerprint(
    sample_peaks(),
    config,
    frame_count=10,
    bin_count=16,
  )
  let second = try! @fingerprint.fingerprint(
    sample_peaks(),
    config,
    frame_count=10,
    bin_count=16,
  )
  assert_eq(first.hashes.length(), 6)
  assert_eq(second.hashes.length(), first.hashes.length())
  for index in 0..<first.hashes.length() {
    assert_eq(first.hashes[index].hash, second.hashes[index].hash)
    assert_eq(
      first.hashes[index].anchor_frame,
      second.hashes[index].anchor_frame,
    )
  }
}

///|
test "fingerprint binary v1 round-trips" {
  let config = try! @fingerprint.HashConfig::new(
    fan_out=2,
    min_delta_frames=1,
    max_delta_frames=8,
    max_frequency_distance=4,
  )
  let original = try! @fingerprint.fingerprint(
    sample_peaks(),
    config,
    frame_count=10,
    bin_count=16,
  )
  let encoded = try! @fingerprint.encode(original)
  let decoded = try @fingerprint.decode(encoded) catch {
    err => fail(@fingerprint.error_message(err))
  } noraise {
    value => value
  }
  assert_eq(decoded.version, 1)
  assert_eq(decoded.frame_count, 10)
  assert_eq(decoded.bin_count, 16)
  assert_eq(decoded.hashes.length(), original.hashes.length())
  for index in 0..<decoded.hashes.length() {
    assert_eq(decoded.hashes[index].hash, original.hashes[index].hash)
    assert_eq(
      decoded.hashes[index].anchor_frame,
      original.hashes[index].anchor_frame,
    )
    assert_eq(
      decoded.hashes[index].target_bin,
      original.hashes[index].target_bin,
    )
  }
}

///|
test "fingerprint decode rejects damaged payload" {
  let config = try! @fingerprint.HashConfig::new()
  let original = try! @fingerprint.fingerprint(
    sample_peaks(),
    config,
    frame_count=10,
    bin_count=16,
  )
  let encoded = try! @fingerprint.encode(original)
  let damaged = encoded.to_array()
  damaged[20] = (damaged[20].to_int() ^ 0xff).to_byte()
  try @fingerprint.decode(Bytes::from_array(damaged)) catch {
    ChecksumMismatch(_, _) => ()
    err =>
      fail("expected checksum mismatch, got \{@fingerprint.error_message(err)}")
  } noraise {
    _ => fail("expected damaged payload to fail")
  }
}
