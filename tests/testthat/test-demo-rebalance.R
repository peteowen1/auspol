# .demo_rebalance(): the demographic correction delivered in full under AUSPOL_DEMO_RESID_FULL=1 (audit F7, 2026-10-19)
test_that("full delivery keeps the adjusted cells exactly and the row total; the default rescales them", {
  sh <- matrix(c(40, 30, 10, 12, 8), nrow = 1, dimnames = list("A", c("ALP", "LNP", "GRN", "ONP", "OTH")))
  tot <- rowSums(sh); s2 <- sh; s2[, "ALP"] <- 42; s2[, "GRN"] <- 9
  withr::local_envvar(AUSPOL_DEMO_RESID_FULL = "1")
  o <- NULL; utils::capture.output(o <- .demo_rebalance(s2, tot, c("ALP", "GRN")))
  expect_equal(unname(o[, c("ALP", "GRN")]), c(42, 9))
  expect_equal(sum(o), 100)
  withr::local_envvar(AUSPOL_DEMO_RESID_FULL = "0")
  o0 <- .demo_rebalance(s2, tot, c("ALP", "GRN"))
  expect_lt(o0[, "ALP"], 42)
  expect_equal(sum(o0), 100)
})
