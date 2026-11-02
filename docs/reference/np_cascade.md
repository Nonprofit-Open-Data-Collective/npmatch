# Match with a progressive blocking cascade

Runs
[`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
-\>
[`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
-\>
[`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
-\>
[`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
pass by pass, tight to loose. After each pass, queries that reached the
YES tier are removed from the pending set, so each successive (more
expensive) pass only processes the harder residual. Candidate pairs are
scored once; the final
[`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
/
[`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
run over the de-duplicated union, so a match found by a looser pass
still competes on equal footing (and the runner-up margin is computed
across all of a query's candidates).

## Usage

``` r
np_cascade(
  query,
  reference,
  config = np_config(),
  method = "hier",
  passes = np_default_passes(),
  verbose = TRUE,
  query_map = np_map_sam(),
  reference_map = np_map_bmf(),
  name_freq = NULL,
  token_idf = NULL,
  ref_index = NULL,
  addr_freq = NULL
)
```

## Arguments

- query:

  Raw data frame or `np_query`.

- reference:

  Raw data frame, `np_reference`, or a matchdb reference: the list that
  `matchdb::md_compile()` or `matchdb::md_reference()` returns. From a
  matchdb reference, npmatch takes the frame and whichever of
  `name_freq`, `token_idf`, `ref_index` and `addr_freq` it carries;
  arguments you pass explicitly take precedence. It is refused if its
  normalizer signature differs from the installed one. matchdb itself is
  not needed.

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md).

- method:

  Scoring method for
  [`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
  (default `"hier"`).

- passes:

  A list of pass specs (see
  [`np_default_passes()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_default_passes.md)).

- verbose:

  Print the per-stage report. Default `TRUE`.

- query_map, reference_map:

  Schema maps for raw inputs.

- name_freq, token_idf:

  Optional pre-computed reference tables from
  [`np_name_freq()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_name_freq.html)
  /
  [`np_token_idf()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_token_idf.html).
  Supply them (together with an already-normalized `reference`) to reuse
  a one-time normalization across many calls — e.g. from a batched
  driver
  ([`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md)).
  Computed from the reference when `NULL`.

- ref_index:

  Optional precomputed
  [`np_ref_index()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ref_index.md)
  blocking index. Built once from the reference when `NULL` and reused
  across every pass (and, via
  [`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md),
  every batch), so a large reference is tokenized once rather than per
  pass.

- addr_freq:

  Optional precomputed
  [`np_addr_freq()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_addr_freq.html)
  table: how many reference records share each address and suite, and
  what kind of place each shared address is. Counted over the whole
  reference when `NULL`. Pass one counted over the full reference when
  `reference` is only part of it (one state, say), so crowded addresses
  are not under-counted.

## Value

An `np_tiered` result with a `pass` column recording which pass produced
each query's chosen match. A per-stage summary is attached as
`attr(result, "stages")`; the scored candidate union as
`attr(result, "pairs")`.

## Details

With `verbose = TRUE` it reports the scoring method and decision
criteria once, then per stage: candidates generated, YES / MAYBE / NO
found, how many were resolved, how many remain pending, and the median
YES margin.
