# npmatch: nonprofit record linkage to the IRS BMF

A geography-adaptive, tiered linkage pipeline built as a thin layer over
reclin2. The stages compose left to right:

## Details

1.  [`np_query()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_query.md)
    /
    [`np_reference()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_reference.md)
    — map a dataset onto canonical fields

2.  [`np_normalize()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize.md)
    — standardize names/addresses, extract veto features

3.  [`np_compare()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_compare.md)
    — block and score candidate pairs (reclin2)

4.  [`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
    — combine field similarities (weighted / EM / model)

5.  [`np_veto()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_veto.md)
    — apply hard do-not-match rules

6.  [`np_select()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_select.md)
    — best entity per query, plus loosened name/addr views

7.  [`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
    — sort into YES / MAYBE / NO

[`np_match()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_match.md)
runs the whole chain;
[`np_label_frame()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label_frame.md)
emits training data.

## See also

Useful links:

- <https://github.com/Nonprofit-Open-Data-Collective/npmatch>

- <https://nonprofit-open-data-collective.github.io/npmatch/>

- Report bugs at
  <https://github.com/Nonprofit-Open-Data-Collective/npmatch/issues>

## Author

**Maintainer**: Jesse Lecy <jdlecy@gmail.com>
