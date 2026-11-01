<div id="main" class="col-md-9" role="main">

# Apply veto rules to candidate pairs

<div class="ref-description section level2">

Flags pairs that violate a do-not-match rule. Runs *after* scoring, so a
rule can override a strong fuzzy match: the rules encode facts about
identity that string similarity cannot see (a chapter number, a
for-profit legal form), rather than adjusting the score. Every rule in
`config$rules` is evaluated on every pair — there is no short-circuit —
and the hits are accumulated by severity into four new columns:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_veto(pairs, config = np_config())
```

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    An `np_pairs` frame (typically already scored).

-   config:

    An `np_config()` whose `rules` are applied. Defaults to
    `np_default_rules()`; supply your own with
    `np_config(rules = rbind(np_default_rules(), np_rule(...)))`.

</div>

<div class="section level2">

## Value

`pairs` with the four veto columns.

</div>

<div class="section level2">

## Details

-   `veto` (logical) / `veto_reason` (character) — any **hard** rule
    fired.

-   `veto_soft` / `veto_soft_reason` — any **soft** rule fired.

The two are independent: a pair can carry both. When several rules of
the same severity fire, their ids are joined with `;` in the reason
column; `NA` means no rule of that severity fired. A rule that errors is
caught and treated as no-hit for every row, so a malformed custom rule
degrades rather than aborting the run. Rules with a missing `severity`
are treated as hard.

What each severity costs the pair happens downstream, not here —
`np_select()` drops hard-vetoed pairs from candidate selection, and
`np_tier()` caps a soft-vetoed selected pair at MAYBE. See
`np_default_rules()` for the shipped rules and the reasoning behind
each.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_default_rules()`, `np_rule()`, `np_veto_audit()`.

</div>

</div>

</div>
