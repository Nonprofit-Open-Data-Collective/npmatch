<div id="main" class="col-md-9" role="main">

# Collapse a RUCA code to an urban / rural flag

<div class="ref-description section level2">

Primary Rural-Urban Commuting Area codes 1-3 are metropolitan; 4 and
above are non-metropolitan. Returns `"urban"` / `"rural"` accordingly.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_ruca_urban(ruca, urban_max = 3)
```

</div>

</div>

<div class="section level2">

## Arguments

-   ruca:

    Numeric or character primary RUCA codes.

-   urban_max:

    Highest RUCA still treated as urban. Default 3.

</div>

<div class="section level2">

## Value

A character vector of `"urban"` / `"rural"` / `NA`.

</div>

</div>
