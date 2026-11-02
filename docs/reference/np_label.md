# Attach labels to candidate pairs

Joins a labelled review sheet (as filled in from
[`np_label_frame()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label_frame.md))
back onto an `np_pairs` object by `(.id, .ein)`, adding a `label`
column. Unlabelled pairs get `NA`.

## Usage

``` r
np_label(pairs, labels)
```

## Arguments

- pairs:

  An `np_pairs` frame.

- labels:

  A data frame with columns `.id`, `.ein`, and `label`.

## Value

`pairs` with a `label` column (attributes preserved).
