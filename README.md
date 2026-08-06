# npmatch

A package for matching nonprofit organizations to the IRS BMF database when EINs are not available.

## Package Overview

`npmatch` builds a crosswalk from arbitrary source organization records (name + variable
geographic detail) to the IRS Business Master File (BMF). It is a two-part process: match
as much as possible **algorithmically** using only information in the BMF, then hand the
residual (MAYBE / NO cases) to humans or LLM agents for investigation.

The pipeline is a sequence of stages, orchestrated end-to-end by `np_cascade()` (scalable,
multi-pass) or `np_match()` (single-pass). Each stage below lists the internal subroutines
it calls and enumerates the concrete steps, with the function that performs each step noted
as `:: fx()`.

```
raw data → np_normalize → np_block → np_compare → np_score → np_veto → np_select → np_tier → np_route
```

### Raw data sources

* **USASpending / SAM organizations** — the query (source) side. Key fields:
  `legal_business_name`, `dba_name`, `entity_division_name`, physical address, and the
  Unique Entity Identifier (`uei`).
* **Standardized IRS EO Business Master File (BMF)** — from NCCS; the reference (candidate)
  side, keyed by `ein`. Carries `org_name_join`, `dba_name`, address, NTEE, 501(c)
  subsection, foundation code, ruling date, assets/revenue, filing requirement, affiliation
  and group-exemption codes.

### `np_query(df, map)` / `np_reference(df, map)` — canonicalize

Rename raw source columns onto the canonical schema so every downstream stage works on
common column names.

* subroutines
  * `.np_canonicalize()` :: apply a schema map (`np_map_sam()` / `np_map_bmf()`) that maps
    canonical fields (`name`, `dba`, `street`, `city`, `state`, `zip5`, `.id`/`.ein`) to
    source columns.

### `np_normalize(df)` — clean, standardize, and extract features

Brings names and addresses onto a common matchable form and extracts the token-level
features the veto layer needs. Adds `name_key`, `dba_key`, `name_full`, `name_form`,
`name_gen`, `name_nums`, `name_ord`, `name_dir`, `street_key`, `street_num/name/type/unit`,
`is_po_box`, `zip5/zip3/zip9`, `state_abb`.

* subroutines
  * `.np_basic_clean()` :: uppercase, de-accent, `&`→`AND`, strip punctuation, squish space
  * `.np_replace_tokens(dict)` :: whole-word dictionary substitution (abbreviations, USPS types)
  * `.np_strip_lead_the()` :: drop a single leading `THE`
  * `.np_strip_suffix()` :: strip trailing legal suffixes to form the match key
  * `.np_extract_form()` / `.np_canon_form()` :: detect & canonicalize the legal form
  * `.np_extract_generation()` :: JR / SR marker
  * `.np_extract_numbers()` :: embedded digit tokens (chapter / local numbers)
  * `.np_extract_ordinals()` :: FIRST/SECOND/… → canonical rank
  * `.np_extract_direction()` :: NORTH/SOUTHWEST/… → N / SW
  * `.np_street_key()` :: cleaned street with unit dropped and USPS types standardized
  * `.np_extract_unit()` :: pull the suite / apt / unit token
  * `.np_is_pobox()` :: detect PO-box variants (`PO BOX`, `POB`, `P O`, `BOX`, …)
  * `.np_parse_street()` :: split the street key into number / name / type
  * `.np_parse_zip()` :: build the nested `zip3 ⊂ zip5 ⊂ zip9` family, restoring leading zeros
  * `.np_to_state_abb()` :: map a full state name to its 2-letter code

Name steps:

* convert name to upper case :: `.np_basic_clean()`
* de-accent to ASCII (`Ñ`→`N`) :: `.np_basic_clean()`
* expand `&` to `AND` :: `.np_basic_clean()`
* strip punctuation, keep `A–Z 0–9` only :: `.np_basic_clean()`
* squish repeated white space :: `.np_basic_clean()`
* expand abbreviations whole-word (`NATL`→`NATIONAL`, `ST`→`SAINT`, `CTR`→`CENTER`, …) :: `.np_replace_tokens(.np_abbrev)` → **`name_full`**
* remove a leading `THE` :: `.np_strip_lead_the()`
* strip trailing legal suffixes (`INC`, `CORP`, `LLC`, `FOUNDATION`, `TRUST`, …) :: `.np_strip_suffix()` → **`name_key`** (the match key)
* apply the same normalization to the DBA name → **`dba_key`**
* detect & record the legal form (`INC`/`LLC`/`CORP`/…) — stripped but held for the veto layer :: `.np_extract_form()`
* record generation (JR/SR), embedded numbers, ordinals, and directional markers for veto tests :: `.np_extract_generation()`, `.np_extract_numbers()`, `.np_extract_ordinals()`, `.np_extract_direction()`

Address steps:

* clean the street, drop the unit portion, standardize USPS street types (`STREET`→`ST`) :: `.np_street_key()`
* extract the unit (`STE`/`APT`/`#`) :: `.np_extract_unit()`
* flag PO-box addresses :: `.np_is_pobox()`
* split the street into house number / street name / street type :: `.np_parse_street()`
* parse the ZIP: restore dropped leading zeros, derive `zip5` and its `zip3` prefix, and build `zip9` from the +4 add-on :: `.np_parse_zip()`
* map the state to a 2-letter code (pass through valid codes, translate full names) :: `.np_to_state_abb()`

### `np_block(query, reference)` — generate candidate pairs

Produces only the (query, reference) pairs worth comparing, so `np_compare()` never scores
every same-state pair. This is where **inverse document frequency (IDF) tokenization** lives.

* subroutines
  * `.np_bykey()` :: build a composite exact-block key (e.g. `state`, or `state`+`name_key`)
  * `np_stopwords()` :: the non-discriminating tokens dropped before token blocking
  * `np_token_idf()` :: per-token IDF, `log(N / df)`, over the reference corpus
* build candidate pairs that share an exact block key (hash join), OR
* tokenize each name and index it, dropping stopwords and sub-2-character tokens :: `idx_of()`
* drop corpus-common tokens whose reference document frequency exceeds `max_ref_freq`
* **tokenize by inverse document frequency**: keep a pair only when the sum of its shared
  tokens' IDF clears `min_pair_idf`, so one rare token (or several moderately common ones)
  justifies a pair but a lone common token (e.g. `CALIFORNIA`, `CHURCH`) does not
* `np_block_union()` :: de-duplicate the pairs from several passes

`np_cascade()` runs blocking as **progressive passes** — exact name, exact name↔DBA, exact
DBA↔name, exact DBA↔DBA, shared-token same-state, shared-token cross-state — pruning each
query out of later (looser, costlier) passes once it is resolved (**residual pruning**).

### `np_compare(query, reference)` — per-field similarity

* subroutines
  * `reclin2::compare_pairs()` with `cmp_jarowinkler()` / `cmp_identical()` :: per-field comparison
  * `.np_name_overlap()` :: token-set + acronym-aware overlap (word-reorder, `EMS`↔`Emergency Medical Service`)
  * `.np_collapse_initials()` :: collapse single-letter runs (`F O R`→`FOR`)
  * `np_name_freq()` :: how many reference records share a normalized name
* compare the name on `name_key` with Jaro-Winkler :: `cmp_jarowinkler()`
* floor fuzzy similarities below `jw_threshold` to 0 (Winkler is a prefix *boost*, not a cutoff)
* compare geo fields — fuzzy city/street (JW) and exact ZIP :: `cmp_jarowinkler()` / `cmp_identical()`
* compute exact geo signals: ZIP9 / ZIP5 / ZIP3 / state / street-number / PO-box matches :: `exact()`
* effective name similarity = best of name↔name, name↔DBA, DBA↔name, DBA↔DBA cross-products
* name-blind recovery: token-set + acronym overlap when JW & DBA both score 0 **and** the address is confirmed :: `.np_name_overlap()`
* record which name **version** matched on each side (`main` / `dba` / `token_overlap` / `none`)
* compute the name distinctiveness count (`normalized_match_count`) :: `np_name_freq()`

### `np_score(pairs, method = "hier")` — combine into one score

* subroutines
  * `.np_hier_score()` :: name similarity + a hierarchical geo sub-score
* geo sub-score = the **strongest confirmed** location granularity via `max`, not a sum
  (`ZIP9 > street > ZIP5 > PO box > ZIP3 > city > state`), so correlated address fields
  are not double-counted :: `.np_hier_score()`
* `score = 0.6 · name + 0.4 · geo`
* distinctive-exact-name promotion: an exact match on a rare name is floored up so it
  auto-accepts without address corroboration — **state-aware**: cross-state name-only
  matches get a lower floor and land in MAYBE for review :: `.np_hier_score()`

### `np_veto(pairs)` — do-not-match rules

* subroutines
  * `.np_rule_number()` / `.np_rule_ordinal()` / `.np_rule_direction()` :: hard predicates
  * `.np_rule_affiliate_suffix()` :: soft predicate
* number conflict — disjoint embedded numbers (`Local 32` vs `Local 45`) → **hard** (force NO)
* ordinal conflict — `FIRST` vs `SECOND` → **hard**
* direction conflict — `SOUTHWEST` vs `SOUTHEAST` → **hard**
* affiliate-suffix mismatch — query `X` matched to candidate `X FOUNDATION` → **soft** (cap at MAYBE)
* adds `veto` / `veto_reason` (hard) and `veto_soft` / `veto_soft_reason` (soft)

### `np_select(pairs)` — best candidate per query

* subroutines
  * `.np_overall_summary()` :: the overall pick with tie-aware tiebreaking
  * `.np_argmax_by()` :: best row per query for a given column
  * `.np_full_name_sim()` :: break a high tie by full-name similarity
* drop hard-vetoed pairs
* pick the overall best by combined `score`; when several tie near the top, break the tie by full-name similarity :: `.np_overall_summary()`
* also surface the best **name-only** and best **address-only** view (disagreement widens the review set)
* compute the runner-up margin — the lead over the next-best distinct entity
* flag near-ties (`n_close`, `tie`) and whether the views agree (`views_agree`)

### `np_tier(selection)` — YES / MAYBE / NO

* `score ≥ yes` → **YES**; `≥ maybe` → **MAYBE**; else **NO**
* demote YES → MAYBE on a near-tie (`overall_margin < min_margin`) — genuine ambiguity
* demote YES → MAYBE on a soft veto

### `np_route(tiered)` — hand-off products

* subroutines
  * `.np_candidates()` :: surface top-k by score plus the best name-only and best address-only pairs
  * `.np_review_layout()` / `.np_rename_review()` :: assemble the human review / evaluation frame
  * `np_bmf_review_fields()` :: import BMF context (NTEE, subsection, foundation flag, ruling year, assets/revenue, 990 form type, affiliation, group exemption)
  * `np_token_idf()` :: annotate the tokenized name fields with each token's rarity
* **`accepted`** — the auto-matched crosswalk (YES)
* **`review`** — the candidate-level evaluation spreadsheet: match strength + outcome
  (`decision`, `is_top_candidate`, `decision_layer`, `decision_reason`, veto flags), the
  name-match summary and cleaning progression, the aligned address fields, and the imported
  BMF context — the same schema a human sheet and an LLM prompt (`np_as_prompt()`) both consume
* **`unmatched`** — the NO tier, each with its best near-miss for reference
