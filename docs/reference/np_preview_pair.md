<div id="main" class="col-md-9" role="main">

# Preview the field-by-field comparison for one candidate pair

<div class="ref-description section level2">

Reconstructs, for a single query/reference pair, the values compared on
each field and their similarity — the view a human reviewer needs.
Adapted from the prototype `preview_pair()`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_preview_pair(pairs, id, ein = NULL)
```

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    An `np_pairs` frame.

-   id:

    A query `.id`.

-   ein:

    A reference `.ein`. Defaults to that query's top-scoring pair.

</div>

<div class="section level2">

## Value

A small data frame: one row per compared field.

</div>

</div>
