# Seat-composition spread (AUSPOL_COMPOSITION_SD). docs/plans/prereg-composition-spread-2026-10-17.md

test_that("composition_sd_factor widens with the predicted IND share and never narrows", {
  sh <- matrix(c(40, 40, 10, 0,  30, 30, 10, 30,  35, 25, 40, 0), nrow = 3, byrow = TRUE,
               dimnames = list(c("party", "ind30", "grn40"), c("ALP", "LNP", "GRN", "IND")))
  co <- data.frame(class = c("GRN", "IND", "ONP"), b = c(-0.25, 0.25, 0.1), w = c(1, 1, 0))
  f <- composition_sd_factor(sh, co)
  expect_equal(unname(f[2]), max(1, exp((-0.25 * 1 + 0.25 * 3) / 2)))
  expect_equal(unname(f[1]), 1)        # GRN 10 alone has a negative sum: floored at 1, not narrowed
  expect_equal(unname(f[3]), 1)
  expect_true(all(f >= 1))
  # a class the shares do not carry (ONP) and a zero weight contribute nothing
  expect_equal(composition_sd_factor(sh, co[co$class == "ONP", ]), rep(1, 3))
})

test_that("size_sd_apply: composition off leaves the override alone; on widens every class of the IND seat only", {
  r <- withr::local_tempdir()
  writeLines("Package: x", file.path(r, "DESCRIPTION"))
  d <- file.path(r, "output"); dir.create(d)
  withr::local_options(auspol.root = r)
  withr::local_envvar(AUSPOL_SIZE_SD = "0", AUSPOL_COMPOSITION_SD = "0")
  sh <- matrix(c(45, 45, 10, 0,  30, 30, 10, 30), nrow = 2, byrow = TRUE,
               dimnames = list(c("plain", "indseat"), c("ALP", "LNP", "GRN", "IND")))
  expect_null(size_sd_apply(NULL, sh, "vic2026", c(1.1, 8.67)))
  data.table::fwrite(data.table::data.table(target = "vic2026", class = composition_sd_classes(),
                                            b = c(0, 0.25, 0, 0, 0), se = 0.05, w = c(0, 1, 0, 0, 0),
                                            n_cells = 1000L, n_pairs = 10L),
                     file.path(d, "spread-by-composition.csv"))
  withr::local_envvar(AUSPOL_COMPOSITION_SD = "1")
  o <- size_sd_apply(NULL, sh, "vic2026", c(1.1, 8.67))
  expect_true(all(is.na(o["plain", ])))
  p <- sh["indseat", ] / 100
  expect_equal(unname(o["indseat", ]), unname((1.1 + 8.67 * sqrt(p * (1 - p))) * exp(0.25 * 3 / 2)))
  expect_error(size_sd_apply(NULL, sh, "nsw2027", c(1.1, 8.67)), "no rows for nsw2027")
})

test_that("own mode widens only the non-major class's own cell, capped at s_max", {
  r <- withr::local_tempdir()
  writeLines("Package: x", file.path(r, "DESCRIPTION"))
  d <- file.path(r, "output"); dir.create(d)
  withr::local_options(auspol.root = r)
  withr::local_envvar(AUSPOL_SIZE_SD = "0", AUSPOL_COMPOSITION_SD = "own")
  sh <- matrix(c(45, 45, 10, 0,  30, 30, 10, 30), nrow = 2, byrow = TRUE,
               dimnames = list(c("plain", "indseat"), c("ALP", "LNP", "GRN", "IND")))
  co <- data.table::data.table(target = "vic2026", class = composition_sd_classes(),
                               a = c(0, 0.8, 0, 0, 0), w_a = c(0, 1, 0, 0, 0), b = c(0, 0.2, 0, 0, 0), w_b = c(0, 1, 0, 0, 0),
                               s_max = c(40, 20, 10, 10, 10), n_pairs = 10L)
  fm <- composition_own_factor(sh, co)
  expect_equal(unname(fm["indseat", "IND"]), exp((0.8 + 0.2 * 20 / 10) / 2))   # 30 capped at s_max 20
  expect_equal(unname(fm["plain", "IND"]), 1)                                     # not standing (0): nothing, no phantom votes
  expect_true(all(fm[, c("ALP", "LNP", "GRN")] == 1))
  data.table::fwrite(co, file.path(d, "spread-by-class-own.csv"))
  o <- size_sd_apply(NULL, sh, "vic2026", c(1.1, 8.67))
  expect_true(all(is.na(o[, c("ALP", "LNP", "GRN")])))                           # majors and GRN untouched
  p <- sh["indseat", "IND"] / 100
  expect_equal(unname(o["indseat", "IND"]), (1.1 + 8.67 * sqrt(p * (1 - p))) * exp((0.8 + 0.4) / 2))
  sh2 <- sh; sh2["plain", "IND"] <- 1.5; sh2["plain", "ALP"] <- 43.5
  expect_equal(unname(composition_own_factor(sh2, co)["plain", "IND"]), 1)        # under the 2-point training floor
  sh2["plain", "IND"] <- 2; sh2["plain", "ALP"] <- 43
  expect_equal(unname(composition_own_factor(sh2, co)["plain", "IND"]), exp((0.8 + 0.2 * 0.2) / 2))
  withr::local_envvar(AUSPOL_COMPOSITION_SD = "bogus")
  expect_error(size_sd_apply(NULL, sh, "vic2026", c(1.1, 8.67)), "must be")
})
