# Augment records with ZIP-level geography

Left-joins a ZIP-keyed crosswalk onto `data`, adding whatever columns it
carries (county, CBSA/metro name, RUCA code, urban/rural flag, ...).
npmatch ships no crosswalk data; you supply one built from a standard
source and load it yourself:

## Usage

``` r
np_augment_geo(data, crosswalk, by = "zip5", cols = NULL)
```

## Arguments

- data:

  A data frame with a ZIP key column (default `zip5`).

- crosswalk:

  A data frame keyed by the same column.

- by:

  The join key column name present in both. Default `"zip5"`.

- cols:

  Columns from `crosswalk` to add; default all non-key columns.

## Value

`data` with the crosswalk columns joined on.

## Details

- **county / CBSA (metro):** HUD USPS ZIP Crosswalk (ZIP-\>CBSA,
  ZIP-\>county) or the `zipcodeR` package's `zip_code_db`.

- **urban / rural:** USDA ERS ZIP-code RUCA codes (then
  [`np_ruca_urban()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ruca_urban.md)).

The crosswalk must have a `zip5` (or `by`) key column; all other columns
are added to `data`. Join first on the record's own `zip5` from
[`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# from the zipcodeR package
xwalk <- zipcodeR::zip_code_db[, c("zipcode", "county", "state")]
names(xwalk)[1] <- "zip5"
records <- np_augment_geo(records, xwalk)
} # }
```
