# npmatch: a tiered workflow for organization record linkage

npmatch manages the steps of matching organization records to a
reference database when no shared identifier exists. The steps are
generic; the nonprofit case the package ships wired for — federal
registrants (SAM) to the IRS Business Master File — is one deployment of
the framework, not a requirement of it.

## Details

Six tiers, each a separable concern:

1.  **Alias enumeration** — every name and address an entity is known
    by. Supplied by matchdb: pass the object its `md_compile()` or
    `md_reference()` returns straight to
    [`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
    as `reference`.

2.  **Input standardization** —
    [`np_query()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_query.md)
    /
    [`np_reference()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_reference.md)
    map any dataset onto the canonical fields, then
    [`np_normalize()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_normalize.html)
    (from npnormalize, re-exported here) builds the name and address
    keys.

3.  **Data pre-prep** — the corpus statistics that make a token or an
    address informative:
    [`np_ref_index()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_ref_index.md),
    [`np_token_idf()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_token_idf.html),
    [`np_name_freq()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_name_freq.html),
    [`np_addr_freq()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_addr_freq.html).
    Computed once over the whole reference, or taken precomputed from a
    matchdb reference.

4.  **Candidate generation** —
    [`np_block()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block.md)
    /
    [`np_block_union()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_block_union.md)
    keep the pair set tractable;
    [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
    scores each field, over reclin2.

5.  **Tiered adjudication** —
    [`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
    combines the fields,
    [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
    applies hard and soft do-not-match rules,
    [`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
    picks the best candidate per query,
    [`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
    sorts into YES / MAYBE / NO.

6.  **Packaging for review** —
    [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
    emits the accepted crosswalk, the candidate-level review queue and
    the unmatched set;
    [`np_label_frame()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label_frame.md)
    emits training data and
    [`np_as_prompt()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_as_prompt.md)
    LLM prompts.

[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
runs tiers 2–5 as progressive blocking passes (the scalable path) and
[`np_match()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_match.md)
in a single pass;
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
then does tier 6 on the result.
[`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md)
chunks a large source over
[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
and routes each chunk, and the stage drivers
([`np_stage1_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage1_run.md)
and its siblings) wrap the whole thing in an on-disk run project.

## See also

Useful links:

- <https://github.com/Nonprofit-Open-Data-Collective/npmatch>

- <https://nonprofit-open-data-collective.github.io/npmatch/>

- Report bugs at
  <https://github.com/Nonprofit-Open-Data-Collective/npmatch/issues>

## Author

**Maintainer**: Jesse Lecy <jdlecy@gmail.com>
