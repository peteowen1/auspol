# AUSPOL_DEPARTED_SUCCESSOR: a per-seat departed-independent rate.
# docs/plans/prereg-departed-successor-flag-2026-10-07.md

seats <- c("s1", "s2", "s3", "s4")
returns <- data.table::data.table(seat = seats, party = "IND",
                                  same = c(FALSE, FALSE, FALSE, TRUE), same_mp = FALSE,
                                  prior_leader_returns = c(FALSE, FALSE, FALSE, TRUE))
permit <- c(FALSE, FALSE, TRUE, FALSE)   # s3 departed but permitted -> uniform 1.0

test_that("successor_rate = NULL is the shipped behaviour exactly", {
  a <- screened_slopes("IND", seats, returns, permit, honour_departed = TRUE, with_flags = TRUE)
  b <- screened_slopes("IND", seats, returns, permit, honour_departed = TRUE, with_flags = TRUE,
                       successor_rate = NULL)
  expect_identical(a, b)
})

test_that("a named seat takes its own rate only where the departed decay fires", {
  sr <- c(s1 = 0.12, s3 = 0.70, s4 = 0.50)
  sl <- screened_slopes("IND", seats, returns, permit, honour_departed = TRUE, with_flags = TRUE,
                        successor_rate = sr)
  expect_equal(sl[[1]], 0.12)   # departed, not permitted, named
  expect_equal(sl[[2]], 0.38)   # departed, not named -> the shipped rate
  expect_equal(sl[[3]], 1.0)    # permitted successor keeps the uniform path, rate ignored
  expect_equal(sl[[4]], 0.907)  # leader returned: the decay never fires, rate ignored
  # Only the named, fired seat is held, so unnamed departed cells keep today's renormalisation.
  expect_equal(unname(attr(sl, "departed")), c(TRUE, FALSE, FALSE, FALSE))
})

test_that("other classes are untouched and never held", {
  r2 <- data.table::copy(returns); r2$party <- "OTH_RIGHT"
  a <- screened_slopes("OTH_RIGHT", seats, r2, permit, honour_departed = TRUE, with_flags = TRUE)
  b <- screened_slopes("OTH_RIGHT", seats, r2, permit, honour_departed = TRUE, with_flags = TRUE,
                       successor_rate = c(s1 = 0.12))
  expect_equal(as.numeric(a), as.numeric(b))
  expect_false(any(attr(b, "departed")))
})

test_that("an unnamed or duplicated successor_rate is an error, not a silent no-op", {
  expect_error(screened_slopes("IND", seats, returns, permit, honour_departed = TRUE,
                               successor_rate = c(0.1, 0.2)), "named by seat")
  expect_error(screened_slopes("IND", seats, returns, permit, honour_departed = TRUE,
                               successor_rate = c(s1 = 0.1, s1 = 0.2)), "named by seat")
})

test_that("departed_successor_rates is NULL when off and loud when on but unfitted", {
  f <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(target = c("vic2022", "vic2022", "vic2018"),
                              seat = c("Pascoe Vale", "Morwell", "(none)"),
                              rate = c(0.11, 0.55, NA)), f, row.names = FALSE)
  withr::local_envvar(AUSPOL_DEPARTED_SUCCESSOR = "0")
  expect_null(departed_successor_rates("vic2022", f))
  withr::local_envvar(AUSPOL_DEPARTED_SUCCESSOR = "1")
  expect_equal(departed_successor_rates("vic2022", f), c(`Pascoe Vale` = 0.11, Morwell = 0.55))
  expect_length(departed_successor_rates("vic2018", f), 0)          # fitted, no cells
  expect_error(departed_successor_rates("vic2014", f), "no rows")   # never fitted
  expect_error(departed_successor_rates("vic2022", tempfile()), "needs")
})
