# Default location-granularity credits

The evidence weight for confirming two records share a location at each
granularity, used by the hierarchical geo score. The score takes the
*maximum* applicable term ("how precisely is the location confirmed"),
so correlated fields are never double-counted and a redundant noisy
field (e.g. a wrong city when the ZIP already matches) cannot lower the
score.

## Usage

``` r
np_default_geo_weights()
```

## Value

A named numeric vector.

## Details

Ordered strongest to weakest: full ZIP+4 (`zip9`), same street (`street`
= number + body), 5-digit ZIP, matching PO box, 3-digit ZIP (SCF
region), city, state.
