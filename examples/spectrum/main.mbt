///|
fn main {
  let signal = try! @mspectrum.sine_wave(
    length=1024,
    sample_rate=8000.0,
    frequency=440.0,
  )
  let peak = try! @analysis.dominant_peak(signal[:], 8000.0)
  println("Spectrum example")
  println("dominant_frequency_hz: \{peak.frequency}")
  println("dominant_bin: \{peak.index}")
}
