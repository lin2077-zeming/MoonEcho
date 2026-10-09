///|
fn match_config() -> @fingerprint.HashConfig {
  try! @fingerprint.HashConfig::new()
}

///|
fn hash(
  value : UInt64,
  anchor_frame : Int,
  anchor_bin : Int,
  delta_frames : Int,
  target_bin : Int,
) -> @fingerprint.FingerprintHash {
  { hash: value, anchor_frame, anchor_bin, delta_frames, target_bin, }
}

///|
fn make_fp(
  hashes : Array[@fingerprint.FingerprintHash],
) -> @fingerprint.AudioFingerprint {
  {
    version: @fingerprint.fingerprint_version,
    frame_count: 256,
    bin_count: 128,
    config: match_config(),
    hashes,
  }
}

///|
fn make_index() -> @index.FingerprintIndex {
  let index = @index.FingerprintIndex::new(match_config())
  let track_a = make_fp([
    hash(11UL, 100, 10, 3, 12),
    hash(12UL, 110, 20, 3, 22),
    hash(13UL, 120, 30, 3, 32),
  ])
  let track_b = make_fp([hash(13UL, 50, 40, 3, 42)])
  try! index.add_track(1, "track-a", track_a)
  try! index.add_track(2, "track-b", track_b)
  index
}

///|
test "candidate voting selects aligned track" {
  let index = make_index()
  let query = make_fp([
    hash(11UL, 20, 10, 3, 12),
    hash(12UL, 30, 20, 3, 22),
    hash(13UL, 40, 30, 3, 32),
    hash(99UL, 50, 40, 3, 42),
  ])
  let config = try! @match.MatchConfig::new(
    top_k=5,
    min_votes=3,
    min_confidence=0.5,
    min_margin=0.3,
  )
  let result = try! @match.match_fingerprint(index, query, config)
  assert_true(result.status is @match.Strong)
  assert_eq(result.candidates.length(), 2)
  assert_eq(result.candidates[0].track_id, 1)
  assert_eq(result.candidates[0].offset_frames, 80)
  assert_eq(result.candidates[0].votes, 3)
  assert_eq(result.candidates[0].name, "track-a")
}

///|
test "weak result when votes are below threshold" {
  let index = make_index()
  let query = make_fp([hash(11UL, 20, 10, 3, 12)])
  let config = try! @match.MatchConfig::new(min_votes=5, min_confidence=0.5)
  let result = try! @match.match_fingerprint(index, query, config)
  assert_true(result.status is @match.Weak)
  assert_eq(result.candidates[0].track_id, 1)
}

///|
test "empty query returns no match" {
  let index = make_index()
  let query = make_fp([])
  let config = try! @match.MatchConfig::new()
  let result = try! @match.match_fingerprint(index, query, config)
  assert_true(result.status is @match.NoMatch)
  assert_eq(result.candidates.length(), 0)
}
