///|
pub suberror CliError {
  Argument(String)
  IO(String)
  Align(@align.AlignError)
  Benchmark(@benchmark.BenchmarkError)
  Audio(@audio.AudioError)
  Spectrum(@spectrum.SpectrumError)
  Fingerprint(@fingerprint.FingerprintError)
  Index(@index.IndexError)
  Match(@match.MatchError)
}

///|
pub fn error_message(error : CliError) -> String {
  match error {
    Argument(message) => message
    IO(message) => message
    Align(err) => @align.error_message(err)
    Benchmark(err) => @benchmark.error_message(err)
    Audio(err) => @audio.error_message(err)
    Spectrum(err) => @spectrum.error_message(err)
    Fingerprint(err) => @fingerprint.error_message(err)
    Index(err) => @index.error_message(err)
    Match(err) => @match.error_message(err)
  }
}

///|
pub fn usage() -> String {
  "MoonEcho CLI\n\nUsage:\n" +
  "  moonecho version\n" +
  "  moonecho index --input <wav> --output <snapshot> [--name <track>] [--id <n>] [--append] [--sample-rate <hz>] [--window-length <n>] [--hop-size <n>] [--json]\n" +
  "  moonecho index --manifest <file> --output <snapshot> [--append] [--sample-rate <hz>] [--window-length <n>] [--hop-size <n>] [--json]\n" +
  "  moonecho match --index <snapshot> --input <wav> [--track <wav>] [--sample-rate <hz>] [--window-length <n>] [--hop-size <n>] [--top-k <n>] [--min-votes <n>] [--min-confidence <f>] [--min-margin <f>] [--json]\n" +
  "  moonecho info --index <snapshot> [--json]\n" +
  "  moonecho bench [--repeat <n>] [--json]\n"
}

///|
priv struct IndexOptions {
  input : String?
  output : String
  track_name : String
  track_id : Int
  sample_rate : Int
  window_length : Int
  hop_size : Int
  append : Bool
  manifest : String?
}

///|
priv struct MatchOptions {
  index_path : String
  input : String
  track_path : String?
  sample_rate : Int?
  window_length : Int?
  hop_size : Int?
  top_k : Int
  min_votes : Int
  min_confidence : Double
  min_margin : Double
}

///|
priv struct InfoOptions {
  index_path : String
}

///|
pub fn run(args : Array[String]) -> String raise CliError {
  if args.length() < 2 {
    return usage()
  }
  match args[1] {
    "version" => "MoonEcho v\{@moonecho.project_version()}"
    "help" | "--help" | "-h" => usage()
    "index" => run_index(sub_args(args, 2), has_flag(args, "--json"))
    "match" => run_match(sub_args(args, 2), has_flag(args, "--json"))
    "info" => run_info(sub_args(args, 2), has_flag(args, "--json"))
    "bench" => run_bench(sub_args(args, 2), has_flag(args, "--json"))
    command => raise Argument("unknown command: \{command}")
  }
}

///|
fn run_bench(args : Array[String], json_output : Bool) -> String raise CliError {
  let repeat = parse_bench_options(args)
  let config = try @benchmark.RobustnessConfig::new() catch {
    err => raise Benchmark(err)
  } noraise {
    value => value
  }
  let report = try @benchmark.benchmark_report(config, repeat) catch {
    err => raise Benchmark(err)
  } noraise {
    value => value
  }
  if json_output {
    json_object([
      json_field("status", json_string("ok")),
      json_field("cases", json_number(report.cases.length())),
      json_field("correct_hits", json_number(report.correct_hits)),
      json_field("positive_cases", json_number(report.positive_cases)),
      json_field("negative_hits", json_number(report.negative_hits)),
      json_field("negative_cases", json_number(report.negative_cases)),
      json_field(
        "mean_offset_error_frames",
        json_number_double(report.mean_offset_error_frames),
      ),
      json_field(
        "max_offset_error_frames",
        json_number(report.max_offset_error_frames),
      ),
      json_field(
        "mean_sample_offset_error",
        json_number_double(report.mean_sample_offset_error),
      ),
      json_field(
        "max_sample_offset_error",
        json_number(report.max_sample_offset_error),
      ),
      json_field("hash_count", json_number(report.hash_count)),
      json_field("posting_count", json_number(report.posting_count)),
      json_field("snapshot_bytes", json_number(report.snapshot_bytes)),
      json_field("query_median_us", json_number_double(report.query_median_us)),
    ])
  } else {
    "benchmark: ok\n" +
    "cases: \{report.cases.length()}\n" +
    "correct_hits: \{report.correct_hits}/\{report.positive_cases}\n" +
    "negative_hits: \{report.negative_hits}/\{report.negative_cases}\n" +
    "mean_offset_error_frames: \{report.mean_offset_error_frames}\n" +
    "max_offset_error_frames: \{report.max_offset_error_frames}\n" +
    "mean_sample_offset_error: \{report.mean_sample_offset_error}\n" +
    "max_sample_offset_error: \{report.max_sample_offset_error}\n" +
    "hash_count: \{report.hash_count}\n" +
    "posting_count: \{report.posting_count}\n" +
    "snapshot_bytes: \{report.snapshot_bytes}\n" +
    "query_median_us: \{report.query_median_us}"
  }
}

///|
fn run_info(args : Array[String], json_output : Bool) -> String raise CliError {
  let options = parse_info_options(args)
  let bytes = read_bytes(options.index_path)
  let version = snapshot_version(bytes)
  let index = index_or_cli(bytes)
  if json_output {
    let tracks : Array[String] = []
    for track in index.tracks {
      tracks.push(
        json_object([
          json_field("track_id", json_number(track.track_id)),
          json_field("name", json_string(track.name)),
          json_field("frame_count", json_number(track.frame_count)),
          json_field("bin_count", json_number(track.bin_count)),
          json_field("hash_count", json_number(track.hash_count)),
        ]),
      )
    }
    json_object([
      json_field("snapshot", json_string(options.index_path)),
      json_field("snapshot_version", json_number(version)),
      json_field(
        "fingerprint_version",
        json_number(@fingerprint.fingerprint_version),
      ),
      json_field("sample_rate", json_number(index.profile.sample_rate)),
      json_field("window_length", json_number(index.profile.window_length)),
      json_field("hop_size", json_number(index.profile.hop_size)),
      json_field(
        "peak_frequency_radius",
        json_number(index.profile.peak_config.frequency_radius),
      ),
      json_field(
        "peak_time_radius",
        json_number(index.profile.peak_config.time_radius),
      ),
      json_field(
        "peak_min_magnitude",
        json_number_double(index.profile.peak_config.min_magnitude),
      ),
      json_field(
        "peak_relative_threshold",
        json_number_double(index.profile.peak_config.relative_threshold),
      ),
      json_field(
        "peak_max_per_frame",
        json_number(index.profile.peak_config.max_peaks_per_frame),
      ),
      json_field(
        "hash_seed",
        json_string(index.profile.hash_config.hash_seed.to_string()),
      ),
      json_field("hash_fan_out", json_number(index.profile.hash_config.fan_out)),
      json_field(
        "hash_min_delta_frames",
        json_number(index.profile.hash_config.min_delta_frames),
      ),
      json_field(
        "hash_max_delta_frames",
        json_number(index.profile.hash_config.max_delta_frames),
      ),
      json_field(
        "hash_max_frequency_distance",
        json_frequency_distance(
          index.profile.hash_config.max_frequency_distance,
        ),
      ),
      json_field("track_count", json_number(index.track_count())),
      json_field("posting_count", json_number(index.posting_count())),
      json_field("tracks", "[" + tracks.join(",") + "]"),
    ])
  } else {
    let mut output = "snapshot: \{options.index_path}\n" +
      "snapshot_version: \{version}\n" +
      "fingerprint_version: \{@fingerprint.fingerprint_version}\n" +
      "sample_rate: \{index.profile.sample_rate}\n" +
      "window_length: \{index.profile.window_length}\n" +
      "hop_size: \{index.profile.hop_size}\n" +
      "peak_frequency_radius: \{index.profile.peak_config.frequency_radius}\n" +
      "peak_time_radius: \{index.profile.peak_config.time_radius}\n" +
      "peak_min_magnitude: \{index.profile.peak_config.min_magnitude}\n" +
      "peak_relative_threshold: \{index.profile.peak_config.relative_threshold}\n" +
      "peak_max_per_frame: \{index.profile.peak_config.max_peaks_per_frame}\n" +
      "hash_seed: \{index.profile.hash_config.hash_seed}\n" +
      "hash_fan_out: \{index.profile.hash_config.fan_out}\n" +
      "hash_min_delta_frames: \{index.profile.hash_config.min_delta_frames}\n" +
      "hash_max_delta_frames: \{index.profile.hash_config.max_delta_frames}\n" +
      "hash_max_frequency_distance: " +
      frequency_distance_label(index.profile.hash_config.max_frequency_distance) +
      "\n" +
      "tracks: \{index.track_count()}\n" +
      "postings: \{index.posting_count()}"
    for track in index.tracks {
      output = output +
        "\n  \{track.track_id}\t\{track.name}\thashes=\{track.hash_count}"
    }
    output
  }
}

///|
fn parse_info_options(args : Array[String]) -> InfoOptions raise CliError {
  let mut index_path : String? = None
  let mut cursor = 0
  while cursor < args.length() {
    let option = args[cursor]
    if option == "--index" {
      index_path = Some(require_value(args, cursor, option))
      cursor = cursor + 2
    } else if option == "--json" {
      cursor = cursor + 1
    } else {
      raise Argument("unknown info option: \{option}")
    }
  }
  match index_path {
    Some(index_path) => { index_path, }
    None => raise Argument("info requires --index")
  }
}

///|
fn snapshot_version(bytes : Bytes) -> Int {
  if bytes.has_prefix(@index.index_magic_v1()) {
    1
  } else {
    2
  }
}

///|
fn add_wav_entry(
  index : @index.FingerprintIndex,
  track_id : Int,
  name : String,
  path : String,
) -> Int raise CliError {
  let fingerprint = fingerprint_for_profile(path, index.profile)
  add_track_or_cli(index, track_id, name, fingerprint)
  fingerprint.hashes.length()
}

///|
fn fingerprint_for_profile(
  path : String,
  profile : @index.ProcessingProfile,
) -> @fingerprint.AudioFingerprint raise CliError {
  let audio = audio_or_cli(bytes_to_ints(read_bytes(path)), profile.sample_rate)
  let spectrogram = spectrogram_or_cli(
    audio,
    spectrum_config_or_cli(profile.window_length, profile.hop_size),
  )
  let peaks = peaks_or_cli(spectrogram, profile.peak_config)
  fingerprint_or_cli(
    peaks,
    profile.hash_config,
    spectrogram.magnitudes.length(),
    spectrogram.frequencies.length(),
  )
}

///|
fn add_manifest(
  index : @index.FingerprintIndex,
  path : String,
) -> Int raise CliError {
  let content = try @fs.read_file_to_string(path) catch {
    _ => raise IO("failed to read manifest: \{path}")
  } noraise {
    value => value
  }
  let mut total_hashes = 0
  for raw_line in content.split("\n") {
    let line = raw_line.trim()
    if line.is_blank() || line.has_prefix("#") {
      continue
    }
    let parts : Array[StringView] = line.split("\t").to_array()
    if parts.length() != 3 {
      raise Argument("manifest line must be id<TAB>name<TAB>wav")
    }
    let track_id = parse_int(parts[0].to_owned(), "manifest id")
    total_hashes = total_hashes +
      add_wav_entry(index, track_id, parts[1].to_owned(), parts[2].to_owned())
  }
  total_hashes
}

///|
fn parse_bench_options(args : Array[String]) -> Int raise CliError {
  let mut repeat = 5
  let mut cursor = 0
  while cursor < args.length() {
    let option = args[cursor]
    if option == "--repeat" {
      repeat = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--json" {
      cursor = cursor + 1
    } else {
      raise Argument("unknown bench option: \{option}")
    }
  }
  if repeat <= 0 {
    raise Argument("repeat must be positive")
  }
  repeat
}

///|
fn run_index(args : Array[String], json_output : Bool) -> String raise CliError {
  let options = parse_index_options(args)
  let peak_config = default_peak_config_or_cli()
  let hash_config = hash_config_or_cli()
  let profile = try
    @index.ProcessingProfile::new(
      options.sample_rate,
      options.window_length,
      options.hop_size,
      peak_config,
      hash_config,
    )
  catch {
    err => raise Index(err)
  } noraise {
    value => value
  }
  let index = if options.append && @fs.path_exists(options.output) {
    let existing = index_or_cli(read_bytes(options.output))
    if !@index.profile_equal(existing.profile, profile) {
      raise Argument("append profile does not match existing snapshot")
    }
    existing
  } else {
    @index.with_profile(profile)
  }
  let mut added_hashes = 0
  match (options.input, options.manifest) {
    (Some(input), None) =>
      added_hashes = add_wav_entry(
        index,
        options.track_id,
        options.track_name,
        input,
      )
    (None, Some(manifest)) => added_hashes = add_manifest(index, manifest)
    _ => raise Argument("index requires --input or --manifest")
  }
  let snapshot = @index.encode(index)
  write_bytes(options.output, snapshot)
  if json_output {
    json_object([
      json_field("status", json_string("indexed")),
      json_field("snapshot", json_string(options.output)),
      json_field("tracks", json_number(index.track_count())),
      json_field("added_hashes", json_number(added_hashes)),
      json_field("postings", json_number(index.posting_count())),
    ])
  } else {
    "indexed\n" +
    "tracks: \{index.track_count()}\n" +
    "added_hashes: \{added_hashes}\n" +
    "postings: \{index.posting_count()}\n" +
    "snapshot: \{options.output}"
  }
}

///|
fn run_match(args : Array[String], json_output : Bool) -> String raise CliError {
  let options = parse_match_options(args)
  let index = index_or_cli(read_bytes(options.index_path))
  check_match_profile_options(options, index.profile)
  let query_audio = audio_or_cli(
    bytes_to_ints(read_bytes(options.input)),
    index.profile.sample_rate,
  )
  let spectrogram = spectrogram_or_cli(
    query_audio,
    spectrum_config_or_cli(index.profile.window_length, index.profile.hop_size),
  )
  let peaks = peaks_or_cli(spectrogram, index.profile.peak_config)
  let query = fingerprint_or_cli(
    peaks,
    index.profile.hash_config,
    spectrogram.magnitudes.length(),
    spectrogram.frequencies.length(),
  )
  let match_config = match_config_or_cli(
    options.top_k,
    options.min_votes,
    options.min_confidence,
    options.min_margin,
  )
  let result = match_or_cli(index, query, match_config)
  if result.candidates.length() == 0 {
    if json_output {
      return json_object([
        json_field("status", json_string(@match.status_label(result.status))),
        json_field("candidates", json_number(0)),
        json_field(
          "considered_postings",
          json_number(result.considered_postings),
        ),
      ])
    }
    return "status: \{@match.status_label(result.status)}\n" +
      "candidates: 0\n" +
      "considered_postings: \{result.considered_postings}"
  }
  let best = result.candidates[0]
  let rough_offset_samples = best.offset_frames * index.profile.hop_size
  let (offset_samples, alignment, correlation) = match options.track_path {
    Some(track_path) => {
      let track_audio = audio_or_cli(
        bytes_to_ints(read_bytes(track_path)),
        index.profile.sample_rate,
      )
      let alignment_config = try
        @align.AlignConfig::new(
          search_radius_samples=index.profile.hop_size,
          window_samples=4096,
        )
      catch {
        err => raise Align(err)
      } noraise {
        value => value
      }
      let refined = try
        @align.refine_offset(
          track_audio.samples[:],
          query_audio.samples[:],
          rough_offset_samples,
          alignment_config,
        )
      catch {
        err => raise Align(err)
      } noraise {
        value => value
      }
      (refined.refined_offset_samples, "sample", refined.correlation)
    }
    None => (rough_offset_samples, "frame", 0.0)
  }
  let offset_seconds = offset_samples.to_double() /
    index.profile.sample_rate.to_double()
  if json_output {
    return json_object([
      json_field("status", json_string(@match.status_label(result.status))),
      json_field("top_track", json_string(best.name)),
      json_field("offset_frames", json_number(best.offset_frames)),
      json_field("offset_samples", json_number(offset_samples)),
      json_field("offset_seconds", json_number_double(offset_seconds)),
      json_field("alignment", json_string(alignment)),
      json_field("correlation", json_number_double(correlation)),
      json_field("confidence", json_number_double(best.confidence)),
      json_field("candidates", json_number(result.candidates.length())),
      json_field("considered_postings", json_number(result.considered_postings)),
    ])
  }
  "status: \{@match.status_label(result.status)}\n" +
  "top_track: \{best.name}\n" +
  "offset_frames: \{best.offset_frames}\n" +
  "offset_samples: \{offset_samples}\n" +
  "offset_seconds: \{offset_seconds}\n" +
  "alignment: \{alignment}\n" +
  "correlation: \{correlation}\n" +
  "confidence: \{best.confidence}\n" +
  "candidates: \{result.candidates.length()}\n" +
  "considered_postings: \{result.considered_postings}"
}

///|
fn parse_index_options(args : Array[String]) -> IndexOptions raise CliError {
  let mut input : String? = None
  let mut output : String? = None
  let mut manifest : String? = None
  let mut track_name = "track"
  let mut track_id = 1
  let mut sample_rate = 16000
  let mut window_length = 1024
  let mut hop_size = 512
  let mut append = false
  let mut cursor = 0
  while cursor < args.length() {
    let option = args[cursor]
    if option == "--input" {
      input = Some(require_value(args, cursor, option))
      cursor = cursor + 2
    } else if option == "--manifest" {
      manifest = Some(require_value(args, cursor, option))
      cursor = cursor + 2
    } else if option == "--append" {
      append = true
      cursor = cursor + 1
    } else if option == "--json" {
      cursor = cursor + 1
    } else if option == "--output" {
      output = Some(require_value(args, cursor, option))
      cursor = cursor + 2
    } else if option == "--name" {
      track_name = require_value(args, cursor, option)
      cursor = cursor + 2
    } else if option == "--id" {
      track_id = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--sample-rate" {
      sample_rate = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--window-length" {
      window_length = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--hop-size" {
      hop_size = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else {
      raise Argument("unknown index option: \{option}")
    }
  }
  match (input, manifest) {
    (Some(_), Some(_)) =>
      raise Argument("index accepts only one of --input or --manifest")
    (None, None) => raise Argument("index requires --input or --manifest")
    _ => ()
  }
  match output {
    Some(output) =>
      {
        input,
        output,
        track_name,
        track_id,
        sample_rate,
        window_length,
        hop_size,
        append,
        manifest,
      }
    None => raise Argument("index requires --output")
  }
}

///|
fn parse_match_options(args : Array[String]) -> MatchOptions raise CliError {
  let mut index_path : String? = None
  let mut input : String? = None
  let mut track_path : String? = None
  let mut sample_rate : Int? = None
  let mut window_length : Int? = None
  let mut hop_size : Int? = None
  let mut top_k = 5
  let mut min_votes = 3
  let mut min_confidence = 0.05
  let mut min_margin = 0.0
  let mut cursor = 0
  while cursor < args.length() {
    let option = args[cursor]
    if option == "--index" {
      index_path = Some(require_value(args, cursor, option))
      cursor = cursor + 2
    } else if option == "--input" {
      input = Some(require_value(args, cursor, option))
      cursor = cursor + 2
    } else if option == "--track" {
      track_path = Some(require_value(args, cursor, option))
      cursor = cursor + 2
    } else if option == "--json" {
      cursor = cursor + 1
    } else if option == "--sample-rate" {
      sample_rate = Some(parse_int(require_value(args, cursor, option), option))
      cursor = cursor + 2
    } else if option == "--window-length" {
      window_length = Some(
        parse_int(require_value(args, cursor, option), option),
      )
      cursor = cursor + 2
    } else if option == "--hop-size" {
      hop_size = Some(parse_int(require_value(args, cursor, option), option))
      cursor = cursor + 2
    } else if option == "--top-k" {
      top_k = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--min-votes" {
      min_votes = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--min-confidence" {
      min_confidence = parse_double(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--min-margin" {
      min_margin = parse_double(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else {
      raise Argument("unknown match option: \{option}")
    }
  }
  match (index_path, input) {
    (Some(index_path), Some(input)) =>
      {
        index_path,
        input,
        track_path,
        sample_rate,
        window_length,
        hop_size,
        top_k,
        min_votes,
        min_confidence,
        min_margin,
      }
    _ => raise Argument("match requires --index and --input")
  }
}

///|
fn check_match_profile_options(
  options : MatchOptions,
  profile : @index.ProcessingProfile,
) -> Unit raise CliError {
  match options.sample_rate {
    Some(value) =>
      if value != profile.sample_rate {
        raise Argument(
          "--sample-rate \{value} conflicts with index profile \{profile.sample_rate}",
        )
      }
    None => ()
  }
  match options.window_length {
    Some(value) =>
      if value != profile.window_length {
        raise Argument(
          "--window-length \{value} conflicts with index profile \{profile.window_length}",
        )
      }
    None => ()
  }
  match options.hop_size {
    Some(value) =>
      if value != profile.hop_size {
        raise Argument(
          "--hop-size \{value} conflicts with index profile \{profile.hop_size}",
        )
      }
    None => ()
  }
}

///|
fn require_value(
  args : Array[String],
  cursor : Int,
  option : String,
) -> String raise CliError {
  if cursor + 1 >= args.length() {
    raise Argument("missing value for \{option}")
  }
  args[cursor + 1]
}

///|
fn parse_int(value : String, option : String) -> Int raise CliError {
  try @string.parse_int(value) catch {
    _ => raise Argument("invalid integer for \{option}: \{value}")
  } noraise {
    parsed => parsed
  }
}

///|
fn parse_double(value : String, option : String) -> Double raise CliError {
  try @string.parse_double(value) catch {
    _ => raise Argument("invalid number for \{option}: \{value}")
  } noraise {
    parsed => parsed
  }
}

///|
fn audio_or_cli(
  bytes : Array[Int],
  sample_rate : Int,
) -> @audio.AudioBuffer raise CliError {
  try @audio.load_wav_mono(bytes, target_sample_rate=sample_rate) catch {
    err => raise Audio(err)
  } noraise {
    value => value
  }
}

///|
fn spectrum_config_or_cli(
  window_length : Int,
  hop_size : Int,
) -> @spectrum.SpectrumConfig raise CliError {
  try @spectrum.SpectrumConfig::new(window_length~, hop_size~) catch {
    err => raise Spectrum(err)
  } noraise {
    value => value
  }
}

///|
fn spectrogram_or_cli(
  audio : @audio.AudioBuffer,
  config : @spectrum.SpectrumConfig,
) -> @spectrum.Spectrogram raise CliError {
  try @spectrum.spectrogram(audio, config) catch {
    err => raise Spectrum(err)
  } noraise {
    value => value
  }
}

///|
fn default_peak_config_or_cli() -> @spectrum.PeakConfig raise CliError {
  try @spectrum.PeakConfig::new() catch {
    err => raise Spectrum(err)
  } noraise {
    value => value
  }
}

///|
fn peaks_or_cli(
  spectrogram : @spectrum.Spectrogram,
  config : @spectrum.PeakConfig,
) -> Array[@spectrum.SpectralPeak] raise CliError {
  try @spectrum.extract_peaks(spectrogram, config) catch {
    err => raise Spectrum(err)
  } noraise {
    value => value
  }
}

///|
fn hash_config_or_cli() -> @fingerprint.HashConfig raise CliError {
  try @fingerprint.HashConfig::new() catch {
    err => raise Fingerprint(err)
  } noraise {
    value => value
  }
}

///|
fn fingerprint_or_cli(
  peaks : Array[@spectrum.SpectralPeak],
  config : @fingerprint.HashConfig,
  frame_count : Int,
  bin_count : Int,
) -> @fingerprint.AudioFingerprint raise CliError {
  try @fingerprint.fingerprint(peaks, config, frame_count~, bin_count~) catch {
    err => raise Fingerprint(err)
  } noraise {
    value => value
  }
}

///|
fn add_track_or_cli(
  index : @index.FingerprintIndex,
  track_id : Int,
  name : String,
  fingerprint : @fingerprint.AudioFingerprint,
) -> Unit raise CliError {
  try index.add_track(track_id, name, fingerprint) catch {
    err => raise Index(err)
  } noraise {
    _ => ()
  }
}

///|
fn index_or_cli(bytes : Bytes) -> @index.FingerprintIndex raise CliError {
  try @index.decode(bytes) catch {
    err => raise Index(err)
  } noraise {
    value => value
  }
}

///|
fn match_config_or_cli(
  top_k : Int,
  min_votes : Int,
  min_confidence : Double,
  min_margin : Double,
) -> @match.MatchConfig raise CliError {
  try
    @match.MatchConfig::new(top_k~, min_votes~, min_confidence~, min_margin~)
  catch {
    err => raise Match(err)
  } noraise {
    value => value
  }
}

///|
fn match_or_cli(
  index : @index.FingerprintIndex,
  query : @fingerprint.AudioFingerprint,
  config : @match.MatchConfig,
) -> @match.MatchResult raise CliError {
  try @match.match_fingerprint(index, query, config) catch {
    err => raise Match(err)
  } noraise {
    value => value
  }
}

///|
fn read_bytes(path : String) -> Bytes raise CliError {
  try @fs.read_file_to_bytes(path) catch {
    _ => raise IO("failed to read file: \{path}")
  } noraise {
    bytes => bytes
  }
}

///|
fn write_bytes(path : String, bytes : Bytes) -> Unit raise CliError {
  try @fs.write_bytes_to_file(path, bytes) catch {
    _ => raise IO("failed to write file: \{path}")
  } noraise {
    _ => ()
  }
}

///|
fn bytes_to_ints(bytes : Bytes) -> Array[Int] {
  let output : Array[Int] = []
  for byte in bytes {
    output.push(byte.to_int())
  }
  output
}

///|
fn sub_args(args : Array[String], start : Int) -> Array[String] {
  let output : Array[String] = []
  for index in start..<args.length() {
    output.push(args[index])
  }
  output
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  for arg in args {
    if arg == flag {
      return true
    }
  }
  false
}

///|
fn json_field(name : String, value : String) -> String {
  json_string(name) + ":" + value
}

///|
fn json_object(fields : Array[String]) -> String {
  "{" + fields.join(",") + "}"
}

///|
fn json_string(value : String) -> String {
  "\"" + json_escape(value) + "\""
}

///|
fn json_escape(value : String) -> String {
  let mut output = ""
  for char in value {
    if char == '"' {
      output = output + "\\\""
    } else if char == '\\' {
      output = output + "\\\\"
    } else if char == '\n' {
      output = output + "\\n"
    } else if char == '\r' {
      output = output + "\\r"
    } else if char == '\t' {
      output = output + "\\t"
    } else if char.to_int() < 0x20 {
      let code = char.to_int()
      output = output +
        "\\u00" +
        json_hex_digit(code / 16).to_string() +
        json_hex_digit(code % 16).to_string()
    } else {
      output = output + char.to_string()
    }
  }
  output
}

///|
fn json_number(value : Int) -> String {
  value.to_string()
}

///|
fn json_number_double(value : Double) -> String {
  value.to_string()
}

///|
fn json_frequency_distance(value : Int) -> String {
  if value < 0 {
    "null"
  } else {
    json_number(value)
  }
}

///|
fn frequency_distance_label(value : Int) -> String {
  if value < 0 {
    "unlimited"
  } else {
    value.to_string()
  }
}

///|
fn json_hex_digit(value : Int) -> Char {
  if value < 10 {
    ('0'.to_int() + value).unsafe_to_char()
  } else {
    ('a'.to_int() + value - 10).unsafe_to_char()
  }
}
