///|
test "parse index options" {
  let options = parse_index_options([
    "--input", "a.wav", "--output", "a.idx", "--name", "demo", "--id", "7",
  ])
  assert_eq(options.input, "a.wav")
  assert_eq(options.output, "a.idx")
  assert_eq(options.track_name, "demo")
  assert_eq(options.track_id, 7)
}

///|
test "parse match options" {
  let options = parse_match_options([
    "--index", "a.idx", "--input", "clip.wav", "--track", "track.wav", "--min-votes",
    "4", "--min-confidence", "0.25",
  ])
  assert_eq(options.index_path, "a.idx")
  assert_eq(options.input, "clip.wav")
  assert_true(
    match options.track_path {
      Some(path) => path == "track.wav"
      None => false
    },
  )
  assert_true(options.sample_rate is None)
  assert_eq(options.min_votes, 4)
  assert_true((options.min_confidence - 0.25).abs() < 0.0001)
}

///|
test "match rejects profile-conflicting options" {
  let profile = try! @index.ProcessingProfile::new(
    8000,
    256,
    128,
    @index.default_peak_config(),
    @fingerprint.HashConfig::new(),
  )
  let options = parse_match_options([
    "--index", "a.idx", "--input", "clip.wav", "--sample-rate", "16000",
  ])
  try check_match_profile_options(options, profile) catch {
    Argument(_) => ()
    _ => fail("expected profile conflict")
  } noraise {
    _ => fail("expected profile conflict")
  }
}

///|
test "run version and help" {
  assert_eq(try! run(["moonecho", "version"]), "MoonEcho v0.1.0")
  assert_true(try! run(["moonecho", "help"]).contains("moonecho index"))
}

///|
test "parse bench options" {
  assert_eq(parse_bench_options([]), 5)
  assert_eq(parse_bench_options(["--repeat", "9"]), 9)
}
