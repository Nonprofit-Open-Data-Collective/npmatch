# match report

This report is based upon a sample of 1,502 organizations from the SAMS database matched against the Unified BMF (NCCS BMF version). These cases constitute both a **training dataset** and a **validation dataset**. 

- **1,000 a true random sample** used to benchmark algorithm performance 
- **502 hard cases** (an oversample of difficult
residual matches) used to probe model failures and improve the classifier

## Record Linkage Performance

The goal is to identify a BMF record (and EIN) for each of the 165,000 organizations that are flagged as nonprofits in the SAMS database. 

Performance is determined by: 

- A positive event is **a correct EIN link**. 
- The **recall metric** = correct links ÷ linkable
orgs (how many actual nonprofits are retrieved by the process)
- The **precision metric** = correct links ÷ accepted
- The MAYBE tier is a human/LLM review queue.

The ground truth was established by additional human + LLM analysis of the 1,502 cases in the training dataset to confirm that matches were correct, and to investigate whether non-matches were actual nonprofits and whether they have records in the BMF that were missed. 

| Metric | Random (n=1,000) | Hard (n=502) | All (n=1,502) |
|---|---:|---:|---:|
| Linkable orgs | 807 | 380 | 1,187 |
| Non-linkable orgs | 193 | 122 | 315 |
| **Recall — auto (YES only)** | 88.1% | 70.0% | 82.3% |
| **Recall — auto + review** | **95.0%** | 86.1% | **92.2%** |
| **Precision (YES picks correct)** | **99.2%** | 96.0% | **98.3%** |
| Auto-accept false positives | 5 | 7 | 12 |

The **random sample** column represents the expected real-world performance: ~95% of linkable
nonprofits are recovered once the review tier is worked, at ~99% precision on the
auto-accepted matches. The hard column is the deliberately-difficult residual.

## Breakdown of Algorithm Only Performance

| Tier | Random | Hard | Meaning |
|---|---:|---:|---|
| YES (auto-accept) | 717 | 277 | strong name + address, no veto |
| MAYBE (review) | 123 | 136 | surfaced for human/LLM confirmation |
| NO (withhold) | 144 | 87 | nothing cleared the review floor |
| No candidates | 16 | 2 | blocking found nothing |

## Case Summary

Because some organizations are legitimately unmatchable (not nonprofits, or nonprofits like churches that might not appear in the BMF), the match rate must be
read against how often a match *can* exist:

| Outcome class | Random | Share |
|---|---:|---:|
| in BMF (matchable) | 807 | 80.7% |
| nonprofit, not in BMF (churches, lapsed, state-only) | 85 | 8.5% |
| not a nonprofit (SAM mislabels) | 65 | 6.5% |
| no match / n.a. | 22 | 2.2% |
| can't determine | 21 | 2.1% |

So ~81% of SAM records are ACTUALLY nonprofits in the BMF and ~19% are correctly sorted into the NO category, which would typically mean that a match was not achieved but in this case NO can also be a TRUE NEGATIVE indicating that the record is NOT in fact a nonprofit. We cannot assume that just because a match is not returned an organization is not a nonprofit, so the NO cases in the training data have been reviewed to confirm that a NO is generally correct as an org outside of the set of true nonprofits, not a failed match. 

Two denominators therefore matter:

- **recall** or correct identification of true nonprofits is **near 95%**
- **yield over the whole population:** the share of *all* source records that receive a correct EIN link (YES + review) is **around 77%** 

## Notes

- **Inactive matches were relabeled.** 30 orgs the labeling first tagged "not in
  BMF" (because it checked only the *active* file) are actually exact-name +
  address matches to *inactive* BMF records; these were corrected to
  `in_bmf_match` with the inactive EIN (20 by rule, 10 confirmed on manual/web
  review). A further 6 candidates were reviewed and rejected as non-matches
  (affiliate siblings, cross-state name collisions). This is why the unified
  reference is used: it recovers real lapsed-org links the active file cannot.
- **MAYBE is not an error tier** — it is the review queue; most non-linkable orgs
  that aren't withheld land here, not in YES.

## Files in this bundle

| File | What |
|---|---|
| `EVAL-FRAME-1502-MERGED.csv` | Candidate-level evaluation frame (150 cols) + ground truth — the reviewable dataset |
| `DATA-DICTIONARY-EVAL-FRAME.md` / `.csv` | Column dictionary for the evaluation frame |

Not provided but available: 

| `GROUNDTRUTH-MASTER-1502.csv` | Query-level ground-truth labels (1 row per org) |
| `MATCH-REPORT-1502.csv` | Per-org algo decision vs. ground truth |

