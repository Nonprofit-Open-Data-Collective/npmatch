# Preview the field-by-field comparison for one candidate pair

Reconstructs, for a single query/reference pair, the values compared on
each field and their similarity — the view a human reviewer needs.
Adapted from the prototype `preview_pair()`.

## Usage

``` r
np_preview_pair(pairs, id, ein = NULL)
```

## Arguments

- pairs:

  An `np_pairs` frame.

- id:

  A query `.id`.

- ein:

  A reference `.ein`. Defaults to that query's top-scoring pair.

## Value

A small data frame: one row per compared field.
