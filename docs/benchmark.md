# MoonEcho Robustness and Benchmark Harness

## Goal

The harness measures the current index and matcher under deterministic
transformations of a generated track. It is intended for regression checks and
acceptance evidence, not as a general audio benchmark suite.

## Generated Track

The harness synthesizes a deterministic two-tone track:

- 440 Hz tone
- 660 Hz tone
- fixed sample rate and frame count

No external audio files or network access are required.

## Robustness Cases

- `clean`: a crop from the generated track.
- `silence`: the same crop with deterministic left/right silence padding.
- `gain`: the same crop after a gain change.
- `noise`: the same crop with deterministic white noise.
- `unrelated`: a different frequency used as a negative control.

Positive cases are expected to return the indexed track as the top hit.
Negative cases are expected not to hit the indexed track.

## Reported Metrics

- `correct_hits / positive_cases`
- `negative_hits / negative_cases`
- mean offset error in STFT frames
- maximum offset error in STFT frames
- hash count and posting count
- snapshot size in bytes
- median query time in microseconds

Query timing uses the MoonBit core monotonic clock. Timing values vary by host
and should be interpreted as a reproducible local measurement, not a universal
performance claim.
