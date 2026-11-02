# npmatch canonical fields

The internal, dataset-agnostic column names every npmatch stage works
with. Query and reference frames are mapped onto these by
[`np_query()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_query.md)
/
[`np_reference()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_reference.md).
Not every field will be populated for every dataset; the
geography-adaptive machinery keys off which of the geo fields are
present.

## Usage

``` r
np_fields
```

## Format

A character vector of canonical field names.
