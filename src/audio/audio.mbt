///|
/// MoonEcho's normalized audio buffer.
///
/// The concrete representation is provided by MoonWavKit's `FloatBuffer` so
/// that WAV parsing and PCM conversion stay in a dedicated dependency.
pub type AudioBuffer = @wav.FloatBuffer

///|
/// Errors raised by MoonEcho's audio adapter.
pub suberror AudioError {
  Decode(@wav.WavError)
  InvalidArgument(String)
}

///|
/// Format a stable message for CLI and test diagnostics.
pub fn error_message(error : AudioError) -> String {
  match error {
    Decode(err) => "\{err.code()}: \{err.message}"
    InvalidArgument(message) => message
  }
}

///|
/// Decode a RIFF/WAVE byte buffer into normalized interleaved samples.
pub fn load_wav(bytes : Array[Int]) -> AudioBuffer raise AudioError {
  let decoded = @wav.parse_and_decode(bytes)
  if decoded.ok {
    decoded.float_buffer
  } else {
    raise Decode(decoded.error)
  }
}

///|
/// Decode WAV bytes, downmix to mono, and resample to the configured rate.
pub fn load_wav_mono(
  bytes : Array[Int],
  target_sample_rate? : Int = 16000,
) -> AudioBuffer raise AudioError {
  let decoded = load_wav(bytes)
  let mono = downmix(decoded)
  resample(mono, target_sample_rate)
}

///|
/// Number of channels in a normalized buffer.
pub fn channels(buffer : AudioBuffer) -> Int {
  buffer.channels
}

///|
/// Sample rate in Hz.
pub fn sample_rate(buffer : AudioBuffer) -> Int {
  buffer.sample_rate
}

///|
/// Number of interleaved frames.
pub fn frame_count(buffer : AudioBuffer) -> Int {
  buffer.frame_count()
}

///|
/// Duration in seconds.
pub fn duration_seconds(buffer : AudioBuffer) -> Double {
  buffer.duration_seconds()
}

///|
/// Return a defensive validation result for the adapter boundary.
pub fn validate(buffer : AudioBuffer) -> Bool {
  buffer.is_valid()
}

///|
/// Downmix all channels to mono.
pub fn downmix(buffer : AudioBuffer) -> AudioBuffer raise AudioError {
  if !buffer.is_valid() {
    raise InvalidArgument("cannot downmix an invalid audio buffer")
  }
  @wav.downmix_to_mono(buffer)
}

///|
/// Apply a constant gain.
pub fn apply_gain(
  buffer : AudioBuffer,
  gain : Double,
) -> AudioBuffer raise AudioError {
  if !buffer.is_valid() {
    raise InvalidArgument("cannot apply gain to an invalid audio buffer")
  }
  if gain < 0.0 {
    raise InvalidArgument("gain must be non-negative")
  }
  @wav.apply_gain(buffer, gain)
}

///|
/// Normalize the buffer peak to the default MoonWavKit target.
pub fn normalize(buffer : AudioBuffer) -> AudioBuffer raise AudioError {
  let report = @wav.normalize_peak(buffer)
  if report.ok {
    report.buffer
  } else {
    raise Decode(report.error)
  }
}

///|
/// Resample a buffer with linear interpolation.
pub fn resample(
  buffer : AudioBuffer,
  target_sample_rate : Int,
) -> AudioBuffer raise AudioError {
  let result = @wav.resample_linear(buffer, target_sample_rate)
  if result.ok {
    result.buffer
  } else {
    raise Decode(result.error)
  }
}
