# Detect the geographic profile of a query frame

Inspects which geo fields are usably populated and returns the richest
[`np_geo_profiles()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_geo_profiles.md)
entry all of whose fields clear `min_coverage`. This drives the "optimal
approach is conditional on the geography available" decision: blocking
key, comparison fields, and weight vector all follow from the detected
profile.

## Usage

``` r
np_detect_geo(query, min_coverage = 0.5)
```

## Arguments

- query:

  An `np_query` frame (normalized or not).

- min_coverage:

  Minimum non-missing fraction for a field to count as available.
  Default 0.5.

## Value

A length-one character naming the detected profile, with attributes
`coverage` (per-field non-missing fraction) and `fields`.
