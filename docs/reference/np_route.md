<div id="main" class="col-md-9" role="main">

# Route a tiered result to accept / review / unmatched

<div class="ref-description section level2">

Turns an `np_tier()` / `np_match()` result into the three hand-off
products of the pipeline:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_route(
  tiered,
  config = attr(tiered, "config"),
  pairs = attr(tiered, "pairs"),
  k = 3,
  source = "uss",
  reference = "bmf",
  id_label = "uei",
  bmf = NULL,
  sam = NULL,
  review_tiers = c("YES", "MAYBE", "NO"),
  token_idf = NULL,
  source_data = NULL,
  reference_data = NULL,
  extra_source = NULL,
  extra_reference = NULL,
  source_key = NULL,
  reference_key = "ein"
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   tiered:

    An `np_tiered` result (carries the scored pairs and config).

-   config:

    An `np_config()` for the tier thresholds. Defaults to the config the
    result was tiered with.

-   pairs:

    The scored candidate pairs. Defaults to those attached by
    `np_match()`.

-   k:

    Candidates to surface per review case. Default 3.

-   source:

    Suffix for the query-side (source) columns, replacing `_x`. Default
    `"uss"` (USASpending), the shipped deployment's source.

-   reference:

    Suffix for the candidate-side (reference) columns, replacing `_y`.
    Default `"bmf"`. Set both for another pair of datasets — the layout
    and the derived fields do not change.

-   id_label:

    Column name for the query key (`.id`), which is ambiguous. Default
    `"uei"` (Unique Entity Identifier), the key of the shipped
    deployment's source; its reference key is `ein`.

-   bmf:

    Optional raw processed BMF. When supplied, the default context
    fields from `np_bmf_review_fields()` (NTEE, 501(c) subsection,
    foundation flag, ruling year, assets, revenue, 990 form type) are
    joined onto each review row (`BMF_`-prefixed) and placed at the end,
    after the derived fields.

-   sam:

    Optional raw SAM source frame. When supplied,
    `np_sam_review_fields()` context columns (entity start/fiscal dates,
    URL, structure + label, primary NAICS, POC name/title, and one
    boolean per business type) are joined onto each review row
    (`SAM_`-prefixed) and placed at the end.

-   review_tiers:

    Which tiers to include in the `review` inspection frame. Default all
    three (`c("YES","MAYBE","NO")`) so `decision` shows the full
    YES/MAYBE/NO outcome; set to `"MAYBE"` for just the human-review
    hand-off.

-   token_idf:

    Optional token -> IDF table from `np_token_idf()`. When given, the
    `name_*_tokenized` fields annotate each content token with its
    reference IDF (rarest first), exposing which tokens carry the match.

-   source_data, reference_data:

    Optional data frames to pull extra passthrough columns from (e.g.
    award fields from the source, NTEE/ruling fields from the BMF).
    Joined by key onto each review row.

-   extra_source, extra_reference:

    Character vectors of column names to carry through from
    `source_data` / `reference_data`. Appended, suffixed by `source` /
    `reference`, after the generated features.

-   source_key, reference_key:

    Join keys in `source_data` / `reference_data`. Default to `id_label`
    and `"ein"` respectively.

</div>

<div class="section level2">

## Value

An `np_routing` object: a list of `accepted`, `review`, `unmatched`, and
a `summary` count vector.

</div>

<div class="section level2">

## Details

-   **`accepted`** the auto-matched crosswalk (YES tier),

-   **`review`** a self-contained queue for the MAYBE tier — one row per
    surfaced candidate (top-k by score plus the best name-only and best
    address-only pairs). Columns lead with a curated decision block —
    `<id_label>, ein, name_<source>, name_<reference>, name_sim, addr_sim, score, decision, decision_layer, decision_reason, notes`,
    then the aligned address fields and per-field sims — followed by
    **every** remaining generated feature/stat, and finally any optional
    passthrough columns.

-   **`unmatched`** the NO tier, each with its best near-miss for
    reference.

The `review` queue is the same schema a human spreadsheet and an LLM
prompt both consume (`np_as_prompt()` renders one case as prompt text).
No LLM or network calls are made.

</div>

</div>
