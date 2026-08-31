# Name-key frequency table for a reference corpus

Counts how many reference records share each exact `name_key`. A name
that occurs once or twice is distinctive (an exact match to it is
trustworthy even without address corroboration); a name shared by many
records (e.g. "FIRST BAPTIST CHURCH") is not. Used by the
distinctive-exact-name promotion in `np_score(method = "hier")`. This is
more robust than summed token IDF, which conflates distinctiveness with
name length.

## Usage

``` r
np_name_freq(name_keys)
```

## Arguments

- name_keys:

  Character vector of normalized names (reference `name_key`).

## Value

A named integer vector mapping `name_key` -\> record count.
