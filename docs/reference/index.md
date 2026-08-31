# Package index

## Run projects & stage drivers

Scaffold a run directory, address files inside it, drive each stage, and
report on progress. See the Workflow article for the layout these
produce.

- [`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md)
  : Create a run project directory
- [`np_project_use()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_use.md)
  : Point the session at an existing project
- [`np_project_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_root.md)
  : Locate the active npmatch project
- [`np_project_path()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_path.md)
  : Build a path inside the active project
- [`np_project_status()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_status.md)
  : Report the status of a run project
- [`np_stage_schema()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage_schema.md)
  : The shared outcome schema
- [`np_stage1_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage1_run.md)
  : Run stage 1 - the probabilistic cascade
- [`np_stage2_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage2_run.md)
  : Run stage 2 - LLM adjudication of the MAYBE queue
- [`np_stage3_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage3_run.md)
  : Run stage 3 - LLM research of the NO cases
- [`np_final_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_final_run.md)
  : Roll the stages up into the final deliverables
- [`np_gate_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_gate_rules.md)
  : Entity-gate rules
- [`np_entity_gate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_entity_gate.md)
  : Classify source records before research
- [`np_merge_decisions()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_merge_decisions.md)
  : Merge adjudication decisions onto a review frame

## Match pipeline

Block, compare, score, veto, select, and tier candidate pairs.

- [`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
  : Match with a progressive blocking cascade
- [`np_match()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_match.md)
  : Run the full linkage pipeline
- [`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
  : Generate candidate pairs by blocking
- [`np_block_union()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block_union.md)
  : Union candidate-pair sets from several blocking passes
- [`np_ref_index()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ref_index.md)
  : Precompute the reference-side token index for blocking
- [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
  : Generate and compare candidate pairs
- [`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
  : Score candidate pairs
- [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
  : Apply veto rules to candidate pairs
- [`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
  : Select best matches per query record
- [`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
  : Sort selected matches into YES / MAYBE / NO tiers
- [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
  : Route a tiered result to accept / review / unmatched

## Batched matching

Run the stage-1 cascade over a large source in evenly sized chunks.

- [`np_batch()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_batch.md)
  : Split a data frame into batches
- [`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md)
  : Run stage-1 matching in batches against a shared reference

## Setup & normalization

Map raw datasets onto canonical fields and normalize names and
addresses.

- [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md)
  : Configuration for a linkage run
- [`np_fields`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fields.md)
  : npmatch canonical fields
- [`np_query()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_query.md)
  : Construct a query frame
- [`np_reference()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_reference.md)
  : Construct a reference frame
- [`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md)
  : Normalize a query or reference frame
- [`np_normalize_signature()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize_signature.md)
  : Fingerprint the normalizer
- [`np_map_bmf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)
  [`np_map_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)
  : Built-in schema maps
- [`np_flag_active()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_flag_active.md)
  : Flag which reference EINs are active
- [`np_geo_profiles()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_geo_profiles.md)
  : Geographic profiles
- [`np_detect_geo()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_detect_geo.md)
  : Detect the geographic profile of a query frame

## Rules, distinctiveness & training

Do-not-match rules, token/name statistics, and model benchmarking.

- [`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md)
  [`np_rule_legal_form()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md)
  : Default veto rule set
- [`np_rule()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_rule.md)
  : Build a veto rule
- [`np_default_passes()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_passes.md)
  : Default progressive blocking passes
- [`np_stopwords()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stopwords.md)
  : Blocking stopwords
- [`np_name_freq()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_name_freq.md)
  : Name-key frequency table for a reference corpus
- [`np_token_idf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_token_idf.md)
  : Per-token inverse document frequency for a reference corpus
- [`np_default_weights()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_weights.md)
  : Default per-profile field weights
- [`np_default_geo_weights()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_geo_weights.md)
  : Default location-granularity credits
- [`np_train()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_train.md)
  : Train a supervised match combiner
- [`np_benchmark()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_benchmark.md)
  : Benchmark scoring methods by cross-validation
- [`np_auc()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_auc.md)
  : Area under the ROC curve (Mann-Whitney form)
- [`np_evaluate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_evaluate.md)
  : Evaluate scored pairs against known labels
- [`np_tune_thresholds()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tune_thresholds.md)
  : Tune YES / MAYBE thresholds from labelled data

## Review & labeling hand-off

Build review frames, LLM prompts, and calibration/labeling tools.

- [`np_label_frame()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label_frame.md)
  : Build a labelling frame for training and evaluation
- [`np_calibration_frame()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_calibration_frame.md)
  : Build a labelling frame for threshold / weight calibration
- [`np_label()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label.md)
  : Attach labels to candidate pairs
- [`np_preview_pair()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_preview_pair.md)
  : Preview the field-by-field comparison for one candidate pair
- [`np_veto_audit()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto_audit.md)
  : Extract vetoed pairs for auditing and training
- [`np_bmf_review_fields()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_bmf_review_fields.md)
  : Default BMF context fields for the review queue
- [`np_sam_review_fields()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_sam_review_fields.md)
  : SAM context fields for the review queue
- [`np_as_prompt()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_as_prompt.md)
  : Render a review case as an LLM adjudication prompt
- [`np_as_prompts()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_as_prompts.md)
  : Render every review case as a prompt
- [`np_review_report()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_review_report.md)
  : Render a review frame as a static HTML report

## Data management, fetching & reporting

Resolve data assets, fetch/prepare source files, run incremental diffs,
and report on a run.

- [`np_data_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_data.md)
  [`np_data_path()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_data.md)
  [`np_data_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_data.md)
  : npmatch data asset directories
- [`np_manifest()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_manifest.md)
  [`np_manifest_add()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_manifest.md)
  : Record and read the data-asset manifest
- [`np_source_urls()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_source_urls.md)
  : Known npmatch data sources
- [`np_fetch()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch.md)
  : Download a data file
- [`np_fetch_bmf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch_bmf.md)
  : Fetch the reference BMF (pinned archive)
- [`np_fetch_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch_sam.md)
  : Fetch a SAM extract (pinned archive or a URL you supply)
- [`np_read_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_read_sam.md)
  : Read a raw SAM public extract
- [`np_sam_layout()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_sam_layout.md)
  : SAM public extract column layout
- [`np_flag_nonprofits()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_flag_nonprofits.md)
  : Filter a SAM extract to nonprofits
- [`np_prepare_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_prepare_sam.md)
  : Download-and-prepare a SAM extract for matching
- [`np_diff_unmatched()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_diff_unmatched.md)
  : Retain only source records not already matched (incremental
  matching)
- [`np_run_report()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_report.md)
  : Summarise a cascade run as a report

## Datasets

The hand-labeled 1,502-org training/evaluation benchmark.

- [`npmatch_eval`](https://nonprofit-open-data-collective.github.io/npmatch/reference/npmatch_eval.md)
  : npmatch evaluation frame (1,502-org benchmark)
- [`npmatch_groundtruth`](https://nonprofit-open-data-collective.github.io/npmatch/reference/npmatch_groundtruth.md)
  : npmatch ground-truth master (1,502-org benchmark)

## Geography helpers

- [`np_clean_geo()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_clean_geo.md)
  : Clean and standardize city and state fields
- [`np_city_aliases()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_city_aliases.md)
  : Common city aliases
- [`np_augment_geo()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_augment_geo.md)
  : Augment records with ZIP-level geography
- [`np_ruca_urban()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ruca_urban.md)
  : Collapse a RUCA code to an urban / rural flag
- [`np_load_hud()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_load_hud.md)
  : Load a HUD USPS ZIP crosswalk file
- [`np_load_ruca()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_load_ruca.md)
  : Load a USDA ERS ZIP-code RUCA file
- [`np_load_zipcode_db()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_load_zipcode_db.md)
  : Build a ZIP crosswalk from the zipcodeR package
