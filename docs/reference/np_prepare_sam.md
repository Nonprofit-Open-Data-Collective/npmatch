<div id="main" class="col-md-9" role="main">

# Download-and-prepare a SAM extract for matching

<div class="ref-description section level2">

Reads a raw SAM `.dat`, filters to nonprofits, and (optionally) writes
the result. The output is ready to pass to `np_cascade()` / `np_match()`
with `np_map_sam()` (after the usual header lower-casing).

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_prepare_sam(path, out = NULL, codes = c("A8", "BZ", "2U", "A7"))
```

</div>

</div>

<div class="section level2">

## Arguments

-   path:

    Path to the raw `.dat` (or use `np_fetch_sam()` first).

-   out:

    Optional output CSV path. If given, the nonprofit subset is written.

-   codes:

    Nonprofit codes (see `np_flag_nonprofits()`).

</div>

<div class="section level2">

## Value

The nonprofit subset (invisibly if `out` is written).

</div>

</div>
