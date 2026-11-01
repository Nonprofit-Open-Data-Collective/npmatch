<div id="main" class="col-md-9" role="main">

# The Candidate Evaluation Frame — Fields & Methods

*A technical companion to the Reviewer’s Guide. It defines every field
in the evaluation frame npmatch returns and explains how the derived
measures — similarity scores, token weights, name-distinctiveness, and
the geographic hierarchy — are computed.*

<div class="section level2">

## What the evaluation frame is

The matcher returns **one row per surfaced candidate** (a source
organization with several plausible EINs contributes several rows). Each
row is a self-contained *review packet*: everything a human or an LLM
needs to judge whether that candidate is the right match, arranged in an
**information hierarchy** from the bottom line up:

1.  **Match strength & outcome** — the score, the decision, and any
    veto.
2.  **Name-match summary** — which name matched, how, and how
    distinctive it is.
3.  **Name-cleaning progression** — raw → normalized → tokenized, for
    both sides.
4.  **Address & geography** — field similarities and exact-agreement
    flags.
5.  **Imported context** — descriptive fields carried verbatim from each
    source, flagged by a `SAM_` / `BMF_` prefix.

Two conventions run throughout: a **`_uss` / `_bmf` suffix** marks which
side a field describes (source vs. reference), and a **`SAM_` / `BMF_`
prefix** marks a field *imported* from that dataset rather than
*derived* by npmatch.

The `_uss` / `_bmf` and `SAM_` / `BMF_` names come from the deployment
npmatch ships wired for — federal registrants against the IRS Business
Master File. Read them as *source* and *reference*: the derived fields
and the layout are the same whatever the two datasets are, and
`np_route()` takes the context frames to import as arguments.

</div>

<div class="section level2">

## Field dictionary

<div class="section level3">

### 1 · Match strength & outcome

<div class="cell">

<div class="cell-output-display">

<div class="kable-table">

| Field                        | Meaning                                                                      |
|:-----------------------------|:-----------------------------------------------------------------------------|
| uei / ein                    | the two entity keys — source UEI and reference EIN                           |
| name_similarity              | 0–1 agreement of the names (see Methods)                                     |
| addr_similarity              | 0–1 agreement of the addresses (best available granularity)                  |
| candidate_type               | how this candidate entered — exact, token, de-spaced, cross-state            |
| total_score                  | combined 0–1 score = 0.6·name_similarity + 0.4·geo (see Methods)             |
| num_of_candidates            | how many candidates were surfaced for this source org (review group size)    |
| is_top_candidate             | 1 on the selected pick (YES/MAYBE); 0 on the others                          |
| match_decision               | the tier: YES (auto-accept) / MAYBE (review) / NO (reject)                   |
| match_layer                  | which cascade pass produced this candidate                                   |
| decision_reason              | short human-readable reason for the tier                                     |
| veto / veto_reason           | hard do-not-match rule fired → forces NO (e.g. for-profit legal form)        |
| veto_soft / veto_soft_reason | soft rule fired → capped at MAYBE (e.g. affiliate suffix, government entity) |
| notes                        | free-text annotations                                                        |

</div>

</div>

</div>

</div>

<div class="section level3">

### 2 · Name-match summary

<div class="cell">

<div class="cell-output-display">

<div class="kable-table">

| Field                                 | Meaning                                                                                               |
|:--------------------------------------|:------------------------------------------------------------------------------------------------------|
| match_name_uss / match_name_bmf       | the actual name string that produced the match, on each side                                          |
| match_version_uss / match_version_bmf | which name version matched: MAIN, DBA, or DIVISION                                                    |
| match_type                            | exact · name (fuzzy) · dba · token_overlap — how the names were matched                               |
| normalized_match_count                | how many reference records share this exact normalized name — a distinctiveness measure (see Methods) |

</div>

</div>

</div>

</div>

<div class="section level3">

### 3 · Name-cleaning progression (each side, `_uss` and `_bmf`)

<div class="cell">

<div class="cell-output-display">

<div class="kable-table">

| Field                  | Meaning                                                                                  |
|:-----------------------|:-----------------------------------------------------------------------------------------|
| name\_\*\_raw_main     | the original legal name as supplied                                                      |
| name\_\*\_raw_dba      | the original DBA / alternate name, if any                                                |
| name\_\*\_raw_division | the original division / second alternate name, if any                                    |
| name\_\*\_normalized   | the cleaned match key (suffixes, ‘The’, punctuation removed; abbreviations standardized) |
| name\_\*\_org_type     | the organization-type words that were stripped (Foundation, Inc, Association …)          |
| name\_\*\_tokenized    | the informative tokens with their IDF weights, rarest first — TOKEN(idf) (see Methods)   |

</div>

</div>

</div>

</div>

<div class="section level3">

### 4 · Address & geography

<div class="cell">

<div class="cell-output-display">

<div class="kable-table">

| Field                                                              | Meaning                                                                                |
|:-------------------------------------------------------------------|:---------------------------------------------------------------------------------------|
| street_similarity / city_similarity / zip_similarity               | 0–1 field-level agreement for street, city, ZIP                                        |
| street\_\* / city\_\* / state\_\* / zip5\_\* (per side)            | the raw address components carried for both sides                                      |
| street\_\*\_normalized                                             | the standardized street body used for comparison                                       |
| geo_stnum / geo_zip9 / geo_zip5 / geo_zip3 / geo_state / geo_pobox | exact-agreement flags (1/0) at each granularity of the ZIP/geo hierarchy (see Methods) |

</div>

</div>

</div>

</div>

<div class="section level3">

### 5 · Imported context (appended last)

`SAM_`-prefixed fields (entity structure, NAICS, points of contact, …)
and `BMF_`-prefixed fields (NTEE code, 501(c) subsection, ruling year,
assets, revenue, foundation status, …) are carried **verbatim** from the
source and reference datasets to give the reviewer background. They are
not computed by npmatch and are documented in their originating
dataset’s data dictionary; the prefix is the provenance flag.

</div>

</div>

<div class="section level2">

## Methods — how the derived measures are computed

<div class="section level3">

### Name similarity (Jaro–Winkler)

Name agreement is a **Jaro–Winkler** similarity in \[0, 1\]. Jaro counts
how many characters the two strings share **within a sliding window**
(so order and small gaps are tolerated) and penalizes **transpositions**
(characters matched but out of order). **Winkler** then adds a *prefix
boost*: strings that agree on their first few characters score higher,
because shared beginnings are strong evidence for organization names.
npmatch uses a prefix factor `p = 0.1` and **floors** similarities below
`jw_threshold` (default 0.85) to 0, so unrelated strings contribute
nothing.

<div class="cell">

<div class="cell-output-display">

<div class="kable-table">

| A                    | B                   |  jaro | jaro_winkler |
|:---------------------|:--------------------|------:|-------------:|
| MERCY HEALTH         | MERCY HEALTH SYSTEM | 0.877 |        0.926 |
| MERCY HEALTH         | MEDSTAR HEALTH      | 0.733 |        0.786 |
| SAINT MARYS HOSPITAL | SAINT MARYS HOSP    | 0.933 |        0.960 |
| STEP FORWARD         | STEPFORWARD         | 0.972 |        0.983 |

</div>

</div>

</div>

The `jaro_winkler` column is what npmatch uses. Note how the shared
prefix lifts “MERCY HEALTH” / “MERCY HEALTH SYSTEM” above the unrelated
“MEDSTAR HEALTH”, and how a de-spaced or truncated variant still scores
high. Where the character-level score misses a real match — reordered
words, acronyms, subset/superset names — a **token-overlap** measure
takes over (that match is capped at MAYBE, since containment alone can’t
separate a parent from a subsidiary).

</div>

<div class="section level3">

### Tokenized names and IDF weights

A normalized name is split into **tokens** (words). Each token carries
an **inverse document frequency (IDF)** weight, `log(N / d)`, where `N`
is the number of reference records and `d` is how many contain that
token. **Rare tokens score high** (they pin down an organization);
common ones score low. The `name_*_tokenized` field lists tokens
**rarest-first** as `TOKEN(idf)`, so a reviewer can see at a glance
which words carry the match.

<div class="cell">

<div class="cell-output-display">

<div class="kable-table">

|     | token       |  idf |
|:----|:------------|-----:|
| 1   | ACTION      | 1.95 |
| 2   | AGENCY      | 1.95 |
| 3   | CENTER      | 1.95 |
| 4   | CLINIC      | 1.95 |
| 8   | STEPFORWARD | 1.95 |
| 7   | MERCY       | 1.25 |

</div>

</div>

</div>

Here “STEPFORWARD” (appears once) is far more discriminating than
“COMMUNITY” (appears in many records). Blocking uses these weights so a
pair is only proposed when it shares *distinctive* words — one rare
token, or several moderately common ones, not a lone “COMMUNITY”.

</div>

<div class="section level3">

### Name distinctiveness (`normalized_match_count`)

This counts how many reference records share a candidate’s exact
normalized name. A count of **1** means an exact name match is
trustworthy on its own (few things are named that); a large count
(e.g. “First Baptist Church”) means an exact name match needs address
corroboration. npmatch uses it to decide when an exact name alone
justifies a confident tier.

</div>

<div class="section level3">

### The geographic hierarchy and the geo score

ZIP codes form a **nested prefix family**: the 3-digit region contains
the 5-digit ZIP, which the +4 refines to `zip9`.

> `zip3` ⊃ `zip5` ⊃ `zip9` · plus street number, PO box, city, state

The `geo_*` flags record exact agreement at each level. The **geo
sub-score takes the strongest confirmed granularity via a `max`, not a
sum** — so a matching ZIP+4 (or street) counts fully, correlated fields
aren’t double-counted, and a wrong *city* can’t drag down a
*ZIP*-confirmed match. Granularity weights, strongest to weakest:

<div class="cell">

<div class="cell-output-display">

<div class="kable-table">

| granularity | weight |
|:------------|-------:|
| zip9        |   1.00 |
| unit        |   0.97 |
| street      |   0.95 |
| zip5        |   0.90 |
| pobox       |   0.90 |
| zip3        |   0.55 |
| city        |   0.50 |
| state       |   0.20 |

</div>

</div>

</div>

This is what lets the score **degrade gracefully**: an org known only to
the state level still scores (weakly) on geography, while one confirmed
to the building scores fully — without either being penalized for the
detail it lacks.

</div>

<div class="section level3">

### The combined score

    total_score = 0.60 · name_similarity  +  0.40 · geo_score

with `geo_score` the max-over-granularity value above. A distinctive
exact name can be promoted (trusted without address); a
token-overlap-only match is capped below YES. The `match_decision` tier
then applies the YES (≥ 0.78) and MAYBE (≥ 0.65) thresholds, plus a
runner-up **margin** check so a near-tie between two candidates routes
to review rather than auto-accepting the wrong one.

</div>

</div>

<div class="section level2">

## Appendix — field order in the frame

Fields are emitted in the information hierarchy above: keys and decision
first, then the name summary, the name-cleaning progression, address and
geography, and finally the imported `SAM_` / `BMF_` context. The `_uss`
/ `_bmf` suffix always marks the side; the `SAM_` / `BMF_` prefix always
marks an imported (non-derived) field.

</div>

</div>
