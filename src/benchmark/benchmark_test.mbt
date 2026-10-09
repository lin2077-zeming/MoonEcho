///|
test "robustness suite has no negative hits" {
  let config = try! @benchmark.RobustnessConfig::new(
    sample_rate=8000,
    window_length=128,
    hop_size=64,
    track_frames=4096,
    clip_start=1024,
    clip_frames=2048,
    silence_padding=64,
    noise_amplitude=0.03,
  )
  let report = try! @benchmark.robustness_report(config)
  assert_eq(report.correct_hits, report.positive_cases)
  assert_eq(report.negative_hits, 0)
  assert_true(report.mean_offset_error_frames <= 1.0)
  assert_true(report.hash_count > 0)
  assert_true(report.snapshot_bytes > 0)
}
