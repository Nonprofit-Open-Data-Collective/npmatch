# Geographic profiles

npmatch adapts blocking, comparison, and weighting to the geographic
detail available in the *query* dataset. A profile is an ordered set of
geo fields; `np_geo_profiles()` lists the ones npmatch recognises,
weakest to strongest. State is the minimum (and the default blocking
key); richer profiles add comparison fields and shift weight away from
the name.

## Usage

``` r
np_geo_profiles()
```

## Value

A named list; each element is the character vector of geo fields that
defines that profile.
