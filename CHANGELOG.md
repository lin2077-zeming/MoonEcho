# Changelog

## 0.1.2 - 2026-10-13

- Removed the module root package facade so `moon bundle --all` runs
  successfully under MoonBit `0.10.15`.
- Moved the project metadata and its tests into the `src/project` leaf
  package.

## 0.1.1 - 2026-10-13

- Fixed CLI error paths to return a non-zero process exit code.
- Adapted formatting and generated interfaces for MoonBit `0.10.15`.
- Moved project metadata into `src/project` so CLI and examples do not reverse
  depend on the module root package.
- Renamed the executable package directory to `cmd/moonecho-cli` to avoid
  duplicate core output names.
- Added CLI exit-code smoke coverage to CI.

## 0.1.0 - 2026-10-11

- Added WAV/PCM adaptation over MoonWavKit.
- Added FFT/STFT and spectral peak extraction over MoonSpectrum.
- Added fingerprint v1 encoding and decoding.
- Added inverted-index snapshot v1/v2 with processing profiles.
- Added candidate voting, confidence scoring, and sample-accurate alignment.
- Added batch and append indexing, snapshot info, and JSON CLI output.
- Added robustness benchmarks and deterministic synthetic audio fixtures.
- Added a browser `wasm-gc` matching workbench and Node smoke test.
- Added Mooncakes.io release and third-party license documentation.
- Published `lin2077-zeming/moonecho@0.1.0` to Mooncakes.io.
