test_that("surge_blend_estimate leaves a zero-hazard estimate unchanged", {
  expect_equal(surge_blend_estimate(c(2, 5, 10), c(0, 0, 0), 35), c(2, 5, 10))
})

test_that("surge_blend_estimate moves fully to surge_mu at hazard 1", {
  expect_equal(surge_blend_estimate(c(2, 5), c(1, 1), 35), c(35, 35))
})

test_that("surge_blend_estimate is a genuine linear blend in between", {
  # This is the exact gap the fix closes: Zoe Daniel's uniform-swing estimate
  # (3.2%) barely moved on her own jump, but her fitted hazard should pull
  # the point estimate meaningfully toward the surge magnitude rather than
  # leaving it near the uniform-swing floor.
  out <- surge_blend_estimate(uniform_share = 3.2, p_hat = 0.6, surge_mu = 34.56)
  expect_equal(out, 0.4 * 3.2 + 0.6 * 34.56)
  expect_gt(out, 3.2 * 3)  # meaningfully higher than the unblended estimate
})

test_that("surge_blend_estimate rejects mismatched lengths", {
  expect_error(surge_blend_estimate(c(1, 2), c(0.5), 10), "same length")
})

test_that("a non-finite p_hat is treated as zero hazard, not propagated", {
  out <- surge_blend_estimate(c(5, 5), c(NA_real_, 0.5), 30)
  expect_equal(out[1], 5)
  expect_false(anyNA(out))
})
