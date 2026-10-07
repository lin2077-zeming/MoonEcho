///|
fn main {
  let audio = try! @audio.load_wav_mono(
    @wav.fixture_pcm8_stereo(),
    target_sample_rate=16000,
  )
  println("WAV adapter example")
  println("channels: \{@audio.channels(audio)}")
  println("sample_rate: \{@audio.sample_rate(audio)}")
  println("frames: \{@audio.frame_count(audio)}")
}
