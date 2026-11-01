<div id="main" class="col-md-9" role="main">

# Load a HUD USPS ZIP crosswalk file

<div class="ref-description section level2">

Reshapes a downloaded HUD ZIP crosswalk (ZIP->CBSA, ZIP->county, ...)
into a `zip5`-keyed lookup for `np_augment_geo()`. A ZIP can map to
several target geographies; the dominant one (highest address ratio) is
kept.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_load_hud(x, ratio = c("tot", "res", "bus", "oth"))
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A HUD crosswalk: a data frame, `.csv`, or `.xlsx` path.

-   ratio:

    Which HUD ratio to rank dominance by: `"tot"`, `"res"`, `"bus"`, or
    `"oth"`. Default `"tot"`.

</div>

<div class="section level2">

## Value

A data frame with `zip5` and the detected geography column.

</div>

<div class="section level2">

## Details

Download from
<https://www.huduser.gov/portal/datasets/usps_crosswalk.html> (login
required). The geography column (`cbsa`, `county`, ...) is detected
automatically as the non-ZIP, non-ratio column.

</div>

</div>
