///|
fn main {
  let signal = try! @mspectrum.sine_wave(
    length=1024,
    sample_rate=8000.0,
    frequency=440.0,
  )
  let peak = try! @analysis.dominant_peak(signal[:], 8000.0)
  let buffer = try! @audio.audio_buffer(1, 8000, signal)
  let spectrum_config = try! @analysis.SpectrumConfig::new(
    window_length=256,
    hop_size=128,
    window_kind=@mspectrum.Hann,
  )
  let spectrogram = try! @analysis.spectrogram(buffer, spectrum_config)
  let peak_config = try! @analysis.PeakConfig::new(
    frequency_radius=2,
    time_radius=0,
    min_magnitude=0.1,
    max_peaks_per_frame=2,
  )
  let peaks = try! @analysis.extract_peaks(spectrogram, peak_config)
  println("Spectrum example")
  println("dominant_frequency_hz: \{peak.frequency}")
  println("dominant_bin: \{peak.index}")
  println("selected_peak_count: \{peaks.length()}")
}
