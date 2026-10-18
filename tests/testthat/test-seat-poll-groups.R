# Seat-poll groups by method and sponsor (AUSPOL_SEAT_POLL_GROUPS). docs/plans/prereg-seat-poll-method-weights-2026-10-18.md

test_that("the groups switch is validated and picks the group set", {
  withr::local_envvar(AUSPOL_SEAT_POLL_GROUPS = "0")
  expect_equal(auspol:::.seat_poll_group_names(), c("mrp", "direct", "sponsored"))
  withr::local_envvar(AUSPOL_SEAT_POLL_GROUPS = "method")
  expect_equal(auspol:::.seat_poll_group_names(), c("mrp", "direct_indep", "direct_stake", "optin"))
  withr::local_envvar(AUSPOL_SEAT_POLL_GROUPS = "methods")
  expect_error(auspol:::.seat_poll_group_names(), "must be")
})

test_that("only opt-in under 'method' starts from the near-zero-weight prior; everything else from the pool", {
  withr::local_envvar(AUSPOL_SEAT_POLL_GROUPS = "method")
  expect_equal(auspol:::.seat_poll_group_prior("optin", 16), auspol:::SEAT_POLL_OPTIN_FLOOR_PRIOR)
  expect_equal(auspol:::.seat_poll_group_prior("direct_stake", 16), 16)
  expect_equal(auspol:::.seat_poll_group_prior("mrp", 20), 20)
  withr::local_envvar(AUSPOL_SEAT_POLL_GROUPS = "method0")
  expect_equal(auspol:::.seat_poll_group_prior("optin", 16), 16)
  # at the prior, an opt-in poll of n = 1,000 at 40% carries about a tenth of a direct poll's weight
  sv <- 40 * 60 / 1000
  expect_lt((sv + 16) / (sv + auspol:::SEAT_POLL_OPTIN_FLOOR_PRIOR), 0.12)
})

test_that("the method table maps method and sponsor to the four groups", {
  skip_if_not(file.exists(file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "poll_methods.csv")))
  m <- auspol:::.seat_poll_method_table()
  expect_true(all(m$mgroup %in% c("mrp", "direct_indep", "direct_stake", "optin")))
  expect_true(all(m$mgroup[m$method == "optin_link"] == "optin"))
  expect_true(all(m$mgroup[m$method == "mrp"] == "mrp"))
  st <- m$method != "mrp" & m$method != "optin_link" & m$sponsor_type %in% c("party", "union", "advocacy_group", "industry_lobby")
  expect_true(all(m$mgroup[st] == "direct_stake"))
})
