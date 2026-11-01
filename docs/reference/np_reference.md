<div id="main" class="col-md-9" role="main">

# Construct a reference frame

<div class="ref-description section level2">

Maps the BMF (or, later, the disambiguation database) onto canonical
fields. The entity key `.ein` is required and is what selection/tiering
resolve to.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_reference(data, map = np_map_bmf())
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame.

-   map:

    A named character vector (see
    [np_maps](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)).
    Defaults to the BMF map.

</div>

<div class="section level2">

## Value

A data frame of class `np_reference` with the canonical columns.

</div>

</div>
