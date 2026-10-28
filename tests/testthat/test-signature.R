# The normalizer and its signature live in npnormalize. npmatch re-exports them
# unchanged, so what npmatch reports must be exactly what npnormalize reports:
# a stored artifact stamped with npmatch's signature has to keep validating.
# The signature's own behaviour (moves on logic, not on comments) is tested in
# npnormalize.

test_that("npmatch reports npnormalize's signature, the one it always reported", {
  expect_identical(np_normalize_signature(), npnormalize::np_normalize_signature())
  # the value every artifact built before the move was stamped with
  expect_identical(np_normalize_signature(), "v1-3e7b9f9d59bbb19e")
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
