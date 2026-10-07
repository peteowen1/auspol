test_that("one cluster gives an infinite variance, never NaN, and a zero weight", {
  withr::local_envvar(AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER = "none")
  # Perfect fit in one cluster: the score sum is exactly 0, and 0 * Inf was NaN.
  dx <- c(1, 2, 3); dy <- c(2, 4, 6); b <- sum(dx * dy) / sum(dx^2); e <- dy - b * dx
  se2 <- .cluster_se2(sum(tapply(dx * e, rep("a", 3), sum)^2), sum(dx^2)^2, 1L)
  expect_identical(se2, Inf)
  expect_identical(min(1, max(0, b * b^2 / (b^2 + se2))), 0)
  expect_equal(.cluster_se2(4, 2, 3L), 4 / 2 * 3 / 2)
  withr::local_envvar(AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER = "legacy")
  expect_equal(.cluster_se2(4, 2, 1L), 2)
  withr::local_envvar(AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER = "bad")
  expect_error(.cluster_se2(1, 1, 2L), "must be")
})
