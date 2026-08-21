# np_normalize_signature() has one job: move when the normalizer's behaviour
# moves, and stay put otherwise. Both halves need testing -- a signature that
# never changes is useless, and one that changes on a comment is worse than
# useless because people route around it.

test_that("the signature is stable within a session and across calls", {
  expect_identical(np_normalize_signature(), np_normalize_signature())
  expect_match(np_normalize_signature(), "^v1-[0-9a-f]{16}$")
})

test_that("detail = TRUE localizes the signature to its components", {
  d <- np_normalize_signature(detail = TRUE)
  expect_s3_class(d, "np_signature")
  expect_identical(d$signature, np_normalize_signature())
  expect_true(length(d$components) > 30L)
  expect_true(all(grepl("^[0-9a-f]{32}$", d$components)))
  # every registered name is reported, so a mismatch is attributable
  reg <- sort(unique(unlist(npmatch:::.np_signature_registry(), use.names = FALSE)))
  expect_identical(names(d$components), reg)
})

test_that("a comment-only edit does not move the signature", {
  # the property that makes the check tolerable to live with: reformatting and
  # documentation must not invalidate a cache. Simulated by hashing a function
  # against a commented copy of itself.
  f <- npmatch:::.np_strip_lead_the
  g <- eval(parse(text = paste0(
    "function(x) {\n",
    "  # a newly added comment that changes nothing\n",
    "  out <- sub('^THE ', '', x)\n",
    "  ifelse(nzchar(out), out, x)  # trailing comment\n",
    "}")), envir = asNamespace("npmatch"))
  txt <- function(fn) paste(deparse(utils::removeSource(fn), width.cutoff = 500L,
                                    control = c("keepInteger", "keepNA")),
                            collapse = "\n")
  # same logic, different comments and quoting -> same canonical text
  expect_identical(txt(f), txt(g))
})

test_that("a rule-table change moves the signature", {
  base <- np_normalize_signature()
  ns <- asNamespace("npmatch")
  old <- get(".np_abbrev", envir = ns)
  unlockBinding(".np_abbrev", ns)
  on.exit({ assign(".np_abbrev", old, envir = ns); lockBinding(".np_abbrev", ns) },
          add = TRUE)

  assign(".np_abbrev", c(old, ZZZTEST = "ZZZ"), envir = ns)
  expect_false(identical(np_normalize_signature(), base))

  # and it is attributable to the table that actually moved
  d <- np_normalize_signature(detail = TRUE)
  assign(".np_abbrev", old, envir = ns)
  d0 <- np_normalize_signature(detail = TRUE)
  moved <- names(d$components)[d$components != d0$components]
  expect_identical(moved, ".np_abbrev")
})

test_that("a function-body change moves the signature", {
  base <- np_normalize_signature()
  ns <- asNamespace("npmatch")
  old <- get(".np_strip_lead_the", envir = ns)
  unlockBinding(".np_strip_lead_the", ns)
  on.exit({ assign(".np_strip_lead_the", old, envir = ns)
            lockBinding(".np_strip_lead_the", ns) }, add = TRUE)

  # strip "THE " *and* "A " -- a real behaviour change
  assign(".np_strip_lead_the", function(x) {
    out <- sub("^(THE|A) ", "", x)
    ifelse(nzchar(out), out, x)
  }, envir = ns)
  expect_false(identical(np_normalize_signature(), base))
})

test_that("the registry and the exemption list partition the normalize path", {
  # Guard against the registry silently falling behind the code: a new rule
  # table or normalizer helper must be classified as covered or exempt, or this
  # fails. Without it the signature could miss real drift.
  ns <- asNamespace("npmatch")
  covered <- unlist(npmatch:::.np_signature_registry(), use.names = FALSE)
  exempt  <- npmatch:::.np_signature_exempt()

  # everything defined in normalize.R, discovered by re-parsing the source
  src <- file.path(testthat::test_path("..", ".."), "R", "normalize.R")
  skip_if_not(file.exists(src), "source tree not available (installed package)")
  top <- grep("^(\\.np_|np_)[A-Za-z0-9_.]* *<-", readLines(src), value = TRUE)
  defined <- unique(sub(" *<-.*$", "", top))

  unclassified <- setdiff(defined, c(covered, exempt))
  expect_identical(unclassified, character(0),
    info = paste("unclassified normalize.R objects:",
                 paste(unclassified, collapse = ", ")))
})

test_that("every registered name resolves", {
  reg <- unlist(npmatch:::.np_signature_registry(), use.names = FALSE)
  ns <- asNamespace("npmatch")
  missing <- reg[!vapply(reg, exists, logical(1), envir = ns, inherits = FALSE)]
  expect_identical(missing, character(0),
    info = paste("registered but absent:", paste(missing, collapse = ", ")))
})
