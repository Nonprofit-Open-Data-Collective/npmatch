<div id="main" class="col-md-9" role="main">

# Construct a query frame

<div class="ref-description section level2">

Maps an arbitrary source dataset onto npmatch canonical fields. The
query is the "unknown" side being matched *into* the reference. A stable
`.id` is required; if the map does not supply one, row numbers are used.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_query(data, map = np_map_sam())
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame.

-   map:

    A named character vector, `canonical = source_column` (see
    [np_maps](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)).
    Defaults to the SAM/USASpending map.

</div>

<div class="section level2">

## Value

A data frame of class `np_query` with the canonical columns.

</div>

</div>
