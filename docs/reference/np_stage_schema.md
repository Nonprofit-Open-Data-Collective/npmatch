<div id="main" class="col-md-9" role="main">

# The shared outcome schema

<div class="ref-description section level2">

Every `stage*_yes` / `stage*_maybe` / `stage*_no` file carries these
columns, in this order, with exactly one row per source id. Identical
columns across every stage is what makes the rollup a plain `rbind()`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_stage_schema()
```

</div>

</div>

<div class="section level2">

## Value

A character vector of column names.

</div>

<div class="section level2">

## Details

Candidate-level and stage-specific detail lives in side tables joined by
`uei` — `stage1_k_candidates.csv` (one row per surfaced candidate) and
`stage3_research_findings.csv` (the full research record).

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_project_init()` for the directory layout these files live in.

</div>

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
np_stage_schema()
#>  [1] "uei"            "run_id"         "stage"          "outcome"       
#>  [5] "ein"            "name_source"    "name_reference" "score"         
#>  [9] "decided_by"     "confidence"     "reason"        
```

</div>

</div>

</div>
