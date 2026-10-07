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
