# Roll the stages up into the final deliverables

Binds the per-stage outcome files into the two artifacts the run exists
to produce, and reports the end-to-end funnel.

## Usage

``` r
np_final_run(
  project = np_project_root(),
  precedence = c("1", "2", "3"),
  verbose = TRUE
)
```

## Arguments

- project:

  Project root. Defaults to
  [`np_project_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_root.md).

- precedence:

  Order in which stages win when one source id is matched by more than
  one (a duplicate registration can be matched in two stages). Default
  `c("1", "2", "3")` — the earliest, most automatic match wins.

- verbose:

  Print progress. Default `TRUE`.

## Value

The crosswalk, invisibly.

## Details

- **`crosswalk.csv`** — every matched source id, one row each, carrying
  `decided_by` so a consumer can tell an auto-accepted stage-1 match
  from one an adjudicator or a web search produced. This is the only
  place the word "crosswalk" is used; elsewhere the linked pairs are
  `matches`.

- **`eval_frame.csv`** — the candidate-level frame: every candidate
  stage 1 surfaced, annotated with the final answer for its source id.

## Answers found outside the candidate set

Stage 3 recovers matches the matcher never surfaced, so the final EIN
for a source id is often absent from `stage1_k_candidates`. Those are
**not** dropped: a synthetic row is emitted carrying the final EIN with
its similarity columns empty and `candidate_source = "stage3_research"`,
and `final_ein_in_candset` records which case each row is.

That flag splits recall loss in two. A match whose EIN was never in the
candidate set is a **blocking** failure — no threshold change recovers
it. One that was surfaced but scored below the floor is a **scoring**
failure, and is recoverable by recalibration. Collapsing them would hide
the only number that says which of the two to work on.

## See also

[`np_stage1_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage1_run.md),
[`np_stage2_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage2_run.md),
[`np_stage3_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage3_run.md).
