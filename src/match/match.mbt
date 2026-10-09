///|
pub(all) struct MatchConfig {
  top_k : Int
  min_votes : Int
  min_confidence : Double
  min_margin : Double
}

///|
pub(all) struct MatchCandidate {
  track_id : Int
  name : String
  offset_frames : Int
  votes : Int
  confidence : Double
  margin : Double
}

///|
pub(all) enum MatchStatus {
  Strong
  Weak
  NoMatch
}

///|
pub(all) struct MatchResult {
  status : MatchStatus
  candidates : Array[MatchCandidate]
  query_hash_count : Int
  considered_postings : Int
}

///|
pub suberror MatchError {
  InvalidArgument(String)
}

///|
pub fn error_message(error : MatchError) -> String {
  match error {
    InvalidArgument(message) => message
  }
}

///|
pub fn status_label(status : MatchStatus) -> String {
  match status {
    Strong => "strong"
    Weak => "weak"
    NoMatch => "no-match"
  }
}

///|
pub fn MatchConfig::new(
  top_k? : Int = 5,
  min_votes? : Int = 3,
  min_confidence? : Double = 0.05,
  min_margin? : Double = 0.0,
) -> MatchConfig raise MatchError {
  if top_k <= 0 {
    raise InvalidArgument("top_k must be positive")
  }
  if min_votes <= 0 {
    raise InvalidArgument("min_votes must be positive")
  }
  if min_confidence < 0.0 || min_confidence > 1.0 {
    raise InvalidArgument("min_confidence must be in 0..1")
  }
  if min_margin < 0.0 || min_margin > 1.0 {
    raise InvalidArgument("min_margin must be in 0..1")
  }
  { top_k, min_votes, min_confidence, min_margin, }
}

///|
pub fn match_fingerprint(
  index : @index.FingerprintIndex,
  query : @fingerprint.AudioFingerprint,
  config : MatchConfig,
) -> MatchResult raise MatchError {
  if !hash_config_equal(index.config, query.config) {
    raise InvalidArgument(
      "query fingerprint config does not match index config",
    )
  }
  let query_hash_count = query.hashes.length()
  if query_hash_count == 0 {
    return {
      status: NoMatch,
      candidates: [],
      query_hash_count,
      considered_postings: 0,
    }
  }
  let votes : Map[(Int, Int), Int] = Map([])
  let mut considered_postings = 0
  for item in query.hashes {
    let postings = index.lookup(item.hash)
    considered_postings = considered_postings + postings.length()
    for posting in postings {
      let offset = posting.anchor_frame - item.anchor_frame
      let key = (posting.track_id, offset)
      let next = match votes.get(key) {
        Some(count) => count + 1
        None => 1
      }
      votes.set(key, next)
    }
  }
  let best_by_track : Map[Int, (Int, Int)] = Map([])
  for entry in votes.iter() {
    let key = entry.0
    let vote_count = entry.1
    let track_id = key.0
    let offset = key.1
    let replace = match best_by_track.get(track_id) {
      Some(best) => vote_count > best.1
      None => true
    }
    if replace {
      best_by_track.set(track_id, (offset, vote_count))
    }
  }
  let ranked : Array[(Int, Int, Int)] = []
  for entry in best_by_track.iter() {
    ranked.push((entry.0, entry.1.0, entry.1.1))
  }
  ranked.sort_by(compare_ranked)
  let limit = if ranked.length() < config.top_k {
    ranked.length()
  } else {
    config.top_k
  }
  let candidates : Array[MatchCandidate] = []
  for candidate_index in 0..<limit {
    let track_id = ranked[candidate_index].0
    let offset = ranked[candidate_index].1
    let vote_count = ranked[candidate_index].2
    let next_votes = if candidate_index + 1 < ranked.length() {
      ranked[candidate_index + 1].2
    } else {
      0
    }
    let confidence = vote_count.to_double() / query_hash_count.to_double()
    let margin = (vote_count - next_votes).to_double() / vote_count.to_double()
    candidates.push({
      track_id,
      name: track_name(index, track_id),
      offset_frames: offset,
      votes: vote_count,
      confidence,
      margin,
    })
  }
  let status = if candidates.length() == 0 {
    NoMatch
  } else {
    let best = candidates[0]
    if best.votes < config.min_votes ||
      best.confidence < config.min_confidence ||
      best.margin < config.min_margin {
      Weak
    } else {
      Strong
    }
  }
  { status, candidates, query_hash_count, considered_postings, }
}

///|
fn compare_ranked(left : (Int, Int, Int), right : (Int, Int, Int)) -> Int {
  if left.2 != right.2 {
    right.2 - left.2
  } else {
    left.0 - right.0
  }
}

///|
fn hash_config_equal(
  left : @fingerprint.HashConfig,
  right : @fingerprint.HashConfig,
) -> Bool {
  left.fan_out == right.fan_out &&
  left.min_delta_frames == right.min_delta_frames &&
  left.max_delta_frames == right.max_delta_frames &&
  left.max_frequency_distance == right.max_frequency_distance &&
  left.hash_seed == right.hash_seed
}

///|
fn track_name(index : @index.FingerprintIndex, track_id : Int) -> String {
  for track in index.tracks {
    if track.track_id == track_id {
      return track.name
    }
  }
  ""
}
