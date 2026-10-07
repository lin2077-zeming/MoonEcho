///|
test "load PCM16 mono fixture" {
  let buffer = try! @audio.load_wav(@wav.fixture_pcm16_mono())
  assert_eq(@audio.channels(buffer), 1)
  assert_eq(@audio.sample_rate(buffer), 8000)
  assert_eq(@audio.frame_count(buffer), 4)
  assert_eq(buffer.samples[0], 0.0)
  assert_eq(buffer.samples[2], -1.0)
  assert_eq(buffer.samples[3], 0.5)
}

///|
test "downmix stereo fixture to mono" {
  let buffer = try! @audio.load_wav(@wav.fixture_pcm8_stereo())
  let mono = try! @audio.downmix(buffer)
  assert_eq(@audio.channels(mono), 1)
  assert_eq(@audio.frame_count(mono), 4)
  assert_eq(mono.samples[0], 0.0)
  assert_eq(mono.samples[2], 0.0)
}

///|
test "load WAV as mono at target sample rate" {
  let buffer = try! @audio.load_wav_mono(
    @wav.fixture_pcm16_mono(),
    target_sample_rate=16000,
  )
  assert_eq(@audio.channels(buffer), 1)
  assert_eq(@audio.sample_rate(buffer), 16000)
  assert_eq(@audio.frame_count(buffer), 8)
}

///|
test "reject invalid audio input" {
  try @audio.load_wav(@wav.fixture_not_riff()) catch {
    Decode(_) => ()
    InvalidArgument(_) => fail("expected a decode error")
  } noraise {
    _ => fail("expected invalid WAV input to fail")
  }
}
