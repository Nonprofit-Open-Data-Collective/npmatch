# Report the status of a run project

Scans the project directory and reports, per stage, whether it has run
and what it produced. This is a **scanner, not a ledger**: it reads what
is on disk every time, so it cannot drift out of sync with reality the
way a stored state file would. Deleting an output makes the stage report
as incomplete on the next call.

## Usage

``` r
np_project_status(project = np_project_root(), write = TRUE, quiet = FALSE)
```

## Arguments

- project:

  Project root. Defaults to
  [`np_project_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_root.md).

- write:

  Write `RUN-STATUS.md` at the project root. Default `TRUE`.

- quiet:

  Suppress the printed summary. Default `FALSE`.

## Value

A data frame with one row per expected output (`stage`, `file`,
`exists`, `rows`, `modified`), invisibly. The per-stage roll-up is
carried in the `stages` attribute.

## Details

A stage is `complete` when every expected output in the layout is
present, `partial` when some are, and `not run` when none are.

## See also

[`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md).

## Examples

``` r
p <- file.path(tempdir(), "run-status-demo")
np_project_init(p, run_id = "demo", quiet = TRUE, use = FALSE)
s <- np_project_status(p, write = FALSE, quiet = TRUE)
attr(s, "stages")[, c("stage", "status")]
#>       stage  status
#> 1    00_bmf not run
#> 2   00_sams not run
#> 3 01_stage1 not run
#> 4 02_stage2 not run
#> 5 03_stage3 not run
#> 6  04_final not run
unlink(p, recursive = TRUE)
```
