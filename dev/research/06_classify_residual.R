suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
f <- fread(file.path(base,"data-dev/FUZZY-RECHECK.csv"), colClasses="character")
tr <- fread(file.path(base,"data-dev/TRAINING-RESEARCH.csv"), colClasses="character")  # structural seed (9)
f[, `:=`(jw=as.numeric(jw), jac=as.numeric(jac), addr=addr=="TRUE")]
U <- toupper(f$name)

church <- grepl("CHURCH|PARISH|CATHEDRAL|BASILICA|CHAPEL|MINISTR|CONGREGATION|TEMPLE|SYNAGOGUE|MOSQUE|EPISCOPAL|PRESBYTERIAN|METHODIST|BAPTIST|LUTHERAN|ORTHODOX|PENTECOSTAL|WORSHIP CENTER|ASSEMBLY OF GOD|SEVENTH DAY ADVENTIST", U) &
          !grepl("CHARIT|FOUNDATION|SCHOOL|ACADEMY|UNIVERSITY|COLLEGE|HOUSING|APARTMENT|SERVICES|COUNCIL", U)
# strict person: 3 tokens with a single-letter middle initial (e.g. "LAUREN L CRUZ"); high precision
tk <- strsplit(trimws(gsub("[^A-Z ]"," ",U))," +")
person <- vapply(tk, function(t) length(t)==3 && nchar(t[2])==1, logical(1)) &
          !grepl("FOUNDATION|ASSOC|SOCIETY|INSTITUTE|CENTER|COUNCIL|FUND|TRUST|CLUB|CHURCH|SCHOOL|INC|CORP|GROUP|COMPANY|UNION|LODGE|DISTRICT|AUTHORITY", U)

f[, det := NA_character_][, conf := NA_character_][, src := NA_character_][, ein := ""]
# 1. address-corroborated fuzzy match (reliable)
i1 <- is.na(f$det) & f$jw>=0.92 & f$addr; i1[is.na(i1)] <- FALSE
f[i1, `:=`(det=fifelse(cand_active=="TRUE","match","nonprofit_not_in_bmf:inactive"),
           ein=cand_ein, conf="high", src="local fuzzy + address")]
# 2. distinctive full-name near-identical, no addr needed (jw on full string guards town mismatch)
i2 <- is.na(f$det) & f$jw>=0.97 & f$jac>=0.70; i2[is.na(i2)] <- FALSE
f[i2, `:=`(det=fifelse(cand_active=="TRUE","match","nonprofit_not_in_bmf:inactive"),
           ein=cand_ein, conf="med", src="local fuzzy (distinctive name)")]
# 3. church/worship, no BMF addr match -> auto-exempt / group ruling, typically not individually listed
i3 <- is.na(f$det) & church
f[i3, `:=`(det="nonprofit_not_in_bmf:church", conf="med", src="name pattern (worship/auto-exempt)")]
# 4. individual person registrant
i4 <- is.na(f$det) & person
f[i4, `:=`(det="not_a_nonprofit:individual", conf="med", src="name pattern (person)")]
# rest -> web
f[, needs_web := is.na(det)]

add <- f[!is.na(det), .(uei, set, algo_tier, name, state, ein_found=ein,
   determination=det, confidence=conf, resolving_tier="tier1_local", source=src, notes="")]
allres <- rbindlist(list(tr, add), use.names=TRUE)
fwrite(allres, file.path(base,"data-dev/TRAINING-RESEARCH.csv"))
web <- f[needs_web==TRUE, .(uei, set, algo_tier, name, city, state, cand_ein, cand_name, jw, jac)]
setorder(web, set, -algo_tier)
fwrite(web, file.path(base,"data-dev/WEB-FINAL.csv"))

cat(sprintf("=== residual classification (medium effort) ===\ntotal unresolved: 260\n"))
cat(sprintf("structural seed:        %d\n", nrow(tr)))
cat(sprintf("local fuzzy + address:  %d\n", sum(i1)))
cat(sprintf("local fuzzy distinctive:%d\n", sum(i2)))
cat(sprintf("church/auto-exempt:     %d\n", sum(i3)))
cat(sprintf("individual:             %d\n", sum(i4)))
cat(sprintf("--------------------------------\nRESOLVED so far: %d (%.0f%%)\n", nrow(allres), 100*nrow(allres)/260))
cat(sprintf("TRUE web pass remaining (distinctive names, ProPublica): %d\n\n", nrow(web)))
cat("by set x algo_tier (web remaining):\n"); print(table(web$set, web$algo_tier))
cat("\n--- next ProPublica batch (first 20, NO/ZERO-tier = highest FN value) ---\n")
print(head(web[, .(name=substr(name,1,40), city, state)], 20), row.names=FALSE)
