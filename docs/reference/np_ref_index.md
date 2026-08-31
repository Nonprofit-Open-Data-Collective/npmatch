# Precompute the reference-side token index for blocking

Tokenizes the reference `token_col` (default `name_key`) once — the
inverted index plus per-token document frequency that
[`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
otherwise rebuilds on every token pass. Pass the result to
[`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
/
[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
/
[`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md)
via `ref_index =` to skip re-tokenizing a large reference on every pass
and every batch. The blocking results are identical either way.

## Usage

``` r
np_ref_index(
  reference,
  token_col = "name_key",
  stopwords = np_stopwords(),
  min_token_len = 2L
)
```

## Arguments

- reference:

  A normalized `np_reference` (from
  [`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md)).

- token_col:

  Column to tokenize. Default `"name_key"`.

- stopwords:

  Tokens to drop (see
  [`np_stopwords()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stopwords.md)).

- min_token_len:

  Minimum token length to index. Default 2.

## Value

An `np_ref_index` object. It is only reused by
[`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
when `token_col`, `stopwords`, and `min_token_len` match the block call.

## Details

Both base tokens and adjacent-token concatenations (the
`concat_adjacent` bigrams) are indexed, so one index serves passes with
or without `concat_adjacent`.
