<div id="main" class="col-md-9" role="main">

# Run the full linkage pipeline

<div class="ref-description section level2">

Convenience wrapper chaining normalize -> compare -> score -> veto ->
select -> tier. Intermediate objects are attached as attributes for
inspection.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_match(
  query,
  reference,
  config = np_config(),
  method = "weighted",
  model = NULL,
  block = "state",
  profile = NULL,
  candidates = NULL,
  query_map = np_map_sam(),
  reference_map = np_map_bmf()
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   query:

    A raw query data frame, or an `np_query` from `np_query()`.

-   reference:

    A raw reference data frame, or an `np_reference`.

-   config:

    An `np_config()`.

-   method:

    Scoring method for `np_score()`.

-   model:

    A fitted `np_train()` model, required when `method = "model"`.

-   block, profile, candidates:

    Passed to `np_compare()`; supply `candidates` from `np_block()` for
    the scalable name-token blocking path.

-   query_map, reference_map:

    Schema maps used only if `query`/`reference` are raw data frames.

</div>

<div class="section level2">

## Value

An `np_tiered` result. The scored candidate pairs are attached as
`attr(result, "pairs")`.

</div>

</div>
