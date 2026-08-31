# NOV-2025 MAYBE review — LLM adjudication plan

Adjudicate the **18,498 MAYBE cases** (the review hand-off from the match run)
with **Claude subagents**, one per shard, producing a YES/NO decision + **EIN +
confidence + reasoning** for every source UEI. Mirrors the match run: **batched,
checkpointed, resumable**.

---

## 1. Inputs / outputs

| | |
|---|---|
| **Source** | 133 MAYBE shards `../review-NN-partKK.csv` (from `np_route()`), 18,498 UEIs, 63,587 candidate rows |
| **Slimmed** | `slim/slim-NN-partKK.csv` — the ~35 adjudication columns only (built by `slim.R`) |
| **Per-shard decision** | `decisions/decision-NN-partKK.csv` — one row per UEI |
| **Final** | `DECISIONS-ALL.csv`, `CROSSWALK-AUGMENTED-2025NOV.csv`, `REVIEW-REPORT.md` |

**Decision schema** (`decisions/decision-*.csv`):

| col | meaning |
|---|---|
| `uei` | source org id (verbatim) |
| `best_ein` | chosen BMF EIN when YES; empty when NO |
| `llm_decision` | `YES` (best_ein is the same org) / `NO` (no credible candidate) |
| `llm_confidence` | `high` / `medium` / `low` |
| `llm_reason` | one concise clause (comma-free; semicolons instead) |

## 2. How adjudication works

Each shard is handed to one **general-purpose Claude subagent (Sonnet)** that:
reads the slim CSV, and for every UEI judges organizational **identity** (not
string overlap) across all its candidates — allowing abbreviations/DBAs/reordering,
requiring consistent org **type** and corroborating **geography**, overriding the
pipeline's top-scored pick when a lower-scored candidate is clearly the true org,
and never selecting a `veto=TRUE` candidate. It writes one decision row per UEI
and returns a count summary.

Orchestration is the **`llm-review-maybe` workflow** (fan-out, one agent per
shard, concurrency-capped at ~14).

Script: `.../workflows/scripts/llm-review-maybe-wf_49c1f6f7-f4e.js`
(re-invoke with `{scriptPath, args:{review_dir, bases:[...]}}`).

## 3. Quality gate + resume (`validate.R`)

A shard counts as **done** only when its decision file passes `validate.R`:
exact header, **one row per UEI** (no missing/extra/dupe UEIs), `llm_decision ∈
{YES,NO}`, `llm_confidence ∈ {high,medium,low}`, and every YES `best_ein` is a
**real candidate EIN** for that UEI (no hallucinated EINs). Invalid/missing
shards are written to `pending.txt`.

**Resume = re-run `validate.R`, then launch the workflow with `bases =` the
pending list.** Finished, valid shards are never redone.

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" validate.R   # refresh pending.txt
```

## 4. Run loop

1. `slim.R` — build slim shards + `manifest.csv`
2. Pilot: workflow on 3 shards → `validate.R` → eyeball quality
3. Full: workflow on remaining pending bases → `validate.R`
4. `repair.R` — deterministically fix invalid files (see below), then `validate.R`
5. Re-run only shards still failing (`bases =` pending) → `validate.R`
6. Repeat 4–5 until `validate.R` reports **0 pending**
7. `merge.R` — build `DECISIONS-ALL.csv`, `CROSSWALK-AUGMENTED-2025NOV.csv`
   (auto-YES + LLM-YES, distinguished by a `source` column, carrying
   `llm_confidence` + `llm_reason`), and `REVIEW-REPORT.md`

**`repair.R`** salvages agent output without a re-run: robust re-parse of
comma-in-reason rows (reason is the last field), confidence normalization, and
**downgrades any YES whose `best_ein` is not a real candidate for that UEI to
NO** (never promotes an unverifiable EIN). It flags bases that are genuinely
missing a UEI as `NEEDS-RERUN`.

**Dedup:** some source UEIs recur across shards (duplicate SAM registrations
matched in >1 compute chunk). `merge.R` collapses `DECISIONS-ALL` and the
augmented crosswalk to **one row per UEI** (YES/high-confidence preferred;
auto-YES preferred over LLM-YES) and reports how many were collapsed and how many
duplicate adjudications disagreed.

## 5. Monitoring

```bash
ls decisions/decision-*.csv | wc -l                # shards written / 133
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" validate.R   # done vs pending + tallies
cat progress.log
```

Live workflow progress: `/workflows`.

## 6. Notes

- `bmf_active` is blank (unified reference has no active flag), so it is not used
  in adjudication.
- Reasons are kept comma-free so the CSVs need no quoting and validate cleanly.
- The augmented crosswalk keeps auto-YES and LLM-YES separable via `source`; all
  LLM rows carry confidence + reasoning so you can filter (e.g. high-confidence
  only) downstream.
