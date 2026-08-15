# Preference-flow carry-forward. The anchor's flow file is hand-maintained and
# incomplete; without this, a missing year silently becomes a 50-50 split.

fake_flows <- function() {
  data.table::data.table(
    year = c(2018L, 2018L, 2018L, 2022L, 2022L, 2018L),
    region = c("vic", "vic", "vic", "nsw", "nsw", "nsw"),
    party = c("GRN", "ONP", "OTH", "GRN", "OTH", "GRN"),
    flow_alp = c(81.94, 42.00, 50.5, 79.0, 51.0, 77.0),
    exhaust = c(0, 0, 0, 22.0, 30.0, 20.0)
  )
}

test_that("flows_for actually filters by region and year (NSE regression)", {
  # Written the obvious way, `flows[flows$region == region & ...]` inside a
  # data.table resolves the bare `region` to the COLUMN, so the mask is always
  # TRUE and every region's rows come back. That handed Victoria the federal
  # flows and moved its validation TPP by 3 points with nothing failing.
  f <- fake_flows()
  f <- rbind(f, data.table::data.table(
    year = 2028L, region = "fed", party = "GRN", flow_alp = 88.19, exhaust = 0))
  out <- flows_for(f, 2026, "vic", quiet = TRUE)
  expect_true(all(out$flow_year <= 2026))
  expect_equal(out$flow_alp[out$party == "GRN"], 81.94)  # vic 2018, not fed 2028
  expect_false(any(out$flow_alp == 88.19))
})

test_that("flows_for carries the most recent estimate forward", {
  f <- fake_flows()
  expect_message(flows_for(f, 2026, "vic"), "carried forward")
  out <- flows_for(f, 2026, "vic", quiet = TRUE)
  expect_true(setequal(out$party, c("GRN", "ONP", "OTH")))
  expect_equal(out$flow_alp[out$party == "GRN"], 81.94)
  expect_true(all(out$flow_year == 2018))
  expect_true(all(out$year == 2026))
})

test_that("flows_for prefers the nearer year when several exist", {
  f <- fake_flows()
  out <- flows_for(f, 2027, "nsw", quiet = TRUE)
  expect_equal(out$flow_alp[out$party == "GRN"], 79.0)   # 2022, not 2018
  expect_equal(out$flow_year[out$party == "GRN"], 2022)
})

test_that("flows_for never looks past the requested year or across regions", {
  f <- fake_flows()
  out <- flows_for(f, 2020, "nsw", quiet = TRUE)
  expect_equal(out$flow_alp[out$party == "GRN"], 77.0)   # the 2018 estimate
  expect_false("ONP" %in% out$party)                      # ONP is vic-only here
  expect_error(flows_for(f, 2026, "qld"), "No preference flows")
})

test_that("exhaust rates are carried with their own party's estimate", {
  f <- fake_flows()
  out <- flows_for(f, 2027, "nsw", quiet = TRUE)
  expect_equal(out$exhaust[out$party == "GRN"], 22.0)
  expect_equal(out$exhaust[out$party == "OTH"], 30.0)
})

test_that("an exact-year match is silent and unchanged", {
  f <- fake_flows()
  expect_silent(out <- flows_for(f, 2018, "vic"))
  expect_true(all(out$flow_year == 2018))
})
