# Merge adjudication decisions onto a review frame

Joins the query-level YES/NO decisions produced by the stage-2 review
(LLM subagents or human reviewers) back onto the candidate-level review
frame from
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md),
and derives which candidate the adjudicator actually chose.

## Usage

``` r
np_merge_decisions(
  review,
  decisions,
  id = "uei",
  ein = "ein",
  prefix = "llm_",
  quiet = FALSE
)
```

## Arguments

- review:

  The candidate-level frame: an `np_routing` from
  [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
  (its `review` element is used), a review frame / data frame, or a path
  to a CSV of one.

- decisions:

  The adjudication result: a data frame, a path to a merged decisions
  CSV, or a path to a **directory** of per-shard `decision-*.csv` files
  (read and stacked, with a `.shard` column recording the source file).
  Must carry `uei`, `best_ein`, `llm_decision`, `llm_confidence`,
  `llm_reason`.

- id:

  Column naming the query key in `review`. Default `"uei"`; the decision
  side is always keyed on `uei`. Set this when
  [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
  was called with a different `id_label`.

- ein:

  Column naming the candidate key in `review`. Default `"ein"`.

- prefix:

  Prefix for the added columns. Default `"llm_"`, giving `llm_decision`,
  `llm_confidence`, `llm_reason`, `llm_best_ein`, and `llm_selected`.
  Use e.g. `"human_"` to merge a second, independent pass alongside the
  first without collision.

- quiet:

  Suppress the merge summary message and warnings. Default `FALSE`.

## Value

`review` with five columns appended, in its original row order and
class. Carries a `decision_merge` attribute: a list of `n_decisions`,
`n_ids`, `n_collapsed`, `n_matched` (review rows that got a decision),
`n_unmatched_ids` (decision ids absent from the frame), and `conflicts`.

## Details

[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
makes no LLM or network calls: its `review` frame is the hand-off *into*
adjudication, and the decisions come back as a separate artifact. This
is the join that closes that loop.

## Grain

Decisions are **query-level** — one row per source id. The review frame
is **candidate-level** — several rows per source id, one per surfaced
EIN. The decision columns therefore replicate across all of a query's
candidate rows, and the per-row answer is `llm_selected`: `TRUE` on the
single candidate the adjudicator picked. It is the stage-2 analogue of
`is_top_candidate`, and comparing the two shows where adjudication
overrode the pipeline's pick.

## Unadjudicated rows are NA, not FALSE

A decision file normally covers the MAYBE tier only, so queries that
were auto-accepted or auto-rejected have no decision row. Their decision
columns and `llm_selected` come back `NA` — meaning *not adjudicated*,
which is not the same as rejected. Guard with `%in% TRUE` (or
[`isTRUE()`](https://rdrr.io/r/base/Logic.html)) rather than letting
`NA` propagate when filtering.

## Duplicate source registrations

A source id matched in more than one compute chunk can be adjudicated in
more than one shard. Those rows are collapsed to one, preferring a YES
over a NO and then higher confidence — the same precedence the run-level
merge uses. Ids whose duplicate rows genuinely disagreed are recorded in
the `conflicts` attribute of the result, and warned about unless
`quiet = TRUE`.

## See also

[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
for producing the review frame,
[`np_as_prompt()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_as_prompt.md)
for rendering one case for an adjudicator, and
[`np_evaluate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_evaluate.md)
for scoring the merged result against labels.

## Examples

``` r
review <- data.frame(
  uei = c("A1", "A1", "B2", "C3"),
  ein = c("11-1111111", "22-2222222", "33-3333333", "44-4444444"),
  name_uss = c("Alpha", "Alpha", "Beta", "Gamma"),
  stringsAsFactors = FALSE
)
decisions <- data.frame(
  uei            = c("A1", "B2"),
  best_ein       = c("22-2222222", ""),
  llm_decision   = c("YES", "NO"),
  llm_confidence = c("high", "medium"),
  llm_reason     = c("same org; address confirms", "no credible candidate"),
  stringsAsFactors = FALSE
)
merged <- np_merge_decisions(review, decisions)
#> merged 2 decision(s) -> 2 id(s); 3 of 4 review rows adjudicated, 1 selected
merged[, c("uei", "ein", "llm_decision", "llm_selected")]
#>   uei        ein llm_decision llm_selected
#> 1  A1 11-1111111          YES        FALSE
#> 2  A1 22-2222222          YES         TRUE
#> 3  B2 33-3333333           NO        FALSE
#> 4  C3 44-4444444         <NA>           NA
# C3 was never adjudicated -> NA, not FALSE
```
