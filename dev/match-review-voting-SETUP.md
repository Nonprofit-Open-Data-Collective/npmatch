# Match Review — voting setup

The review report (`dev/match-review-report.qmd`) can collect **Yes / No / Maybe**
votes per candidate and record them to a **Google Sheet**, with no server to run.
Reviewers open one shared URL, vote, and their votes are saved to the sheet
(and kept locally in their browser as a backup).

There are three moving parts:

1. **A Google Sheet + Apps Script** that receives votes (`dev/vote-endpoint.gs`).
2. **The rendered HTML report**, with the endpoint URL baked in.
3. **A place to host the HTML** so reviewers can reach it by URL.

---

## 1. Create the vote endpoint (once, ~5 min)

1. Create a new **Google Sheet** (blank). From its URL copy the ID — the long
   string between `/d/` and `/edit`:
   `https://docs.google.com/spreadsheets/d/`**`THIS_PART`**`/edit`
2. In the sheet: **Extensions → Apps Script**.
3. Delete the starter code, paste the contents of **`dev/vote-endpoint.gs`**,
   and set `SHEET_ID` to the ID from step 1. Save.
4. **Deploy → New deployment**. Click the gear → **Web app**. Set:
   - **Execute as:** *Me*
   - **Who has access:** *Anyone*  (required so reviewers' browsers can POST)
5. **Deploy**, authorize when prompted, and copy the **Web app URL**
   (ends in `/exec`).
6. Sanity check: open that `/exec` URL in a browser — it should return
   `{"ok":true,"service":"match-review votes"}`.

> The report sends votes with `mode:"no-cors"`, so the browser can't read the
> response. That's expected — the row is still written. The report always keeps
> a local copy too (see *Backups* below), so nothing is lost if the endpoint is
> ever misconfigured.

---

## 2. Render the report with the endpoint

Pass the `/exec` URL as the `vote_endpoint` param (quote it):

```bash
quarto render dev/match-review-report.qmd \
  -P vote_endpoint:"https://script.google.com/macros/s/AKfy.../exec" \
  -P decision_filter:MAYBE \
  -P max_ueis:0
```

Useful params:

| param | default | meaning |
|---|---|---|
| `enable_voting` | `true` | `false` = read-only report, no vote controls |
| `vote_endpoint` | `""` | the Apps Script `/exec` URL; empty = votes saved locally only |
| `blind` | `false` | `true` = hide the ground-truth highlighting/badges/ordering so votes are unbiased (score `is_gt_ein` afterward by joining on `uei`+`ein`) |
| `decision_filter` | `"MAYBE"` | which pipeline decisions to include (`ALL`/`YES`/`NO`/`MAYBE`, comma-combinable) |
| `only_missing_gt` | `false` | only UEIs whose ground-truth EIN isn't among the candidates |
| `max_ueis` | `40` | cap the number of UEI sections; `0` = all |

For a real vote-collection run you'll usually want `max_ueis:0`. Consider
splitting the pool across reviewers (e.g. render several reports each filtered
to a slice) so nobody reviews the same cases — or just have each reviewer enter
a distinct name; votes are keyed by reviewer in the sheet.

---

## 3. Host the HTML (pick one)

The report is a single self-contained `.html` file. Any static host works:

- **GitHub Pages** — commit the HTML to a repo/`docs/` folder; share the Pages URL.
- **Netlify Drop** — drag the file onto <https://app.netlify.com/drop>; instant URL.
- **Google Drive / Dropbox** shared link (rendered view varies by browser).
- Even **emailing the file** works — voting + local backup still function; only
  the Sheet write needs the reviewer to be online.

---

## How reviewers use it

1. Open the URL. Type a **name/initials** in the top bar and click **Set**
   (this labels their votes and lets them resume later on the same browser).
2. For each UEI, click **Yes / No / Maybe** on the correct candidate(s), add an
   optional note, and click **Save UEI vote**.
3. The top progress bar shows *N of M UEIs saved*. Work is saved in the browser
   as they go, so they can close and come back.

## Backups & the source of truth

- Every vote is stored in the browser's `localStorage` immediately, keyed by
  reviewer name — refreshing or closing the tab does not lose work.
- **Download my votes (CSV)** (top bar) exports that reviewer's votes at any time.
- The Google Sheet is the aggregated record across reviewers. If you ever doubt
  a write reached the sheet, the per-reviewer CSV is the fallback.

## Analyzing results

The sheet has one row per candidate a reviewer judged, including `is_gt_ein`
(when not in blind mode). To score reviewers against ground truth, compare the
candidate a reviewer marked `yes` to the row where `is_gt_ein == 1` for that
`uei`. In blind mode `is_gt_ein` is blank in the sheet — join the votes back to
`data-dev/EVAL-FRAME-1502-MERGED.csv` on `uei` + `ein` to recover it.
