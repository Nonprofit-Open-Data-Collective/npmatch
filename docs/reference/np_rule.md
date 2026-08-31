# Build a veto rule

Build a veto rule

## Usage

``` r
np_rule(id, description, test, severity = c("hard", "soft"))
```

## Arguments

- id:

  Short rule identifier (recorded in the veto reason).

- description:

  Human-readable description.

- test:

  A function of the pair-level data frame returning a logical vector,
  `TRUE` where the pair violates the rule.

- severity:

  `"hard"` (force NO) or `"soft"` (cap at MAYBE).

## Value

A one-row `np_rules` data frame.
