# AUSPOL_XGB_BASE_DELTA: the measurement mode that feeds this run's base share to
# the frozen as-at trees. Synthetic: a tiny as-at model is trained in a temp root.

bd_root <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  file.create(file.path(root, "DESCRIPTION"))
  withr::local_options(auspol.root = root, .local_envir = env)
  dir.create(file.path(root, "output", "xgb-primary-asat"), recursive = TRUE)
  set.seed(11)
  seats <- paste0("S", 1:6); parties <- c("ALP", "LNP", "GRN")
  D <- data.table::CJ(seat = seats, party = parties, sorted = FALSE)
  D[, pair := "tst2020"]
  D[, base_pred := c(ALP = 40, LNP = 40, GRN = 20)[party] + rnorm(.N, 0, 3)]
  D[, f1 := rnorm(.N)]
  D[, f2 := runif(.N)]
  D[, actual_share := base_pred + 2 * f1 + rnorm(.N)]
  cols <- c("base_pred", "f1", "f2")
  dtr <- xgboost::xgb.DMatrix(data = as.matrix(as.data.frame(D)[, cols]), label = D$actual_share, missing = NA)
  xgboost::setinfo(dtr, "base_margin", D$base_pred)
  m <- xgboost::xgb.train(params = list(objective = "reg:squarederror", eta = 0.3, max_depth = 3),
                          data = dtr, nrounds = 25, verbose = 0)
  xgboost::xgb.save(m, file.path(root, "output", "xgb-primary-asat", "tst2020.ubj"))
  writeLines(cols, file.path(root, "output", "xgb-primary-asat", "feat_cols.txt"))
  data.table::fwrite(D[, c("pair", "seat", "party", "actual_share", cols), with = FALSE],
                     file.path(root, "output", "xgb-primary-v6-features.csv"))
  D[, xgb_pred := pmax(0, predict(m, { d <- xgboost::xgb.DMatrix(data = as.matrix(as.data.frame(D)[, cols]), missing = NA)
                                       xgboost::setinfo(d, "base_margin", D$base_pred); d }))]
  data.table::fwrite(D[, .(pair, seat, party, base_pred, actual_share, xgb_pred)],
                     file.path(root, "output", "xgb-primary-asat-predictions.csv"))
  sh <- matrix(0, length(seats), length(parties), dimnames = list(seats, parties))
  for (i in seq_len(nrow(D))) sh[D$seat[i], D$party[i]] <- D$base_pred[i]
  list(root = root, D = D, model = m, cols = cols, shares = 100 * sh / rowSums(sh))
}

bd_run <- function(shares, delta = "0", record = "0", ref = NULL, root = NULL) {
  withr::local_envvar(AUSPOL_XGB_PRIMARY = "1", AUSPOL_XGB_BASE_DELTA = delta, AUSPOL_XGB_BASE_RECORD = record,
                      AUSPOL_XGB_BASE_DELTA_TOL = "0.05")
  out <- NULL
  lg <- utils::capture.output(out <- xgb_primary_override(shares, "tst2020")); attr(out, "log") <- lg
  out
}

test_that("switch 0 is the old behaviour: cached predictions, renormalised to 100", {
  fx <- bd_root()
  out <- bd_run(fx$shares, "0"); attr(out, "log") <- NULL
  want <- matrix(fx$D$xgb_pred, 6, 3, byrow = TRUE, dimnames = dimnames(fx$shares))
  want <- 100 * want / rowSums(want)
  expect_equal(out, want, tolerance = 1e-9)
})

test_that("baseline: reference equal to this run's shares changes nothing, whatever the base looks like", {
  fx <- bd_root()
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "1", AUSPOL_DEPARTED_SUCCESSOR = "0", AUSPOL_XGB_PRIMARY = "0", AUSPOL_REENTRY = "0", AUSPOL_NEW_IND_SHRINK = "0")
  # the harness shares are NOT the cached base (later pipeline steps move them):
  # offset them before recording, to mimic that; the delta must still be zero
  off <- fx$shares; off[, "GRN"] <- off[, "GRN"] + 3
  utils::capture.output(xgb_primary_override(off, "tst2020"))           # stage 1 records
  expect_true(file.exists(file.path(fx$root, "output", "xgb-base-ref", "tst2020.csv")))
  on <- NULL
  on <- bd_run(off, "1"); lg <- attr(on, "log"); attr(on, "log") <- NULL
  base <- bd_run(off, "0"); attr(base, "log") <- NULL
  expect_identical(on, base)
  expect_true(any(grepl("0 of 18 cells have \\|delta\\| > 0.05; 0 acted on", lg)))
})

test_that("a planted base change moves its own seat only, via the frozen trees", {
  fx <- bd_root()
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "1", AUSPOL_DEPARTED_SUCCESSOR = "0", AUSPOL_XGB_PRIMARY = "0", AUSPOL_REENTRY = "0", AUSPOL_NEW_IND_SHRINK = "0")
  utils::capture.output(xgb_primary_override(fx$shares, "tst2020"))
  sh2 <- fx$shares
  sh2["S3", "GRN"] <- sh2["S3", "GRN"] + 12          # a fix fills 12 points into S3 GRN
  sh2["S3", ] <- 100 * sh2["S3", ] / sum(sh2["S3", ])
  on <- NULL
  on <- bd_run(sh2, "1"); lg <- attr(on, "log"); attr(on, "log") <- NULL
  base <- bd_run(fx$shares, "0"); attr(base, "log") <- NULL
  other <- setdiff(rownames(sh2), "S3")
  expect_identical(on[other, ], base[other, ])        # nothing else moves
  expect_false(isTRUE(all.equal(on["S3", ], base["S3", ])))
  expect_true(any(grepl("FAITHFUL", lg)))
  # faithful value: re-predict the changed cells with the new base as margin AND feature
  chg <- which(abs(sh2["S3", ] - fx$shares["S3", ]) > 0.05)
  expect_true("GRN" %in% names(chg))
  F <- fx$D[seat == "S3"]
  M <- as.matrix(as.data.frame(F)[, fx$cols]); M[, "base_pred"] <- F$base_pred + (sh2["S3", F$party] - fx$shares["S3", F$party])
  d <- xgboost::xgb.DMatrix(data = M, missing = NA)
  xgboost::setinfo(d, "base_margin", M[, "base_pred"])
  p <- pmax(0, predict(fx$model, d))
  p <- p * sum(F$xgb_pred) / sum(p)                   # back to the seat's pre-shift total
  want <- 100 * p / sum(p)
  expect_equal(unname(on["S3", F$party]), unname(want), tolerance = 1e-4)
  expect_gt(on["S3", "GRN"], base["S3", "GRN"])
})

test_that("without the model the mode falls back to the labelled additive estimate", {
  fx <- bd_root()
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "1", AUSPOL_DEPARTED_SUCCESSOR = "0", AUSPOL_XGB_PRIMARY = "0", AUSPOL_REENTRY = "0", AUSPOL_NEW_IND_SHRINK = "0")
  utils::capture.output(xgb_primary_override(fx$shares, "tst2020"))
  file.remove(file.path(fx$root, "output", "xgb-primary-asat", "tst2020.ubj"))
  sh2 <- fx$shares; sh2["S2", "ALP"] <- sh2["S2", "ALP"] + 8
  sh2["S2", ] <- 100 * sh2["S2", ] / sum(sh2["S2", ])
  on <- NULL
  on <- bd_run(sh2, "1"); lg <- attr(on, "log"); attr(on, "log") <- NULL
  expect_true(any(grepl("ADDITIVE", lg)))
  base <- bd_run(fx$shares, "0"); attr(base, "log") <- NULL
  expect_gt(on["S2", "ALP"], base["S2", "ALP"])
  expect_identical(on[setdiff(rownames(sh2), "S2"), ], base[setdiff(rownames(sh2), "S2"), ])
})

test_that("a missing reference file stops the run instead of comparing with the cached base", {
  fx <- bd_root()
  expect_error(bd_run(fx$shares, "1"), "is missing")
})

test_that("recording a reference with the new-independent shrink switched on is refused", {
  fx <- bd_root()
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "1", AUSPOL_DEPARTED_SUCCESSOR = "0", AUSPOL_XGB_PRIMARY = "0", AUSPOL_REENTRY = "0",
                      AUSPOL_NEW_IND_SHRINK = "1")
  expect_error(utils::capture.output(xgb_primary_override(fx$shares, "tst2020")), "AUSPOL_NEW_IND_SHRINK=0")
  expect_false(file.exists(file.path(fx$root, "output", "xgb-base-ref", "tst2020.csv")))
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "0")
  lg <- utils::capture.output(xgb_primary_override(fx$shares, "tst2020"))
  expect_true(any(grepl("XG9!!.*AUSPOL_NEW_IND_SHRINK=1", lg)))
  # all post-xgb switches off: recording works
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "1", AUSPOL_DEPARTED_SUCCESSOR = "0", AUSPOL_NEW_IND_SHRINK = "0")
  utils::capture.output(xgb_primary_override(fx$shares, "tst2020"))
  expect_true(file.exists(file.path(fx$root, "output", "xgb-base-ref", "tst2020.csv")))
})

test_that("recording a reference with the re-entry fill switched on is refused", {
  fx <- bd_root()
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "1", AUSPOL_DEPARTED_SUCCESSOR = "0", AUSPOL_XGB_PRIMARY = "0", AUSPOL_REENTRY = "majors")
  expect_error(utils::capture.output(xgb_primary_override(fx$shares, "tst2020")), "AUSPOL_REENTRY=0")
  expect_false(file.exists(file.path(fx$root, "output", "xgb-base-ref", "tst2020.csv")))
  # without recording it still runs, and says the base carries the fill
  withr::local_envvar(AUSPOL_XGB_BASE_RECORD = "0")
  lg <- utils::capture.output(xgb_primary_override(fx$shares, "tst2020"))
  expect_true(any(grepl("XG9!!", lg)))
})
