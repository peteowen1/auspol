# AUSPOL_REENTRY = "majors": a major class's own history, swung by the
# statewide change. Pete's decision 2026-10-06 after the general GLM prior was
# refused (it filled One Nation at 30-43 in safe Labor Queensland 2020 seats).

.majors_corpus <- function(extra = NULL) {
  mk <- function(el, seat, party, votes) data.frame(election = el, region = "vic",
                                                    seat = seat, party = party, votes = votes)
  d <- rbind(
    # vic2014: Richmond LNP 20 of 100; statewide LNP (20 + 60) / 200 = 40
    mk("vic2014", "Richmond", c("ALP", "GRN", "LNP"), c(50, 30, 20)),
    mk("vic2014", "Other",    c("ALP", "LNP"),        c(40, 60)),
    # vic2018: Richmond Liberals did not stand
    mk("vic2018", "Richmond", c("ALP", "GRN"),        c(60, 40)),
    mk("vic2018", "Other",    c("ALP", "LNP"),        c(45, 55)),
    mk("vic2022", "Richmond", c("ALP", "GRN", "LNP"), c(40, 40, 20)),
    mk("vic2022", "Other",    c("ALP", "LNP"),        c(45, 55)))
  if (!is.null(extra)) d <- rbind(d, extra)
  data.table::as.data.table(d)
}
.majors_mat <- function() {
  matrix(c(60, 40, 0, 0,   # Richmond 2018: ALP GRN LNP ONP
           45, 0, 55, 0,   # Other
           10, 0, 0, 0),   # NewSeat: ALP only
         3, 4, byrow = TRUE,
         dimnames = list(c("Richmond", "Other", "NewSeat"), c("ALP", "GRN", "LNP", "ONP")))
}
.majors_stand <- data.frame(
  seat = c("Richmond", "Richmond", "Richmond", "Richmond", "NewSeat", "NewSeat", "NewSeat"),
  party = c("ALP", "GRN", "LNP", "ONP", "ALP", "LNP", "GRN"))

test_that("majors: Richmond-shaped cell is filled from its 2014 share, swung by the statewide change", {
  withr::local_envvar(AUSPOL_DEV_SLOPE = NA)
  out <- capture.output(m <- reentry_majors_fill(
    .majors_mat(), .majors_stand, c(ALP = 40, GRN = 10, LNP = 30, ONP = 5), "vic2022",
    corpus = .majors_corpus(), code = "T"))
  # 2014 seat share 20, statewide then 40, statewide now 30, slope 1 -> 30 + (20 - 40)
  expect_equal(m["Richmond", "LNP"], 10)
  re <- attr(m, "reentry")
  expect_equal(nrow(re), 1L)
  expect_equal(re$old_election, "vic2014")
  expect_equal(re$old_share, 20)
  expect_equal(re$level_prev, 40)
  expect_equal(re$path, "majors")
  expect_true(any(grepl("FILLED: Richmond | LNP | from vic2014", out, fixed = TRUE)))
  # nothing else moved
  m0 <- .majors_mat(); m0["Richmond", "LNP"] <- 10
  expect_equal(unclass(m), m0, ignore_attr = TRUE)
})

test_that("majors: a class slope is honoured", {
  withr::local_envvar(AUSPOL_DEV_SLOPE = "LNP=0.5")
  capture.output(m <- reentry_majors_fill(
    .majors_mat(), .majors_stand, c(ALP = 40, GRN = 10, LNP = 30), "vic2022",
    corpus = .majors_corpus(), code = "T"))
  expect_equal(m["Richmond", "LNP"], 30 + 0.5 * (20 - 40))
})

test_that("majors: no earlier contest under the seat name -> nothing filled, and it is logged", {
  withr::local_envvar(AUSPOL_DEV_SLOPE = NA)
  out <- capture.output(m <- reentry_majors_fill(
    .majors_mat(), .majors_stand, c(ALP = 40, GRN = 10, LNP = 30), "vic2022",
    corpus = .majors_corpus(), code = "T"))
  expect_equal(unname(m["NewSeat", "LNP"]), 0)
  expect_equal(unname(m["NewSeat", "GRN"]), 0)
  expect_true(any(grepl("NOT filled: NewSeat | LNP", out, fixed = TRUE)))
  expect_true(any(grepl("NOT filled: NewSeat | GRN", out, fixed = TRUE)))
  expect_false("NewSeat" %in% attr(m, "reentry")$seat)
})

test_that("majors: ONP and IND are never filled, even when standing with a zero base", {
  withr::local_envvar(AUSPOL_DEV_SLOPE = NA)
  mat <- cbind(.majors_mat(), IND = 0)
  st <- rbind(.majors_stand, data.frame(seat = "Richmond", party = "IND"))
  cor <- .majors_corpus(data.frame(election = "vic2014", region = "vic", seat = "Richmond",
                                   party = c("ONP", "IND"), votes = c(30, 30)))
  capture.output(m <- reentry_majors_fill(mat, st, c(ALP = 40, GRN = 10, LNP = 30, ONP = 5, IND = 5),
                                          "vic2022", corpus = cor, code = "T"))
  expect_equal(unname(m["Richmond", "ONP"]), 0)
  expect_equal(unname(m["Richmond", "IND"]), 0)
  expect_true(all(attr(m, "reentry")$party %in% c("ALP", "LNP", "GRN")))
})

test_that("majors: time-forward, never reads the target or any later election", {
  withr::local_envvar(AUSPOL_DEV_SLOPE = NA, AUSPOL_TIME_FORWARD_FITS = "0")  # the leave-one-out mode must not matter
  # Make the target (vic2022) and a LATER election hold a huge Richmond LNP share.
  later <- data.frame(election = c("vic2022", "vic2026"), region = "vic", seat = "Richmond",
                      party = "LNP", votes = c(900, 900))
  cor <- .majors_corpus(later)
  capture.output(m <- reentry_majors_fill(
    .majors_mat(), .majors_stand, c(ALP = 40, GRN = 10, LNP = 30), "vic2022",
    corpus = cor, code = "T"))
  expect_equal(m["Richmond", "LNP"], 10)
  expect_equal(attr(m, "reentry")$old_election, "vic2014")
  # and a target at vic2018 cannot see vic2022 either: no earlier vic2018-before contest by LNP in Richmond except 2014
  capture.output(m2 <- reentry_majors_fill(
    .majors_mat(), .majors_stand, c(ALP = 40, GRN = 10, LNP = 30), "vic2014",
    corpus = cor, code = "T"))
  expect_equal(unname(m2["Richmond", "LNP"]), 0)   # nothing before 2014 in this corpus
})

test_that("majors: reentry_apply_harness routes to it and does not fit the GLM", {
  withr::local_envvar(AUSPOL_REENTRY = "majors", AUSPOL_DEV_SLOPE = NA)
  testthat::local_mocked_bindings(reentry_fit = function(...) stop("GLM must not be fitted in majors mode"))
  fb <- data.frame(seat = .majors_stand$seat, party = .majors_stand$party, votes = 100)
  capture.output(m <- reentry_apply_harness(.majors_mat(), NULL, fb, c(ALP = 40, GRN = 10, LNP = 30),
                                            "vic2022", all_election_pairs(), code = "T",
                                            corpus = .majors_corpus()))
  expect_equal(m["Richmond", "LNP"], 10)
})

test_that("reentry_mode validates the switch", {
  withr::local_envvar(AUSPOL_REENTRY = NA)
  expect_identical(reentry_mode(), "majors")   # the shipped value
  withr::local_envvar(AUSPOL_REENTRY = "")
  expect_identical(reentry_mode(), "majors")
  for (v in c("0", "1", "majors")) { withr::local_envvar(AUSPOL_REENTRY = v); expect_identical(reentry_mode(), v) }
  withr::local_envvar(AUSPOL_REENTRY = "major")
  expect_error(reentry_mode(), "must be")
  m <- .majors_mat()
  expect_error(reentry_apply_harness(m, NULL, NULL, c(ALP = 40), "vic2022", list()), "must be")
})
