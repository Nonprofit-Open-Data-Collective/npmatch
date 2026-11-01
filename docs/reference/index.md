<div id="main" class="col-md-9" role="main">

# Package index

<div class="section level2">

## Run projects & stage drivers

<div class="section-desc">

Scaffold a run directory, address files inside it, drive each stage, and
report on progress. See the Workflow article for the layout these
produce.

</div>

</div>

<div class="section level2">

-   `np_project_init()` : Create a run project directory
-   `np_project_use()` : Point the session at an existing project
-   `np_project_root()` : Locate the active npmatch project
-   `np_project_path()` : Build a path inside the active project
-   `np_project_status()` : Report the status of a run project
-   `np_stage_schema()` : The shared outcome schema
-   `np_stage1_run()` : Run stage 1 - the probabilistic cascade
-   `np_stage2_run()` : Run stage 2 - LLM adjudication of the MAYBE
    queue
-   `np_stage3_run()` : Run stage 3 - LLM research of the NO cases
-   `np_final_run()` : Roll the stages up into the final deliverables
-   `np_gate_rules()` : Entity-gate rules
-   `np_entity_gate()` : Classify source records before research
-   `np_merge_decisions()` : Merge adjudication decisions onto a review
    frame

</div>

<div class="section level2">

## Match pipeline

<div class="section-desc">

Tiers 3–6: pre-prep the reference corpus, generate candidates by
blocking, compare and score them, apply the veto rules, select and tier.
`np_cascade()` orchestrates all of it, and takes a matchdb reference
directly.

</div>

</div>

<div class="section level2">

-   `np_cascade()` : Match with a progressive blocking cascade
-   `np_match()` : Run the full linkage pipeline
-   `np_block()` : Generate candidate pairs by blocking
-   `np_block_union()` : Union candidate-pair sets from several blocking
    passes
-   `np_ref_index()` : Precompute the reference-side token index for
    blocking
-   `np_compare()` : Generate and compare candidate pairs
-   `np_score()` : Score candidate pairs
-   `np_veto()` : Apply veto rules to candidate pairs
-   `np_select()` : Select best matches per query record
-   `np_tier()` : Sort selected matches into YES / MAYBE / NO tiers
-   `np_route()` : Route a tiered result to accept / review / unmatched

</div>

<div class="section level2">

## Entity families

<div class="section-desc">

Roll a query up to the family its candidates belong to — a chapter of a
federation, a hospital system, a school and its PTO — and tell a contest
between strangers from one within a family. Both take cluster membership
from
[matchdb](https://nonprofit-open-data-collective.github.io/matchdb/)
(`cluster_member` joined to `cluster`).

</div>

</div>

<div class="section level2">

-   `np_cluster_rollup()` : Match one level up: roll candidates up to
    their family
-   `np_pair_links()` : Are a query's top two candidates one family?

</div>

<div class="section level2">

## Batched matching

<div class="section-desc">

Run the stage-1 cascade over a large source in evenly sized chunks.

</div>

</div>

<div class="section level2">

-   `np_batch()` : Split a data frame into batches
-   `np_run_batches()` : Run stage-1 matching in batches against a
    shared reference

</div>

<div class="section level2">

## Setup & standardization

<div class="section-desc">

Tier 2: map any dataset onto the canonical fields, from which every
later tier works. The standardization itself — `np_normalize()`,
`np_name_core()`, the name, token and address statistics, and the
signature that pins them — lives in
[npnormalize](https://nonprofit-open-data-collective.github.io/npnormalize/)
and is re-exported here unchanged. `np_map_sam()` / `np_map_bmf()` are
the maps for the SAM-to-BMF deployment; write your own for another one.

</div>

</div>

<div class="section level2">

-   `np_config()` : Configuration for a linkage run
-   `np_fields` : npmatch canonical fields
-   `np_query()` : Construct a query frame
-   `np_reference()` : Construct a reference frame
-   `reexports` `np_normalize` `np_normalize_signature` `np_name_core`
    `np_name_placeholder` `np_name_rules` `np_stopwords` `np_name_freq`
    `np_token_idf` `np_addr_freq` : Objects exported from other packages
-   `np_map_bmf()` `np_map_sam()` : Built-in schema maps
-   `np_flag_active()` : Flag which reference EINs are active
-   `np_geo_profiles()` : Geographic profiles
-   `np_detect_geo()` : Detect the geographic profile of a query frame

</div>

<div class="section level2">

## Rules, distinctiveness & training

<div class="section-desc">

Do-not-match rules, token/name statistics, and model benchmarking.

</div>

</div>

<div class="section level2">

-   `np_default_rules()` `np_rule_legal_form()` : Default veto rule set
-   `np_rule()` : Build a veto rule
-   `np_default_passes()` : Default progressive blocking passes
-   `np_default_weights()` : Default per-profile field weights
-   `np_default_geo_weights()` : Default location-granularity credits
-   `np_train()` : Train a supervised match combiner
-   `np_benchmark()` : Benchmark scoring methods by cross-validation
-   `np_auc()` : Area under the ROC curve (Mann-Whitney form)
-   `np_evaluate()` : Evaluate scored pairs against known labels
-   `np_tune_thresholds()` : Tune YES / MAYBE thresholds from labelled
    data

</div>

<div class="section level2">

## Review & labeling hand-off

<div class="section-desc">

Tier 6: package what the algorithm could not settle. Review frames, LLM
prompts, and calibration/labeling tools.

</div>

</div>

<div class="section level2">

-   `np_label_frame()` : Build a labelling frame for training and
    evaluation
-   `np_calibration_frame()` : Build a labelling frame for threshold /
    weight calibration
-   `np_label()` : Attach labels to candidate pairs
-   `np_preview_pair()` : Preview the field-by-field comparison for one
    candidate pair
-   `np_veto_audit()` : Extract vetoed pairs for auditing and training
-   `np_bmf_review_fields()` : Default BMF context fields for the review
    queue
-   `np_sam_review_fields()` : SAM context fields for the review queue
-   `np_as_prompt()` : Render a review case as an LLM adjudication
    prompt
-   `np_as_prompts()` : Render every review case as a prompt
-   `np_review_report()` : Render a review frame as a static HTML report

</div>

<div class="section level2">

## Data management, fetching & reporting

<div class="section-desc">

Resolve data assets, fetch/prepare source files, run incremental diffs,
and report on a run. These build a reference from raw NCCS BMF and SAM
files;
[matchdb](https://nonprofit-open-data-collective.github.io/matchdb/) is
the shorter path to a reference, and supplies tier 1 (alias enumeration)
as well.

</div>

</div>

<div class="section level2">

-   `np_data_root()` `np_data_path()` `np_data_init()` : npmatch data
    asset directories
-   `np_manifest()` `np_manifest_add()` : Record and read the data-asset
    manifest
-   `np_source_urls()` : Known npmatch data sources
-   `np_fetch()` : Download a data file
-   `np_fetch_bmf()` : Fetch the reference BMF (pinned archive)
-   `np_fetch_sam()` : Fetch a SAM extract (pinned archive or a URL you
    supply)
-   `np_read_sam()` : Read a raw SAM public extract
-   `np_sam_layout()` : SAM public extract column layout
-   `np_flag_nonprofits()` : Filter a SAM extract to nonprofits
-   `np_prepare_sam()` : Download-and-prepare a SAM extract for matching
-   `np_diff_unmatched()` : Retain only source records not already
    matched (incremental matching)
-   `np_run_report()` : Summarise a cascade run as a report

</div>

<div class="section level2">

## Datasets

<div class="section-desc">

The hand-labeled 1,502-org training/evaluation benchmark.

</div>

</div>

<div class="section level2">

-   `npmatch_eval` : npmatch evaluation frame (1,502-org benchmark)
-   `npmatch_groundtruth` : npmatch ground-truth master (1,502-org
    benchmark)

</div>

<div class="section level2">

## Geography helpers

</div>

<div class="section level2">

-   `np_clean_geo()` : Clean and standardize city and state fields
-   `np_city_aliases()` : Common city aliases
-   `np_augment_geo()` : Augment records with ZIP-level geography
-   `np_ruca_urban()` : Collapse a RUCA code to an urban / rural flag
-   `np_load_hud()` : Load a HUD USPS ZIP crosswalk file
-   `np_load_ruca()` : Load a USDA ERS ZIP-code RUCA file
-   `np_load_zipcode_db()` : Build a ZIP crosswalk from the zipcodeR
    package

</div>

</div>
