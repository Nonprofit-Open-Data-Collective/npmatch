# Load a HUD USPS ZIP crosswalk file

Reshapes a downloaded HUD ZIP crosswalk (ZIP-\>CBSA, ZIP-\>county, ...)
into a `zip5`-keyed lookup for
[`np_augment_geo()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_augment_geo.md).
A ZIP can map to several target geographies; the dominant one (highest
address ratio) is kept.

## Usage

``` r
np_load_hud(x, ratio = c("tot", "res", "bus", "oth"))
```

## Arguments

- x:

  A HUD crosswalk: a data frame, `.csv`, or `.xlsx` path.

- ratio:

  Which HUD ratio to rank dominance by: `"tot"`, `"res"`, `"bus"`, or
  `"oth"`. Default `"tot"`.

## Value

A data frame with `zip5` and the detected geography column.

## Details

Download from
<https://www.huduser.gov/portal/datasets/usps_crosswalk.html> (login
required). The geography column (`cbsa`, `county`, ...) is detected
automatically as the non-ZIP, non-ratio column.
