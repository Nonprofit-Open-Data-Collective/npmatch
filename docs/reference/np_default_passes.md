<div id="main" class="col-md-9" role="main">

# Default progressive blocking passes

<div class="ref-description section level2">

The tight-to-loose blocking cascade used by `np_cascade()`. Each pass is
a list with a `name`, a human-readable `desc` (the decision criterion,
shown in the stage report), and `args` passed to `np_block()`. Earlier
passes are cheap and high-precision; later passes are looser and only
run on the residual (queries not yet auto-accepted).

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_default_passes()
```

</div>

</div>

<div class="section level2">

## Value

A list of pass specifications.

</div>

<div class="section level2">

## Details

The first tier is four **exact** passes that exploit both the legal name
and the DBA on each side (name==name, name==dba, dba==name, dba==dba),
then name-token blocking within state, then a cross-state token pass for
the firm-vs-establishment case.

</div>

</div>
