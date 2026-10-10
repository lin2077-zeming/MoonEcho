# MoonEcho Fingerprint Index Snapshot v2

## Purpose

Index Snapshot v2 extends v1 with a processing profile. A snapshot now carries
the sample rate and spectrum/peak/hash settings used to create its fingerprints,
so matching can reproduce the same preprocessing without relying on external
CLI arguments.

## Format Properties

- Magic: ASCII `MOONIX02`
- Index version: `2`
- Fingerprint version carried by the header: `1`
- Endianness: little-endian for all integers and IEEE-754 doubles
- Checksum: FNV-1a 64-bit over every byte before the checksum field
- Required minimum size: 84 bytes

The decoder also accepts legacy `MOONIX01` v1 snapshots, which are upgraded in
memory to v2 records with the default processing profile.

## Header

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 8 | magic |
| 8 | 2 | index version |
| 10 | 2 | flags |
| 12 | 2 | fingerprint version |
| 14 | 2 | reserved, must be `0` |
| 16 | 4 | sample rate |
| 20 | 4 | window length |
| 24 | 4 | hop size |
| 28 | 2 | peak frequency radius |
| 30 | 2 | peak time radius |
| 32 | 2 | max peaks per frame |
| 34 | 2 | reserved, must be `0` |
| 36 | 8 | minimum magnitude |
| 44 | 8 | relative threshold |
| 52 | 8 | hash seed |
| 60 | 2 | fan-out |
| 62 | 2 | min delta frames |
| 64 | 2 | max delta frames |
| 66 | 2 | encoded max frequency distance |
| 68 | 4 | track count |
| 72 | 4 | posting count |

Header size: 76 bytes.

`encoded max frequency distance` uses `0` for unlimited, otherwise
`distance + 1`. Minimum magnitude and relative threshold are stored as IEEE-754
binary64 values.

## Track Record

Track records follow the header and are written in ascending track-id order.

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 4 | track id |
| 4 | 4 | source frame count |
| 8 | 4 | source bin count |
| 12 | 4 | fingerprint hash count |
| 16 | 2 | UTF-8 name length |
| 18 | N | UTF-8 track name |

Track record size: `18 + name_length`.

## Posting Record

Posting records follow all track records. They are written in ascending order
by hash, then track id, anchor frame, anchor bin, target bin, and delta.

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 8 | hash |
| 8 | 4 | track id |
| 12 | 4 | anchor frame |
| 16 | 4 | anchor bin |
| 20 | 2 | delta frames |
| 22 | 4 | target bin |
| 26 | 2 | reserved, must be `0` |

Posting record size: 28 bytes.

## Checksum

The snapshot ends with an 8-byte FNV-1a 64-bit checksum over all preceding
bytes.

## Compatibility Rules

- Unknown magic, version, flags, reserved fields, truncated data, malformed
  UTF-8 names, length mismatch, and checksum mismatch are rejected.
- Track ids must be unique.
- Every track fingerprint config must match the profile hash config.
- `match` uses the embedded profile by default.
- Caller-supplied sample-rate/window/hop options that conflict with the profile
  are rejected by the CLI.
