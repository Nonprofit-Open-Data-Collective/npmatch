# Research brief — resolving NO cases to a BMF EIN or a confirmed non-match

You are resolving IRS EINs for SAM-registered organizations that the `npmatch` pipeline
classified as **NO** (no confident BMF match). For each organization in your batch file you
must either find the correct EIN, or establish that no matchable US nonprofit exists.

Follow `dev/RESEARCH-PROTOCOL.md`. The summary below is operative; read the protocol only if
you hit an edge case it covers (federated/multi-EIN orgs, `in_care_of` traps, X vs X Foundation).

## Working directory

`C:\Users\jdlec\Dropbox\00 - URBAN\00-GITHUB\npmatch` — all paths below are relative to it.

---

## Tier 1 — grep the full BMF (free, do it for every case)

`data-dev/no-research/BMF-GREP.tsv` — full unified BMF, 3.69M rows, tab-separated:

```
ein  name  dba  city  state  zip5  care_of  subsection  ACTIVE|INACTIVE
```

Search on the **distinctive** tokens of the org name — not the whole name, not generic words:

```bash
rg -i "WALLOWA COUNTY" data-dev/no-research/BMF-GREP.tsv | head -30
```

Allow for `NE`↔`NORTHEAST`, `&`↔`AND`, `ST`↔`SAINT`, spacing (`STEP FORWARD`↔`STEPFORWARD`),
acronym↔spelled-out (`SC`↔`SOUTH CAROLINA`), and ordinary typos. A hit counts as a **match**
only when the name lines up AND city/state is consistent (or the org is known to have moved).
Your packet already includes an exact-name-key lookup under `Tier-1 full-BMF name lookup`;
that is exact-key only, so grep still adds value.

## Tier 1.5 — the efile 990 index (free, and usually decisive)

`data-dev/no-research/EFILE-XWALK.tsv` — 660,362 EINs that filed a 990/990-EZ 2019-2024, one
row each, tab-separated:

```
ein  name  dba  web_domain  phone  street  city  state  zip  care_of  officer
year_formed  domicile_state  is_501c3  group_exempt  last_tax_year  years_filed  n_name_variants
```

`data-dev/no-research/EFILE-NAMES.tsv` — every distinct name/DBA an EIN filed under across
those years (`ein  variant  kind  variant_key`). This is the **rebrand index**: an org that
changed names appears under both the old and the new one.

```bash
rg -i "	somedomain\.org	" data-dev/no-research/EFILE-XWALK.tsv
rg -i "OLD NAME" data-dev/no-research/EFILE-NAMES.tsv | head -20
```

**Why this matters.** The BMF tells you an EIN exists. The efile index gives you *independent
confirming evidence* — a website, a phone, a principal officer, a formation year. A SAM
record and a BMF candidate that share a **website domain** are the same organization: that is
a second independent signal, so the match is `high` confidence with no web search at all.
Measured on confirmed matches, where both sides carry a domain they agree 81% of the time.

Your packet lists any efile filers sharing this org's website domain, or filing under this
name. **Check those first — the cheapest confirmation available.**

Caveats: 990/990-EZ only (**no 990-N**, so the small-org tail is missing), 2019-2024 only, and
**churches do not file at all** — absence from this index is weak evidence for a church and
strong evidence for a mid-size secular nonprofit.

## Tier 2 — ProPublica: ALREADY FETCHED, DO NOT QUERY

Each case carries a line `ProPublica (CACHED - do not re-query)` with the result of a
distinctive-name search: the count, the HTTP status, and up to 15 organizations as
`EIN | name | city, state | ntee | subsection`.

- **`0 results (HTTP 404)` means a genuine zero** — the API answers 404 for an empty result
  set. Treat it as real evidence of absence, not as an error.
- **Do not call ProPublica yourself.** No WebFetch to `projects.propublica.org`. The cache is
  the Tier-2 evidence of record; re-querying reintroduces the rate limiting this removed.
- If the cached query looks too narrow for the org, say so in `notes` rather than re-querying.
- **Always cross-check any EIN you take from the cache against `BMF-GREP.tsv`.** In the BMF →
  `match` (a blocking miss). Not in the BMF but a real filer → `nonprofit_not_in_bmf`, and
  still record the EIN.

## Tier 3 — general web search

Only if Tiers 1-2 left it open. Search `"<org name>" <city> EIN nonprofit`, the org's own site
(the packet usually gives `SAM url`), GuideStar/Candid, Cause IQ, or the state charity
registry. Disambiguate on address, leadership, or founding year. Record the URL.

---

## Determinations (pick exactly one)

- `match` — a specific EIN is the same organization. Put it in `ein_found`.
- `not_a_nonprofit` — for-profit, an individual, or a government unit.
- `nonprofit_not_in_bmf` — a real nonprofit legitimately absent from the active BMF: a church
  or church auxiliary (auto-exempt, not required to apply), a foreign org, a state-only
  registration, or an org found only in the inactive BMF / 990 data. **If you found an EIN
  anyway, still record it in `ein_found`.**
- `cant_determine` — insufficient evidence after all tiers.

## Confidence

- `high` — two independent signals: name + address, **website-domain agreement between SAM
  and the efile index**, or ProPublica plus the org's own site. Or the entity class is
  unambiguous (an individual, a named government unit).
- `medium` — one solid signal, nothing contradicting.
- `low` — plausible but unconfirmed; name the gap in `notes`.

## Rules that catch most of the errors

These are not generic advice. Rules 1-3 come from auditing 167 gated cases twice: the
**self-reported legal-form fields were wrong 25% (SAM 2L) and 14% (LLC-in-name) of the time**,
while the structural gates were right 48 out of 48.

1. **Legal form is suggestive, not decisive.** A for-profit form (LLC/LP/PLLC) in the legal
   name does *not* settle the case — nonprofit chapters register under LLC names. Gigi's
   Playhouse Raleigh **LLC** and Nazareth Construction **LLC** are both 501(c)(3)s. Check the
   BMF and efile indexes before calling anything `not_a_nonprofit` on form alone.
2. **Never settle on SAM entity structure `2L` alone.** It nominally means "corporate entity,
   not tax exempt" and is frequently wrong for real nonprofits. Alexandria Ministries, Bangor
   Chinese School and Meadows Apartment Ownership are all 2L in SAM and all sit in the BMF.
3. **A foreign address does not rule out a US EIN.** Foreign-incorporated organizations
   sometimes hold one — Trinity Western University is Canadian and has 23-7204465, which the
   BMF files under a bogus NJ state code. Check both indexes before concluding.
4. **An individual or a named government unit IS decisive.** A person's name with SAM
   structure 2J, or "City of…", "… School District", "… Housing Authority", a public
   university or library — these settle as `not_a_nonprofit` with no web needed. Zero errors
   in 48 audited cases.
5. **`in_care_of` is not identity.** A candidate that lines up only through its care-of party
   (an honor society c/o a university) is NOT the organization. Reject it.
6. **Do not reject on suffix alone.** For `X` vs `X Foundation`: check whether a separate
   plain-`X` EIN exists — if so that is the match; if the Foundation is the only entity at the
   address, the Foundation may BE the org.
7. **Federated / multi-EIN orgs.** A SAM record may map to the operating entity, an endowment,
   a hospital, or a state branch. Prefer same-address, same-name-core. If several branches are
   plausible and none is distinguishable, use `cant_determine`.
8. **Cases flagged `confirm_tier1_exact_name_hit`** already have an exact same-state BMF name
   hit. Your job is to **confirm or refute** it — check the address and any other similarly
   named entity in the same state before accepting.
9. **Never invent an EIN.** If you did not see it in a source, leave `ein_found` empty. Every
   recovered EIN is machine-checked against the BMF after the run.

---

## Output — write a TSV, do not report the rows in your reply

Write exactly one row per case to `data-dev/no-research/agent-out/batch-<NNN>.tsv`,
tab-separated, with this header line first:

```
uei	sam_name	run	stage	ein_found	determination	resolving_tier	confidence	sources	judgement	notes
```

- `resolving_tier` — `tier1` (BMF or efile, local), `tier2` (cached ProPublica), or `tier3`
  (web): the tier that actually settled it.
- `sources` — semicolon-separated, real and specific: `bmf_grep`, `efile_xwalk:<ein>`,
  `efile_names:<ein>`, `propublica_cache`, `web:<url>`. **State negative results explicitly**
  — e.g. `bmf_grep: no name hit; efile: no filer at this domain; propublica_cache: 0 results`.
- `judgement` — one sentence: why it is not a match, or what the true match is.
- `notes` — anything a reviewer would need, including what is missing on a `low` or
  `cant_determine`.

**No tab or newline characters inside any field** — replace them with spaces or semicolons.
Write the file even if some cases came back empty; every case in your batch needs a row.

Your reply to the orchestrator should be one short line: the batch number, the row count
written, and a count by determination. Do not paste the rows.

## Column alignment — the failure that field counts do not catch

A row can have exactly 11 fields and still be wrong. The common slip is **omitting
`ein_found` instead of leaving it empty** when there is no EIN: everything after it shifts
left one position, the row still has 11 fields, and the error survives every count-based
check.

Write an empty field for every value you do not have. Before you finish, verify one row by
eye: field 5 is `ein_found` (often empty), field 6 is the determination — one of `match`,
`not_a_nonprofit`, `nonprofit_not_in_bmf`, `cant_determine` — and field 7 is `tier1`/`tier2`/
`tier3`. If field 6 reads `tier1`, the row is shifted and must be rewritten.
