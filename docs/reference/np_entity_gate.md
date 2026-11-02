# Classify source records before research

Applies
[`np_gate_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_gate_rules.md)
to decide what kind of entity each source record is, from its legal name
and SAM structure code alone. This is the screen that settles most NO
cases without any lookup.

## Usage

``` r
np_entity_gate(
  data,
  name = "name",
  state = "state",
  structure = NULL,
  state_incorp = NULL,
  rules = np_gate_rules()
)
```

## Arguments

- data:

  A data frame of source records.

- name, state:

  Columns holding the legal name and the physical-address state. `name`
  is required.

- structure, state_incorp:

  Optional columns holding the SAM entity structure code and the state
  of incorporation. Without `structure`, the `individual` and
  `not_tax_exempt_corp` categories cannot fire.

- rules:

  Rule set. Defaults to
  [`np_gate_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_gate_rules.md).

## Value

`data` with `entity_gate` and `foreign_us_incorp` appended.

## Details

Categories are assigned in priority order: `foreign`, `individual`,
`government`, `tribal_government`, `for_profit_form`,
`not_tax_exempt_corp`, `church`, then `nonprofit_candidate` for anything
left. The order matters — a foreign government unit is reported as
foreign, because being outside the BMF's scope is the more basic fact
about it.

## See also

[`np_gate_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_gate_rules.md),
[`np_stage3_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage3_run.md).

## Examples

``` r
d <- data.frame(name = c("ACME HOLDINGS LLC", "CITY OF AUSTIN",
                         "FIRST BAPTIST CHURCH", "RIVER ARTS COUNCIL"),
                state = "TX")
np_entity_gate(d)$entity_gate
#> [1] "for_profit_form"     "government"          "church"             
#> [4] "nonprofit_candidate"
```
