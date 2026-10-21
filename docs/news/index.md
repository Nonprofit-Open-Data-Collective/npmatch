# Changelog

## npmatch 0.1.0 (v0)

First tagged release (git tag `v0.1.0`). It pins the code that produced
the combined 2025NOV + 2026MAY SAM-to-BMF crosswalk, so that crosswalk
can be reproduced and cited against a fixed version of the package.

### Results of the pinned run

Of 175,053 SAM nonprofit registrants, 141,420 (80.8%) are matched to an
IRS BMF EIN:

| matched by                           | matches | share of matches |
|--------------------------------------|---------|------------------|
| stage 1 — probabilistic cascade      | 121,972 | 86.2%            |
| stage 2 — LLM adjudication of MAYBEs | 12,443  | 8.8%             |
| stage 3 — LLM research of NOs        | 7,005   | 5.0%             |

The 33,633 unmatched registrants are mostly explained by stage 3: 12,892
are not nonprofits, 18,770 are nonprofits absent from this BMF vintage
(mostly churches and foreign organizations), and 1,971 could not be
determined.

### What is in this release

#### Matching engine

- A full record-linkage pipeline against the BMF:
  [`np_query()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_query.md)
  /
  [`np_reference()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_reference.md)
  →
  [`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md)
  →
  [`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
  →
  [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
  →
  [`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
  →
  [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
  →
  [`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
  →
  [`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
  →
  [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md),
  orchestrated by
  [`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
  (multi-pass) or
  [`np_match()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_match.md)
  (single pass).
- Nonprofit-specific normalization: abbreviation expansion, legal-suffix
  stripping, legal-form capture, and extraction of embedded numbers,
  ordinals and directions.
  [`np_normalize_signature()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize_signature.md)
  lets a cached artifact detect when normalization has drifted.
- Progressive blocking passes: four exact name/DBA passes, then
  IDF-weighted name-token blocking within a state, a de-spaced-compound
  pass, and a cross-state pass.
  [`np_ref_index()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ref_index.md)
  tokenizes the reference once for reuse across passes and batches.
- Hierarchical scoring (`method = "hier"`): name similarity plus the
  strongest confirmed geographic granularity, with a state-aware
  promotion for rare exact names.
- A do-not-match veto engine
  ([`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md)):
  hard vetoes for number, ordinal and direction conflicts and for-profit
  legal forms; soft vetoes (cap at MAYBE) for affiliate-suffix
  mismatches and government entities.
- YES / MAYBE / NO tiering with a near-tie margin and soft-veto
  demotion.

#### Running a project

- Per-run project scaffolding:
  [`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md),
  [`np_project_use()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_use.md),
  [`np_project_path()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_path.md)
  and
  [`np_project_status()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_status.md).
- Stage drivers that share one outcome schema
  ([`np_stage_schema()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage_schema.md)):
  [`np_stage1_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage1_run.md)
  (batched cascade via
  [`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md)),
  [`np_stage2_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage2_run.md)
  (MAYBE adjudication hand-off),
  [`np_stage3_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage3_run.md)
  (NO research, with the
  [`np_entity_gate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_entity_gate.md)
  screen) and
  [`np_final_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_final_run.md)
  (crosswalk, evaluation frame and funnel report).
- [`np_merge_decisions()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_merge_decisions.md)
  joins stage-2 adjudications back onto the review frame.

#### Review, labeling and training

- Candidate-level review frames and LLM prompts:
  [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md),
  [`np_as_prompt()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_as_prompt.md)
  /
  [`np_as_prompts()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_as_prompts.md),
  [`np_review_report()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_review_report.md)
  (static HTML review report),
  [`np_label_frame()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label_frame.md),
  [`np_calibration_frame()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_calibration_frame.md)
  and
  [`np_veto_audit()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto_audit.md).
- Model fitting and evaluation:
  [`np_train()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_train.md),
  [`np_benchmark()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_benchmark.md),
  [`np_auc()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_auc.md),
  [`np_evaluate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_evaluate.md)
  and
  [`np_tune_thresholds()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tune_thresholds.md).
- Bundled data: `npmatch_eval` and `npmatch_groundtruth`, a hand-labeled
  1,502-organization benchmark.

#### Data management

- A data store with a manifest
  ([`np_data_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_data.md),
  [`np_manifest()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_manifest.md)),
  source fetchers for the BMF and SAM extracts
  ([`np_fetch_bmf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch_bmf.md),
  [`np_fetch_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch_sam.md),
  [`np_prepare_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_prepare_sam.md)),
  incremental diffs
  ([`np_diff_unmatched()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_diff_unmatched.md))
  and run reports
  ([`np_run_report()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_report.md)).
- Geography helpers: city aliases, HUD crosswalks, RUCA urbanicity and
  ZIP lookups.

#### Documentation

- Articles: *Workflow*, *Reviewer guide*, *Candidate evaluation frame*,
  *Training dataset* and *Building a classifier*, published with the
  pkgdown site.
- Reviewer workbook builds under `dev/review-workbooks/`: per-state
  themed evaluation workbooks, plus the stage-3 secondary review
  workbooks (all states, per state and zipped).

### Known issues

- **Blocking misses.** Of the 4,925 stage-3 matches that stage 1 never
  surfaced, 3,189 were never generated by blocking, 1,507 were scored
  but missed the shortlist, and 229 were hard-vetoed.
  `final_ein_in_candset = 0` therefore mixes blocking, scoring and veto
  misses rather than marking blocking failures alone; the stage-3
  secondary review separates them in `stage1_pair_status`.
- **Word-order sensitivity.** Name similarity is Jaro-Winkler on the
  normalized name, so a reordered name (e.g. “BERNARDINO TELACU HOUSING
  SAN II” vs “TELACU HOUSING SAN BERNARDINO II”) can fall below the 0.85
  floor. The order-insensitive overlap recovery only runs when the
  address already matches.
- **Fully vetoed registrants.** For 5,226 registrants, stage 1 scored
  candidate pairs but the hard veto removed every one. They are flagged
  `fully_vetoed` in the secondary review for inspection. Among the 229
  vetoed stage-3 matches, the for-profit legal-form rule accounts for
  183.
- **Rollup anomaly.** 126 `stage3_research` rows in the combined
  evaluation frame are `NO_MATCH` with an EIN but a blank `final_ein`;
  synthetic rows should only exist for matched registrants.
- `candidate_source = "none"` rows come from the combined-run build,
  which is not part of the package; that value is not yet documented in
  the reviewer data dictionary.
