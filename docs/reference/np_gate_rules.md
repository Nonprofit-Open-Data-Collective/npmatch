# Entity-gate rules

The patterns
[`np_entity_gate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_entity_gate.md)
uses to classify a source record from its legal name and SAM structure
code, before any lookup. Returned as data so they can be inspected,
edited and passed back in.

## Usage

``` r
np_gate_rules()
```

## Value

A named list of patterns.

## Details

Each element is a case-insensitive regular expression matched against
the upper-cased legal name, except `us_states` (the set treated as
domestic) and `structure_*` (exact SAM entity-structure codes).

## See also

[`np_entity_gate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_entity_gate.md),
[`np_stage3_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage3_run.md).

## Examples

``` r
names(np_gate_rules())
#> [1] "us_states"            "structure_individual" "structure_not_exempt"
#> [4] "for_profit_form"      "government"           "tribal"              
#> [7] "church"               "person_name"          "person_not"          
np_gate_rules()$tribal
#> [1] "\\b(TRIBE|TRIBAL|NATION OF|BAND OF|PUEBLO OF|RANCHERIA|NATIVE VILLAGE)\\b"
```
