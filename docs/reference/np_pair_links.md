<div id="main" class="col-md-9" role="main">

# Are a query's top two candidates one family?

<div class="ref-description section level2">

For each query, the best and second-best distinct candidate EINs, and
the cluster types they share. When they share one, the contest is within
a family - a hospital and its foundation, two chapters - not between
strangers. A `YES` won over a linked sibling by a thin margin is the
case a reference without the sibling would have auto-accepted unseen
(matchdb `PLAN.md` section 8a); `family_contest` marks it.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_pair_links(
  tiered,
  clusters,
  pairs = attr(tiered, "pairs"),
  margin = 0.05,
  types = NULL
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   tiered:

    The result of `np_cascade()`, carrying `attr(, "pairs")`.

-   clusters:

    Cluster membership: a data frame with `cluster_id`, `cluster_type`,
    `.ein` (or `ein`), and optionally `size` and `brand_tokens` -
    matchdb's `cluster_member` joined to `cluster`.

-   pairs:

    The scored candidate pairs. Defaults to `attr(tiered, "pairs")`.

-   margin:

    A winner ahead of a linked runner-up by less than this is a
    `family_contest`.

-   types:

    Cluster types to use; `NULL` for all.

</div>

<div class="section level2">

## Value

A data frame, one row per query with at least two candidates: `.id`,
`top_ein`, `runner_up_ein`, `top_score`, `runner_up_score`, `linked`,
`link_types` (`;`-separated), `family_contest`.

</div>

</div>
