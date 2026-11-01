<div id="main" class="col-md-9" role="main">

# Extract vetoed pairs for auditing and training

<div class="ref-description section level2">

Returns every candidate pair a veto rule fired on — the pairs
`np_select()` otherwise drops (hard) or demotes (soft). During
development this lets you confirm each rule fires only on genuine
non-matches, and it seeds the training set with rule-flagged negatives.
Hard vetoes are auto-labelled `FALSE` (do-not-match by rule); soft
vetoes get `label = NA` (inherently ambiguous — review them). If a
hard-vetoed row is actually a true match, the rule is too aggressive.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_veto_audit(pairs)
```

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    A vetoed `np_pairs` frame (after `np_veto()`).

</div>

<div class="section level2">

## Value

A data frame (class `np_veto_audit`) with `.id`, `.ein`, display names,
`score`, `severity`, `veto_rule`, and an auto `label`.

</div>

</div>
