///|
fn test_config() -> @fingerprint.HashConfig {
  try! @fingerprint.HashConfig::new(
    fan_out=2,
    min_delta_frames=1,
    max_delta_frames=8,
    max_frequency_distance=4,
  )
}

///|
fn test_fingerprint(
  frame_count : Int,
  bin_count : Int,
  hashes : Array[@fingerprint.FingerprintHash],
) -> @fingerprint.AudioFingerprint {
  {
    version: @fingerprint.fingerprint_version,
    frame_count,
    bin_count,
    config: test_config(),
    hashes,
  }
}

///|
test "index stores and looks up postings" {
  let index = @index.FingerprintIndex::new(test_config())
  let fp = test_fingerprint(16, 32, [
    {
      hash: 42UL,
      anchor_frame: 3,
      anchor_bin: 7,
      delta_frames: 2,
      target_bin: 9,
    },
    {
      hash: 99UL,
      anchor_frame: 8,
      anchor_bin: 2,
      delta_frames: 4,
      target_bin: 6,
    },
  ])
  try! index.add_track(1, "track-a", fp)
  let matches = index.lookup(42UL)
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].track_id, 1)
  assert_eq(matches[0].anchor_frame, 3)
  assert_eq(index.track_count(), 1)
  assert_eq(index.posting_count(), 2)
}

///|
test "index snapshot v1 round-trips" {
  let index = @index.FingerprintIndex::new(test_config())
  let fp = test_fingerprint(16, 32, [
    {
      hash: 42UL,
      anchor_frame: 3,
      anchor_bin: 7,
      delta_frames: 2,
      target_bin: 9,
    },
    {
      hash: 99UL,
      anchor_frame: 8,
      anchor_bin: 2,
      delta_frames: 4,
      target_bin: 6,
    },
  ])
  try! index.add_track(1, "track-a", fp)
  let encoded = @index.encode(index)
  let decoded = try! @index.decode(encoded)
  assert_eq(decoded.tracks.length(), 1)
  assert_eq(decoded.posting_count, 2)
  assert_eq(decoded.lookup(99UL).length(), 1)
  assert_eq(decoded.tracks[0].name, "track-a")
}

///|
test "index rejects duplicate track ids" {
  let index = @index.FingerprintIndex::new(test_config())
  let fp = test_fingerprint(16, 32, [])
  try! index.add_track(1, "track-a", fp)
  try index.add_track(1, "track-b", fp) catch {
    DuplicateTrack(1) => ()
    err => fail(@index.error_message(err))
  } noraise {
    _ => fail("expected duplicate track rejection")
  }
}

///|
test "index snapshot rejects damaged payload" {
  let index = @index.FingerprintIndex::new(test_config())
  let encoded = @index.encode(index)
  let damaged = encoded.to_array()
  damaged[16] = (damaged[16].to_int() ^ 0xff).to_byte()
  try @index.decode(Bytes::from_array(damaged)) catch {
    ChecksumMismatch(_, _) => ()
    err => fail("expected checksum mismatch, got \{@index.error_message(err)}")
  } noraise {
    _ => fail("expected damaged snapshot to fail")
  }
}
