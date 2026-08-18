# Building a flow matrix from observed transfers. No external data: the whole
# point is that the logic is checkable in CI while the election data it will
# really consume cannot be committed.

fake_transfers <- function() {
  # Two seats, each excluding GRN with ALP and LNP standing, plus one seat
  # excluding GRN with ALP and ONP standing. The two configurations must NOT
  # be pooled together -- that is the property the whole design exists for.
  data.table::data.table(
    election = "vic2022",
    seat  = c("A","A", "B","B", "C","C"),
    round = 1L,
    from  = "GRN",
    to    = c("ALP","LNP", "ALP","LNP", "ALP","ONP"),
    votes = c(800, 200,  900, 100,  600, 400)
  )
}

test_that("cells are keyed on the survivor set, not just the excluded party", {
  m <- build_flow_matrix(fake_transfers(), min_n = 2L)
  expect_true("GRN|ALP+LNP" %in% names(m$conditional))
  expect_equal(unname(m$conditional[["GRN|ALP+LNP"]][["ALP"]]), 85)  # 1700/2000
  # the ALP+ONP seat is a separate cell and is withheld at min_n = 2 (n = 1)
  expect_false("GRN|ALP+ONP" %in% names(m$conditional))
})

test_that("withheld cells still appear in coverage, flagged", {
  m <- build_flow_matrix(fake_transfers(), min_n = 2L)
  cov <- m$coverage
  expect_true("GRN|ALP+ONP" %in% cov$cell)
  expect_false(cov$used[cov$cell == "GRN|ALP+ONP"])
  expect_true(cov$used[cov$cell == "GRN|ALP+LNP"])
  # a caller can therefore see WHICH rates rest on how much
  expect_equal(cov$n[cov$cell == "GRN|ALP+LNP"], 2L)
})

test_that("the pooled row averages across configurations", {
  m <- build_flow_matrix(fake_transfers(), min_n = 2L)
  # ALP total 2300 of 3000
  expect_equal(unname(round(m$pooled[["GRN"]][["ALP"]], 4)),
               round(100 * 2300 / 3000, 4))
  expect_equal(sum(m$pooled[["GRN"]]), 100)
})

test_that("min_n controls what is trusted, and is not cosmetic", {
  t <- fake_transfers()
  strict <- build_flow_matrix(t, min_n = 3L)
  loose  <- build_flow_matrix(t, min_n = 1L)
  expect_length(strict$conditional, 0L)      # nothing has 3 events
  expect_length(loose$conditional, 2L)       # both cells qualify
})

test_that("shares within a cell sum to 100", {
  m <- build_flow_matrix(fake_transfers(), min_n = 1L)
  for (nm in names(m$conditional)) {
    expect_equal(sum(m$conditional[[nm]]), 100, tolerance = 1e-8,
                 info = nm)
  }
})

test_that("the output plugs straight into distribute_preferences", {
  m <- build_flow_matrix(fake_transfers(), min_n = 2L)
  r <- distribute_preferences(c(ALP = 40, LNP = 38, GRN = 22),
                              conditional = m$conditional,
                              pooled = m$pooled, smooth = 0)
  expect_equal(r$winner, "ALP")
  expect_equal(r$fallbacks, 0L)   # the ALP+LNP cell was available
})

test_that("bad input is refused rather than half-processed", {
  expect_error(build_flow_matrix(data.frame(seat = "A")), "missing column")
  z <- fake_transfers(); z$votes <- 0
  expect_error(build_flow_matrix(z), "No positive transfers")
})
