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
test "index snapshot v2 round-trips profile and postings" {
  let profile = try! @index.ProcessingProfile::new(
    22050,
    512,
    256,
    {
      frequency_radius: 1,
      time_radius: 0,
      min_magnitude: 0.1,
      relative_threshold: 0.2,
      max_peaks_per_frame: 3,
    },
    test_config(),
  )
  let index = @index.with_profile(profile)
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
  assert_eq(decoded.profile.sample_rate, 22050)
  assert_eq(decoded.profile.window_length, 512)
  assert_eq(decoded.profile.hop_size, 256)
  assert_eq(decoded.profile.peak_config.frequency_radius, 1)
  assert_eq(decoded.profile.peak_config.max_peaks_per_frame, 3)
}

///|
test "index snapshot v1 fixture remains readable" {
  let bytes = v1_empty_snapshot()
  let decoded = try @index.decode(bytes) catch {
    err => fail(@index.error_message(err))
  } noraise {
    value => value
  }
  assert_eq(decoded.tracks.length(), 0)
  assert_eq(decoded.posting_count, 0)
  assert_eq(decoded.profile.sample_rate, 16000)
  assert_eq(decoded.profile.window_length, 1024)
  assert_eq(decoded.profile.hop_size, 512)
}

///|
test "index snapshot v2 rejects damaged payload" {
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
  let damaged = encoded.to_array()
  damaged[16] = (damaged[16].to_int() ^ 0xff).to_byte()
  try @index.decode(Bytes::from_array(damaged)) catch {
    ChecksumMismatch(_, _) => ()
    err => fail("expected checksum mismatch, got \{@index.error_message(err)}")
  } noraise {
    _ => fail("expected damaged snapshot to fail")
  }
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
fn v1_empty_snapshot() -> Bytes {
  let out : Array[Byte] = []
  for byte in @index.index_magic_v1() {
    out.push(byte)
  }
  push_u16(out, 1)
  push_u16(out, 0)
  push_u16(out, @fingerprint.fingerprint_version)
  push_u16(out, 0)
  push_u64(out, 0x9E3779B97F4A7C15UL)
  push_u16(out, 5)
  push_u16(out, 1)
  push_u16(out, 64)
  push_u16(out, 33)
  push_u32(out, 0)
  push_u32(out, 0)
  let payload = Bytes::from_array(out)
  push_u64(out, v1_checksum(payload))
  Bytes::from_array(out)
}

///|
fn push_u16(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
}

///|
fn push_u32(out : Array[Byte], value : Int) -> Unit {
  for byte_index in 0..<4 {
    out.push(((value >> (byte_index * 8)) & 0xff).to_byte())
  }
}

///|
fn push_u64(out : Array[Byte], value : UInt64) -> Unit {
  for byte_index in 0..<8 {
    out.push(((value >> (byte_index * 8)) & 0xffUL).to_byte())
  }
}

///|
fn v1_checksum(bytes : Bytes) -> UInt64 {
  let mut checksum = 0xcbf29ce484222325UL
  for byte in bytes {
    checksum = (checksum ^ byte.to_uint64()) * 0x100000001B3UL
  }
  checksum
}
