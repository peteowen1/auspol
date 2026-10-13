fe_table <- function(path) {
  utils::write.csv(data.frame(
    election = c("sa2014", "sa2014", "sa2014", "sa2018"),
    party = c("GRN", "IND", "ONP", "GRN"),
    flow_alp = c(80, 50, 40, 70), exhaust = c(0, 10, 0, 0),
    n_seats = c(10L, 6L, 3L, 12L)), path, row.names = FALSE)
  path
}
fe_ref <- function() data.table::data.table(
  election = "fed2013", seat = rep(c("a", "b"), each = 2), round = 2L,
  from = "GRN", to = rep(c("ALP", "LNP"), 2), votes = c(300, 100, 100, 100))

test_that("synthetic events use ONLY the named election's estimate and the right split", {
  f <- fe_table(tempfile(fileext = ".csv"))
  ev <- estimated_flow_events("sa2014", fe_ref(), estimates = f, min_seats = 5L)
  expect_setequal(unique(ev$from), c("GRN", "IND"))            # ONP (3 seats) is below min_seats, sa2018's GRN is not sa2014's
  expect_equal(length(unique(ev$seat[ev$from == "GRN"])), 10L)
  expect_equal(length(unique(ev$seat[ev$from == "IND"])), 6L)
  g <- ev[ev$from == "GRN" & ev$seat == ev$seat[1], ]
  expect_equal(sum(g$votes), 300)                              # sized from the reference: two events of 400 and 200
  expect_equal(g$votes[g$to == "ALP"] / sum(g$votes), 0.80)
  i <- ev[ev$from == "IND" & ev$seat == unique(ev$seat[ev$from == "IND"])[1], ]
  expect_equal(i$votes[i$to == "ALP"] / sum(i$votes), 0.50 / 0.90)   # exhaust is not a destination, so the two shares are what is left
  expect_true(all(ev$election == "sa2014"))
  s <- attr(ev, "summary")
  expect_equal(s$sized_from_reference, c(TRUE, FALSE))         # no IND events in the reference: overall mean
})

test_that("an election with no estimate gives zero rows, and the events feed build_flow_matrix", {
  f <- fe_table(tempfile(fileext = ".csv"))
  expect_equal(nrow(estimated_flow_events("sa2030", fe_ref(), estimates = f)), 0L)
  ev <- estimated_flow_events("sa2014", fe_ref(), estimates = f)
  fm <- build_flow_matrix(rbind(fe_ref()[, names(ev), with = FALSE], ev), min_n = 3L)
  expect_true("GRN|ALP+LNP" %in% names(fm$conditional))
  expect_gt(fm$conditional[["GRN|ALP+LNP"]][["ALP"]], 70)       # 10 estimated events at 80% dominate 2 federal events at 62.5%
})

test_that("bad estimates are refused, not coerced", {
  f <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(election = "sa2014", party = "GRN", flow_alp = 120, exhaust = 0, n_seats = 9L), f, row.names = FALSE)
  expect_error(estimated_flow_events("sa2014", fe_ref(), estimates = f))
  expect_error(estimated_flow_events("sa2014", fe_ref(), estimates = tempfile()), "missing")
})
