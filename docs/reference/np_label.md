<div id="main" class="col-md-9" role="main">

# Attach labels to candidate pairs

<div class="ref-description section level2">

Joins a labelled review sheet (as filled in from `np_label_frame()`)
back onto an `np_pairs` object by `(.id, .ein)`, adding a `label`
column. Unlabelled pairs get `NA`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_label(pairs, labels)
```

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    An `np_pairs` frame.

-   labels:

    A data frame with columns `.id`, `.ein`, and `label`.

</div>

<div class="section level2">

## Value

`pairs` with a `label` column (attributes preserved).

</div>

</div>
