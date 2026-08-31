# Score candidate pairs

Collapses the per-field similarities of an
[`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
result into a single `score` in \[0, 1\]. Three methods are provided so
the "best" combiner can be chosen empirically against a labelled
training set:

## Usage

``` r
np_score(
  pairs,
  config = np_config(),
  method = c("weighted", "hier", "em", "model"),
  model = NULL
)
```

## Arguments

- pairs:

  An `np_pairs` frame from
  [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md).

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md).

- method:

  One of `"weighted"`, `"em"`, `"model"`.

- model:

  A fitted model with a
  [`predict()`](https://rdrr.io/r/stats/predict.html) method, required
  for `method = "model"`. Must accept a data frame of the similarity
  columns.

## Value

`pairs` with a numeric `score` column added (and method raw output).

## Details

- `"weighted"` — normalized weighted sum using the profile weights in
  `config`. Transparent, no training required. The default.

- `"hier"` — name similarity plus a *hierarchical* geo sub-score that
  takes the strongest confirmed location granularity (ZIP+4 \> street \>
  ZIP5 \> PO boxZIP3 \> city \> state) via a max, not a sum. Correlated
  address fields arenot double-counted, and a wrong city cannot pull
  down a ZIP-confirmed match.Degrades gracefully as geo fields go
  missing. See np_default_geo_weights().

- `"em"` — unsupervised Fellegi-Sunter weights via
  [`reclin2::problink_em()`](https://rdrr.io/pkg/reclin2/man/problink_em.html);
  `score` is the match posterior. Learns weights from the data.

- `"model"` — apply a fitted classifier (`glm`, `ranger`, `xgboost`,
  ...) supplied in `model` to the per-field similarity columns; `score`
  is its predicted match probability. This is the hook for supervised
  optimization.

The chosen method's raw output is retained (`weight_em`, `p_model`) so
methods can be compared side by side before one is adopted.
