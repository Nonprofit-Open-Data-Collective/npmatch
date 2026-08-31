# Configuration for a linkage run

Bundles the comparators, per-field weights, tier thresholds, and active
veto rule set so a run is reproducible and tunable. Weights are supplied
per geo profile;
[`np_detect_geo()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_detect_geo.md)
picks the profile at run time and
[`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
uses the matching weight vector. Weights need not sum to 1 — they are
normalised internally.

## Usage

``` r
np_config(
  weights = np_default_weights(),
  thresholds = c(yes = 0.78, maybe = 0.65),
  min_margin = 0.05,
  tie_band = 0.05,
  tie_high = 0.95,
  tiebreak = "name",
  distinct_name_maxfreq = 3,
  distinct_name_min_idf = 0,
  distinct_name_main_only = TRUE,
  distinct_name_floor = 0.9,
  distinct_name_floor_xstate = 0.72,
  overlap_maybe_floor = 0.8,
  name_comparator = "jaro_winkler",
  addr_comparator = "jaro_winkler",
  jw_threshold = 0.85,
  rules = np_default_rules(),
  geo_weights = np_default_geo_weights(),
  name_geo = c(name = 0.6, geo = 0.4)
)
```

## Arguments

- weights:

  Named list mapping geo-profile name to a named numeric vector of field
  weights. Fields absent from a profile are ignored.

- thresholds:

  Named numeric of length 2, `yes` and `maybe`, on the 0-1 score scale.
  `score >= yes` -\> YES; `>= maybe` -\> MAYBE; else NO.

- min_margin:

  Minimum lead the best match must have over the runner-up (next-best
  distinct entity) to be auto-accepted. A near-tie
  (`margin < min_margin`) is held at MAYBE for disambiguation even above
  `yes`.

- tie_band:

  Score window below the top candidate within which other candidates
  count as "tied" (used to flag 2-3 close candidates).

- tie_high:

  When tied candidates are all at or above this score, the tie is broken
  by the `tiebreak` rule instead of the combined score.

- tiebreak:

  How to break a high tie: `"name"` picks the tied candidate with the
  highest name similarity (address is uninformative when several strong
  candidates exist); `"none"` keeps the combined-score pick.

- distinct_name_maxfreq, distinct_name_floor:

  Distinctive-name promotion (hier scoring): an exact name match on a
  name shared by at most `distinct_name_maxfreq` reference records is
  trusted even without address corroboration, its score floored up to
  `distinct_name_floor`.

- distinct_name_min_idf:

  Minimum summed token IDF the reference name must carry to be eligible
  for the distinctive-name promotion. Defaults to `0`, i.e.
  **disabled**: it was added on the theory that `distinct_name_maxfreq`
  measures lexical rarity rather than identifying power, but measured on
  990-PF grants it moved only 2 matches, net zero. The theory was right
  and the target was wrong – the reference legal names behind the
  generic-name errors are not generic at all
  (`FORT JONES COMMUNITY CHURCH`, `CHRIST CHURCH OF BEAVER SPRINGS`);
  the matches had been made on those records' short generic DBAs.
  `distinct_name_main_only` is the fix that works. Retained because the
  mechanism is sound and may suit another reference; has no effect
  unless `token_idf` was supplied to
  [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md).

- distinct_name_main_only:

  Restrict the distinctive-name promotion to matches made on the
  reference's PRIMARY name. `name_freq` and `name_idf` describe that
  primary name, but
  [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
  keeps the best of the name/DBA/division cross-product, so a match made
  on a DBA is justified by statistics about a different string. A DBA is
  often a short generic trade name whose rarity means nothing. Has no
  effect unless the pairs carry `name_ver_y`.

- distinct_name_floor_xstate:

  Lower promotion floor applied when the distinctive-name match is *not*
  state-confirmed (query and candidate in different states, or no state
  to compare). Cross-state exact-name-only matches are far less reliable
  than same-state ones, so they are floored to this lower value (landing
  in MAYBE for review) rather than `distinct_name_floor`.

- overlap_maybe_floor:

  Minimum token-overlap name score for a containment/acronym recovery
  match to be floored to the MAYBE tier. Such matches (found only via
  token overlap, not JW/DBA) are always capped below YES – containment
  cannot separate a parent from a subsidiary or chapter – so they
  surface for review rather than auto-accepting.

- name_comparator, addr_comparator:

  reclin2 comparator constructors used for name-like and address-like
  fields respectively.

- jw_threshold:

  Jaro-Winkler floor passed to the comparators; per-field similarities
  below this are set to 0 (reduces noise from unrelated pairs).

- rules:

  A veto rule set as returned by
  [`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md)
  (or a user-extended version).

- geo_weights:

  Named numeric of location-granularity credits used by
  `np_score(method = "hier")` (see
  [`np_default_geo_weights()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_geo_weights.md)).

- name_geo:

  Named numeric `c(name=, geo=)` splitting the hierarchical score
  between the name and the geo sub-score. Should sum to 1.

## Value

An object of class `np_config`.
