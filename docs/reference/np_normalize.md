# Normalize a query or reference frame

Brings entity names and addresses onto a common, matchable form (parity
with the BMF `org_name_join` field) and extracts the token-level
features the veto layer needs. Adds columns alongside the canonical
ones:

## Usage

``` r
np_normalize(data)
```

## Arguments

- data:

  An `np_query` or `np_reference` frame from
  [`np_query()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_query.md)
  /
  [`np_reference()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_reference.md).

## Value

The same frame with the normalization columns added.

## Details

- `name_key` cleaned, abbreviation-standardized, legal-suffix-stripped

- `dba_key` the DBA name under the same normalization (for
  cross-matching)

- `name_full` cleaned name *with* suffix retained

- `name_form` detected legal form (INC / LLC / CORP / ...), or `NA`

- `name_gen`, `name_gen_rank` **vestigial** — a person-name generation
  marker (`JR` / `SR`, ranked `SR` = 1, `JR` = 2) inherited from
  npmatch's person-matching lineage. Organisations do not have
  generations; nothing in the package consumes these and they are not
  useful features. Retained only for column compatibility with existing
  labeled extracts. See
  [`np_default_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_rules.md).

- `name_nums` space-joined embedded digit tokens (chapter/local numbers)

- `name_ord` canonical ordinal rank(s) found in the name

- `street_key` USPS-standardized street with unit stripped

- `street_num` leading house / box number

- `street_name` street body with the number, type, and unit removed

- `street_type` trailing street type (ST / AVE / BLVD / WAY / ...), or
  `NA`

- `street_unit` extracted suite/unit/apt number, if any

- `is_po_box` `TRUE` if the street is a PO box (any variant), else
  `FALSE`

- `zip5` five-digit ZIP, leading zeros restored (nested prefix)

- `zip3` three-digit ZIP prefix / SCF region (nested prefix)

- `zip9` full `xxxxx-xxxx` ZIP when the +4 is known, else `NA`

The ZIP match hierarchy is the nested prefix family `zip3` \\\subset\\
`zip5` \\\subset\\ `zip9`. The +4 add-on (`zip_plus4`) is an input only,
consumed to build `zip9`; it is not a standalone level.

- `state_abb` two-letter state code (mapped from a full state name if
  given)
