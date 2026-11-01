<div id="main" class="col-md-9" role="main">

# Record and read the data-asset manifest

<div class="ref-description section level2">

The manifest is a small CSV under the data root that records the
provenance of every source and derived asset — what it is, where it came
from, when it was fetched, its checksum and row count. It is what makes
a run reproducible: documentation can point at exact vintages, and a
colleague can verify they hold the same bytes.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_manifest(root = np_data_root())

np_manifest_add(
  asset,
  tier = c("raw", "normalized", "results"),
  source = NA,
  url = NA,
  path = NULL,
  md5 = NA,
  row_count = NA,
  note = NA,
  root = np_data_root()
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   root:

    Data root. Defaults to `np_data_root()`.

-   asset:

    Short asset name (also the file's basename), e.g. `"bmf-2026-01"`.

-   tier:

    One of `"raw"`, `"normalized"`, `"results"`.

-   source:

    Human label of the origin (e.g. `"NCCS BMF catalog"`).

-   url:

    Download / origin URL.

-   path:

    Optional path to the file, used to auto-fill `md5` and `row_count`.

-   md5, row_count:

    Optional explicit checksum / row count (override `path`).

-   note:

    Free-text note.

</div>

<div class="section level2">

## Value

`np_manifest()` returns the manifest data frame; `np_manifest_add()`
returns it invisibly after writing.

</div>

<div class="section level2">

## Details

`np_manifest_add()` appends (or replaces, by `asset` name) one row; the
`md5` is computed with `tools::md5sum()` when `path` is given and `md5`
is not.

</div>

</div>
