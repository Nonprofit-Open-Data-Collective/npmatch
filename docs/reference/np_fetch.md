<div id="main" class="col-md-9" role="main">

# Download a data file

<div class="ref-description section level2">

Thin wrapper over `utils::download.file()` with sensible defaults for
large files (binary mode, long timeout, resumable skip). Records the
download in the data `np_manifest()` when `manifest = TRUE`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_fetch(
  url,
  dest = NULL,
  overwrite = FALSE,
  manifest = TRUE,
  timeout = 3600,
  method = "auto",
  quiet = FALSE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   url:

    File URL.

-   dest:

    Destination path. Default: `raw/<basename>` under the data root.

-   overwrite:

    Re-download if the destination already exists. Default `FALSE`.

-   manifest:

    Record the download in the manifest. Default `TRUE`.

-   timeout:

    Download timeout in seconds. Default 3600.

-   method:

    Download method passed to `utils::download.file()`. Default `"auto"`
    (R picks a working transport); override with `"libcurl"`, `"curl"`,
    or `"wininet"` if needed.

-   quiet:

    Suppress progress. Default `FALSE`.

</div>

<div class="section level2">

## Value

The destination path, invisibly.

</div>

</div>
