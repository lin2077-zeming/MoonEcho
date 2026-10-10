# MoonEcho CLI

## Commands

```text
moonecho version
moonecho index --input <wav> --output <snapshot>
moonecho match --index <snapshot> --input <wav>
moonecho bench
```

## Index

The `index` command:

1. Reads a WAV file.
2. Downmixes and resamples to the configured sample rate.
3. Computes an STFT and extracts spectral peaks.
4. Builds fingerprint hashes.
5. Adds the track to an inverted index.
6. Writes an index snapshot v1.

Required options:

- `--input <wav>`
- `--output <snapshot>`

Optional options:

- `--name <track-name>`
- `--id <track-id>`
- `--sample-rate <hz>`
- `--window-length <frames>`
- `--hop-size <frames>`

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

- `--sample-rate <hz>`
- `--window-length <frames>`
- `--hop-size <frames>`
- `--top-k <n>`
- `--min-votes <n>`
- `--min-confidence <f>`
- `--min-margin <f>`

Index snapshots are written as v2 and carry the full processing profile.
`match` uses the embedded sample rate, window length, hop size, peak config, and
hash config automatically. If the caller explicitly supplies `--sample-rate`,
`--window-length`, or `--hop-size` with values that conflict with the profile,
the command fails instead of silently producing a mismatched query.

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

Use `--repeat <n>` to control the timing repetition count.
