# npmatch — A Reviewer's Guide

*A plain-language overview of how the nonprofit crosswalk is built, what the
package decides on its own, and where a human (or an LLM standing in for one)
comes in.*

---

## 1. What the package does

npmatch links organizations from one list (here, federal award/registration
records keyed by a **UEI**) to the IRS **Business Master File** of nonprofits
(keyed by an **EIN**). It does three things:

1. **Normalizes** both sides so they can be compared fairly — standardizing
   names ("The Smith Fdn., Inc." → "SMITH"), splitting addresses into
   comparable pieces (street, city, ZIP), and pulling out alternate names (DBAs,
   divisions).
2. **Runs a multi-tier matching strategy** — from strict to loose. It first
   looks for exact name-and-place agreement, then progressively widens: shared
   distinctive words, de-spaced/abbreviated variants, and finally same-name
   organizations in a different state. Each candidate pair is scored on how well
   the names and addresses agree, and rules veto impossible matches (a
   government body or a for-profit LLC can't be a nonprofit).
3. **Returns a scored, labeled candidate dataset** — for every source
   organization it produces the candidate EIN(s) it considered, a 0–1 match
   score, and a **decision label: YES, MAYBE, or NO**.

The output is not just "the answer" — it's an auditable table showing *which
candidates were weighed and why one was chosen*.

## 2. The two-stage idea

npmatch is deliberately split into two stages:

> **Stage 1 (the algorithm)** surfaces and sorts the candidates — fast,
> consistent, and cheap across millions of records.
> **Stage 2 (a human or an LLM)** confirms the ambiguous cases and gathers the
> extra evidence the algorithm can't see.

The three labels are the handoff between the stages. **YES** is confident enough
to accept automatically. **NO** is confident enough to reject. **MAYBE** is the
algorithm saying *"a match probably exists, but I can't be sure on name and
address alone — please look."* The goal of Stage 1 is not to be right about
everything; it's to be **right when it's confident and honest when it isn't**,
so Stage 2's effort goes only where it's needed.

## 3. The three answers — and how much to trust each

The numbers below are from a held-out sample of 1,000 randomly drawn source
organizations that were fully researched by hand, so we know the truth for each.

### 🟢 YES — "accept this match"
**Trust: ~98% correct. About 1 in 50 is wrong (a false positive).**

When the package says YES, the name and address agree strongly and no rule
objects. A reviewer's job here is light: glance at the candidate list and
confirm the obvious pick.

*Why the ~2% go wrong:* two different organizations that share distinctive words
**and** an address. Classic cases:
- **Same campus, different entity** — a booster club, auxiliary, or foundation
  sharing its parent's building ("Virtua Health" vs. "Virtua Health and
  Rehabilitation").
- **Same distinctive name, wrong entity type** — "Luzerne County Housing
  Authority" pulled toward "Luzerne County Historical Society." (A new
  government-entity rule now routes most of these to MAYBE instead.)

### 🟡 MAYBE — "a match likely exists; please review"
**Trust: this is the review tier. Combined with YES, ~98% of all true matches
are surfaced here for a human to see.**

MAYBE holds the genuinely ambiguous: the true match is *usually* somewhere in the
candidate list, but the algorithm won't auto-accept it. A reviewer either
**picks the right candidate** from the surfaced list or **collects a little more
information** (a website, a 990 filing, an address history) to decide.

*Why a case lands in MAYBE rather than YES:*
- **Subset/superset names** — "Nowlin Hall" vs. "Nowlin Hall Apartments." Could
  be the same org, could be a related property; name alone can't tell.
- **Parent vs. subsidiary vs. chapter** — all share the distinctive words, so
  the algorithm surfaces them but refuses to guess which EIN is right.
- **Cross-state parents** — a national organization that files under a
  headquarters in a different state than the local address.

### 🔴 NO — "no acceptable match found"
**Trust: correct rejection most of the time. About 2% of organizations that
*do* have a match are wrongly placed here (a false negative).**

Most NO answers are right — the organization genuinely has no current nonprofit
record. But a small share are misses. There are two reasons a true match ends up
in NO:

1. **The right candidate was never surfaced (a "blocking" miss).** The two names
   are too different for the search to connect them:
   - **Rebrands** — "Coalition for the Common Good" is Antioch University's new
     legal name; the strings share nothing.
   - **Acronyms** — "YWCA of Helena" vs. "Young Women's Christian Association."
   - **Typos in the official record** — "…Environment" vs. the BMF's
     "…Enviroment."
   - **Spacing/abbreviation** — "Step Forward" vs. "StepForward," "NE Texas" vs.
     "Northeast Texas." *(These last two are now recovered automatically.)*
2. **The organization truly isn't in the file** — churches (auto-exempt and
   often unlisted), foreign organizations, and brand-new nonprofits. Here NO is
   the *correct* answer, and a reviewer's job is simply to confirm that.

## 4. What a reviewer does in each tier

| Tier | Reviewer effort | Task |
|---|---|---|
| 🟢 YES | Light / spot-check | Confirm the auto-selected EIN against the surfaced candidates. |
| 🟡 MAYBE | Moderate | Pick the correct candidate, or gather a little evidence to decide. |
| 🔴 NO | Targeted | Confirm the org is genuinely unmatched — or research a possible miss. |

Because YES is ~98% precise and NO is mostly correct, **the real work
concentrates in MAYBE** — which is exactly where you want human judgment spent.

## 5. Humans or LLMs — interchangeable at Stage 2

Stage 2 is the same task whether a person or a language model does it: *look at a
surfaced organization, decide if a candidate is the right EIN, and if not, find
out what the organization actually is.* npmatch is built so the two are drop-in
substitutes.

To make the LLM path turnkey, the project ships a **tiered research protocol with
a reusable per-organization prompt** (see `dev/RESEARCH-PROTOCOL.md`). It
escalates only as far as needed and is cost-aware:
- **Tier 1** — a free local recheck against the full IRS file (name variants,
  de-spaced forms, typos).
- **Tier 2** — nonprofit registries (e.g., ProPublica) for the EIN.
- **Tier 3** — open web search to establish what the organization is when the
  registries are silent.

Each organization comes back with a determination, the EIN found (if any), the
source, a confidence level, and a token/cost estimate — the same structured
verdict a human enumerator would record, so the two can be mixed freely (e.g.,
LLM triage first, humans on the residual). This is what lets the review stage
scale from hundreds of cases to hundreds of thousands.

## 6. Where things stand today

On the researched benchmark:
- **YES precision ≈ 98%** (auto-accepts you can trust).
- **Coverage ≈ 98%** — of organizations that have a real match, ~98% are
  surfaced as YES or MAYBE for review; only ~2% are missed into NO.
- The **MAYBE tier is ~10% of cases** — the focused queue for Stage-2 review.

The matching engine (Stage 1) is the current deliverable. The evaluation dataset
— 1,500 hand-verified cases — is what these confidence numbers are measured
against, and it doubles as a regression check as the package improves.
