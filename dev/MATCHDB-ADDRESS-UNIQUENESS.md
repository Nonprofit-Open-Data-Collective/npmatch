# Precompiling address and suite uniqueness in matchdb

A design note for the matchdb side, written from what npmatch now does at run
time and what it measurably cannot do there. Numbers are from the unified BMF
(1,924,822 records, `data-dev/NORM-R.rds`), measured with
`dev/scan-unit-designators.R` and the probes behind this note.

## 1. What npmatch does today, and where it runs out

`np_addr_freq()` builds three tables from the reference frame it is handed:
records per address, records per address + suite, and distinct suites per
address. `np_compare()` annotates every candidate pair with `geo_unit`
(1 same suite / 0 different / NA unknown), `addr_shared`, `addr_units`,
`addr_unit_shared` and a reviewer-facing `addr_note`, and
`np_score(method = "hier")` credits a matching suite only where the address has
several distinct suites on record and that suite is not itself shared by more
than `share_min` (default 10) records.

Three limits, in increasing order of how much they matter:

1. **It is computed per run, from whatever frame is passed.** `np_cascade()`
   builds it once from the whole reference, but any caller that compares a
   *slice* (a state partition, a shard) gets counts for the slice. A shared
   address is then systematically under-reported, and the quiet failure is the
   bad kind: scores shift with no error.
2. **It needs the whole corpus in memory in every worker.** 1.2M addresses as
   named integer vectors, rebuilt per process.
3. **It cannot see what actually distinguishes the shared-address cases**,
   because that needs the occupants' names and the BMF's own group-ruling
   columns, joined across the full database. See section 4. This is the real
   argument for preprocessing, not the first two.

## 2. The scale of the problem

| | count | share |
|---|---|---|
| records | 1,924,822 | |
| PO box records (excluded throughout) | 383,498 | 19.9% |
| distinct street addresses (`street_key` + `zip5`) | 1,197,673 | |
| addresses shared by 2 or more records | 138,629 | 11.6% of addresses |
| records living at a shared address | 482,097 | 25.0% of records |
| addresses with more than 10 records | 3,723 | 0.3% |
| address + suite groups with more than 10 records | 922 | |
| most distinct suites at one address | 98 | |

**Only 11.6% of addresses are shared at all.** A precompiled table should carry
only those: a lookup miss means "one record here", which is the answer for the
other 1.06M addresses. That is an ~89% reduction before any other compression.

## 3. The key contract

The precomputed key has to be the key npmatch builds, character for character,
or every lookup misses silently.

* Address key = `.np_addr_key()` = `street_key` + `" "` + `zip5`, with PO boxes
  mapped to an empty key and dropped. `street_key` is `.np_street_key()`:
  special letters folded, de-accented, upper-cased, **unit removed**, USPS
  street types standardized, punctuation collapsed.
* Suite key = address key + `"|"` + `street_unit_id`, the identifier with
  separators dropped (`STE D-2` becomes `D2`), so `STE 320`, `Suite 320` and
  `# 320` are one office.
* Stamp the table with `np_normalize_signature()` and **refuse to load it
  against a different value**, exactly as the cached `name_key` artifacts do.
  The street parser moved twice this month (letter folding, then the unit
  rewrite, which changed `street_key` on 34,280 BMF rows), and a table built
  across either boundary is wrong rather than stale.

The cheapest way to honour the contract is for matchdb to *store* npmatch's
computed `street_key` and `street_unit_id` next to the EIN rather than
re-deriving them in SQL. A SQL port is possible, and `md_light_key()` already
does it for names, but it doubles the surface that has to stay in sync.

## 4. What to precompute: classify, do not just count

Counts alone cannot tell the two crowded-address archetypes apart, and they
pull in opposite directions. The occupants' names separate them cleanly. The
five most-occupied addresses in the BMF:

| address | records | distinct `name_key` | top-name share |
|---|---|---|---|
| 3700 GRAND AVE 50312 (PEO Sisterhood) | 5,965 | 45 | 0.98 |
| 1 WATERFOWL WAY 38120 (Ducks Unlimited) | 4,639 | 13 | 0.99 |
| 770 AUGUSTA RD 29824 (Natl Wild Turkey Fedn) | 3,662 | 23 | 0.99 |
| 2029 WOODLAND PKWY 63146 (Beta Gamma Sigma) | 544 | 17 | 0.96 |
| 501 SILVERSIDE RD 19809 (Foundation Source) | 1,933 | 1,931 | 0.00 |

Two regimes, and one statistic puts a bright line between them: the share of
records carrying the single most common `name_key`.

* **Federated parent / group ruling** (top-name share approaching 1). Thousands
  of chapters file from the national office under one name. The address is not
  weak evidence here, it is *anti*-evidence: it matches every chapter equally,
  and so does the suite. What separates them is the chapter number, which
  npmatch already extracts (`name_nums`) and vetoes on.
* **Fiscal sponsor / service provider / registered agent** (distinct names
  approaching the record count). Foundation Source hosts 1,933 private
  foundations under 1,931 distinct names. The address is pure noise.
* **Multi-tenant building** (many distinct suites, each held by one or two
  records). The suite is the discriminator, and this is the case npmatch's new
  credit exists for.
* **Family cluster** (2 to 4 records whose names share distinctive tokens: an
  org, its foundation, its auxiliary). Neither address nor suite helps; the
  name logic already handles it.

### Proposed table

One row per shared address (`n_records >= 2`), plus one row per shared
address + suite:

| column | why |
|---|---|
| `addr_key`, `unit_id` (`NULL` at address grain) | the join keys of section 3 |
| `n_records`, `n_eins` | occupancy, and distinct EINs in case of duplicate rows |
| `n_active`, `n_total` | the active-only and unified counts **both**, so a run can pick the population matching its reference; counting defunct orgs inflates every threshold |
| `n_distinct_name_key`, `top_name_share` | the discriminator above |
| `n_distinct_units`, `max_records_per_unit` | multi-tenant versus mail drop |
| `n_records_with_unit`, `unit_coverage` | section 5, the trap |
| `n_group_exemptions`, `share_in_largest_group` | from the BMF's own `group_exemption_number` / `affiliation_code`: a decisive and free federated-address test |
| `addr_class` | the label, derived from the above |
| `first_vintage`, `last_vintage`, `occupant_churn` | section 7 |
| `signature` | the normalizer stamp of section 3 |

Ship the evidence columns, not only `addr_class`, so npmatch can re-derive the
label under different thresholds without a rebuild.

## 5. The trap: suites are mostly not recorded

At the 4,417 addresses with 10 or more records, the share of records that name
a suite has median **0.73** and mean **0.52** - and at **1,601 of them not one
record names a suite**.

This matters because npmatch's current gate is `addr_units >= 2`: it asks
whether the reference lists several suites at the address. At a genuine
multi-tenant building where the BMF recorded suites for only a third of the
tenants, that test passes on thin data; at the 1,601 addresses with no suites
at all it never fires however crowded the building is. So:

* precompute `unit_coverage` and let npmatch require a floor (say 0.5) before
  treating "several distinct suites" as a description of the building rather
  than of the data;
* where coverage is low and occupancy is high, the honest output is the
  reviewer flag, not a score adjustment.

## 6. Post offices and the other non-buildings

"Post offices aside" is the right instinct, and the class is wider than PO
boxes. Each of these should be labelled and excluded from occupancy counts
rather than silently inflating them:

* **PO boxes** - already excluded by `.np_addr_key()` (19.9% of records). A box
  number *is* the address, so counting records at one counts the box's owners,
  not a building's tenants.
* **CMRA / private mailboxes** - `PMB` is now parsed as a unit (10,752 BMF
  rows). A mailbox store with 200 PMBs looks exactly like a multi-tenant
  building and is not one. Flag an address whose suites are predominantly `PMB`
  as `cmra` and do not credit a PMB match.
* **Care-of addresses** - `street_key` beginning `C O` (an accountant, a law
  firm, a trustee). The occupants are unrelated by construction.
* **Bank trust departments** - for example `10 S DEARBORN IL1 0111 60603`,
  1,190 records. The shape is identical to a sponsor; the giveaway is the
  mail-code pseudo-suite.
* **General delivery, APO/FPO**, and the single-building-per-ZIP cases where a
  ZIP exists to serve one organisation.

## 7. What only matchdb can do

* **Occupant churn across vintages.** matchdb holds BMF vintages; npmatch sees
  one. An address whose occupant set turns over every year is an agent's
  address; one stable for a decade is a building. Not computable at run time at
  all.
* **Group-ruling structure.** `group_exemption_number` and `affiliation_code`
  are already imported for review (`np_bmf_review_fields()`) but are not used
  to characterize an address. "90% of the records here share one group
  exemption" settles the federated case without touching names.
* **Geocode-based building ids.** `bmf_unified_geocoded` carries coordinates.
  Clustering rooftop-precision points would unify `127 FILMORE LN`,
  `127 FILLMORE LANE` and `127 FILMORE LN STE 320` into one building id - a
  stronger key than string equality, and the only way to catch one building
  spelled two ways. Restrict it to rooftop or parcel precision; a ZIP centroid
  would merge a whole town.

## 8. Does preprocessing on the matchdb side benefit npmatch?

Yes, for three distinct reasons, in order of weight:

1. **It enables a signal npmatch cannot compute.** The federated-versus-sponsor
   distinction, group-ruling structure and vintage churn need the full database
   and its history. Without them npmatch has counts and no way to read them,
   which is why the current gate is deliberately crude.
2. **It removes a correctness footgun.** Counts must come from the whole
   corpus; `np_compare(addr_freq = NULL)` computing them from whatever frame it
   was handed is correct only when that frame is the entire reference. A
   signature-stamped table that refuses to load against the wrong normalizer
   makes the invariant structural rather than documented.
3. **It is cheaper.** About 139k rows shipped instead of 1.2M rebuilt per
   process.

The integration point already exists: `np_compare(addr_freq = )` takes the
object `np_addr_freq()` returns, so matchdb only has to produce that shape, or
npmatch gains a small `np_addr_freq_from_table()` constructor. Nothing in the
scoring path changes.

The cost is one more versioned artifact that can go stale against the
normalizer - the same cost the cached `name_key` already carries, with the same
mitigation.

## 9. What npmatch should change to consume it

Follow-ups on this side, in order:

1. Gate the multi-tenant credit on `unit_coverage`, not just `addr_units >= 2`
   (section 5).
2. **Damp the street credit at low-discrimination addresses.** `street_hit`
   currently pays the full 0.95 geo weight at `3700 GRAND AVE`, where 5,965
   records share one address *and* one name. An address that matches every
   candidate equally is not evidence, and `top_name_share` is exactly the
   number that says so. This is probably worth more recall than the suite work
   itself.
3. Let `addr_class` reach the reviewer verbatim, so a packet can say "fiscal
   sponsor address, 1,933 unrelated organisations" instead of "12 records share
   this address and suite".
4. Teach `np_addr_freq()` to read a matchdb table and verify the signature.
