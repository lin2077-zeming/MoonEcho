///|
pub suberror CliError {
  Argument(String)
  IO(String)
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
  "  moonecho index --input <wav> --output <snapshot> [--name <track>] [--id <n>] [--sample-rate <hz>] [--window-length <n>] [--hop-size <n>]\n" +
  "  moonecho match --index <snapshot> --input <wav> [--sample-rate <hz>] [--window-length <n>] [--hop-size <n>] [--top-k <n>] [--min-votes <n>] [--min-confidence <f>] [--min-margin <f>]\n" +
  "  moonecho bench [--repeat <n>]\n"
}

///|
priv struct IndexOptions {
  input : String
  output : String
  track_name : String
  track_id : Int
  sample_rate : Int
  window_length : Int
  hop_size : Int
}

///|
priv struct MatchOptions {
  index_path : String
  input : String
  sample_rate : Int
  window_length : Int
  hop_size : Int
  top_k : Int
  min_votes : Int
  min_confidence : Double
  min_margin : Double
}

///|
pub fn run(args : Array[String]) -> String raise CliError {
  if args.length() < 2 {
    return usage()
  }
  match args[1] {
    "version" => "MoonEcho v\{@moonecho.project_version()}"
    "help" | "--help" | "-h" => usage()
    "index" => run_index(sub_args(args, 2))
    "match" => run_match(sub_args(args, 2))
    "bench" => run_bench(sub_args(args, 2))
    command => raise Argument("unknown command: \{command}")
  }
}

///|
fn run_bench(args : Array[String]) -> String raise CliError {
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
  "benchmark: ok\n" +
  "cases: \{report.cases.length()}\n" +
  "correct_hits: \{report.correct_hits}/\{report.positive_cases}\n" +
  "negative_hits: \{report.negative_hits}/\{report.negative_cases}\n" +
  "mean_offset_error_frames: \{report.mean_offset_error_frames}\n" +
  "max_offset_error_frames: \{report.max_offset_error_frames}\n" +
  "hash_count: \{report.hash_count}\n" +
  "posting_count: \{report.posting_count}\n" +
  "snapshot_bytes: \{report.snapshot_bytes}\n" +
  "query_median_us: \{report.query_median_us}"
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
fn run_index(args : Array[String]) -> String raise CliError {
  let options = parse_index_options(args)
  let audio = audio_or_cli(
    bytes_to_ints(read_bytes(options.input)),
    options.sample_rate,
  )
  let spectrogram = spectrogram_or_cli(
    audio,
    spectrum_config_or_cli(options.window_length, options.hop_size),
  )
  let peaks = peaks_or_cli(spectrogram, default_peak_config_or_cli())
  let hash_config = hash_config_or_cli()
  let fingerprint = fingerprint_or_cli(
    peaks,
    hash_config,
    spectrogram.magnitudes.length(),
    spectrogram.frequencies.length(),
  )
  let index = @index.FingerprintIndex::new(hash_config)
  add_track_or_cli(index, options.track_id, options.track_name, fingerprint)
  let snapshot = @index.encode(index)
  write_bytes(options.output, snapshot)
  "indexed track \{options.track_id}: \{options.track_name}\n" +
  "hashes: \{fingerprint.hashes.length()}\n" +
  "postings: \{index.posting_count()}\n" +
  "snapshot: \{options.output}"
}

///|
fn run_match(args : Array[String]) -> String raise CliError {
  let options = parse_match_options(args)
  let index = index_or_cli(read_bytes(options.index_path))
  let query_audio = audio_or_cli(
    bytes_to_ints(read_bytes(options.input)),
    options.sample_rate,
  )
  let spectrogram = spectrogram_or_cli(
    query_audio,
    spectrum_config_or_cli(options.window_length, options.hop_size),
  )
  let peaks = peaks_or_cli(spectrogram, default_peak_config_or_cli())
  let query = fingerprint_or_cli(
    peaks,
    index.config,
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
    return "status: \{@match.status_label(result.status)}\n" +
      "candidates: 0\n" +
      "considered_postings: \{result.considered_postings}"
  }
  let best = result.candidates[0]
  let offset_seconds = best.offset_frames.to_double() *
    options.hop_size.to_double() /
    options.sample_rate.to_double()
  "status: \{@match.status_label(result.status)}\n" +
  "top_track: \{best.name}\n" +
  "offset_frames: \{best.offset_frames}\n" +
  "offset_seconds: \{offset_seconds}\n" +
  "confidence: \{best.confidence}\n" +
  "candidates: \{result.candidates.length()}\n" +
  "considered_postings: \{result.considered_postings}"
}

///|
fn parse_index_options(args : Array[String]) -> IndexOptions raise CliError {
  let mut input : String? = None
  let mut output : String? = None
  let mut track_name = "track"
  let mut track_id = 1
  let mut sample_rate = 16000
  let mut window_length = 1024
  let mut hop_size = 512
  let mut cursor = 0
  while cursor < args.length() {
    let option = args[cursor]
    if option == "--input" {
      input = Some(require_value(args, cursor, option))
      cursor = cursor + 2
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
  match (input, output) {
    (Some(input), Some(output)) =>
      {
        input,
        output,
        track_name,
        track_id,
        sample_rate,
        window_length,
        hop_size,
      }
    _ => raise Argument("index requires --input and --output")
  }
}

///|
fn parse_match_options(args : Array[String]) -> MatchOptions raise CliError {
  let mut index_path : String? = None
  let mut input : String? = None
  let mut sample_rate = 16000
  let mut window_length = 1024
  let mut hop_size = 512
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
    } else if option == "--sample-rate" {
      sample_rate = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--window-length" {
      window_length = parse_int(require_value(args, cursor, option), option)
      cursor = cursor + 2
    } else if option == "--hop-size" {
      hop_size = parse_int(require_value(args, cursor, option), option)
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
