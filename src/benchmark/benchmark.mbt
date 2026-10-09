///|
pub(all) struct RobustnessConfig {
  sample_rate : Int
  window_length : Int
  hop_size : Int
  track_frames : Int
  clip_start : Int
  clip_frames : Int
  silence_padding : Int
  noise_amplitude : Double
}

///|
pub(all) struct RobustnessCase {
  name : String
  top1_hit : Bool
  strong : Bool
  expected_offset_frames : Int
  actual_offset_frames : Int
  offset_error_frames : Int
}

///|
pub(all) struct BenchmarkReport {
  cases : Array[RobustnessCase]
  correct_hits : Int
  positive_cases : Int
  negative_cases : Int
  negative_hits : Int
  mean_offset_error_frames : Double
  max_offset_error_frames : Int
  hash_count : Int
  posting_count : Int
  snapshot_bytes : Int
  query_median_us : Double
}

///|
pub suberror BenchmarkError {
  Build(String)
}

///|
pub fn RobustnessConfig::new(
  sample_rate? : Int = 8000,
  window_length? : Int = 256,
  hop_size? : Int = 128,
  track_frames? : Int = 8000,
  clip_start? : Int = 2048,
  clip_frames? : Int = 4096,
  silence_padding? : Int = 128,
  noise_amplitude? : Double = 0.05,
) -> RobustnessConfig raise BenchmarkError {
  if sample_rate <= 0 || window_length <= 0 || hop_size <= 0 {
    raise Build("sample_rate, window_length, and hop_size must be positive")
  }
  if track_frames <= clip_start + clip_frames {
    raise Build("track_frames must be larger than clip_start + clip_frames")
  }
  if silence_padding < 0 {
    raise Build("silence_padding must be non-negative")
  }
  {
    sample_rate,
    window_length,
    hop_size,
    track_frames,
    clip_start,
    clip_frames,
    silence_padding,
    noise_amplitude,
  }
}

///|
pub fn robustness_report(
  config : RobustnessConfig,
) -> BenchmarkReport raise BenchmarkError {
  let track = build_track(config)
  let index = build_index(config, track)
  let snapshot = @index.encode(index)
  let hash_count = count_hashes(index)
  let clip = slice_samples(track, config.clip_start, config.clip_frames)
  let clean = match_case(index, "clean", clip, 0, config)
  let padded = match_case(
    index,
    "silence",
    pad_silence(clip, config.silence_padding),
    -(config.silence_padding / config.hop_size),
    config,
  )
  let gained = match_case(index, "gain", apply_gain(clip, 0.5), 0, config)
  let noisy = match_case(
    index,
    "noise",
    add_noise(clip, config.noise_amplitude),
    0,
    config,
  )
  let negative_signal = different_signal(config.clip_frames, config.sample_rate)
  let negative = match_case(index, "unrelated", negative_signal, 0, config)
  let cases = [clean, padded, gained, noisy, negative]
  summarize(cases, hash_count, index.posting_count(), snapshot.length())
}

///|
pub fn benchmark_report(
  config : RobustnessConfig,
  repeats : Int,
) -> BenchmarkReport raise BenchmarkError {
  if repeats <= 0 {
    raise Build("repeats must be positive")
  }
  let report = robustness_report(config)
  let track = build_track(config)
  let index = build_index(config, track)
  let clip = slice_samples(track, config.clip_start, config.clip_frames)
  let query = fingerprint_from_samples(clip, index.config, config)
  let match_config = try
    @match.MatchConfig::new(
      top_k=5,
      min_votes=1,
      min_confidence=0.0,
      min_margin=0.0,
    )
  catch {
    err => raise Build(@match.error_message(err))
  } noraise {
    value => value
  }
  let durations = Array::makei(repeats, _ => {
    let start = @bench.monotonic_clock_start()
    let _ = try! @match.match_fingerprint(index, query, match_config)
    @bench.monotonic_clock_end(start)
  })
  durations.sort()
  {
    cases: report.cases,
    correct_hits: report.correct_hits,
    positive_cases: report.positive_cases,
    negative_cases: report.negative_cases,
    negative_hits: report.negative_hits,
    mean_offset_error_frames: report.mean_offset_error_frames,
    max_offset_error_frames: report.max_offset_error_frames,
    hash_count: report.hash_count,
    posting_count: report.posting_count,
    snapshot_bytes: report.snapshot_bytes,
    query_median_us: durations[repeats / 2],
  }
}

///|
fn build_track(config : RobustnessConfig) -> Array[Double] raise BenchmarkError {
  let first = sine_or_build(config, 440.0, 0.8)
  let second = sine_or_build(config, 660.0, 0.35)
  let output = first.copy()
  for index in 0..<output.length() {
    output[index] = output[index] + second[index]
  }
  output
}

///|
fn build_index(
  config : RobustnessConfig,
  track : Array[Double],
) -> @index.FingerprintIndex raise BenchmarkError {
  let hash_config = try @fingerprint.HashConfig::new() catch {
    _ => raise Build("failed to create hash config")
  } noraise {
    value => value
  }
  let index = @index.FingerprintIndex::new(hash_config)
  let fingerprint = fingerprint_from_samples(track, hash_config, config)
  try index.add_track(1, "benchmark-track", fingerprint) catch {
    _ => raise Build("failed to add benchmark track")
  } noraise {
    _ => ()
  }
  index
}

///|
fn fingerprint_from_samples(
  samples : Array[Double],
  hash_config : @fingerprint.HashConfig,
  config : RobustnessConfig,
) -> @fingerprint.AudioFingerprint raise BenchmarkError {
  let buffer = try @audio.audio_buffer(1, config.sample_rate, samples) catch {
    _ => raise Build("failed to create audio buffer")
  } noraise {
    value => value
  }
  let spectrum_config = try
    @spectrum.SpectrumConfig::new(
      window_length=config.window_length,
      hop_size=config.hop_size,
    )
  catch {
    _ => raise Build("failed to create spectrum config")
  } noraise {
    value => value
  }
  let spectrogram = try @spectrum.spectrogram(buffer, spectrum_config) catch {
    _ => raise Build("failed to compute spectrogram")
  } noraise {
    value => value
  }
  let peak_config = try
    @spectrum.PeakConfig::new(
      frequency_radius=2,
      time_radius=0,
      min_magnitude=0.05,
      max_peaks_per_frame=4,
    )
  catch {
    _ => raise Build("failed to create peak config")
  } noraise {
    value => value
  }
  let peaks = try @spectrum.extract_peaks(spectrogram, peak_config) catch {
    _ => raise Build("failed to extract peaks")
  } noraise {
    value => value
  }
  try
    @fingerprint.fingerprint(
      peaks,
      hash_config,
      frame_count=spectrogram.magnitudes.length(),
      bin_count=spectrogram.frequencies.length(),
    )
  catch {
    _ => raise Build("failed to create fingerprint")
  } noraise {
    value => value
  }
}

///|
fn match_case(
  index : @index.FingerprintIndex,
  name : String,
  samples : Array[Double],
  expected_offset_frames : Int,
  config : RobustnessConfig,
) -> RobustnessCase raise BenchmarkError {
  let query = fingerprint_from_samples(samples, index.config, config)
  let match_config = try
    @match.MatchConfig::new(
      top_k=5,
      min_votes=1,
      min_confidence=0.0,
      min_margin=0.0,
    )
  catch {
    _ => raise Build("failed to create match config")
  } noraise {
    value => value
  }
  let result = try @match.match_fingerprint(index, query, match_config) catch {
    _ => raise Build("failed to run benchmark match")
  } noraise {
    value => value
  }
  let top1_hit = if result.candidates.length() == 0 {
    false
  } else {
    result.candidates[0].track_id == 1
  }
  let actual = if top1_hit { result.candidates[0].offset_frames } else { 0 }
  let offset_error = if top1_hit {
    abs_int(actual - expected_offset_frames)
  } else {
    0
  }
  {
    name,
    top1_hit,
    strong: result.status is Strong,
    expected_offset_frames,
    actual_offset_frames: actual,
    offset_error_frames: offset_error,
  }
}

///|
fn summarize(
  cases : Array[RobustnessCase],
  hash_count : Int,
  posting_count : Int,
  snapshot_bytes : Int,
) -> BenchmarkReport {
  let mut correct_hits = 0
  let mut positive_cases = 0
  let mut negative_cases = 0
  let mut negative_hits = 0
  let mut offset_error_sum = 0
  let mut offset_error_count = 0
  let mut max_offset_error = 0
  for case in cases {
    if case.name == "unrelated" {
      negative_cases = negative_cases + 1
      if case.top1_hit {
        negative_hits = negative_hits + 1
      }
    } else {
      positive_cases = positive_cases + 1
      if case.top1_hit {
        correct_hits = correct_hits + 1
      }
      offset_error_sum = offset_error_sum + case.offset_error_frames
      offset_error_count = offset_error_count + 1
      if case.offset_error_frames > max_offset_error {
        max_offset_error = case.offset_error_frames
      }
    }
  }
  let mean_offset_error = if offset_error_count == 0 {
    0.0
  } else {
    offset_error_sum.to_double() / offset_error_count.to_double()
  }
  {
    cases,
    correct_hits,
    positive_cases,
    negative_cases,
    negative_hits,
    mean_offset_error_frames: mean_offset_error,
    max_offset_error_frames: max_offset_error,
    hash_count,
    posting_count,
    snapshot_bytes,
    query_median_us: 0.0,
  }
}

///|
fn slice_samples(
  samples : Array[Double],
  start : Int,
  count : Int,
) -> Array[Double] {
  let output : Array[Double] = []
  let end = if start + count < samples.length() {
    start + count
  } else {
    samples.length()
  }
  for index in start..<end {
    output.push(samples[index])
  }
  output
}

///|
fn pad_silence(samples : Array[Double], padding : Int) -> Array[Double] {
  let output = Array::make(padding, 0.0)
  for sample in samples {
    output.push(sample)
  }
  for _ in 0..<padding {
    output.push(0.0)
  }
  output
}

///|
fn apply_gain(samples : Array[Double], gain : Double) -> Array[Double] {
  Array::makei(samples.length(), index => samples[index] * gain)
}

///|
fn add_noise(samples : Array[Double], amplitude : Double) -> Array[Double] {
  let noise = try
    @mspectrum.white_noise(length=samples.length(), seed=7U, amplitude~)
  catch {
    _ => []
  } noraise {
    value => value
  }
  let output = samples.copy()
  for index in 0..<output.length() {
    output[index] = output[index] + noise[index]
  }
  output
}

///|
fn different_signal(length : Int, sample_rate : Int) -> Array[Double] {
  try! @mspectrum.sine_wave(
    length~,
    sample_rate=sample_rate.to_double(),
    frequency=880.0,
    amplitude=0.8,
  )
}

///|
fn sine_or_build(
  config : RobustnessConfig,
  frequency : Double,
  amplitude : Double,
) -> Array[Double] raise BenchmarkError {
  try
    @mspectrum.sine_wave(
      length=config.track_frames,
      sample_rate=config.sample_rate.to_double(),
      frequency~,
      amplitude~,
    )
  catch {
    _ => raise Build("failed to synthesize sine wave")
  } noraise {
    value => value
  }
}

///|
fn count_hashes(index : @index.FingerprintIndex) -> Int {
  let mut total = 0
  for hash in index.postings.keys() {
    ignore(hash)
    match index.postings.get(hash) {
      Some(postings) => total = total + postings.length()
      None => ()
    }
  }
  total
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}
