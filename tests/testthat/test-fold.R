# Parties folded into "Others": some pollsters do not name One Nation, so its
# votes land in the residual line and inflate it.

make_folded <- function(seed = 5, n = 120, T_days = 400,
                        levels = c(ALP = 35, LNP = 32, GRN = 10, ONP = 12, OTH = 11),
                        fold_firm = "B", noise = 0.8) {
  set.seed(seed)
  dates <- as.Date("2025-01-01") + sort(sample(0:T_days, n, replace = TRUE))
  firm <- rep(c("A", "B"), length.out = n)
  d <- data.table::data.table(date = dates, firm = firm, tpp_published = NA_real_)
  for (p in names(levels)) d[[p]] <- levels[[p]] + rnorm(n, 0, noise)
  # Real published polls are rescaled so first preferences sum to 100; the
  # arithmetic test in folded_rows() relies on that, so the fixture must do it
  # too or it is testing a data shape that does not occur.
  tot <- rowSums(as.matrix(d[, names(levels), with = FALSE]))
  for (p in names(levels)) d[[p]] <- d[[p]] * 100 / tot
  # The folding firm reports no ONP; those votes sit inside OTH instead, so
  # its reported first preferences still sum to ~100.
  hide <- d$firm == fold_firm
  d$OTH[hide] <- d$OTH[hide] + d$ONP[hide]
  d$ONP[hide] <- NA_real_

  data.table::setattr(d, "parties", names(levels))
  data.table::setattr(d, "region", "test")
  data.table::setattr(d, "cycle_year", 2026)
  data.table::setattr(d, "cycle_start", as.Date("2025-01-01"))
  data.table::setattr(d, "cycle_end", as.Date("2025-01-01") + T_days)
  d
}

test_that("folded_rows finds absorbed parties and ignores genuinely missing ones", {
  d <- make_folded()
  hit <- folded_rows(d, "ONP")
  expect_true(all(d$firm[hit] == "B"))
  expect_equal(sum(hit), sum(d$firm == "B"))

  # A poll that simply omits ONP without absorbing it sums to ~88, not ~100,
  # and must NOT be corrected.
  d2 <- data.table::copy(d)
  data.table::setattr(d2, "parties", attr(d, "parties"))
  miss <- which(d2$firm == "B")[1:5]
  d2$OTH[miss] <- d2$OTH[miss] - 12          # take the folded votes back out
  expect_false(any(folded_rows(d2, "ONP")[miss]))
})

test_that("unfold_others restores the residual line to its true level", {
  d <- make_folded()
  truth <- 11

  # Inflated before correction
  gap_before <- mean(d$OTH[d$firm == "B"]) - mean(d$OTH[d$firm == "A"])
  expect_gt(gap_before, 10)

  fits <- fit_cycle_trends(d, parties = c("ALP", "LNP", "GRN", "ONP", "OTH"),
                           priors = c(ALP = 35, LNP = 32, GRN = 10,
                                      ONP = 12, OTH = 11))
  corrected <- unfold_others(d, fits)
  gap_after <- mean(corrected$OTH[corrected$firm == "B"]) -
    mean(corrected$OTH[corrected$firm == "A"])

  expect_lt(abs(gap_after), 1.0)
  expect_lt(abs(mean(corrected$OTH[corrected$firm == "B"]) - truth), 1.0)
  # Polls that already reported ONP are untouched
  expect_equal(corrected$OTH[corrected$firm == "A"], d$OTH[d$firm == "A"])
})

test_that("unfold_others logs what it changed and leaves other columns alone", {
  d <- make_folded()
  fits <- fit_cycle_trends(d, parties = c("ALP", "LNP", "GRN", "ONP", "OTH"),
                           priors = c(ALP = 35, LNP = 32, GRN = 10,
                                      ONP = 12, OTH = 11))
  corrected <- unfold_others(d, fits)
  log <- attr(corrected, "folded")

  expect_s3_class(log, "data.table")
  expect_true(all(log$party == "ONP"))
  expect_equal(nrow(log), sum(d$firm == "B"))
  expect_equal(log$oth_after, log$oth_before - log$imputed)
  # ONP itself is NOT fabricated back in — the imputation carries no new
  # information about ONP and feeding it back would be circular.
  expect_true(all(is.na(corrected$ONP[corrected$firm == "B"])))
  expect_equal(corrected$ALP, d$ALP)
})

test_that("fit_cycle_unfolded converges and reports its iterations", {
  d <- make_folded()
  fits <- suppressMessages(fit_cycle_unfolded(
    d, parties = c("ALP", "LNP", "GRN", "ONP", "OTH"),
    priors = c(ALP = 35, LNP = 32, GRN = 10, ONP = 12, OTH = 11),
    verbose = FALSE))

  expect_lt(attr(fits, "iterations"), 10L)
  corrected <- attr(fits, "polls_corrected")
  gap <- mean(corrected$OTH[corrected$firm == "B"]) -
    mean(corrected$OTH[corrected$firm == "A"])
  expect_lt(abs(gap), 1.0)
  # The OTH trend should now sit near the truth rather than well above it
  oth_end <- fits$OTH$trend$mean[which.max(fits$OTH$trend$date)]
  expect_lt(abs(oth_end - 11), 1.5)
})

test_that("both folded parties are removed when a poll hides two", {
  # Regression: detection is arithmetic, so subtracting the first party drops
  # the row's total below the "sums to ~100" window and used to hide the
  # second. Federally the common case is a poll omitting both ONP and UAP.
  d <- make_folded(seed = 9,
                   levels = c(ALP = 34, LNP = 31, GRN = 10, ONP = 12,
                              UAP = 5, OTH = 8))
  hide <- d$firm == "B"
  d$OTH[hide] <- d$OTH[hide] + d$UAP[hide]     # UAP folded away as well
  d$UAP[hide] <- NA_real_

  pri <- c(ALP = 34, LNP = 31, GRN = 10, ONP = 12, UAP = 5, OTH = 8)
  fits <- fit_cycle_trends(d, parties = names(pri), priors = pri)
  corrected <- unfold_others(d, fits)

  log <- attr(corrected, "folded")
  expect_setequal(unique(log$party), c("ONP", "UAP"))
  gap <- mean(corrected$OTH[hide]) - mean(corrected$OTH[!hide])
  expect_lt(abs(gap), 1.5)
})

test_that("polls outside the party's observed window are left alone", {
  # The NSW 2027 case: the folding polls sit in a period where the party was
  # never measured, so the trend there is prior-driven interpolation and
  # subtracting it would invent vote share.
  d <- make_folded(seed = 15, n = 120, T_days = 600)
  # Firm A only starts naming ONP late in the cycle
  early_a <- d$firm == "A" & d$date < as.Date("2025-01-01") + 400
  d$OTH[early_a] <- d$OTH[early_a] + d$ONP[early_a]
  d$ONP[early_a] <- NA_real_

  pri <- c(ALP = 35, LNP = 32, GRN = 10, ONP = 12, OTH = 11)
  fits <- fit_cycle_trends(d, parties = names(pri), priors = pri)
  corrected <- unfold_others(d, fits)

  skipped <- attr(corrected, "fold_skipped")
  expect_gt(nrow(skipped), 0)
  expect_true(all(skipped$date < min(fits$ONP$residuals$date)))
  # Skipped rows keep their original OTH exactly
  m <- match(paste(skipped$date, skipped$firm), paste(d$date, d$firm))
  expect_equal(corrected$OTH[m], d$OTH[m])
})

test_that("correcting is a no-op when every poll reports every party", {
  d <- make_folded(fold_firm = "none")
  expect_false(any(folded_rows(d, "ONP")))
  fits <- fit_cycle_trends(d, parties = c("ALP", "LNP", "GRN", "ONP", "OTH"),
                           priors = c(ALP = 35, LNP = 32, GRN = 10,
                                      ONP = 12, OTH = 11))
  corrected <- unfold_others(d, fits)
  expect_equal(corrected$OTH, d$OTH)
  expect_equal(nrow(attr(corrected, "folded")), 0L)
})

test_that("poll_data_age reports the newest poll and its age", {
  skip_if_no_anchor()
  a <- poll_data_age("vic", as_of = as.Date("2026-08-15"))
  expect_equal(a$region, "vic")
  expect_s3_class(a$latest, "Date")
  expect_gte(a$age_days, 0)
  expect_equal(a$age_days, as.integer(as.Date("2026-08-15") - a$latest))
  expect_gt(a$n_recent, 0)
})

test_that("check_poll_freshness stops on stale data and passes on fresh", {
  skip_if_no_anchor()
  # Measured far in the future, every region is stale
  expect_error(
    suppressMessages(check_poll_freshness("vic", as_of = as.Date("2027-06-01"))),
    "stale")
  # strict = FALSE proceeds, but the data is STILL reported as stale:
  # "proceed anyway" and "it is not stale" are different claims.
  expect_warning(
    info <- suppressMessages(check_poll_freshness(
      "vic", as_of = as.Date("2027-06-01"), strict = FALSE)))
  expect_equal(info$status, "STALE")

  # Measured at the last poll's own date, it is fresh
  latest <- poll_data_age("vic")$latest
  ok <- suppressMessages(check_poll_freshness("vic", as_of = latest))
  expect_equal(ok$status, "ok")
  expect_equal(ok$age_days, 0L)
})

test_that("a region whose dates all fail to parse is BROKEN, not silently ok", {
  # which() DROPS NA rather than matching it, so an NA status vanished from the
  # stale gate — meaning the one region whose data was corrupt was the one
  # region not checked. And `if (any(c(NA, FALSE)))` errors outright, replacing
  # the informative message with a cryptic one.
  skip_if_no_anchor()
  fake <- suppressMessages(load_polls("vic"))
  expect_true(all(c("region", "status") %in%
    names(suppressMessages(suppressWarnings(
      check_poll_freshness("vic", strict = FALSE, as_of = as.Date("2027-06-01")))))))
  # status must never be NA, whatever the input
  info <- suppressMessages(suppressWarnings(
    check_poll_freshness(c("vic", "fed"), strict = FALSE,
                         as_of = as.Date("2027-06-01"))))
  expect_false(anyNA(info$status))
  expect_true(all(info$status %in% c("ok", "ageing", "STALE", "BROKEN")))
})

test_that("check_poll_freshness refuses an empty region list", {
  # An empty vector made every downstream guard vacuously clean and printed
  # nothing at all — the report would look like a clean pass.
  expect_error(check_poll_freshness(character(0)), "length")
})

test_that("an ageing region still warns without stopping the run", {
  skip_if_no_anchor()
  latest <- poll_data_age("vic")$latest
  # expect_warning() returns the condition, not the value, so capture separately
  suppressMessages(expect_warning(
    check_poll_freshness("vic", as_of = latest + 30), "ageing"))
  info <- suppressMessages(suppressWarnings(
    check_poll_freshness("vic", as_of = latest + 30)))
  expect_equal(info$status, "ageing")
  expect_equal(info$age_days, 30L)
})
