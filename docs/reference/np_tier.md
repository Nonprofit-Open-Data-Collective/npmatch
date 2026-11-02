# Sort selected matches into YES / MAYBE / NO tiers

Applies the `config` thresholds to each query's overall match, then
holds back the high-scoring matches that are not safe to auto-accept.

## Usage

``` r
np_tier(selection, config = np_config())
```

## Arguments

- selection:

  An `np_selection` from
  [`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md).

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md)
  supplying `thresholds` and `min_margin`.

## Value

`selection` with a `tier` factor (`YES` / `MAYBE` / `NO`) and the
`decision_score` used, of class `np_tiered`.

## Details

The base tier is the score alone: `overall_score >= thresholds["yes"]`
-\> YES, `>= thresholds["maybe"]` -\> MAYBE, else NO. Two conditions
then demote a YES to MAYBE:

- a **near-tie** with the runner-up (`overall_margin < min_margin`) —
  genuine ambiguity between two reference records that a reviewer must
  resolve;

- a **soft veto** —
  [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
  flagged the selected pair with a rule whose severity is `"soft"`.

View disagreement is *not* a gate: it is a signal that expands the
review candidate list (see
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)),
not a reason to demote a clear, well-separated match.

## How vetoes reach this stage

Vetoes are evaluated once, per candidate pair, by
[`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md),
and reach `np_tier()` through
[`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
in two different ways:

- **hard** vetoes (`veto` / `veto_reason`) never get here.
  [`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
  drops hard-vetoed pairs before picking the best candidate (unless it
  was called with `include_vetoed = TRUE`), so a hard veto removes that
  reference record from contention entirely. The query still gets a tier
  — computed from whatever candidate survives, which may be a weaker
  one, or NO if none does.

- **soft** vetoes (`veto_soft` / `veto_soft_reason`) stay eligible and
  are carried onto the selected row as `overall_veto_soft` /
  `overall_veto_reason`. `np_tier()` reads those two columns: a soft
  veto on the *selected* pair caps it at MAYBE. It never pushes a MAYBE
  down to NO, and a soft veto on a pair that was not selected has no
  effect.

The soft rules in the shipped rule set are `affiliate_suffix` (the
candidate ends in a subordinate-affiliate token — FOUNDATION / ENDOWMENT
/ AUXILIARY / BOOSTERS — that the query name does not carry, on an
otherwise strong name match) and `government_entity` (the query is a
municipality, school district, or special district). Both mean
"plausible, but a human should look". See
[`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md)
for the full set and the hard rules, and
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
for how the reason text is surfaced to reviewers.

Note that the rule set is configurable, so which vetoes can fire depends
on `config$rules`; the description above is of
[`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md).

## See also

[`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
and
[`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md)
for the rules themselves;
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
for what happens to each tier.
