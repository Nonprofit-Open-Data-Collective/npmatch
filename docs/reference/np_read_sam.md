# Read a raw SAM public extract

The extract is headerless, pipe-delimited, and unquoted; this reads it
and applies
[`np_sam_layout()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_sam_layout.md)
names.

## Usage

``` r
np_read_sam(path, layout = np_sam_layout())
```

## Arguments

- path:

  Path to the `.dat` file.

- layout:

  Column names. Default
  [`np_sam_layout()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_sam_layout.md).

## Value

A `data.table`.
