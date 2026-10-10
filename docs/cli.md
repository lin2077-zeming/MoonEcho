# MoonEcho CLI

## Commands

```text
moonecho version
moonecho index --input <wav> --output <snapshot> [options]
moonecho index --manifest <file> --output <snapshot> [options]
moonecho match --index <snapshot> --input <wav> [options]
moonecho info --index <snapshot> [--json]
moonecho bench [--repeat <n>] [--json]
```

All successful commands return plain text by default. Add `--json` to `index`,
`match`, `info`, or `bench` for machine-readable output.

## Index

The `index` command:

1. Reads one WAV file or a manifest of WAV files.
2. Downmixes and resamples to the configured sample rate.
3. Computes an STFT and extracts spectral peaks.
4. Builds fingerprint hashes.
5. Adds tracks to an inverted index.
6. Writes an index snapshot v2.

Required options:

- `--output <snapshot>`
- Exactly one of `--input <wav>` or `--manifest <file>`

Single-track options:

- `--name <track-name>` defaults to `track`
- `--id <track-id>` defaults to `1`

Shared processing options:

- `--sample-rate <hz>` defaults to `16000`
- `--window-length <frames>` defaults to `1024`
- `--hop-size <frames>` defaults to `512`

Other options:

- `--append` adds to an existing snapshot instead of creating a new one
- `--json` prints the result as JSON

### Append

`--append` reads the existing snapshot first, verifies that its processing
profile exactly matches the requested profile, and rejects duplicate track ids.
If the output file does not exist, the command creates a new snapshot.

When appending to a snapshot with custom processing settings, repeat the same
sample-rate, window-length, and hop-size options. Snapshot v1 files remain
readable and are rewritten as v2 when a successful append is saved.

### Manifest

Manifest files are UTF-8 text with one tab-separated track per line:

```text
<track_id><TAB><name><TAB><wav_path>
```

Example:

```text
1	track-a	audio/track-a.wav
2	track-b	audio/track-b.wav
```

Blank lines and lines whose first non-whitespace character is `#` are ignored.
Paths are resolved by the process working directory. The manifest is processed
from top to bottom; snapshot encoding then sorts tracks and postings so the
same manifest produces the same stored index regardless of map iteration order.

Example:

```bash
moon run cmd/moonecho -- index \
  --manifest tracks.tsv \
  --output library.idx

moon run cmd/moonecho -- index \
  --input audio/new-track.wav \
  --id 3 \
  --name new-track \
  --output library.idx \
  --append
```

## Match

The `match` command:

1. Reads an index snapshot.
2. Reads and preprocesses a query WAV file.
3. Builds query fingerprints with the index hash configuration.
4. Votes on `(track_id, offset)` candidates.
5. Prints the best track, offset, confidence, and status.

Required options:

- `--index <snapshot>`
- `--input <wav>`

Optional options:

- `--track <wav>` for sample-accurate alignment refinement
- `--sample-rate <hz>`
- `--window-length <frames>`
- `--hop-size <frames>`
- `--top-k <n>`
- `--min-votes <n>`
- `--min-confidence <f>`
- `--min-margin <f>`
- `--json`

Index snapshots are written as v2 and carry the full processing profile.
`match` uses the embedded sample rate, window length, hop size, peak config, and
hash config automatically. If the caller explicitly supplies `--sample-rate`,
`--window-length`, or `--hop-size` with values that conflict with the profile,
the command fails instead of silently producing a mismatched query.

When `--track` is supplied, `match` runs bounded normalized cross-correlation
around the fingerprint-derived frame offset and reports `offset_samples` and
`correlation`.

If no candidate passes the configured thresholds, the plain-text output reports
zero candidates. JSON output still contains `status`, `candidates`, and
`considered_postings`.

## Info

`info` prints the snapshot format version, fingerprint version, processing
profile, track count, posting count, and track list.

```bash
moon run cmd/moonecho -- info --index library.idx
moon run cmd/moonecho -- info --index library.idx --json
```

The processing profile in `info` includes:

- sample rate, window length, and hop size
- peak frequency/time radii, magnitude threshold, relative threshold, and
  maximum peaks per frame
- hash seed, fan-out, delta-frame bounds, and maximum frequency distance

In JSON output, `hash_seed` is a decimal string so a 64-bit seed is not rounded
by JSON consumers that use IEEE-754 numbers.

## Bench

`bench` runs the built-in robustness suite:

- clean clip
- silence-padded clip
- gain-shifted clip
- noisy clip
- unrelated negative-control clip

It reports:

- correct top-1 hits
- negative-control hits
- mean and maximum offset error
- hash and posting counts
- snapshot bytes
- median query time in microseconds

Use `--repeat <n>` to control the timing repetition count and `--json` for
machine-readable output.

## JSON Output

JSON output is a single object on stdout. Field order is stable within each
command, although consumers should rely on field names rather than order.

Index:

```json
{"status":"indexed","snapshot":"library.idx","tracks":2,"added_hashes":42,"postings":80}
```

Match with a candidate:

```json
{"status":"matched","top_track":"track-a","offset_frames":18,"offset_samples":576,"offset_seconds":0.036,"alignment":"sample","correlation":0.99,"confidence":0.82,"candidates":1,"considered_postings":80}
```

Info:

```json
{"snapshot":"library.idx","snapshot_version":2,"fingerprint_version":1,"sample_rate":16000,"window_length":1024,"hop_size":512,"track_count":2,"posting_count":80,"tracks":[]}
```

Bench:

```json
{"status":"ok","cases":5,"correct_hits":4,"positive_cases":4,"negative_hits":0,"negative_cases":1,"query_median_us":0.0}
```

The examples abbreviate the full field set. See the command output for the
complete object.
