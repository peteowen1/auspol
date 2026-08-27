test_that("slope 1 reproduces uniform swing exactly", {
  x <- c(10, 25, 3, 40.5)
  # every one of the four expressions the harnesses use, at slope 1
  expect_equal(dev_slope(x, 12, 15, 1), pmax(0, x + (15 - 12)))
  expect_equal(dev_slope(x, 0, 0, 1), pmax(0, x))
})

test_that("the floor at zero bites, and only from below", {
  expect_equal(dev_slope(c(1, 2), 10, 0, 1), c(0, 0))
  expect_true(all(dev_slope(c(1, 2), 0, 10, 1) > 0))
})

test_that("slope 0 collapses every seat onto the statewide level", {
  expect_equal(dev_slope(c(0, 5, 40), 8, 11, 0), c(11, 11, 11))
})

test_that("slope shrinks toward the level rather than toward zero", {
  # a seat BELOW the statewide level must move UP when shrunk, not down --
  # the sign error that "shrinkage" invites
  expect_gt(dev_slope(2, 10, 10, 0.5), dev_slope(2, 10, 10, 1))
  expect_lt(dev_slope(30, 10, 10, 0.5), dev_slope(30, 10, 10, 1))
})

test_that("a non-finite level is an error, not a silent NA", {
  expect_error(dev_slope(1:3, NA_real_, 5, 1), "finite")
  expect_error(dev_slope(1:3, 5, NA_real_, 1), "finite")
  expect_error(dev_slope(1:3, 5, 5, NA_real_), "finite")
})

test_that("dev_slopes_for defaults to uniform swing", {
  withr::with_envvar(c(AUSPOL_DEV_SLOPE = ""), {
    expect_equal(unname(dev_slopes_for(c("ALP", "IND"))), c(1, 1))
  })
})

test_that("dev_slopes_for parses only the classes named", {
  withr::with_envvar(c(AUSPOL_DEV_SLOPE = "IND=0.618"), {
    s <- dev_slopes_for(c("ALP", "IND", "GRN"))
    expect_equal(s[["IND"]], 0.618)
    expect_equal(s[["ALP"]], 1)
    expect_equal(s[["GRN"]], 1)
  })
})

test_that("a name that is not a party class is an ERROR, never a silent no-op", {
  # A typo that leaves every slope at 1 produces a run indistinguishable from
  # "this parameter does not matter" -- the failure this repo already recorded.
  withr::with_envvar(c(AUSPOL_DEV_SLOPE = "INDD=0.5"), {
    expect_error(dev_slopes_for(c("ALP", "IND")), "not a party class")
  })
})

test_that("a real class absent from THIS election is reported, not an error", {
  # One Nation did not contest WA 2001, and one spec must run across every
  # harness. This is data, not a mistake, and the two must not be conflated.
  withr::with_envvar(c(AUSPOL_DEV_SLOPE = "ONP=0.551,IND=0.618"), {
    s <- dev_slopes_for(c("ALP", "LNP", "IND"))
    expect_equal(s[["IND"]], 0.618)
    expect_equal(attr(s, "absent"), "ONP")
    expect_false("ONP" %in% names(s))
  })
})

test_that("no absences means an empty attribute, not NULL surprises", {
  withr::with_envvar(c(AUSPOL_DEV_SLOPE = "IND=0.6"), {
    expect_length(attr(dev_slopes_for(c("IND", "ALP")), "absent"), 0L)
  })
})

test_that("a malformed entry is an error", {
  withr::with_envvar(c(AUSPOL_DEV_SLOPE = "IND"), {
    expect_error(dev_slopes_for(c("IND")), "CLASS=value")
  })
  withr::with_envvar(c(AUSPOL_DEV_SLOPE = "IND=banana"), {
    expect_error(dev_slopes_for(c("IND")), "not a number")
  })
})

test_that("a per-seat slope vector is accepted and applied elementwise", {
  x <- c(10, 30, 5)
  s <- c(0.9, 0.3, 0.9)
  expect_equal(dev_slope(x, 12, 15, s),
               pmax(0, 15 + s * (x - 12)))
})

test_that("a per-seat vector of the wrong length is an error, not recycled", {
  # Silent recycling would apply the WRONG seat's slope to every third seat and
  # produce plausible output, which is this repo's characteristic failure.
  expect_error(dev_slope(1:6, 5, 5, c(0.9, 0.3)), "one per seat")
})

test_that("a scalar still works, so the shipped path is unchanged", {
  expect_equal(dev_slope(c(10, 30), 12, 15, 1), pmax(0, c(10, 30) + 3))
})
