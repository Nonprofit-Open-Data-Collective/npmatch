---
title: "Reviewer's Guide"
subtitle: "Checking the nonprofit match results"
date: "September 2026"
---

# What this project is doing

We have a list of organizations that register with the federal government to
receive awards. Each one has a federal registration number called a **UEI**. We
also have the IRS's master list of nonprofits, where each organization has an
**EIN** — its tax identification number.

The goal is to connect the two: for each federal registrant, find the same
organization in the IRS file. That connection lets us tell what kind of
nonprofit received an award, how large it is, and what it does.

The difficulty is that the two lists rarely write a name the same way. One says
"The Smith Foundation, Inc.", the other says "SMITH FDN". One lists a
headquarters, the other a local office. There is no shared identifier to join on,
so the match has to be worked out from names and addresses.

# Your job as a reviewer

**The computer has already proposed an answer for every organization. Your job is
to check whether it got them right.**

You are not being asked to find matches from scratch. You are being asked to look
at what was chosen, decide whether it is believable, and **flag the ones that look
wrong or doubtful**. A reviewer who flags twenty genuinely bad matches has done
far more good than one who confirms a thousand obvious ones.

The spreadsheet has been arranged to make this as quick as possible. Most rows
will take a couple of seconds. Save your attention for the ones that look odd.

# How the matching works

The work happens in three stages. Each stage is more expensive than the last, so
each one only handles what the stage before it could not settle.

## Stage 1 — The matching algorithm

The computer compares every federal registrant against the IRS list and scores
how well they agree on two things:

- **Name similarity** — how close the two organization names are
- **Address similarity** — how close the two addresses are

These combine into a single **total score** between 0 and 1, where 1 means the
name and address both agree almost perfectly. Name agreement counts for rather
more than address agreement, because two unrelated nonprofits share a building
far more often than they share a distinctive name.

Any IRS organization that scores well enough becomes a **candidate** — a possible
answer worth considering. Most registrants get a handful of candidates; some get
only one; some get none.

Then the algorithm decides what to do:

- **If one candidate scores above 0.78 and is clearly ahead of the runner-up, it
  becomes the match.** The computer is confident enough to accept it without
  further review. Most matches are settled here.
- **Otherwise, nothing is accepted automatically** and the whole group of
  candidates is passed on to stage 2.

The algorithm also refuses certain matches outright, no matter how well the names
agree — a for-profit company or a city government cannot be a nonprofit.

## Stage 2 — Judgment applied to the candidates

Stage 2 looks at the cases stage 1 could not settle. The candidates are already
on the table; the only question is **which one, if any, is the same organization**
— not a similar one, not a related one, but the same legal entity.

It applies a consistent set of rules.

**These are treated as different organizations, even when the names look alike:**

- Different chapter, post, lodge, or local numbers — American Legion Post 51 is
  not American Legion Post 27
- Different ordinals — First Baptist Church is not Second Baptist Church
- Different generational suffixes — a Jr. and a Sr. foundation are two entities
- A parent organization and an affiliate that registered separately

**These are treated as the same organization:**

- A trade name or "doing business as" name against the legal name
- A division name that matches the division named in the registration
- Differences that are only punctuation, spacing, or abbreviation
- A former name, when the address confirms it is the same place

Two further principles guide the call. A shared address raises confidence but
never settles it on its own. And a name that agrees but is generic, with nothing
geographic to corroborate it, is weak evidence.

Each decision is recorded as a yes or no, with a confidence rating and a
one-sentence reason.

## Stage 3 — Research

Whatever is still unmatched after stages 1 and 2 goes to stage 3, which is the
only stage allowed to look beyond the candidate list.

First, obvious cases are set aside without research. If the registration plainly
describes a city government, a for-profit company, or an individual person, there
is no nonprofit to find.

Everything else is researched, escalating only as far as needed:

1. **A careful second look at the IRS file**, allowing for spelling variants,
   missing spaces, and typos that the first pass would have missed.
2. **Nonprofit registries**, which can turn up an EIN the IRS file did not
   surface.
3. **An open web search**, to establish what the organization actually is when
   the registries are silent.

Stage 3 ends with one of four conclusions:

| Conclusion | What it means |
|---|---|
| **A match was found** | A specific EIN is the same organization. This is the only outcome that produces a match. |
| **A nonprofit, but not in this IRS file** | Genuinely a nonprofit, legitimately absent — most often a church, which is automatically exempt and frequently unlisted, or a foreign organization. |
| **Not a nonprofit** | A business, an individual, or a government body. |
| **Could not be determined** | The evidence ran out. |

Because stage 3 can search outside the candidate list, it sometimes finds an
organization the algorithm never surfaced at all — usually where the two names
share almost no words, such as an organization that has been renamed.

# How to read the spreadsheet

## The tabs

- **`eval_frame`** — the data you are reviewing
- **`data_dictionary`** — what every column means, in order
- **`legend`** — a reminder of what the colors mean

## How it is organized

**Rows are grouped by organization.** All the candidates considered for one
federal registrant sit together in a block, and the shading alternates between
white and gray at each new registrant. The gray and white carry no meaning beyond
telling you where one organization's block ends and the next begins.

**The match is shaded orange.** In each block, the orange row is the answer the
process settled on — whichever of the three stages produced it. There is exactly
one orange row per matched organization.

**A block with no orange row was not matched.** That is often the correct answer:
churches, foreign organizations, businesses, and government bodies all belong
here.

The rows that are *not* orange are the candidates that were considered and set
aside. They are useful context: they show you what else was on the table and let
you judge whether the right one won.

The most useful columns sit at the left of the sheet, so you can usually work
without scrolling: the two organization names, the two addresses, the similarity
scores, and the total score.

## How to review a block

1. **Read the registrant's name and address** on the left.
2. **Look at the orange row** — is this plausibly the same organization?
3. **Glance at the other rows in the block.** Did a better candidate get passed
   over?
4. **Move on, or flag it.** If something looks wrong or you cannot tell, flag the
   row and write a short note saying what bothered you. You do not need to find
   the right answer — identifying the problem is the contribution.

A block with a single candidate and a high score is usually a two-second check. A
block with several close candidates deserves a longer look — that is where
mistakes hide.

# What to watch out for

These are the mistakes this kind of matching makes most often. All the examples
below are real cases from this data.

## 1. The organization matched to its own fundraising foundation

The most common error, and the hardest to spot, because everything looks right:
the names nearly agree, the address agrees exactly, and the score is high. But a
college and its foundation are two separate legal entities with two separate
EINs.

> "Kishwaukee College" matched to "Kishwaukee College Foundation"
> "Joplin Public Library" matched to "Joplin Library Foundation"
> "Centricity Credit Union" matched to "Centricity Credit Union Foundation"

**Watch for** the words *Foundation*, *Friends of*, *Auxiliary*, *Booster*, or
*Endowment* appearing on one side and not the other.

## 2. A local branch matched to its national headquarters

Many local operations have no separate IRS record, so the match lands on the
national or regional organization instead. One EIN then ends up standing for
dozens or hundreds of separate local registrations.

> A Salvation Army corps in Georgia and another in Michigan both matched to the
> same national Salvation Army EIN.
> Over a hundred Good Samaritan Society locations across the Dakotas all matched
> to a single EIN.

Whether this is right depends on what the number will be used for. Counting
organizations, it overstates nothing but hides the local unit. Tracing money to
the entity that files a tax return, it may be exactly right. **Flag these so the
decision gets made deliberately rather than by accident.**

**Watch for** a very well-known national name, and an address in a different city
or state from the registrant.

## 3. The right name in the wrong place

The names agree closely but the addresses are in different states. Sometimes
correct — a national organization files under a headquarters elsewhere. Sometimes
two unrelated organizations simply share a name.

> "Mercy Manor" in Paducah, Kentucky matched to "Mercy Manor" in Denver, Colorado
> "Transformative Community Health" in Naperville, Illinois matched to the same
> name in Las Vegas, Nevada

**Watch for** a high name score alongside a low address score. The name is
carrying the entire decision on its own.

## 4. Numbered and ordinal siblings

Chapters, posts, lodges, and locals are distinct organizations that differ only
by a number — and a number is a very small part of a long name, so the score
barely moves when it is wrong.

> "American Legion Post 51" and "American Legion Post 27" are different
> organizations, as are "First Baptist Church" and "Second Baptist Church".

**Watch for** any number or ordinal in the name. Check it digit by digit; do not
trust the score here.

## 5. Generic names

Some names are so common that the name alone cannot identify anyone — "Community
Action Agency", "Housing Authority", "Historical Society". The algorithm will
surface many candidates and may pick one almost arbitrarily.

**Watch for** blocks with several candidates all scoring similarly. If nothing
distinguishes the winner from the runners-up, that is a case to flag.

## 6. Similar names, unrelated organizations

Two organizations can share their most distinctive words and be entirely
unconnected, especially when they also share a town.

> "Torrington Housing Authority" and "Torrington Community Housing"
> A county Housing Authority pulled toward the county Historical Society

**Watch for** a shared place name doing most of the work, with the rest of the
name describing a different kind of activity.

## 7. Renamed organizations

When an organization changes its name, the old and new names may share nothing at
all. The algorithm cannot connect them, so these usually surface only in stage 3,
if at all. If you happen to know that a registrant has been renamed and it is
unmatched, that is worth flagging — the research stage may have missed it.

## 8. Typos and spacing in the official records

Both sources contain errors, and an error on either side can break a match or
create a false one.

> The IRS file contains "Texas Inter-Faith Housing Corporati on" with a stray
> space, and "Westminister Towers" for "Westminster Towers".

**Watch for** near-identical names where a match was *not* made — the reason may
simply be a typo in one of the records.

## 9. A match that is correct but no longer active

The organization may be the right one while its IRS record is dormant or it has
not filed a return in years. This is not a matching error, but it matters for how
the record can be used. The spreadsheet records the status of each matched
organization in plain language.

## 10. Correct non-matches — confirm, don't chase

Many unmatched organizations are unmatched for good reason. Churches are
automatically tax-exempt and are often absent from the IRS list entirely. Foreign
organizations, brand-new nonprofits, businesses, and government agencies all
belong in the unmatched group. Here, no match **is** the right answer, and all
that is needed is to confirm it.

# If you are short on time

Work in this order:

1. Blocks where several candidates scored close together
2. Blocks where the names agree but the addresses are in different states
3. Any name containing a number or an ordinal
4. Any match where one side says *Foundation*, *Friends of*, or *Auxiliary* and
   the other does not
5. Well-known national names matched from a small local address

If you get through only the first two, you will have covered most of the errors
worth finding.
