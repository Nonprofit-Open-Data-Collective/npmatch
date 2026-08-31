# Per-token inverse document frequency for a reference corpus

Document frequency of each name token across the reference, turned into
`idf = log(N / df)`: rare tokens (distinctive, high IDF) are the ones
the name-token blocking leverages; corpus-common tokens (low IDF) are
not. Feed the result to
[`np_route()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_route.md)
(`token_idf =`) to annotate the tokenized name fields with each token's
rarity, exposing which tokens carry the match.

## Usage

``` r
np_token_idf(name_keys, stopwords = np_stopwords(), min_token_len = 2L)
```

## Arguments

- name_keys:

  Character vector of normalized names (reference `name_key`).

- stopwords:

  Tokens to drop (see
  [`np_stopwords()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stopwords.md)).

- min_token_len:

  Minimum token length to count. Default 2.

## Value

A named numeric vector mapping token -\> IDF.
