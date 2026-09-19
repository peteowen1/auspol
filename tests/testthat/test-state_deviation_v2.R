# v2 state-deviation arm: decayed prior-state-election term and the
# two-predictor ridge fit, on synthetic tables (no anchor data needed).

test_that(".sd_elec_term decays with the gap and is zero when absent", {
  expect_equal(auspol:::.sd_elec_term(10, 0), 10)
  expect_equal(auspol:::.sd_elec_term(10, 24), 10 * exp(-1))
  expect_equal(auspol:::.sd_elec_term(10, 999), 0)      # the builder's "no reading" sentinel
  expect_equal(auspol:::.sd_elec_term(NA, 3), 0)
  expect_equal(auspol:::.sd_elec_term(c(4, -4), c(12, 12)), c(4, -4) * exp(-0.5))
})

test_that("state_deviation_b2 recovers a planted two-predictor relation and excludes the target pair", {
  td <- withr::local_tempdir()
  set.seed(7)
  pairs <- paste0("fed", c(2007, 2010, 2013, 2016, 2019, 2022))
  states <- c("nsw", "vic", "qld", "sa", "wa")
  dev <- data.table::rbindlist(lapply(pairs, function(pr) data.table::rbindlist(lapply(states, function(st) {
    x1 <- round(stats::rnorm(1, 0, 3), 2); x2 <- round(stats::rnorm(1, 0, 8), 2); gap <- sample(c(3, 12, 20), 1)
    data.table::data.table(pair = pr, seat = paste(st, 1:4), state = st,
                           state_poll_dev = x1, state_poll_n = 5L, state_elec_dev = x2, state_elec_gap = gap)
  }))))
  # planted: err = 0.5 * poll_dev + 0.25 * decayed elec_dev, plus seat noise
  dev[, .x2 := auspol:::.sd_elec_term(state_elec_dev, state_elec_gap)]
  oof <- dev[, .(pair, seat, party = "ALP", xgb_pred = 30,
                 actual_share = 30 + 0.5 * state_poll_dev + 0.25 * .x2 + stats::rnorm(.N, 0, 0.3))]
  # the target pair carries an absurd residual: if it leaked into the fit the coefficients would blow up
  oof[pair == "fed2022", actual_share := actual_share + 200]
  f_oof <- file.path(td, "oof.csv"); f_dev <- file.path(td, "dev.csv")
  data.table::fwrite(oof, f_oof); data.table::fwrite(dev[, !".x2"], f_dev)
  b <- state_deviation_b2("ALP", "fed2022", oof = f_oof, dev = f_dev)
  expect_true(all(is.finite(b[c("b_poll", "b_elec")])))
  expect_equal(unname(b[["b_poll"]]), 0.5, tolerance = 0.15)
  expect_equal(unname(b[["b_elec"]]), 0.25, tolerance = 0.15)
  expect_equal(unname(b[["n"]]), 25)     # 5 training pairs x 5 states
  # too little to fit -> NAs, not an error
  b0 <- state_deviation_b2("GRN", "fed2022", oof = f_oof, dev = f_dev)
  expect_true(all(is.na(b0[c("b_poll", "b_elec")])))
})

test_that("state_deviation_apply mode 2 leaves a seat with neither source untouched and preserves row totals", {
  td <- withr::local_tempdir()
  dev <- data.table::data.table(
    pair = "fed2022", seat = c("A", "B", "C"), state = c("wa", "wa", "tas"),
    state_poll_dev = c(3, 3, 0), state_poll_n = c(6L, 6L, 0L),
    state_elec_dev = c(10, 10, 0), state_elec_gap = c(12, 12, 999))
  # training rows for other pairs
  tr <- data.table::rbindlist(lapply(paste0("fed", c(2010, 2013, 2016, 2019)), function(pr)
    data.table::data.table(pair = pr, seat = paste0(pr, c("A", "B")), state = c("wa", "sa"),
                           state_poll_dev = c(2, -1), state_poll_n = 6L, state_elec_dev = c(6, -3) * (1 + as.integer(sub("fed", "", pr)) %% 4), state_elec_gap = 6)))
  dev <- rbind(dev, tr)
  oof <- tr[, .(pair, seat, party = "ALP", xgb_pred = 30,
                actual_share = 30 + 0.4 * state_poll_dev + 0.2 * state_elec_dev * exp(-state_elec_gap / 24))]
  f_oof <- file.path(td, "oof.csv"); f_dev <- file.path(td, "dev.csv")
  data.table::fwrite(oof, f_oof); data.table::fwrite(dev, f_dev)
  sh <- matrix(c(30, 30, 30, 40, 40, 40, 30, 30, 30), 3, dimnames = list(c("A", "B", "C"), c("ALP", "LNP", "GRN")))
  out <- withr::with_dir(td, {
    # state_deviation_b2 is called with dev = f_dev but oof at its default path: put it there
    dir.create("output"); file.copy(f_oof, "output/xgb-primary-v6-oof-predictions.csv")
    state_deviation_apply(sh, "fed2022", classes = "ALP", dev = f_dev, mode = 2)
  })
  expect_equal(unname(out["C", ]), unname(sh["C", ]))          # tas: no poll, no fresh election
  expect_gt(out["A", "ALP"], sh["A", "ALP"])                   # wa: both terms positive
  expect_equal(rowSums(out), rowSums(sh))
})
