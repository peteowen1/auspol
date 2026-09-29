test_that("the statewide mix and fundamentals learn only from earlier elections", {
  skip_if_not(file.exists(out_path("projection-data.csv")), "no projection data")
  f <- tryCatch(build_fundamentals_data(), error = function(e) NULL)
  skip_if(is.null(f), "no fundamentals data (anchor clone)")
  p <- data.table::fread(out_path("projection-data.csv"))
  el <- unique(p[, c("region", "year")])
  el <- el[elections_before(paste0(el$region, el$year), "nsw2019"), ]
  # An earlier election with fewer than 10 before IT has no time-forward
  # fundamentals, and drops out of the mix fit.
  n_before <- sum(is.finite(mapply(fundamentals_tf, el$region, el$year)))
  m <- projection_mix_tf("nsw", 2019L)
  expect_equal(m$n[m$horizon == 1], n_before)
  expect_lt(m$n[m$horizon == 1], sum(p$horizon == 1))
  # NSE-trap guard: a different target must give a different training set.
  expect_false(identical(projection_mix_tf("nsw", 2023L)$n, m$n))
  expect_true(is.finite(fundamentals_tf("nsw", 2023L)))
})

test_that("a leave-one-out value cached earlier does not answer a time-forward call", {
  f <- tryCatch(build_fundamentals_data(), error = function(e) NULL)
  skip_if(is.null(f), "no fundamentals data (anchor clone)")
  loo <- withr::with_envvar(c(AUSPOL_TIME_FORWARD_FITS = "0"), fundamentals_tf("nsw", 2019L))
  tf  <- withr::with_envvar(c(AUSPOL_TIME_FORWARD_FITS = "1"), fundamentals_tf("nsw", 2019L))
  expect_false(isTRUE(all.equal(loo, tf)))
})
