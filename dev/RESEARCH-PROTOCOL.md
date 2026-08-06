# EIN Research Protocol (training-data ground truth)

A reproducible, tiered procedure for giving a **definitive** determination on each
MAYBE / NO SAM organization: find the correct BMF EIN, or verify the org is not a
matchable US nonprofit. Runs cheapest-first and escalates only when needed.

## Determination taxonomy (the `determination` field)

- `match` — a specific EIN is the same organization. Record it in `ein_found`.
- `not_a_nonprofit` — for-profit (LLC/LP/Inc-company), individual/person, or government
  unit (city, public university, public library, housing authority, school district).
- `nonprofit_not_in_bmf` — a real nonprofit that is legitimately absent from the *active*
  BMF: churches / church-integrated auxiliaries (auto-exempt, not required to file),
  foreign orgs, state-only registrations, or an org found only in the **inactive** BMF /
  990 data (record the EIN in `ein_found` even though it isn't in the active file).
- `cant_determine` — insufficient information after all tiers.

Also record: `resolving_tier` (tier1/tier2/tier3), `confidence` (high/medium/low),
`source` (where the EIN/decision came from), `notes`, `token_cost` (low/med/high).

## Tier 1 — Deep review (local, ~free). Do this for EVERY case.

Inputs, all local: the review row (surfaced candidates + `match_version`, `BMF_*`
context, `in_care_of`, address) and a **full-BMF name grep** (catches blocking-misses).

Steps:
1. **Legal-form / entity gate first.** If the SAM legal name ends in a for-profit form
   (LLC, LP, LLLP, PLLC, "… and Company", "Inc" on an obvious business) or is a person's
   name, or is a government unit ("City of …", a public university, "… Housing Authority",
   "… School District", "… Public Library") → `not_a_nonprofit`. Use `SAM_entity_structure`
   (2L = not tax exempt) and `bus_type_*` flags (`for_profit`, absence of `nonprofit`).
2. **`in_care_of` guard.** A candidate that aligns only via its care-of address (e.g. an
   honor society *in-care-of* a university) is NOT the org — reject it.
3. **Grep the full BMF** for the distinctive name tokens. If an entry matches on
   name (allowing NE↔Northeast, &↔and, spacing like STEP FORWARD↔STEPFORWARD, and typos
   like ENVIRONMENT↔ENVIROMENT) AND the address/state is consistent → `match`.
4. **Name-variant stress test** (do NOT reject on suffix alone):
   - `X` vs `X Foundation`: check whether a *separate* plain-`X` EIN exists (twin) — if so,
     that's the match; if the Foundation is the *only* entity at the org's address, the
     "Foundation" may BE the org (common for schools/older charities) → keep it as a
     candidate, escalate to confirm.
   - Federated / multi-EIN (Harvard-style): the SAM record may map to the operating entity,
     the endowment, a hospital, or a state branch. Prefer same-address / same-name-core;
     if several plausible branches exist and none is distinguishable → escalate or
     `cant_determine`.
5. If confidently resolved, STOP. Otherwise escalate.

## Tier 2 — Nonprofit databases (ProPublica Nonprofit Explorer).

Only for cases Tier 1 left open. URL: `projects.propublica.org/nonprofits/search?q=<name>`.
- **Query with the distinctive name only — NO city/state terms** (multi-word + city returns
  0). Spell out abbreviations.
- Read EIN + city + NTEE + revenue; confirm it's the same org by city/leadership.
- **Cross-check the EIN in the local BMF.** In BMF → `match` (blocking-miss). Not in BMF but
  a real filer → `nonprofit_not_in_bmf` (likely inactive/990-only), record the EIN.
- A ProPublica `0` for a church/charter/foreign name is *informative*: supports
  `nonprofit_not_in_bmf` (church) or escalate.

## Tier 3 — General web (search engine).

Only for cases Tier 1-2 left open, and worth the tokens.
- Search: `"<org name>" <city> EIN nonprofit` and/or the org's website / GuideStar /
  Cause IQ / state charity registry. Catches rebrands ("Step Forward" ← CEOGC),
  foundation-self-reference (the school files as "… Foundation"), and self-listed EINs.
- Disambiguate by address / leadership / founding year. Record source URL.
- If still unresolved → `cant_determine` (note what's missing).

## Output schema (one row per case)

`uei, sam_name, orig_tier, ein_found, determination, resolving_tier, confidence,
token_cost, source, notes`  (see `data-dev/RESEARCH-SAMPLE-FINDINGS.csv`).

## Referenced files (set up once)

- Active BMF: `data-raw/bmf_2026_01_processed.csv` (grep target).
- Inactive/omitted BMF: *(to be added — enables Tier-1.5 for the not-in-active cases).*
- Review dataset (candidates + context): produced by `np_route(res, bmf=, sam=, token_idf=)`;
  per-sample CSV, e.g. `data-dev/REVIEW-*.csv`.
- ProPublica base URL: `https://projects.propublica.org/nonprofits/search?q=`.

## Batching (minimize low-yield tokens)

1. **Tier 1 for the whole sample at once** — a single batched `rg` over all N names +
   the review rows. ~20 tokens/case. This resolves ~55-60% and flags the residual.
2. **Escalate only the residual to Tier 2**, one ProPublica lookup per case
   (distinctive-name query). ~150 tokens/case; resolves another ~20%.
3. **Tier 3 only for the still-open, high-value residual** (~20-25%). ~1-3k tokens/case.
4. **Run the web tiers as isolated per-org tasks** (fresh context each), not one growing
   conversation — with prompt caching on this protocol + tool schemas, each org pays only
   its own evidence. Never carry one org's web content into the next org's context.
5. Skip Tier 3 entirely for records the legal-form/entity gate already settled
   (for-profit / person / government) — they never need the web.

## Reusable task prompt (for a research agent, one org per task)

> You are resolving the IRS EIN for one SAM-registered organization, or determining it is
> not a matchable US nonprofit. Follow `dev/RESEARCH-PROTOCOL.md` exactly: Tier 1 (review
> row + full grep of `data-raw/bmf_2026_01_processed.csv`), then Tier 2
> (ProPublica, distinctive-name query, cross-check EIN in the BMF), then Tier 3 (web) only
> if unresolved and worthwhile. Apply the name-variant / foundation / federated /
> `in_care_of` / legal-form rules. Stop at the first tier that yields a confident call.
> Return exactly one row: `uei, sam_name, orig_tier, ein_found, determination,
> resolving_tier, confidence, token_cost, source, notes`.
