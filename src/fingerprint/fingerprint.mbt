///|
pub let fingerprint_version : Int = 1

///|
pub fn magic() -> Bytes {
  Bytes::from_array([b'M', b'O', b'O', b'N', b'F', b'P', b'0', b'1'])
}

///|
pub(all) struct HashConfig {
  fan_out : Int
  min_delta_frames : Int
  max_delta_frames : Int
  max_frequency_distance : Int
  hash_seed : UInt64
}

///|
pub(all) struct FingerprintHash {
  hash : UInt64
  anchor_frame : Int
  anchor_bin : Int
  delta_frames : Int
  target_bin : Int
}

///|
pub(all) struct AudioFingerprint {
  version : Int
  frame_count : Int
  bin_count : Int
  config : HashConfig
  hashes : Array[FingerprintHash]
}

///|
pub suberror FingerprintError {
  InvalidArgument(String)
  InvalidMagic
  UnsupportedVersion(Int)
  Truncated(String)
  InvalidLength(String)
  ChecksumMismatch(UInt64, UInt64)
}

///|
pub fn error_message(error : FingerprintError) -> String {
  match error {
    InvalidArgument(message) => message
    InvalidMagic => "invalid fingerprint magic"
    UnsupportedVersion(version) => "unsupported fingerprint version: \{version}"
    Truncated(message) => "truncated fingerprint: \{message}"
    InvalidLength(message) => "invalid fingerprint length: \{message}"
    ChecksumMismatch(expected, actual) =>
      "fingerprint checksum mismatch: expected=\{expected.to_string()}, actual=\{actual.to_string()}"
  }
}

///|
pub fn HashConfig::new(
  fan_out? : Int = 5,
  min_delta_frames? : Int = 1,
  max_delta_frames? : Int = 64,
  max_frequency_distance? : Int = 32,
  hash_seed? : UInt64 = 0x9E3779B97F4A7C15UL,
) -> HashConfig raise FingerprintError {
  if fan_out <= 0 {
    raise InvalidArgument("fan_out must be positive")
  }
  if min_delta_frames <= 0 {
    raise InvalidArgument("min_delta_frames must be positive")
  }
  if max_delta_frames < min_delta_frames {
    raise InvalidArgument("max_delta_frames must be >= min_delta_frames")
  }
  if max_frequency_distance < -1 {
    raise InvalidArgument("max_frequency_distance must be >= -1")
  }
  {
    fan_out,
    min_delta_frames,
    max_delta_frames,
    max_frequency_distance,
    hash_seed,
  }
}

///|
pub fn fingerprint(
  peaks : Array[@spectrum.SpectralPeak],
  config : HashConfig,
  frame_count~ : Int,
  bin_count~ : Int,
) -> AudioFingerprint raise FingerprintError {
  if frame_count <= 0 {
    raise InvalidArgument("frame_count must be positive")
  }
  if bin_count <= 0 {
    raise InvalidArgument("bin_count must be positive")
  }
  let sorted_peaks = sort_spectral_peaks(peaks)
  let hashes : Array[FingerprintHash] = []
  for anchor_index in 0..<sorted_peaks.length() {
    let anchor = sorted_peaks[anchor_index]
    let candidates : Array[@spectrum.SpectralPeak] = []
    let mut target_index = anchor_index + 1
    while target_index < sorted_peaks.length() {
      let target = sorted_peaks[target_index]
      let delta_frames = target.frame - anchor.frame
      if delta_frames > config.max_delta_frames {
        break
      }
      if delta_frames >= config.min_delta_frames &&
        frequency_distance_allowed(anchor, target, config) {
        candidates.push(target)
      }
      target_index = target_index + 1
    }
    candidates.sort_by(compare_spectral_peaks)
    let limit = if candidates.length() < config.fan_out {
      candidates.length()
    } else {
      config.fan_out
    }
    for index in 0..<limit {
      let target = candidates[index]
      let delta_frames = target.frame - anchor.frame
      hashes.push({
        hash: pair_hash(anchor.bin, target.bin, delta_frames, config.hash_seed),
        anchor_frame: anchor.frame,
        anchor_bin: anchor.bin,
        delta_frames,
        target_bin: target.bin,
      })
    }
  }
  { version: fingerprint_version, frame_count, bin_count, config, hashes, }
}

///|
pub fn encode(fingerprint : AudioFingerprint) -> Bytes raise FingerprintError {
  if fingerprint.version != fingerprint_version {
    raise UnsupportedVersion(fingerprint.version)
  }
  let out : Array[Byte] = []
  write_magic(out)
  push_u16_le(out, fingerprint.version)
  push_u16_le(out, 0)
  push_u64_le(out, fingerprint.config.hash_seed)
  push_u16_le(out, fingerprint.config.fan_out)
  push_u16_le(out, fingerprint.config.min_delta_frames)
  push_u16_le(out, fingerprint.config.max_delta_frames)
  push_u16_le(
    out,
    encode_frequency_distance(fingerprint.config.max_frequency_distance),
  )
  push_u32_le(out, fingerprint.frame_count)
  push_u32_le(out, fingerprint.bin_count)
  push_u32_le(out, fingerprint.hashes.length())
  for item in fingerprint.hashes {
    push_u64_le(out, item.hash)
    push_u32_le(out, item.anchor_frame)
    push_u32_le(out, item.anchor_bin)
    push_u16_le(out, item.delta_frames)
    push_u32_le(out, item.target_bin)
    push_u16_le(out, 0)
  }
  let payload = Bytes::from_array(out)
  push_u64_le(out, checksum_bytes(payload, payload.length()))
  Bytes::from_array(out)
}

///|
pub fn decode(bytes : Bytes) -> AudioFingerprint raise FingerprintError {
  if bytes.length() < 48 {
    raise Truncated("expected at least 48 bytes")
  }
  if !bytes.has_prefix(magic()) {
    raise InvalidMagic
  }
  let version = read_u16_le(bytes, 8)
  if version != fingerprint_version {
    raise UnsupportedVersion(version)
  }
  let flags = read_u16_le(bytes, 10)
  if flags != 0 {
    raise InvalidArgument("unsupported fingerprint flags: \{flags}")
  }
  let hash_seed = read_u64_le(bytes, 12)
  let fan_out = read_u16_le(bytes, 20)
  let min_delta_frames = read_u16_le(bytes, 22)
  let max_delta_frames = read_u16_le(bytes, 24)
  let max_frequency_distance = decode_frequency_distance(read_u16_le(bytes, 26))
  let frame_count = read_u32_le(bytes, 28)
  let bin_count = read_u32_le(bytes, 32)
  let hash_count = read_u32_le(bytes, 36)
  let expected_length = 48 + hash_count * 24
  if bytes.length() != expected_length {
    raise InvalidLength(
      "expected \{expected_length} bytes, got \{bytes.length()}",
    )
  }
  let payload_length = bytes.length() - 8
  let expected_checksum = checksum_bytes(bytes, payload_length)
  let actual_checksum = read_u64_le(bytes, payload_length)
  if expected_checksum != actual_checksum {
    raise ChecksumMismatch(expected_checksum, actual_checksum)
  }
  let config = HashConfig::new(
    fan_out~,
    min_delta_frames~,
    max_delta_frames~,
    max_frequency_distance~,
    hash_seed~,
  )
  let hashes : Array[FingerprintHash] = []
  let mut offset = 40
  for _ in 0..<hash_count {
    hashes.push({
      hash: read_u64_le(bytes, offset),
      anchor_frame: read_u32_le(bytes, offset + 8),
      anchor_bin: read_u32_le(bytes, offset + 12),
      delta_frames: read_u16_le(bytes, offset + 16),
      target_bin: read_u32_le(bytes, offset + 18),
    })
    offset = offset + 24
  }
  { version, frame_count, bin_count, config, hashes, }
}

///|
fn frequency_distance_allowed(
  anchor : @spectrum.SpectralPeak,
  target : @spectrum.SpectralPeak,
  config : HashConfig,
) -> Bool {
  if config.max_frequency_distance < 0 {
    true
  } else {
    let distance = if anchor.bin >= target.bin {
      anchor.bin - target.bin
    } else {
      target.bin - anchor.bin
    }
    distance <= config.max_frequency_distance
  }
}

///|
fn pair_hash(
  anchor_bin : Int,
  target_bin : Int,
  delta_frames : Int,
  seed : UInt64,
) -> UInt64 {
  let mut hash = seed
  hash = mix_u64(hash, anchor_bin.to_uint64())
  hash = mix_u64(hash, target_bin.to_uint64())
  mix_u64(hash, delta_frames.to_uint64())
}

///|
fn mix_u64(hash : UInt64, value : UInt64) -> UInt64 {
  let mut result = hash
  for byte_index in 0..<8 {
    let byte_value = (value >> (byte_index * 8)) & 0xffUL
    result = (result ^ byte_value) * 0x100000001B3UL
  }
  result
}

///|
fn sort_spectral_peaks(
  peaks : Array[@spectrum.SpectralPeak],
) -> Array[@spectrum.SpectralPeak] {
  let sorted = peaks.copy()
  sorted.sort_by(compare_spectral_peaks)
  sorted
}

///|
fn compare_spectral_peaks(
  left : @spectrum.SpectralPeak,
  right : @spectrum.SpectralPeak,
) -> Int {
  if left.frame != right.frame {
    left.frame - right.frame
  } else if left.bin != right.bin {
    left.bin - right.bin
  } else if left.magnitude > right.magnitude {
    -1
  } else if left.magnitude < right.magnitude {
    1
  } else {
    0
  }
}

///|
fn write_magic(out : Array[Byte]) -> Unit {
  out.push(b'M')
  out.push(b'O')
  out.push(b'O')
  out.push(b'N')
  out.push(b'F')
  out.push(b'P')
  out.push(b'0')
  out.push(b'1')
}

///|
fn encode_frequency_distance(distance : Int) -> Int {
  if distance < 0 {
    0
  } else {
    distance + 1
  }
}

///|
fn decode_frequency_distance(value : Int) -> Int {
  if value == 0 {
    -1
  } else {
    value - 1
  }
}

///|
fn push_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
}

///|
fn push_u32_le(out : Array[Byte], value : Int) -> Unit {
  for byte_index in 0..<4 {
    out.push(((value >> (byte_index * 8)) & 0xff).to_byte())
  }
}

///|
fn push_u64_le(out : Array[Byte], value : UInt64) -> Unit {
  for byte_index in 0..<8 {
    out.push(((value >> (byte_index * 8)) & 0xffUL).to_byte())
  }
}

///|
fn read_u16_le(bytes : Bytes, offset : Int) -> Int raise FingerprintError {
  require_bytes(bytes, offset, 2)
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
}

///|
fn read_u32_le(bytes : Bytes, offset : Int) -> Int raise FingerprintError {
  require_bytes(bytes, offset, 4)
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}

///|
fn read_u64_le(bytes : Bytes, offset : Int) -> UInt64 raise FingerprintError {
  require_bytes(bytes, offset, 8)
  let mut value = 0UL
  for byte_index in 0..<8 {
    value = value + (bytes[offset + byte_index].to_uint64() << (byte_index * 8))
  }
  value
}

///|
fn require_bytes(
  bytes : Bytes,
  offset : Int,
  length : Int,
) -> Unit raise FingerprintError {
  if offset < 0 || length < 0 || offset + length > bytes.length() {
    raise Truncated(
      "need \{length} bytes at offset \{offset}, length=\{bytes.length()}",
    )
  }
}

///|
fn checksum_bytes(bytes : Bytes, length : Int) -> UInt64 {
  let mut checksum = 0xcbf29ce484222325UL
  for index in 0..<length {
    checksum = (checksum ^ bytes[index].to_uint64()) * 0x100000001B3UL
  }
  checksum
}
