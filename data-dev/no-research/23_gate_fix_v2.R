#!/usr/bin/env Rscript
# Re-score the escape hatch against the BETTER ground truth from audit v2
# (cached Tier 2 + efile index, zero 429s).
suppressPackageStartupMessages({library(data.table)})

out <- "data-dev/no-research"
seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
vv   <- fread(file.path(out, "AUDIT-V1-VS-V2.csv"), colClasses = "character")
xw   <- fread(file.path(out, "EFILE-XWALK.tsv"), sep="\t", colClasses="character", quote="")
nm   <- fread(file.path(out, "EFILE-NAMES.tsv"), sep="\t", colClasses="character", quote="")

dom <- function(u){u<-tolower(trimws(u));u<-sub("^[a-z]+://","",u);u<-sub("^www[0-9]?\\.","",u)
  u<-sub("[/?#].*$","",u);u<-sub(":.*$","",u);u<-sub("\\.+$","",u)
  u[!grepl("\\.",u)|nchar(u)<4]<-"";u}

g <- seed[web == "FALSE"]
g[, sam_dom := dom(sam_url)]
d <- unique(xw[web_domain != "", .(web_domain, ein)], by = c("web_domain","ein"))
g[, f_dom := uei %chin% unique(merge(g[sam_dom!="",.(uei,sam_dom)], d,
                by.x="sam_dom", by.y="web_domain")$uei)]
hn <- merge(g[q_nk_ds!="", .(uei,q_nk_ds)], nm, by.x="q_nk_ds", by.y="variant_key",
            allow.cartesian=TRUE)
g[, f_nm := uei %chin% unique(hn$uei)]
g[, hatch := bmf_lookup != "" | entity_gate == "not_tax_exempt_corp"]

a <- merge(vv[, .(uei, entity_gate, sam_name, v1_det, v2_det, v2_ein)],
           g[, .(uei, hatch, f_dom, f_nm)], by = "uei")
a[, fs := v2_det == "match"]
N <- nrow(a); K <- sum(a$fs)
cat("audited:", N, " false settles (v2 truth):", K,
    sprintf(" = %.1f%%\n\n", 100*K/N))

score <- function(lbl, flag) data.table(
  signal = lbl, caught = sum(flag & a$fs), of = K, flagged = sum(flag),
  extra_vol = sprintf("%.1f%%", 100*mean(flag)),
  residual = sprintf("%.2f%%", 100*sum(!flag & a$fs)/max(1,sum(!flag))))
print(rbindlist(list(
  score("hatch only (BMF-hit OR 2L)",   a$hatch),
  score("efile domain only",            a$f_dom),
  score("hatch + efile domain",         a$hatch | a$f_dom),
  score("hatch + efile domain + name",  a$hatch | a$f_dom | a$f_nm))))

cat("\n=== the 8 false settles, by signal ===\n")
print(a[fs == TRUE, .(org = substr(sam_name,1,34), gate = entity_gate, ein = v2_ein,
                      hatch, efile_dom = f_dom, efile_name = f_nm)])

cat("\n=== false-settle rate by gate, on v2 truth ===\n")
b <- a[, .(audited = .N, false_settles = sum(fs)), by = entity_gate]
b[, rate := sprintf("%.1f%%", 100*false_settles/audited)]
print(b[order(-false_settles)])

cat("\n=== projection to the full pool ===\n")
p1 <- nrow(fread(file.path(out,"POOL-STAGE1-NO.csv")))
p2 <- nrow(fread(file.path(out,"POOL-STAGE2-NO.csv")))
g1 <- seed[.src=="stage1", mean(web=="FALSE")]; g2 <- seed[.src=="stage2", mean(web=="FALSE")]
gated <- p1*g1 + p2*g2
ci <- binom.test(K, N)$conf.int
cat(sprintf("gated cases pool-wide: %s\n", format(round(gated), big.mark=",")))
cat(sprintf("matches lost with NO fix : ~%s  (95%% CI %s - %s)\n",
    format(round(gated*K/N), big.mark=","), format(round(gated*ci[1]), big.mark=","),
    format(round(gated*ci[2]), big.mark=",")))
best <- a$hatch | a$f_dom
res_rate <- sum(!best & a$fs)/max(1,sum(!best))
cat(sprintf("matches lost WITH hatch+efile-domain: ~%s (residual %.2f%%), extra volume %.1f%% of gated\n",
    format(round((gated*(1-mean(best)))*res_rate), big.mark=","), 100*res_rate, 100*mean(best)))
fwrite(a, file.path(out, "GATE-FIX-V2.csv"))
