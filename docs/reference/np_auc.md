<div id="main" class="col-md-9" role="main">

# Area under the ROC curve (Mann-Whitney form)

<div class="ref-description section level2">

Area under the ROC curve (Mann-Whitney form)

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_auc(score, label)
```

</div>

</div>

<div class="section level2">

## Arguments

-   score:

    Numeric predicted scores.

-   label:

    Truth: logical / 0-1 / "TRUE"/"FALSE".

</div>

<div class="section level2">

## Value

Scalar AUC, or `NA` if a class is absent.

</div>

</div>
