# MoonEcho Fingerprint Index Snapshot v1

## Purpose

Index Snapshot v1 stores an inverted index from fingerprint hash to posting
lists. It is deterministic, self-describing, and designed for local persistence.

## Format Properties

- Magic: ASCII `MOONIX01`
- Index version: `1`
- Fingerprint version carried by the header: `1`
- Endianness: little-endian for all integers
- Checksum: FNV-1a 64-bit over every byte before the checksum field
- Required minimum size: 48 bytes

## Header

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 8 | magic |
| 8 | 2 | index version |
| 10 | 2 | flags |
| 12 | 2 | fingerprint version |
| 14 | 2 | reserved, must be `0` |
| 16 | 8 | hash seed |
| 24 | 2 | fan-out |
| 26 | 2 | min delta frames |
| 28 | 2 | max delta frames |
| 30 | 2 | encoded max frequency distance |
| 32 | 4 | track count |
| 36 | 4 | posting count |

`encoded max frequency distance` uses `0` for unlimited, otherwise
`distance + 1`.

Header size: 40 bytes.

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
- Every track fingerprint config must match the index config.
- New fields require a new snapshot version or a documented flag bit.

