# Flag which reference EINs are active

Convenience for the unified (active + inactive) BMF: sets the `active`
column to `TRUE` for EINs present in `active_eins`, `FALSE` otherwise,
so matches carry the flag through to the result. Use when you loaded the
unified BMF but only have the active EIN set separately.

## Usage

``` r
np_flag_active(reference, active_eins)
```

## Arguments

- reference:

  An `np_reference` (or a data frame with an `.ein`/`ein` key).

- active_eins:

  Character vector of EINs in the active BMF.

## Value

`reference` with a logical `active` column.
