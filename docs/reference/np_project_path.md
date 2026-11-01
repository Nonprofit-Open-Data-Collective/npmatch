<div id="main" class="col-md-9" role="main">

# Build a path inside the active project

<div class="ref-description section level2">

Build a path inside the active project

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_project_path(
  stage = "",
  file = NULL,
  create = FALSE,
  project = np_project_root()
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   stage:

    Stage directory: a canonical name (`"01_stage1"`), a short alias
    (`"stage1"`, `"bmf"`, `"final"`), or `""` for the project root.

-   file:

    Optional path below the stage directory, e.g. `"stage1_yes.csv"` or
    `"batches/shards"`.

-   create:

    Create the directory (of `stage`, or of `file`'s parent) if it does
    not exist. Default `FALSE`.

-   project:

    Project root. Defaults to `np_project_root()`.

</div>

<div class="section level2">

## Value

A path string.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_project_init()`, `np_project_use()`.

</div>

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
old <- options(npmatch.project = "P:/runs/2026MAY")
np_project_path("stage1", "stage1_yes.csv")
#> [1] "P:/runs/2026MAY/01_stage1/stage1_yes.csv"
np_project_path("03_stage3", "batches/packets")
#> [1] "P:/runs/2026MAY/03_stage3/batches/packets"
options(old)
```

</div>

</div>

</div>
