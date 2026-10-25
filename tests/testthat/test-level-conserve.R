# AUSPOL_LEVEL_CONSERVE: rake the seat x class matrix so each standing class's
# vote-weighted implied statewide share equals its level (R/level_conserve.R).
# docs/plans/prereg-level-conserve-2026-10-25.md. Synthetic data only.

lc_fixture <- function() {
  sh <- matrix(c(40, 35, 10, 15,
                 30, 50, 20,  0,
                 55, 25,  5, 15,
                 20, 60, 12,  8), nrow = 4, byrow = TRUE,
               dimnames = list(c("s1", "s2", "s3", "s4"), c("ALP", "LNP", "GRN", "ONP")))
  list(shares = sh, level = c(ALP = 38, LNP = 40, GRN = 10, ONP = 12), w = c(100, 80, 120, 90))
}
lc_implied <- function(m, w) colSums(w * m) / sum(w)
lc_quiet <- function(expr) { out <- NULL; utils::capture.output(out <- expr); out }

test_that("raking meets the level to 1e-6, keeps rows at 100, never goes negative, keeps zeros", {
  f <- lc_fixture()
  r <- level_conserve_rake(f$shares, f$level, f$w)
  expect_lt(max(abs(rowSums(r) - 100)), 1e-9)
  expect_lt(max(abs(lc_implied(r, f$w) - f$level)), 1e-6)
  expect_true(all(r >= 0))
  expect_identical(r["s2", "ONP"], 0)
  # the check above is not vacuous: the input was off the level
  expect_gt(max(abs(lc_implied(f$shares, f$w) - f$level)), 1)
})

test_that("a class with a level and no candidate anywhere gives its level up pro rata to the others' levels", {
  f <- lc_fixture()
  sh <- f$shares; sh[, "ONP"] <- 0; sh <- 100 * sh / rowSums(sh)
  r <- level_conserve_rake(sh, f$level, f$w)
  want <- f$level[c("ALP", "LNP", "GRN")] / sum(f$level[c("ALP", "LNP", "GRN")]) * 100
  expect_lt(max(abs(lc_implied(r, f$w)[names(want)] - want)), 1e-6)
  rep_ <- attr(r, "report")
  expect_identical(rep_$dropped, "ONP")
  expect_equal(rep_$dropped_mass, 12)
})

test_that("held cells are unchanged and still count toward their class", {
  f <- lc_fixture()
  held <- matrix(FALSE, 4, 4, dimnames = dimnames(f$shares)); held["s1", "LNP"] <- TRUE; held["s3", "GRN"] <- TRUE
  r <- level_conserve_rake(f$shares, f$level, f$w, adjust = !held)
  expect_identical(r[held], f$shares[held])
  expect_lt(max(abs(lc_implied(r, f$w) - f$level)), 1e-6)
  expect_lt(max(abs(rowSums(r) - 100)), 1e-9)
  # through the entry point, held matched by name with a different row order
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE = "final")
  held2 <- held[c(4, 3, 2, 1), ]
  out <- lc_quiet(level_conserve_apply(f$shares, f$level, "wa2017", stage = "final", held = held2, weights = f$w))
  expect_identical(out[held], f$shares[held])
})

test_that("infeasible targets are refused loudly", {
  f <- lc_fixture()
  # a held cell already above its class's whole level
  held <- matrix(FALSE, 4, 4, dimnames = dimnames(f$shares)); held[, "GRN"] <- TRUE
  sh <- f$shares; sh[, "GRN"] <- c(40, 40, 40, 40); sh[, c("ALP", "LNP", "ONP")] <- sh[, c("ALP", "LNP", "ONP")] * 60 / rowSums(sh[, c("ALP", "LNP", "ONP")])
  expect_error(level_conserve_rake(sh, f$level, f$w, adjust = !held), "infeasible")
  # a class that stands only in one small seat cannot reach a large level there
  sh2 <- f$shares; sh2[, "ONP"] <- c(1, 0, 0, 0); sh2 <- 100 * sh2 / rowSums(sh2)
  expect_error(level_conserve_rake(sh2, c(ALP = 20, LNP = 20, GRN = 10, ONP = 50), f$w), "infeasible")
  # bad inputs
  expect_error(level_conserve_rake(f$shares, c(38, 40, 10, 12), f$w), "named")
  expect_error(level_conserve_rake(f$shares, f$level, c(1, 1)), "weight")
  bad <- f$shares; bad[1, 1] <- -1
  expect_error(level_conserve_rake(bad, f$level, f$w), ">= 0")
})

test_that("off is byte-identical and the switch is validated", {
  f <- lc_fixture()
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE = "0")
  expect_identical(level_conserve_apply(f$shares, f$level, "wa2017", stage = "base"), f$shares)
  expect_identical(level_conserve_apply(f$shares, NULL, "wa2017", stage = "final"), f$shares)
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE = "final")
  expect_identical(level_conserve_apply(f$shares, f$level, "wa2017", stage = "base"), f$shares)
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE = "yes")
  expect_error(level_conserve_mode(), "must be")
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE = "base")
  expect_true("AUSPOL_LEVEL_CONSERVE" %in% names(post_xgb_switches()))
})

test_that("final mode prints what it applied and lambda blends", {
  f <- lc_fixture()
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE = "final", AUSPOL_LEVEL_CONSERVE_LAMBDA = "1")
  txt <- utils::capture.output(out <- level_conserve_apply(f$shares, f$level, "wa2017", stage = "final", weights = f$w))
  expect_match(txt, "^LCV1  level conserve \\(final")
  expect_match(txt, "-> 0\\.000")
  expect_lt(max(abs(lc_implied(out, f$w) - f$level)), 1e-6)
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE_LAMBDA = "0.5")
  half <- lc_quiet(level_conserve_apply(f$shares, f$level, "wa2017", stage = "final", weights = f$w))
  expect_equal(half, 0.5 * f$shares + 0.5 * out, tolerance = 1e-9)
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE_LAMBDA = "2")
  expect_error(level_conserve_lambda(), "\\[0, 1\\]")
})

test_that("base mode zeroes unnominated classes, rakes, and adds only the change", {
  f <- lc_fixture()
  # ONP did not stand in s1 or s4 (the target table names those seats without ONP)
  tg <- data.frame(seat = rep(c("s1", "s2", "s3", "s4"), each = 4),
                   party = rep(c("ALP", "LNP", "GRN", "ONP"), 4),
                   votes = c(1, 1, 1, 0,  1, 1, 1, 0,  1, 1, 1, 1,  1, 1, 1, 0))
  S <- level_conserve_standing(f$shares, tg)
  expect_identical(unname(S[, "ONP"]), c(FALSE, FALSE, TRUE, FALSE))
  withr::local_envvar(AUSPOL_LEVEL_CONSERVE = "base")
  out <- lc_quiet(level_conserve_apply(f$shares, f$level, "wa2017", stage = "base", target = tg, weights = f$w))
  expect_lt(max(abs(rowSums(out) - 100)), 1e-9)
  expect_true(all(out >= 0))
  expect_identical(out[!S], f$shares[!S])          # left for the later nomination zero
  # zeroing the unnominated cells pro rata gives exactly the raked matrix
  Z <- f$shares; Z[!S] <- 0; Z <- 100 * Z / rowSums(Z)
  R <- level_conserve_rake(Z, f$level, f$w)
  # the change out - shares equals R - Z on the standing cells
  expect_lt(max(abs((out - f$shares)[S] - (R - Z)[S])), 1e-9)
  expect_lt(max(abs(lc_implied(R, f$w)[c("ALP", "LNP", "GRN", "ONP")] -
                    f$level / sum(f$level) * 100)), 1e-6)
})

test_that("weights come from the previous election's formal votes, median for unmatched seats", {
  corpus <- data.frame(election = c("wa2013", "wa2013", "wa2013", "wa2008", "wa2017"),
                       region = "wa", year = c(2013, 2013, 2013, 2008, 2017),
                       seat = c("Alpha", "Alpha", "Beta", "Gamma", "Alpha"),
                       votes = c(600, 400, 3000, 9999, 7))
  w <- level_conserve_weights(c("alpha", "Beta", "New Seat"), "wa2017", corpus = corpus)
  expect_equal(as.numeric(w), c(1000, 3000, 2000))
  expect_match(attr(w, "source"), "wa2013 \\(2 of 3 seats matched")
  w0 <- level_conserve_weights(c("a", "b"), "nt2016", corpus = corpus)
  expect_equal(as.numeric(w0), c(1, 1))
  expect_match(attr(w0, "source"), "EQUAL")
})
