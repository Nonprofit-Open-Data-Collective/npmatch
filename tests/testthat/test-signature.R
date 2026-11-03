# The normalizer and its signature live in npnormalize. npmatch re-exports them
# unchanged, so what npmatch reports must be exactly what npnormalize reports:
# a stored artifact stamped with npmatch's signature has to keep validating.
# The signature's own behaviour (moves on logic, not on comments) is tested in
# npnormalize.

test_that("npmatch reports npnormalize's signature, whatever it now is", {
  expect_identical(np_normalize_signature(), npnormalize::np_normalize_signature())
  # The pinned value is npnormalize's own, and it moves only when npnormalize
  # moves it deliberately. Every move invalidates stored keys, so the literal is
  # here to make an accidental one impossible to miss -- and to fail loudly when
  # the installed npnormalize is not the one this npmatch was written against:
  #   v1-3e7b9f9d59bbb19e  npnormalize 0.1.0-0.1.1, and npmatch 0.1.1 before
  #                        the normalizer moved out -- the move itself changed
  #                        nothing
  #   v1-6d90b52d8b781673  0.1.2 -- BUILDING became a unit designator
  #   v1-592912060053c4c3  0.1.3 -- a line naming several units keeps the most
  #                        specific one, and the house number is a whole token
  #   v1-1179714ce1e9d31f  0.1.4 -- the street parse reads an anchored box, and
  #                        street_has_box joined the address keys
  #   v1-533f186c123357cf  0.1.5 -- one box vocabulary, published for the
  #                        packages that each kept their own, and a lettered
  #                        box (PO BOX A) is a box
  #   v1-d49b18cc81ab79fb  0.1.6 -- the long-tail box spellings (PO BX, PB,
  #                        P BOX, POSTAL DRAWER, POSTAL OFC BOX, APDO) joined
  #                        the box vocabulary; a mail-only line (general
  #                        delivery, military mail, a bare drawer) blanks the
  #                        address key instead of keying it; and mail_key
  #                        carries the box plus its ZIP
  #   v1-59c6e84c5f38e9f5  0.1.7 -- a hyphen in a leading house number is
  #                        closed up rather than spaced, so the two filed
  #                        spellings of one Queens or Hawaii address share a
  #                        street_key; and eleven further spellings of
  #                        FOUNDATION fold, three of them a word a line break
  #                        split (FOUND is not one of them -- it is a word)
  #   v1-5e901add4a04a5d6  0.1.8 -- the house-number join leaves a lone compass
  #                        letter alone, because "1002-E SENECA ST" is 1002
  #                        East Seneca and 0.1.7 keyed it "1002E SENECA ST",
  #                        apart from the spelling of that door filed with a
  #                        space
  expect_identical(np_normalize_signature(), "v1-5e901add4a04a5d6")
})

test_that("the re-exported functions are npnormalize's own", {
  for (f in c("np_normalize", "np_normalize_signature", "np_name_core", "np_name_placeholder",
              "np_name_rules", "np_stopwords", "np_name_freq", "np_token_idf", "np_addr_freq")) {
    expect_identical(getExportedValue("npmatch", f), getExportedValue("npnormalize", f), label = f)
  }
})

test_that("npmatch no longer carries a copy of the normalizer", {
  ns <- asNamespace("npmatch")
  for (f in c(".np_basic_clean", ".np_abbrev", ".np_street_key", ".np_tokenize",
              ".np_signature_registry")) {
    expect_false(exists(f, envir = ns, inherits = FALSE), label = f)
  }
})

# ---------------------------------------------------------------------------
# Provenance: the label and the stamp (npnormalize 0.1.9's np_signature_history)
# ---------------------------------------------------------------------------

test_that(".np_sig_label names the release a signature came from", {
  skip_if_not_installed("npnormalize")
  lbl <- npmatch:::.np_sig_label(np_normalize_signature())
  expect_identical(lbl, "v1-5e901add4a04a5d6 (npnormalize 0.1.8)")
})

test_that(".np_sig_label distinguishes unrecognized from recognized-undated", {
  skip_if_not_installed("npnormalize")
  # A value npnormalize has never reported gets no row, which must read as
  # unknown rather than as a pre-split value with a missing version.
  expect_match(npmatch:::.np_sig_label("v1-0000000000000000"), "unrecognized", fixed = TRUE)
  # A pre-split npmatch signature is recognized, and is attributed to npmatch
  # rather than to npnormalize.
  expect_match(npmatch:::.np_sig_label("v1-421e1e2a6afb024e"), "npmatch", fixed = TRUE)
  # Degenerate input never errors -- this text goes into error messages.
  expect_identical(npmatch:::.np_sig_label(NULL), "(none recorded)")
  expect_identical(npmatch:::.np_sig_label(NA), "(none recorded)")
  expect_identical(npmatch:::.np_sig_label(""), "(none recorded)")
})

test_that("np_signature_stamp writes the bare signature on line 1", {
  p <- file.path(tempdir(), paste0("npp-sig-", sample.int(1e6, 1)))
  on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE)

  f <- np_signature_stamp(p)
  expect_true(file.exists(f))
  txt <- readLines(f)
  # Line 1 stays the bare hash: the hand-written files this replaces were one
  # line, and readers compare readLines(f)[1] to the installed signature.
  expect_identical(txt[1], np_normalize_signature())
  # Everything after it is commented, so a reader cannot mistake prose for a value.
  expect_true(all(grepl("^#", txt[-1])))
  expect_true(any(grepl("npnormalize 0.1.8", txt, fixed = TRUE)))
})

test_that("np_signature_stamp records a signature other than the installed one", {
  p <- file.path(tempdir(), paste0("npp-sig-", sample.int(1e6, 1)))
  on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE)

  # An older bundle's real provenance, not overwritten with today's value.
  f <- np_signature_stamp(p, signature = "v1-421e1e2a6afb024e")
  txt <- readLines(f)
  expect_identical(txt[1], "v1-421e1e2a6afb024e")
  expect_true(any(grepl("npmatch", txt, fixed = TRUE)))

  # overwrite = FALSE leaves that claim in place rather than restamping it.
  np_signature_stamp(p, overwrite = FALSE)
  expect_identical(readLines(f)[1], "v1-421e1e2a6afb024e")
  # The default does restamp, because a stamp describes the cache as it now is.
  np_signature_stamp(p)
  expect_identical(readLines(f)[1], np_normalize_signature())
})

test_that("np_signature_stamp refuses a path that is not a project", {
  p <- file.path(tempdir(), paste0("npp-sig-", sample.int(1e6, 1)))
  dir.create(p); on.exit(unlink(p, recursive = TRUE))
  expect_error(np_signature_stamp(p), "no 00_bmf/ folder", fixed = TRUE)
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  expect_error(np_signature_stamp(), "no project given", fixed = TRUE)
})

test_that("the cascade's normalizer refusal names both releases", {
  skip_if_not_installed("npnormalize")
  ref <- list(reference = data.frame(ein = "1", name_key = "A"),
              stamp = list(normalize_signature = "v1-421e1e2a6afb024e"))
  # A stale matchdb reference is refused, and the message dates both values so
  # the reader can see which way the drift runs without looking a hash up.
  expect_error(npmatch:::.np_unpack_reference(ref),
               "npmatch", fixed = TRUE)
  expect_error(npmatch:::.np_unpack_reference(ref),
               "npnormalize 0.1.8", fixed = TRUE)
})
