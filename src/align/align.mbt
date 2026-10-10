///|
pub(all) struct AlignConfig {
  search_radius_samples : Int
  window_samples : Int
}

///|
pub(all) struct AlignmentResult {
  rough_offset_samples : Int
  refined_offset_samples : Int
  correlation : Double
  evaluated_lags : Int
}

///|
pub suberror AlignError {
  InvalidArgument(String)
}

///|
pub fn error_message(error : AlignError) -> String {
  match error {
    InvalidArgument(message) => message
  }
}

///|
pub fn AlignConfig::new(
  search_radius_samples? : Int = 512,
  window_samples? : Int = 4096,
) -> AlignConfig raise AlignError {
  if search_radius_samples < 0 {
    raise InvalidArgument("search_radius_samples must be non-negative")
  }
  if window_samples <= 0 {
    raise InvalidArgument("window_samples must be positive")
  }
  { search_radius_samples, window_samples, }
}

///|
pub fn refine_offset(
  track : ArrayView[Double],
  query : ArrayView[Double],
  rough_offset_samples : Int,
  config : AlignConfig,
) -> AlignmentResult raise AlignError {
  if track.length() == 0 || query.length() == 0 {
    raise InvalidArgument("track and query must be non-empty")
  }
  let start = rough_offset_samples - config.search_radius_samples
  let end = rough_offset_samples + config.search_radius_samples
  let mut best_lag = rough_offset_samples
  let mut best_score = -2.0
  let mut best_distance = 0
  let mut evaluated = 0
  for lag in start..<=end {
    let overlap = overlap_length(
      track.length(),
      query.length(),
      lag,
      config.window_samples,
    )
    if overlap <= 0 {
      continue
    }
    let score = correlation_at(track, query, lag, overlap)
    let distance = abs_int(lag - rough_offset_samples)
    let base_offset = offset_for_lag(track.length(), query.length(), lag)
    if score > best_score || (score == best_score && distance < best_distance) {
      best_lag = lag
      best_score = score
      best_distance = distance
      if base_offset < 0 {
        best_lag = lag
      }
    }
    evaluated = evaluated + 1
  }
  if evaluated == 0 {
    raise InvalidArgument("no overlapping alignment window")
  }
  {
    rough_offset_samples,
    refined_offset_samples: best_lag,
    correlation: best_score,
    evaluated_lags: evaluated,
  }
}

///|
fn correlation_at(
  track : ArrayView[Double],
  query : ArrayView[Double],
  lag : Int,
  overlap : Int,
) -> Double {
  let mut sum_track = 0.0
  let mut sum_query = 0.0
  for index in 0..<overlap {
    sum_track = sum_track + track_value(track, query, lag, index)
    sum_query = sum_query + query_value(track, query, lag, index)
  }
  let mean_track = sum_track / overlap.to_double()
  let mean_query = sum_query / overlap.to_double()
  let mut covariance = 0.0
  let mut variance_track = 0.0
  let mut variance_query = 0.0
  for index in 0..<overlap {
    let track_sample = track_value(track, query, lag, index) - mean_track
    let query_sample = query_value(track, query, lag, index) - mean_query
    covariance = covariance + track_sample * query_sample
    variance_track = variance_track + track_sample * track_sample
    variance_query = variance_query + query_sample * query_sample
  }
  let denominator = (variance_track * variance_query).sqrt()
  if denominator == 0.0 {
    0.0
  } else {
    covariance / denominator
  }
}

///|
fn track_value(
  track : ArrayView[Double],
  query : ArrayView[Double],
  lag : Int,
  index : Int,
) -> Double {
  ignore(query)
  if lag >= 0 {
    track[lag + index]
  } else {
    track[index]
  }
}

///|
fn query_value(
  track : ArrayView[Double],
  query : ArrayView[Double],
  lag : Int,
  index : Int,
) -> Double {
  ignore(track)
  if lag >= 0 {
    query[index]
  } else {
    query[-lag + index]
  }
}

///|
fn overlap_length(
  track_length : Int,
  query_length : Int,
  lag : Int,
  window_samples : Int,
) -> Int {
  let available = if lag >= 0 {
    let track_available = track_length - lag
    let query_available = query_length
    if track_available < query_available {
      track_available
    } else {
      query_available
    }
  } else {
    let track_available = track_length
    let query_available = query_length + lag
    if track_available < query_available {
      track_available
    } else {
      query_available
    }
  }
  if available < window_samples {
    available
  } else {
    window_samples
  }
}

///|
fn offset_for_lag(track_length : Int, query_length : Int, lag : Int) -> Int {
  ignore(track_length)
  ignore(query_length)
  lag
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}
