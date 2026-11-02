# Render a review frame as a static HTML report

Turns the `review` queue from
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
into a self-contained HTML report for human review: one section per
source entity (UEI), each candidate laid out as a side-by-side "matching
form" (id, name, nonprofit type, age, size, affiliate, address, point of
contact, and the match-score block). Candidates are ordered with the
pipeline's selected pick first, then by descending `total_score`.

## Usage

``` r
np_review_report(
  x,
  output = "match-review-report.html",
  decision = "MAYBE",
  max_ueis = 0,
  only_missing_gt = FALSE,
  seed = 42,
  quiet = TRUE
)
```

## Arguments

- x:

  One of: an `np_routing` object from
  [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
  (its `review` element is used); an `np_review` frame or plain data
  frame in the review schema; or a path to a CSV of one.

- output:

  Path for the HTML file to write. Default `"match-review-report.html"`
  in the working directory. A `.html` extension is added if missing.

- decision:

  Which `match_decision` tiers to include: `"ALL"`, `"YES"`, `"NO"`, or
  `"MAYBE"` (comma-separate to combine, e.g. `"MAYBE,NO"`). Default
  `"MAYBE"` — the human-review hand-off queue.

- max_ueis:

  Cap on the number of UEI sections rendered; `0` or `NA` means no cap.
  When the pool is larger than `max_ueis`, a deterministic random sample
  (see `seed`) is drawn. Default `0`.

- only_missing_gt:

  Logical; when the frame carries ground-truth columns, restrict to UEIs
  whose ground-truth EIN is not among the candidates (recall misses).
  Ignored on frames without ground truth. Default `FALSE`.

- seed:

  Sampling seed used when `max_ueis` truncates the pool. Default 42.

- quiet:

  Suppress Quarto's rendering progress output. Default `TRUE`.

## Value

The path to the written HTML file, invisibly.

## Details

The report is read-only. If the frame also carries evaluation columns
(`is_gt_ein`, `gt_confidence`, `gt_outcome_class`, `labeled_by`) — as
produced by the benchmarking harness — the ground-truth candidate is
highlighted and floated to the top of its section, and UEIs whose true
EIN is missing from the candidate set are flagged. On an ordinary
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
frame those columns are simply absent and the report renders without
them.

Rendering requires the quarto package and a Quarto CLI installation (the
same dependency the vignettes use). The bundled template lives at
`system.file("report", "match-review-report.qmd", package = "npmatch")`.

## See also

[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
for producing the review frame;
[`np_run_report()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_report.md)
for a Markdown run summary.

## Examples

``` r
if (FALSE) { # \dontrun{
res     <- np_cascade(query, reference)
routing <- np_route(res, bmf = bmf_raw, sam = sam_raw)
np_review_report(routing, output = "review.html")

# just the recall misses on a labelled evaluation frame
np_review_report("EVAL-FRAME-MERGED.csv", decision = "ALL",
                 only_missing_gt = TRUE, output = "misses.html")
} # }
```
