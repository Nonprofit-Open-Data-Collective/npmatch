# Retain only source records not already matched (incremental matching)

Compares a fresh source table against an existing crosswalk and returns
the subset of fresh records that have **not** already been resolved — so
a re-run only spends compute on new or previously-unmatched
organisations.

## Usage

``` r
np_diff_unmatched(
  fresh,
  crosswalk,
  key_fresh = NULL,
  key_cross = NULL,
  status_col = NULL,
  matched_values = c("YES", "MATCH", "match"),
  quiet = FALSE
)
```

## Arguments

- fresh:

  Fresh source records (data frame) with an id key.

- crosswalk:

  Existing crosswalk (data frame) with an id key and, ideally, a
  tier/status column.

- key_fresh, key_cross:

  Key column names. Auto-detected from `uei` / `UNIQUE ENTITY ID` /
  `unique_entity_id` / `.id` if `NULL`.

- status_col:

  Status/tier column in `crosswalk`. Auto-detected from `tier` /
  `match_decision` / `status` if `NULL`.

- matched_values:

  Status values that count as already matched.

- quiet:

  Suppress the summary message.

## Value

The retained subset of `fresh`, with an integer `"diff"` attribute
(`fresh`, `already_matched`, `retained`, `new_ids`).

## Details

A record counts as "already matched" if its key appears in the crosswalk
with a status in `matched_values` (when a status/tier column is present
or named via `status_col`); if no status column is found, any appearance
in the crosswalk counts as matched. Set
`matched_values = c("YES","MAYBE")` to also retain (re-run)
review-pending cases against a refreshed reference.
