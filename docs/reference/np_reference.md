# Construct a reference frame

Maps the BMF (or, later, the disambiguation database) onto canonical
fields. The entity key `.ein` is required and is what selection/tiering
resolve to.

## Usage

``` r
np_reference(data, map = np_map_bmf())
```

## Arguments

- data:

  A data frame.

- map:

  A named character vector (see
  [np_maps](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)).
  Defaults to the BMF map.

## Value

A data frame of class `np_reference` with the canonical columns.
