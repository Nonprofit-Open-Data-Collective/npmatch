# Fetch a SAM extract (pinned archive or a URL you supply)

Downloads the raw pipe-delimited SAM `.dat`. It still needs filtering to
nonprofits and column naming before matching — see
[`np_prepare_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_prepare_sam.md).

## Usage

``` r
np_fetch_sam(url = NULL, dest = NULL, overwrite = FALSE, quiet = FALSE, ...)
```

## Arguments

- url:

  SAM extract URL. Defaults to the pinned archive extract.

- dest, overwrite, quiet:

  Passed to
  [`np_fetch()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch.md).

## Value

The destination path, invisibly.
