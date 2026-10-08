///|
fn make_fingerprint() -> @fp.AudioFingerprint {
  let config = try! @fp.HashConfig::new()
  {
    version: @fp.fingerprint_version,
    frame_count: 64,
    bin_count: 128,
    config,
    hashes: [
      {
        hash: 1001UL,
        anchor_frame: 4,
        anchor_bin: 10,
        delta_frames: 3,
        target_bin: 18,
      },
      {
        hash: 1002UL,
        anchor_frame: 12,
        anchor_bin: 22,
        delta_frames: 5,
        target_bin: 30,
      },
    ],
  }
}

///|
fn main {
  let config = try! @fp.HashConfig::new()
  let index = @idx.FingerprintIndex::new(config)
  try! index.add_track(1, "demo-track", make_fingerprint())
  let snapshot = @idx.encode(index)
  let decoded = try! @idx.decode(snapshot)
  println("Index snapshot v1 example")
  println("tracks: \{decoded.track_count()}")
  println("postings: \{decoded.posting_count()}")
  println("matches_1001: \{decoded.lookup(1001UL).length()}")
  println("snapshot_bytes: \{snapshot.length()}")
}
