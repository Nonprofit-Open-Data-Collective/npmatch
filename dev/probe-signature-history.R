#!/usr/bin/env Rscript
# ============================================================================
# probe-signature-history.R -- does np_normalize_signature() actually track the
# normalizer's real history?
#
# The unit tests demonstrate the property against synthetic edits. This checks
# it against every commit that has ever touched R/normalize.R or R/block.R, and
# it is the stronger evidence, because two of those commits are a known natural
# experiment:
#
#   5e23269  "Fix apostrophe normalization ..."  -- rewrote .np_strip_joiners()
#            to DELETE apostrophes rather than space them. Moved the pfmatch
#            5,000-grant benchmark from 2,746 to 2,821 YES. The signature MUST
#            move here: any name_key cached before it is wrong after it.
#
#   407f48f  "docs: document the real veto rules ..." -- comment-only in
#            normalize.R. The signature MUST NOT move: invalidating every
#            cached artifact on a documentation edit is how a staleness check
#            earns a reputation for crying wolf.
#
# Each commit's normalize.R + block.R are sourced into a bare environment whose
# parent is the installed namespace, and hashed with the same internals the
# exported function uses.
# ============================================================================
suppressWarnings(suppressMessages(devtools::load_all(".", quiet = TRUE)))

say <- function(...) { cat(sprintf(...), "\n"); flush.console() }
hr  <- function() cat(strrep("=", 78), "\n")

FILES <- c("R/normalize.R", "R/block.R")
shas <- rev(system2("git", c("log", "--format=%h", "--", FILES),
                    stdout = TRUE))
say("commits touching %s: %d", paste(FILES, collapse = " + "), length(shas))

sig_at <- function(sha) {
  env <- new.env(parent = asNamespace("npmatch"))
  for (f in FILES) {
    src <- suppressWarnings(system2("git", c("show", paste0(sha, ":", f)),
                                    stdout = TRUE, stderr = FALSE))
    if (!length(src)) next                       # file did not exist yet
    tf <- tempfile(fileext = ".R"); on.exit(unlink(tf), add = TRUE)
    writeLines(src, tf)
    ok <- tryCatch({ sys.source(tf, envir = env, keep.source = FALSE); TRUE },
                   error = function(e) { say("  ! %s %s: %s", sha, f,
                                             conditionMessage(e)); FALSE })
    if (!ok) return(NULL)
  }
  npmatch:::.np_signature_from(env)
}

hr(); say("%-9s %-22s %-8s %s", "commit", "signature", "moved?", "components changed")
hr()

prev <- NULL; prev_sha <- NULL; rows <- list()
for (s in shas) {
  cur <- sig_at(s)
  if (is.null(cur)) next
  if (is.null(prev)) {
    say("%-9s %-22s %-8s %s", s, cur$signature, "-",
        sprintf("(baseline, %d components)", length(cur$components)))
  } else {
    moved <- !identical(cur$signature, prev$signature)
    shared <- intersect(names(cur$components), names(prev$components))
    diff <- shared[cur$components[shared] != prev$components[shared]]
    added <- setdiff(names(cur$components), names(prev$components))
    lbl <- c(diff, if (length(added)) sprintf("+%s", added))
    say("%-9s %-22s %-8s %s", s, cur$signature, if (moved) "YES" else "no",
        if (length(lbl)) paste(lbl, collapse = ", ") else "-")
    rows[[length(rows) + 1L]] <- list(sha = s, moved = moved, changed = diff)
  }
  prev <- cur; prev_sha <- s
}

## ---- the two assertions that matter ----------------------------------------
hr(); say("natural experiment"); hr()
fail <- 0L
chk <- function(lbl, ok, note) {
  say("  %-46s %s   %s", lbl, if (ok) "PASS" else "**FAIL**", note)
  if (!ok) fail <<- fail + 1L
}
get_row <- function(pat) {
  hit <- Filter(function(r) startsWith(r$sha, pat), rows)
  if (length(hit)) hit[[1]] else NULL
}

r_apos <- get_row("5e23269")
if (is.null(r_apos)) {
  chk("5e23269 apostrophe fix moves it", FALSE, "commit not reached")
} else {
  chk("5e23269 apostrophe fix moves it", r_apos$moved,
      sprintf("changed: %s", paste(r_apos$changed, collapse = ", ")))
}

r_doc <- get_row("407f48f")
if (is.null(r_doc)) {
  chk("407f48f comment-only leaves it alone", FALSE, "commit not reached")
} else {
  chk("407f48f comment-only leaves it alone", !r_doc$moved,
      if (r_doc$moved) sprintf("changed: %s", paste(r_doc$changed, collapse = ", "))
      else "no component moved")
}

hr()
if (fail == 0L) {
  say("Signature tracks the normalizer's real history.")
} else {
  say("%d assertion(s) failed.", fail)
}
quit(save = "no", status = if (fail == 0L) 0L else 1L)
