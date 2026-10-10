# MoonEcho

MoonEcho is a local-first acoustic fingerprint search and audio alignment toolkit written in MoonBit.

The project is currently in milestone `M4`: the audio, spectrum, fingerprint,
index, matching, alignment, benchmark, and automation CLI layers are in place.
The remaining milestone work is the WASM demo and release materials.

## Status

- Project name: MoonEcho / 月响
- Version: 0.1.0
- Main language: MoonBit
- Target: native and WebAssembly
- License: Apache-2.0
- Audio input dependency: `Ridge-Lab/moonwavkit@0.1.3`
- Spectrum dependency: `chgttyyr/MoonSpectrum@0.2.2`

## Quick Start

```bash
moon check
moon test
moon run cmd/moonecho
moon run examples/basic
moon run examples/wav-adapter
moon run examples/spectrum
moon run examples/fingerprint
moon run examples/index
moon run examples/match
```

CLI:

```bash
moon run cmd/moonecho -- version
moon run cmd/moonecho -- index --input track.wav --output track.idx --name demo
moon run cmd/moonecho -- index --manifest tracks.tsv --output library.idx
moon run cmd/moonecho -- index --input clip.wav --output library.idx --id 2 --append
moon run cmd/moonecho -- match --index track.idx --input clip.wav
moon run cmd/moonecho -- info --index library.idx --json
moon run cmd/moonecho -- bench --json
```

Expected CLI output:

```text
MoonEcho (月响) v0.1.0: Local-first acoustic fingerprint search and audio alignment toolkit
```

## Minimal API

```moonbit nocheck
///|
fn main {
  println(status())
}
```

## Audio Adapter

MoonEcho intentionally reuses MoonWavKit for RIFF/WAVE parsing, PCM decoding,
generic PCM processing, and linear resampling. MoonEcho's adapter keeps a
stable local API for the fingerprint pipeline:

```moonbit nocheck
///|
fn inspect_wav(bytes : Array[Int]) -> Unit raise {
  let audio = @audio.load_wav_mono(bytes, target_sample_rate=16000)
  println(audio.frame_count())
}
```

## Spectrum Adapter

MoonSpectrum provides the FFT, STFT, and synthetic signal generators. MoonEcho
adapts them to normalized audio buffers and its own error boundary:

```moonbit nocheck
///|
let audio = @audio.load_wav_mono(bytes, target_sample_rate=16000)

///|
let config = @spectrum.SpectrumConfig::new(window_length=1024, hop_size=512)

///|
let result = @spectrum.spectrogram(audio, config)

///|
let peaks = @spectrum.extract_peaks(result, @spectrum.PeakConfig::new())
```

## Fingerprint v1

MoonEcho's fingerprint layer turns spectral peaks into pairwise hashes and
serializes them in a deterministic binary format:

```moonbit nocheck
///|
let config = @fingerprint.HashConfig::new()

///|
let fp = @fingerprint.fingerprint(
  peaks,
  config,
  frame_count=result.magnitudes.length(),
  bin_count=result.frequencies.length(),
)

///|
let encoded = @fingerprint.encode(fp)
```

The exact byte layout is documented in
[docs/fingerprint-v1.md](docs/fingerprint-v1.md).

## Index Snapshot v2

The index layer maps each fingerprint hash to track/frame/bin postings and
persists the full structure plus its preprocessing profile with a deterministic
binary snapshot:

```moonbit nocheck
let index = @index.FingerprintIndex::new(config)
index.add_track(1, "track-a", fingerprint)
let snapshot = @index.encode(index)
let restored = @index.decode(snapshot)
```

The exact byte layout is documented in [docs/index-v2.md](docs/index-v2.md).
Legacy v1 snapshots remain readable; see [docs/index-v1.md](docs/index-v1.md).

## Candidate Matching

The matching layer votes on `(track_id, offset)` pairs produced by shared
fingerprint hashes, then ranks tracks and computes confidence and margin:

```moonbit nocheck
let config = @match.MatchConfig::new(min_votes=3, min_confidence=0.2)
let result = @match.match_fingerprint(index, query, config)
println(@match.status_label(result.status))
```

The scoring algorithm is documented in [docs/matching.md](docs/matching.md).
Sample-accurate refinement is documented in [docs/alignment.md](docs/alignment.md).

## CLI

The command-line façade wires audio decoding, spectrum extraction, fingerprint
encoding, index snapshots, batch/append indexing, inspection, candidate
matching, and benchmarks into one executable:

```text
moonecho index   # single track, manifest, or append
moonecho match   # search and optional sample alignment
moonecho info    # inspect snapshot metadata and tracks
moonecho bench   # robustness and performance report
```

`index`, `match`, `info`, and `bench` support `--json` for automation.

See [docs/cli.md](docs/cli.md) for all options and reproducibility notes.

The robustness and benchmark harness is documented in
[docs/benchmark.md](docs/benchmark.md).

## Roadmap

- M0: project skeleton, README, LICENSE, CI, tests, first runnable example.
- M1: WAV/PCM adapter over MoonWavKit, FFT/STFT adapter over MoonSpectrum, two-dimensional spectral peak extraction.
- M2: fingerprint encoding, inverted index, snapshot format.
- M3: matching, offset voting, confidence scoring, CLI.
- M4: robustness tests, benchmarks, WASM demo.
- M5: mooncakes.io release and final acceptance materials.

See [docs/任务规划书.md](docs/任务规划书.md) for the full plan.
