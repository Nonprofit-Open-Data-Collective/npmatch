<div id="main" class="col-md-9" role="main">

# Fetch the reference BMF (pinned archive)

<div class="ref-description section level2">

Fetch the reference BMF (pinned archive)

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_fetch_bmf(
  which = c("unified", "processed", "dictionary"),
  dest = NULL,
  overwrite = FALSE,
  quiet = FALSE,
  ...
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   which:

    Which BMF file: `"unified"` (active+inactive), `"processed"` (active
    only), or `"dictionary"`.

-   dest, overwrite, quiet:

    Passed to `np_fetch()`.

</div>

<div class="section level2">

## Value

The destination path, invisibly.

</div>

</div>
