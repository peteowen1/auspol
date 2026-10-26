# Audit F12 (reviews/audit-f8-f19-status-2026-10-25.md; plans/prereg-live-level-pred-2026-10-25.md): the live
# trees are served a level_pred built after the recent-poll blend, while build_level_pred.R trains them on one
# without it. AUSPOL_LIVE_LEVEL_PRED_TREND serves the pre-blend level live; AUSPOL_LEVEL_PRED_RECENT blends the
# training level, time-forward. No anchor data needed: the poll table is injected into the blend's memo.

blended <- c(ALP = 24.6, LNP = 28.9, GRN = 14.3, ONP = 21.86, OTH = 10.34)
trend   <- c(ALP = 25.2, LNP = 29.3, GRN = 14.2, ONP = 21.25, OTH = 10.05)   # same total (100.00)

test_that("on is the default (shipped 2026-10-26)", {
  withr::local_envvar(AUSPOL_LIVE_LEVEL_PRED_TREND = NA)
  expect_true(live_level_pred_trend())
})

test_that("off serves the blended level untouched, and says so", {
  withr::local_envvar(AUSPOL_LIVE_LEVEL_PRED_TREND = "0")
  expect_false(live_level_pred_trend())
  out <- NULL
  txt <- capture.output(out <- live_level_pred_serve(blended, trend))
  expect_identical(out, blended)
  expect_match(txt, "^LLP1  xgb level_pred served from the BLENDED level")
  expect_match(txt, "ALP -0.60", fixed = TRUE)
})

test_that("on serves the pre-blend level, in the blended class order", {
  out <- NULL
  txt <- capture.output(out <- live_level_pred_serve(blended, rev(trend), enabled = TRUE))
  expect_identical(names(out), names(blended))
  expect_equal(unname(out), unname(trend))
  expect_match(txt, "PRE-BLEND trend level, the training recipe")
  expect_match(txt, "LNP -0.40", fixed = TRUE)
})

test_that("on refuses a pre-blend level that does not belong to the same pipeline point (deliberately broken inputs)", {
  q <- function(...) capture.output(invisible(live_level_pred_serve(...)))
  expect_error(q(blended, trend[-5], enabled = TRUE), "LLP1! .*classes")             # a class lost
  bad <- trend; bad[["ONP"]] <- NA
  expect_error(q(blended, bad, enabled = TRUE), "LLP1! .*non-finite")
  off <- trend; off[["OTH"]] <- off[["OTH"]] + 2                                      # captured before the rescale
  expect_error(q(blended, off, enabled = TRUE), "LLP1! .*not the same pipeline point")
  expect_error(q(blended, unname(trend), enabled = TRUE), "LLP1! .*class names")
  # off: the same broken inputs never stop the published run; the gap is reported as not comparable
  expect_match(q(blended, trend[-5], enabled = FALSE), "not comparable")
  expect_identical(suppressWarnings({ capture.output(o <- live_level_pred_serve(blended, off, enabled = FALSE)); o }), blended)
})

test_that("both switches take only \"0\" or \"1\"", {
  withr::local_envvar(AUSPOL_LIVE_LEVEL_PRED_TREND = "yes", AUSPOL_LEVEL_PRED_RECENT = "true")
  expect_error(live_level_pred_trend(), "must be")
  expect_error(level_pred_recent(), "must be")
  withr::local_envvar(AUSPOL_LIVE_LEVEL_PRED_TREND = "1", AUSPOL_LEVEL_PRED_RECENT = "1")
  expect_true(live_level_pred_trend()); expect_true(level_pred_recent())
  withr::local_envvar(AUSPOL_LEVEL_PRED_RECENT = NA)
  expect_false(level_pred_recent())
})

# ---- the training blend is time-forward ----------------------------------------------------------------
# Synthetic Victorian polls: before each of vic2014/vic2018/vic2022, a steady ALP 35 / LNP 35 / GRN 10, while
# the trend said 30 / 40 / 10 and the result was 35 / 35 / 10, so the fitted blend leans on the polls.
fake_polls <- function(extra = NULL) {
  days <- function(d) as.Date(d) - c(3, 10, 20, 35, 50)
  p <- data.table::data.table(date = c(days("2014-11-29"), days("2018-11-24"), days("2022-11-26")),
                              ALP = 35, LNP = 35, GRN = 10)
  if (!is.null(extra)) p <- rbind(p, extra)
  p
}
fake_tab <- data.table::data.table(
  election = rep(c("vic2014", "vic2018"), each = 3), region = "vic", cls = rep(c("ALP", "LNP", "GRN"), 2),
  trend = rep(c(30, 40, 10), 2), actual = rep(c(35, 35, 10), 2))
lv22 <- c(ALP = 30, LNP = 40, GRN = 10, ONP = 5, OTH = 15)

with_polls <- function(polls, code, tab = fake_tab) {
  memo <- auspol:::.lr_poll_memo
  had <- !is.null(memo[["vic"]]); old <- memo[["vic"]]
  on.exit(if (had) assign("vic", old, envir = memo) else if (exists("vic", envir = memo, inherits = FALSE)) rm("vic", envir = memo))
  assign("vic", polls, envir = memo)
  withr::local_envvar(AUSPOL_LEVEL_RECENT = "decay", AUSPOL_LEVEL_RECENT_HALFLIFE = "20", AUSPOL_LEVEL_FED_R = "0",
                      AUSPOL_TIME_FORWARD_FITS = NA)
  out <- NULL
  capture.output(out <- level_pred_recent_apply(lv22, "vic2022", "vic", "2022-11-26", code = code, tab = tab))
  out
}

test_that("the training blend moves level_pred toward the pre-election polls and keeps the total", {
  out <- with_polls(fake_polls(), "LPR1")
  expect_gt(out[["ALP"]], 33); expect_lt(out[["LNP"]], 37)
  expect_equal(sum(out), sum(lv22))
  expect_gt(attr(out, "moved"), 5)
  expect_identical(names(out), names(lv22))
})

test_that("a poll fielded on or after polling day cannot reach the training level (and the check can fail)", {
  base <- with_polls(fake_polls(), "LPR1")
  absurd <- function(d) data.table::data.table(date = as.Date(d), ALP = 90, LNP = 2, GRN = 1)
  after <- with_polls(fake_polls(rbind(absurd("2022-11-26"), absurd("2022-12-10"))), "LPR1")
  expect_identical(unclass(after), unclass(base))
  # control: the same poll one day BEFORE polling day does move it, so the identity above is not vacuous
  before <- with_polls(fake_polls(absurd("2022-11-25")), "LPR1")
  expect_gt(before[["ALP"]] - base[["ALP"]], 1)
})

test_that("the blend constant ignores the target's own result in the table", {
  base <- with_polls(fake_polls(), "LPR1")
  leaky <- rbind(fake_tab, data.table::data.table(election = "vic2022", region = "vic", cls = c("ALP", "LNP", "GRN"),
                                                  trend = c(30, 40, 10), actual = c(10, 70, 1)))
  expect_identical(unclass(with_polls(fake_polls(), "LPR1", tab = leaky)), unclass(base))
  # control: the same absurd result on an EARLIER election does move the fit
  moved <- data.table::copy(fake_tab); moved$actual[moved$election == "vic2018"] <- c(10, 70, 1)
  expect_false(identical(unclass(with_polls(fake_polls(), "LPR1", tab = moved)), unclass(base)))
})

test_that("AUSPOL_LEVEL_RECENT=0 leaves the training level alone, as live does", {
  withr::local_envvar(AUSPOL_LEVEL_RECENT = "0")
  out <- level_pred_recent_apply(lv22, "vic2022", "vic", "2022-11-26", tab = fake_tab)
  expect_equal(as.numeric(out), unname(lv22)); expect_equal(attr(out, "moved"), 0)
  expect_error(level_pred_recent_apply(lv22, "vic2022", "vic", NA, tab = fake_tab), "LPR1! .*polling day")
})
