# Download a data file

Thin wrapper over
[`utils::download.file()`](https://rdrr.io/r/utils/download.file.html)
with sensible defaults for large files (binary mode, long timeout,
resumable skip). Records the download in the data
[`np_manifest()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_manifest.md)
when `manifest = TRUE`.

## Usage

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

## Arguments

- url:

  File URL.

- dest:

  Destination path. Default: `raw/<basename>` under the data root.

- overwrite:

  Re-download if the destination already exists. Default `FALSE`.

- manifest:

  Record the download in the manifest. Default `TRUE`.

- timeout:

  Download timeout in seconds. Default 3600.

- method:

  Download method passed to
  [`utils::download.file()`](https://rdrr.io/r/utils/download.file.html).
  Default `"auto"` (R picks a working transport); override with
  `"libcurl"`, `"curl"`, or `"wininet"` if needed.

- quiet:

  Suppress progress. Default `FALSE`.

## Value

The destination path, invisibly.
