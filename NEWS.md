# npmatch (development version)

**The normalizer now comes from npnormalize. The next release is 0.2.0.**

* **What moved.** npmatch's normalizer moved, unchanged, into the new
  [npnormalize](https://github.com/Nonprofit-Open-Data-Collective/npnormalize)
  package, which npmatch now imports. That covers:
  * the rule tables;
  * `np_normalize()`, `np_name_core()` and `np_name_placeholder()`;
  * the corpus statistics (`np_name_freq()`, `np_token_idf()`,
    `np_addr_freq()`, `np_stopwords()`);
  * the blocking tokenizer;
  * `np_normalize_signature()`.
* **Nothing changes for callers.** npmatch re-exports those nine functions, so
  `npmatch::np_normalize()`, scripts, pfmatch and networked990 work as before.
  `np_normalize_signature()` reports the same value, `v1-3e7b9f9d59bbb19e`, so
  every stored artifact built under npmatch 0.1.1 stays valid. That includes
  matchdb's database, bundles and tranches.
* **Why.** Both sides of a match depend on the normalizer: matchdb stores its
  keys, and npmatch computes them for each query. With the normalizer in its own
  package, matchdb no longer needs npmatch, and npmatch can depend on matchdb in
  turn.
* **Where things are now:**
  * The normalizer's tests live in npnormalize. npmatch keeps the tests that
    block, compare or score on top of it, and adds one checking that its
    signature and re-exported functions are npnormalize's own.
  * The five name comparators that sat beside the normalizer moved to
    `R/compare.R`, since they feed `np_compare()` and precompute nothing.
  * npmatch's blocking and comparison call npnormalize's exported
    `np_tokenize()`, `np_doc_freq()`, `np_addr_key()` and `np_state_abb()`.
* **Dependencies:** stringi is no longer imported (only the normalizer used it);
  npnormalize is, from GitHub (`Remotes:`).

# npmatch 0.1.1

Tagged `v0.1.1`. This is the last npmatch that carries its own normalizer. In
the next version the normalizer moves, unchanged, into the npnormalize package,
which npmatch then imports and re-exports. Pin this release (in renv, or with
`@v0.1.1`) for anything that should reproduce results from before that move.

* **The normalizer signature at this release is `v1-3e7b9f9d59bbb19e`.** It is
  the signature matchdb's 2026-10-26 release was built with, and the one
  npnormalize 0.1.0 reproduces.
* Everything since 0.1.0 is listed below: address and suite classification,
  the suite identifier, and the name-normalization fixes.

## Address and suite normalization

* `np_addr_freq()` classifies each shared address, because what a shared
  address *is* decides what its evidence is worth, and counts alone cannot tell
  the kinds apart. It now takes `name_keys` and adds `n_names`,
  `top_name_share`, `unit_coverage` and `class`: `federated` (many records, one
  name dominating — a national office its chapters file from, where the address
  matches every chapter equally and the chapter number is the only
  discriminator), `shared` (many records, many names — a fiscal sponsor or
  registered agent), `building` (many records across several recorded suites —
  the suite discriminates) or `cluster` (a handful, usually an org with its
  foundation). Over the unified BMF: 1,188 federated addresses holding 60,064
  records, 1,319 shared holding 29,910, 1,910 buildings holding 36,327, and
  134,212 clusters. `np_compare()` carries `addr_class`,
  `addr_top_name_share` and `addr_unit_coverage` per pair and states the class
  in `addr_note`, which reaches the review frame, the stage 2 packet and
  `np_as_prompt()`.
* The suite credit is additionally gated on `unit_coverage` (default 0.5): at
  the BMF addresses holding 10 or more records the share of records naming a
  suite averages 0.52 and 1,601 of them name none, so "two or more distinct
  suites here" can describe the data rather than the building. This withholds
  the credit at 445 of the 23,310 addresses listing two or more suites (1.9%).
* **Damping the street credit at low-discrimination addresses was measured and
  rejected**, against an earlier recommendation of our own. With the street
  evidence *zeroed* at crowded addresses, the 304,274 labeled pairs give AUC
  0.9981 to 0.9981, precision 0.5669 to 0.5669, recall 0.9212 to 0.9212 and
  1,898 YES-band pairs either way — not one decision changes. The geo terms
  combine with `max()` and the top rungs sit 0.05 apart, so removing one moves
  a total score by 0.02; and the two crowded archetypes want opposite
  treatment, since at a sponsor address the name separates cleanly and damping
  would only pull the true match down. See `dev/MATCHDB-ADDRESS-UNIQUENESS.md`
  section 9.
* `np_addr_freq()` is covered by the normalizer signature, so these changes move
  it again. **Read the value with `np_normalize_signature()` on the commit you
  are building from, rather than from any value quoted here.** The signature is
  computed over the whole registered normalize path, so a change merging
  alongside this one moves it too: this entry previously named a value measured
  on the feature branch, and a one-line `.np_replace_tokens()` fix that landed
  in between made it wrong before the merge was a day old. A literal is only
  safe in a tagged release note, where the commit is pinned.

* **The suite number is parsed properly, carried through to review, and used as
  evidence where it means something.** Previously it was extracted, stripped
  from `street_key`, and then dropped: nothing downstream saw it, so neither a
  human reviewer nor the stage 2 adjudicator could tell two tenants of one
  building apart.
* `np_normalize()` adds `street_unit_id`, the identifier alone with separators
  dropped (`STE D-2` -> `D2`). Records are compared on it, so a BMF `STE 300`
  and a source `# 300` are recognised as one office, while 320 and 380 are
  simply different — a suite is an identifier, and a fuzzy score between two of
  them means nothing.
* `street_unit` is now read from the **`unit` column** (a second address line)
  when the street line names no suite. Ignoring it was a penalty rather than a
  gap: SAM keeps the suite in `physical_address_line_2`, `np_detect_geo()`
  selected the `street_unit_full` profile on that column's coverage, and the
  compared column was then `NA` on every row — a unit similarity of 0 on every
  pair, fired precisely *because* the data was present.
* A profile requiring `unit` is no longer auto-selected, because the per-profile
  weights are a weighted *sum*, where a field earns its weight only by matching
  and an unrecorded suite is therefore a silent penalty. Suite evidence now
  enters `np_score(method = "hier")`, where the geo terms combine with `max()`
  so an absent, differing or crowded suite costs a pair nothing.
  `street_unit_full` remains available via an explicit `profile =`.
* New `np_addr_freq()` counts, over the reference, the records at each address,
  at each address + suite, and the distinct suites per address. `np_compare()`
  annotates every pair with `geo_unit` (1 same suite / 0 different / `NA`
  unknown), `addr_shared`, `addr_units`, `addr_unit_shared` and a
  reviewer-facing `addr_note`, and `np_default_geo_weights()` gains
  `unit = 0.97`. A matching suite is credited only where it discriminates:
  several distinct suites on record at that address (a multi-tenant building,
  where an exact-address match surfaces every tenant) and that suite not itself
  shared by more than `share_min` records (a fiscal sponsor or registered
  agent, where a shared suite says nothing). The crowded cases are reported to
  the reviewer instead — "12 records share this address and suite" — in the
  review frame, the stage 2 packet and `np_as_prompt()`.
* The unit pattern is rebuilt from a `.np_unit_designators` table and now
  requires a word boundary and, before an alphabetic id, a separator. Measured
  on the 1.92M-row unified BMF (`dev/scan-unit-designators.R`), the old pattern
  produced a false unit on 27,954 rows (11.3% of all extractions) by matching
  inside ordinary words — `SHERMAN WAY` gave room "AN WAY" and
  `INDIGO BROOM LOOP` keyed as `10317 INDIGO B` — and in 3,636 of them the
  false match also **masked the real unit**:
  `259 N RADNOR CHESTER RD STE 150` extracted `STER`, from inside CHESTER.
* Designators added, by volume in the BMF: `PMB`, `FL` / `FLOOR` (including the
  postfix form, `2ND FLOOR` -> `FL 2`), `SPC` / `SPACE`, `LOT`, `TRLR`, `DEPT`,
  `STOP`, `LBBY`, `HNGR`, `BSMT`, `NUM` / `NUMBER`. USPS C2's `FRNT`, `REAR`,
  `LOWR`, `UPPR`, `OFC`, `PH`, `PIER`, `KEY`, `SIDE` and `SLIP` are left out
  because in this corpus they match street names, and `NO` because it is North
  far more often than Number.
* The `#` form is stripped from `street_key` at last: extraction allowed `#` and
  the key strip did not, so `123 MAIN ST # 300` recorded unit `# 300` *and*
  keyed as `123 MAIN ST 300`. Both now run off one pattern, before cleaning,
  which is the only point at which the `#` still exists.
* `np_as_prompt()` could not run at all: it addressed the pipeline column names
  (`score`, `name_sim`) on a review frame that renames them (`total_score`,
  `name_similarity`), so `order(-NULL)` errored. Its test had been skipping past
  the call for the same reason — the id column is renamed too — and now runs.

## Name normalization

* Letters that are not an accented form of another letter now fold to their
  ASCII spelling: `ß` → `SS`, `Ø` → `O`, `Ł` → `L`, `Đ` → `D`, `Æ` → `AE`,
  `Œ` → `OE`, `Þ` → `TH`. De-accenting cannot reach them, and an unmapped
  letter was replaced by a space, which split the word it sat in: `Straße Fund`
  normalized to `STRA E FUND`. Folding now runs before the upper-casing, which
  is what let the eszett through — R's `toupper()` is per-character, so it left
  a letter whose upper case is two letters alone. This is the list matchdb's
  `md_light_key()` folds, so a cached reference key and a run-time query key
  agree character for character; `np_name_rules()` returns it as
  `special_letters`. **`np_normalize_signature()` changes with it**, so any
  cached `name_key` / `street_key` artifact must be rebuilt.
* 16 more abbreviations expand, taken from networked990's 990 name resolver
  and checked against the BMF: FDN / FND / FNDTN / FDTN (FOUNDATION), HOSP,
  MED, HLTH, HLTHCARE, MGMT, REG / RGNL (REGIONAL), CNTR, SYS / SYST and
  SRVCS / SRVS. PHYS is deliberately left alone (in the BMF it is mostly
  physical education). Because this changes `name_key`, it can change which
  EINs stage 1 matches, and `np_normalize_signature()` changes with it.
* `np_normalize()` adds `name_core`, an exact-lookup key that drops connector
  words and legal forms anywhere in the name but keeps FOUNDATION, TRUST and
  FUND, so a charity and its foundation get different keys. `np_name_core()`
  computes it for raw strings.
* `np_normalize()` adds `name_placeholder`, `TRUE` for names that are not
  names ("SEE SCHEDULE O", "N/A", no letters). `np_block()` gives such query
  rows no candidates. `np_name_placeholder()` checks raw strings.
* `np_name_rules()` returns the normalization tables, for porting the rules to
  another engine such as a DuckDB SQL macro.

# npmatch 0.1.0 (v0)

First tagged release (git tag `v0.1.0`). It pins the code that produced the
combined 2025NOV + 2026MAY SAM-to-BMF crosswalk, so that crosswalk can be
reproduced and cited against a fixed version of the package.

## Results of the pinned run

Of 175,053 SAM nonprofit registrants, 141,420 (80.8%) are matched to an IRS
BMF EIN:

| matched by | matches | share of matches |
|---|---|---|
| stage 1 — probabilistic cascade | 121,972 | 86.2% |
| stage 2 — LLM adjudication of MAYBEs | 12,443 | 8.8% |
| stage 3 — LLM research of NOs | 7,005 | 5.0% |

The 33,633 unmatched registrants are mostly explained by stage 3: 12,892 are
not nonprofits, 18,770 are nonprofits absent from this BMF vintage (mostly
churches and foreign organizations), and 1,971 could not be determined.

## What is in this release

### Matching engine

* A full record-linkage pipeline against the BMF: `np_query()` /
  `np_reference()` → `np_normalize()` → `np_block()` → `np_compare()` →
  `np_score()` → `np_veto()` → `np_select()` → `np_tier()` → `np_route()`,
  orchestrated by `np_cascade()` (multi-pass) or `np_match()` (single pass).
* Nonprofit-specific normalization: abbreviation expansion, legal-suffix
  stripping, legal-form capture, and extraction of embedded numbers, ordinals
  and directions. `np_normalize_signature()` lets a cached artifact detect when
  normalization has drifted.
* Progressive blocking passes: four exact name/DBA passes, then
  IDF-weighted name-token blocking within a state, a de-spaced-compound pass,
  and a cross-state pass. `np_ref_index()` tokenizes the reference once for
  reuse across passes and batches.
* Hierarchical scoring (`method = "hier"`): name similarity plus the strongest
  confirmed geographic granularity, with a state-aware promotion for rare
  exact names.
* A do-not-match veto engine (`np_default_rules()`): hard vetoes for number,
  ordinal and direction conflicts and for-profit legal forms; soft vetoes
  (cap at MAYBE) for affiliate-suffix mismatches and government entities.
* YES / MAYBE / NO tiering with a near-tie margin and soft-veto demotion.

### Running a project

* Per-run project scaffolding: `np_project_init()`, `np_project_use()`,
  `np_project_path()` and `np_project_status()`.
* Stage drivers that share one outcome schema (`np_stage_schema()`):
  `np_stage1_run()` (batched cascade via `np_run_batches()`),
  `np_stage2_run()` (MAYBE adjudication hand-off), `np_stage3_run()`
  (NO research, with the `np_entity_gate()` screen) and `np_final_run()`
  (crosswalk, evaluation frame and funnel report).
* `np_merge_decisions()` joins stage-2 adjudications back onto the review frame.

### Review, labeling and training

* Candidate-level review frames and LLM prompts: `np_route()`,
  `np_as_prompt()` / `np_as_prompts()`, `np_review_report()` (static HTML
  review report), `np_label_frame()`, `np_calibration_frame()` and
  `np_veto_audit()`.
* Model fitting and evaluation: `np_train()`, `np_benchmark()`, `np_auc()`,
  `np_evaluate()` and `np_tune_thresholds()`.
* Bundled data: `npmatch_eval` and `npmatch_groundtruth`, a hand-labeled
  1,502-organization benchmark.

### Data management

* A data store with a manifest (`np_data_init()`, `np_manifest()`), source
  fetchers for the BMF and SAM extracts (`np_fetch_bmf()`, `np_fetch_sam()`,
  `np_prepare_sam()`), incremental diffs (`np_diff_unmatched()`) and run
  reports (`np_run_report()`).
* Geography helpers: city aliases, HUD crosswalks, RUCA urbanicity and ZIP
  lookups.

### Documentation

* Articles: *Workflow*, *Reviewer guide*, *Candidate evaluation frame*,
  *Training dataset* and *Building a classifier*, published with the
  pkgdown site.
* Reviewer workbook builds under `dev/review-workbooks/`: per-state themed
  evaluation workbooks, plus the stage-3 secondary review workbooks (all
  states, per state and zipped).

## Known issues

* **Blocking misses.** Of the 4,925 stage-3 matches that stage 1 never
  surfaced, 3,189 were never generated by blocking, 1,507 were scored but
  missed the shortlist, and 229 were hard-vetoed. `final_ein_in_candset = 0`
  therefore mixes blocking, scoring and veto misses rather than marking
  blocking failures alone; the stage-3 secondary review separates them in
  `stage1_pair_status`.
* **Word-order sensitivity.** Name similarity is Jaro-Winkler on the
  normalized name, so a reordered name (e.g. "BERNARDINO TELACU HOUSING SAN
  II" vs "TELACU HOUSING SAN BERNARDINO II") can fall below the 0.85 floor.
  The order-insensitive overlap recovery only runs when the address already
  matches.
* **Fully vetoed registrants.** For 5,226 registrants, stage 1 scored candidate
  pairs but the hard veto removed every one. They are flagged `fully_vetoed` in
  the secondary review for inspection. Among the 229 vetoed stage-3 matches,
  the for-profit legal-form rule accounts for 183.
* **Rollup anomaly.** 126 `stage3_research` rows in the combined evaluation
  frame are `NO_MATCH` with an EIN but a blank `final_ein`; synthetic rows
  should only exist for matched registrants.
* `candidate_source = "none"` rows come from the combined-run build, which is
  not part of the package; that value is not yet documented in the reviewer
  data dictionary.
