test_that("name_key uppercases, de-punctuates, and strips trailing legal suffixes", {
  d <- np_query(data.frame(unique_entity_id = c("1","2","3"),
                           name = c("Widget, LLC", "Acme Corp.", "Globex Inc"),
                           state = "AZ", stringsAsFactors = FALSE),
                c(.id = "unique_entity_id", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_key, c("WIDGET", "ACME", "GLOBEX"))
  expect_equal(d$name_form, c("LLC", "CORP", "INC"))
})

test_that("a leading THE is stripped from the match key but kept in name_full", {
  d <- np_query(data.frame(unique_entity_id = c("1", "2"),
                           name = c("THE SAN DIEGO EDUCATION FOUNDATION", "THEATER GUILD"),
                           state = "CA", stringsAsFactors = FALSE),
                c(.id = "unique_entity_id", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_key, c("SAN DIEGO EDUCATION", "THEATER GUILD"))  # THE stripped, THEATER intact
  expect_match(d$name_full[1], "^THE ")
})

test_that("generation, number, and ordinal features are extracted", {
  d <- np_reference(data.frame(ein = c("1","2","3","4"),
        name = c("KEN GRIFFEY JR", "IBEW LOCAL 32", "FIRST BAPTIST CHURCH",
                 "KEN GRIFFEY SR"),
        state = "AK", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_gen, c("JR", NA, NA, "SR"))       # JR/SR only; roman is not generational
  expect_equal(d$name_gen_rank, c("2", NA, NA, "1"))
  expect_equal(d$name_nums, c(NA, "32", NA, NA))
  expect_equal(d$name_ord, c(NA, NA, "1", NA))
})

test_that("ordinal words are not treated as generation markers", {
  d <- np_reference(data.frame(ein = "1", name = "SECOND BAPTIST CHURCH",
                               state = "AK", stringsAsFactors = FALSE),
                    c(.ein = "ein", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_true(is.na(d$name_gen))
  expect_equal(d$name_ord, "2")
})

test_that("address normalization splits zip5 and strips the unit from the key", {
  d <- np_query(data.frame(unique_entity_id = "1", name = "X",
                           street = "3406 GLACIER HWY STE A", zip = "99801-9501",
                           state = "AK", stringsAsFactors = FALSE),
                c(.id = "unique_entity_id", name = "name", street = "street",
                  zip5 = "zip", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$zip5, "99801")
  expect_equal(d$street_key, "3406 GLACIER HWY")
  expect_equal(d$street_unit, "STE A")
})

test_that("possessive apostrophes are deleted, not spaced, so the query matches the BMF", {
  # The IRS BMF holds "St. Luke's Hospital" as "ST LUKES HOSPITAL". Turning the
  # apostrophe into a space would give "ST LUKE S HOSPITAL" on the query side
  # only, and no possessive name could ever clear an exact-name pass.
  q <- np_query(data.frame(unique_entity_id = as.character(1:4),
        name = c("BO'S PLACE", "St Luke's Hospital",
                 "The Children's Museum of NH", "L'Arche Mobile"),
        state = "TX", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", state = "state"))
  r <- np_reference(data.frame(ein = as.character(1:4),
        name = c("BOS PLACE", "ST LUKES HOSPITAL",
                 "CHILDRENS MUSEUM OF NH", "LARCHE MOBILE"),
        state = "TX", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", state = "state"))
  expect_equal(np_normalize(q)$name_key, np_normalize(r)$name_key)
})

test_that("periods join an initialism but still break words that were already apart", {
  d <- np_query(data.frame(unique_entity_id = c("1", "2", "3"),
        name = c("F.I.N.D.", "U.S.A. Today Fund", "Acme Inc. of America"),
        state = "CA", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_full, c("FIND", "USA TODAY FUND", "ACME INC OF AMERICA"))
})

test_that("hyphens, ampersands, and slashes still separate tokens", {
  # These survive in the BMF on both sides, so they must keep the old behaviour.
  d <- np_query(data.frame(unique_entity_id = c("1", "2", "3"),
        name = c("MID-ATLANTIC MINISTRIES", "Smith & Jones Fund", "Vedic Society C/O Ed"),
        state = "MD", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_full,
               c("MID ATLANTIC MINISTRIES", "SMITH AND JONES FUND",
                 "VEDIC SOCIETY C O ED"))
})

test_that("990-style abbreviations expand; PHYS is left alone", {
  expect_equal(np_name_core(c("NYP FDN", "ACME HLTH SYS", "UNIVERSITY REG MED CTR",
                              "Pine Hosp Fndtn", "Delta Mgmt Srvcs", "PHYS ED BOOSTERS")),
               c("NYP FOUNDATION", "ACME HEALTH SYSTEM", "UNIVERSITY REGIONAL MEDICAL CENTER",
                 "PINE HOSPITAL FOUNDATION", "DELTA MANAGEMENT SERVICES", "PHYS ED BOOSTERS"))
})

test_that("name_core keeps a charity and its foundation apart", {
  # name_key strips trailing FOUNDATION / TRUST / SOCIETY, so these collide there
  x <- c("PEOPLE OF FAITH INC", "PEOPLE OF FAITH FOUNDATION INC",
         "Pueblo Zoological Society", "Pueblo Zoological Society Foundation",
         "Greater Horizons Foundation", "Greater Horizons Trust")
  k <- np_name_core(x)
  expect_equal(k, c("PEOPLE FAITH", "PEOPLE FAITH FOUNDATION",
                    "PUEBLO ZOOLOGICAL SOCIETY", "PUEBLO ZOOLOGICAL SOCIETY FOUNDATION",
                    "GREATER HORIZONS FOUNDATION", "GREATER HORIZONS TRUST"))
  expect_equal(length(unique(k)), 6L)
  # connector words and legal forms drop anywhere; possessives join
  expect_equal(np_name_core(c("The Sons of the Republic of Texas", "SONS REPUBLIC TEXAS INC",
                              "Abilities at Eagle's Nest, Inc.", "THE CO")),
               c("SONS REPUBLIC TEXAS", "SONS REPUBLIC TEXAS", "ABILITIES AT EAGLES NEST", ""))
  expect_equal(np_name_core(c(NA, "")), c("", ""))
  expect_true(np_name_placeholder(NA))
  # the column np_normalize() adds is the same rule
  d <- np_normalize(np_reference(data.frame(ein = "1", name = x[2], state = "CO"),
                                 c(.ein = "ein", name = "name", state = "state")))
  expect_equal(d$name_core, k[2])
})

test_that("placeholder names are flagged and get no candidates", {
  x <- c("SEE SCHEDULE O", "See Attached", "N/A", "SAME AS ABOVE", "NONE", "100", "",
         "Acme Fdn", "See Change Coalition", "NA Health Center")
  expect_equal(np_name_placeholder(x), c(rep(TRUE, 7), FALSE, FALSE, FALSE))
  q <- np_normalize(np_query(data.frame(id = c("1", "2"), name = c("SEE SCHEDULE O", "ACME FDN"), state = "AZ"),
                             c(.id = "id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = c("9", "8"), name = c("SEE SCHEDULE O", "ACME FOUNDATION"), state = "AZ"),
                                 c(.ein = "ein", name = "name", state = "state")))
  # a state block pairs all 4 combinations; the placeholder query loses its two
  b <- np_block(q, r, by = "state", token = FALSE)
  expect_equal(as.data.frame(b)[, c(".x", ".y")], data.frame(.x = 2L, .y = 1:2))
  b <- np_block(q, r, by = c("state", "name_key"), token = FALSE)
  expect_equal(as.data.frame(b)[, c(".x", ".y")], data.frame(.x = 2L, .y = 2L))
})

test_that("letters with no accent to drop fold to ASCII instead of splitting the word", {
  # matchdb's md_light_key() maps the same letters, and the two keys have to
  # agree character for character or a cached reference key never meets the
  # query key normalized at run time. An unmapped letter becomes a space, which
  # used to split the word it sat in: "STRA E FUND", "RESUND TRUST".
  x <- c("Stra\u00dfe Fund", "\u00d8resund Trust", "\u0141ucja Society",
         "\u0110uro Institute", "\u00c6on Fund", "\u0152uvre Fund",
         "\u00deor Foundation", "Mu\u00f1oz Center", "\u00c9cole Fund")
  expect_equal(np_name_core(x),
               c("STRASSE FUND", "ORESUND TRUST", "LUCJA SOCIETY",
                 "DURO INSTITUTE", "AEON FUND", "OEUVRE FUND",
                 "THOR FOUNDATION", "MUNOZ CENTER", "ECOLE FUND"))
  # the fold is case-blind: the key cannot depend on how the name was written
  expect_equal(np_name_core(c("stra\u00dfe fund", "\u00f8resund trust")),
               c("STRASSE FUND", "ORESUND TRUST"))
  # a spelled-out name reaches the same key, which is the point of folding
  expect_equal(np_name_core("Strasse Fund"), np_name_core("Stra\u00dfe Fund"))
})

test_that("tabs and newlines separate tokens rather than joining words", {
  expect_equal(np_name_core("Acme\tHealth\nFund"), "ACME HEALTH FUND")
})

test_that("np_name_rules() exposes the tables the normalizer uses", {
  r <- np_name_rules()
  expect_named(r, c("abbrev", "core_stop", "legal_suffixes", "special_letters",
                    "placeholder_re", "placeholder_tok"))
  expect_equal(r$special_letters[["\u00df"]], "SS")
  expect_equal(r$special_letters[["\u00de"]], "TH")
  expect_equal(r$abbrev[["FDN"]], "FOUNDATION")
  expect_false("PHYS" %in% names(r$abbrev))
  expect_true(all(c("OF", "INC") %in% r$core_stop))
  expect_false(any(c("FOUNDATION", "TRUST") %in% r$core_stop))
})

test_that("a missing street or name is empty, never the text NA", {
  # paste() inside the token replacement used to turn NA into "NA", so every
  # record with no street had street_key "NA" and agreed with every other one
  map <- c(.ein = "ein", name = "nm", street = "st", city = "ci", state = "s", zip5 = "z")
  d <- data.frame(ein = c("EIN-10-0000001", "EIN-10-0000002", "EIN-10-0000003"),
                  nm = c("A CLUB", "B CLUB", NA), st = c(NA, "", "1 MAIN ST"),
                  ci = "X", s = "GA", z = "30341", stringsAsFactors = FALSE)
  r <- np_normalize(np_reference(d, map))
  expect_identical(r$street_key[1:2], c("", ""))           # NA and "" alike
  expect_true(is.na(r$street_name[1]) && is.na(r$street_name[2]))
  expect_identical(r$street_key[3], "1 MAIN ST")
  expect_false(any(c(r$street_key, r$street_name, r$name_key, r$name_full) %in% "NA"))
  expect_identical(r$name_key[3], "")
  q <- np_normalize(np_query(data.frame(id = 1:2, nm = c("A", "B"), st = NA),
                             c(.id = "id", name = "nm", street = "st")))
  expect_identical(q$street_key, c("", ""))
})

test_that("a street literally named NA is still a street", {
  r <- np_normalize(np_reference(
    data.frame(ein = "EIN-10-0000001", nm = "A CLUB", st = "12 NA ST", stringsAsFactors = FALSE),
    c(.ein = "ein", name = "nm", street = "st")))
  expect_identical(r$street_key, "12 NA ST")
})

test_that("two records with no street do not agree on the street", {
  qmap <- c(.id = "id", name = "nm", street = "st", city = "ci", state = "s", zip5 = "z")
  rmap <- c(.ein = "ein", name = "nm", street = "st", city = "ci", state = "s", zip5 = "z")
  q <- np_normalize(np_query(data.frame(id = c("q1", "q2", "q3"), nm = "ACME CLUB",
                                        st = c(NA, "", "1 MAIN ST"), ci = "X", s = "GA",
                                        z = "30341", stringsAsFactors = FALSE), qmap))
  r <- np_normalize(np_reference(data.frame(ein = c("EIN-10-0000001", "EIN-10-0000002"),
                                            nm = "ACME CLUB", st = c(NA, "1 MAIN ST"),
                                            ci = "X", s = "GA", z = "30341",
                                            stringsAsFactors = FALSE), rmap))
  p <- as.data.frame(np_compare(q, r, profile = "street_full"))
  expect_true("street_key" %in% names(p))
  st <- function(id, ein) p$street_key[p$.id == id & p$.ein == ein]
  # missing on both sides, or on one side: no street evidence either way
  expect_equal(st("q1", "EIN-10-0000001"), 0)
  expect_equal(st("q2", "EIN-10-0000001"), 0)
  expect_equal(st("q1", "EIN-10-0000002"), 0)
  # a real street still agrees with itself
  expect_equal(st("q3", "EIN-10-0000002"), 1)
})
