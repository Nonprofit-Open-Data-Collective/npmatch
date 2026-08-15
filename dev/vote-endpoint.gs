/**
 * Match Review — vote collection endpoint (Google Apps Script)
 * Appends each incoming vote to a Google Sheet tab named "votes".
 *
 * Setup: see dev/match-review-voting-SETUP.md
 *   1. Create a Google Sheet, copy its ID from the URL.
 *   2. Extensions > Apps Script, paste this file, set SHEET_ID below.
 *   3. Deploy > New deployment > type "Web app",
 *        Execute as: Me,  Who has access: Anyone.
 *   4. Copy the /exec URL into the QMD param `vote_endpoint` (or the
 *      VOTE_ENDPOINT constant in the rendered HTML) and re-render.
 *
 * The report POSTs an array of vote objects (one per candidate judged) as a
 * text/plain body. Browsers send this "no-cors", so the report cannot read the
 * response — that's fine; the sheet is written and the report also keeps a
 * local copy (localStorage + "Download my votes (CSV)").
 */

var SHEET_ID   = 'PASTE_YOUR_SHEET_ID_HERE';
var SHEET_NAME = 'votes';

var HEADER = ['server_ts','client_ts','reviewer','uei','ein','cand_index',
  'num_candidates','is_gt_ein','pipeline_decision','name_uss','name_bmf',
  'total_score','vote','notes'];

function doPost(e) {
  try {
    var payload = JSON.parse(e.postData.contents);
    var rows = Array.isArray(payload) ? payload : [payload];

    var ss = SpreadsheetApp.openById(SHEET_ID);
    var sh = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);
    if (sh.getLastRow() === 0) sh.appendRow(HEADER);

    var now = new Date();
    var out = rows.map(function (r) {
      return [now, r.client_ts || '', r.reviewer || '', r.uei || '', r.ein || '',
        r.cand_index || '', r.num_candidates || '', r.is_gt_ein || '',
        r.pipeline_decision || '', r.name_uss || '', r.name_bmf || '',
        r.total_score || '', r.vote || '', r.notes || ''];
    });
    // batch write for speed
    sh.getRange(sh.getLastRow() + 1, 1, out.length, HEADER.length).setValues(out);

    return ContentService
      .createTextOutput(JSON.stringify({ ok: true, written: out.length }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ ok: false, error: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// Optional: visiting the /exec URL in a browser returns a health check.
function doGet() {
  return ContentService
    .createTextOutput(JSON.stringify({ ok: true, service: 'match-review votes' }))
    .setMimeType(ContentService.MimeType.JSON);
}
