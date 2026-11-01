<div id="main" class="col-md-9" role="main">

# Fetch a SAM extract (pinned archive or a URL you supply)

<div class="ref-description section level2">

Downloads the raw pipe-delimited SAM `.dat`. It still needs filtering to
nonprofits and column naming before matching — see `np_prepare_sam()`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_fetch_sam(url = NULL, dest = NULL, overwrite = FALSE, quiet = FALSE, ...)
```

</div>

</div>

<div class="section level2">

## Arguments

-   url:

    SAM extract URL. Defaults to the pinned archive extract.

-   dest, overwrite, quiet:

    Passed to `np_fetch()`.

</div>

<div class="section level2">

## Value

The destination path, invisibly.

</div>

</div>
