<div id="main" class="col-md-9" role="main">

# Detect the geographic profile of a query frame

<div class="ref-description section level2">

Inspects which geo fields are usably populated and returns the richest
`np_geo_profiles()` entry all of whose fields clear `min_coverage`. This
drives the "optimal approach is conditional on the geography available"
decision: blocking key, comparison fields, and weight vector all follow
from the detected profile.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_detect_geo(query, min_coverage = 0.5)
```

</div>

</div>

<div class="section level2">

## Arguments

-   query:

    An `np_query` frame (normalized or not).

-   min_coverage:

    Minimum non-missing fraction for a field to count as available.
    Default 0.5.

</div>

<div class="section level2">

## Value

A length-one character naming the detected profile, with attributes
`coverage` (per-field non-missing fraction) and `fields`.

</div>

</div>
