///|
pub let index_version_v1 : Int = 1

///|
pub let index_version_v2 : Int = 2

///|
pub let index_version : Int = index_version_v2

///|
pub fn index_magic_v1() -> Bytes {
  Bytes::from_array([b'M', b'O', b'O', b'N', b'I', b'X', b'0', b'1'])
}

///|
pub fn index_magic_v2() -> Bytes {
  Bytes::from_array([b'M', b'O', b'O', b'N', b'I', b'X', b'0', b'2'])
}

///|
pub fn index_magic() -> Bytes {
  index_magic_v2()
}

///|
pub(all) struct ProcessingProfile {
  sample_rate : Int
  window_length : Int
  hop_size : Int
  peak_config : @spectrum.PeakConfig
  hash_config : @fingerprint.HashConfig
}

///|
pub(all) struct TrackInfo {
  track_id : Int
  name : String
  frame_count : Int
  bin_count : Int
  hash_count : Int
}

///|
pub(all) struct IndexPosting {
  track_id : Int
  anchor_frame : Int
  anchor_bin : Int
  delta_frames : Int
  target_bin : Int
}

///|
pub(all) struct FingerprintIndex {
  config : @fingerprint.HashConfig
  profile : ProcessingProfile
  tracks : Array[TrackInfo]
  postings : Map[UInt64, Array[IndexPosting]]
  mut posting_count : Int
}

///|
pub suberror IndexError {
  InvalidArgument(String)
  DuplicateTrack(Int)
  InvalidMagic
  UnsupportedVersion(Int)
  Truncated(String)
  InvalidLength(String)
  ChecksumMismatch(UInt64, UInt64)
  Spectrum(@spectrum.SpectrumError)
}

///|
pub fn error_message(error : IndexError) -> String {
  match error {
    InvalidArgument(message) => message
    DuplicateTrack(track_id) => "duplicate track id: \{track_id}"
    InvalidMagic => "invalid index magic"
    UnsupportedVersion(version) => "unsupported index version: \{version}"
    Truncated(message) => "truncated index: \{message}"
    InvalidLength(message) => "invalid index length: \{message}"
    ChecksumMismatch(expected, actual) =>
      "index checksum mismatch: expected=\{expected.to_string()}, actual=\{actual.to_string()}"
    Spectrum(err) => @spectrum.error_message(err)
  }
}

///|
pub fn ProcessingProfile::new(
  sample_rate : Int,
  window_length : Int,
  hop_size : Int,
  peak_config : @spectrum.PeakConfig,
  hash_config : @fingerprint.HashConfig,
) -> ProcessingProfile raise IndexError {
  if sample_rate <= 0 {
    raise InvalidArgument("sample_rate must be positive")
  }
  try @spectrum.SpectrumConfig::new(window_length~, hop_size~) catch {
    err => raise Spectrum(err)
  } noraise {
    _ => ()
  }
  { sample_rate, window_length, hop_size, peak_config, hash_config, }
}

///|
pub fn default_peak_config() -> @spectrum.PeakConfig {
  {
    frequency_radius: 2,
    time_radius: 0,
    min_magnitude: 0.05,
    relative_threshold: 0.0,
    max_peaks_per_frame: 4,
  }
}

///|
pub fn default_profile(
  hash_config : @fingerprint.HashConfig,
) -> ProcessingProfile {
  {
    sample_rate: 16000,
    window_length: 1024,
    hop_size: 512,
    peak_config: default_peak_config(),
    hash_config,
  }
}

///|
pub fn FingerprintIndex::new(
  config : @fingerprint.HashConfig,
) -> FingerprintIndex {
  with_profile(default_profile(config))
}

///|
pub fn with_profile(profile : ProcessingProfile) -> FingerprintIndex {
  {
    config: profile.hash_config,
    profile,
    tracks: [],
    postings: Map([]),
    posting_count: 0,
  }
}

///|
pub fn FingerprintIndex::add_track(
  self : FingerprintIndex,
  track_id : Int,
  name : String,
  fingerprint : @fingerprint.AudioFingerprint,
) -> Unit raise IndexError {
  if track_id < 0 {
    raise InvalidArgument("track_id must be non-negative")
  }
  if @utf8.encode(name).length() > 65535 {
    raise InvalidArgument("track name is too long for snapshot")
  }
  if !hash_config_equal(self.config, fingerprint.config) {
    raise InvalidArgument("fingerprint config does not match index config")
  }
  for track in self.tracks {
    if track.track_id == track_id {
      raise DuplicateTrack(track_id)
    }
  }
  self.tracks.push({
    track_id,
    name,
    frame_count: fingerprint.frame_count,
    bin_count: fingerprint.bin_count,
    hash_count: fingerprint.hashes.length(),
  })
  for item in fingerprint.hashes {
    append_posting(self, item.hash, {
      track_id,
      anchor_frame: item.anchor_frame,
      anchor_bin: item.anchor_bin,
      delta_frames: item.delta_frames,
      target_bin: item.target_bin,
    })
  }
}

///|
pub fn FingerprintIndex::lookup(
  self : FingerprintIndex,
  hash : UInt64,
) -> Array[IndexPosting] {
  match self.postings.get(hash) {
    Some(postings) => postings.copy()
    None => []
  }
}

///|
pub fn FingerprintIndex::track_count(self : FingerprintIndex) -> Int {
  self.tracks.length()
}

///|
pub fn FingerprintIndex::posting_count(self : FingerprintIndex) -> Int {
  self.posting_count
}

///|
pub fn encode(index : FingerprintIndex) -> Bytes {
  let out : Array[Byte] = []
  write_magic(out, index_magic_v2())
  push_u16_le(out, index_version_v2)
  push_u16_le(out, 0)
  push_u16_le(out, @fingerprint.fingerprint_version)
  push_u16_le(out, 0)
  push_u32_le(out, index.profile.sample_rate)
  push_u32_le(out, index.profile.window_length)
  push_u32_le(out, index.profile.hop_size)
  push_u16_le(out, index.profile.peak_config.frequency_radius)
  push_u16_le(out, index.profile.peak_config.time_radius)
  push_u16_le(out, index.profile.peak_config.max_peaks_per_frame)
  push_u16_le(out, 0)
  push_f64_le(out, index.profile.peak_config.min_magnitude)
  push_f64_le(out, index.profile.peak_config.relative_threshold)
  push_u64_le(out, index.profile.hash_config.hash_seed)
  push_u16_le(out, index.profile.hash_config.fan_out)
  push_u16_le(out, index.profile.hash_config.min_delta_frames)
  push_u16_le(out, index.profile.hash_config.max_delta_frames)
  push_u16_le(
    out,
    encode_frequency_distance(index.profile.hash_config.max_frequency_distance),
  )
  push_u32_le(out, index.tracks.length())
  push_u32_le(out, index.posting_count)
  let tracks = index.tracks.copy()
  tracks.sort_by(compare_track_info)
  for track in tracks {
    let name_bytes = @utf8.encode(track.name)
    push_u32_le(out, track.track_id)
    push_u32_le(out, track.frame_count)
    push_u32_le(out, track.bin_count)
    push_u32_le(out, track.hash_count)
    push_u16_le(out, name_bytes.length())
    for byte in name_bytes {
      out.push(byte)
    }
  }
  let entries : Array[(UInt64, IndexPosting)] = []
  for hash in index.postings.keys() {
    match index.postings.get(hash) {
      Some(postings) =>
        for posting in postings {
          entries.push((hash, posting))
        }
      None => ()
    }
  }
  entries.sort_by(compare_posting_entries)
  for entry in entries {
    push_u64_le(out, entry.0)
    push_u32_le(out, entry.1.track_id)
    push_u32_le(out, entry.1.anchor_frame)
    push_u32_le(out, entry.1.anchor_bin)
    push_u16_le(out, entry.1.delta_frames)
    push_u32_le(out, entry.1.target_bin)
    push_u16_le(out, 0)
  }
  let payload = Bytes::from_array(out)
  push_u64_le(out, checksum_bytes(payload, payload.length()))
  Bytes::from_array(out)
}

///|
pub fn decode(bytes : Bytes) -> FingerprintIndex raise IndexError {
  if bytes.has_prefix(index_magic_v1()) {
    decode_v1(bytes)
  } else if bytes.has_prefix(index_magic_v2()) {
    decode_v2(bytes)
  } else {
    raise InvalidMagic
  }
}

///|
fn decode_v1(bytes : Bytes) -> FingerprintIndex raise IndexError {
  if bytes.length() < 48 {
    raise Truncated("expected at least 48 bytes")
  }
  let version = read_u16_le(bytes, 8)
  if version != index_version_v1 {
    raise UnsupportedVersion(version)
  }
  let flags = read_u16_le(bytes, 10)
  if flags != 0 {
    raise InvalidArgument("unsupported index flags: \{flags}")
  }
  if read_u16_le(bytes, 12) != @fingerprint.fingerprint_version {
    raise UnsupportedVersion(read_u16_le(bytes, 12))
  }
  if read_u16_le(bytes, 14) != 0 {
    raise InvalidArgument("unsupported index reserved header field")
  }
  let config : @fingerprint.HashConfig = {
    hash_seed: read_u64_le(bytes, 16),
    fan_out: read_u16_le(bytes, 24),
    min_delta_frames: read_u16_le(bytes, 26),
    max_delta_frames: read_u16_le(bytes, 28),
    max_frequency_distance: decode_frequency_distance(read_u16_le(bytes, 30)),
  }
  validate_hash_config(config)
  let track_total = read_u32_le(bytes, 32)
  let posting_total = read_u32_le(bytes, 36)
  let (tracks, postings, offset) = decode_records(
    bytes, 40, track_total, posting_total,
  )
  validate_payload_end(bytes, offset)
  {
    config,
    profile: default_profile(config),
    tracks,
    postings,
    posting_count: posting_total,
  }
}

///|
fn decode_v2(bytes : Bytes) -> FingerprintIndex raise IndexError {
  if bytes.length() < 84 {
    raise Truncated("expected at least 84 bytes")
  }
  let version = read_u16_le(bytes, 8)
  if version != index_version_v2 {
    raise UnsupportedVersion(version)
  }
  let flags = read_u16_le(bytes, 10)
  if flags != 0 {
    raise InvalidArgument("unsupported index flags: \{flags}")
  }
  if read_u16_le(bytes, 12) != @fingerprint.fingerprint_version {
    raise UnsupportedVersion(read_u16_le(bytes, 12))
  }
  if read_u16_le(bytes, 14) != 0 {
    raise InvalidArgument("unsupported index reserved header field")
  }
  let sample_rate = read_u32_le(bytes, 16)
  let window_length = read_u32_le(bytes, 20)
  let hop_size = read_u32_le(bytes, 24)
  let peak_config : @spectrum.PeakConfig = {
    frequency_radius: read_u16_le(bytes, 28),
    time_radius: read_u16_le(bytes, 30),
    max_peaks_per_frame: read_u16_le(bytes, 32),
    min_magnitude: read_f64_le(bytes, 36),
    relative_threshold: read_f64_le(bytes, 44),
  }
  if read_u16_le(bytes, 34) != 0 {
    raise InvalidArgument("unsupported peak reserved field")
  }
  let hash_config : @fingerprint.HashConfig = {
    hash_seed: read_u64_le(bytes, 52),
    fan_out: read_u16_le(bytes, 60),
    min_delta_frames: read_u16_le(bytes, 62),
    max_delta_frames: read_u16_le(bytes, 64),
    max_frequency_distance: decode_frequency_distance(read_u16_le(bytes, 66)),
  }
  validate_hash_config(hash_config)
  let track_total = read_u32_le(bytes, 68)
  let posting_total = read_u32_le(bytes, 72)
  let (tracks, postings, offset) = decode_records(
    bytes, 76, track_total, posting_total,
  )
  validate_payload_end(bytes, offset)
  let profile = ProcessingProfile::new(
    sample_rate, window_length, hop_size, peak_config, hash_config,
  )
  {
    config: hash_config,
    profile,
    tracks,
    postings,
    posting_count: posting_total,
  }
}

///|
fn decode_records(
  bytes : Bytes,
  start : Int,
  track_total : Int,
  posting_total : Int,
) -> (Array[TrackInfo], Map[UInt64, Array[IndexPosting]], Int) raise IndexError {
  let tracks : Array[TrackInfo] = []
  let mut offset = start
  for _ in 0..<track_total {
    require_bytes(bytes, offset, 18)
    let track_id = read_u32_le(bytes, offset)
    let frame_count = read_u32_le(bytes, offset + 4)
    let bin_count = read_u32_le(bytes, offset + 8)
    let hash_count = read_u32_le(bytes, offset + 12)
    let name_length = read_u16_le(bytes, offset + 16)
    offset = offset + 18
    require_bytes(bytes, offset, name_length)
    let name = try @utf8.decode(bytes[offset:offset + name_length]) catch {
      _ => raise InvalidArgument("invalid UTF-8 track name")
    } noraise {
      value => value
    }
    offset = offset + name_length
    tracks.push({ track_id, name, frame_count, bin_count, hash_count, })
  }
  let postings : Map[UInt64, Array[IndexPosting]] = Map([])
  for _ in 0..<posting_total {
    require_bytes(bytes, offset, 28)
    let hash = read_u64_le(bytes, offset)
    let posting : IndexPosting = {
      track_id: read_u32_le(bytes, offset + 8),
      anchor_frame: read_u32_le(bytes, offset + 12),
      anchor_bin: read_u32_le(bytes, offset + 16),
      delta_frames: read_u16_le(bytes, offset + 20),
      target_bin: read_u32_le(bytes, offset + 22),
    }
    if read_u16_le(bytes, offset + 26) != 0 {
      raise InvalidArgument("unsupported posting reserved field")
    }
    append_posting_map(postings, hash, posting)
    offset = offset + 28
  }
  (tracks, postings, offset)
}

///|
fn validate_payload_end(bytes : Bytes, offset : Int) -> Unit raise IndexError {
  if offset != bytes.length() - 8 {
    raise InvalidLength(
      "expected \{offset} payload bytes, got \{bytes.length() - 8}",
    )
  }
  let payload_length = bytes.length() - 8
  let expected_checksum = checksum_bytes(bytes, payload_length)
  let actual_checksum = read_u64_le(bytes, payload_length)
  if expected_checksum != actual_checksum {
    raise ChecksumMismatch(expected_checksum, actual_checksum)
  }
}

///|
fn validate_hash_config(
  config : @fingerprint.HashConfig,
) -> Unit raise IndexError {
  if config.fan_out <= 0 {
    raise InvalidArgument("fan_out must be positive")
  }
  if config.min_delta_frames <= 0 {
    raise InvalidArgument("min_delta_frames must be positive")
  }
  if config.max_delta_frames < config.min_delta_frames {
    raise InvalidArgument("max_delta_frames must be >= min_delta_frames")
  }
  if config.max_frequency_distance < -1 {
    raise InvalidArgument("max_frequency_distance must be >= -1")
  }
}

///|
fn append_posting(
  index : FingerprintIndex,
  hash : UInt64,
  posting : IndexPosting,
) -> Unit {
  append_posting_map(index.postings, hash, posting)
  index.posting_count = index.posting_count + 1
}

///|
fn append_posting_map(
  postings : Map[UInt64, Array[IndexPosting]],
  hash : UInt64,
  posting : IndexPosting,
) -> Unit {
  match postings.get(hash) {
    Some(list) => list.push(posting)
    None => {
      let list : Array[IndexPosting] = [posting]
      postings.set(hash, list)
    }
  }
}

///|
fn hash_config_equal(
  left : @fingerprint.HashConfig,
  right : @fingerprint.HashConfig,
) -> Bool {
  left.fan_out == right.fan_out &&
  left.min_delta_frames == right.min_delta_frames &&
  left.max_delta_frames == right.max_delta_frames &&
  left.max_frequency_distance == right.max_frequency_distance &&
  left.hash_seed == right.hash_seed
}

///|
fn compare_track_info(left : TrackInfo, right : TrackInfo) -> Int {
  left.track_id - right.track_id
}

///|
fn compare_posting_entries(
  left : (UInt64, IndexPosting),
  right : (UInt64, IndexPosting),
) -> Int {
  let hash_order = compare_u64(left.0, right.0)
  if hash_order != 0 {
    hash_order
  } else if left.1.track_id != right.1.track_id {
    left.1.track_id - right.1.track_id
  } else if left.1.anchor_frame != right.1.anchor_frame {
    left.1.anchor_frame - right.1.anchor_frame
  } else if left.1.anchor_bin != right.1.anchor_bin {
    left.1.anchor_bin - right.1.anchor_bin
  } else if left.1.target_bin != right.1.target_bin {
    left.1.target_bin - right.1.target_bin
  } else {
    left.1.delta_frames - right.1.delta_frames
  }
}

///|
fn compare_u64(left : UInt64, right : UInt64) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn write_magic(out : Array[Byte], magic : Bytes) -> Unit {
  for byte in magic {
    out.push(byte)
  }
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
fn push_f64_le(out : Array[Byte], value : Double) -> Unit {
  push_u64_le(out, value.reinterpret_as_uint64())
}

///|
fn read_u16_le(bytes : Bytes, offset : Int) -> Int raise IndexError {
  require_bytes(bytes, offset, 2)
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
}

///|
fn read_u32_le(bytes : Bytes, offset : Int) -> Int raise IndexError {
  require_bytes(bytes, offset, 4)
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}

///|
fn read_u64_le(bytes : Bytes, offset : Int) -> UInt64 raise IndexError {
  require_bytes(bytes, offset, 8)
  let mut value = 0UL
  for byte_index in 0..<8 {
    value = value + (bytes[offset + byte_index].to_uint64() << (byte_index * 8))
  }
  value
}

///|
fn read_f64_le(bytes : Bytes, offset : Int) -> Double raise IndexError {
  read_u64_le(bytes, offset).reinterpret_as_double()
}

///|
fn require_bytes(
  bytes : Bytes,
  offset : Int,
  length : Int,
) -> Unit raise IndexError {
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
