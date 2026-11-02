# Build a ZIP crosswalk from the zipcodeR package

Convenience wrapper around `zipcodeR::zip_code_db` (no download needed)
that returns a `zip5`-keyed lookup for
[`np_augment_geo()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_augment_geo.md).

## Usage

``` r
np_load_zipcode_db(cols = c("county", "state", "major_city"))
```

## Arguments

- cols:

  Columns to carry from `zip_code_db`. Default county / state / primary
  city.

## Value

A data frame with `zip5` and the requested columns.
