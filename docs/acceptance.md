# Acceptance Summary

## Deliverables

MoonEcho is a local-first acoustic fingerprint search and alignment toolkit for
MoonBit. The repository contains:

- WAV/PCM adaptation over `Ridge-Lab/moonwavkit`
- FFT/STFT and peak extraction over `chgttyyr/MoonSpectrum`
- fingerprint hash generation and binary serialization
- inverted index and snapshot v1/v2 persistence
- matching with offset voting and confidence scoring
- bounded sample-accurate alignment
- native CLI, JSON automation output, manifest indexing, and append indexing
- robustness benchmarks with positive and negative controls
- a browser demo using a real `wasm-gc` module
- README, CLI/WASM/release documentation, Apache-2.0 license, and third-party
  notices

## Reproduction

Native CLI:

```bash
moon check --target all --deny-warn
moon test --target native --deny-warn
moon run cmd/moonecho -- bench --json
```

Browser demo:

```bash
npm run build:demo
npm run serve:demo
npm run smoke:demo
```

The browser page is served at `http://127.0.0.1:4173`. The built-in corpus is
generated locally and requires no external audio assets.

## Acceptance Evidence

- local checks: `moon check --target all --deny-warn`
- tests: `moon test --target wasm --deny-warn` and
  `moon test --target native --deny-warn`
- demo: `npm run smoke:demo` verifies the expected reference, offset,
  confidence, and sample correlation
- browser: Playwright smoke covers desktop and mobile rendering, WASM
  instantiation, index construction, query execution, and horizontal overflow
- release: `moon package --list` shows the source and release documents; the
  publish dry run reports server-side validation

## Known Limits

- the browser demo currently accepts PCM WAV files through a small byte-based
  host ABI
- the index is designed for local or embedded use; no server-side database or
  distributed search is included
- the built-in benchmark corpus is synthetic and does not replace evaluation
  against a licensed music collection
- the native backend does not build the browser-only `src/web` package

## Submission State

`lin2077-zeming/moonecho@0.1.0` is published on Mooncakes.io:

https://mooncakes.io/docs/#/lin2077-zeming/moonecho/

The published dependency set is `moonbitlang/x@0.4.45`,
`Ridge-Lab/moonwavkit@0.1.3`, and `chgttyyr/MoonSpectrum@0.2.2`.
