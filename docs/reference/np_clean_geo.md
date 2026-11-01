<div id="main" class="col-md-9" role="main">

# Clean and standardize city and state fields

<div class="ref-description section level2">

Normalizes `city` and `state` in place. Two engines:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_clean_geo(
  data,
  engine = c("rules", "campfin"),
  aliases = np_city_aliases(),
  zip_ref = NULL,
  max_dist = 2
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   data:

    A data frame with `city` / `state` (and `zip5` for `zip_ref`).

-   engine:

    `"rules"` or `"campfin"`.

-   aliases:

    Whole-name city alias map (see `np_city_aliases()`).

-   zip_ref:

    Optional `zip5`-keyed crosswalk for misspelling correction.

-   max_dist:

    Max edit distance to treat a city as a correctable near-miss.

</div>

<div class="section level2">

## Value

`data` with `city` / `state` cleaned in place.

</div>

<div class="section level2">

## Details

-   `"rules"` (default, no dependency) — upper-case and squish, expand
    the common abbreviated prefixes (`ST`->`SAINT`, `FT`->`FORT`,
    `MT`->`MOUNT`), apply whole-name city aliases
    (`NYC`->`NEW YORK CITY`), and coerce `state` to a two-letter code.

-   `"campfin"` — delegate city/state normalization to the `campfin`
    package (`normal_city()` / `normal_state()`), which validate against
    USPS and Census place lists (expanding abbreviations, stripping
    trailing state tokens, and nulling known-invalid entries). The alias
    map is still applied on top.

Correcting arbitrary *misspellings* (e.g. "PHOENex" -> "PHOENIX") needs
a reference of valid place names. Supply `zip_ref` (a `zip5`-keyed
crosswalk with a city column, e.g. from `np_load_zipcode_db()`): a
missing city is filled from its ZIP, and a near-miss (edit distance \<=
`max_dist`) is snapped to the ZIP's canonical city.

</div>

</div>
