# AUSPOL_COV_TF / cov_time_forward(): a target's correlation may use only pairs
# whose second election is strictly before it, shrunk smoothly by n.

make_D <- function(seed = 1) {
  set.seed(seed)
  nm <- c("fed2007", "fed2010", "fed2013", "fed2016", "fed2019", "nsw2019",
          "fed2022", "nsw2023", "sa2026")
  matrix(rnorm(length(nm) * 4), length(nm), 4,
         dimnames = list(nm, c("ALP", "LNP", "GRN", "ONP")))
}

test_that("earliest target gets the identity", {
  D <- make_D()
  e <- cov_time_forward(D, "fed2007")
  expect_equal(e$n_pairs, 0L)
  expect_equal(unname(e$cor_shrunk), diag(4))
  e2 <- cov_time_forward(D, "fed2013")           # n = 2 < 3
  expect_equal(e2$n_pairs, 2L)
  expect_equal(unname(e2$cor_shrunk), diag(4))
})

test_that("no later pair influences a target", {
  D <- make_D()
  base <- cov_time_forward(D, "nsw2019")
  expect_equal(sort(base$earlier),
               c("fed2007", "fed2010", "fed2013", "fed2016"))  # fed2019 (May) is AFTER nsw2019 (March)
  D2 <- D
  D2["fed2022", ] <- D2["fed2022", ] + 50      # later pair
  D2["sa2026", ]  <- -D2["sa2026", ] * 9       # later pair
  D2["nsw2019", ] <- D2["nsw2019", ] + 7       # the target's own pair
  expect_identical(cov_time_forward(D2, "nsw2019")$cor_shrunk, base$cor_shrunk)
  # an EARLIER pair does move it, so the test can fail
  D3 <- D; D3["fed2016", ] <- D3["fed2016", ] * c(5, -3, 2, 8)
  expect_false(isTRUE(all.equal(cov_time_forward(D3, "nsw2019")$cor_shrunk,
                                base$cor_shrunk)))
})

test_that("shrink weight grows smoothly with n and follows lambda*n/(n+K)", {
  D <- make_D()
  tg <- c("fed2016", "fed2019", "fed2022", "sa2026")
  w <- vapply(tg, function(t) cov_time_forward(D, t, lambda = 0.5, K = 5)$w, numeric(1))
  n <- vapply(tg, function(t) cov_time_forward(D, t)$n_pairs, numeric(1))
  expect_true(all(diff(w) > 0))
  expect_equal(unname(w), unname(0.5 * n / (n + 5)))
  expect_lt(max(w), 0.5)
  expect_lt(cov_time_forward(D, "sa2026", K = 20)$w,
            cov_time_forward(D, "sa2026", K = 5)$w)
})

test_that("a zero-variance column gets zero correlation and is reported", {
  D <- make_D(); D[, "ONP"] <- 0
  e <- cov_time_forward(D, "sa2026")
  expect_equal(e$zero_var, "ONP")
  expect_true(all(e$cor["ONP", -4] == 0))
  expect_false(anyNA(e$cor_shrunk))
})

test_that("a deliberately leaky input is caught", {
  D <- make_D()
  clean <- cov_time_forward(D, "nsw2019")
  # a leave-one-out builder uses every other pair, including later ones
  loo <- stats::cor(D[rownames(D) != "nsw2019", ])
  expect_false(isTRUE(all.equal(unname(clean$cor), unname(loo))))
  d <- election_dates()
  expect_true(all(d[clean$earlier] < d["nsw2019"]))
  expect_false(any(c("fed2022", "nsw2023", "sa2026", "nsw2019") %in% clean$earlier))
  # a pair with no recorded date refuses rather than silently entering
  D4 <- D; rownames(D4)[1] <- "zzz1999"
  expect_error(cov_time_forward(D4, "nsw2019"), "no polling day")
})

test_that("statewide_cor honours AUSPOL_COV_TF and labels the source", {
  D <- make_D()
  tf <- lapply(stats::setNames(nm = rownames(D)), function(t) cov_time_forward(D, t))
  co <- list(change = D, cor = stats::cor(D), cor_shrunk = stats::cor(D),
             by_target = list(nsw2019 = list(cor = diag(4), cor_shrunk = diag(4),
                                             n_pairs = 8)),
             by_target_tf = tf, lambda = 0.5)
  p <- tempfile(fileext = ".rds"); saveRDS(co, p)
  old <- Sys.getenv("AUSPOL_COV_TF", NA)
  on.exit(if (is.na(old)) Sys.unsetenv("AUSPOL_COV_TF") else Sys.setenv(AUSPOL_COV_TF = old))
  Sys.setenv(AUSPOL_COV_TF = "1")
  m <- statewide_cor("nsw2019", path = p)
  expect_match(attr(m, "cor_source"), "time-forward, 4 earlier pairs")
  expect_equal(unname(m), unname(tf$nsw2019$cor_shrunk), ignore_attr = TRUE)
  Sys.setenv(AUSPOL_COV_TF = "0")
  expect_match(attr(statewide_cor("nsw2019", path = p), "cor_source"), "leave-one-out")
})
