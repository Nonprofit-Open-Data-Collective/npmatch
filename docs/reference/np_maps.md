<div id="main" class="col-md-9" role="main">

# Built-in schema maps

<div class="ref-description section level2">

Named vectors mapping canonical npmatch fields (names) to source column
names (values) for known dataset formats. Use with the `map` argument of
`np_query()` / `np_reference()`, or supply your own.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_map_bmf(active_col = NULL)

np_map_sam()
```

</div>

</div>

<div class="section level2">

## Arguments

-   active_col:

    Optional source column flagging whether each EIN is in the active
    BMF. Supply it when the reference is the **unified** (active +
    inactive) BMF so matches carry an `active` flag downstream
    (current-990s vs identity-resolution filtering). Omit for the
    active-only BMF.

</div>

<div class="section level2">

## Value

A named character vector: `canonical_field = source_column`.

</div>

<div class="section level2">

## Details

`np_map_bmf()` targets the current processed IRS BMF. It matches on
`org_name_join` (already uppercased and de-punctuated) and keeps the raw
and parent names for the veto layer.

`np_map_sam()` targets the SAM / USASpending public extract used as the
worked example.

</div>

</div>
