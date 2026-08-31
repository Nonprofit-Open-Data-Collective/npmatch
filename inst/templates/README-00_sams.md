# 00_sams — source extract

SAM is genuinely per-run, so the real bytes live here.

| path | what |
|---|---|
| `raw/` | the monthly SAM public extract (`.dat`), pasted in or fetched |
| `sam_query.csv` | **primary output** — the filtered nonprofit query frame |
| `SAM-REPORT.md` | rows in, nonprofits out, business-type flag breakdown |
| `interim/` | layout map, flagged-but-unfiltered frame |
| `logs/` | |

## The nonprofit filter

SAM is raw: it must be filtered before matching. A record counts as a nonprofit
when its `BUS TYPE STRING` contains any of `A8`, `BZ`, `2U`, `A7`. Headers are
lower-cased and underscored so `np_map_sam()` can address them.

```r
sam <- np_read_sam("raw/<extract>.dat")
q   <- np_prepare_sam(sam)             # flag + filter + rename
```

Everything downstream keys on `uei` (Unique Entity Identifier). One row per UEI:
duplicate registrations are collapsed here, not later.

Source extract: `{{sam}}`
