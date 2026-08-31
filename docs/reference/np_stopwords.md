# Blocking stopwords

Non-discriminating legal/filler tokens dropped from name-token blocking
so blocks stay small and precise. Deliberately conservative (legal forms
and function words only) — rely on `max_ref_freq` in
[`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
to prune the remaining corpus-common words data-drivenly rather than
hard-coding them.

## Usage

``` r
np_stopwords()
```

## Value

A character vector of uppercase stopwords.
