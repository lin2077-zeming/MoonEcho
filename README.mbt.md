# MoonEcho

MoonEcho is a local-first acoustic fingerprint search and audio alignment toolkit written in MoonBit.

The project is currently at milestone `M0`: project skeleton, public API, CLI, tests, and CI.

## Status

- Project name: MoonEcho / 月响
- Version: 0.1.0
- Main language: MoonBit
- Target: native and WebAssembly
- License: Apache-2.0

## Quick Start

```bash
moon check
moon test
moon run cmd/moonecho
moon run examples/basic
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

## Roadmap

- M0: project skeleton, README, LICENSE, CI, tests, first runnable example.
- M1: PCM/WAV preprocessing, FFT/STFT, spectral peak extraction.
- M2: fingerprint encoding, inverted index, snapshot format.
- M3: matching, offset voting, confidence scoring, CLI.
- M4: robustness tests, benchmarks, WASM demo.
- M5: mooncakes.io release and final acceptance materials.

See [docs/任务规划书.md](docs/任务规划书.md) for the full plan.
