# npmatch ground-truth master (1,502-org benchmark)

Query-level ground-truth labels for the benchmark: one row per source
organization. This is the archival label key — the training/validation
target that the evaluation frame joins onto.

## Usage

``` r
npmatch_groundtruth
```

## Format

A data frame with 1,502 rows and 17 columns, including:

- uei:

  Source (SAM) Unique Entity ID.

- sample_type:

  `"random"` (1,000 representative) or `"hard"` (502 oversampled).

- sam_name:

  Source organization legal name.

- gt_is_match:

  `TRUE` if a correct BMF EIN exists.

- gt_outcome_class:

  `in_bmf_match` / `nonprofit_not_in_bmf` / `not_a_nonprofit` /
  `no_match_or_na` / `cant_determine`.

- gt_ein:

  The correct EIN (may be an inactive-BMF or externally-collected EIN).

- gt_ein_in_bmf, gt_ein_bmf_active:

  Whether `gt_ein` is in the BMF, and active.

- gt_method, gt_confidence, gt_notes:

  How the label was determined, confidence, and notes.

## Source

See
[`vignette("training-dataset", package = "npmatch")`](https://nonprofit-open-data-collective.github.io/npmatch/articles/training-dataset.md).

## See also

[npmatch_eval](https://nonprofit-open-data-collective.github.io/npmatch/reference/npmatch_eval.md)
