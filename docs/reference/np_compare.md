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
  token_idf = NULL,
  addr_freq = NULL
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

- name_freq, token_idf:

  Optional pre-computed reference tables from
  [`np_name_freq()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_name_freq.html)
  /
  [`np_token_idf()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_token_idf.html).

- addr_freq:

  Optional
  [`np_addr_freq()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_addr_freq.html)
  table for the reference. Used to read a suite match in context:
  `addr_shared`, `addr_units`, `addr_unit_shared` and `addr_note` are
  added to the result, and `np_score(method = "hier")` credits a
  matching suite only where the address is genuinely multi-tenant.
  Computed from `reference` when `NULL`, which is wrong if `reference`
  is a slice of the real corpus — build it once from the whole reference
  and pass it in (as
  [`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
  does).

## Value

A data frame of candidate pairs, one row per (query, reference) pair,
with class `np_pairs`. Columns include `.x`, `.y`, `.id`, `.ein`, a
similarity column per compared field, plus carried veto features. Two
columns report the suite, both three-valued (1 agree, 0 differ, `NA`
either side names no unit): `geo_unit` compares the unit identifier with
the designator stripped, which is the column
[`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
credits and the reason `STE 320` and `# 320` agree; `geo_unit_same_kind`
says whether the two sides name the same kind of place, so a reviewer
reading a floor against a suite is not told they are the same office.

## Details

The name is always compared (on `name_key`). Geographic comparison
fields are taken from the profile. Name-feature columns needed by
[`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
are carried through for both sides with `_x` / `_y` suffixes.
