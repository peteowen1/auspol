test_that("anchor_clone_age reads the clone's commit age and flags staleness (2026-10-31 stale-clone artifact)", {
  a <- anchor_clone_age()
  skip_if(is.na(a$commit), "no anchor clone with git history here")
  expect_true(is.finite(a$age_days) && a$age_days >= 0)
  expect_true(anchor_clone_age(max_age_days = -1)$stale)            # any clone is older than -1 days: the flag can fire
  expect_false(anchor_clone_age(max_age_days = 1e6)$stale)
})

test_that("anchor_clone_age returns NA, not an error, where there is no clone", {
  withr::local_options(auspol.anchor_dir = tempfile())
  a <- anchor_clone_age()
  expect_true(is.na(a$commit) && is.na(a$stale))
})
