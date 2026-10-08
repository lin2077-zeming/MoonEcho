///|
pub let index_version : Int = 1

///|
pub fn index_magic() -> Bytes {
  Bytes::from_array([b'M', b'O', b'O', b'N', b'I', b'X', b'0', b'1'])
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
  }
}

///|
pub fn FingerprintIndex::new(
  config : @fingerprint.HashConfig,
) -> FingerprintIndex {
  { config, tracks: [], postings: Map([]), posting_count: 0, }
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
    raise InvalidArgument("track name is too long for snapshot v1")
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
  write_index_magic(out)
  push_u16_le(out, index_version)
  push_u16_le(out, 0)
  push_u16_le(out, @fingerprint.fingerprint_version)
  push_u16_le(out, 0)
  push_u64_le(out, index.config.hash_seed)
  push_u16_le(out, index.config.fan_out)
  push_u16_le(out, index.config.min_delta_frames)
  push_u16_le(out, index.config.max_delta_frames)
  push_u16_le(
    out,
    encode_frequency_distance(index.config.max_frequency_distance),
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
  if bytes.length() < 48 {
    raise Truncated("expected at least 48 bytes")
  }
  if !bytes.has_prefix(index_magic()) {
    raise InvalidMagic
  }
  let version = read_u16_le(bytes, 8)
  if version != index_version {
    raise UnsupportedVersion(version)
  }
  let flags = read_u16_le(bytes, 10)
  if flags != 0 {
    raise InvalidArgument("unsupported index flags: \{flags}")
  }
  let fingerprint_version = read_u16_le(bytes, 12)
  if fingerprint_version != @fingerprint.fingerprint_version {
    raise UnsupportedVersion(fingerprint_version)
  }
  if read_u16_le(bytes, 14) != 0 {
    raise InvalidArgument("unsupported index reserved header field")
  }
  let fan_out = read_u16_le(bytes, 24)
  let min_delta_frames = read_u16_le(bytes, 26)
  let max_delta_frames = read_u16_le(bytes, 28)
  let max_frequency_distance = decode_frequency_distance(read_u16_le(bytes, 30))
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
  let config : @fingerprint.HashConfig = {
    fan_out,
    min_delta_frames,
    max_delta_frames,
    max_frequency_distance,
    hash_seed: read_u64_le(bytes, 16),
  }
  let track_total = read_u32_le(bytes, 32)
  let expected_posting_total = read_u32_le(bytes, 36)
  let tracks : Array[TrackInfo] = []
  let mut offset = 40
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
  for _ in 0..<expected_posting_total {
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
  { config, tracks, postings, posting_count: expected_posting_total, }
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
fn write_index_magic(out : Array[Byte]) -> Unit {
  out.push(b'M')
  out.push(b'O')
  out.push(b'O')
  out.push(b'N')
  out.push(b'I')
  out.push(b'X')
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
