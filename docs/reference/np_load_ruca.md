<div id="main" class="col-md-9" role="main">

# Load a USDA ERS ZIP-code RUCA file

<div class="ref-description section level2">

Reshapes the USDA Economic Research Service ZIP-code Rural-Urban
Commuting Area file into a `zip5`-keyed lookup with a numeric `ruca`
(primary RUCA). Pair with `np_ruca_urban()` for an urban/rural flag.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_load_ruca(x, sheet = 1)
```

</div>

</div>

<div class="section level2">

## Arguments

-   x:

    A RUCA file: a data frame, `.csv`, or `.xlsx` path.

-   sheet:

    Worksheet for `.xlsx` input. Default 1.

</div>

<div class="section level2">

## Value

A data frame with `zip5` and `ruca`.

</div>

<div class="section level2">

## Details

Download from
<https://www.ers.usda.gov/data-products/rural-urban-commuting-area-codes>.

</div>

</div>
