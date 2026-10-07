///|
test "FFT finds the synthetic sine peak" {
  let signal = try! @mspectrum.sine_wave(
    length=8,
    sample_rate=8.0,
    frequency=2.0,
  )
  let peak = try! @spectrum.dominant_peak(signal[:], 8.0)
  assert_eq(peak.index, 2)
  assert_true((peak.frequency - 2.0).abs() < 0.0001)
}

///|
test "spectrogram adapter computes stable frame shape" {
  let samples = try! @mspectrum.sine_wave(
    length=32,
    sample_rate=16.0,
    frequency=4.0,
  )
  let buffer = try! @audio.audio_buffer(1, 16, samples)
  let config = try! @spectrum.SpectrumConfig::new(
    window_length=16,
    hop_size=8,
    window_kind=@mspectrum.Hann,
  )
  let result = try! @spectrum.spectrogram(buffer, config)
  assert_eq(result.frequencies.length(), 9)
  assert_eq(result.magnitudes.length(), 3)
  assert_eq(result.magnitudes[0].length(), 9)
}

///|
test "spectrum adapter rejects stereo input" {
  let buffer = try! @audio.audio_buffer(2, 8000, [0.0, 0.0, 0.0, 0.0])
  let config = try! @spectrum.SpectrumConfig::new(window_length=4, hop_size=2)
  try @spectrum.spectrogram(buffer, config) catch {
    InvalidArgument(_) => ()
    Analysis(_) => fail("expected an adapter argument error")
  } noraise {
    _ => fail("expected stereo input to be rejected")
  }
}
