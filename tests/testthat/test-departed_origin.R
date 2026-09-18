# A departed defector's vote goes home -- docs/plans/prereg-departed-origin-return-2026-09-18.md
corpus <- data.table::data.table(
  election = c("vic2014", "vic2014", "vic2018", "vic2018", "vic2018", "vic2022", "vic2022", "vic2022"),
  seat     = "Morwell",
  party    = c("LNP", "ALP", "IND", "ALP", "LNP", "ALP", "LNP", "IND"),
  surname  = c("NORTHE", "RICHARDS", "NORTHE", "RICHARDS", "BOND", "MAXFIELD", "CAMERON", "LUND"),
  given    = c("Russell", "Mark", "Russell", "Mark", "Sheridan", "Kate", "Martin", "Tracie"),
  name     = NA_character_,
  pcv      = c(44.4, 40.0, 19.6, 34.2, 23.0, 31.4, 38.4, 2.8),
  votes    = c(444, 400, 196, 342, 230, 314, 384, 28))

test_that("departed_defectors finds the retired defector and names the origin party", {
  d <- departed_defectors("vic2018", "vic2022", corpus = corpus)
  expect_equal(nrow(d), 1L)
  expect_equal(d$party, "IND"); expect_equal(d$origin, "LNP"); expect_equal(d$lead_pcv, 19.6)
  # the leader re-standing under any label means no departure
  back <- rbind(corpus, data.table::data.table(election = "vic2022", seat = "Morwell", party = "IND",
                surname = "NORTHE", given = "Russell", name = NA_character_, pcv = 10, votes = 100))
  expect_equal(nrow(departed_defectors("vic2018", "vic2022", corpus = back)), 0L)
  # a leader with no major-party history in the seat is not a defector
  expect_equal(nrow(departed_defectors("vic2014", "vic2018", corpus = corpus)), 0L)
})

test_that("route_departed_origin moves frac * lead_pcv and conserves the row", {
  m <- matrix(c(23, 28.2, 34.2), 1, dimnames = list("Morwell", c("LNP", "IND", "ALP")))
  r <- route_departed_origin(m, "vic2018", "vic2022", 0.5, corpus = corpus)
  expect_equal(unname(r["Morwell", "LNP"]), 23 + 9.8)
  expect_equal(unname(r["Morwell", "IND"]), 28.2 - 9.8)
  expect_equal(sum(r), sum(m))
  expect_equal(attr(r, "departed_origin")$applied, 1L)
  expect_identical(route_departed_origin(m, "vic2018", "vic2022", NULL, corpus = corpus), m)
  # a missing column is skipped and NAMED, never silently dropped
  m2 <- m[, c("IND", "ALP"), drop = FALSE]
  r2 <- route_departed_origin(m2, "vic2018", "vic2022", 0.5, corpus = corpus)
  expect_equal(attr(r2, "departed_origin")$skipped, "Morwell/IND->LNP")
  expect_equal(r2[1, ], m2[1, ])
})

test_that("fit_departed_origin_return excludes the target pair and clips to [0, 1]", {
  pairs <- list(list(election = "vic2018", prev = "vic2014"), list(election = "vic2022", prev = "vic2018"))
  f <- fit_departed_origin_return("vic2022", corpus = corpus, pairs = pairs, min_n = 1L)
  expect_equal(f$n, 0L); expect_null(f$frac)          # the only case IS the target
  g <- fit_departed_origin_return("nsw2023", corpus = corpus, pairs = pairs, min_n = 1L)
  expect_equal(g$n, 1L); expect_true(g$frac >= 0 && g$frac <= 1)
})
