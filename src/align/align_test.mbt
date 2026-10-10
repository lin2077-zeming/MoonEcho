///|
fn synthetic_track(length : Int) -> Array[Double] {
  Array::makei(length, index => {
    let a = ((index * 37 + 11) % 101).to_double() - 50.0
    let b = ((index * 17 + 5) % 43).to_double() - 21.0
    a + b * 0.5
  })
}

///|
fn slice(samples : Array[Double], start : Int, count : Int) -> Array[Double] {
  let output : Array[Double] = []
  let end = start + count
  for index in start..<end {
    output.push(samples[index])
  }
  output
}

///|
test "refine offset recovers exact known lag" {
  let track = synthetic_track(512)
  let query = slice(track, 123, 64)
  let result = try! @align.refine_offset(
    track[:],
    query[:],
    120,
    @align.AlignConfig::new(search_radius_samples=8, window_samples=64),
  )
  assert_eq(result.refined_offset_samples, 123)
  assert_true(result.correlation > 0.99)
}

///|
test "refine offset tolerates gain and deterministic noise" {
  let track = synthetic_track(512)
  let query = slice(track, 200, 96)
  for index in 0..<query.length() {
    query[index] = query[index] * 0.5 +
      ((index * 29 % 7).to_double() - 3.0) * 0.01
  }
  let result = try! @align.refine_offset(
    track[:],
    query[:],
    193,
    @align.AlignConfig::new(search_radius_samples=16, window_samples=96),
  )
  assert_true((result.refined_offset_samples - 200).abs() <= 1)
}

///|
test "refine offset rejects invalid config" {
  try @align.AlignConfig::new(search_radius_samples=-1) catch {
    InvalidArgument(_) => ()
  } noraise {
    _ => fail("expected invalid align config")
  }
}
