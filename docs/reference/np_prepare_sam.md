# Download-and-prepare a SAM extract for matching

Reads a raw SAM `.dat`, filters to nonprofits, and (optionally) writes
the result. The output is ready to pass to
[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
/
[`np_match()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_match.md)
with
[`np_map_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)
(after the usual header lower-casing).

## Usage

``` r
np_prepare_sam(path, out = NULL, codes = c("A8", "BZ", "2U", "A7"))
```

## Arguments

- path:

  Path to the raw `.dat` (or use
  [`np_fetch_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch_sam.md)
  first).

- out:

  Optional output CSV path. If given, the nonprofit subset is written.

- codes:

  Nonprofit codes (see
  [`np_flag_nonprofits()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_flag_nonprofits.md)).

## Value

The nonprofit subset (invisibly if `out` is written).
