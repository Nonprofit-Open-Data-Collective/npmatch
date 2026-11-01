<div id="main" class="col-md-9" role="main">

# Locate the active npmatch project

<div class="ref-description section level2">

Resolved from `getOption("npmatch.project")`, then the `NPMATCH_PROJECT`
environment variable. `np_project_init()` and `np_project_use()` set the
option, so the fetch helpers and stage functions can default their paths
into the run directory without the caller repeating it.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_project_root()
```

</div>

</div>

<div class="section level2">

## Value

The project root path, or `NA_character_` when none is active.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_project_use()` to point the session at an existing run.

</div>

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
old <- options(npmatch.project = tempdir())
np_project_root()
#> [1] "C:\\Users\\jdlec\\AppData\\Local\\Temp\\RtmpcDQvHQ"
options(old)
```

</div>

</div>

</div>
