# Batch-1 re-run: old same-state gate → new address-gated recovery

Re-ran the exact batch-1 query set (2,130 unique UEIs) against the unified BMF (3.69M,
cached) under the **current address-gated** name-blind recovery, to remove the code seam in
`CROSSWALK-ALL` and measure the impact of the compare change.

## Tier totals (2,130 UEIs)

| tier | old gate | new gate | delta |
|---|---|---|---|
| YES   | 1,402 | 1,402 | **0** |
| MAYBE | 193   | 162   | **−31** |
| NO*   | 535   | 566   | **+31** |

\* NO includes the ~37 queries with no candidate at all.

## Transition matrix (rows = old, cols = new)

| old \ new | YES | MAYBE | NO |
|---|---|---|---|
| **YES**   | 1,402 | 0 | 0 |
| **MAYBE** | 0 | 162 | **31** |
| **NO**    | 0 | 0 | 535 |

The change is **strictly one-directional: 31 cases MAYBE → NO.** No YES moved in either
direction; no NO was promoted. Auto-accept is completely unaffected.

## What the 31 are, and why they moved

Every one of the 31 dropped cases had a **name-blind (`token_overlap`) top candidate with no
confirming address**:

| signal | 31 dropped (MAYBE→NO) | 162 MAYBE that stayed |
|---|---|---|
| top-candidate match_type | **31/31 `token_overlap`** | mixed: exact 63, name 30, dba 23, token_overlap 46 |
| median address similarity | **0.00** (max 0.33) | **0.49** |
| name similarity (min/med/max) | 0.75 / 0.82 / 1.00 | — |
| score (min/med/max) | 0.650 / 0.670 / 0.780 | — |

So the gate does exactly what it was tightened to do: a shared distinctive token used to lift
a pair into review **even with no address match**; now the recovery fires **only when the
address is confirmed** (same ZIP5 / street number / PO box). Address-confirmed name-blind
recoveries (46 of them) stayed in review.

### Examples of the 31 (name_uss ↔ name_bmf, addr_sim ≈ 0)

Mostly genuine **non-matches** that shared tokens — correctly moved to NO:

- `SALEM GRACE CHURCH OF THE NAZARENE` ↔ `GRACE FELLOWSHIP CHURCH OF THE NAZARENE`
- `HOODOO WATER SEWER DISTRICT` ↔ `ROCKY BEACH WATER AND SEWER DISTRICT`
- `LAND AND SEA MARKET TAMPA PALMS` ↔ `TAMPA PALMS WOMENS CLUB`
- `HIGH STREET BAPTIST CHURCH` ↔ `HOSACK STREET BAPTIST CHURCH`

A **minority look like real matches** that simply lack a BMF address to confirm them — these
are the thin recall cost (now NO = "no confident BMF match", deferred to stage-2 research, not
mis-accepted):

- `SC FIRST STEPS TO SCHOOL READINESS` ↔ `SOUTH CAROLINA FIRST STEPS TO SCHO…` (acronym)
- `PRINCE JADE NONPROFIT ORGANIZATION` ↔ `PRINCE JADE` (name_sim 0.95)
- `FREE KICKS FOUNDATION` ↔ `FREE KICKS SOCCER ACADEMY` (name_sim 0.95)

## Impact summary

- **Auto-accept (YES): unchanged** — same 1,402, so precision and recall of the accepted
  crosswalk are identical. `CROSSWALK-ALL-2026MAY.csv` is unchanged at **6,875** unique YES
  (regenerated from the new batch-1 so all 10,658 now use one gate — the seam is gone).
- **Review queue: 16% leaner and cleaner** — batch-1 MAYBE 193 → 162; combined residual
  review ~933 → ~902. The removed cases are address-unconfirmable name-blind pairs, most of
  which are true non-matches.
- **Recall: a small, bounded cost** — a handful of genuine address-less name-blind matches
  now land in NO instead of review. This is the documented two-part behavior: they are not
  lost, they move to the stage-2 (human/LLM external research) bucket.
- **Blocking / cascade protocol: identical** — all passes, including block-by-state, run
  unchanged; only the name-scoring recovery gate changed.
