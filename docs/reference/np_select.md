<div id="main" class="col-md-9" role="main">

# Select best matches per query record

<div class="ref-description section level2">

Reduces scored, vetoed candidate pairs to the best reference entity per
query record, and — because the useful MAYBE/NO review set is wider than
a single best guess — also surfaces the best match under two *loosened*
views:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_select(pairs, config = np_config(), include_vetoed = FALSE)
```

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    Scored + vetoed `np_pairs` (see `np_score()`, `np_veto()`).

-   include_vetoed:

    If `TRUE`, vetoed pairs remain eligible (recorded, not dropped).
    Default `FALSE`.

</div>

<div class="section level2">

## Value

A one-row-per-query data frame of class `np_selection` with the chosen
`overall_*` match and the alternative `name_*` / `addr_*` matches.

</div>

<div class="section level2">

## Details

-   `overall` best by combined `score` (the primary decision),

-   `name` best by name similarity alone (address ignored beyond
    blocking),

-   `addr` best by address similarity alone (name ignored).

When the three views disagree, that disagreement is itself signal for
review. Vetoed pairs are excluded from every "best" pick by default.

</div>

</div>
