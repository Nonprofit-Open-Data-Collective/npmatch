# Review workbooks

Turns `eval_frame_full.csv` into the Excel workbooks colleagues review, plus the
reviewer's guide that ships alongside them.

```
Rscript theme-eval-frame.R states      # one workbook per state (default)
Rscript theme-eval-frame.R full        # the single 332k-row workbook
Rscript theme-eval-frame.R all         # both
Rscript theme-eval-frame.R CO NY       # rebuild named states only
```

Output goes to `<run>/review/` — state files under `review/by_state/`. The run
directory defaults to `data-dev/runs/COMBINED_RESULTS`; override with
`NPMATCH_RUN_DIR`.

Needs `data.table`, `openxlsx`, `openssl`, `readxl`.

## Files

| | |
|---|---|
| `theme-eval-frame.R` | The build. |
| `stage3-secondary-review.R` | Builds `review/STAGE-03-SECONDARY-REVIEW.xlsx` from the state workbooks — see below. |
| `build-size-uss.R` | Aggregates federal award totals per UEI → `size_uss.rds`. Run before the build if that file is missing or stale. |
| `dictionary.R` | Definitions for all 118 fields, plus the section map. |
| `column-order.txt` | The 115 reviewer-facing columns, in order. |
| `reviewers-guide.md` | Source for the Word guide. |
| `reference.docx` | Pandoc style template (headings themed to the workbook header). |

Rebuild the guide (pandoc; RStudio bundles a copy under
`resources/app/bin/quarto/bin/tools`):

```
pandoc reviewers-guide.md -o REVIEWERS-GUIDE.docx \
  --reference-doc=reference.docx --toc --toc-depth=2 -V papersize=letter
```

## What the build does, and why

**Column names and order follow `eval_frame_full.xlsx`, not the CSV.** That
workbook is the reviewer-facing presentation of the same data: it front-loads the
fields a reviewer actually reads and renames 18 columns — `s3_*` → `llm_*`,
`final_stage` → `match_stage`, `final_reason` → `match_reason`. The two sources
were checked row-for-row and hold identical values, so the build reads the CSV
(fast) and applies the xlsx's naming. `column-order.txt` is that contract; the
script asserts the frame matches it exactly.

One rename is ours rather than the xlsx's: **`is_top_candidate` →
`is_best_candidate`**. "Top" was being read as "the answer", which it is not once
stages 2 and 3 have had their say.

**`row_id` is prepended as column 1** — `RID-` plus a 12-character MD5 of
`uei|ein|total_score`, computed from the raw CSV strings before type conversion.
That triple is unique across the frame (the script aborts if it ever stops being),
so a row can be cited without pasting it, and the id is identical in a state
workbook and the full one. It is derived, not a sequence: rebuilding reproduces
it; a row whose score changes gets a new one.

**Two size markers sit after `ein`**, so large organizations can be sorted to the
top without scrolling out to the BMF block.

- **`size_uss`** — total federal award obligations for the UEI, FY2008-2026,
  contracts plus assistance, from the USASpending annual archives. A source-side
  measure, so it is constant across a UEI's block.
- **`size_bmf`** — IRS-reported annual revenue of the EIN *on that row*, copied
  from `bmf_revenue_amount`. Row-level, so on a non-matched candidate it is that
  candidate's revenue, not the registrant's.

They are not comparable in magnitude: `size_uss` is a 19-year cumulative total,
`size_bmf` a single year. Their rank correlation among matched organizations with
both populated is only about 0.43, so they genuinely measure different things —
federal relationship versus overall budget.

**`size_uss` blank means unknown, not zero.** The USASpending archive was filtered
to the matched crosswalk, so its universe is exactly the matched UEIs. A matched
registrant absent from it drew no federal awards in the period and is written as
0; an *unmatched* registrant was never in scope and is left blank. Collapsing
those two into 0 would invent a fact about ~33,600 organizations.

**There is no source-side size field in SAM.** All four upstream SAM extracts
carry 142 columns with no revenue, receipts, assets or employee count — the
public Entity Management layout simply omits the SBA size data. That is why
`size_uss` comes from USASpending rather than from the registration itself.

**Rows are sorted by `uei`**, stably, so each group keeps its candidate ordering
(top1, top2, top3, best_name, best_addr, then any stage-3 row). The source file is
not grouped: about 4,300 UEIs have their candidate block early and a stray
stage-3 row in the tail.

**Each UEI goes to exactly one state file** — the modal `state_uss` across its
rows, falling back to the modal `state_bmf` of its candidates when the source
record carries no state (that fallback places ~10,300 otherwise-unknown UEIs).
Non-US states collapse to `foreign`; nothing left goes to `unknown`.

**Shading is conditional formatting, not per-cell styles.** At 332k × 117 that
would be 39M style records. Instead a hidden `_band` column carries a 0/1 parity
flag and two CF rules read it — a few lines of XML regardless of row count.

- Parity is computed **per output file**. Computing it once on the full frame and
  then slicing by state breaks the alternation, because consecutive groups within
  a state are not adjacent in the full frame.
- The rules are written mutually exclusive — `$<final>2=1` for orange,
  `AND($<band>2=1, $<final>2<>1)` for gray — so Excel's rule priority never
  matters.

**Orange marks `is_final_ein`, not `is_best_candidate`.** `is_best_candidate` is
stage 1 only: it is 0 on every answer stages 2 and 3 produced (~9,100 rows) and 1
on ~7,900 stage-1 picks those stages later overrode. `is_final_ein` is the
stage-agnostic answer — exactly one row per matched UEI, none per unmatched one.

## Gotchas worth keeping

- **`zip5_uss` / `zip5_bmf` must stay text.** They are numeric-looking but carry
  leading zeros; `geo_zip5` and friends are 0/1 flags, not ZIPs, and are
  deliberately not in the keep-as-text list.
- **A workbook open in Excel is locked, and `openxlsx` only warns** — which would
  leave a stale file looking like a fresh build. The script verifies the write
  landed and diverts to `<name>-NEW.xlsx` if not.
- **Field definitions are sourced, not invented**:
  `vignettes/candidate-evaluation-frame.qmd` for scores/names/geography,
  `R/final.R` for the `final_*` rollup, `R/stage3.R` and
  `dev/RESEARCH-PROTOCOL.md` for the `llm_*` fields. Value domains were read off
  the data, so `candidate_type` is documented in its real `best_addr+best_name+top1`
  combination form.
- **The `llm_*` columns are stage 3 only** — populated on all stage-3 matches,
  empty on every stage-1 and stage-2 one. Stage 2 leaves its verdict in
  `final_confidence` and `match_reason` instead. A blank `llm_determination`
  means the case never needed research, not that it went unreviewed.

## Stage-3 secondary review

```
Rscript stage3-secondary-review.R           # reuses cached steps
Rscript stage3-secondary-review.R --fresh   # redo load / scan / recompute (~25 min)
```

Rows with a blank `is_best_candidate` are the synthetic rows the rollup adds
(`candidate_source` = `stage3_research` or `none`), which carry NA for every
candidate-level column. This build collects every such UEI with all its rows
and fills the blanks — never overwriting a value — from, in order: stage 1's
scored pairs (`<run>/01_stage1/interim/pairs-*.rds`) when stage 1 scored the
pair; `np_compare()` against `NORM-BMF-UNIFIED-v2.rds` (the cache stage 1 used)
when it did not; and `<run>/00_sams/sam_query.csv` for the SAM side. Filled
cells are blue italic and listed in `filled_columns`.

`stage1_pair_status` says why stage 1 missed each stage-3 EIN (blocking,
scoring or veto), and `fully_vetoed` flags UEIs where stage 1 scored pairs but
the hard veto removed every one. Intermediate steps are cached under
`<run>/review/_secondary-review-work/`. Needs `pkgload` and `readxl` on top of
the main build's packages.

## Known issue in the source data

126 rows carry `candidate_source = "stage3_research"` with `final_outcome =
NO_MATCH` and a blank `final_ein`. Per `R/final.R`, synthetic rows are only
emitted for UEIs that have a final EIN, so these should not exist. They shade
correctly (not the answer), so the workbooks are unaffected — but it points at
something upstream.
