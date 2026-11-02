# Default BMF context fields for the review queue

Builds the small set of IRS-BMF descriptive fields worth showing a human
reviewer next to each candidate: what kind of nonprofit it is and how
big. Pass the raw processed BMF and join the result onto a review frame
by `ein` (this is what `np_route(bmf = ...)` does automatically).

## Usage

``` r
np_bmf_review_fields(bmf)
```

## Arguments

- bmf:

  The raw processed BMF data frame.

## Value

A data frame keyed by `ein` with `BMF_`-prefixed context fields.

## Details

Derived / imported fields:

- `ntee_clean`, `nteev2` — cleaned NTEE code and NTEEv2 classification

- `subsection` — 501(c) subsection number (3 = 501(c)(3), ...)

- `is_foundation` — TRUE for private (operating or non-operating)
  foundations

- `rule_year` — year of the IRS ruling (exemption) date

- `assets`, `revenue` — reported asset / revenue amounts

- `form_990` — filing requirement: 990PF / 990N / 990-EZ/990 / none /
  group

- `affiliation_code`, `affiliation_code_definition` —
  central/subordinate status

- `group_exemption_number`, `group_exemption_is_member` — group-ruling
  membership

Imported columns are prefixed `BMF_` (capitalized source prefix) so they
read as distinct from the pipeline's derived `_bmf` matching fields.
