<div id="main" class="col-md-9" role="main">

# Default location-granularity credits

<div class="ref-description section level2">

The evidence weight for confirming two records share a location at each
granularity, used by the hierarchical geo score. The score takes the
*maximum* applicable term ("how precisely is the location confirmed"),
so correlated fields are never double-counted and a redundant noisy
field (e.g. a wrong city when the ZIP already matches) cannot lower the
score.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_default_geo_weights()
```

</div>

</div>

<div class="section level2">

## Value

A named numeric vector.

</div>

<div class="section level2">

## Details

Ordered strongest to weakest: full ZIP+4 (`zip9`), same street and suite
(`unit`), same street (`street` = number + body), 5-digit ZIP, matching
PO box, 3-digit ZIP (SCF region), city, state.

`unit` sits just above `street` and below `zip9`: a confirmed suite in a
multi-tenant building is a more precise location than the street alone,
but it is not claimed to beat a full ZIP+4. It is credited only where
the suite is informative — see `np_addr_freq()` — and, because the terms
combine with `max()`, never subtracts when a suite is absent, differing,
or shared by a crowd. A weight vector without `unit` (one saved before
this existed) falls back to 0.97.

</div>

</div>
