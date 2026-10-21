# npmatch (development version)

## Name normalization

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
