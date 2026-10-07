///|
/// Public window type re-exported from MoonSpectrum.
pub type WindowKind = @mspectrum.WindowKind

///|
/// Public spectrogram result re-exported from MoonSpectrum.
pub type Spectrogram = @mspectrum.SpectrogramResult

///|
/// Public FFT peak result re-exported from MoonSpectrum.
pub type Peak = @mspectrum.Peak

///|
/// A selected time-frequency peak from a spectrogram.
pub(all) struct SpectralPeak {
  frame : Int
  bin : Int
  time : Double
  frequency : Double
  magnitude : Double
}

///|
/// Configuration for two-dimensional spectrogram peak extraction.
pub(all) struct PeakConfig {
  frequency_radius : Int
  time_radius : Int
  min_magnitude : Double
  relative_threshold : Double
  max_peaks_per_frame : Int
}

///|
/// Errors raised by MoonEcho's spectrum adapter.
pub suberror SpectrumError {
  Analysis(@mspectrum.SpectrumError)
  InvalidArgument(String)
}

///|
/// Format a stable message for CLI and test diagnostics.
pub fn error_message(error : SpectrumError) -> String {
  match error {
    Analysis(err) =>
      match err {
        EmptySignal => "empty signal"
        LengthMismatch => "length mismatch"
        NonPowerOfTwo(length~) => "non-power-of-two length: \{length}"
        InvalidArgument(message~) => message
      }
    InvalidArgument(message) => message
  }
}

///|
/// Build a validated peak extraction configuration.
pub fn PeakConfig::new(
  frequency_radius? : Int = 2,
  time_radius? : Int = 0,
  min_magnitude? : Double = 0.05,
  relative_threshold? : Double = 0.0,
  max_peaks_per_frame? : Int = 4,
) -> PeakConfig raise SpectrumError {
  if frequency_radius < 0 {
    raise InvalidArgument("frequency_radius must be non-negative")
  }
  if time_radius < 0 {
    raise InvalidArgument("time_radius must be non-negative")
  }
  if min_magnitude < 0.0 {
    raise InvalidArgument("min_magnitude must be non-negative")
  }
  if relative_threshold < 0.0 || relative_threshold > 1.0 {
    raise InvalidArgument("relative_threshold must be in 0..1")
  }
  if max_peaks_per_frame <= 0 {
    raise InvalidArgument("max_peaks_per_frame must be positive")
  }
  {
    frequency_radius,
    time_radius,
    min_magnitude,
    relative_threshold,
    max_peaks_per_frame,
  }
}

///|
/// Configuration for STFT and spectrogram computation.
pub(all) struct SpectrumConfig {
  window_length : Int
  hop_size : Int
  window_kind : WindowKind
}

///|
/// Build a validated spectrum configuration.
pub fn SpectrumConfig::new(
  window_length? : Int = 1024,
  hop_size? : Int = 512,
  window_kind? : WindowKind = @mspectrum.Hann,
) -> SpectrumConfig raise SpectrumError {
  if window_length <= 0 {
    raise InvalidArgument("window_length must be positive")
  }
  if hop_size <= 0 {
    raise InvalidArgument("hop_size must be positive")
  }
  if hop_size > window_length {
    raise InvalidArgument("hop_size must not exceed window_length")
  }
  { window_length, hop_size, window_kind, }
}

///|
/// Compute FFT magnitudes for a mono signal.
pub fn fft_magnitudes(
  samples : ArrayView[Double],
) -> Array[Double] raise SpectrumError {
  @mspectrum.magnitude_spectrum(@mspectrum.fft(@mspectrum.real_signal(samples))) catch {
    err => raise Analysis(err)
  }
}

///|
/// Find the dominant frequency in a mono signal.
pub fn dominant_peak(
  samples : ArrayView[Double],
  sample_rate : Double,
) -> Peak raise SpectrumError {
  if sample_rate <= 0.0 {
    raise InvalidArgument("sample_rate must be positive")
  }
  try {
    let spectrum = @mspectrum.fft(@mspectrum.real_signal(samples))
    @mspectrum.dominant_peak(spectrum, sample_rate)
  } catch {
    err => raise Analysis(err)
  }
}

///|
/// Compute a mono spectrogram from a MoonEcho audio buffer.
pub fn spectrogram(
  buffer : @audio.AudioBuffer,
  config : SpectrumConfig,
) -> Spectrogram raise SpectrumError {
  if !buffer.is_valid() {
    raise InvalidArgument("cannot analyze an invalid audio buffer")
  }
  if buffer.channels != 1 {
    raise InvalidArgument(
      "spectrogram expects mono audio; call audio.downmix first",
    )
  }
  @mspectrum.spectrogram(
    buffer.samples[:],
    config.window_kind,
    window_length=config.window_length,
    hop_size=config.hop_size,
    sample_rate=buffer.sample_rate.to_double(),
  ) catch {
    err => raise Analysis(err)
  }
}

///|
/// Extract deterministic local maxima from a spectrogram.
///
/// Candidates are selected with a two-dimensional time-frequency neighborhood,
/// then limited to `max_peaks_per_frame` entries per frame.
pub fn extract_peaks(
  result : Spectrogram,
  config : PeakConfig,
) -> Array[SpectralPeak] raise SpectrumError {
  let frame_count = result.magnitudes.length()
  let bin_count = result.frequencies.length()
  if frame_count == 0 || bin_count == 0 {
    raise InvalidArgument("spectrogram must contain at least one frame and bin")
  }
  if result.frame_times.length() != frame_count {
    raise InvalidArgument("spectrogram frame count does not match frame times")
  }
  let mut max_magnitude = 0.0
  for frame in 0..<frame_count {
    if result.magnitudes[frame].length() != bin_count {
      raise InvalidArgument(
        "spectrogram frame width does not match frequency bins",
      )
    }
    for bin in 0..<bin_count {
      let value = result.magnitudes[frame][bin]
      if value > max_magnitude {
        max_magnitude = value
      }
    }
  }
  let absolute_floor = if max_magnitude == 0.0 {
    config.min_magnitude
  } else {
    let relative_floor = max_magnitude * config.relative_threshold
    if relative_floor > config.min_magnitude {
      relative_floor
    } else {
      config.min_magnitude
    }
  }
  let selected : Array[SpectralPeak] = []
  for frame in 0..<frame_count {
    let row = result.magnitudes[frame]
    let frame_candidates : Array[SpectralPeak] = []
    for bin in 0..<bin_count {
      let value = row[bin]
      if value <= absolute_floor {
        continue
      }
      let frame_start = if frame > config.time_radius {
        frame - config.time_radius
      } else {
        0
      }
      let frame_end = if frame + config.time_radius < frame_count {
        frame + config.time_radius
      } else {
        frame_count - 1
      }
      let bin_start = if bin > config.frequency_radius {
        bin - config.frequency_radius
      } else {
        0
      }
      let bin_end = if bin + config.frequency_radius < bin_count {
        bin + config.frequency_radius
      } else {
        bin_count - 1
      }
      let mut is_local_max = true
      for neighbor_frame in frame_start..<=frame_end {
        for neighbor_bin in bin_start..<=bin_end {
          if neighbor_frame == frame && neighbor_bin == bin {
            continue
          }
          if result.magnitudes[neighbor_frame][neighbor_bin] >= value {
            is_local_max = false
          }
        }
      }
      if is_local_max {
        frame_candidates.push({
          frame,
          bin,
          time: result.frame_times[frame],
          frequency: result.frequencies[bin],
          magnitude: value,
        })
      }
    }
    let ranked = sort_peaks_descending(frame_candidates)
    let limit = if ranked.length() < config.max_peaks_per_frame {
      ranked.length()
    } else {
      config.max_peaks_per_frame
    }
    for index in 0..<limit {
      selected.push(ranked[index])
    }
  }
  selected
}

///|
fn sort_peaks_descending(peaks : Array[SpectralPeak]) -> Array[SpectralPeak] {
  let sorted = peaks.copy()
  for index in 1..<sorted.length() {
    let current = sorted[index]
    let mut cursor = index
    while cursor > 0 && should_precede(current, sorted[cursor - 1]) {
      sorted[cursor] = sorted[cursor - 1]
      cursor = cursor - 1
    }
    sorted[cursor] = current
  }
  sorted
}

///|
fn should_precede(left : SpectralPeak, right : SpectralPeak) -> Bool {
  if left.magnitude > right.magnitude {
    true
  } else if left.magnitude < right.magnitude {
    false
  } else {
    left.bin < right.bin
  }
}
