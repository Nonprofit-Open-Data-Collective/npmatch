# Area under the ROC curve (Mann-Whitney form)

Area under the ROC curve (Mann-Whitney form)

## Usage

``` r
np_auc(score, label)
```

## Arguments

- score:

  Numeric predicted scores.

- label:

  Truth: logical / 0-1 / "TRUE"/"FALSE".

## Value

Scalar AUC, or `NA` if a class is absent.
