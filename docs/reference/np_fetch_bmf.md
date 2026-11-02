# Fetch the reference BMF (pinned archive)

Fetch the reference BMF (pinned archive)

## Usage

``` r
np_fetch_bmf(
  which = c("unified", "processed", "dictionary"),
  dest = NULL,
  overwrite = FALSE,
  quiet = FALSE,
  ...
)
```

## Arguments

- which:

  Which BMF file: `"unified"` (active+inactive), `"processed"` (active
  only), or `"dictionary"`.

- dest, overwrite, quiet:

  Passed to
  [`np_fetch()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch.md).

## Value

The destination path, invisibly.
