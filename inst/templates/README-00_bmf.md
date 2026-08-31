# 00_bmf — reference pointer

**This folder holds no reference data.** The BMF is ~3.5 GB raw plus a ~470 MB
normalized bundle, and it is reused across runs. Copying it per run would cost
gigabytes and defeat the cache.

| file | what |
|---|---|
| `SOURCE.md` | which vintage this run used: path in the shared store, URL, md5, row count |
| `SIGNATURE.txt` | `np_normalize_signature()` hash of the cached normalized bundle |
| `logs/` | fetch and normalization logs |

## Why the signature matters

The normalized reference, the token-IDF table and the blocking index are built
once and reused. If the normalization code changes after the cache was built,
the cache is stale and a run using it is not reproducible against current code.
`SIGNATURE.txt` makes that detectable instead of silent.

Check it before every run:

```r
np_normalize_signature(readRDS(<cached bundle>)$reference)
```

If it differs from `SIGNATURE.txt`, rebuild the bundle.

## Derived reference assets

Large tables derived from the BMF vintage — the full-text grep index, the efile
crosswalk and name list — also live in the shared store, not here. They are
regenerable from the pinned vintage and would otherwise cost several hundred MB
per run.

Reference vintage: `{{bmf}}`
