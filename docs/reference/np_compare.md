# Generate and compare candidate pairs

Blocks the query against the reference, then scores each candidate pair
on the fields implied by the detected (or supplied) geographic profile.
reclin2 does the blocked pairing and per-field string comparison; the
result is returned as a plain data frame so every downstream npmatch
stage works on ordinary columns.

## Usage

``` r
np_compare(
  query,
  reference,
  config = np_config(),
  block = "state",
  profile = NULL,
  candidates = NULL,
  name_freq = NULL,
  token_idf = NULL
)
```

## Arguments

- query, reference:

  Normalized `np_query` / `np_reference` frames.

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md).

- block:

  Character vector of canonical fields to block on when `candidates` is
  not supplied. Defaults to `"state"`.

- profile:

  Optional profile name to force; otherwise
  [`np_detect_geo()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_detect_geo.md).

- candidates:

  Optional `np_blocks` from
  [`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md).
  When given, these candidate pairs are compared instead of blocking on
  `block` — the scalable path (name-token / progressive blocking).

## Value

A data frame of candidate pairs, one row per (query, reference) pair,
with class `np_pairs`. Columns include `.x`, `.y`, `.id`, `.ein`, a
similarity column per compared field, plus carried veto features.

## Details

The name is always compared (on `name_key`). Geographic comparison
fields are taken from the profile. Name-feature columns needed by
[`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
are carried through for both sides with `_x` / `_y` suffixes.
