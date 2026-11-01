<div id="main" class="col-md-9" role="main">

# Point the session at an existing project

<div class="ref-description section level2">

Point the session at an existing project

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_project_use(path, quiet = FALSE)
```

</div>

</div>

<div class="section level2">

## Arguments

-   path:

    An existing project root created by `np_project_init()`.

-   quiet:

    Suppress the confirmation message. Default `FALSE`.

</div>

<div class="section level2">

## Value

The path, invisibly.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_project_init()`, `np_project_status()`.

</div>

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
if (FALSE) { # \dontrun{
np_project_use("runs/2026MAY")
} # }
```

</div>

</div>

</div>
