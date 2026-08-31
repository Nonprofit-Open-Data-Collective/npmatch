# Generate candidate pairs by blocking

Produces the (query, reference) candidate pairs worth comparing, so
[`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
never has to score every same-state pair. Three modes:

## Usage

``` r
np_block(
  query,
  reference,
  by = "state",
  by_x = NULL,
  by_y = NULL,
  token = TRUE,
  token_col = "name_key",
  stopwords = np_stopwords(),
  min_token_len = 2L,
  max_ref_freq = NULL,
  min_pair_idf = NULL,
  concat_adjacent = FALSE,
  ref_index = NULL
)
```

## Arguments

- query, reference:

  Normalized `np_query` / `np_reference` frames.

- by:

  Character vector of exact-match block columns, or `NULL`. Applied to
  both sides unless `by_x` / `by_y` override.

- by_x, by_y:

  Per-side block columns for cross-column matching (e.g.
  `by_x = c("state","name_key")`, `by_y = c("state","dba_key")` pairs a
  query name against a reference DBA). Default to `by`. Columns are
  matched position-for-position, so the two must be the same length.

- token:

  If `TRUE` (default), also require a shared `token_col` token.

- token_col:

  Column to tokenize. Default `"name_key"`.

- stopwords:

  Tokens to drop (see
  [`np_stopwords()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stopwords.md)).

- min_token_len:

  Minimum token length to index. Default 2.

- max_ref_freq:

  Optional: drop tokens occurring in more than this many reference
  records (kills corpus-common words). `NULL` = stopwords only.

- min_pair_idf:

  Optional IDF-weighted pruning. A single common token (e.g.
  "CALIFORNIA", "CHURCH") should not by itself justify a candidate pair,
  but a global `max_ref_freq` can't see that such a token is
  concentrated within one block (state). With `min_pair_idf` set, each
  shared token is weighted by its inverse document frequency
  `log(N_ref / df)` and a pair is kept only when the sum of its shared
  tokens' IDF is at least this value. One rare token, or several
  moderately common ones, clears the bar; a lone common token does not.
  `NULL` (default) disables this. Only used when `token`.

- concat_adjacent:

  If `TRUE`, also index the concatenation of each adjacent pair of
  (post-stopword) tokens as an extra token. This recovers de-spacing
  differences symmetrically: "STEP FORWARD" emits the compound
  "STEPFORWARD" which matches a reference already spelled "STEPFORWARD",
  and vice versa. The compounds are rare (high IDF), so with
  `min_pair_idf` set they only justify a pair when genuinely shared.
  Default `FALSE`. Only used when `token`.

- ref_index:

  Optional precomputed
  [`np_ref_index()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ref_index.md)
  for the reference's token index + document frequency. When supplied
  (and compatible with `token_col` / `stopwords` / `min_token_len`), the
  reference is not re-tokenized — the same candidate pairs are produced
  far faster on repeated calls (across passes and batches). Only used
  when `token`.

## Value

A data frame of candidate pairs with integer columns `.x` (query row)
and `.y` (reference row), class `np_blocks`.

## Details

- **exact** (`token = FALSE`) — pairs that match exactly on all `by`
  columns (a hash join). E.g. `by = "state"` or
  `by = c("state", "zip5")`.

- **token** (`token = TRUE`, default) — pairs that share the exact `by`
  key **and** at least one distinctive token of `token_col` (a
  name-token inverted index). This is what makes blocking scale: "ALASKA
  X" is only paired with same-state orgs that share a rare token, not
  all ~40k orgs in the state.

- **token, cross-key** (`by = NULL`, `token = TRUE`) — shared token
  only, no exact key. The loose recall-recovery pass (finds a same-name
  org in another state — the firm-vs-establishment case).

Both frames must be normalized
([`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md)).
Combine passes by `rbind`-ing results and de-duplicating (see
[`np_block_union()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block_union.md)).
