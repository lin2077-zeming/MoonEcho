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

///|
test "extract peaks from a synthetic spectrogram" {
  let result : @mspectrum.SpectrogramResult = {
    frequencies: [0.0, 1.0, 2.0, 3.0, 4.0],
    frame_times: [0.0, 0.25, 0.5],
    magnitudes: [
      [0.0, 1.0, 0.1, 0.0, 0.0],
      [0.0, 0.1, 1.2, 0.1, 0.0],
      [0.0, 0.0, 0.2, 0.8, 0.0],
    ],
  }
  let config = try! @spectrum.PeakConfig::new(
    frequency_radius=1,
    time_radius=0,
    min_magnitude=0.5,
    max_peaks_per_frame=1,
  )
  let peaks = try! @spectrum.extract_peaks(result, config)
  assert_eq(peaks.length(), 3)
  assert_eq(peaks[0].frame, 0)
  assert_eq(peaks[0].bin, 1)
  assert_eq(peaks[1].frame, 1)
  assert_eq(peaks[1].bin, 2)
  assert_eq(peaks[2].frame, 2)
  assert_eq(peaks[2].bin, 3)
}

///|
test "extract peaks from a synthetic sine spectrogram" {
  let samples = try! @mspectrum.sine_wave(
    length=32,
    sample_rate=16.0,
    frequency=4.0,
  )
  let buffer = try! @audio.audio_buffer(1, 16, samples)
  let spectrum_config = try! @spectrum.SpectrumConfig::new(
    window_length=16,
    hop_size=8,
    window_kind=@mspectrum.Hann,
  )
  let result = try! @spectrum.spectrogram(buffer, spectrum_config)
  let peak_config = try! @spectrum.PeakConfig::new(
    frequency_radius=1,
    time_radius=0,
    min_magnitude=0.1,
    max_peaks_per_frame=2,
  )
  let peaks = try! @spectrum.extract_peaks(result, peak_config)
  assert_true(peaks.length() > 0)
  assert_true((peaks[0].frequency - 4.0).abs() < 0.0001)
}
