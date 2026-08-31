# Point the session at an existing project

Point the session at an existing project

## Usage

``` r
np_project_use(path, quiet = FALSE)
```

## Arguments

- path:

  An existing project root created by
  [`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md).

- quiet:

  Suppress the confirmation message. Default `FALSE`.

## Value

The path, invisibly.

## See also

[`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md),
[`np_project_status()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_status.md).

## Examples

``` r
if (FALSE) { # \dontrun{
np_project_use("runs/2026MAY")
} # }
```
