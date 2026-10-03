test_that("zero_unnominated zeroes a class with no candidate and renormalises", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  sh <- matrix(c(40, 35, 25,
                 50, 30, 20), nrow = 2, byrow = TRUE,
               dimnames = list(c("Narracan", "Morwell"), c("ALP", "LNP", "IND")))
  tg <- data.table::data.table(seat = c("Narracan", "Narracan", "Morwell", "Morwell", "Morwell"),
                               party = c("LNP", "IND", "ALP", "LNP", "IND"),
                               votes = c(100, 50, 10, 10, 10))
  out <- zero_unnominated(sh, tg, "test")
  expect_equal(unname(out["Narracan", "ALP"]), 0)
  expect_equal(unname(rowSums(out)), c(100, 100))
  expect_equal(out["Morwell", ], sh["Morwell", ])          # everyone stood: untouched
  expect_equal(unname(out["Narracan", "LNP"]), 35 / 60 * 100)
})

test_that("zero_unnominated never zeroes a class the result table does not use, or an unknown seat", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  sh <- matrix(c(40, 35, 25), nrow = 1, dimnames = list("Nowhere-Not-A-Seat", c("ALP", "NAT", "LNP")))
  tg <- data.table::data.table(seat = "Elsewhere", party = c("ALP", "LNP"), votes = c(1, 1))
  expect_equal(zero_unnominated(sh, tg, "test"), sh)     # seat absent from the table
  sh2 <- matrix(c(40, 35, 25), nrow = 1, dimnames = list("Elsewhere", c("ALP", "NAT", "LNP")))
  out <- zero_unnominated(sh2, tg, "test")
  expect_gt(out[1, "NAT"], 0)                             # NAT never appears in the result table
})

test_that("zero_unnominated is a no-op when the switch is off", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "0")
  sh <- matrix(c(40, 60), nrow = 1, dimnames = list("A", c("ALP", "LNP")))
  expect_identical(zero_unnominated(sh, data.table::data.table(seat = "A", party = "LNP", votes = 1), "t"), sh)
})

test_that("mode 2 sends the freed share where the flow matrix says, conditional first", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "2")
  sh <- matrix(c(40, 40, 10, 10), nrow = 1, dimnames = list("Richmond", c("ALP", "GRN", "LNP", "OTH")))
  # Kew carries an LNP candidate, so LNP is a class the result table uses
  tg <- data.table::data.table(seat = c("Richmond", "Richmond", "Richmond", "Kew"),
                               party = c("ALP", "GRN", "OTH", "LNP"), votes = 1)
  fl <- list(conditional = list("LNP|ALP+GRN+OTH" = c(ALP = 20, GRN = 70, OTH = 10)),
             pooled = list(LNP = c(ALP = 90, GRN = 10)))
  out <- zero_unnominated(sh, tg, "test", flows = fl)
  expect_equal(unname(out[1, "LNP"]), 0)
  expect_equal(unname(out[1, c("ALP", "GRN", "OTH")]), c(42, 47, 11))
  fl2 <- list(conditional = list(), pooled = list(LNP = c(ALP = 90, GRN = 10)))
  out2 <- zero_unnominated(sh, tg, "test", flows = fl2)   # pooled fallback, OTH gets none
  expect_equal(unname(out2[1, c("ALP", "GRN", "OTH")]), c(49, 41, 10))
  expect_equal(sum(out2), 100)
})

.live_fixture <- function() {
  seats <- c("Richmond", "Kew", "Narracan")
  prior <- data.table::data.table(election = "vic2022", seat = rep(seats, each = 4),
                                  party = rep(c("ALP", "LNP", "GRN", "IND"), 3))
  # vic2026: Narracan has no GRN candidate; everything else stands. 11 of 12 = 92%.
  now <- data.table::data.table(election = "vic2026", seat = rep(seats, each = 4),
                                party = rep(c("ALP", "LNP", "GRN", "IND"), 3))
  now <- now[!(now$seat == "Narracan" & now$party == "GRN")]
  list(seats = seats, corpus = rbind(prior, now))
}
.live_shares <- function(seats) {
  matrix(c(40, 30, 20, 10), nrow = 3, ncol = 4, byrow = TRUE,
         dimnames = list(seats, c("ALP", "LNP", "GRN", "IND")))
}
.live_flows <- list(conditional = list(), pooled = list(GRN = c(ALP = 50, LNP = 50)))

test_that("live: a complete post-close list zeroes the non-standing party and sends its share by flows", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-11-10"))
  expect_equal(unname(out["Narracan", "GRN"]), 0)
  expect_output(zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-11-10")), "applied: 3 cells changed")
  expect_equal(unname(out["Narracan", c("ALP", "LNP", "IND")]), c(50, 40, 10))   # GRN 20 split 50/50 ALP/LNP
  expect_equal(out["Richmond", ], sh["Richmond", ])                              # everyone stood
  expect_equal(unname(rowSums(out)), c(100, 100, 100))
})

test_that("live: a no-op, saying so, with no nominations, before close, or on an incomplete list", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  # empty nominations: vic2022 rows only, no vic2026 candidacies at all
  empty <- fx$corpus[fx$corpus$election == "vic2022"]
  expect_output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = empty, today = as.Date("2026-11-10")), "NOT applied")
  expect_identical(out, sh)
  # before nominations close, even with a full-looking list
  expect_output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-10-03")), "not closed")
  expect_identical(out, sh)
  # partial list (the Wikipedia situation): 1 of 12 candidacies is far below the floor
  part <- rbind(empty, fx$corpus[fx$corpus$election == "vic2026"][1])
  expect_output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = part, today = as.Date("2026-11-10")), "incomplete")
  expect_identical(out, sh)
  # switch off
  withr::local_envvar(AUSPOL_NOM_LIVE = "0")
  expect_output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-11-10")), "NOT applied")
  expect_identical(out, sh)
})

test_that("live: AUSPOL_NOM_LIVE=1 skips the date test but never the completeness floor", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-10-03"))
  expect_equal(unname(out["Narracan", "GRN"]), 0)
  partial <- fx$corpus[!(fx$corpus$election == "vic2026" & fx$corpus$seat == "Kew")]
  expect_output(out2 <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = partial, today = as.Date("2026-10-03")), "have no candidacy|incomplete")
  expect_identical(out2, sh)
})

test_that("a seat left with no standing class is kept unchanged, never NaN (review, both modes)", {
  sh <- matrix(c(50, 50, 0, 60, 40, 0), nrow = 2, byrow = TRUE,
               dimnames = list(c("A", "B"), c("ALP", "LNP", "IND")))
  tg <- data.table::data.table(seat = c("A", "B", "B"), party = c("IND", "ALP", "LNP"), votes = 1)
  fl <- list(conditional = list(), pooled = list(ALP = c(LNP = 100), LNP = c(ALP = 100)))
  for (m in c("1", "2")) {
    withr::local_envvar(AUSPOL_NOM_ZERO = m)
    out <- zero_unnominated(sh, tg, "test", flows = fl)
    expect_true(all(is.finite(out)))
    expect_equal(out["A", ], sh["A", ])
    expect_equal(out["B", ], sh["B", ])
  }
})

test_that("live: AUSPOL_NOM_ZERO=0 on a complete list logs a no-op, never 'applied'", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "0")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  txt <- paste(capture.output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-11-10"))), collapse = "\n")
  expect_match(txt, "no-op: nothing changed")
  expect_false(grepl("applied:", txt, fixed = TRUE))
  expect_identical(out, sh)
})

test_that("live: a class absent from the nomination table is reported as skipped", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture()
  sh <- cbind(.live_shares(fx$seats), NAT = 0)
  sh[, "NAT"] <- 5; sh[, "ALP"] <- 35
  expect_output(zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-11-10")),
                "absent from the nomination table: NAT")
})

test_that("live: Labor missing in some seats keeps the gate closed even when the total count is above the floor", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  # drop Labor in Kew only: 10 of 12 candidacies vs 12 at vic2022 = 83%... so pad: see below
  extra <- data.table::data.table(election = "vic2026", seat = rep("Kew", 3), party = c("IND", "OTH", "ONP"))
  c2 <- fx$corpus[!(fx$corpus$election == "vic2026" & fx$corpus$seat == "Kew" & fx$corpus$party == "ALP")]
  c2 <- rbind(c2, extra)
  expect_gt(sum(c2$election == "vic2026") / sum(c2$election == "vic2022"), 0.85)
  txt <- paste(capture.output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = c2, today = as.Date("2026-11-10"))), collapse = "\n")
  expect_match(txt, "ALP has no candidacy in 1 of 3 seats")
  expect_identical(out, sh)
})

test_that("live: the gate stays shut on 2026-11-09 and opens on 2026-11-10", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  expect_output(zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-11-09")), "not closed")
  expect_output(zero_unnominated_live(sh, .live_flows, "vic2026", corpus = fx$corpus, today = as.Date("2026-11-10")), "applied")
})
