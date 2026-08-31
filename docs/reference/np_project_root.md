# Locate the active npmatch project

Resolved from `getOption("npmatch.project")`, then the `NPMATCH_PROJECT`
environment variable.
[`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md)
and
[`np_project_use()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_use.md)
set the option, so the fetch helpers and stage functions can default
their paths into the run directory without the caller repeating it.

## Usage

``` r
np_project_root()
```

## Value

The project root path, or `NA_character_` when none is active.

## See also

[`np_project_use()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_use.md)
to point the session at an existing run.

## Examples

``` r
old <- options(npmatch.project = tempdir())
np_project_root()
#> [1] "C:\\Users\\jdlec\\AppData\\Local\\Temp\\RtmpW0OTGG"
options(old)
```
