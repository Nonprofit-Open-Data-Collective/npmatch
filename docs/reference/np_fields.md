<div id="main" class="col-md-9" role="main">

# npmatch canonical fields

<div class="ref-description section level2">

The internal, dataset-agnostic column names every npmatch stage works
with. Query and reference frames are mapped onto these by `np_query()` /
`np_reference()`. Not every field will be populated for every dataset;
the geography-adaptive machinery keys off which of the geo fields are
present.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_fields
```

</div>

</div>

<div class="section level2">

## Format

A character vector of canonical field names.

</div>

</div>
