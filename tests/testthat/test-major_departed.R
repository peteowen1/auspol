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

# Targets after nsw2023 (vic2026): since 2026-09-28 fits are time-forward, so a
# target dated before the only fixture pair (e.g. vic2022) correctly gets none.
test_that("fit_major_departed_slope leaves the target out and needs min_n rows", {
  pairs <- list(list(election = "nsw2023", prev = "nsw2019"))
  f <- fit_major_departed_slope("nsw2023", corpus = corpus, pairs = pairs, min_n = 1L)
  expect_equal(unname(f$slope), c(1, 1)); expect_equal(unname(f$n), c(0L, 0L))
  g <- suppressWarnings(fit_major_departed_slope("vic2026", corpus = corpus, pairs = pairs, min_n = 1L))
  expect_equal(g$n[["ALP"]], 1L); expect_true(is.finite(g$slope[["ALP"]]))
})

test_that("major_present covers the non-departed cells and departed still wins", {
  r <- candidate_returns("nsw2019", "nsw2023", corpus = corpus)
  s <- conditional_slopes("ALP", c("Cabramatta", "Auburn"), r, major_departed = c(ALP = 0.6), major_present = c(ALP = 0.9))
  expect_equal(s, c(0.6, 0.9))
  expect_equal(conditional_slopes("ALP", c("Cabramatta", "Auburn"), r, major_present = c(ALP = 0.9)), c(1, 0.9))
  pairs <- list(list(election = "nsw2023", prev = "nsw2019"))
  g <- suppressWarnings(fit_major_departed_slope("vic2026", corpus = corpus, pairs = pairs, min_n = 1L))
  expect_true(all(c("slope_present", "n_present") %in% names(g)))
  expect_equal(g$n_present[["ALP"]], 1L)
})

test_that("a pair dated after the target is not used (time-forward)", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1")
  pairs <- list(list(election = "nsw2023", prev = "nsw2019"))
  g <- suppressWarnings(fit_major_departed_slope("vic2022", corpus = corpus, pairs = pairs, min_n = 1L))
  expect_equal(unname(g$n), c(0L, 0L))
})

# AUSPOL_DEPARTED_POOL -- docs/plans/prereg-departed-slope-pool-2026-11-05.md
test_that("departed slopes pool toward the two-party slope with tau^2 from per-election gaps", {
  mk <- function(p, cl, dev, k) data.table::data.table(pair = p, party = cl, dev = dev, yy = k * dev + c(0.3, -0.2, 0.1, -0.1))
  dev <- c(-10, -5, 5, 10)
  # Same gap in every election: tau^2 > 0, each party stays near its own slope.
  dep <- data.table::rbindlist(lapply(c("e1", "e2", "e3"), function(p) rbind(mk(p, "ALP", dev, 0.4), mk(p, "LNP", dev, 0.8))))
  r <- auspol:::.pool_departed_slopes(dep)
  expect_gt(r$tau2, 0.03)
  expect_equal(unname(r$slope[["ALP"]]), unname(r$own[["ALP"]]), tolerance = 0.02)
  expect_equal(unname(r$slope[["LNP"]]), unname(r$own[["LNP"]]), tolerance = 0.02)
  expect_lt(r$slope[["ALP"]], 0.5); expect_gt(r$slope[["LNP"]], 0.7)
  # Gaps that cancel across elections (same true slope, noise only): tau^2 0, both take mu.
  dep2 <- rbind(mk("e1", "ALP", dev, 0.6), mk("e1", "LNP", dev, 0.6), mk("e2", "ALP", dev, 0.6), mk("e2", "LNP", dev, 0.6))
  r2 <- auspol:::.pool_departed_slopes(dep2)
  expect_equal(r2$tau2, 0)
  expect_equal(unname(r2$slope[["ALP"]]), r2$mu); expect_equal(unname(r2$slope[["LNP"]]), r2$mu)
  # One party with no rows takes mu; no rows at all returns NULL (the caller keeps 1).
  r3 <- auspol:::.pool_departed_slopes(mk("e1", "ALP", dev, 0.5))
  expect_equal(unname(r3$slope[["LNP"]]), r3$mu)
  expect_null(auspol:::.pool_departed_slopes(dep[0]))
})

test_that("AUSPOL_DEPARTED_POOL removes the min_n cliff in fit_major_departed_slope", {
  pairs <- list(list(election = "nsw2023", prev = "nsw2019"))
  # A third seat the Coalition held whose member left, so both parties have one departed row.
  c2 <- rbind(corpus, data.table::data.table(
    election = c("nsw2019", "nsw2019", "nsw2023", "nsw2023"), seat = "Penrith", party = c("ALP", "LNP", "ALP", "LNP"),
    surname = c("DAVIS", "AYRES", "DAVIS", "NEWMAN"), given = c("Ed", "Stu", "Ed", "Ken"), name = NA_character_,
    pcv = c(40, 52, 47, 44), votes = c(400, 520, 470, 440), tot = 1000, elected = c(FALSE, TRUE, FALSE, TRUE)))
  withr::local_envvar(AUSPOL_DEPARTED_POOL = "0")
  off <- suppressWarnings(fit_major_departed_slope("vic2026", corpus = c2, pairs = pairs))   # n = 1 < 40: cliff gives 1
  expect_equal(off$slope[["ALP"]], 1); expect_null(off$pool)
  withr::local_envvar(AUSPOL_DEPARTED_POOL = "1")
  on <- suppressWarnings(fit_major_departed_slope("vic2026", corpus = c2, pairs = pairs))
  expect_equal(unname(on$n), c(1L, 1L))
  expect_equal(unname(on$slope[["ALP"]]), on$pool$mu); expect_equal(unname(on$slope[["LNP"]]), on$pool$mu)
  expect_false(is.null(on$pool))
  expect_false(isTRUE(all.equal(on$slope[["ALP"]], 1)))
})
