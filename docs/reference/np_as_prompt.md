# Render a review case as an LLM adjudication prompt

Formats one query's review packet as self-contained prompt text: the
source organisation, the candidate BMF entities with their fields and
similarities, why it was flagged, and a JSON-output instruction. Pure
string formatting — it does not call any model. Use it to drive an LLM
refinement step, or read it as the human-facing summary of a case.

## Usage

``` r
np_as_prompt(routing, id)
```

## Arguments

- routing:

  An `np_routing` from
  [`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md).

- id:

  A query `.id` present in the review queue.

## Value

A length-one character string.
