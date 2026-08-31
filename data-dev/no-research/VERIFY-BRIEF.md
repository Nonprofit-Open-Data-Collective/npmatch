# Refutation brief — stress-testing claimed EIN matches

A prior research pass claimed each organization in your batch matches a specific EIN, and
the SAM record and the BMF record are **in different states**. Your job is to **try to
refute** each claim. Default to `refuted` when the evidence is thin. A claim survives only
when you can positively confirm it.

## Working directory

`C:\Users\jdlec\Dropbox\00 - URBAN\00-GITHUB\npmatch`

`data-dev/no-research/BMF-GREP.tsv` is the full unified BMF (3.69M rows, tab-separated):
`ein  name  dba  city  state  zip5  care_of  subsection  ACTIVE|INACTIVE`.

## The specific failure mode you are hunting

A local, single-purpose entity being handed the EIN of its **national parent, sponsor, or
territorial corporation**. Watch for:

1. **HUD Section 202/811 and affiliated housing.** "X Apartments" in one state matched to a
   sponsor like RHF / Retirement Housing Foundation, National Church Residences, Volunteers
   of America, or NBA/Disciples in another state. Individual properties usually hold their
   **own** EIN. Grep the BMF for the property name and for the sponsor's affiliates before
   accepting a parent EIN.
2. **Federated charities.** Salvation Army, YMCA/YWCA, Goodwill, United Way, Red Cross,
   Boys & Girls Clubs, LULAC, NAACP. Some genuinely file only at territorial/national level;
   others have a local EIN. Determine which applies **for this organization**, and say so.
3. **Rebrands vs. different organizations.** A name change plus a state change is two
   independent leaps. Require a source that ties the old and new name together.
4. **`care_of` alignment.** A BMF record that lines up only through its care-of party is not
   the organization.

## Legitimate reasons a cross-state match can still be right

A genuine HQ relocation; a national organization whose SAM registration lists a field office
address; a single legal entity operating across state lines. Confirm with a source, don't
assume.

## Method

Grep the BMF for the SAM name's distinctive tokens **in the SAM state first** — if a
same-state entity with that name exists, the cross-state claim is almost certainly wrong and
you should return the better EIN. Then check ProPublica
(`https://projects.propublica.org/nonprofits/search?q=<distinctive+name>`; if it returns
HTTP 429, retry once, then fall back to web search and say so) and the open web.

## Output — write a TSV, do not report rows in your reply

Write to `data-dev/no-research/verify-out/verify-<NN>.tsv`, tab-separated, header first:

```
uei	claimed_ein	verdict	corrected_ein	corrected_determination	confidence	sources	judgement
```

- `verdict` — `confirmed` (claim holds), `refuted` (claim is wrong), or `uncertain`.
- `corrected_ein` — if refuted and you found the right EIN, put it here; otherwise empty.
- `corrected_determination` — if refuted, what it should be: `match`, `not_a_nonprofit`,
  `nonprofit_not_in_bmf`, or `cant_determine`. Empty when confirmed.
- `confidence` — `high` / `medium` / `low` in **your verdict**.
- `sources` — real URLs and greps, semicolon-separated; state negative results explicitly.
- `judgement` — one sentence on why the claim holds or fails.

No tabs or newlines inside fields. One row per claim, every claim. Reply with one short line:
batch number, rows written, and counts by verdict.
