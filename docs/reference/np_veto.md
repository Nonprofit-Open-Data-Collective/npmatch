# Apply veto rules to candidate pairs

Flags pairs that violate a do-not-match rule. Runs *after* scoring, so a
rule can override a strong fuzzy match: the rules encode facts about
identity that string similarity cannot see (a chapter number, a
for-profit legal form), rather than adjusting the score. Every rule in
`config$rules` is evaluated on every pair — there is no short-circuit —
and the hits are accumulated by severity into four new columns:

## Usage

``` r
np_veto(pairs, config = np_config())
```

## Arguments

- pairs:

  An `np_pairs` frame (typically already scored).

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md)
  whose `rules` are applied. Defaults to
  [`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md);
  supply your own with
  `np_config(rules = rbind(np_default_rules(), np_rule(...)))`.

## Value

`pairs` with the four veto columns.

## Details

- `veto` (logical) / `veto_reason` (character) — any **hard** rule
  fired.

- `veto_soft` / `veto_soft_reason` — any **soft** rule fired.

The two are independent: a pair can carry both. When several rules of
the same severity fire, their ids are joined with `;` in the reason
column; `NA` means no rule of that severity fired. A rule that errors is
caught and treated as no-hit for every row, so a malformed custom rule
degrades rather than aborting the run. Rules with a missing `severity`
are treated as hard.

What each severity costs the pair happens downstream, not here —
[`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
drops hard-vetoed pairs from candidate selection, and
[`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
caps a soft-vetoed selected pair at MAYBE. See
[`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md)
for the shipped rules and the reasoning behind each.

## See also

[`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md),
[`np_rule()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_rule.md),
[`np_veto_audit()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto_audit.md).
