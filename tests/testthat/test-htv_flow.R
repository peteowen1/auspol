# How-to-vote card selects the Liberal-excluded ALP:GRN flow row -- docs/plans/prereg-htv-flow-2026-09-18.md
fm <- list(conditional = list("LNP|ALP+GRN"     = c(ALP = 60, GRN = 40),
                              "LNP|ALP+GRN+IND" = c(ALP = 50, GRN = 30, IND = 20),
                              "LNP|ALP+IND"     = c(ALP = 70, IND = 30),
                              "GRN|ALP+LNP"     = c(ALP = 80, LNP = 20)))
tab <- data.frame(election = c("vic2022", "vic2022"), seat = c("ALL", "Kew"),
                  greens_above_labor = c(TRUE, FALSE), source = "test")
rows <- list(greens_above = 35, labor_above = 62)

test_that("only Liberal-excluded rows with both ALP and GRN alive change, other survivors untouched", {
  r <- htv_flow_override(NULL, fm, "vic2022", c("Footscray", "Kew"), table = tab, rows = rows)
  expect_equal(unname(r$Footscray[["LNP|ALP+GRN"]]), c(35, 65))
  expect_equal(unname(r$Footscray[["LNP|ALP+GRN+IND"]]), c(80 * 0.35, 80 * 0.65, 20))
  expect_equal(r$Footscray[["LNP|ALP+IND"]], fm$conditional[["LNP|ALP+IND"]])
  expect_equal(r$Footscray[["GRN|ALP+LNP"]], fm$conditional[["GRN|ALP+LNP"]])
  # a seat-level entry overrides the ALL entry
  expect_equal(unname(r$Kew[["LNP|ALP+GRN"]]), c(62, 38))
  expect_equal(attr(r, "htv")$applied, 2L)
})

test_that("no entry for the election leaves the override untouched, and an existing per-seat list is edited in place", {
  ov <- list(Footscray = list("LNP|ALP+GRN" = c(ALP = 55, GRN = 45)))
  attr(ov, "sd") <- "keep-me"
  expect_identical(htv_flow_override(ov, fm, "nsw2023", "Footscray", table = tab, rows = rows), ov)
  r <- htv_flow_override(ov, fm, "vic2022", "Footscray", table = tab, rows = rows)
  expect_equal(unname(r$Footscray[["LNP|ALP+GRN"]]), c(35, 65))
  expect_equal(attr(r, "sd"), "keep-me")
})

test_that("fit_htv_flow_rows leaves the target out and labels by the observed split", {
  d <- tempfile(); dir.create(d)
  tx <- data.table::data.table(
    election = c(rep("a2018", 4), rep("b2022", 4), rep("c2024", 4)),
    seat = rep(c("S1", "S1", "S2", "S2"), 3), round = 3L,
    from = "LNP", to = rep(c("ALP", "GRN"), 6),
    votes = c(60, 40, 60, 40,  30, 70, 30, 70,  70, 30, 70, 30))
  data.table::fwrite(tx, file.path(d, "x-transfers.csv"))
  f <- fit_htv_flow_rows("c2024", dir = d, min_seats = 2L)
  expect_equal(f$greens_above, 30); expect_equal(f$labor_above, 60)   # c2024's own 70% excluded
  g <- fit_htv_flow_rows("zzz", dir = d, min_seats = 2L)
  expect_equal(g$labor_above, 65)                                       # both labor-above elections, seat-weighted
})
