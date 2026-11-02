# The shared outcome schema

Every `stage*_yes` / `stage*_maybe` / `stage*_no` file carries these
columns, in this order, with exactly one row per source id. Identical
columns across every stage is what makes the rollup a plain
[`rbind()`](https://rdrr.io/r/base/cbind.html).

## Usage

``` r
np_stage_schema()
```

## Value

A character vector of column names.

## Details

Candidate-level and stage-specific detail lives in side tables joined by
`uei` — `stage1_k_candidates.csv` (one row per surfaced candidate) and
`stage3_research_findings.csv` (the full research record).

## See also

[`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md)
for the directory layout these files live in.

## Examples

``` r
np_stage_schema()
#>  [1] "uei"            "run_id"         "stage"          "outcome"       
#>  [5] "ein"            "name_source"    "name_reference" "score"         
#>  [9] "decided_by"     "confidence"     "reason"        
```
