# Load a USDA ERS ZIP-code RUCA file

Reshapes the USDA Economic Research Service ZIP-code Rural-Urban
Commuting Area file into a `zip5`-keyed lookup with a numeric `ruca`
(primary RUCA). Pair with
[`np_ruca_urban()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ruca_urban.md)
for an urban/rural flag.

## Usage

``` r
np_load_ruca(x, sheet = 1)
```

## Arguments

- x:

  A RUCA file: a data frame, `.csv`, or `.xlsx` path.

- sheet:

  Worksheet for `.xlsx` input. Default 1.

## Value

A data frame with `zip5` and `ruca`.

## Details

Download from
<https://www.ers.usda.gov/data-products/rural-urban-commuting-area-codes>.
