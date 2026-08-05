# Address-confirmed matches whose NAME the Jaro-Winkler score misses:
# acronym/expansion, word-reorder. The token-set + acronym overlap should
# recover them; unrelated same-address orgs should stay unmatched.
nb_match <- function(qname, rname, same_addr = TRUE) {
  mq <- c(.id = "unique_entity_id", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  mr <- c(.ein = "ein", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  q <- np_normalize(np_query(data.frame(unique_entity_id = "q", name = qname,
        street = "402 S HIGH ST", city = "PORT MATILDA", state = "PA", zip = "16870",
        stringsAsFactors = FALSE), mq))
  raddr <- if (same_addr) list("402 S HIGH ST", "PORT MATILDA", "16870")
           else            list("15 FARAWAY RD", "PITTSBURGH", "15201")   # no geo match
  r <- np_normalize(np_reference(data.frame(ein = "R", name = rname,
        street = raddr[[1]], city = raddr[[2]], state = "PA", zip = raddr[[3]],
        stringsAsFactors = FALSE), mr))
  np_score(np_compare(q, r, block = "state"), method = "hier")$score
}

test_that("acronym / expansion matches are recovered when the address confirms", {
  expect_gte(nb_match("PORT MATILDA EMS", "PORT MATILDA EMERGENCY MEDICAL SERVICE"), 0.80)
})

test_that("word-reorder matches are recovered when the address confirms", {
  expect_gte(nb_match("HERITAGE MUSEUM OF NEWAYGO COUNTY",
                      "NEWAYGO COUNTY MUSEUM AND HERITAGE CENTER"), 0.78)
})

test_that("an unrelated org at the same address is NOT recovered", {
  # shares only 'LIHI'/one token: overlap below the floor, stays name-blind
  s <- nb_match("LIHI NORTHWEST BUILDING", "LIHI CASCADE SENIOR HOUSING")
  expect_lt(s, 0.65)
})

test_that("name-blind recovery does not fire without address confirmation", {
  # same acronym case but different address -> no geo gate, name stays 0
  s <- nb_match("PORT MATILDA EMS", "PORT MATILDA EMERGENCY MEDICAL SERVICE",
                same_addr = FALSE)
  expect_lt(s, 0.75)
})
