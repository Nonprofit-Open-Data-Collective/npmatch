# Collapse a RUCA code to an urban / rural flag

Primary Rural-Urban Commuting Area codes 1-3 are metropolitan; 4 and
above are non-metropolitan. Returns `"urban"` / `"rural"` accordingly.

## Usage

``` r
np_ruca_urban(ruca, urban_max = 3)
```

## Arguments

- ruca:

  Numeric or character primary RUCA codes.

- urban_max:

  Highest RUCA still treated as urban. Default 3.

## Value

A character vector of `"urban"` / `"rural"` / `NA`.
