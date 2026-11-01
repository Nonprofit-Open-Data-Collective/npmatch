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
  expect_identical(np_normalize_signature(), "v1-592912060053c4c3")
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
