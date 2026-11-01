<div id="main" class="col-md-9" role="main">

# Build a ZIP crosswalk from the zipcodeR package

<div class="ref-description section level2">

Convenience wrapper around `zipcodeR::zip_code_db` (no download needed)
that returns a `zip5`-keyed lookup for `np_augment_geo()`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_load_zipcode_db(cols = c("county", "state", "major_city"))
```

</div>

</div>

<div class="section level2">

## Arguments

-   cols:

    Columns to carry from `zip_code_db`. Default county / state /
    primary city.

</div>

<div class="section level2">

## Value

A data frame with `zip5` and the requested columns.

</div>

</div>
