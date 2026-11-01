<div id="main" class="col-md-9" role="main">

# Read a raw SAM public extract

<div class="ref-description section level2">

The extract is headerless, pipe-delimited, and unquoted; this reads it
and applies `np_sam_layout()` names.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_read_sam(path, layout = np_sam_layout())
```

</div>

</div>

<div class="section level2">

## Arguments

-   path:

    Path to the `.dat` file.

-   layout:

    Column names. Default `np_sam_layout()`.

</div>

<div class="section level2">

## Value

A `data.table`.

</div>

</div>
