<div id="main" class="col-md-9" role="main">

# Precompute the reference-side token index for blocking

<div class="ref-description section level2">

Tokenizes the reference `token_col` (default `name_key`) once — the
inverted index plus per-token document frequency that `np_block()`
otherwise rebuilds on every token pass. Pass the result to `np_block()`
/ `np_cascade()` / `np_run_batches()` via `ref_index =` to skip
re-tokenizing a large reference on every pass and every batch. The
blocking results are identical either way.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_ref_index(
  reference,
  token_col = "name_key",
  stopwords = np_stopwords(),
  min_token_len = 2L
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   reference:

    A normalized `np_reference` (from `np_normalize()`).

-   token_col:

    Column to tokenize. Default `"name_key"`.

-   stopwords:

    Tokens to drop (see `np_stopwords()`).

-   min_token_len:

    Minimum token length to index. Default 2.

</div>

<div class="section level2">

## Value

An `np_ref_index` object. It is only reused by `np_block()` when
`token_col`, `stopwords`, and `min_token_len` match the block call.

</div>

<div class="section level2">

## Details

Both base tokens and adjacent-token concatenations (the
`concat_adjacent` bigrams) are indexed, so one index serves passes with
or without `concat_adjacent`.

</div>

</div>
