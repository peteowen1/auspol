test_that("fit_pairs_for drops the target AND every later election", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1")
  pairs <- list(list(election = "fed2016"), list(election = "fed2019"),
                list(election = "nsw2023"), list(election = "fed2025"))
  kept <- vapply(fit_pairs_for("fed2019", pairs), `[[`, character(1), "election")
  expect_identical(kept, "fed2016")          # nsw2023 and fed2025 are later
  expect_true(all(elections_before(c("fed2016", "sa2018"), "fed2019")))
  expect_false(any(elections_before(c("fed2019", "fed2025"), "fed2019")))
})

test_that("the old leave-target-out choice is kept behind the switch", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "0")
  pairs <- list(list(election = "fed2016"), list(election = "fed2019"), list(election = "fed2025"))
  kept <- vapply(fit_pairs_for("fed2019", pairs), `[[`, character(1), "election")
  expect_identical(kept, c("fed2016", "fed2025"))
})

test_that("a label with only a year uses the year; a non-election target drops only itself", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1")
  expect_identical(elections_before(c("x2018", "x2020"), "y2019"), c(TRUE, FALSE))
  expect_identical(elections_before(c("e1", "e2"), "nope"), c(TRUE, TRUE))
})
