# Default progressive blocking passes

The tight-to-loose blocking cascade used by
[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md).
Each pass is a list with a `name`, a human-readable `desc` (the decision
criterion, shown in the stage report), and `args` passed to
[`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md).
Earlier passes are cheap and high-precision; later passes are looser and
only run on the residual (queries not yet auto-accepted).

## Usage

``` r
np_default_passes()
```

## Value

A list of pass specifications.

## Details

The first tier is four **exact** passes that exploit both the legal name
and the DBA on each side (name==name, name==dba, dba==name, dba==dba),
then name-token blocking within state, then a cross-state token pass for
the firm-vs-establishment case.
