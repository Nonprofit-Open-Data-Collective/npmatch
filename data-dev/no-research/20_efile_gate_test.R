#!/usr/bin/env Rscript
# Re-run the gate audit against the efile crosswalk.
#
# We already have blind ground truth for 167 gated cases (AUDIT-TIER1-SCORED.csv),
# so this is a deterministic test: which escape-hatch signal would have flagged
# the 6 false settles, and at what cost in extra volume?
suppressPackageStartupMessages({library(data.table)})

out <- "data-dev/no-research"
seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
au   <- fread(file.path(out, "AUDIT-TIER1-SCORED.csv"), colClasses = "character")
xw   <- fread(file.path(out, "EFILE-XWALK.tsv"), sep = "\t", colClasses = "character", quote = "")
nm   <- fread(file.path(out, "EFILE-NAMES.tsv"), sep = "\t", colClasses = "character", quote = "")

dom <- function(u) {
  u <- tolower(trimws(u)); u <- sub("^[a-z]+://", "", u); u <- sub("^www[0-9]?\\.", "", u)
  u <- sub("[/?#].*$", "", u); u <- sub(":.*$", "", u); u <- sub("\\.+$", "", u)
  u[!grepl("\\.", u) | nchar(u) < 4] <- ""; u
}

g <- seed[web == "FALSE"]                       # the 462 cases the gate settled
g[, sam_dom := dom(sam_url)]

## ---- signal 1: website domain matches an efile filer --------------------
d <- unique(xw[web_domain != "", .(web_domain, ein)], by = c("web_domain","ein"))
hit_dom <- merge(g[sam_dom != "", .(uei, sam_dom, sam_state)], d,
                 by.x = "sam_dom", by.y = "web_domain")
hit_dom <- merge(hit_dom, xw[, .(ein, e_state = state, e_name = name)], by = "ein")
dom_flag <- unique(hit_dom$uei)

## ---- signal 2: name-as-filed matches (efile name/dba variants) ----------
setkey(nm, variant_key)
hit_nm <- merge(g[q_nk_ds != "", .(uei, q_nk_ds, sam_state)], nm,
                by.x = "q_nk_ds", by.y = "variant_key", allow.cartesian = TRUE)
hit_nm <- merge(hit_nm, xw[, .(ein, e_state = state)], by = "ein")
nm_flag       <- unique(hit_nm$uei)
nm_flag_state <- unique(hit_nm[e_state == sam_state]$uei)   # same-state only

## ---- the escape hatch already in the plan -------------------------------
g[, hatch_now := bmf_lookup != "" | entity_gate == "not_tax_exempt_corp"]
g[, f_dom      := uei %chin% dom_flag]
g[, f_nm       := uei %chin% nm_flag]
g[, f_nm_state := uei %chin% nm_flag_state]

## ---- score against the audited truth ------------------------------------
a <- merge(au[, .(uei, entity_gate, sam_name, audit_determination, audit_ein)],
           g[, .(uei, hatch_now, f_dom, f_nm, f_nm_state)], by = "uei")
a[, is_false_settle := audit_determination == "match"]
NFS <- sum(a$is_false_settle)
cat("audited gated cases:", nrow(a), " known false settles:", NFS, "\n\n")

score <- function(lbl, flag) {
  data.table(signal = lbl,
             caught = sum(flag & a$is_false_settle),
             of = NFS,
             flagged = sum(flag),
             extra_volume_pct = sprintf("%.1f%%", 100*mean(flag)),
             residual_rate = sprintf("%.2f%%",
                100*sum(!flag & a$is_false_settle)/max(1, sum(!flag))))
}
res <- rbindlist(list(
  score("current hatch (BMF-hit OR 2L)",      a$hatch_now),
  score("efile website domain",               a$f_dom),
  score("efile name-as-filed (same state)",   a$f_nm_state),
  score("efile name-as-filed (any state)",    a$f_nm),
  score("hatch + efile domain",               a$hatch_now | a$f_dom),
  score("hatch + efile domain + name(state)", a$hatch_now | a$f_dom | a$f_nm_state)))
cat("=== which signal catches the false settles, and at what cost ===\n")
print(res)

cat("\n=== the 6 false settles, signal by signal ===\n")
print(a[is_false_settle == TRUE, .(gate = entity_gate, org = substr(sam_name, 1, 32),
        ein = audit_ein, hatch = hatch_now, efile_dom = f_dom, efile_name = f_nm_state)])

cat("\n=== the case the current hatch misses ===\n")
miss <- a[is_false_settle == TRUE & hatch_now == FALSE]
print(miss[, .(org = sam_name, gate = entity_gate, ein = audit_ein,
               caught_by_efile_domain = f_dom, caught_by_efile_name = f_nm_state)])

## ---- project across the whole gated pool --------------------------------
cat("\n=== volume across all 462 gated pilot cases ===\n")
print(g[, .(hatch_only = sum(hatch_now),
            plus_efile = sum(hatch_now | f_dom | f_nm_state),
            added_by_efile = sum((f_dom | f_nm_state) & !hatch_now))])
fwrite(a, file.path(out, "AUDIT-VS-EFILE.csv"))
