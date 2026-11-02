# Match one level up: roll candidates up to their family

Some queries cannot be settled to one EIN but can be to a family: a
chapter of a federation, a hospital system, a school and its PTO. Often
the evidence is split - the name matches one member and the address
another - so no single candidate scores as a match, while the family
plainly does. `np_cluster_rollup()` finds those cases among queries that
did not reach `YES`, from the candidates the cascade already scored.

## Usage

``` r
np_cluster_rollup(
  tiered,
  clusters,
  pairs = attr(tiered, "pairs"),
  query = NULL,
  min_name = 0.9,
  min_addr = 0.8,
  max_size = 25L,
  types = NULL
)
```

## Arguments

- tiered:

  The result of
  [`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md),
  carrying `attr(, "pairs")`.

- clusters:

  Cluster membership: a data frame with `cluster_id`, `cluster_type`,
  `.ein` (or `ein`), and optionally `size` and `brand_tokens` -
  matchdb's `cluster_member` joined to `cluster`.

- pairs:

  The scored candidate pairs. Defaults to `attr(tiered, "pairs")`.

- query:

  Optional query frame with `.id` and `name_key`, for the brand test.
  Without it, condition 3 is not used.

- min_name, min_addr:

  Similarity each side must reach within the cluster.

- max_size:

  Largest cluster accepted without the brand test.

- types:

  Cluster types to use; `NULL` for all.

## Value

A data frame, one row per query that rolls up: `.id`, `cluster_id`,
`cluster_type`, `cluster_size`, `cluster_name_sim`, `cluster_addr_sim`,
`cluster_score`, `name_ein`, `addr_ein`, `n_members`, `basis` (which
condition admitted it).

## How a cluster qualifies

For each query and each cluster holding at least one of its candidates,
take the best name similarity and the best address similarity over the
cluster's candidate members. The cluster qualifies when both clear
`min_name` and `min_addr`, and it passes a size guard: a cluster of
thousands has, by chance alone, some member near the query's name and
some other member near its address. So one of these must hold:

1.  the same member is best on both name and address (then the EIN-level
    result was close, and the family confirms it);

2.  the cluster has at most `max_size` members;

3.  the cluster's leading brand token - the first word of four or more
    letters in matchdb's `cluster.brand_tokens`, which lists the words
    most members share, most shared first: `ROTARY`, not `CLUB` -
    appears in the query's name.

Of several qualifying clusters the one with the highest combined score
wins, smaller clusters first on ties: the narrowest family that explains
the evidence.

The result annotates; it does not change the EIN-level `tier`. Whether a
`CLUSTER` match counts as a resolution is the analysis's choice.
