# npmatch data management

npmatch does **not** bundle data — the reference files are large (BMF ≈ 1.6 GB
active / 3.4 GB unified) and versioned on their own cadence. This note describes
how source, derived, and output data are organised, what is built during a run,
and what is reusable vs. ephemeral.

## Three tiers of data

| Tier | What | Lifecycle | Tracked in git? |
|---|---|---|---|
| **A. Source snapshots** | Raw BMF + SAM extracts | Downloaded, versioned, immutable | No — archived externally |
| **B. Derived assets** | Normalized reference + IDF / frequency tables | Built **once** per source vintage, reused | No — rebuildable from A |
| **C. Run outputs** | Crosswalks, evaluation frames, run reports | Per run | Small ones optionally |

## Folder layout

Resolved from `getOption("npmatch.data")` → `NPMATCH_DATA` env var → `~/npmatch-data`.
Create it with `np_data_init()`; address it with `np_data_path()`.

```
<data-root>/
  raw/          bmf_<vintage>.csv, sam_<yyyymm>.dat            (Tier A)
  normalized/   reference-<vintage>.rds, token_idf-<vintage>.rds, name_freq-<vintage>.rds  (Tier B)
  results/      crosswalk-<run>.csv, eval-frame-<run>.csv, run-report-<run>.md             (Tier C)
  MANIFEST.csv  provenance: source, url, download_date, md5, row_count
```

`np_manifest_add()` records each asset (auto-fills md5 + row count from a path);
`np_manifest()` reads the table. This is what makes a run reproducible:
documentation can cite exact vintages and a colleague can verify identical bytes.

## Sources & fetching

* **BMF** — NCCS catalog (already cleaned/geocoded; pick a vintage):
  <https://nccs.urban.org/nccs/catalogs/catalog-bmf.html>
* **SAM** — historical monthly public extract:
  <https://sam.gov/data-services/Entity%20Registration/Public%20-%20Historical>
  **SAM is raw**: it must be filtered to nonprofits using the flags in
  `dev/prototype/IDENTIFY-NONPROFITS.R`, and its column headers lower-cased /
  underscored, before it can be mapped with `np_map_sam()`. (BMF ≈ ready to
  normalize; SAM ≈ needs preprocessing first.)

Two modes: **pinned** (download the archived snapshot used in the docs for
exact reproducibility) and **fresh** (pull the latest to check for updates).

Helpers (`R/fetch.R`):

* `np_source_urls()` — registry of pinned archive URLs + fresh source pages.
* `np_fetch(url, dest)` — download (large-file friendly), records to the manifest.
* `np_fetch_bmf(which=)` — pinned BMF (`"unified"`/`"processed"`/`"dictionary"`).
* `np_fetch_sam(url=)` — pinned or user-supplied SAM extract.
* `np_read_sam()` / `np_sam_layout()` — read the headerless pipe-delimited `.dat`.
* `np_flag_nonprofits()` / `np_prepare_sam()` — filter SAM to nonprofits
  (`BUS TYPE STRING` contains `A8`/`BZ`/`2U`/`A7`) and write the ready-to-match subset.

**Archive host (NCCS S3):** `https://nccsdata.s3.dualstack.us-east-1.amazonaws.com/crosswalks/npmatch/`.
As of setup, `bmf_2026_01_processed.csv` and `bmf_2026_01_data_dictionary.csv`
are public; `bmf_unified_geocoded.csv`, the SAM extract, and the sample files
return HTTP 403 (not yet public / not uploaded) — those object ACLs need fixing
before `np_fetch_bmf("unified")` / `np_fetch_sam()` will work.

## Incremental matching (differencing)

`np_diff_unmatched(fresh, crosswalk)` returns only the source records **not
already matched**, so a refreshed extract re-matches just the new/unresolved
residual instead of the whole file:

```r
sam   <- np_prepare_sam(np_fetch_sam())          # fresh nonprofits
xwalk <- read.csv(np_data_path("results", "crosswalk-latest.csv"))
todo  <- np_diff_unmatched(sam, xwalk)           # drop already-matched UEIs
res   <- np_cascade(todo, reference)             # match only the residual
# append res's YES/MAYBE picks to the crosswalk, write a new dated crosswalk
```

A record counts as already matched if its key appears in the crosswalk with a
status in `matched_values` (default `YES`). Pass `matched_values=c("YES","MAYBE")`
to also re-run review-pending cases against a refreshed reference; with no
status column, any appearance counts as matched. Keys are auto-detected
(`uei` / `UNIQUE ENTITY ID` / `unique_entity_id` / `.id`).

## What a run builds (asset inventory)

`np_normalize()` adds ~19 derived columns **inside** the reference/query data
frame — `name_key`, `name_gen/nums/ord/dir/form`, `dba_key`, `division_key`,
`street_key/num/name/type`, `is_po_box`, `zip3/zip9`, `state_abb`. Nothing is
hashed; blocking is IDF-weighted **tokenization** computed on the fly.

| Asset | Built by | Cost | Reusable? |
|---|---|---|---|
| Normalized reference | `np_normalize(np_reference())` | High (millions of rows) | **Yes** — cache to `normalized/` |
| `token_idf` (per-token IDF) | `np_token_idf(name_key)` | Medium | **Yes** — cache |
| `name_freq` (distinctiveness) | `np_name_freq(name_key)` | Medium | **Yes** — cache |
| Normalized query | `np_normalize(np_query())` | Low | rebuild each run |
| Candidate pairs / features / scores | `np_block`/`np_compare`/`np_score` | High | **Ephemeral** — except `attr(res,"pairs")`, the scored union that feeds the review frame + training table |

### Known gap (roadmap item)

`np_cascade()` currently **re-normalizes the reference and recomputes
`token_idf`/`name_freq` on every call** — it does not yet accept a pre-normalized
reference or cached tables. Caching the Tier-B assets only pays off once the
cascade can skip that work. Planned enhancement: detect an already-normalized
reference and accept optional `name_freq` / `token_idf` arguments, turning the
~hour normalization into a one-time cost.

## Run report

`np_run_report(res, inputs=, timings=, outputs=, reference=)` assembles a
Markdown report from a cascade result (reads `attr(res,"stages")` and
`attr(res,"pairs")`, so no labelled truth set is required):

1. **Provenance** — version, config, input files + vintages.
2. **Matching process** — per-pass cascade table, avg candidates per org, how
   matches were formed (match-type + `name_ver_x` × `name_ver_y` cross-tab).
3. **Outcome** — YES / MAYBE / NO with margins and vetoes.
4. **Operations** — timings, files written.
5. **Next stage** — the MAYBE review queue and where the LLM prompts come from
   (`np_as_prompts(np_route(res))`).

## Roadmap

1. ~~Folder convention + manifest + path accessors~~ — `R/assets.R`.
2. ~~`np_run_report()`~~ — `R/report.R`.
3. Cascade caching (skip-if-normalized; optional `name_freq`/`token_idf` args).
4. ~~Fetch/preprocess helpers + incremental diff~~ — `R/fetch.R`.
