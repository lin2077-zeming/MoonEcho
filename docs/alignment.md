# Sample-Accurate Alignment Refinement

## Goal

Fingerprint matching produces a frame-level offset. Alignment refinement turns
that rough location into a sample-level estimate by comparing the query against
the original track audio in a bounded neighborhood.

## Algorithm

The refiner evaluates candidate lags in:

```text
[rough_offset_samples - search_radius_samples,
 rough_offset_samples + search_radius_samples]
```

For each lag it computes normalized cross-correlation over the overlapping
window, with a configurable maximum window length. The lag with the highest
correlation is returned.

The refiner is intentionally bounded:

- It never scans the entire track.
- It uses the fingerprint candidate as the search center.
- It reports the evaluated lag count and correlation.

## CLI

`moonecho match --track <wav>` enables source-audio refinement. Without
`--track`, CLI output remains frame-level.

With `--track`, output includes:

- `offset_samples`
- `offset_seconds`
- `alignment: sample`
- `correlation`

## Benchmark

The robustness harness uses a stronger deterministic corpus containing:

- two tones
- a linear chirp
- alternating pulses
- deterministic noise and gain variants
- an unrelated high-frequency negative control

The benchmark reports both frame-level and sample-level offset errors.
