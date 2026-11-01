<div id="main" class="col-md-9" role="main">

# npmatch data asset directories

<div class="ref-description section level2">

npmatch keeps data outside the package (the reference files are large
and versioned separately). These helpers resolve and create a consistent
on-disk layout with three tiers:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_data_root()

np_data_path(subdir = "", file = NULL, create = FALSE)

np_data_init(root = np_data_root(), quiet = FALSE)
```

</div>

</div>

<div class="section level2">

## Arguments

-   subdir:

    One of `"raw"`, `"normalized"`, `"results"`, or `""` (the root).

-   file:

    Optional file name to append to the resolved directory.

-   create:

    Create the directory if it does not exist. Default `FALSE`.

-   root:

    Data root directory. Defaults to `np_data_root()`.

-   quiet:

    Suppress the informational message. Default `FALSE`.

</div>

<div class="section level2">

## Value

`np_data_root()` and `np_data_path()` return a path string;
`np_data_init()` returns the root invisibly.

</div>

<div class="section level2">

## Details

-   `raw/` — immutable source downloads (BMF, SAM extracts), one per
    vintage.

-   `normalized/` — reusable derived assets built once per source
    vintage (the normalized reference, the token-IDF table, the
    name-frequency table).

-   `results/` — per-run outputs (crosswalks, evaluation frames, run
    reports).

The root is resolved in order from `getOption("npmatch.data")`, the
`NPMATCH_DATA` environment variable, then a default of `~/npmatch-data`.

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
if (FALSE) { # \dontrun{
options(npmatch.data = tempfile("npdata"))
np_data_init()
np_data_path("normalized", "reference-2026-01.rds")
} # }
```

</div>

</div>

</div>
