# docs/plans/prereg-reentry-flatratio-variance-2026-09-08.md. These are the
# dry-run cases from that plan, checked here rather than only by eye.

mk_shares <- function() {
  matrix(c(45, 35, 12, 8,
           38, 40, 15, 7,
           50, 30, 12, 8), nrow = 3, byrow = TRUE,
        dimnames = list(c("A", "B", "C"), c("ALP", "LNP", "GRN", "IND")))
}

test_that("k_sd = 0 is an exact no-op: every cell is NA", {
  sh <- mk_shares()
  re <- data.frame(seat = c("A", "B"), party = c("GRN", "IND"),
                   value = c(10, 20), n = c(29, 2), path = c("ratio", "ratio"))
  out <- reentry_sd_matrix(sh, re, level_sd = c(1.10, 8.67), k_sd = 0)
  expect_true(all(is.na(out)))
  expect_equal(dim(out), dim(sh))
  expect_equal(dimnames(out), dimnames(sh))
  expect_equal(attr(out, "n_set"), 0L)
})

test_that("a class with more evidence gets a SMALLER sd bump", {
  # GRN has ~29 rows in the corpus, ALP/LNP have 1-4. k_sd/sqrt(n) must give
  # GRN the small bump and ALP/LNP the large one -- not a flat bump that
  # happens to average out right.
  sh <- mk_shares()
  re <- data.frame(seat = c("A", "B"), party = c("GRN", "ALP"),
                   value = c(10, 20), n = c(29, 2), path = c("ratio", "ratio"))
  out <- reentry_sd_matrix(sh, re, level_sd = c(1.10, 8.67), k_sd = 10)
  base_a <- 1.10 + 8.67 * sqrt((sh["A", "GRN"] / 100) * (1 - sh["A", "GRN"] / 100))
  base_b <- 1.10 + 8.67 * sqrt((sh["B", "ALP"] / 100) * (1 - sh["B", "ALP"] / 100))
  extra_grn <- 10 / sqrt(29)
  extra_alp <- 10 / sqrt(2)
  expect_equal(out["A", "GRN"], sqrt(base_a^2 + extra_grn^2))
  expect_equal(out["B", "ALP"], sqrt(base_b^2 + extra_alp^2))
  expect_gt(extra_alp, extra_grn)
  expect_gt(out["B", "ALP"] - base_b, out["A", "GRN"] - base_a)
})

test_that("a GLM-path cell and an untouched seat are left NA", {
  sh <- mk_shares()
  re <- data.frame(seat = c("A", "C"), party = c("IND", "GRN"),
                   value = c(10, 5), n = c(415, 40), path = c("glm", "glm"))
  out <- reentry_sd_matrix(sh, re, level_sd = c(1.10, 8.67), k_sd = 10)
  # Both rows are GLM-path, so nothing should be set at all.
  expect_true(all(is.na(out)))
  # A cell absent from `re` entirely (B, LNP) must also stay NA even with
  # ratio-path rows elsewhere.
  re2 <- data.frame(seat = "A", party = "GRN", value = 10, n = 5, path = "ratio")
  out2 <- reentry_sd_matrix(sh, re2, level_sd = c(1.10, 8.67), k_sd = 10)
  expect_true(is.na(out2["B", "LNP"]))
  expect_false(is.na(out2["A", "GRN"]))
})

test_that("n = 0 or non-finite n is excluded rather than dividing by zero", {
  sh <- mk_shares()
  re <- data.frame(seat = "A", party = "GRN", value = 10,
                   n = 0, path = "ratio")
  out <- reentry_sd_matrix(sh, re, level_sd = c(1.10, 8.67), k_sd = 10)
  expect_true(all(is.na(out)))
  re[["n"]] <- NA_integer_
  out2 <- reentry_sd_matrix(sh, re, level_sd = c(1.10, 8.67), k_sd = 10)
  expect_true(all(is.na(out2)))
})

test_that("an empty or NULL reentry frame is a clean no-op", {
  sh <- mk_shares()
  empty <- data.frame(seat = character(0), party = character(0),
                      value = numeric(0), n = integer(0), path = character(0))
  expect_true(all(is.na(reentry_sd_matrix(sh, empty, c(1.10, 8.67), k_sd = 10))))
  expect_true(all(is.na(reentry_sd_matrix(sh, NULL, c(1.10, 8.67), k_sd = 10))))
})

# ---- combine_sd_override ----------------------------------------------------

test_that("combine_sd_override takes the larger value, never understating either", {
  a <- matrix(c(1, NA, NA, 4), 2, 2, dimnames = list(c("s1", "s2"), c("p1", "p2")))
  b <- matrix(c(NA, 5, NA, 2), 2, 2, dimnames = list(c("s1", "s2"), c("p1", "p2")))
  out <- combine_sd_override(a, b)
  expect_equal(unname(out["s1", "p1"]), 1)   # only a has an opinion
  expect_equal(unname(out["s2", "p1"]), 5)   # only b has an opinion
  expect_true(is.na(out["s1", "p2"]))        # neither has an opinion
  expect_equal(unname(out["s2", "p2"]), 4)   # both do; the larger wins
  expect_equal(dimnames(out), dimnames(a))
})

test_that("combine_sd_override passes either NULL argument through unchanged", {
  a <- matrix(1, 2, 2, dimnames = list(c("s1", "s2"), c("p1", "p2")))
  expect_identical(combine_sd_override(a, NULL), a)
  expect_identical(combine_sd_override(NULL, a), a)
  expect_null(combine_sd_override(NULL, NULL))
})

test_that("combine_sd_override refuses mismatched shapes rather than recycling", {
  a <- matrix(1, 2, 2, dimnames = list(c("s1", "s2"), c("p1", "p2")))
  b <- matrix(1, 3, 2)
  expect_error(combine_sd_override(a, b), "same shape")
})
