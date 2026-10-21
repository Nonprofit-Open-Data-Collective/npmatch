# Name-normalization rule tables

The tables
[`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md)
uses, for packages that need the same rules in another engine (for
example a DuckDB SQL macro). A port should be checked against
[`np_name_core()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_name_core.md)
on test strings; the tables are covered by
[`np_normalize_signature()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize_signature.md).

## Usage

``` r
np_name_rules()
```

## Value

A list: `abbrev` (named character, token to expansion), `core_stop`
(tokens dropped from `name_core`), `legal_suffixes` (trailing tokens
stripped from `name_key`), `placeholder_re` (a Perl regex on the raw
upper-cased name) and `placeholder_tok`.
