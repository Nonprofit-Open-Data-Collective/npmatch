# Filter a SAM extract to nonprofits

Keeps SAM registrations whose business-type string carries a nonprofit
code (`A8` Non-Profit, `BZ` Foundation, `2U` Other Not-For-Profit, `A7`
AbilityOne) — the definition used to build the worked example (see
`dev/prototype/IDENTIFY-NONPROFITS.R`).

## Usage

``` r
np_flag_nonprofits(
  sam,
  codes = c("A8", "BZ", "2U", "A7"),
  bus_type_col = NULL,
  keep = TRUE
)
```

## Arguments

- sam:

  A SAM data frame (with a business-type-string column), or a path to a
  raw `.dat` (read via
  [`np_read_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_read_sam.md)).

- codes:

  Nonprofit business-type codes to keep.

- bus_type_col:

  Business-type-string column. Auto-detected from `"BUS TYPE STRING"` /
  `"bus_type_string"` if `NULL`.

- keep:

  If `TRUE` (default) return only nonprofit rows; if `FALSE` return all
  rows with an added logical `is_nonprofit` column.

## Value

The filtered (or flagged) data frame.
