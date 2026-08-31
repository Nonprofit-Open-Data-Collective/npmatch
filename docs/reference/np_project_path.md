# Build a path inside the active project

Build a path inside the active project

## Usage

``` r
np_project_path(
  stage = "",
  file = NULL,
  create = FALSE,
  project = np_project_root()
)
```

## Arguments

- stage:

  Stage directory: a canonical name (`"01_stage1"`), a short alias
  (`"stage1"`, `"bmf"`, `"final"`), or `""` for the project root.

- file:

  Optional path below the stage directory, e.g. `"stage1_yes.csv"` or
  `"batches/shards"`.

- create:

  Create the directory (of `stage`, or of `file`'s parent) if it does
  not exist. Default `FALSE`.

- project:

  Project root. Defaults to
  [`np_project_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_root.md).

## Value

A path string.

## See also

[`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md),
[`np_project_use()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_use.md).

## Examples

``` r
old <- options(npmatch.project = "P:/runs/2026MAY")
np_project_path("stage1", "stage1_yes.csv")
#> [1] "P:/runs/2026MAY/01_stage1/stage1_yes.csv"
np_project_path("03_stage3", "batches/packets")
#> [1] "P:/runs/2026MAY/03_stage3/batches/packets"
options(old)
```
