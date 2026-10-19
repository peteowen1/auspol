# harness_sw_draws(): state harnesses get the statewide draws the live forecast ships (audit F4,
# plans/prereg-harness-sw-draws-2026-10-19.md)
.swd_fixture <- function(n = 50L) {
  set.seed(1)
  d <- cbind(ALP = stats::rnorm(n, 35, 2.5), LNP = stats::rnorm(n, 35, 2.5), GRN = stats::rnorm(n, 12, 2.5))
  d
}

test_that("off (the default) returns NULL whatever it is given", {
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = NA)
  expect_null(harness_sw_draws(.swd_fixture(), c("ALP", "LNP"), 10L, "vic2022"))
})

test_that("on: the first n rows of exactly the simulator's columns, in its order, and the spread is printed", {
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "1", AUSPOL_PARTY_COR = "off")
  d <- .swd_fixture()
  out <- NULL
  txt <- utils::capture.output(out <- harness_sw_draws(d, c("LNP", "ALP"), 10L, "vic2022", code = "BVW"))
  expect_identical(dim(out), c(10L, 2L))
  expect_identical(colnames(out), c("LNP", "ALP"))
  expect_identical(unname(out[, "ALP"]), unname(d[1:10, "ALP"]))
  expect_match(txt, "^BVW1 vic2022: statewide draws applied \\(10 x 2\\)")
  # a later block (Victoria's flow ensemble) starts where it is told
  utils::capture.output(b <- harness_sw_draws(d, "ALP", 10L, "vic2022", from = 11L, quiet = TRUE))
  expect_identical(unname(b[, "ALP"]), unname(d[11:20, "ALP"]))
})

test_that("on: a pair it cannot serve says so (SW0!) and keeps the flat spread, never silently", {
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "1", AUSPOL_PARTY_COR = "off")
  d <- .swd_fixture()
  expect_output(expect_null(harness_sw_draws(NULL, "ALP", 10L, "wa2021", code = "BWW")), "BWW0! wa2021: no draws")
  expect_output(expect_null(harness_sw_draws(d, c("ALP", "ONP"), 10L, "qld2024")), "draws lack ONP")
  expect_output(expect_null(harness_sw_draws(d, "ALP", 60L, "sa2026")), "50 draws, 60 needed")
})

test_that("on: a correlation arm cannot silently do nothing, and a bad value stops", {
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "1", AUSPOL_PARTY_COR = "on")
  expect_error(harness_sw_draws(.swd_fixture(), "ALP", 10L, "vic2022"), "no-op")
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "yes", AUSPOL_PARTY_COR = "off")
  expect_error(harness_sw_draws(.swd_fixture(), "ALP", 10L, "vic2022"), "must be")
})

test_that("net: the seat sd gives back exactly the draws' extra variance, with the floor counted", {
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "net", AUSPOL_PARTY_COR = "off")
  shares <- matrix(c(40, 35, 10, 45, 30, 2), 2, 3, byrow = TRUE, dimnames = list(c("A", "B"), c("ALP", "LNP", "GRN")))
  set.seed(2)
  dr <- cbind(ALP = stats::rnorm(4000, 0, 3), LNP = stats::rnorm(4000, 0, 3), GRN = stats::rnorm(4000, 0, 1))
  lsd <- c(1.10, 8.67)
  txt <- utils::capture.output(out <- harness_sw_net_sd(NULL, dr, shares, lsd, NULL, 1.5, "vic2022", "BVW"))
  base <- lsd[1] + lsd[2] * sqrt(shares / 100 * (1 - shares / 100))
  V <- apply(dr, 2, stats::var)
  # total variance (seat + statewide) is what it was under the flat 1.5, cell by cell, wherever the floor does not bind
  tot_new <- sweep(out^2, 2, V, `+`); tot_old <- base^2 + 1.5^2
  expect_equal(unname(tot_new[, c("ALP", "LNP")]), unname(tot_old[, c("ALP", "LNP")]), tolerance = 1e-10)
  # the Greens' draws are NARROWER than 1.5, so their seat sd widens
  expect_true(all(out[, "GRN"] > base[, "GRN"]))
  expect_match(txt, "^BVWN1 vic2022: seat sd net of the draws")
  # a cell where the identity would go below half its sd is floored there, and counted
  big <- dr; big[, "ALP"] <- big[, "ALP"] * 4
  txt2 <- utils::capture.output(o2 <- harness_sw_net_sd(NULL, big, shares, lsd, NULL, 1.5, "vic2022", "BVW"))
  expect_equal(unname(o2[, "ALP"]), unname(0.5 * base[, "ALP"]))
  expect_match(txt2, "2 of 6 cells at the 0.5 floor")
  # an existing override (size factor) is what gets netted, not the bare level sd
  so <- matrix(NA_real_, 2, 3, dimnames = dimnames(shares)); so["A", "ALP"] <- 9
  utils::capture.output(o3 <- harness_sw_net_sd(so, dr, shares, lsd, NULL, 1.5, "x", "BVW"))
  expect_equal(o3["A", "ALP"], sqrt(81 - (V[["ALP"]] - 2.25)))
})

test_that("net off, or no draws, leaves the override untouched; the width switch reads and validates", {
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "1")
  so <- matrix(1, 1, 1)
  expect_identical(harness_sw_net_sd(so, matrix(0, 2, 1, dimnames = list(NULL, "ALP")), so, c(1, 1), NULL, 1.5, "x"), so)
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "net")
  expect_identical(harness_sw_net_sd(so, NULL, so, c(1, 1), NULL, 1.5, "x"), so)
  withr::local_envvar(AUSPOL_FP_EXTRA_SD = NA)
  expect_identical(fp_extra_sd_env(), 2.419)
  withr::local_envvar(AUSPOL_FP_EXTRA_SD = "1.2")
  expect_identical(fp_extra_sd_env(), 1.2)
  withr::local_envvar(AUSPOL_FP_EXTRA_SD = "-1")
  expect_error(fp_extra_sd_env(), "must be one number")
})

test_that("force applies the net-out whatever the harness switch says (the published forecast's own switch decides)", {
  withr::local_envvar(AUSPOL_HARNESS_SW_DRAWS = "0")
  shares <- matrix(c(40, 35), 1, 2, dimnames = list("A", c("ALP", "LNP")))
  set.seed(3); dr <- cbind(ALP = stats::rnorm(2000, 0, 3), LNP = stats::rnorm(2000, 0, 3))
  expect_null(harness_sw_net_sd(NULL, dr, shares, c(1.10, 8.67), NULL, 1.5, "vic2026", "SWL"))
  utils::capture.output(o <- harness_sw_net_sd(NULL, dr, shares, c(1.10, 8.67), NULL, 1.5, "vic2026", "SWL", force = TRUE))
  expect_true(all(o < 1.10 + 8.67 * sqrt(shares / 100 * (1 - shares / 100))))
})
