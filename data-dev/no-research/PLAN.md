# Full NO-case review — operating plan (rev. 2)

Pilot finding: **14.2% of stage-1 NO and 28.4% of stage-2 (MAYBE→NO) cases are real
matches.** Across the 40,860-case NO pool that is roughly **6,730 recoverable crosswalk
rows**. This plan scales the pilot to the full pool with instructions that produce the same
answer no matter which agent, machine, or day runs them.

Everything below is implemented in `data-dev/no-research/*.R`, numbered in execution order.

**Changes in rev. 2:** 2026MAY stage-2 folded in (359 cases), pool final at 40,860; the
Tier-1 gate audited **twice** and fixed; the efile 990 header index built and wired in as
Phase 1.5; per-case cost columns added to the result tables; model choice separated from
concurrency as a cost lever.

---

## 0. The run, by case count

Computed from the live pipeline — the escape hatch and efile index are in the seed script,
and the rates are the post-refresh pilot measurements (`26_final_plan.R`).

| | Cases | Share |
|---|---|---|
| **Total NO pool** | **40,860** | 100% |
| Settled by code, no agent | 21,717 | 53% |
| **Sent to research** | **19,143** | **47%** |

**Settled by code** — the four gates that audited at 0-1.2% error:

| gate | pooled |
|---|---|
| `foreign` | 14,522 |
| `for_profit_form` (no BMF/efile signal) | 3,777 |
| `individual` | 1,812 |
| `government` | 1,606 |

**Sent to research** — with the reason attached to each case:

| why | pooled |
|---|---|
| open nonprofit candidate | 11,506 |
| **efile 990 filer shares this website** | **2,775** |
| **SAM 2L flag unreliable** | **1,674** |
| confirm Tier-1 exact name hit | 1,565 |
| church, may or may not be in BMF | 1,555 |
| foreign address but US-incorporated | 69 |

**4,449 of those 19,143 are there only because of the escape hatch.** Without it they would
have been silently closed, and the audits say roughly 1 in 20 of them is a real match.

| | |
|---|---|
| Agents (8 cases each) | **2,393** |
| Tokens/case measured | 10,805 |
| **Total tokens** | **~207 M** |
| Wall clock @ concurrency 20 | **8.6 h** (3.5 h @ 50) |
| Cost — opus-5 / sonnet-5 / haiku-4.5 | **$5,171 / $2,068 / $1,034** |
| Phase-2 prefetch (separate, 0 tokens) | ~1.9 h single-threaded |
| **Expected recoveries** | **~7,300** (5,360 stage-1 + 1,940 stage-2) |
| Cost per match | $0.71 opus, $0.28 sonnet |

---

## 1. The pool

| Run | Stage-1 NO | Stage-2 NO (MAYBE→NO) | Total |
|---|---|---|---|
| 2025NOV | 31,540 | 6,166 | 37,706 |
| 2026MAY | 2,795 | 359 | **3,154** |
| **Total** | **34,335** | **6,525** | **40,860** |

2026MAY stage-1 breaks down as 2,764 algorithmic + 31 moved MAYBE→NO by the address-gate
re-run (tagged `no_origin = algorithm_regate`).

The 2026MAY stage-2 decisions (893 MAYBE → 534 YES / 359 NO) are at
`run-2026MAY/llm-review/DECISIONS-ALL.csv`; `01_build_pools.R` picks them up automatically
and warns if the NO count drifts from 359. Both runs' pools are final at **40,860**.

**The 28.4% stage-2 rate is a 2025NOV measurement.** The pilot's 500 stage-2 cases were all
drawn from 2025NOV. 2026MAY was adjudicated separately *and* ran under the tightened address
gate, so its MAYBE queue was already 16% leaner. Treat its 359 cases as their own stratum and
sample ~30 before assuming the rate carries — 4 agents, and it tells you whether the two
adjudicators fail the same way.

---

## 2. The pipeline

| Phase | What | Who runs it | Cost |
|---|---|---|---|
| 0 | Freeze inputs, rebuild the grep index | script | minutes |
| 1 | Tier-1 deterministic gate (+ the audited escape hatch) | script | free |
| 1.5 | Build the efile 990 index (one-off, reused every run) | script | ~2 GB, ~15 min |
| 2 | Tier-2 ProPublica prefetch → cache | script, single process | ~1.6 h |
| 3 | Tier-3 agent fan-out | LLM agents | see §5 |
| 4 | Merge + hard validation | script | minutes |
| 5 | Adversarial verification of risk strata | LLM agents | ~8% of ph.3 |
| 6 | Report + fold into crosswalk | script | minutes |

The ordering matters: **every phase that code can settle runs before any agent is spawned.**
Agents are the most expensive and least reproducible component, so they only ever see cases
that genuinely need judgement.

### Phase 1 — the Tier-1 gate, and what auditing it found

`03_tier1_screen.R` + `04_seed_findings.R` classify each case on SAM fields plus an exact
name-key lookup against all 3.69M BMF rows:

| gate | determination | basis |
|---|---|---|
| `individual` | `not_a_nonprofit` | SAM structure 2J + person-form name |
| `for_profit_form` | `not_a_nonprofit` | LLC / LP / PLLC in legal name |
| `government` | `not_a_nonprofit` | city, county, district, authority |
| `not_tax_exempt_corp` | `not_a_nonprofit` | SAM structure 2L |
| `foreign` (no US incorporation) | `nonprofit_not_in_bmf` | outside BMF scope |

**This was asserted, not measured — so it was measured, twice.** 167 gated cases were sent
through the full research pipeline *blind* (the packets omit the gate's verdict). The first
pass lost Tier 2 to 429s on 75 of them, so it was re-run with cached ProPublica and the new
efile index:

| Pass | Conditions | False settles | Rate |
|---|---|---|---|
| v1 | live ProPublica, 75 cases lost to 429 | 6 / 167 | 3.6% (CI 1.3–7.7%) |
| **v2** | **cached Tier 2 + efile index, zero 429s** | **8 / 167** | **4.8% (CI 2.1–9.2%)** |

**The rate went up, not down — 3.6% was a floor, exactly as suspected.** v2 is the number to
plan against: **~1,163 matches lost inside the gate pool-wide (CI 507–2,238)**.

The two passes agree on **92.2%** of determinations exactly, 95.8% forgiving `foreign` vs
`not_a_nonprofit` label swaps, and where both called `match` all 5 picked the **same EIN**.
That clears the 85% inter-agent gate this plan proposes, so the harness passes its own test.

The rate is concentrated in the two *self-reported legal-form* gates:

| gate | audited | false settles | rate |
|---|---|---|---|
| `not_tax_exempt_corp` (SAM 2L) | 16 | 4 | **25.0%** |
| `for_profit_form` (LLC/LP in name) | 21 | 3 | **14.3%** |
| `foreign` | 82 | 1 | 1.2% |
| `individual` | 16 | 0 | **0%** |
| `government` | 32 | 0 | **0%** |

**The structural gates are sound; the legal-form heuristics are not.** `individual` and
`government` are 0 for 48 across both passes. But SAM's 2L flag is wrong a quarter of the
time, and an LLC in the legal name means little — Gigi's Playhouse Raleigh **LLC** and
Nazareth Construction **LLC** are both 501(c)(3)s. Trinity Western University is Canadian yet
holds a US EIN the BMF files under a bogus NJ state code.

**The fix — un-gate any case with a full-BMF name-key hit, OR SAM structure 2L, OR a website
domain shared with a 990 efile filer:**

| | |
|---|---|
| Extra volume | 14.7% of gated cases → ~3,573 pool-wide |
| Extra cost | ~447 agents, ~39 M tokens, ~1.6 h at concurrency 20 |
| False settles caught | **8 of 8** |
| Residual | **0 observed in 142 unflagged cases** (95% upper bound 2.6%) |
| Matches lost in the gate | ~990 → **0 observed, at most ~531** |

The efile domain condition is what closes the gap: the hatch alone catches 6 of 8, and the
domain signal catches the two `for_profit_form` cases it misses. Name-as-filed adds nothing
here (0 of 8) — gated cases already ran a BMF name lookup, and efile names largely duplicate
BMF names. Keep it as a Tier-1.5 grep target during research, not as a gate condition.

Net: the gate still settles **20,700 cases (51% of the pool) for free**, now with no observed
recall loss.

### Phase 1.5 — the efile 990 index

```bash
Rscript data-dev/no-research/19_build_efile_xwalk.R    # ~2 GB download, one-off
```

Two local assets built from the NCCS efile 990 header tables, 2019-2024 (2.73 M filings):

| file | what |
|---|---|
| `EFILE-XWALK.tsv` | 660,362 EINs, one row each: name-as-filed, DBA, **website domain**, phone, address, care-of, officer, formation year, domicile state, years filed |
| `EFILE-NAMES.tsv` | 777,695 distinct name/DBA variants across years — the rebrand index |

**Why it earns its place: independent confirmation, not extra coverage.** Only 2.0% of its
EINs are absent from the unified BMF, so it finds almost no new organizations. What it adds
is a second signal — a SAM record and a BMF candidate sharing a **website domain** are the
same org, which is `high` confidence by the brief's own rubric, at zero web cost. Measured on
the pilot's confirmed matches, where both sides carry a domain they agree **81% of the time**
(51 of 63).

Limits to plan around: **990/990-EZ only, so no 990-N filers** (the small-org tail);
2019-2024 only, with e-filing mandatory just since TY2019; and **churches do not file at
all**, which is the single largest NO category. Absence from this index is weak evidence for
a church and strong evidence for a mid-size secular nonprofit.

Two fields to ignore: `F9_00_ORG_NAME_CHANGE_X` is 0.7% filled (useless despite the promising
name — use multi-year name history instead), and only 55.2% of website fields survive
normalization to a real domain, the rest being "N/A" and bare "www.".

### Phase 2 — Tier-2 prefetch (the rate-limit answer, §6)

```bash
Rscript data-dev/no-research/12_pp_prefetch.R <queue.csv> 2.5
```

One rate-limited resumable process resolves every distinct org name and writes
`PP-CACHE.tsv`. Agents read the cache. **No agent touches ProPublica.**

**Validated end to end on the 167-case audit re-run:** 167/167 cached in 1.1 minutes, **zero
429s**, and only 5 cases needed cached ProPublica as their resolving tier while 166 of 167
cited the efile index. Tier 2 is now a cheap confirmation layer rather than a bottleneck.

### Phase 3 — agent fan-out

`05_make_batches.R` emits `web-batches/batch-NNN.md`, 8 cases each. One fresh agent per
batch running `AGENT-BRIEF.md`; agents write TSV to `agent-out/`, never prose.

> **Before the next run, repoint `AGENT-BRIEF.md` Tier 2 at `PP-CACHE.tsv`** with the JSON
> API as the fallback for cache misses. It still names the HTML search URL, which is what
> produced the 429s in both the pilot and the audit.

### Phase 4 — merge + hard validation

`06_merge_findings.R` fails unless every queued case has a row, every determination is in the
closed taxonomy, every EIN is well-formed, and no `sources` is blank. `07_qc.R` then
cross-checks **every recovered EIN against the BMF** — a non-existent EIN is a fabrication
and must fail the run.

### Phase 5 — adversarial verification

`08_make_verify.R` + `VERIFY-BRIEF.md` re-run high-risk matches through an agent told to
**refute** them. Five standing strata:

1. **cross-state** matches (SAM state ≠ BMF state) — the federated / parent-sponsor trap
2. any match at `medium` or `low` confidence
3. federated names (Salvation Army, YMCA, Goodwill, United Way, NAACP, VOA, RHF, National
   Church Residences) regardless of state
4. a **random 5%** of `high`-confidence matches — an unbiased error-rate estimate
5. **a random 160 Tier-1-gated cases** — the gate audit, now a standing check rather than a
   one-off, since the gate silently decides half the pool

Pilot: 55 cross-state claims → 52 confirmed, 2 refuted, 1 downgraded (3.6% error).

---

## 3. What makes the instructions replicable

Consistency is engineered, not requested. Nine mechanisms:

1. **One versioned brief.** `AGENT-BRIEF.md` is the only instruction source; record its
   SHA-256 in the run report. Changing it mid-run starts a new run ID.
2. **Closed determination taxonomy.** Four values; free text rejected at merge.
3. **Explicit confidence rubric.** `high` = two independent signals; `medium` = one solid
   signal, nothing contradicting; `low` = plausible but unconfirmed, gap named in `notes`.
4. **Fixed schema, machine-validated.** 11-column TSV; what the agent writes is what merges.
5. **Deterministic pre-gate.** Agents never adjudicate what Phase 1 settled — half the pool
   carries zero agent variance.
6. **Fresh context per batch.** 8 cases, one agent, no carry-over between batches.
7. **Negative evidence is mandatory.** "Not found" must say where you looked and what came
   back; a blank `sources` fails validation.
8. **Never invent an EIN** — enforced by the Phase-4 BMF cross-check, not requested.
9. **Seeded + instrumented.** Fixed sampling seed; every agent's tokens and duration logged
   to `agent-telemetry.csv` / `audit-telemetry.csv`.

### Control cases — measure agreement, don't assume it

Salt **one known-answer case into every batch** from `GROUNDTRUTH-MASTER-1502.csv`,
indistinguishable from real work: a running accuracy read per batch at ~12% overhead.

**Double-run 3% of batches** through two independent agents and report inter-agent agreement
on `determination` and on `ein_found`. Publish both numbers — without them the output is
unfalsifiable.

**Stop condition:** control accuracy below 90%, or inter-agent agreement below 85% — halt and
fix the brief. Do not let a drifting run finish because restarting is expensive.

---

## 4. Recommended sequencing

**Stage 2 first.** A quarter of the work for a quarter of the recoveries, at twice the hit
rate per case:

| | web cases | agents | matches expected | matches / agent-hour |
|---|---|---|---|---|
| stage 2 | 5,034 | 630 | ~1,850 | **~62** |
| stage 1 | 15,126 | 1,891 | ~4,880 | ~31 |

Stage-2 cases arrive with a scored candidate slate, so an agent adjudicates a shortlist
rather than searching from nothing. The second reason outlasts the rows: those wrongly
rejected matches are **labelled training data for the adjudicator prompt**. Fixing the review
step stops the pool refilling on every subsequent run.

---

## 5. Runtime and cost

Measured over 68 pilot agents / 538 cases: **10,925 tokens per case**, 86,437 per 8-case
agent, **260 s per agent** (median 246, p90 368), 31 tool calls per agent.

**Model:** subagents inherit the session model. The pilot ran entirely on **`claude-opus-5`**
($5 / $25 per MTok in/out). The `Agent` tool takes a `model` override — this is a bigger cost
lever than concurrency, and independent of it.

Full pool, both stages, web cases only (20,160 cases → 2,521 agents → 218 M tokens):

| Model | Output $/MTok | Cost | @ 20 | @ 50 |
|---|---|---|---|---|
| `claude-opus-5` | $25 | **~$5,448** | 9.1 h | 3.6 h |
| `claude-sonnet-5` | $10 | **~$2,179** | 9.1 h | 3.6 h |
| `claude-haiku-4-5` | $5 | ~$1,090 | 9.1 h | 3.6 h |

Stage 2 alone: 5,034 cases, 630 agents, 54 M tokens, 2.3 h at 20 — **$1,361 / $545 / $272**.

**Recommendation: run Phase 3 on Sonnet 5, keep Opus 5 for Phase 5 verification.** The bulk
research is mechanical — grep a TSV, fetch a JSON endpoint, classify into four values, write
a fixed schema. The refutation pass, where the model must resist a plausible wrong answer, is
where Opus earns its premium. And you don't have to take it on faith: run the control cases
and the 3% double-run on Sonnet against the Opus results for one wave. If agreement holds
above the 85% gate, switch and bank the difference; if not, you spent ~$50 finding out.
Haiku's 200K context is tight for packets carrying long candidate slates.

**Caveats on the money.** Token figures are the harness's `subagent_tokens`; the input side
is not in that number, and in an agentic loop with a stable prefix most of it should hit cache
at 0.1× base input. Expect the invoice somewhat above the table. And if you run Claude Code on
a Max or Team plan rather than API billing, this draws against plan limits instead of
per-token dollars, and the model choice becomes a question about rate limits, not money.

**Measured unit economics from the pilot: $163.16 for 1,000 cases → $0.77 per recovered
match** ($0.71 stage-1, $0.79 stage-2). Projected across the pool at Sonnet: **~$0.32 per
match.**

Checkpointing: agents write per-batch files and `06_merge_findings.R` reports missing batches
by number, so an interrupted run resumes by re-launching only the gaps.

---

## 6. ProPublica rate limits — the strategy

**Root cause.** The pilot pointed 20 concurrent agents at the HTML UI
(`/nonprofits/search?q=`). It throttles hard: 67 research cases and 75 of 167 audit cases lost
Tier 2 to HTTP 429s. Worse than the loss, a 429 is *silence* — an agent that reads it as "no
results" turns missing evidence into false evidence.

### 1. Use the JSON API, not the HTML UI

```
https://projects.propublica.org/nonprofits/api/v2/search.json?q=<name>
```

Measured: **30 requests in 10 s (3 req/s), zero 429s.** A different, far more permissive
throttle, returning structured JSON (`strein`, `name`, `city`, `state`, `ntee_code`,
`subseccd`) instead of HTML an agent must parse.

**One convention:** the API answers **`404` for a genuine zero-result query**, with
`total_results: 0` in the body. That is evidence, not an error — parse the body on 404 exactly
as on 200. My first pass got this wrong and discarded 44 valid zero-answers.

### 2. Move Tier 2 out of the agents — prefetch to a cache

The real fix. Concurrent agents cannot coordinate a rate limit; a single process can.
`12_pp_prefetch.R` resolves every distinct name at 2.5 req/s, backs off on 429, appends to
`PP-CACHE.tsv`, and is resumable.

**Verified on the exact 67 cases that failed in the pilot: 67/67 resolved, zero 429s, ~30
seconds.** Full pool is ~14,700 distinct queries → **~1.6 h** single-threaded, overlapping
Phase 1.

Three wins beyond dodging the throttle:

| Win | Why it matters |
|---|---|
| **Deduplication** | Query the distinctive name — "Salvation Army" fetched once, not once per corps |
| **Determinism** | Every agent sees byte-identical Tier-2 evidence; live queries make a run unreproducible |
| **Honest negatives** | A cached `total_results: 0` is a recorded fact; a live 429 is an unknown that looks like one |

### 3. Fail loudly, never silently

Keep even after prefetching: retry a 429 once, then record it verbatim as
`propublica: HTTP 429, unavailable`, cap the case at `medium` confidence, and never write it
down as "0 results".

### Longer term

`irs990efile` is already installed here. A local 990-filer index built from the IRS bulk
extracts would replace most of what ProPublica provides — organizations that file but sit
outside the active BMF — and remove the network from the critical path. Worth doing before
the next refresh cycle.

---

## 7. Result-table columns

Both findings tables and the audit table carry per-case cost:

| Column | Meaning |
|---|---|
| `agent_tokens_alloc` | **Allocated**, not measured: batch tokens ÷ cases in batch, summed across the research and verification passes. Tier-1-gated cases are 0. |
| `est_usd_alloc` | `agent_tokens_alloc` × $25/MTok (Opus 5 output). Divide by 2.5 for Sonnet 5. |

The billable unit is the agent, not the case — eight cases share one context, so a true
per-case split does not exist. The allocation is the honest approximation.

---

## 8. Definition of done

- [x] 2026MAY stage-2 decisions file located; pool rebuilt at 40,860
- [x] Tier 2 repointed at `PP-CACHE.tsv` (`AUDIT2-BRIEF.md`); gate audit re-run — 4.8%
- [x] efile 990 index built (`EFILE-XWALK.tsv`, `EFILE-NAMES.tsv`) and validated
- [ ] Roll `AUDIT2-BRIEF.md`'s cached-Tier-2 + efile sections into `AGENT-BRIEF.md` for
      the production run — the audit re-run used them, the main brief does not yet
- [ ] Tier-1 escape hatch (BMF-hit OR 2L OR efile domain) live in `04_seed_findings.R`
- [ ] Every case has a determination in the closed taxonomy
- [ ] Every recovered EIN exists in the pinned BMF (`07_qc.R` clean)
- [ ] No blank `sources`; negative results stated explicitly
- [ ] Control accuracy ≥ 90%, inter-agent agreement ≥ 85%, both published
      (v1-vs-v2 on the audit set already gives 92.2% — reproduce it on production batches)
- [ ] IOP Publishing (23-2659520) tie-broken: v1 called it a match, v2 `not_a_nonprofit`
- [ ] All five risk strata verified; refutation rate reported
- [ ] 2026MAY stage-2 sampled as its own stratum before assuming the 28.4% rate
- [ ] Match rows folded into the crosswalk tagged `source = no_research_<run>`
- [ ] Stage-2 wrong-rejections exported as labelled data for retuning the adjudicator
