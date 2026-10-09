///|
fn main {
  let config = try! @fp.HashConfig::new()
  let index = @idx.FingerprintIndex::new(config)
  let track : @fp.AudioFingerprint = {
    version: @fp.fingerprint_version,
    frame_count: 256,
    bin_count: 128,
    config,
    hashes: [
      {
        hash: 11UL,
        anchor_frame: 100,
        anchor_bin: 10,
        delta_frames: 3,
        target_bin: 12,
      },
      {
        hash: 12UL,
        anchor_frame: 110,
        anchor_bin: 20,
        delta_frames: 3,
        target_bin: 22,
      },
    ],
  }
  try! index.add_track(1, "demo-track", track)
  let query : @fp.AudioFingerprint = {
    version: @fp.fingerprint_version,
    frame_count: 128,
    bin_count: 128,
    config,
    hashes: [
      {
        hash: 11UL,
        anchor_frame: 20,
        anchor_bin: 10,
        delta_frames: 3,
        target_bin: 12,
      },
      {
        hash: 12UL,
        anchor_frame: 30,
        anchor_bin: 20,
        delta_frames: 3,
        target_bin: 22,
      },
    ],
  }
  let result = try! @matcher.match_fingerprint(
    index,
    query,
    @matcher.MatchConfig::new(min_votes=2, min_confidence=0.5),
  )
  println("Matching example")
  println("status: \{@matcher.status_label(result.status)}")
  println("top_track: \{result.candidates[0].name}")
  println("offset_frames: \{result.candidates[0].offset_frames}")
  println("confidence: \{result.candidates[0].confidence}")
}
