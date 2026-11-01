<div id="main" class="col-md-9" role="main">

# Flag which reference EINs are active

<div class="ref-description section level2">

Convenience for the unified (active + inactive) BMF: sets the `active`
column to `TRUE` for EINs present in `active_eins`, `FALSE` otherwise,
so matches carry the flag through to the result. Use when you loaded the
unified BMF but only have the active EIN set separately.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_flag_active(reference, active_eins)
```

</div>

</div>

<div class="section level2">

## Arguments

-   reference:

    An `np_reference` (or a data frame with an `.ein`/`ein` key).

-   active_eins:

    Character vector of EINs in the active BMF.

</div>

<div class="section level2">

## Value

`reference` with a logical `active` column.

</div>

</div>
