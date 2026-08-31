# Default veto rule set

The do-not-match rules applied by
[`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md).
A rule is a predicate over the candidate-pair frame — both-sided
features are suffixed `_x` (query) and `_y` (reference) — plus a
`severity` that decides what a hit costs the pair.

## Usage

``` r
np_default_rules()

np_rule_legal_form()
```

## Value

A data frame (class `np_rules`) with columns `id`, `description`,
`severity`, and a list-column `test`.

## Details

The layer exists because fuzzy string similarity is at its worst exactly
where organization names differ by one short, decisive token. "First
Presbyterian Church" and "Second Presbyterian Church" are ~95% similar
as strings and are two different congregations; so are "Southwest
Community Center" and "Southeast Community Center", "UAW Local 32" and
"UAW Local 45", and an organization versus its fundraising foundation.
No amount of scorer tuning separates those — the one differing token is
drowned out by the agreeing ones. The rules below encode the token as a
constraint on identity instead, and are applied *after* scoring so they
can override a strong match.

## Severities

- **hard** — the pair is impossible, whatever the similarity.
  [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
  sets `veto` / `veto_reason`, and
  [`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
  drops the pair before choosing a best candidate, so that reference
  record is out of contention for the query. (Pass
  `include_vetoed = TRUE` to keep it and inspect why.)

- **soft** — the pair is plausible but wants a human.
  [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
  sets `veto_soft` / `veto_soft_reason`, the pair stays eligible, and if
  it *is* the selected match
  [`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
  caps it at MAYBE instead of auto-accepting. A soft veto never turns a
  MAYBE into a NO, and one on a pair that was not selected has no
  effect.

Both flags are accumulated independently and `;`-separated when several
rules of the same severity fire, so `veto_reason` is the full list of
hard hits, not just the first.

## The shipped rules

- `number_conflict` (hard):

  Both names carry embedded digit tokens and the two sets are disjoint —
  "Local 32" vs "Local 45", VFW Post 1234 vs Post 5678.
  Chapter/local/post/district numbers are identifiers, so a disjoint
  pair is a different unit of the same parent, not a typo.

- `ordinal_conflict` (hard):

  Ordinal markers present on both sides and disagreeing — "First
  Baptist" vs "Second Baptist". Matched on canonical rank, so FIRST and
  1ST are the same marker.

- `direction_conflict` (hard):

  Directional markers present on both sides and disagreeing — "Southwest
  Community Center" vs "Southeast Community Center". Word forms only;
  bare N/S/E/W are usually initials or street directionals and are not
  extracted.

- `forprofit_form` (hard):

  The **query's raw** legal name ends in a for-profit form — LLC, LP,
  LLP, PLLC, LLLP, "limited partnership". These forms are not used by
  exempt organizations, so the query is not the BMF record it resembles.
  Reads `name_raw_x` because normalization strips the legal suffix out
  of `name_key`.

- `affiliate_suffix` (soft):

  The candidate's last token is a subordinate-affiliate word —
  FOUNDATION, ENDOWMENT, AUXILIARY, BOOSTERS, BOOSTER — that the query
  name does not carry, on an otherwise strong name match
  (`name_key >= 0.95`). Query "Rend Lake College" matched to "Rend Lake
  College Foundation": the parent is absent from the reference and its
  fundraising arm absorbed the match. Often the right EIN in practice,
  so it is routed to review rather than rejected. If the query itself
  carries the token there is no conflict and the rule does not fire.

- `government_entity` (soft):

  The query's raw name matches a unit-of- government pattern: a leading
  "City/County/Town/Village/Township/Borough of ...", or a
  housing/redevelopment authority, school district, board of education,
  public library, council of governments, joint powers agency, or a
  water/sewer/fire/utility/conservancy-type special district. Almost
  never a 501(c) — but a few authorities (hospital authorities in
  particular) do file as exempt, so this is soft. The leading-anchor on
  the municipal pattern matters: "Columbia University in the City of New
  York" carries the phrase without being a municipality.

`forprofit_form` and `government_entity` fold what was a separate Tier-1
legal-form / entity screen into the cascade, so the decision is recorded
on the pair with a reason instead of silently removing the query up
front.

## The optional rule

`legal_form_conflict` (INC vs CORP vs LLC) is exported as
`np_rule_legal_form()` and ships **inactive** — the same organization is
routinely written both ways across sources, so enabling it costs recall.
Add it with `rbind(np_default_rules(), np_rule_legal_form())`.

## The generation predicates are vestigial

`.np_rule_generation()` and `.np_rule_generation_asym()` are internal,
unwired, and **not useful for this package**. They test person-name
generational suffixes — Jr vs Sr — which distinguish two *people*, not
two organizations. They are an artifact of npmatch's SAM / USASpending
person-matching lineage, carried over on a misreading of what the veto
layer is for, and they are the wrong thing to reach for when explaining
it.

The organization-level equivalents are the rules that actually ship:
`ordinal_conflict` is the real "First Presbyterian vs Second
Presbyterian" case, `direction_conflict` the regional one,
`number_conflict` the chapter/local one, and `affiliate_suffix` /
`forprofit_form` the legal-form-and-affiliation one. Cite those.

[`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md)
still emits `name_gen` / `name_gen_rank` (JR/SR only) and
[`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
still carries them through as pair features, so they appear in the
training frames and data dictionaries. Nothing consumes them, and they
are retained only so existing labeled extracts keep their column layout.

## See also

[`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
to apply a rule set,
[`np_rule()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_rule.md)
to write one,
[`np_veto_audit()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto_audit.md)
to check a rule's hits against labels, and
[`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
for how severity translates into a tier.
