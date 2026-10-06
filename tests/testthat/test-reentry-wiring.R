# docs/plans/prereg-reentry-prior-2026-09-07.md. AUSPOL_REENTRY is wired the same
# way everywhere: through reentry_apply_harness(), which is time-forward.

test_that("switch 0 returns the matrix untouched, with no attribute", {
  withr::local_envvar(AUSPOL_REENTRY = "0")
  m <- matrix(c(50, 50, 0, 60, 30, 10), 2, byrow = TRUE,
              dimnames = list(c("A", "B"), c("ALP", "LNP", "GRN")))
  fa <- data.frame(seat = "A", party = "ALP", votes = 1)
  expect_identical(reentry_apply_harness(m, fa, fa, c(ALP = 40), "vic2026",
                                         all_election_pairs()), m)
})

test_that("the harness fit uses only elections dated before the target (WA 2008)", {
  withr::local_envvar(AUSPOL_REENTRY = "1", AUSPOL_TIME_FORWARD_FITS = "1")
  seen <- NULL
  testthat::local_mocked_bindings(
    reentry_fit = function(pairs, ...) { seen <<- vapply(pairs, `[[`, "", "election"); stop("stop here") })
  m <- matrix(c(50, 50, 0), 1, dimnames = list("A", c("ALP", "LNP", "GRN")))
  fa <- data.frame(seat = "A", party = "ALP", votes = 1)
  out <- capture.output(reentry_apply_harness(m, fa, fa, c(ALP = 40), "wa2008", all_election_pairs()))
  expect_true(length(seen) > 0)
  expect_true(all(elections_before(seen, "wa2008")))
  expect_false("wa2013" %in% seen)              # the old leave-one-out filter kept this one
  expect_false("fed2025" %in% seen)
  loo <- Filter(function(z) z$election != "wa2008", all_election_pairs())
  expect_gt(length(loo), length(seen))
})

test_that("the WA harness calls the shared time-forward helper, not a private leave-one-out fit", {
  f <- testthat::test_path("..", "..", "scripts", "backtest_candidate_wa.R")
  skip_if_not(file.exists(f), "scripts/ not shipped in the check build")
  code <- grep("^\\s*#", readLines(f, warn = FALSE), value = TRUE, invert = TRUE)
  expect_true(any(grepl("reentry_apply_harness(", code, fixed = TRUE)))
  expect_false(any(grepl("reentry_fit(", code, fixed = TRUE)))
  expect_false(any(grepl("z$election != el_to", code, fixed = TRUE)))
})

test_that("every harness and fit_seats_full use reentry_apply_harness, none a private fit", {
  d <- testthat::test_path("..", "..", "scripts")
  fs <- file.path(d, c("backtest_candidate_fed.R", "backtest_candidate_nsw.R",
                       "backtest_candidate_qld.R", "backtest_candidate_sa.R",
                       "backtest_candidate_vic.R", "backtest_candidate_wa.R",
                       "fit_seats_full.R"))
  skip_if_not(all(file.exists(fs)), "scripts/ not shipped in the check build")
  for (f in fs) {
    code <- grep("^\\s*#", readLines(f, warn = FALSE), value = TRUE, invert = TRUE)
    expect_true(any(grepl("reentry_apply_harness(", code, fixed = TRUE)), info = basename(f))
    expect_false(any(grepl("reentry_fit(", code, fixed = TRUE)), info = basename(f))
  }
})

test_that("reentry_standing_live: no list unless AUSPOL_NOM_LIVE=1, seats spelled as the forecast spells them", {
  corpus <- data.table::data.table(
    election = c(rep("vic2022", 4), rep("vic2026", 4)),
    seat = c("Richmond", "Richmond", "Narracan", "Narracan", "RICHMOND", "RICHMOND", "narracan", "narracan"),
    party = c("ALP", "GRN", "ALP", "LNP", "ALP", "LNP", "ALP", "LNP"))
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto")
  r <- reentry_standing_live(c("Richmond", "Narracan"), corpus = corpus)
  expect_null(r$standing)
  expect_match(r$reason, "provisional")
  withr::local_envvar(AUSPOL_NOM_LIVE = "1")
  r <- reentry_standing_live(c("Richmond", "Narracan"), corpus = corpus, today = as.Date("2026-11-10"))
  expect_setequal(paste(r$standing$seat, r$standing$party, sep = "|"),
                  c("Richmond|ALP", "Richmond|LNP", "Narracan|ALP", "Narracan|LNP"))
  expect_true(all(r$standing$votes == 1))
})
