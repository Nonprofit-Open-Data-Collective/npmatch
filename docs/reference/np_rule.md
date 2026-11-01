<div id="main" class="col-md-9" role="main">

# Build a veto rule

<div class="ref-description section level2">

Build a veto rule

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_rule(id, description, test, severity = c("hard", "soft"))
```

</div>

</div>

<div class="section level2">

## Arguments

-   id:

    Short rule identifier (recorded in the veto reason).

-   description:

    Human-readable description.

-   test:

    A function of the pair-level data frame returning a logical vector,
    `TRUE` where the pair violates the rule.

-   severity:

    `"hard"` (force NO) or `"soft"` (cap at MAYBE).

</div>

<div class="section level2">

## Value

A one-row `np_rules` data frame.

</div>

</div>
