///|
test "parse index options" {
  let options = parse_index_options([
    "--input", "a.wav", "--output", "a.idx", "--name", "demo", "--id", "7",
  ])
  assert_true(
    match options.input {
      Some(value) => value == "a.wav"
      None => false
    },
  )
  assert_eq(options.output, "a.idx")
  assert_eq(options.track_name, "demo")
  assert_eq(options.track_id, 7)
}

///|
test "parse batch index options" {
  let options = parse_index_options([
    "--manifest", "tracks.tsv", "--output", "library.idx", "--append", "--json",
  ])
  assert_true(options.input is None)
  assert_true(
    match options.manifest {
      Some(value) => value == "tracks.tsv"
      None => false
    },
  )
  assert_true(options.append)
}

///|
test "parse index options reject ambiguous input" {
  try
    parse_index_options([
      "--input", "track.wav", "--manifest", "tracks.tsv", "--output", "library.idx",
    ])
  catch {
    Argument(_) => ()
    _ => fail("expected --input and --manifest to be rejected together")
  } noraise {
    _ => fail("expected --input and --manifest to be rejected together")
  }
}

///|
test "parse info options" {
  let options = parse_info_options(["--index", "library.idx", "--json"])
  assert_eq(options.index_path, "library.idx")
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
  assert_eq(parse_bench_options(["--repeat", "2", "--json"]), 2)
}

///|
test "bench JSON output" {
  let output = try! run(["moonecho", "bench", "--repeat", "1", "--json"])
  assert_true(output.has_prefix("{\"status\":\"ok\""))
  assert_true(output.contains("\"query_median_us\""))
}

///|
test "JSON strings escape reserved characters" {
  assert_eq(json_string("a\"b\\c\n"), "\"a\\\"b\\\\c\\n\"")
}

///|
test "CLI batch, append, info, and JSON workflow" {
  let dir = "_build/moonecho_cli_test"
  if @fs.path_exists(dir) {
    @fs.remove_file("\{dir}/track.wav") catch {
      _ => ()
    }
    @fs.remove_file("\{dir}/library.idx") catch {
      _ => ()
    }
    @fs.remove_file("\{dir}/manifest.idx") catch {
      _ => ()
    }
    @fs.remove_file("\{dir}/tracks.tsv") catch {
      _ => ()
    }
    @fs.remove_dir(dir) catch {
      _ => ()
    }
  }
  @fs.create_dir(dir)
  let wav_path = "\{dir}/track.wav"
  let library_path = "\{dir}/library.idx"
  let manifest_path = "\{dir}/manifest.idx"
  let manifest_file = "\{dir}/tracks.tsv"
  @fs.write_bytes_to_file(wav_path, cli_test_wav())

  let initial = try! run([
    "moonecho", "index", "--input", wav_path, "--output", library_path, "--id", "1",
    "--name", "first", "--json",
  ])
  assert_true(initial.contains("\"tracks\":1"))
  let first_index = try! @index.decode(@fs.read_file_to_bytes(library_path))
  assert_eq(first_index.track_count(), 1)
  assert_eq(first_index.tracks[0].name, "first")

  let appended = try! run([
    "moonecho", "index", "--input", wav_path, "--output", library_path, "--id", "2",
    "--name", "second", "--append", "--json",
  ])
  assert_true(appended.contains("\"tracks\":2"))
  let appended_index = try! @index.decode(@fs.read_file_to_bytes(library_path))
  assert_eq(appended_index.track_count(), 2)
  assert_eq(appended_index.tracks[1].track_id, 2)

  try
    run([
      "moonecho", "index", "--input", wav_path, "--output", library_path, "--sample-rate",
      "8000", "--id", "3", "--append",
    ])
  catch {
    Argument(message) => assert_true(message.contains("profile"))
    _ => fail("expected append profile mismatch to fail")
  } noraise {
    _ => fail("expected append profile mismatch to fail")
  }

  try
    run([
      "moonecho", "index", "--input", wav_path, "--output", library_path, "--id",
      "2", "--name", "duplicate", "--append",
    ])
  catch {
    Index(DuplicateTrack(2)) => ()
    _ => fail("expected duplicate append id to fail")
  } noraise {
    _ => fail("expected duplicate append id to fail")
  }

  @fs.write_string_to_file(
    manifest_file,
    "10\ttrack-ten\t\{wav_path}\n20\ttrack-twenty\t\{wav_path}\r\n# ignored\n",
  )
  let batch = try! run([
    "moonecho", "index", "--manifest", manifest_file, "--output", manifest_path,
    "--json",
  ])
  assert_true(batch.contains("\"tracks\":2"))
  let batch_index = try! @index.decode(@fs.read_file_to_bytes(manifest_path))
  assert_eq(batch_index.track_count(), 2)
  assert_eq(batch_index.tracks[0].track_id, 10)
  assert_eq(batch_index.tracks[0].name, "track-ten")
  assert_eq(batch_index.tracks[1].track_id, 20)
  assert_eq(batch_index.tracks[1].name, "track-twenty")

  let human_info = try! run(["moonecho", "info", "--index", manifest_path])
  assert_true(human_info.contains("snapshot_version: 2"))
  assert_true(human_info.contains("hash_max_frequency_distance: 32"))
  let json_info = try! run([
    "moonecho", "info", "--index", manifest_path, "--json",
  ])
  assert_true(json_info.contains("\"track_count\":2"))
  assert_true(json_info.contains("\"name\":\"track-ten\""))

  let match_json = try! run([
    "moonecho", "match", "--index", manifest_path, "--input", wav_path, "--json",
  ])
  assert_true(match_json.contains("\"candidates\":0"))

  @fs.remove_file(manifest_file)
  @fs.remove_file(manifest_path)
  @fs.remove_file(library_path)
  @fs.remove_file(wav_path)
  @fs.remove_dir(dir)
}

///|
fn cli_test_wav() -> Bytes {
  let sample_count = 4000
  let data_size = sample_count * 2
  let out : Array[Byte] = []
  cli_test_push_ascii(out, "RIFF")
  cli_test_push_u32(out, 36 + data_size)
  cli_test_push_ascii(out, "WAVE")
  cli_test_push_ascii(out, "fmt ")
  cli_test_push_u32(out, 16)
  cli_test_push_u16(out, 1)
  cli_test_push_u16(out, 1)
  cli_test_push_u32(out, 8000)
  cli_test_push_u32(out, 16000)
  cli_test_push_u16(out, 2)
  cli_test_push_u16(out, 16)
  cli_test_push_ascii(out, "data")
  cli_test_push_u32(out, data_size)
  for _ in 0..<data_size {
    out.push((0).to_byte())
  }
  Bytes::from_array(out)
}

///|
fn cli_test_push_ascii(out : Array[Byte], value : String) -> Unit {
  for char in value {
    out.push(char.to_int().to_byte())
  }
}

///|
fn cli_test_push_u16(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
}

///|
fn cli_test_push_u32(out : Array[Byte], value : Int) -> Unit {
  for byte_index in 0..<4 {
    out.push(((value >> (byte_index * 8)) & 0xff).to_byte())
  }
}
