# npmatch evaluation frame (1,502-org benchmark)

The candidate-level evaluation frame for the hand-labeled
1,502-organization benchmark: one row per (source organization x BMF
candidate), joined with the ground-truth labels. Group rows by `uei` to
see a source org's competing candidates; `is_top_candidate == 1` marks
the algorithm's chosen pick and `is_gt_ein == 1` marks the row whose EIN
is the ground-truth correct match.

## Usage

``` r
npmatch_eval
```

## Format

A data frame with 2,763 rows and 150 columns.

## Source

SAM / USASpending nonprofit registrations matched to the IRS Business
Master File (unified active + inactive, 2026-01 vintage). See
[`vignette("training-dataset", package = "npmatch")`](https://nonprofit-open-data-collective.github.io/npmatch/articles/training-dataset.md).

## Details

Alongside similarity features it carries the full review evidence:
normalized name variants, IDF-annotated tokens, geographic-agreement
flags, the veto trail, imported BMF context (`BMF_*`) and SAM context
(`SAM_*`), and the ground-truth columns (`gt_*`). Every column is
described in
[`vignette("training-dataset", package = "npmatch")`](https://nonprofit-open-data-collective.github.io/npmatch/articles/training-dataset.md)
and the field-level
[`vignette("candidate-evaluation-frame", package = "npmatch")`](https://nonprofit-open-data-collective.github.io/npmatch/articles/candidate-evaluation-frame.md).

## See also

[npmatch_groundtruth](https://nonprofit-open-data-collective.github.io/npmatch/reference/npmatch_groundtruth.md)
