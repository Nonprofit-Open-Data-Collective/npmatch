# USA Spending awards panel — extraction plan

Exploratory assessment for building an award panel on the 1,000 largest matched
nonprofits from the NOV-2025 crosswalk run.

Written 2026-08-26. All API behaviour below was measured live against
`api.usaspending.gov`, not read off the docs.

---

## 1. The sample

Source: `data-dev/run-2025NOV/CROSSWALK-AUGMENTED-2025NOV.csv`
(126,784 accepted UEI→EIN pairs: 114,746 `auto_yes` + 12,038 `llm_review`).

Revenue joined from `data-raw/bmf_unified_geocoded_2026-08-20.csv`
(`revenue_amount`, one row per EIN, 3,698,124 EINs; join rate **126,784 / 126,784 = 100%**).

| step | n |
|---|---|
| accepted pairs (YES) | 126,784 |
| distinct orgs (EIN) | 124,786 |
| orgs with `revenue_amount > 0` | ~96,000 |
| **selected: top 1,000 by BMF total revenue** | **1,000 orgs** |
| UEIs covering those orgs | **1,364** |

Revenue floor $385,170,089 — ceiling $82,490,440,881; $1.50T combined.
Composition: 568 hospitals (HOS), 110 universities (UNI), 107 UNU, 106 health (HEL),
38 public/societal benefit (PSB), 28 human services (HMS), rest scattered.
710 of the 1,000 came from `auto_yes`, 290 from `llm_review`.

### Outputs

| file | grain | notes |
|---|---|---|
| `TOP1000-REVENUE-2025NOV.csv` | 1 row / org (EIN) | ranked; `uei` = best-scoring UEI, `uei_all` = pipe-delimited full set |
| `TOP1000-UEI-PULLLIST-2025NOV.csv` | 1 row / UEI (1,364) | **this is the API pull list** |
| `TOP1000-UEIS.txt` | bare UEIs | one per line |
| `UEI-AWARD-COUNTS.csv` | 1 row / UEI | pre-flight award counts (see §4) |
| `ORG-AWARD-COUNTS.csv` | 1 row / org | UEI counts rolled up to EIN |

**Pull on all 1,364 UEIs, not the 1,000 primaries.** Large nonprofits carry
multiple SAM registrations and USAspending splits awards across them. NYU
(EIN 13-5562308) has three UEIs holding 2,687 / 4,721 / 9 awards — picking one
UEI per EIN would have dropped 36% or 64% of NYU's federal awards depending on
which one you picked. Battelle has 13 UEIs, Kaiser Foundation Hospitals 3.

---

## 2. How USAspending is actually structured

Three nested grains, and the choice between them decides the whole pipeline:

1. **Transaction** — one row per award action/modification. Carries
   `action_date`, `action_date_fiscal_year`, `federal_action_obligation`.
   *This is the only grain that supports an annual panel.*
2. **Prime award summary** — one row per award, aggregating its transactions.
   `total_obligated_amount` is **lifetime-to-date**, not annual. Useful as a
   spine (100 columns incl. `recipient_uei`, `recipient_parent_uei`,
   `cfda_numbers_and_titles`, `total_outlayed_amount`, agency/office codes).
3. **Subaward** — FSRS pass-through reporting; delivered alongside prime data.

Award-type code families: contracts `A B C D`, IDVs `IDV_*`,
grants `02 03 04 05`, direct payments `06 10`, loans `07 08`, other `09 11`.

Separately there is account-level data (Files B/C — TAS / federal account /
object class outlays). It is *not* reachable from the award-search endpoints and
is one of the few genuine reasons to want the full database.

---

## 3. The three access paths, measured

### Path A — full PostgreSQL database download (from the attached setup doc)
- 160 GB zip → 170 GB unzipped → **~2.5 TB restored** with materialized views
- PostgreSQL 16 + contrib extensions, `root` superuser, "many hours" to restore
- Restore script drops and recreates `data_store_api`

### Path B — Award Data Archive (bulk FY files)
- `POST /api/v2/bulk_download/list_monthly_files/` → one full-year zip per
  FY per type, e.g. `FY2024_All_Assistance_Full_20260806.zip`
- Measured: FY2024 All Assistance = **1.37 GB zipped**
- ~18 fiscal years × {assistance, contracts} ≈ **50–80 GB zipped**, several
  hundred GB as CSV. Filter locally on `recipient_uei` with duckdb.

### Path C — REST API (recommended)
Measured against the real sample:

| probe | result |
|---|---|
| award counts, 1,364 UEIs, FY2008–FY2025 | 270,565 prime awards *(upper bound — see §5 item 1)* |
| transaction counts, same | 1,370,383 transactions *(upper bound)* |
| 69 batched count requests | **24 seconds**, 0 failures |
| `POST /api/v2/download/awards/` 1 UEI + 1 FY | finished in 8.8s, 372 rows |
| `POST /api/v2/download/awards/` 1 UEI, all years | finished in 83s, 5,799 rows, 213 cols, 2.0 MB zip |

**Verdict: use Path C for these 1,000 orgs.** 1.37M transactions is a few GB of
CSV. Restoring 2.5 TB of Postgres to extract 1,364 recipients is not a
defensible trade.

**But note the crossover.** If the panel later extends to the whole crosswalk
(126,784 UEIs — 93× this sample), Path C becomes ~6,300 download jobs and Path B
becomes clearly better: pull ~36 FY archives once and filter locally. Path A
only earns its keep if you need account-level (File B/C) linkage or pre-FY2008
data, neither of which the award API exposes.

---

## 4. Recommended pipeline

**Endpoint:** `POST /api/v2/download/transactions/`
(returns `SubawardsAndPrimeTransactions_*.zip`: prime transactions + subawards).

Use the *download* endpoint, not `spending_by_award` — see the 10,000-record cap
in §5.

```
1. pre-flight   per-UEI counts  -> UEI-AWARD-COUNTS.csv   [done]
2. batch        1,364 UEIs / 5 = 273 jobs
                5 is the working size for high-volume recipients; 20 fails
3. submit       POST /api/v2/download/transactions/     (3 in flight)
                filters: recipient_search_text = batch (<= 5)
                         award_type_codes      = all families in one job
                                                 (mixing contract + assistance
                                                  codes is accepted; the zip
                                                  comes back split by type)
                         time_period           = [{start 2007-10-01,
                                                   end   2025-09-30,
                                                   date_type "action_date"}]
4. poll         GET /api/v2/download/status?file_name=...
                ready | running -> in flight
                finished | failed -> terminal (failed gives no detail)
                retry a failed batch as individual UEIs
5. fetch        file_url -> zip -> duckdb
6. assemble     inner-join on exact UEI, then EIN x fiscal_year
```

Run 3 jobs concurrently. Measured on the 50-org pilot: 26 jobs of 5 UEIs,
all finished, ~35 min wall clock, 302,025 prime transactions, 848 MB of CSV
(68 MB zipped). Scaling to 1,364 UEIs gives ~273 jobs, ~9 GB of CSV, roughly 5–6 hours — run it
overnight, or raise concurrency once you know which UEIs are the heavy ones
(`UEI-AWARD-COUNTS.csv` tells you).

### Panel construction (duckdb, local)

```
recipient_uei --(TOP1000-UEI-PULLLIST)--> ein --(TOP1000-REVENUE)--> org attrs

panel = 1,000 orgs x 18 fiscal years (FY2008-FY2025) = 18,000 org-years
per cell: obligations_assistance, obligations_contract,
          n_awards, n_transactions, n_funding_agencies,
          top_cfda, subaward_obligations
```

Sum `federal_action_obligation` by `action_date_fiscal_year`. Negative
transactions (de-obligations) are real and must be kept — NYU's FY2020 pull
includes rows like `-13,684` and `-21`; dropping them inflates the panel.

---

## 5. Gotchas found while probing (all verified)

1. **`recipient_search_text` is an analysed text match, not an exact UEI lookup.**
   This is the most consequential finding here. Passing a list of UEIs returns
   those recipients *plus neighbours*. In the 50-org pilot the downloads carried
   **121 UEIs that were never requested** — only 2.4% of rows, but **14.5% of
   obligated dollars** ($20.9bn of $144.8bn), because one stray
   (`HG7XL5RBNX55`, 484 transactions, $18.7bn) is a major DOE-scale contractor
   sitting next to Battelle in the index. Consequences:
   - Every downstream step must **inner-join on exact UEI**. `07_build_panel.R`
     does, and writes the discards to `pilot/STRAY-UEIS.csv` so contamination
     stays visible instead of silently inflating the panel.
   - Counts taken straight from `spending_by_award_count` /
     `spending_by_transaction_count` are **upper bounds**, not sample sizes. The
     270,565 / 1,370,383 figures in §3 include strays.
1. **`recipient_search_text` caps at ~20 values — and far lower for transaction
   downloads of large recipients.** On `spending_by_award_count`, 20 works and 30
   returns HTTP 503. On `/download/awards/` with tiny result sets, 20 works and 25
   fails. But on `/download/transactions/` for the 50 largest nonprofits, batches
   of 20 **fail outright after ~5s**, batches of 10 stall past 10 minutes, and
   batches of **5 finish in ~70s**. Size the batch to the recipients' volume, not
   to the documented filter. The pilot ran 26 jobs of 5 UEIs, 3 concurrent, and
   all 26 finished with no retries.
2. **The job state machine is `ready` → `running` → `finished` | `failed`.**
   `ready` is a queue state. A poll loop that treats anything other than
   `running` as terminal reads a freshly-queued job as done and discards a
   perfectly good download — this cost a full pilot run before it was caught.
3. **`spending_by_award` is hard-capped at 10,000 records.** `limit` max is 100
   (`limit 500` → 400 error) and page 101 returns an empty result set. Fine for
   NYU's 4,219 grants, silently truncating for a big contractor.
4. **`recipient_id` is not a valid award-search filter.** Passing it to
   `spending_by_award` does not error — it is *silently ignored* and you get
   unfiltered results back. A query filtered on Kaiser's `recipient_id` returned
   Delaware County Historical Society and Ballet Five Eight. Use
   `recipient_search_text` with the UEI instead. (`recipient_id` is only for the
   `/api/v2/recipient/*` endpoints.)
5. **Never validate on recipient name.** USAspending stores the name as
   submitted at award time, not current SAM. UEI `Y4N3KM8XWK16` is
   "NEW YORK UNIVERSITY" in SAM and in the crosswalk, but comes back from the
   award search as "NEW YORK UNIVERSITY FEDERAL CREDIT UNION". Join on UEI only.
6. **Search is floored at 2007-10-01.** Every response carries a message saying
   so. FY2001–FY2007 requires the Custom Award Download or the full database.
7. **Award-level amounts are lifetime.** `total_obligated_amount` on the prime
   summary is cumulative; using it with a `time_period` filter double-counts
   across years. Build the panel from transactions.
8. **`date_range`/`date_type` at the top of a download filter object are dropped
   silently.** Use `time_period: [{start_date, end_date, date_type}]`.
9. **Sustained single-recipient calls get rate-limited.** 69 batched
   `spending_by_award_count` calls ran clean in 24s, but 1,364 unthrottled
   single-UEI calls failed 1,004 times. At `req_throttle(rate = 2)` with
   exponential backoff the failure rate dropped to 368/1,364 on the first pass,
   and a slower second and third pass left 3 unresolved. Batch where you can,
   throttle where you can't, and always retry — and record failures explicitly,
   because a swallowed error looks exactly like a recipient with no awards.
10. **The R package is agency-centric.** Every exported function on
   `r-pkg.thecoatlessprofessor.com/usaspending` is `agency_*`; there is no
   recipient or award-search wrapper. Only `usasp()` (generic caller) and
   `get_all_pages()` are reusable. A thin `httr2` client is less work than
   bending it — the probe scripts already do this.

---

## 6. Pre-flight coverage (measured, `ORG-AWARD-COUNTS.csv`)

Per-UEI counts for all 1,364 UEIs, FY2008–FY2025. 3 UEIs never resolved after
retries (0.2%) and are flagged `err=TRUE` / `n_awards=NA` — they affect 3 orgs
and are excluded from the rates below rather than counted as zeros.

| | n |
|---|---|
| orgs with ≥1 federal award | **777 / 1,000** |
| orgs with zero awards | 223 |
| total prime awards | 290,106 |
| awards per org: median / p90 / max | 7 / 495 / 17,640 |

**The zero-award orgs are mostly real non-recipients, not bad matches.** They
concentrate hard by sector:

| NTEE group | orgs | zero-award | % |
|---|---|---|---|
| HEL (health, incl. plans) | 106 | 37 | 34.9% |
| UNU | 107 | 32 | 29.9% |
| HMS (human services) | 28 | 8 | 28.6% |
| PSB | 38 | 9 | 23.7% |
| HOS (hospitals) | 568 | 131 | 23.1% |
| **UNI (universities)** | **110** | **0** | **0.0%** |

The largest zero-award orgs are almost all managed-care plans and hospital
operating companies — CareSource Ohio, SelectHealth, SCAN Health Plan, Blue Care
Network of Michigan, Geisinger Health Plan, CareOregon, the Kaiser regional
plans, Sutter Valley Hospitals, Baptist Hospital of Miami. Their federal money
arrives as Medicaid/Medicare capitation through state agencies and CMS, which
never appears in USAspending as a federal award. Every one of the 110
universities has awards, as expected.

**Stage-2 LLM adjudication is not costing precision.** Award hit rates on fully
resolved orgs:

| source | orgs | with awards | % |
|---|---|---|---|
| `llm_review` | 274 | 221 | **80.7%** |
| `auto_yes` | 723 | 555 | **76.8%** |

`llm_review` matches are marginally *more* likely to appear in USAspending than
auto-accepted ones. If stage-2 were letting through false positives you would
expect the opposite.

### Still open

- **Parent/child rollup.** Prime summaries carry `recipient_parent_uei`.
  USAspending may know about subsidiary UEIs absent from the SAM crosswalk;
  worth a pass to see whether the crosswalk is under-collecting registrations.
- **Contracts vs assistance.** 79,831 contracts / 174,324 grants in this sample.
  Kaiser Foundation Health Plan has zero grants FY2008–FY2025 — its federal
  money is contract-side. A panel that pulls only `02–05` will show these orgs
  as non-recipients.
- **The 223 zero-award orgs.** Sector composition argues they are genuine
  non-recipients, but a hand-check of ~20 would confirm none are match errors.

---

## 7. Pilot results (top 50 orgs, all award families)

Ran §4 end to end on the 50 largest orgs (130 UEIs, 26 jobs of 5, 3 concurrent).
All 26 jobs finished, no retries. Scripts `06_pull_pilot.R` -> `07_build_panel.R`.

| | |
|---|---|
| prime transactions downloaded | 302,025 |
| after exact-UEI filter | **294,842** |
| stray transactions discarded | 7,183 (2.4% of rows, **14.5% of dollars**) |
| assistance / contract split | 241,118 / 60,907 |
| negative transactions (de-obligations) | 29,448 (9.7%) |
| obligations, on-list | **$123.84bn** |
| raw CSV on disk | 848 MB (68 MB zipped) |
| panel | **900 rows** = 50 orgs x 18 FY |
| org-years with any obligation | 670 / 900 |
| orgs with zero in every year | 5 / 50 |

Outputs live in `pilot/`: `PANEL-PILOT.csv`, `PILOT-JOBS.csv`,
`STRAY-UEIS.csv`, `PILOT-UEI-PULLLIST.csv`, plus `raw/` and `zips/`.

Obligations rise from $3.8bn (FY2008) to a peak of $11.3bn (FY2024); FY2025 at
$8.4bn is partial-year. Largest single org-years are Battelle (~$2.2bn/yr,
FY2022-25), MIT (~$1.9bn), and Advanced Technology International ($2.65bn
FY2024).

### What the pilot changes about the full run

- **Batch size 5, not 20.** The 20-value filter ceiling is real but irrelevant;
  volume is the binding constraint. 273 jobs for the full 1,364.
- **One job per batch, not two.** Mixed contract + assistance award-type codes
  are accepted in a single request and returned as separate CSVs in the zip.
  This halves the job count versus the original plan.
- **Budget for the exact-UEI filter.** 2.4% of rows and 14.5% of dollars in the
  pilot were recipients nobody asked for.
