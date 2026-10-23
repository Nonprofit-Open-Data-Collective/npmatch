# Cluster roll-up and pair links on hand-built scored pairs. The cases: split
# evidence rolls up, a big cluster needs its brand, YES is left alone, and a
# thin win over a linked sibling is flagged.

mk_pairs <- function(rows) {
  p <- data.frame(rows, stringsAsFactors = FALSE)
  p$veto <- FALSE
  attr(p, "cmp_cols") <- c("name_key", "street_key", "zip5")
  p
}
# name_key / street_key / zip5 columns are the per-field similarities
pr <- function(id, ein, nm, st, zp, sc) {
  data.frame(.id = id, .ein = ein, name_key = nm, street_key = st, zip5 = zp, score = sc,
             stringsAsFactors = FALSE)
}

test_that("a name match on one member and an address match on another roll up", {
  pairs <- mk_pairs(rbind(pr("q1", "E1", 0.97, 0.30, 0.20, 0.70),   # the chapter by name
                          pr("q1", "E2", 0.55, 0.95, 1.00, 0.68),   # the sibling at the address
                          pr("q1", "E9", 0.60, 0.20, 0.10, 0.40)))
  tiered <- data.frame(.id = "q1", tier = "MAYBE", stringsAsFactors = FALSE)
  cl <- data.frame(cluster_id = "GRP-1", cluster_type = "group_exemption",
                   ein = c("E1", "E2", "E3"), size = 3L)
  r <- np_cluster_rollup(tiered, cl, pairs)
  expect_equal(r$cluster_id, "GRP-1")
  expect_equal(c(r$name_ein, r$addr_ein), c("E1", "E2"))
  expect_equal(r$basis, "small_cluster")
  expect_equal(r$n_members, 2L)
  expect_equal(r$cluster_score, (0.97 + 0.975) / 2)
})

test_that("a large cluster needs its brand in the query name", {
  pairs <- mk_pairs(rbind(pr("q1", "E1", 0.95, 0.10, 0.00, 0.60),
                          pr("q1", "E2", 0.40, 0.95, 1.00, 0.60)))
  tiered <- data.frame(.id = "q1", tier = "NO")
  cl <- data.frame(cluster_id = "BRD-ROTARY", cluster_type = "brand", ein = c("E1", "E2"),
                   size = 9000L, brand_tokens = "ROTARY CLUB INTERNATIONAL")
  expect_equal(nrow(np_cluster_rollup(tiered, cl, pairs)), 0)          # no query names
  q_other <- data.frame(.id = "q1", name_key = "SPRINGFIELD SUNRISE BREAKFAST CLUB")
  expect_equal(nrow(np_cluster_rollup(tiered, cl, pairs, query = q_other)), 0)
  q_brand <- data.frame(.id = "q1", name_key = "ROTARY CLUB OF SPRINGFIELD")
  r <- np_cluster_rollup(tiered, cl, pairs, query = q_brand)
  expect_equal(r$basis, "brand")
})

test_that("YES queries, weak evidence and unclustered candidates do not roll up", {
  pairs <- mk_pairs(rbind(pr("q1", "E1", 0.97, 0.30, 0.20, 0.90),
                          pr("q1", "E2", 0.50, 0.95, 1.00, 0.60),
                          pr("q2", "E1", 0.80, 0.30, 0.20, 0.50),   # name too weak
                          pr("q2", "E2", 0.50, 0.95, 1.00, 0.60),
                          pr("q3", "X1", 0.99, 0.99, 1.00, 0.70)))  # in no cluster
  tiered <- data.frame(.id = c("q1", "q2", "q3"), tier = c("YES", "MAYBE", "MAYBE"))
  cl <- data.frame(cluster_id = "GRP-1", cluster_type = "group_exemption",
                   ein = c("E1", "E2"), size = 2L)
  expect_equal(nrow(np_cluster_rollup(tiered, cl, pairs)), 0)
})

test_that("of several qualifying clusters the narrowest family wins ties", {
  pairs <- mk_pairs(rbind(pr("q1", "E1", 0.95, 0.90, 1.00, 0.70),
                          pr("q1", "E2", 0.50, 0.95, 1.00, 0.60)))
  tiered <- data.frame(.id = "q1", tier = "MAYBE")
  cl <- data.frame(cluster_id = c("SYS-1", "SYS-1", "CTN-1", "CTN-1"),
                   cluster_type = c("related_system", "related_system", "co_tenant", "co_tenant"),
                   ein = c("E1", "E2", "E1", "E2"), size = c(20L, 20L, 2L, 2L))
  expect_equal(np_cluster_rollup(tiered, cl, pairs)$cluster_id, "CTN-1")
  expect_equal(np_cluster_rollup(tiered, cl, pairs, types = "related_system")$cluster_id, "SYS-1")
})

test_that("a thin YES over a linked runner-up is a family contest", {
  pairs <- mk_pairs(rbind(pr("q1", "H", 0.99, 1, 1, 0.92), pr("q1", "F", 0.95, 1, 1, 0.90),
                          pr("q2", "A", 0.99, 1, 1, 0.92), pr("q2", "B", 0.95, 1, 1, 0.90),
                          pr("q3", "H", 0.99, 1, 1, 0.95), pr("q3", "F", 0.60, 1, 1, 0.70)))
  tiered <- data.frame(.id = c("q1", "q2", "q3"), tier = c("YES", "YES", "YES"))
  cl <- data.frame(cluster_id = c("SYS-H", "SYS-H"), cluster_type = "related_system",
                   ein = c("H", "F"))
  r <- np_pair_links(tiered, cl, pairs)
  expect_equal(r$linked, c(TRUE, FALSE, TRUE))
  expect_equal(r$link_types[1], "related_system")
  expect_equal(r$family_contest, c(TRUE, FALSE, FALSE))      # q3 wins by 0.25
  expect_equal(r$runner_up_ein, c("F", "B", "F"))
})
