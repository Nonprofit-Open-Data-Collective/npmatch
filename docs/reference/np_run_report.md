# Summarise a cascade run as a report

Assembles a human-readable report from an
[`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
result: provenance (version, config, inputs), the matching process
(per-pass cascade table, how many candidates were generated, how matches
were formed), the outcome (YES / MAYBE / NO with margins and vetoes),
operations (timings, files written), and a pointer to the review
hand-off for the MAYBE queue.

## Usage

``` r
np_run_report(
  res,
  inputs = NULL,
  timings = NULL,
  outputs = NULL,
  reference = NULL,
  file = NULL,
  title = "npmatch run report"
)
```

## Arguments

- res:

  An `np_tiered` result from
  [`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
  (carrying its `stages`, `pairs`, and `config` attributes).

- inputs:

  Optional data frame or named list describing the source files used
  (e.g. columns `file`, `vintage`, `rows`, `md5`). Rendered verbatim.

- timings:

  Optional named numeric vector of stage durations in seconds (e.g.
  `c(normalize = 610, cascade = 2900)`).

- outputs:

  Optional character vector of output file paths written.

- reference:

  Label for the reference used, e.g. `"unified (active+inactive)"`.

- file:

  Optional path to write the Markdown report to.

- title:

  Report title.

## Value

The Markdown report as a length-one character string (invisibly if
`file` is given). A structured list of the computed pieces is attached
as `attr(., "parts")`.

## Details

Most of the content is read straight off the result object —
`attr(res, "stages")` (the per-pass summary) and `attr(res, "pairs")`
(the scored candidate union) — so it works on any cascade result without
a labelled truth set. Supply `inputs`, `timings`, and `outputs` to
record provenance and operational context that the result object cannot
know.
