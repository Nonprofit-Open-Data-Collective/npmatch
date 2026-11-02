# Construct a query frame

Maps an arbitrary source dataset onto npmatch canonical fields. The
query is the "unknown" side being matched *into* the reference. A stable
`.id` is required; if the map does not supply one, row numbers are used.

## Usage

``` r
np_query(data, map = np_map_sam())
```

## Arguments

- data:

  A data frame.

- map:

  A named character vector, `canonical = source_column` (see
  [np_maps](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)).
  Defaults to the SAM/USASpending map.

## Value

A data frame of class `np_query` with the canonical columns.
