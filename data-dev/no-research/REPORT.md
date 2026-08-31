# NO-case research — 2025NOV + 2026MAY

- generated: 2026-08-26
- protocol: `dev/RESEARCH-PROTOCOL.md` (Tier 1 local -> Tier 2 ProPublica -> Tier 3 web)
- sampling seed: 20260826

## Pools

| stage | definition | pool | sampled |
|---|---|---|---|
| stage 1 | matcher dropped outright (not YES, not MAYBE) | 34,335 | 500 |
| stage 2 | LLM adjudication rejected the MAYBE (MAYBE -> NO) | 6,166 | 500 |

Stage-1 sample is stratified by run: 459 from 2025NOV, 41 from 2026MAY, proportional to pool.

**The 2026MAY run has no stage-2 pool.** No LLM adjudication was ever run against its
MAYBE queue, so every stage-2 case comes from 2025NOV. The 31 2026MAY cases that moved
MAYBE -> NO did so through the address-gate re-run, not adjudication, and are tagged
`no_origin = algorithm_regate` inside the stage-1 pool.

## Outcome

| determination | stage 1 | stage 2 |
|---|---|---|
| `match` | 71 (14.2%) | 142 (28.4%) |
| `nonprofit_not_in_bmf` | 266 (53.2%) | 145 (29.0%) |
| `not_a_nonprofit` | 150 (30.0%) | 202 (40.4%) |
| `cant_determine` | 13 (2.6%) | 11 (2.2%) |

## The headline: how wrong is the NO bucket?

- **stage 1: 14.2% of NO cases are real matches** (71/500)
- **stage 2: 28.4% of MAYBE -> NO cases are real matches** (142/500)

Scaled to the pools, that implies roughly **4,880** recoverable matches sitting in stage-1 NO and **1,750** in stage-2 NO — about **6,630** additional crosswalk rows available from the NO bucket.

The two stages fail differently. Stage-1 NO is dominated by cases that *should* be NO —
foreign registrants, individuals, for-profits (64.8% of the sample combined).
Stage-2 NO is the expensive bucket: these cases already had a credible candidate slate, and
the adjudicator rejected a correct match 28.4% of the time.

## Confidence and resolving tier

| | stage 1 | stage 2 |
|---|---|---|
| confidence `high` | 430 | 398 |
| confidence `medium` | 54 | 88 |
| confidence `low` | 16 | 14 |
| resolved at `tier1` | 406 | 279 |
| resolved at `tier2` | 21 | 39 |
| resolved at `tier3` | 73 | 182 |

EINs recovered and recorded: **235** (82 stage-1, 153 stage-2). This exceeds the match count because a `nonprofit_not_in_bmf` case can still have a known EIN — an inactive/990-only filer or a state registration.

## Adversarial verification

All 55 matches whose EIN sat in a different state from the SAM record were re-run through a second agent instructed to **refute** them, hunting the federated / parent-sponsor trap (a local Section 202 property handed its national sponsor's EIN, a local corps handed a territorial EIN).

- confirmed: 52
- refuted: 2
- uncertain (downgraded to low confidence): 1

The trap turned out to be rarer than expected: most cross-state assignments were
single-purpose entities that genuinely hold their own EIN but are booked at a sponsor's
mailing address, which is why the state disagreed.

## Caveats

- **ProPublica rate-limited.** Running 20 research agents concurrently drew HTTP 429s; 67 cases (7 stage-1, 60 stage-2) had Tier 2 unavailable and were settled on BMF grep plus general web instead. Those cases say so explicitly in `sources`. A serial re-run of just those would firm them up.
- **24 cases remain `cant_determine`** after all three tiers; `notes` records what was missing.
- Determinations are agent research, not audited ground truth. The `sources` column carries
  the actual URLs and greps behind each call so any row can be re-checked.

## Files

| file | what |
|---|---|
| `FINDINGS-STAGE1-NO-500.csv` | 500 stage-1 NO cases, researched |
| `FINDINGS-STAGE2-NO-500.csv` | 500 stage-2 NO cases, researched |
| `POOL-STAGE1-NO.csv` / `POOL-STAGE2-NO.csv` | the full NO pools these were drawn from |
| `QC-EIN-CHECK.csv` | every recovered EIN cross-checked against the unified BMF |
| `BMF-GREP.tsv` | flat 3.69M-row unified BMF used for Tier-1.5 grep |
| `AGENT-BRIEF.md` / `VERIFY-BRIEF.md` | the instructions the research and refutation agents ran |
| `01_*.R` .. `10_*.R` | the reproducible pipeline |

### Key columns in the findings tables

`ein_found`, `determination`, `resolving_tier`, `confidence`, `sources`, `judgement`, `notes`,
`verified`. Stage-2 rows additionally carry `rejected_ein`, `llm_reason` and the full
`candidates` slate the adjudicator saw, so a wrong rejection can be traced to its cause.
