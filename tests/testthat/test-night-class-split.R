# Night class split (R/night_class_split.R; plans/prereg-night-class-split-2026-11-14.md). Synthetic booths only.

ncs_live <- function() data.table::data.table(
  district = "Monash", booth = c("A", "A", "A", "A", "B", "B", "B", "B"), booth_type = "ordinary",
  candidate = rep(c("LEONARD, Deb", "BROADBENT, Russell", "ALDRED, Mary", "FLETCHER, Tully"), 2),
  party = rep(c("Independent", "Independent", "Liberal", "Labor"), 2), votes = c(170, 100, 320, 200, 17, 10, 32, 20))
ncs_par <- list(sd0 = 0.2, f = c(IND = 0.43, OTH = 0.24, OTH_RIGHT = 0.29))

test_that("the junior candidate's counted share of the class is the split, with sd shrinking as the seat counts", {
  x <- night_class_split(ncs_live(), list(Monash = "A"), c(Monash = 0.36), ncs_par, c("Monash", "Kooyong"))
  expect_identical(unname(x$cls["Monash"]), "IND")
  expect_equal(unname(x$cls_r["Monash"]), 100 / 270)
  expect_equal(unname(x$cls_sd["Monash"]), 0.2 * sqrt(1 - 0.36))
  expect_equal(unname(x$cls_f["Monash"]), 0.43)
  expect_true(is.na(x$cls["Kooyong"]))                     # a seat with nothing counted: no split
  expect_equal(attr(x, "detail")$n_cand, 2L)
  # only the counted units count
  y <- night_class_split(ncs_live(), list(Monash = "B"), c(Monash = 0.04), ncs_par, "Monash")
  expect_equal(unname(y$cls_r["Monash"]), 10 / 27)
})

test_that("one candidate per class, no parameters, or nothing counted gives no split", {
  one <- ncs_live()[ncs_live()$candidate != "BROADBENT, Russell"]
  expect_null(night_class_split(one, list(Monash = c("A", "B")), c(Monash = 1), ncs_par, "Monash"))
  expect_null(night_class_split(ncs_live(), list(Monash = "A"), c(Monash = 0.5), NULL, "Monash"))
  expect_null(night_class_split(ncs_live(), list(), c(Monash = 0), ncs_par, "Monash"))
  expect_error(night_class_split(ncs_live()[, -"candidate"], list(Monash = "A"), c(Monash = 0.5), ncs_par, "Monash"), "NCS1!")
})

test_that("merging keeps the Coalition elements, and gives neutral ones when the state has none", {
  ncs <- night_class_split(ncs_live(), list(Monash = "A"), c(Monash = 0.36), ncs_par, "Monash")
  m0 <- .night_merge_split(NULL, ncs, "Monash")
  expect_true(all(c("r", "sd", "f", "cls", "cls_r", "cls_sd", "cls_f") %in% names(m0)))
  expect_true(is.na(m0$r["Monash"])); expect_identical(m0$f, 0)
  cs0 <- list(r = c(Monash = 0.3), sd = c(Monash = 0.1), f = 0.8, cls = c(Monash = "OTH"))
  m1 <- .night_merge_split(cs0, ncs, "Monash")
  expect_identical(m1$f, 0.8); expect_identical(unname(m1$cls["Monash"]), "IND")
  expect_identical(.night_merge_split(cs0, NULL, "Monash"), cs0)
})

test_that("the live runner's class_split setting: on by default, off when asked, cached per election", {
  local_mocked_bindings(night_class_split_params = function(target_election) list(sd0 = 0.2, f = c(IND = 0.4)))
  ca <- new.env()
  expect_identical(suppressMessages(.night_class_split_cfg(NULL, "vic2026", ca))$sd0, 0.2)
  expect_true(exists("class_split_vic2026", envir = ca, inherits = FALSE))
  expect_null(.night_class_split_cfg("off", "vic2026", ca))
  expect_identical(suppressMessages(.night_class_split_cfg("on", "vic2026", NULL))$f, c(IND = 0.4))
  expect_error(.night_class_split_cfg("yes", "vic2026", ca), "NW23!")
})
