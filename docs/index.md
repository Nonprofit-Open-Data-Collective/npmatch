# npmatch

A package for matching nonprofit organizations to the IRS BMF database
when EINs are not available.

## Package Overview

`npmatch` builds a crosswalk from arbitrary source organization records
(name + variable geographic detail) to the IRS Business Master File
(BMF). It is a two-part process: match as much as possible
**algorithmically** using only information in the BMF, then hand the
residual (MAYBE / NO cases) to humans or LLM agents for investigation.

The pipeline is a sequence of stages, orchestrated end-to-end by
[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
(scalable, multi-pass) or
[`np_match()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_match.md)
(single-pass). Each stage below lists the internal subroutines it calls
and the ordered process steps, with the function that performs each step
noted as `:: fx()`.

    raw data -> np_normalize -> np_block -> np_compare -> np_score -> np_veto -> np_select -> np_tier -> np_route

### Raw data sources

- **USASpending / SAM organizations** — the query (source) side. Key
  fields: `legal_business_name`, `dba_name`, `entity_division_name`,
  physical address, and the Unique Entity Identifier (`uei`).
- **Standardized IRS EO Business Master File (BMF)** — from NCCS; the
  reference (candidate) side, keyed by `ein`. Carries `org_name_join`,
  `dba_name`, address, NTEE, 501(c) subsection, foundation code, ruling
  date, assets/revenue, filing requirement, affiliation and
  group-exemption codes.

### `np_query(df, map)` / `np_reference(df, map)` — canonicalize

Rename raw source columns onto the canonical schema so every downstream
stage works on common column names.

**subroutines**

- `.np_canonicalize()` :: apply a schema map
  ([`np_map_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)
  /
  [`np_map_bmf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md))
  that maps canonical fields (`name`, `dba`, `division`, `street`,
  `city`, `state`, `zip5`, `.id`/`.ein`) to source columns

**process:**

1.  map each source column onto its canonical field ::
    `.np_canonicalize()`
2.  fill any unmapped canonical field with `NA` and squish white space
    :: `.np_canonicalize()`

### `np_normalize(df)` — clean, standardize, and extract features

Brings names and addresses onto a common matchable form and extracts the
token-level features the veto layer needs. Adds `name_key`, `dba_key`,
`division_key`, `name_full`, `name_form`, `name_gen`, `name_nums`,
`name_ord`, `name_dir`, `street_key`, `street_num/name/type/unit`,
`is_po_box`, `zip5/zip3/zip9`, `state_abb`.

**subroutines**

- `.np_basic_clean()` :: uppercase, de-accent, `&` -\> `AND`, strip
  punctuation, squish space
- `.np_replace_tokens(dict)` :: whole-word dictionary substitution
  (abbreviations, USPS types)
- `.np_strip_lead_the()` :: drop a single leading `THE`
- `.np_strip_suffix()` :: strip trailing legal suffixes to form the
  match key
- `.np_extract_form()` / `.np_canon_form()` :: detect and canonicalize
  the legal form
- `.np_extract_generation()` :: JR / SR marker — **vestigial**, a
  person-name concept from the SAM/USASpending lineage; nothing consumes
  it
- `.np_extract_numbers()` :: embedded digit tokens (chapter / local
  numbers)
- `.np_extract_ordinals()` :: FIRST / SECOND / … -\> canonical rank
- `.np_extract_direction()` :: NORTH / SOUTHWEST / … -\> N / SW
- `.np_street_key()` :: cleaned street with unit dropped and USPS types
  standardized
- `.np_extract_unit()` :: pull the suite / apt / unit token
- `.np_is_pobox()` :: detect PO-box variants (`PO BOX`, `POB`, `P O`,
  `BOX`, …)
- `.np_parse_street()` :: split the street key into number / name / type
- `.np_parse_zip()` :: build the nested `zip3` \< `zip5` \< `zip9`
  family, restoring leading zeros
- `.np_to_state_abb()` :: map a full state name to its 2-letter code

**process (name):**

1.  convert name to upper case :: `.np_basic_clean()`
2.  de-accent to ASCII (`N~` -\> `N`) :: `.np_basic_clean()`
3.  expand `&` to `AND` :: `.np_basic_clean()`
4.  strip punctuation, keep `A-Z 0-9` only :: `.np_basic_clean()`
5.  squish repeated white space :: `.np_basic_clean()`
6.  expand abbreviations whole-word (`NATL` -\> `NATIONAL`, `ST` -\>
    `SAINT`, `CTR` -\> `CENTER`, …) :: `.np_replace_tokens(.np_abbrev)`
    -\> **`name_full`**
7.  remove a leading `THE` :: `.np_strip_lead_the()`
8.  strip trailing legal suffixes (`INC`, `CORP`, `LLC`, `FOUNDATION`,
    `TRUST`, …) :: `.np_strip_suffix()` -\> **`name_key`** (the match
    key)
9.  apply the same normalization to the DBA name -\> **`dba_key`** and
    to the division name -\> **`division_key`**
10. detect and record the legal form (`INC` / `LLC` / `CORP` / …) —
    stripped but held for the veto layer :: `.np_extract_form()`
11. record embedded numbers, ordinals, and directional markers for veto
    tests :: `.np_extract_numbers()`, `.np_extract_ordinals()`,
    `.np_extract_direction()` (`.np_extract_generation()` also runs, but
    `name_gen` is vestigial — see below)

**process (address):**

1.  clean the street, drop the unit portion, standardize USPS street
    types (`STREET` -\> `ST`) :: `.np_street_key()`
2.  extract the unit (`STE` / `APT` / `#`) :: `.np_extract_unit()`
3.  flag PO-box addresses :: `.np_is_pobox()`
4.  split the street into house number / street name / street type ::
    `.np_parse_street()`
5.  parse the ZIP: restore dropped leading zeros, derive `zip5` and its
    `zip3` prefix, and build `zip9` from the +4 add-on ::
    `.np_parse_zip()`
6.  map the state to a 2-letter code (pass through valid codes,
    translate full names) :: `.np_to_state_abb()`

### `np_block(query, reference)` — generate candidate pairs

Produces only the (query, reference) pairs worth comparing, so
[`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
never scores every same-state pair. This is where **inverse document
frequency (IDF) tokenization** lives.

**subroutines**

- `.np_bykey()` :: build a composite exact-block key (e.g. `state`, or
  `state` + `name_key`)
- [`np_stopwords()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stopwords.md)
  :: the non-discriminating tokens dropped before token blocking
- [`np_token_idf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_token_idf.md)
  :: per-token IDF, `log(N / df)`, over the reference corpus

**process:**

1.  build candidate pairs that share an exact block key (hash join), OR
    tokenize each name and index it, dropping stopwords and
    sub-2-character tokens :: `idx_of()`
2.  drop corpus-common tokens whose reference document frequency exceeds
    `max_ref_freq`
3.  **tokenize by inverse document frequency**: keep a pair only when
    the sum of its shared tokens’ IDF clears `min_pair_idf`, so one rare
    token (or several moderately common ones) justifies a pair but a
    lone common token (e.g. `CALIFORNIA`, `CHURCH`) does not
4.  de-duplicate the pairs from several passes ::
    [`np_block_union()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block_union.md)

[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
runs blocking as **progressive passes** — exact name, exact name/DBA,
exact DBA/name, exact DBA/DBA, shared-token same-state, shared-token
cross-state — pruning each query out of later (looser, costlier) passes
once it is resolved (**residual pruning**).

### `np_compare(query, reference)` — per-field similarity

**subroutines**

- [`reclin2::compare_pairs()`](https://rdrr.io/pkg/reclin2/man/compare_pairs.html)
  with `cmp_jarowinkler()` / `cmp_identical()` :: per-field comparison
- `.np_name_overlap()` :: token-set + acronym-aware overlap
  (word-reorder, `EMS` \<-\> `Emergency Medical Service`)
- `.np_collapse_initials()` :: collapse single-letter runs (`F O R` -\>
  `FOR`)
- [`np_name_freq()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_name_freq.md)
  :: how many reference records share a normalized name

**process:**

1.  compare the name on `name_key` with Jaro-Winkler ::
    `cmp_jarowinkler()`
2.  floor fuzzy similarities below `jw_threshold` to 0 (Winkler is a
    prefix *boost*, not a cutoff)
3.  compare geo fields — fuzzy city/street (JW) and exact ZIP ::
    `cmp_jarowinkler()` / `cmp_identical()`
4.  compute exact geo signals: ZIP9 / ZIP5 / ZIP3 / state /
    street-number / PO-box matches :: `exact()`
5.  effective name similarity = best of the name / DBA / division
    cross-products (name vs name, name vs DBA, DBA vs name, DBA vs DBA,
    division vs name, division vs DBA)
6.  name-blind recovery: token-set + acronym overlap when JW and DBA
    both score 0 **and** the address is confirmed ::
    `.np_name_overlap()`
7.  record which name **version** matched on each side (`main` / `dba` /
    `division` / `token_overlap` / `none`)
8.  compute the name distinctiveness count (`normalized_match_count`) ::
    [`np_name_freq()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_name_freq.md)

### `np_score(pairs, method = "hier")` — combine into one score

**subroutines**

- `.np_hier_score()` :: name similarity + a hierarchical geo sub-score

**process:**

1.  name sub-score = the effective name similarity from
    [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
2.  geo sub-score = the **strongest confirmed** location granularity via
    `max`, not a sum
    (`ZIP9 > street > ZIP5 > PO box > ZIP3 > city > state`), so
    correlated address fields are not double-counted ::
    `.np_hier_score()`
3.  combine: `score = 0.6 * name + 0.4 * geo`
4.  distinctive-exact-name promotion: an exact match on a rare name is
    floored up so it auto-accepts without address corroboration —
    **state-aware**: cross-state name-only matches get a lower floor and
    land in MAYBE for review :: `.np_hier_score()`

### `np_veto(pairs)` — do-not-match rules

**subroutines**

- `.np_rule_number()` / `.np_rule_ordinal()` / `.np_rule_direction()` /
  `.np_rule_forprofit()` :: hard predicates
- `.np_rule_affiliate_suffix()` / `.np_rule_government()` :: soft
  predicates

**process:** every rule in `config$rules` runs on every pair; hits
accumulate by severity (`;`-separated when more than one fires). A
**hard** hit means impossible —
[`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
drops the pair, so that EIN is out of contention. A **soft** hit means
plausible-but-review — the pair stays eligible, and if it is the
selected match
[`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
caps it at MAYBE.

1.  number conflict — disjoint embedded numbers (`Local 32` vs
    `Local 45`) -\> **hard** :: `.np_rule_number()`
2.  ordinal conflict — `FIRST` vs `SECOND` -\> **hard** ::
    `.np_rule_ordinal()`
3.  direction conflict — `SOUTHWEST` vs `SOUTHEAST` -\> **hard** ::
    `.np_rule_direction()`
4.  for-profit form — query’s raw name ends in `LLC` / `LP` / `LLP` /
    `PLLC` -\> **hard** (no exempt org uses these) ::
    `.np_rule_forprofit()`
5.  affiliate-suffix mismatch — query `X` matched to candidate
    `X FOUNDATION` on a strong name match -\> **soft** (cap at MAYBE) ::
    `.np_rule_affiliate_suffix()`
6.  government entity — query is a municipality / school district /
    special district / authority -\> **soft** :: `.np_rule_government()`
7.  add `veto` / `veto_reason` (hard) and `veto_soft` /
    `veto_soft_reason` (soft)

Why the layer exists: fuzzy similarity is worst exactly where org names
differ by one short decisive token. `First Presbyterian Church` and
`Second Presbyterian Church` are ~95% similar as strings and are two
different congregations — likewise `Southwest` vs
`Southeast Community Center`, `Local 32` vs `Local 45`, and an org vs
its fundraising foundation. Scorer tuning cannot separate those; the
rules encode the token as a constraint instead.

Steps 4 and 6 fold the old Tier-1 legal-form / entity screen into the
cascade. `legal_form_conflict` (INC vs CORP) ships **inactive** — enable
with `rbind(np_default_rules(), np_rule_legal_form())`. The internal
generation predicates (`.np_rule_generation*`, Jr vs Sr) are **vestigial
and must not be wired in or cited as examples**: generational suffixes
distinguish two *people*, not two organisations, and are an artifact of
the SAM / USASpending person-matching lineage. Rules 1–6 are the
organisation-level equivalents.

### `np_select(pairs)` — best candidate per query

**subroutines**

- `.np_overall_summary()` :: the overall pick with tie-aware tiebreaking
- `.np_argmax_by()` :: best row per query for a given column
- `.np_full_name_sim()` :: break a high tie by full-name similarity

**process:**

1.  drop hard-vetoed pairs
2.  pick the overall best by combined `score`; when several tie near the
    top, break the tie by full-name similarity ::
    `.np_overall_summary()`
3.  also surface the best **name-only** and best **address-only** view
    (disagreement widens the review set) :: `.np_argmax_by()`
4.  compute the runner-up margin — the lead over the next-best distinct
    entity
5.  flag near-ties (`n_close`, `tie`) and whether the views agree
    (`views_agree`)

### `np_tier(selection)` — YES / MAYBE / NO

**process:**

1.  `score >= yes` -\> **YES**; `>= maybe` -\> **MAYBE**; else **NO**
2.  demote YES -\> MAYBE on a near-tie (`overall_margin < min_margin`) —
    genuine ambiguity
3.  demote YES -\> MAYBE on a soft veto on the selected pair
    (`affiliate_suffix`, `government_entity`) — never demotes MAYBE to
    NO

### `np_route(tiered)` — hand-off products

**subroutines**

- `.np_candidates()` :: surface top-k by score plus the best name-only
  and best address-only pairs
- `.np_review_layout()` / `.np_rename_review()` :: assemble the human
  review / evaluation frame
- [`np_bmf_review_fields()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_bmf_review_fields.md)
  :: import BMF context (NTEE, subsection, foundation flag, ruling year,
  assets/revenue, 990 form type, affiliation, group exemption)
- [`np_token_idf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_token_idf.md)
  :: annotate the tokenized name fields with each token’s rarity

**process:**

1.  **`accepted`** — the auto-matched crosswalk (YES tier)
2.  **`review`** — the candidate-level evaluation spreadsheet: match
    strength + outcome (`match_decision`, `is_top_candidate`,
    `match_layer`, `decision_reason`, veto flags), the name-match
    summary and cleaning progression, the aligned address fields, and
    the imported BMF context — the same schema a human sheet and an LLM
    prompt
    ([`np_as_prompt()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_as_prompt.md))
    both consume
3.  **`unmatched`** — the NO tier, each with its best near-miss for
    reference
