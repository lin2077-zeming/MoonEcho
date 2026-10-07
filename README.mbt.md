# MoonEcho

MoonEcho is a local-first acoustic fingerprint search and audio alignment toolkit written in MoonBit.

The project is currently in milestone `M1`: the audio adapter is in place, and the next work is spectrum and fingerprint processing.

## Status

- Project name: MoonEcho / 月响
- Version: 0.1.0
- Main language: MoonBit
- Target: native and WebAssembly
- License: Apache-2.0
- Audio input dependency: `Ridge-Lab/moonwavkit@0.1.3`

## Quick Start

```bash
moon check
moon test
moon run cmd/moonecho
moon run examples/basic
moon run examples/wav-adapter
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

## Roadmap

- M0: project skeleton, README, LICENSE, CI, tests, first runnable example.
- M1: WAV/PCM adapter over MoonWavKit, FFT/STFT, spectral peak extraction.
- M2: fingerprint encoding, inverted index, snapshot format.
- M3: matching, offset voting, confidence scoring, CLI.
- M4: robustness tests, benchmarks, WASM demo.
- M5: mooncakes.io release and final acceptance materials.

See [docs/任务规划书.md](docs/任务规划书.md) for the full plan.
