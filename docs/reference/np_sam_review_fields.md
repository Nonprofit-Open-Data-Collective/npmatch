# SAM context fields for the review queue

Builds descriptive fields imported from the SAM / USASpending source
record, `SAM_`-prefixed so they read as distinct from the derived `_uss`
fields. Handles either the uppercase-spaced or lowercase-underscore SAM
column conventions. The business-type string is tidied into one boolean
per observed type (`SAM_bus_type_<label>`), and `entity_structure` gains
a decoded label.

## Usage

``` r
np_sam_review_fields(sam)
```

## Arguments

- sam:

  The raw SAM data frame.

## Value

A data frame keyed by `uei` with `SAM_`-prefixed context fields.

## Details

Note: SAM's org-size metrics (the "SAM Numerics" employee/receipt codes)
are not present in the V2 public monthly extract, so no size field is
derived here; use the BMF `BMF_assets` / `BMF_revenue` as the size
proxy.
