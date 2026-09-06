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

test_that("surge_hazard_for names the recipient class per seat", {
  skip_if_not(exists("surge_hazard_for"))
  skip_if(!file.exists(file.path("output", "salience-v6.csv")) || !file.exists(file.path("output", "candidacies.csv")),
          "needs the salience corpus")
  pairs <- list(list(election = "fed2019", prev = "fed2016", region = "fed"),
                list(election = "vic2022", prev = "vic2018", region = "vic"))
  h <- surge_hazard_for("fed2022", "fed2019", "fed", pairs)
  skip_if(is.null(h), "no hazard for fed2022 here")
  expect_true(all(c("seat", "party") %in% names(h$seat_recipient)))
  expect_equal(nrow(h$seat_recipient), nrow(h$seat_hazard))
  expect_false(anyNA(h$seat_recipient$party))
})

test_that("surge_hazard_for returns a per-band expected vote fitted without the target election", {
  skip_if(!file.exists(file.path("output", "salience-v6.csv")) || !file.exists(file.path("output", "candidacies.csv")),
          "needs the salience corpus")
  pairs <- list(list(election = "fed2019", prev = "fed2016", region = "fed"),
                list(election = "vic2022", prev = "vic2018", region = "vic"),
                list(election = "nsw2023", prev = "nsw2019", region = "nsw"))
  h <- surge_hazard_for("fed2022", "fed2019", "fed", pairs)
  skip_if(is.null(h), "no hazard for fed2022 here")
  e <- h$seat_party_expected
  expect_true(all(c("seat", "party", "exp_pcv", "exp_sd") %in% names(e)))
  expect_false(anyNA(e$exp_pcv)); expect_true(all(e$exp_pcv >= 0))
  # The expectation must RISE with salience: the top band beats the bottom.
  bt <- h$band_table
  expect_true(bt$exp_pcv[which.max(as.character(bt$.b))] >= min(bt$exp_pcv))
  # And it must be an expectation over winners AND losers, so below surge_mu.
  expect_true(max(e$exp_pcv) < h$surge_mu)
})
