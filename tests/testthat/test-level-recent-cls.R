# AUSPOL_LEVEL_RECENT_CLS (arm BLD, docs/plans/prereg-poll-lean-2026-11-02.md Amendment 1): the published value
# must give the old class set exactly, in the old order; a bad value must stop rather than fall back.

test_that("the published class set is the old one, in order", {
  withr::local_envvar(AUSPOL_LEVEL_RECENT_CLS = NA)
  expect_identical(lr_classes(), .LR_CLS)
  withr::local_envvar(AUSPOL_LEVEL_RECENT_CLS = "ALP,LNP,GRN")
  expect_identical(lr_classes(), c("ALP", "LNP", "GRN"))
})

test_that("One Nation can be added; Others, duplicates and unknown classes cannot", {
  withr::local_envvar(AUSPOL_LEVEL_RECENT_CLS = "ALP, LNP, GRN, ONP")
  expect_identical(lr_classes(), c("ALP", "LNP", "GRN", "ONP"))
  # not "": on Windows an empty variable is unset, so the default applies
  for (bad in c("ALP,LNP,GRN,OTH", "ALP,ALP", "ALP;LNP", " , ")) {
    withr::local_envvar(AUSPOL_LEVEL_RECENT_CLS = bad)
    expect_error(lr_classes(), "AUSPOL_LEVEL_RECENT_CLS")
  }
})
