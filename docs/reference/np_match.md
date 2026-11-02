# Run the full linkage pipeline

Convenience wrapper chaining normalize -\> compare -\> score -\> veto
-\> select -\> tier. Intermediate objects are attached as attributes for
inspection.

## Usage

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

## Arguments

- query:

  A raw query data frame, or an `np_query` from
  [`np_query()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_query.md).

- reference:

  A raw reference data frame, or an `np_reference`.

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md).

- method:

  Scoring method for
  [`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md).

- model:

  A fitted
  [`np_train()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_train.md)
  model, required when `method = "model"`.

- block, profile, candidates:

  Passed to
  [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md);
  supply `candidates` from
  [`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
  for the scalable name-token blocking path.

- query_map, reference_map:

  Schema maps used only if `query`/`reference` are raw data frames.

## Value

An `np_tiered` result. The scored candidate pairs are attached as
`attr(result, "pairs")`.
