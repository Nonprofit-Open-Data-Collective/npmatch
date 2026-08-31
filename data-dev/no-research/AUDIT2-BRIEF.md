# Research brief (rev 2) — cached Tier 2, plus the efile 990 index

Same job as before: for each organization, find the correct IRS EIN, or establish that no
matchable US nonprofit exists. What changed is that **Tier 2 is already done for you** and
there is **a new local index**.

## Working directory

`C:\Users\jdlec\Dropbox\00 - URBAN\00-GITHUB\npmatch`

## Tier 1 — local, do it for every case

**`data-dev/no-research/BMF-GREP.tsv`** — full unified BMF, 3.69M rows, tab-separated:
`ein  name  dba  city  state  zip5  care_of  subsection  ACTIVE|INACTIVE`

```bash
rg -i "DISTINCTIVE TOKENS" data-dev/no-research/BMF-GREP.tsv | head -30
```

Allow for `NE`↔`NORTHEAST`, `&`↔`AND`, `ST`↔`SAINT`, spacing (`STEP FORWARD`↔`STEPFORWARD`),
acronym↔spelled-out, and ordinary typos. A hit counts as a match only when the name lines up
AND city/state is consistent (or the org is known to have moved).

## Tier 1.5 — NEW: the efile 990 header index

**`data-dev/no-research/EFILE-XWALK.tsv`** — 660,362 EINs that filed a 990/990-EZ 2019-2024,
one row each, tab-separated:
`ein  name  dba  web_domain  phone  street  city  state  zip  care_of  officer  year_formed  domicile_state  is_501c3  group_exempt  last_tax_year  years_filed  n_name_variants`

**`data-dev/no-research/EFILE-NAMES.tsv`** — every distinct name/DBA an EIN filed under across
those years (`ein  variant  kind  variant_key`). This is the **rebrand index**: an org that
changed names shows up under both.

```bash
rg -i "	somedomain\.org	" data-dev/no-research/EFILE-XWALK.tsv
rg -i "OLD NAME" data-dev/no-research/EFILE-NAMES.tsv | head -20
```

**Why this matters.** The BMF tells you an EIN exists. The efile index gives you *independent
confirming evidence*: a website, a phone, a principal officer, a formation year. A SAM record
and a BMF candidate that share a **website domain** are the same organization — that is a
second independent signal, so such a match is `high` confidence with no web search at all.

Your packet already lists any efile filers that share this org's website domain, or that
filed under this name. **Check those first — they are the cheapest confirmation available.**

Caveats: 990/990-EZ only (**no 990-N**, so small orgs are missing), 2019-2024 only, and
**churches do not file at all** — absence from this index is weak evidence for a church and
strong evidence for a mid-size secular nonprofit.

## Tier 2 — ProPublica: ALREADY FETCHED, DO NOT QUERY

Each case carries a line `ProPublica (CACHED - do not re-query)` with the result of a
distinctive-name search: the count, the HTTP status, and up to 15 organizations as
`EIN | name | city, state | ntee | subsection`.

- **`0 results (HTTP 404)` means a genuine zero** — the API answers 404 for an empty result
  set. Treat it as real evidence of absence, not as an error.
- **Do not call ProPublica yourself.** No WebFetch to `projects.propublica.org`. The cache is
  the Tier-2 evidence of record, and re-querying reintroduces the rate limiting this was
  built to remove.
- If the cached query looks too narrow for the org, say so in `notes` rather than re-querying.

## Tier 3 — general web

Only if Tiers 1-2 left it open. Search `"<org name>" <city> EIN nonprofit`, the org's own site
(the packet usually gives `SAM url`), GuideStar/Candid, Cause IQ, or the state charity
registry. Disambiguate on address, leadership, or founding year. Record the URL.

## Determinations — pick exactly one

- `match` — a specific EIN is the same organization. Put it in `ein_found`.
- `not_a_nonprofit` — for-profit, an individual, or a government unit.
- `nonprofit_not_in_bmf` — a real nonprofit legitimately absent from the active BMF: a church
  or church auxiliary, a foreign org, a state-only registration, or an org found only in the
  inactive BMF / 990 data. **Record the EIN in `ein_found` if you found one anyway.**
- `cant_determine` — insufficient evidence after all tiers.

## Confidence

`high` = two independent signals (name + address, or website-domain agreement, or ProPublica
plus the org's own site). `medium` = one solid signal, nothing contradicting. `low` =
plausible but unconfirmed; name the gap in `notes`.

## Rules that catch most errors

1. **Legal form first** — but do not stop there. A for-profit form (LLC/LP/PLLC) or a
   government-sounding name is *suggestive*, not decisive: nonprofit chapters do register
   under LLC names. Check the BMF and efile indexes before settling on `not_a_nonprofit`.
2. **SAM's entity-structure field is unreliable.** `2L` nominally means "not tax exempt", and
   it is frequently wrong for real nonprofits. Never settle a case on `2L` alone.
3. **A foreign address does not rule out a US EIN.** Foreign-incorporated organizations
   sometimes hold one. Check both indexes.
4. **`in_care_of` is not identity.** A candidate that aligns only through its care-of party is
   not the organization.
5. **Do not reject on suffix alone.** For `X` vs `X Foundation`, check whether a separate
   plain-`X` EIN exists; if the Foundation is the only entity at the address, it may BE the org.
6. **Federated / multi-EIN orgs** — prefer same-address, same-name-core. If several branches
   are plausible and none is distinguishable, `cant_determine`.
7. **Never invent an EIN.** If you did not see it in a source, leave `ein_found` empty.

## Output — write a TSV, do not report rows in your reply

Write to `data-dev/no-research/audit2-out/audit2-<NN>.tsv`, tab-separated, header first:

```
uei	sam_name	run	stage	ein_found	determination	resolving_tier	confidence	sources	judgement	notes
```

- `resolving_tier` — `tier1` (BMF/efile local), `tier2` (cached ProPublica), or `tier3` (web).
- `sources` — semicolon-separated, real and specific: `bmf_grep`, `efile_xwalk:<ein>`,
  `propublica_cache`, `web:<url>`. **State negative results explicitly** — e.g.
  `bmf_grep: no hit; efile: no filer at this domain; propublica_cache: 0 results`.
- `judgement` — one sentence: why it is not a match, or what the true match is.
- `notes` — anything a reviewer needs, including what is missing on `low`/`cant_determine`.

No tab or newline characters inside any field. One row per case, every case.

Reply with one short line: batch number, rows written, counts by determination.
