# AUSPOL_DEPARTED_RATE: time-forward partial-pooling refit of screened_slopes()'s
# departed_rate. docs/plans/prereg-departed-rate-refit-2026-10-03.md (sections 3, 8, 9).
# Synthetic only: no output/ file, no harness, no model run.

# Six seats, one IND candidate per seat per election, a DIFFERENT person every election
# (so the prior leader never returns: every IND cell is a departed-branch row when the
# screen does not permit). IND share = level + a_k * spread, so the slope of election k on
# election k-1 is a_k / a_{k-1} = the b_k chosen here, up to the small noise term.
.dr_years <- seq(2000, 2024, 4)
.dr_seats <- paste0("S", 1:6)
.dr_corpus <- function(flip_from = Inf, noise = TRUE) {
  b <- c(0.50, 0.30, 0.40, 0.35, 0.45, 0.25)       # slope of election k on election k-1
  spread <- c(-3, -2, -1, 1, 2, 3)
  a <- 10
  out <- list()
  for (k in seq_along(.dr_years)) {
    if (k > 1) a <- a * b[k - 1]
    ak <- if (.dr_years[k] >= flip_from) -3 * a else a     # a later election made to look wildly different
    eps <- if (noise) 0.15 * c(1, -1, 1, -1, 1, -1) * (1 + (k %% 3)) else 0   # noise = FALSE: exact fits
    pcv <- 8 + k + ak * spread + eps
    out[[k]] <- data.table::data.table(
      election = paste0("tst", .dr_years[k]), seat = .dr_seats, party = "IND",
      # letters only: the name matcher drops digits, so "Ind1y2004" and "Ind1y2008" would be one person
      surname = paste0("Pers", letters[seq_along(.dr_seats)], letters[k]), given = "Al", name = NA_character_,
      pcv = pcv, votes = pcv * 10, tot = 1000, elected = FALSE)
  }
  data.table::rbindlist(out)
}
.dr_pairs <- function() lapply(seq_along(.dr_years)[-1], function(k)
  list(election = paste0("tst", .dr_years[k]), prev = paste0("tst", .dr_years[k - 1])))
# Screen that permits nobody: every departed cell is in the departed branch.
.dr_nopermit <- function(el, prev, region) data.table::data.table(seat = .dr_seats, party = "IND", permit = FALSE)
.dr_fit <- function(target, corpus = .dr_corpus(), permit_fn = .dr_nopermit, ...) {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1", .local_envir = parent.frame())
  suppressMessages(fit_departed_rate(target, corpus = corpus, pairs = .dr_pairs(), permit_fn = permit_fn, ...))
}

test_that("(a) switch off is byte-identical to the old default", {
  seats <- c("s1", "s2", "s3")
  returns <- data.table::data.table(seat = seats, party = "IND", same = FALSE, same_mp = FALSE,
                                    prior_leader_returns = c(FALSE, TRUE, FALSE))
  permit <- c(FALSE, FALSE, TRUE)
  old <- screened_slopes("IND", seats, returns, permit = permit, honour_departed = TRUE)
  expect_equal(old[1], 0.38)                       # the hardcoded constant, stated, not inferred
  # what every harness passes when the switch is off
  withr::local_envvar(AUSPOL_DEPARTED_RATE = "0")
  rate <- departed_rate_for_harness("tst2020", active = TRUE)
  expect_null(rate)
  passed <- if (is.null(rate)) eval(formals(screened_slopes)$departed_rate) else rate   # formals() gives the unevaluated call
  expect_identical(passed, c(IND = 0.38))
  expect_identical(screened_slopes("IND", seats, returns, permit = permit, honour_departed = TRUE,
                                   departed_rate = passed), old)
  # and the argument is live: a different rate moves exactly the departed, unpermitted cell
  moved <- screened_slopes("IND", seats, returns, permit = permit, honour_departed = TRUE,
                           departed_rate = c(IND = 0.2))
  expect_equal(moved[1], 0.2)
  expect_identical(moved[-1], old[-1])
  # the off line says it was off (a run that prints nothing cannot be told from "no effect")
  expect_output(departed_rate_for_harness("tst2020", mode = "0"), "DR0 tst2020 IND rate 0.38 \\[arm 0")
  # not active (honour_departed off, no screen): nothing fitted, and it says so
  expect_output(r2 <- departed_rate_for_harness("tst2020", mode = "fit", active = FALSE), "not active")
  expect_null(r2)
})

test_that("(b) the fit uses only earlier elections: later data changes nothing", {
  f <- .dr_fit("tst2016")
  expect_false(f$fallback_used)
  expect_equal(sort(f$elections), c("tst2004", "tst2008", "tst2012"))
  expect_true(all(elections_before(f$elections, "tst2016")))
  # make the target's own pair and every later election wildly different
  g <- .dr_fit("tst2016", corpus = .dr_corpus(flip_from = 2016))
  expect_identical(g$rate, f$rate)
  expect_identical(g$per_election$b, f$per_election$b)
  # ...but an EARLIER election does matter (the fit is not simply constant)
  h <- .dr_fit("tst2016", corpus = .dr_corpus(flip_from = 2008))
  expect_false(isTRUE(all.equal(h$rate, f$rate)))
  # the leave-one-out setting would read later elections, so it refuses rather than leak
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "0")
  expect_error(fit_departed_rate("tst2016", corpus = .dr_corpus(), pairs = .dr_pairs(), permit_fn = .dr_nopermit),
               "time-forward only")
})

test_that("(c) partial pooling shrinks a thin election toward the pool, with no cliff", {
  p <- dl_pool(b = c(0.30, 0.40, 0.90), se2 = c(0.001, 0.002, 1))
  fac <- (p$b_shrunk - p$mu) / (c(0.30, 0.40, 0.90) - p$mu)
  expect_equal(unname(fac), p$tau2 / (p$tau2 + c(0.001, 0.002, 1)))   # the registered formula
  expect_true(all(fac > 0 & fac < 1))
  expect_true(fac[1] > fac[2] && fac[2] > fac[3])                    # graceful: more noise, more shrinkage
  expect_lt(abs(p$b_shrunk[3] - p$mu), 0.02 * abs(0.90 - p$mu))      # the thin one is almost entirely the pool
  expect_gt(abs(p$b_shrunk[1] - p$mu), 0.3 * abs(0.30 - p$mu))       # the precise one mostly keeps its own
  # tau2 is floored, so the weights are never exactly equal by construction
  eq <- dl_pool(b = c(0.4, 0.4, 0.4), se2 = c(0.01, 0.01, 0.01))
  expect_equal(eq$tau2, 0.01^2)
  # through the whole fit: one election with a single departed-branch row (everything else
  # permitted) and an extreme slope barely moves the pooled value and is shrunk to ~mu
  thin_permit <- function(el, prev, region)
    if (identical(el, "tst2008")) data.table::data.table(seat = .dr_seats, party = "IND", permit = c(rep(TRUE, 5), FALSE))   # S6 only: its prior share is positive
    else .dr_nopermit(el, prev, region)
  cp <- .dr_corpus()
  f <- .dr_fit("tst2020", corpus = cp, permit_fn = thin_permit)
  expect_false(f$fallback_used)
  thin <- f$per_election[f$per_election$election == "tst2008", ]
  expect_equal(thin$n, 1L)
  expect_lt(abs(thin$b_shrunk - f$mu), 0.001 + 0.01 * abs(thin$b - f$mu))
  # the rate that is returned is the pooled mean, clipped to [0, 1]
  expect_equal(unname(f$rate), max(0, min(1, f$mu)))
  # all the earlier elections of that target were used, and none of its own or later ones
  expect_equal(sort(f$elections), c("tst2004", "tst2008", "tst2012", "tst2016"))
})

test_that("(d) fewer than 3 earlier elections falls back, and says which fallback fired", {
  # the fallback is the CONTROL value (0.38), not fit_conditional_slopes()$new (addendum 2026-10-04 item 3)
  f2 <- .dr_fit("tst2012")                           # earlier: tst2004, tst2008 only
  expect_true(f2$fallback_used)
  expect_equal(unname(f2$rate), 0.38)
  expect_match(f2$fallback_reason, "fallback to control \\(n informative elections = 2\\)")
  f0 <- .dr_fit("tst2004")                           # none
  expect_true(f0$fallback_used); expect_equal(f0$G, 0L); expect_equal(unname(f0$rate), 0.38)
  f3 <- .dr_fit("tst2016")                           # exactly 3 informative: the fit, not the fallback
  expect_false(f3$fallback_used)
  expect_false(isTRUE(all.equal(unname(f3$rate), 0.38)))
  # the harness line names the fallback and the value used, and the screen/pair counts
  withr::local_envvar(AUSPOL_DEPARTED_RATE = "fit", AUSPOL_TIME_FORWARD_FITS = "1")
  expect_output(
    r <- departed_rate_for_harness("tst2012", corpus = .dr_corpus(), pairs = .dr_pairs(),
                                   permit_fn = .dr_nopermit),
    "IND rate 0.3800.*screened 2 of 2 earlier pairs.*fallback to control \\(n informative elections = 2\\).*elections used: tst2004,tst2008")
  expect_equal(unname(r), 0.38)
  # an unimplemented registered arm fails loudly and keeps the default
  expect_output(r3 <- departed_rate_for_harness("tst2016", mode = "fit_juris"), "BF0d!.*not implemented")
  expect_null(r3)
})

# ---- addendum 2026-10-04 (plans/prereg-departed-rate-refit-2026-10-03.md), after code review ----

# Everything permitted except S6, whose prior share is positive: ONE departed row per election.
.dr_onerow <- function(el, prev, region)
  data.table::data.table(seat = .dr_seats, party = "IND", permit = c(rep(TRUE, 5), FALSE))

test_that("(e) three earlier elections with ONE departed row each fall back to control, not a pooled rate", {
  f <- .dr_fit("tst2016", permit_fn = .dr_onerow)
  expect_equal(f$G, 3L); expect_equal(f$G_informative, 0L); expect_true(all(f$per_election$n == 1L))
  expect_true(f$fallback_used)
  expect_equal(unname(f$rate), 0.38)
  expect_match(f$fallback_reason, "fallback to control \\(n informative elections = 0\\)")
  withr::local_envvar(AUSPOL_DEPARTED_RATE = "fit", AUSPOL_TIME_FORWARD_FITS = "1")
  expect_output(
    r <- departed_rate_for_harness("tst2016", corpus = .dr_corpus(), pairs = .dr_pairs(), permit_fn = .dr_onerow),
    "IND rate 0.3800.*3 elections of which 0 informative.*fallback to control \\(n informative elections = 0\\)")
  expect_equal(unname(r), 0.38)
  # a one-row election may still enter the pool once the floor is met by others
  g <- .dr_fit("tst2020", permit_fn = function(el, prev, region)
    if (identical(el, "tst2008")) .dr_onerow(el, prev, region) else .dr_nopermit(el, prev, region))
  expect_false(g$fallback_used); expect_equal(g$G, 4L); expect_equal(g$G_informative, 3L)
})

test_that("(f) an exact-fit election (zero residual variance) gives a finite rate, not infinite weight", {
  cx <- .dr_corpus(noise = FALSE)
  f <- .dr_fit("tst2020", corpus = cx)
  expect_false(f$fallback_used)
  expect_true(all(f$per_election$se2 >= 1e-6))
  expect_equal(f$per_election$se2, rep(1e-6, nrow(f$per_election)))     # every election is an exact fit: all at the floor
  expect_true(is.finite(f$rate[["IND"]]) && is.finite(f$mu) && is.finite(f$tau2))
  expect_true(all(is.finite(f$per_election$b_shrunk)))
  expect_true(f$rate[["IND"]] >= 0 && f$rate[["IND"]] <= 1)
  expect_error(dl_pool(c(0.3, 0.4, 0.5), c(0, 0.1, 0.1)), "positive variances")   # a zero variance can never reach the pool
})

test_that("(g) a non-finite pooled value stops; the harness never passes one on", {
  bad_pool <- function(b, se2) list(mu = NaN, tau2 = 1, b_shrunk = b)
  expect_error(suppressMessages(fit_departed_rate("tst2020", corpus = .dr_corpus(), pairs = .dr_pairs(),
                                                  permit_fn = .dr_nopermit, pool_fn = bad_pool)),
               "pooled rate is not finite")
  withr::local_envvar(AUSPOL_DEPARTED_RATE = "fit", AUSPOL_TIME_FORWARD_FITS = "1")
  expect_output(r <- departed_rate_for_harness("tst2004", corpus = .dr_corpus(), pairs = .dr_pairs(),
                                               permit_fn = .dr_nopermit, fallback = NaN),
                "BF0d!.*not finite")
  expect_null(r)                                   # default rate kept: screened_slopes() never sees a NaN
  # clamping happens only after the finite check: a finite out-of-range pool is clipped
  hi <- suppressMessages(fit_departed_rate("tst2020", corpus = .dr_corpus(), pairs = .dr_pairs(), permit_fn = .dr_nopermit,
                                           pool_fn = function(b, se2) list(mu = 1.7, tau2 = 1, b_shrunk = b)))
  expect_equal(unname(hi$rate), 1)
})

test_that("(h) an error that drops a pair from the fit is logged, not swallowed", {
  boom <- function(el, prev, region) if (identical(el, "tst2008")) stop("screen exploded") else .dr_nopermit(el, prev, region)
  expect_message(f <- fit_departed_rate("tst2020", corpus = .dr_corpus(), pairs = .dr_pairs(), permit_fn = boom),
                 "DR1! pair tst2004 -> tst2008 DROPPED.*screen exploded")
  expect_equal(f$n_dropped, 1L); expect_equal(f$n_screened, 3L)
  expect_false("tst2008" %in% f$elections)
})
