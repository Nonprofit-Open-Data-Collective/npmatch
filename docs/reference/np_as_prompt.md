<div id="main" class="col-md-9" role="main">

# Render a review case as an LLM adjudication prompt

<div class="ref-description section level2">

Formats one query's review packet as self-contained prompt text: the
source organisation, the candidate BMF entities with their fields and
similarities, why it was flagged, and a JSON-output instruction. Pure
string formatting — it does not call any model. Use it to drive an LLM
refinement step, or read it as the human-facing summary of a case.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_as_prompt(routing, id)
```

</div>

</div>

<div class="section level2">

## Arguments

-   routing:

    An `np_routing` from `np_route()`.

-   id:

    A query `.id` present in the review queue.

</div>

<div class="section level2">

## Value

A length-one character string.

</div>

</div>
