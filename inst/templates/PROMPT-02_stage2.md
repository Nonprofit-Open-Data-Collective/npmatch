# Stage 2 — adjudication instructions

Run {{run_id}}. You are deciding record-linkage matches the algorithm flagged as
uncertain. Each case is one source organization (a SAM registrant) and the
candidate BMF organizations the matcher surfaced for it.

## Your input

One shard file from `batches/slim/`. Every row is one candidate; rows sharing a
`uei` are candidates for the same source organization. Work a whole `uei` at a
time — you are choosing among its candidates, not judging rows independently.

Columns you are reasoning over: the two names in raw and normalized form,
`name_similarity` / `addr_similarity` / `total_score`, the aligned address
fields, why the case was flagged (`decision_reason`), any veto, and the BMF and
SAM context columns.

## The question

**Is one of these candidates the same organization as the source?** Not a
similar one, not a related one — the same legal entity.

Treat as **distinct** organizations:

- different generation suffixes (Jr / Sr)
- different chapter, local, post, or lodge numbers
- different ordinals (First / Second Baptist)
- a parent and its separately-registered affiliate

Treat as **the same** organization: a DBA or trade name against a legal name, a
division name that matches the source's division field, punctuation and
abbreviation differences, and a former name where the address confirms it.

Address agreement raises confidence but does not by itself make a match; two
unrelated nonprofits routinely share a building. Name agreement without any
geographic corroboration is weak when the name is generic.

## Your output

One CSV per shard, to `batches/decisions/decision-<shard>.csv`, with this header:

```
uei,best_ein,llm_decision,llm_confidence,llm_reason
```

- one row per `uei` in the shard — **every** uei, including the ones you reject
- `llm_decision` — `YES` or `NO`, nothing else
- `best_ein` — the chosen EIN on a YES; **empty** on a NO
- `llm_confidence` — `high`, `medium`, or `low`
- `llm_reason` — one sentence naming the evidence that decided it

No commas inside a field unless the field is quoted. No newlines inside a field.

## Before you finish

- Row count equals the number of distinct `uei` in your shard.
- Every `YES` has a non-empty `best_ein` that appears among that uei's candidates.
- Every `NO` has an empty `best_ein`.

Reply to the orchestrator with one line: shard name, rows written, YES/NO counts.
Do not paste the rows.
