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
