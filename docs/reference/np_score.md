<div id="main" class="col-md-9" role="main">

# Score candidate pairs

<div class="ref-description section level2">

Collapses the per-field similarities of an `np_compare()` result into a
single `score` in \[0, 1\]. Three methods are provided so the "best"
combiner can be chosen empirically against a labelled training set:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_score(
  pairs,
  config = np_config(),
  method = c("weighted", "hier", "em", "model"),
  model = NULL
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    An `np_pairs` frame from `np_compare()`.

-   config:

    An `np_config()`.

-   method:

    One of `"weighted"`, `"em"`, `"model"`.

-   model:

    A fitted model with a `predict()` method, required for
    `method = "model"`. Must accept a data frame of the similarity
    columns.

</div>

<div class="section level2">

## Value

`pairs` with a numeric `score` column added (and method raw output).

</div>

<div class="section level2">

## Details

-   `"weighted"` — normalized weighted sum using the profile weights in
    `config`. Transparent, no training required. The default.

-   `"hier"` — name similarity plus a *hierarchical* geo sub-score that
    takes the strongest confirmed location granularity (ZIP+4 > street >
    ZIP5 > PO boxZIP3 > city > state) via a max, not a sum. Correlated
    address fields arenot double-counted, and a wrong city cannot pull
    down a ZIP-confirmed match.Degrades gracefully as geo fields go
    missing. See np_default_geo_weights().

-   `"em"` — unsupervised Fellegi-Sunter weights via
    `reclin2::problink_em()`; `score` is the match posterior. Learns
    weights from the data.

-   `"model"` — apply a fitted classifier (`glm`, `ranger`, `xgboost`,
    ...) supplied in `model` to the per-field similarity columns;
    `score` is its predicted match probability. This is the hook for
    supervised optimization.

The chosen method's raw output is retained (`weight_em`, `p_model`) so
methods can be compared side by side before one is adopted.

</div>

</div>
