# Candidate Voting and Confidence Scoring

## Inputs

- An inverted index containing posting lists keyed by fingerprint hash.
- A query fingerprint produced with the same configuration as the index.
- A `MatchConfig` containing `top_k`, `min_votes`, `min_confidence`, and
  `min_margin`.

Query and index hash configurations must match exactly.

## Offset Voting

For every query fingerprint hash:

1. Look up all index postings for that hash.
2. For each posting, compute:

```text
offset = posting.anchor_frame - query_hash.anchor_frame
```

3. Add one vote for `(posting.track_id, offset)`.

A consistent alignment between the query and an indexed track produces many
votes at the same offset.

## Candidate Selection

For each track, MoonEcho keeps the offset with the highest vote count. Tracks
are ranked by vote count descending, then track id ascending.

## Confidence

For query hash count `Q` and candidate vote count `V`:

```text
confidence = V / Q
```

Confidence is in `[0, 1]`.

## Margin

For candidate vote count `V` and the next-ranked track vote count `N`:

```text
margin = (V - N) / V
```

Margin is `1.0` for the last candidate in the ranked list.

## Status

- `Strong`: best candidate satisfies all configured thresholds.
- `Weak`: at least one candidate exists, but the best candidate does not meet
  one or more thresholds.
- `NoMatch`: no candidate exists or the query fingerprint is empty.

The result also reports `query_hash_count` and `considered_postings` so callers
can audit how much work produced the decision.
