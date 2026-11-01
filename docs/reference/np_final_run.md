<div id="main" class="col-md-9" role="main">

# Roll the stages up into the final deliverables

<div class="ref-description section level2">

Binds the per-stage outcome files into the two artifacts the run exists
to produce, and reports the end-to-end funnel.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_final_run(
  project = np_project_root(),
  precedence = c("1", "2", "3"),
  verbose = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   project:

    Project root. Defaults to `np_project_root()`.

-   precedence:

    Order in which stages win when one source id is matched by more than
    one (a duplicate registration can be matched in two stages). Default
    `c("1", "2", "3")` — the earliest, most automatic match wins.

-   verbose:

    Print progress. Default `TRUE`.

</div>

<div class="section level2">

## Value

The crosswalk, invisibly.

</div>

<div class="section level2">

## Details

-   **`crosswalk.csv`** — every matched source id, one row each,
    carrying `decided_by` so a consumer can tell an auto-accepted
    stage-1 match from one an adjudicator or a web search produced. This
    is the only place the word "crosswalk" is used; elsewhere the linked
    pairs are `matches`.

-   **`eval_frame.csv`** — the candidate-level frame: every candidate
    stage 1 surfaced, annotated with the final answer for its source id.
    Every source id has at least one row; one with no candidates gets a
    single row with `candidate_source = "none"`.

`final_outcome` is `"MATCH"` exactly for the ids in the crosswalk. An
unmatched id takes `final_stage`, `final_basis`, `final_confidence` and
`final_reason` from the last stage that decided it and has no
`final_ein`: a MAYBE candidate rejected downstream is not an answer.

</div>

<div class="section level2">

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

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_stage1_run()`, `np_stage2_run()`, `np_stage3_run()`.

</div>

</div>

</div>
