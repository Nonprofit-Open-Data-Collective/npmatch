<div id="main" class="col-md-9" role="main">

# Sort selected matches into YES / MAYBE / NO tiers

<div class="ref-description section level2">

Applies the `config` thresholds to each query's overall match, then
holds back the high-scoring matches that are not safe to auto-accept.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_tier(selection, config = np_config())
```

</div>

</div>

<div class="section level2">

## Arguments

-   selection:

    An `np_selection` from `np_select()`.

-   config:

    An `np_config()` supplying `thresholds` and `min_margin`.

</div>

<div class="section level2">

## Value

`selection` with a `tier` factor (`YES` / `MAYBE` / `NO`) and the
`decision_score` used, of class `np_tiered`.

</div>

<div class="section level2">

## Details

The base tier is the score alone: `overall_score >= thresholds["yes"]`
-> YES, `>= thresholds["maybe"]` -> MAYBE, else NO. Two conditions then
demote a YES to MAYBE:

-   a **near-tie** with the runner-up (`overall_margin < min_margin`) —
    genuine ambiguity between two reference records that a reviewer must
    resolve;

-   a **soft veto** — `np_veto()` flagged the selected pair with a rule
    whose severity is `"soft"`.

View disagreement is *not* a gate: it is a signal that expands the
review candidate list (see `np_route()`), not a reason to demote a
clear, well-separated match.

</div>

<div class="section level2">

## How vetoes reach this stage

Vetoes are evaluated once, per candidate pair, by `np_veto()`, and reach
`np_tier()` through `np_select()` in two different ways:

-   **hard** vetoes (`veto` / `veto_reason`) never get here.
    `np_select()` drops hard-vetoed pairs before picking the best
    candidate (unless it was called with `include_vetoed = TRUE`), so a
    hard veto removes that reference record from contention entirely.
    The query still gets a tier — computed from whatever candidate
    survives, which may be a weaker one, or NO if none does.

-   **soft** vetoes (`veto_soft` / `veto_soft_reason`) stay eligible and
    are carried onto the selected row as `overall_veto_soft` /
    `overall_veto_reason`. `np_tier()` reads those two columns: a soft
    veto on the *selected* pair caps it at MAYBE. It never pushes a
    MAYBE down to NO, and a soft veto on a pair that was not selected
    has no effect.

The soft rules in the shipped rule set are `affiliate_suffix` (the
candidate ends in a subordinate-affiliate token — FOUNDATION / ENDOWMENT
/ AUXILIARY / BOOSTERS — that the query name does not carry, on an
otherwise strong name match) and `government_entity` (the query is a
municipality, school district, or special district). Both mean
"plausible, but a human should look". See `np_default_rules()` for the
full set and the hard rules, and `np_route()` for how the reason text is
surfaced to reviewers.

Note that the rule set is configurable, so which vetoes can fire depends
on `config$rules`; the description above is of `np_default_rules()`.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_veto()` and `np_default_rules()` for the rules themselves;
`np_route()` for what happens to each tier.

</div>

</div>

</div>
