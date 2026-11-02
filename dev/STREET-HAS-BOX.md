# npmatch does not consume `street_has_box`, and why

npnormalize 0.1.4 added `street_has_box`: does a street *carry* a box
component, whether or not the whole street is one
([npnormalize#9](https://github.com/Nonprofit-Open-Data-Collective/npnormalize/issues/9)).
Its release notes name npmatch as the intended consumer — npmatch is the
package that compares a query street against a reference street, so it is the
one holding a bare identifier with "nothing to tell a box number from a door".

**npmatch consumes nothing.** The column is redundant here: on every pair where
it would fire, `is_po_box` already fires, and on every one of those the score
ladder already refuses the credit. The measurements are below, and
`tests/testthat/test-box-component.R` pins each of them, so that a regression in
npnormalize's parse breaks npmatch's suite rather than passing quietly.

Numbers are from the unified BMF (3,687,435 records, 2,026,583 distinct street
strings, `data-dev/NORM-BMF-UNIFIED-v2.rds`) and from the labeled benchmark
(304,274 scored pairs, 1,168 true matches,
`data-dev/TRAINING-PAIRS-FULL-1502.rds`), both read under **npnormalize 0.1.5**
(signature `v1-533f186c123357cf`), which landed while this was being measured.
Every number below was also measured under 0.1.4 and the conclusion is the
same; 0.1.5 only moves 1,010 lettered-box rows (`PO BOX A` … `PO BOX Z`) out of
`street_has_box & !is_po_box` and into `is_po_box`, shrinking the only slice
where the two columns differ from 11,982 rows to 10,984. Both versions are
checked against the installed package rather than a copied constant, so the
tests below do not pin a version.

## 1. The failure the column was offered to guard

A box number compared against a house number and scored as agreeing. In npmatch
that is `geo_stnum`, which `np_compare()` sets from an exact `street_num`
comparison, and which `.np_hier_score()` reads through
`street_hit <- geo_stnum == 1 & street_sim >= 0.9 & geo_pobox == 0`.

So the question is narrow: **can `street_num` hold a box number on a row where
`is_po_box` is FALSE?** If it cannot, `is_po_box` — which npmatch already reads,
as `geo_pobox` — answers the whole question and `street_has_box` adds nothing.

## 2. It cannot. 0 rows.

`street_has_box & !is_po_box` is 8,692 distinct streets, 10,984 rows (0.298%).
Classifying `street_num` on exactly those rows:

| `street_num` on a `street_has_box & !is_po_box` row | distinct | rows | share |
|---|---|---|---|
| `NA` | 4,551 | 6,482 | 0.1758% |
| the leading house number | 4,101 | 4,461 | 0.1210% |
| a lettered or grid house number (`229C`, `48W445`) | 40 | 41 | 0.0011% |
| **the box number** | **0** | **0** | **0%** |

The accounting is complete: every non-`NA` `street_num` in the slice is the
street's own leading token.

This is 0.1.4's own doing. The same release anchored `.np_parse_street()`'s
gate, so a street that merely carries a box keeps its house number:
`520 N MAIN ST BOX 30` parses to `520`, not `30`; `211 EMMET ST S PO BOX` to
`211`; `ONE HARRISON PLZ BOX 5079` to `NA`, not `5079`. A box number reaches
`street_num` only where `is_po_box` is TRUE, and there it is correct and
announced.

The same holds on the unit side: across the BMF, 282 distinct streets (293
rows, 0.0079%) both carry a box and name a unit, and on **0** of them is the
extracted unit identifier the box number. npnormalize's designator gate never
reads a box number as a unit, so `geo_unit` cannot compare one against a door
either.

## 3. Even where the numbers do collide, the ladder already refuses credit

`street_num` collisions between a box and a door do exist — they just need
`is_po_box` to differ. Across the BMF there are 12,739 `(zip5, number)` pairs
where a PO box number equals a house number in the same ZIP, 18,108
reference-row products. On **none of them** does the `street_key` similarity
reach 0.9:

```
max street_key JW over all 12,739 collisions: 0.634
  e.g. PO BOX 1805 vs 1805 PENBROOK TER   (07065)  jw 0.634
       PO BOX 1014 vs 1014 W PONTOON RD   (62040)  jw 0.634
       PO BOX 32   vs 32 BARSTOW ST 2     (01970)  jw 0.630
```

`street_hit` needs `street_sim >= 0.9`, so it cannot fire on any of them. The
street-body floor already absorbs the collision, and it does so without knowing
anything about boxes.

The only other reader of a bare `geo_stnum == 1` is `addr_ok` in
`np_compare()`, the gate on name-blind recovery. A spurious hit there opens a
containment/overlap path that `np_score()` caps at MAYBE — it surfaces a pair
for review and can never auto-accept one.

## 4. On the labeled benchmark the column selects the same pairs, and no others

| on 304,274 scored pairs | count |
|---|---|
| query street `street_has_box & !is_po_box` | 0 |
| reference street `street_has_box & !is_po_box` | 981 |
| `street_has_box` disagrees across the pair | 51,476 |
| ... **and** `geo_stnum == 1` | **29** |
| `is_po_box` disagrees **and** `geo_stnum == 1` | **29** — the same 29 |
| of those 29, `street_sim >= 0.9` | **0** (max 0.000) |
| flag disagrees, `is_po_box` **agrees**, `geo_stnum == 1` | **0** |

The last three rows are the decisive ones. The two sets of 29 are not merely
equal in size — they are identical row for row, checked by index. So
`street_has_box` selects exactly the pairs `is_po_box` already selects and not
one more; all 29 are box-against-door, and all 29 already fail the street-body
floor. And the shape a flag-based rule would have had to itself — the flag
disagreeing while `is_po_box` agrees — occurs **0** times.

## 5. Why not a veto anyway

A veto keyed on "`street_has_box` disagrees across the pair and the numbers
agree" would be **wrong**, not merely useless. The flag disagrees on

```
211 EMMET ST S PO BOX   (street_has_box TRUE,  is_po_box FALSE, street_num 211)
211 EMMET ST S          (street_has_box FALSE, is_po_box FALSE, street_num 211)
```

and 211 is a genuine house number on both sides: one building, written by one
filer who carries the box number on line 2 and by another who does not. A hard
veto refuses that pair outright. `tests/testthat/test-box-component.R` keeps it
as the must-still-match case.

## 6. The one real cost, which the column does not fix

`street_key` keeps the box word, so that same true pair pays for it in the
street body:

| comparator | `211 EMMET ST S PO BOX` vs `211 EMMET ST S` | `street_hit` |
|---|---|---|
| `jw_p = 0.1` (Jaro-Winkler) | 0.933 | fires |
| `jw_p = NULL` (the default: plain Jaro, no prefix boost) | 0.889 | does not fire |

Under the default comparator the pair loses the shared-building term (0.95) and
falls back to its ZIP5 (0.90) — a 0.4 x 0.05 = 0.02 score difference, against
thresholds of YES 0.78 / MAYBE 0.65. It is not refused and it is not dropped.

`street_has_box` does not help with this either: the flag says the tail is
there, it does not remove it. Removing it would mean stripping the box word out
of `street_key` before comparison — a normalization change, which belongs in
npnormalize and would move the signature. And the shape occurs **0** times in
the benchmark, so there is nothing measured to pay for it. Both rows of that
table are pinned as tests.

## 7. If this is revisited

Two things would change the answer, and neither is true today:

1. **A query source with a real second address line.** The unified BMF carries
   `unit` NA on all 3,687,435 rows — its 401,843 `street_unit` values all come
   from the street line itself — and the 2,000-row SAM query frame has 118
   non-empty second lines, every one designator-led (`STE 100`, `FL 2`), none
   digits-only, with 0 queries carrying a box at all. A source that files a bare
   box number on line 2 is the case npnormalize's notes describe, and npmatch
   would then be the package that has to decide whether that bare number is a
   box or a door. The hook for it is `geo_unit_same_kind` in `R/compare.R`,
   which already resolves the sibling ambiguity ("a bare `#` is either a door or
   a mailbox") for the mail-store case: a `#` whose street carries a box is a
   mailbox, not a door. Measure the source first.
2. **A regression in npnormalize's anchored parse gate.** Section 2 rests on it
   entirely. That is what `test-box-component.R`'s first test asserts, against
   the installed npnormalize rather than against a copied constant.

Re-run the measurement before changing this decision. The scripts are
`dev/scan-box-component.R` in npnormalize — the column's own record — and the
probes behind sections 2-4 here, which are the same two frames read under the
current normalizer.
