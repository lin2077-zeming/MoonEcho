# MoonEcho Fingerprint v1

## Purpose

Fingerprint v1 is the stable binary format produced by MoonEcho from spectral
peaks. It is designed for local storage, index construction, and later matching.
It stores pairwise peak hashes, not audio samples.

## Format Properties

- Format version: `1`
- Magic: ASCII `MOONFP01`
- Endianness: little-endian for all integers
- Checksum: FNV-1a 64-bit over every byte before the checksum field
- Required minimum size: 48 bytes
- Fixed record size: 24 bytes

## Header

| Offset | Size | Field | Notes |
| --- | ---: | --- | --- |
| 0 | 8 | magic | `MOONFP01` |
| 8 | 2 | version | currently `1` |
| 10 | 2 | flags | must be `0` in v1 |
| 12 | 8 | hash_seed | deterministic pair-hash seed |
| 20 | 2 | fan_out | target peaks per anchor |
| 22 | 2 | min_delta_frames | minimum target-frame distance |
| 24 | 2 | max_delta_frames | maximum target-frame distance |
| 26 | 2 | max_frequency_distance | `0` means unlimited; otherwise stored as `distance + 1` |
| 28 | 4 | frame_count | source spectrogram frame count |
| 32 | 4 | bin_count | source spectrogram bin count |
| 36 | 4 | hash_count | number of records |

Header size: 40 bytes.

## Record

Each hash record is 24 bytes.

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 8 | hash |
| 8 | 4 | anchor_frame |
| 12 | 4 | anchor_bin |
| 16 | 2 | delta_frames |
| 18 | 4 | target_bin |
| 22 | 2 | reserved, must be `0` |

`target_frame` is derived as `anchor_frame + delta_frames`.

## Checksum

After `hash_count` records, the payload ends with an 8-byte FNV-1a 64-bit
checksum over all preceding bytes.

Total size:

```text
48 + hash_count * 24
```

## Pair Hash

For an anchor peak `(anchor_bin)` and target peak `(target_bin, delta_frames)`,
the v1 hash is:

```text
hash = FNV1a64(
  seed,
  little_endian_u64(anchor_bin),
  little_endian_u64(target_bin),
  little_endian_u64(delta_frames),
)
```

The hash is stored as an unsigned 64-bit integer. It is intended for candidate
generation, not cryptographic authentication.

## Compatibility Rules

- A decoder must reject an unknown magic, unknown version, non-zero flags,
  unknown reserved fields, truncated data, length mismatch, and checksum
  mismatch.
- `max_delta_frames` must be greater than or equal to `min_delta_frames`.
- `frame_count`, `bin_count`, and `hash_count` must be positive for non-empty
  fingerprints.
- New fields must be introduced through a new version or through a documented
  flag bit.
