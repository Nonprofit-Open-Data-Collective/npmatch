# Select best matches per query record

Reduces scored, vetoed candidate pairs to the best reference entity per
query record, and — because the useful MAYBE/NO review set is wider than
a single best guess — also surfaces the best match under two *loosened*
views:

## Usage

``` r
np_select(pairs, config = np_config(), include_vetoed = FALSE)
```

## Arguments

- pairs:

  Scored + vetoed `np_pairs` (see
  [`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md),
  [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)).

- include_vetoed:

  If `TRUE`, vetoed pairs remain eligible (recorded, not dropped).
  Default `FALSE`.

## Value

A one-row-per-query data frame of class `np_selection` with the chosen
`overall_*` match and the alternative `name_*` / `addr_*` matches.

## Details

- `overall` best by combined `score` (the primary decision),

- `name` best by name similarity alone (address ignored beyond
  blocking),

- `addr` best by address similarity alone (name ignored).

When the three views disagree, that disagreement is itself signal for
review. Vetoed pairs are excluded from every "best" pick by default.
