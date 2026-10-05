# AUSPOL_NOM_ZERO_ORDER (plans/prereg-zero-order-2026-10-03.md): the order of the
# harness zeroing step, factored into nom_zero_order() / zero_unnominated_at() /
# nom_zero_assert_late() so it can be tested without running a harness.

.zo_fixture <- function() {
  sh <- matrix(c(30, 50, 20,
                 40, 40, 20), nrow = 2, byrow = TRUE,
               dimnames = list(c("Narracan", "Morwell"), c("ALP", "LNP", "GRN")))
  # Labor did not contest Narracan; every class stood in Morwell.
  tg <- data.table::data.table(seat = c("Narracan", "Narracan", "Morwell", "Morwell", "Morwell"),
                               party = c("LNP", "GRN", "ALP", "LNP", "GRN"), votes = 1)
  list(sh = sh, tg = tg, adj = c(Narracan = 4, Morwell = -4))   # mean-centred, as the port's is
}

# The harness shape: early call, then a port-shaped pmax(0, ALP + adj) step, then the late call.
.zo_pipeline <- function(f) {
  s <- f$sh
  s <- zero_unnominated_at("early", s, f$tg, "t")
  s[, "ALP"] <- pmax(0, s[, "ALP"] + f$adj)
  s[, "LNP"] <- pmax(0, s[, "LNP"] - f$adj)
  s <- 100 * s / rowSums(s)
  zero_unnominated_at("late", s, f$tg, "t")
}
# The call order BEFORE the switch existed: zero once, straight after the override.
.zo_old_pipeline <- function(f) {
  s <- f$sh
  s <- zero_unnominated(s, f$tg, "t")
  s[, "ALP"] <- pmax(0, s[, "ALP"] + f$adj)
  s[, "LNP"] <- pmax(0, s[, "LNP"] - f$adj)
  100 * s / rowSums(s)
}
.zo_quiet <- function(expr) { out <- NULL; utils::capture.output(out <- force(expr)); out }

test_that("nom_zero_order defaults to late (what ships), accepts early, and rejects anything else", {
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = NA)
  expect_identical(nom_zero_order(), "late")
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = "early")
  expect_identical(nom_zero_order(), "early")
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = "lat")
  expect_error(nom_zero_order(), "NZO!!")
  expect_error(zero_unnominated_at("early", matrix(1), NULL, "t"), "NZO!!")  # a typo must not fall back to early
})

test_that("early order is byte-identical to the call order before the switch existed", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1", AUSPOL_NOM_ZERO_ORDER = "early")
  f <- .zo_fixture()
  expect_identical(.zo_quiet(.zo_pipeline(f)), .zo_quiet(.zo_old_pipeline(f)))
  # unset now means late, the shipped default
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = NA)
  expect_identical(nom_zero_order(), "late")
  # the early helper is exactly the direct call (pin the order: unset now means late)
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = "early")
  expect_identical(.zo_quiet(zero_unnominated_at("early", f$sh, f$tg, "t")),
                   .zo_quiet(zero_unnominated(f$sh, f$tg, "t")))
})

test_that("early order lets a port-shaped step revive a zeroed cell; late keeps it at 0", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  f <- .zo_fixture()
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = "early")
  early <- .zo_quiet(.zo_pipeline(f))
  expect_gt(unname(early["Narracan", "ALP"]), 0)          # the known leak: adj > 0 revives the zero
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = "late")
  late <- .zo_quiet(.zo_pipeline(f))
  expect_identical(unname(late["Narracan", "ALP"]), 0)
  expect_equal(unname(rowSums(late)), c(100, 100))
  # a row with nothing to zero is untouched by the late call
  expect_identical(late["Morwell", ], .zo_quiet(.zo_old_pipeline(f))["Morwell", ])
})

test_that("late order skips the early call", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1", AUSPOL_NOM_ZERO_ORDER = "late")
  f <- .zo_fixture()
  expect_identical(zero_unnominated_at("early", f$sh, f$tg, "t"), f$sh)
  expect_equal(unname(.zo_quiet(zero_unnominated_at("late", f$sh, f$tg, "t"))["Narracan", "ALP"]), 0)
})

test_that("the final-write check fires in late order on a revived cell, never in early", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  f <- .zo_fixture()
  zeroed <- .zo_quiet(zero_unnominated(f$sh, f$tg, "t"))
  cells <- nomination_zeroed_cells(f$sh, zeroed)
  expect_identical(cells$seat, "Narracan"); expect_identical(cells$class, "ALP")
  revived <- zeroed; revived["Narracan", "ALP"] <- 2     # what an early-ordered pipeline ends with
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = "early")
  expect_true(nom_zero_assert_late(revived, cells))      # early: the known leak must NOT fire
  withr::local_envvar(AUSPOL_NOM_ZERO_ORDER = "late")
  expect_error(nom_zero_assert_late(revived, cells), "NZL!!")
  expect_true(nom_zero_assert_late(zeroed, cells))       # still zero: passes
  expect_true(nom_zero_assert_late(zeroed, NULL))
  # a seat dropped before the write (a pair's unscored seat) is not an NA failure
  expect_true(nom_zero_assert_late(zeroed["Morwell", , drop = FALSE], cells))
  # and the whole late pipeline passes its own check
  late <- .zo_quiet(.zo_pipeline(f))
  expect_true(nom_zero_assert_late(late, cells))
})
