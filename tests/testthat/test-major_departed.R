# Major party loses vote when its sitting member departs -- docs/plans/prereg-major-departed-slope-2026-09-18.md
corpus <- data.table::data.table(
  election = c(rep("nsw2019", 4), rep("nsw2023", 4)),
  seat     = c("Cabramatta", "Cabramatta", "Auburn", "Auburn", "Cabramatta", "Cabramatta", "Auburn", "Auburn"),
  party    = c("ALP", "LNP", "ALP", "LNP", "ALP", "LNP", "ALP", "LNP"),
  surname  = c("LALICH", "SMITH", "VOLTZ", "JONES", "VO", "SMITH", "VOLTZ", "BROWN"),
  given    = c("Nick", "Ann", "Lynda", "Bob", "Tri", "Ann", "Lynda", "Cal"),
  name     = NA_character_,
  pcv      = c(55, 25, 50, 30, 41, 23, 60, 20),
  votes    = c(550, 250, 500, 300, 410, 230, 600, 200),
  tot      = 1000,
  elected  = c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE))

test_that("candidate_returns flags a departed sitting member and only that", {
  r <- candidate_returns("nsw2019", "nsw2023", corpus = corpus)
  expect_true("mp_departed" %in% names(r))
  expect_true(r[seat == "Cabramatta" & party == "ALP"]$mp_departed)    # Lalich retired
  expect_false(r[seat == "Auburn" & party == "ALP"]$mp_departed)       # Voltz re-stood
  expect_false(r[seat == "Cabramatta" & party == "LNP"]$mp_departed)   # never held it
})

test_that("conditional_slopes applies major_departed only to departed cells", {
  r <- candidate_returns("nsw2019", "nsw2023", corpus = corpus)
  s <- conditional_slopes("ALP", c("Cabramatta", "Auburn"), r, major_departed = c(ALP = 0.8, LNP = 0.85))
  expect_equal(s, c(0.8, 1))
  expect_equal(conditional_slopes("ALP", c("Cabramatta", "Auburn"), r), c(1, 1))
  s2 <- screened_slopes("ALP", c("Cabramatta", "Auburn"), r, permit = c(TRUE, TRUE), major_departed = c(ALP = 0.8))
  expect_equal(s2, c(0.8, 1))
})

test_that("fit_major_departed_slope leaves the target out and needs min_n rows", {
  pairs <- list(list(election = "nsw2023", prev = "nsw2019"))
  f <- fit_major_departed_slope("nsw2023", corpus = corpus, pairs = pairs, min_n = 1L)
  expect_equal(unname(f$slope), c(1, 1)); expect_equal(unname(f$n), c(0L, 0L))
  g <- fit_major_departed_slope("vic2022", corpus = corpus, pairs = pairs, min_n = 1L)
  expect_equal(g$n[["ALP"]], 1L); expect_true(is.finite(g$slope[["ALP"]]))
})
