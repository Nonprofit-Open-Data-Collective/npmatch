<div id="main" class="col-md-9" role="main">

# Entity-gate rules

<div class="ref-description section level2">

The patterns `np_entity_gate()` uses to classify a source record from
its legal name and SAM structure code, before any lookup. Returned as
data so they can be inspected, edited and passed back in.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_gate_rules()
```

</div>

</div>

<div class="section level2">

## Value

A named list of patterns.

</div>

<div class="section level2">

## Details

Each element is a case-insensitive regular expression matched against
the upper-cased legal name, except `us_states` (the set treated as
domestic) and `structure_*` (exact SAM entity-structure codes).

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_entity_gate()`, `np_stage3_run()`.

</div>

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
names(np_gate_rules())
#> [1] "us_states"            "structure_individual" "structure_not_exempt"
#> [4] "for_profit_form"      "government"           "tribal"              
#> [7] "church"               "person_name"          "person_not"          
np_gate_rules()$tribal
#> [1] "\\b(TRIBE|TRIBAL|NATION OF|BAND OF|PUEBLO OF|RANCHERIA|NATIVE VILLAGE)\\b"
```

</div>

</div>

</div>
