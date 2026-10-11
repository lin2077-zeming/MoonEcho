///|
#external
type HostBytes

///|
fn host_bytes_length(bytes : HostBytes) -> Int = "moonecho_host" "bytes_length"

///|
fn host_bytes_get(bytes : HostBytes, index : Int) -> Int = "moonecho_host" "bytes_get"

///|
priv suberror DemoError {
  Audio(@audio.AudioError)
  Spectrum(@spectrum.SpectrumError)
  Fingerprint(@fingerprint.FingerprintError)
}

///|
priv struct DemoState {
  mut index : @index.FingerprintIndex
  mut track_samples : Map[Int, Array[Double]]
  mut last_status : Int
  mut last_track_id : Int
  mut last_offset_frames : Int
  mut last_offset_samples : Int
  mut last_confidence : Double
  mut last_correlation : Double
  mut last_votes : Int
  mut last_query_hashes : Int
  mut last_considered_postings : Int
  mut last_candidate_count : Int
  mut last_error : Int
}

///|
fn web_hash_config() -> @fingerprint.HashConfig {
  {
    fan_out: 5,
    min_delta_frames: 1,
    max_delta_frames: 64,
    max_frequency_distance: 32,
    hash_seed: 0x9E3779B97F4A7C15UL,
  }
}

///|
fn new_web_index() -> @index.FingerprintIndex {
  @index.with_profile(@index.default_profile(web_hash_config()))
}

///|
let web_state : DemoState = {
  index: new_web_index(),
  track_samples: Map([]),
  last_status: 0,
  last_track_id: 0,
  last_offset_frames: 0,
  last_offset_samples: 0,
  last_confidence: 0.0,
  last_correlation: 0.0,
  last_votes: 0,
  last_query_hashes: 0,
  last_considered_postings: 0,
  last_candidate_count: 0,
  last_error: 0,
}

///|
fn reset_web_state() -> Unit {
  web_state.index = new_web_index()
  web_state.track_samples = Map([])
  web_state.last_status = 0
  web_state.last_track_id = 0
  web_state.last_offset_frames = 0
  web_state.last_offset_samples = 0
  web_state.last_confidence = 0.0
  web_state.last_correlation = 0.0
  web_state.last_votes = 0
  web_state.last_query_hashes = 0
  web_state.last_considered_postings = 0
  web_state.last_candidate_count = 0
  web_state.last_error = 0
}

///|
fn host_bytes_array(bytes : HostBytes) -> Array[Int] {
  let output : Array[Int] = []
  let length = host_bytes_length(bytes)
  for index in 0..<length {
    output.push(host_bytes_get(bytes, index))
  }
  output
}

///|
fn fingerprint_for_profile(
  bytes : HostBytes,
  profile : @index.ProcessingProfile,
) -> (@audio.AudioBuffer, @fingerprint.AudioFingerprint) raise DemoError {
  let normalized = host_bytes_array(bytes)
  let audio = try
    @audio.load_wav_mono(normalized, target_sample_rate=profile.sample_rate)
  catch {
    err => raise Audio(err)
  } noraise {
    value => value
  }
  let config = try
    @spectrum.SpectrumConfig::new(
      window_length=profile.window_length,
      hop_size=profile.hop_size,
    )
  catch {
    err => raise Spectrum(err)
  } noraise {
    value => value
  }
  let spectrogram = try @spectrum.spectrogram(audio, config) catch {
    err => raise Spectrum(err)
  } noraise {
    value => value
  }
  let peaks = try
    @spectrum.extract_peaks(spectrogram, profile.peak_config)
  catch {
    err => raise Spectrum(err)
  } noraise {
    value => value
  }
  let fingerprint = try
    @fingerprint.fingerprint(
      peaks,
      profile.hash_config,
      frame_count=spectrogram.magnitudes.length(),
      bin_count=spectrogram.frequencies.length(),
    )
  catch {
    err => raise Fingerprint(err)
  } noraise {
    value => value
  }
  (audio, fingerprint)
}

///|
fn status_code(status : @match.MatchStatus) -> Int {
  match status {
    Strong => 2
    Weak => 1
    NoMatch => 0
  }
}

///|
#export_name("moonecho_demo_reset")
pub fn demo_reset() -> Int {
  reset_web_state()
  0
}

///|
#export_name("moonecho_demo_index_track")
pub fn demo_index_track(track_id : Int, bytes : HostBytes) -> Int {
  if track_id <= 0 {
    web_state.last_error = 2
    return 1
  }
  let profile = web_state.index.profile
  let (audio, fingerprint) = try fingerprint_for_profile(bytes, profile) catch {
    _ => {
      web_state.last_error = 1
      return 1
    }
  } noraise {
    value => value
  }
  try web_state.index.add_track(track_id, "track", fingerprint) catch {
    DuplicateTrack(_) => {
      web_state.last_error = 3
      return 1
    }
    _ => {
      web_state.last_error = 4
      return 1
    }
  } noraise {
    _ => ()
  }
  web_state.track_samples.set(track_id, audio.samples)
  web_state.last_error = 0
  0
}

///|
#export_name("moonecho_demo_match")
pub fn demo_match(bytes : HostBytes) -> Int {
  if web_state.index.track_count() == 0 {
    web_state.last_error = 5
    return 1
  }
  let profile = web_state.index.profile
  let (audio, query) = try fingerprint_for_profile(bytes, profile) catch {
    _ => {
      web_state.last_error = 1
      return 1
    }
  } noraise {
    value => value
  }
  let config : @match.MatchConfig = {
    top_k: 5,
    min_votes: 3,
    min_confidence: 0.05,
    min_margin: 0.0,
  }
  let result = try
    @match.match_fingerprint(web_state.index, query, config)
  catch {
    err => {
      ignore(err)
      web_state.last_error = 6
      return 1
    }
  } noraise {
    value => value
  }
  web_state.last_status = status_code(result.status)
  web_state.last_query_hashes = result.query_hash_count
  web_state.last_considered_postings = result.considered_postings
  web_state.last_candidate_count = result.candidates.length()
  web_state.last_track_id = 0
  web_state.last_offset_frames = 0
  web_state.last_offset_samples = 0
  web_state.last_confidence = 0.0
  web_state.last_correlation = 0.0
  web_state.last_votes = 0
  if result.candidates.length() > 0 {
    let best = result.candidates[0]
    web_state.last_track_id = best.track_id
    web_state.last_offset_frames = best.offset_frames
    web_state.last_confidence = best.confidence
    web_state.last_votes = best.votes
    let rough_offset_samples = best.offset_frames * profile.hop_size
    match web_state.track_samples.get(best.track_id) {
      Some(track_samples) => {
        let align_config = try
          @align.AlignConfig::new(
            search_radius_samples=profile.hop_size,
            window_samples=4096,
          )
        catch {
          _ => {
            web_state.last_offset_samples = rough_offset_samples
            web_state.last_correlation = 0.0
            web_state.last_error = 0
            return 0
          }
        } noraise {
          value => value
        }
        let alignment = try
          @align.refine_offset(
            track_samples[:],
            audio.samples[:],
            rough_offset_samples,
            align_config,
          )
        catch {
          _ => {
            web_state.last_offset_samples = rough_offset_samples
            web_state.last_correlation = 0.0
            web_state.last_error = 0
            return 0
          }
        } noraise {
          value => value
        }
        web_state.last_offset_samples = alignment.refined_offset_samples
        web_state.last_correlation = alignment.correlation
      }
      None => {
        web_state.last_offset_samples = rough_offset_samples
        web_state.last_correlation = 0.0
      }
    }
  }
  web_state.last_error = 0
  0
}

///|
#export_name("moonecho_demo_track_count")
pub fn demo_track_count() -> Int {
  web_state.index.track_count()
}

///|
#export_name("moonecho_demo_posting_count")
pub fn demo_posting_count() -> Int {
  web_state.index.posting_count()
}

///|
#export_name("moonecho_demo_last_status")
pub fn demo_last_status() -> Int {
  web_state.last_status
}

///|
#export_name("moonecho_demo_last_track_id")
pub fn demo_last_track_id() -> Int {
  web_state.last_track_id
}

///|
#export_name("moonecho_demo_last_offset_frames")
pub fn demo_last_offset_frames() -> Int {
  web_state.last_offset_frames
}

///|
#export_name("moonecho_demo_last_offset_seconds")
pub fn demo_last_offset_seconds() -> Double {
  web_state.last_offset_samples.to_double() /
  web_state.index.profile.sample_rate.to_double()
}

///|
#export_name("moonecho_demo_last_confidence")
pub fn demo_last_confidence() -> Double {
  web_state.last_confidence
}

///|
#export_name("moonecho_demo_last_correlation")
pub fn demo_last_correlation() -> Double {
  web_state.last_correlation
}

///|
#export_name("moonecho_demo_last_votes")
pub fn demo_last_votes() -> Int {
  web_state.last_votes
}

///|
#export_name("moonecho_demo_last_query_hashes")
pub fn demo_last_query_hashes() -> Int {
  web_state.last_query_hashes
}

///|
#export_name("moonecho_demo_last_considered_postings")
pub fn demo_last_considered_postings() -> Int {
  web_state.last_considered_postings
}

///|
#export_name("moonecho_demo_last_candidate_count")
pub fn demo_last_candidate_count() -> Int {
  web_state.last_candidate_count
}

///|
#export_name("moonecho_demo_last_error")
pub fn demo_last_error() -> Int {
  web_state.last_error
}
