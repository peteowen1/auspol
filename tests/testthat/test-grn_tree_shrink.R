# Greens tree shrink -- docs/plans/prereg-grn-tree-shrink-2026-10-24.md
fc <- data.table::data.table(
  election = rep(c("fed2016", "fed2019", "fed2022"), each = 3),
  party = "GRN",
  base_pred = rep(c(10, 25, 40), 3),
  xgb_pred = rep(c(11, 28, 46), 3),        # the trees push up harder as the base grows
  actual_share = rep(c(11, 26.5, 41), 3))  # and only part of that push is real

test_that("grn_tree_shrink_mode validates and defaults to off", {
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = NA), expect_equal(grn_tree_shrink_mode(), "0"))
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = "1"), expect_equal(grn_tree_shrink_mode(), "1"))
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = "50"), expect_equal(grn_tree_shrink_mode(), "50"))
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = "yes"), expect_error(grn_tree_shrink_mode(), "must be"))
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = "1"),
    expect_true("AUSPOL_GRN_TREE_SHRINK" %in% names(post_xgb_switches())))
})

test_that("the fit is time-forward and shrunk by G/(G+k)", {
  expect_equal(grn_tree_shrink_fit("fed2016", fc)$G, 0L)        # nothing before the first
  expect_equal(grn_tree_shrink_fit("fed2016", fc)$lambda, 0)
  f <- grn_tree_shrink_fit("fed2022", fc)
  expect_equal(f$G, 2L)                                          # fed2022 itself is not read
  expect_gt(f$lambda_raw, 0)
  expect_equal(f$lambda, f$lambda_raw * 2 / (2 + 3))
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK_K = "0"),
    expect_equal(grn_tree_shrink_fit("fed2022", fc)$lambda, f$lambda_raw))
  # trees that were right: no pull at all
  ok <- data.table::copy(fc); ok$actual_share <- ok$xgb_pred
  expect_equal(grn_tree_shrink_fit("fed2022", ok)$lambda_raw, 0, tolerance = 1e-4)
})

test_that("apply: off is identical, a fixed k pulls high-base seats hardest", {
  base <- matrix(c(10, 40, 50, 30, 40, 30), 2, dimnames = list(c("A", "B"), c("GRN", "ALP", "LNP")))
  tree <- base; tree[, "GRN"] <- c(12, 48)
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = "0"),
    expect_identical(grn_tree_shrink_apply(tree, base, "fed2025"), tree))
  r <- withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = "40"),
    capture.output(x <- grn_tree_shrink_apply(tree, base, "fed2025")))
  expect_equal(unname(x[, "GRN"]), c(10 + 2 / (1 + 10 / 40), 40 + 8 / 2))
  expect_equal(x[, c("ALP", "LNP")], tree[, c("ALP", "LNP")])     # caller renormalises
  noGrn <- tree[, c("ALP", "LNP")]
  withr::with_envvar(c(AUSPOL_GRN_TREE_SHRINK = "40"),
    expect_identical(grn_tree_shrink_apply(noGrn, base, "fed2025"), noGrn))
})
