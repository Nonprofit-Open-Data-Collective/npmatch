# Split a data frame into batches

Partitions the rows of a data frame into evenly sized batches for
chunked processing (e.g. feeding a large source through
[`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md)
a chunk at a time). Rows are shuffled first (deterministically, given
`seed`) so each batch is a representative slice rather than an accident
of source ordering.

## Usage

``` r
np_batch(x, size = 2500L, n = NULL, shuffle = TRUE, seed = NULL)
```

## Arguments

- x:

  A data frame.

- size:

  Target rows per batch. Ignored if `n` is supplied. Default 2500 — at
  the observed ~8% review rate this yields ~200 review cases per batch,
  one LLM-validation pass.

- n:

  Number of batches. Overrides `size` when given.

- shuffle:

  Shuffle rows before splitting. Default `TRUE`.

- seed:

  Optional RNG seed for reproducible shuffling. The global RNG state is
  saved and restored, so callers are unaffected.

## Value

A list of data frames (the batches), with attribute `n_batches`. An
empty input returns an empty list.

## Details

Batches are made **as even as possible**: with `size`, the number of
batches is `ceiling(nrow / size)` and each batch holds
`nrow / n_batches` rows (so a batch is never larger than `size`, and
there is no tiny remainder batch); with `n`, the rows are split into
exactly `n` near-equal batches.

## Examples

``` r
b <- np_batch(mtcars, size = 10, seed = 1)
length(b); vapply(b, nrow, integer(1))
#> [1] 4
#> [1] 8 8 8 8
```
