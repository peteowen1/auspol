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

.nz_run <- function(sh, corpus, today = as.Date("2026-11-10")) {
  txt <- paste(capture.output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = corpus, today = today)), collapse = "\n")
  list(out = out, txt = txt)
}

test_that("live: =1 with a complete list zeroes the non-standing party and sends its share by flows", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  r <- .nz_run(sh, fx$corpus)
  expect_equal(unname(r$out["Narracan", "GRN"]), 0)
  expect_equal(unname(r$out["Narracan", c("ALP", "LNP", "IND")]), c(50, 40, 10))   # GRN 20 split 50/50 ALP/LNP
  expect_equal(r$out["Richmond", ], sh["Richmond", ])
  expect_match(r$txt, "applied: 3 cells changed")
  expect_false(grepl("WARNING", r$txt, fixed = TRUE))
})

test_that("live: auto never opens, even long after nominations closed", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  r <- .nz_run(sh, fx$corpus, today = as.Date("2027-01-01"))
  expect_match(r$txt, "provisional list, set AUSPOL_NOM_LIVE=1 after loading the VEC final list")
  expect_identical(r$out, sh)
  withr::local_envvar(AUSPOL_NOM_LIVE = "0")
  r0 <- .nz_run(sh, fx$corpus)
  expect_match(r0$txt, "NOT applied")
  expect_identical(r0$out, sh)
})

test_that("live: =1 with Labor absent in some seats and the count above the floor APPLIES, and names the seats", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  extra <- data.table::data.table(election = "vic2026", seat = rep("Kew", 3), party = c("IND", "OTH", "ONP"))
  c2 <- fx$corpus[!(fx$corpus$election == "vic2026" & fx$corpus$seat == "Kew" & fx$corpus$party == "ALP")]
  c2 <- rbind(c2, extra)
  expect_gt(sum(c2$election == "vic2026") / sum(c2$election == "vic2022"), 0.85)
  r <- .nz_run(sh, c2)
  expect_match(r$txt, "ALP has no candidacy in 1 of 3 seats and will be ZEROED there: kew")
  expect_equal(unname(r$out["Kew", "ALP"]), 0)
  expect_match(r$txt, "applied:")
})

test_that("live: =1 with a list under the count floor stays shut", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  part <- rbind(fx$corpus[fx$corpus$election == "vic2022"], fx$corpus[fx$corpus$election == "vic2026"][1])
  r <- .nz_run(sh, part)
  expect_match(r$txt, "list too small")
  expect_identical(r$out, sh)
  r2 <- .nz_run(sh, fx$corpus[fx$corpus$election == "vic2022"])   # no vic2026 rows at all
  expect_match(r2$txt, "NOT applied")
  expect_identical(r2$out, sh)
})

test_that("live: =1 before the nomination-close date warns loudly but does not block", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  early <- .nz_run(sh, fx$corpus, today = as.Date("2026-11-09"))
  expect_match(early$txt, "WARNING AUSPOL_NOM_LIVE=1 set on 2026-11-09, before 2026-11-10")
  expect_equal(unname(early$out["Narracan", "GRN"]), 0)
  late <- .nz_run(sh, fx$corpus, today = as.Date("2026-11-10"))
  expect_false(grepl("before 2026-11-10", late$txt, fixed = TRUE))
})

test_that("live: AUSPOL_NOM_ZERO=0 with the gate open logs a no-op, never 'applied'", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "0")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  r <- .nz_run(sh, fx$corpus)
  expect_match(r$txt, "no-op: nothing changed")
  expect_false(grepl("applied:", r$txt, fixed = TRUE))
  expect_identical(r$out, sh)
})

test_that("live: a class absent from the nomination table is reported as skipped", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture()
  sh <- cbind(.live_shares(fx$seats), NAT = 5)
  sh[, "ALP"] <- 35
  expect_match(.nz_run(sh, fx$corpus)$txt, "absent from the nomination table: NAT")
})
