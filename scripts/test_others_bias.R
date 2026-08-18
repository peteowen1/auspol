# T1/T2/T3 against docs/plans/prereg-others-bias.md
#
# Why "Others" is fitted about 3.6 points below its eventual result at a cycle
# endpoint. Three causes were fixed in advance, each with a test chosen so that
# confirming one does not confirm the others:
#
#   C1 the prior is too sticky      -> T1 bias vs growth since the last election
#   C2 every pollster misses alike  -> T2 model-vs-polls against polls-vs-actual
#   C3 the walk is too slow         -> T3 bias vs late movement in the polls
#
# The decision rule is in the plan and is NOT restated here, so it cannot drift
# to fit whatever comes out.
#
# This is a measurement script, not a pipeline stage. It emits OB* codes.

suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)

# ---------------------------------------------------------------------------
# Anchor checks, written before the run.
#
# This reconstructs a table that already exists -- the 54-cycle bias in
# docs/reviews/couple-party-trends-2026-08-18.md, which was measured ad hoc and
# left no script. So the first thing to establish is that this pipeline
# reproduces it. If it does not, T1-T3 are measuring some other quantity and
# their answers mean nothing, however clean they look.
ANCHOR <- data.table(
  party  = c("OTH", "LNP", "ALP", "GRN"),
  bias   = c(-3.60, -1.11,  0.33,  0.10),
  n      = c(54L,    54L,   54L,   33L)
)
TOL_BIAS <- 0.30   # points
TOL_N    <- 2L     # cycles

# All six regions with a poll file. An earlier run of this script used the four
# that build_projection_data() defaults to, which was an unstated narrowing
# copied from a function with a different purpose -- it dropped SA and WA and
# with them a third of the cycles.
REGIONS <- c("fed", "nsw", "vic", "qld", "sa", "wa")
MIN_YEAR <- 1990
LATE <- 30L   # days: the "final polls" window
MID  <- 90L   # days: late movement is the final 30 vs the 60 before it

cat("\n=== Others bias: T1/T2/T3 ===\n")

cycles   <- load_election_cycles()
ev       <- load_eventual_results()
pol      <- load_polled_elections()
pri_all  <- load_prior_results()
flows_all <- load_preference_flows()

rows <- list()
skipped <- list()
note <- function(rg, y, why) {
  skipped[[length(skipped) + 1L]] <<- data.table(region = rg, year = y, why = why)
}

for (rg in REGIONS) {
  f <- anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE)
  if (!file.exists(f)) { note(rg, NA_integer_, "no poll file"); next }
  polls <- suppressMessages(load_polls(rg))

  keep_pol <- pol$region == rg & pol$year >= MIN_YEAR
  for (y in sort(pol$year[which(keep_pol)])) {
    krow <- cycles$region == rg & cycles$year == y
    if (!any(krow)) { note(rg, y, "no cycle row"); next }
    cyc <- cycles[which(krow), ]
    cyc_end <- cyc$end[1]

    # Actual first preferences for this cycle, excluding the TPP pseudo-party.
    ka <- ev$region == rg & ev$year == y & ev$party != "@TPP"
    act <- ev[which(ka), ]
    if (!nrow(act)) { note(rg, y, "no actual FP"); next }

    # THE FILTER THE PLAN REQUIRES TO STAY. An earlier version of this
    # measurement was confounded by cycles whose recorded actuals were
    # themselves incomplete -- WA 2025 summed to 63.9, which would enter here
    # as a colossal fake "Others" shortfall. Completeness of the truth is a
    # precondition for measuring bias against it.
    act_sum <- sum(act$actual)
    complete <- abs(act_sum - 100) <= 5
    if (!complete) note(rg, y, "actuals incomplete (kept for OB2 only)")

    kp <- pri_all$region == rg & pri_all$year == y
    pr <- pri_all[which(kp), ]
    if (!nrow(pr)) { note(rg, y, "no priors"); next }
    priors <- stats::setNames(pr$prev1, pr$party)

    # Same leakage pin as build_projection_data(): flows may only come from
    # elections strictly before this one, as known at the START of the cycle.
    fl <- tryCatch(flows_for(flows_all, y - 1L, rg, quiet = TRUE,
                             cycles = cycles, as_of = cyc$start[1]),
                   error = function(e) NULL)
    if (is.null(fl)) { note(rg, y, "no flows"); next }

    r <- tryCatch(trend_as_at(polls, y, cycles, cyc_end, priors, fl),
                  error = function(e) { note(rg, y, "fit error"); NULL })
    if (is.null(r)) { note(rg, y, "no fit"); next }

    # Raw published polls in this cycle, for T2 and T3. These are the model's
    # INPUT, so comparing the fit against them separates "the model failed to
    # follow the polls" from "the polls were wrong".
    cp <- cycle_polls(polls, y, cycles)
    for (p in names(r$fp)) {
      ka2 <- act$party == p
      if (!any(ka2)) next
      if (!(p %in% names(cp))) next
      v <- cp[[p]]; d <- cp$date
      fin <- which(!is.na(v) & d > cyc_end - LATE & d <= cyc_end)
      mid <- which(!is.na(v) & d > cyc_end - MID & d <= cyc_end - LATE)
      rows[[length(rows) + 1L]] <- data.table(
        region = rg, year = y, party = p,
        complete = complete, act_sum = act_sum,
        fitted = unname(r$fp[[p]]),
        actual = act$actual[which(ka2)][1],
        prev   = unname(priors[p] %||% NA_real_),
        poll_final = if (length(fin)) mean(v[fin]) else NA_real_,
        poll_mid   = if (length(mid)) mean(v[mid]) else NA_real_,
        n_final = length(fin), n_mid = length(mid))
    }
    message(sprintf("  %s %d done", rg, y))
  }
}

dt <- rbindlist(rows)
skip <- rbindlist(skipped)
stopifnot(nrow(dt) > 0)
dt[, bias := fitted - actual]
dt_all <- copy(dt)
# THE PRE-REGISTERED SET. Everything from OB0 down uses this.
dt <- dt_all[complete == TRUE]

cat(sprintf("\n%d (cycle, party) rows over %d cycles; %d cycles skipped\n",
            nrow(dt), uniqueN(dt[, .(region, year)]), nrow(skip)))
if (nrow(skip)) print(skip[, .N, by = why])

# ---------------------------------------------------------------------------
# OB0  replication anchor
by_party <- dt[, .(n = .N, fitted = mean(fitted), actual = mean(actual),
                   bias = mean(bias)), by = party][order(bias)]
cat("\nOB0  reconstruction of the 54-cycle bias table\n")
print(by_party)

chk <- merge(ANCHOR, by_party[, .(party, got_bias = bias, got_n = n)],
             by = "party", all.x = TRUE)
chk[, ok := !is.na(got_bias) & abs(got_bias - bias) <= TOL_BIAS &
      abs(got_n - n) <= TOL_N]
print(chk)
if (!all(chk$ok)) {
  cat("OB0  FAIL: this does not reproduce the published table.\n")
  cat("     T1-T3 below are therefore measuring a different quantity and\n",
      "    must not be read as answering the pre-registration.\n")
} else {
  cat("OB0  PASS: reproduces the published table within tolerance.\n")
}

oth <- dt[party == "OTH"]
stopifnot(nrow(oth) > 0)

# ---------------------------------------------------------------------------
# T1 (C1, sticky prior): does bias track growth since the last election?
# Predicts a significantly NEGATIVE slope. C2 and C3 predict none.
t1 <- oth[is.finite(prev)]
t1[, growth := actual - prev]
m1 <- stats::lm(bias ~ growth, data = t1)
s1 <- summary(m1)$coefficients
cat(sprintf("\nT1  n=%d  slope=%+.3f (se %.3f, p=%.4g)  cor=%+.3f\n",
            nrow(t1), s1["growth", 1], s1["growth", 2], s1["growth", 4],
            stats::cor(t1$growth, t1$bias)))
T1_FIRES <- s1["growth", 1] < 0 && s1["growth", 4] < 0.05
cat(sprintf("T1  %s\n", if (T1_FIRES) "FIRES: slope is negative and significant"
                        else "does not fire"))

# ---------------------------------------------------------------------------
# T2 (C2, shared pollster miss): is the model near the polls while the polls
# are far from the result? Predicts |model - polls| << |polls - actual|.
t2 <- oth[is.finite(poll_final)]
t2[, `:=`(mdl_vs_polls = fitted - poll_final,
          polls_vs_act = poll_final - actual)]
cat(sprintf("\nT2  n=%d  mean(model - polls)=%+.3f  mean(polls - actual)=%+.3f\n",
            nrow(t2), mean(t2$mdl_vs_polls), mean(t2$polls_vs_act)))
cat(sprintf("T2  mean|model - polls|=%.3f   mean|polls - actual|=%.3f\n",
            mean(abs(t2$mdl_vs_polls)), mean(abs(t2$polls_vs_act))))
# THIS BAR IS NOT PRE-REGISTERED. The plan says |model - polls| should be
# "much smaller" than |polls - actual| and never puts a number on it; 0.5 was
# written here with the script, in the same commit that ran it. The measured
# ratio is 0.41, close enough that a bar of 0.4 would report "nothing fired".
# So the RATIO is the result and the verdict below is a judgement call.
#
# It matters less than it looks: the plan's "nothing fires" branch also leaves
# the trend model untouched, so the ACTION is identical either way. The two
# branches differ only in whether the miss is attributed to the polls, and the
# numbers behind that attribution are descriptive, not threshold-dependent.
T2_FIRES <- mean(abs(t2$mdl_vs_polls)) < 0.5 * mean(abs(t2$polls_vs_act))
cat(sprintf("T2  %s\n",
            if (T2_FIRES) "FIRES: the polls carry the miss, not the model"
            else "does not fire"))

# ---------------------------------------------------------------------------
# T3 (C3, slow walk): does bias scale with late movement in the polls?
# Late movement is the final 30 days against the 60 days before them, measured
# in the POLLS -- the thing the walk is supposed to follow.
t3 <- oth[is.finite(poll_final) & is.finite(poll_mid)]
t3[, late_move := poll_final - poll_mid]
m3 <- stats::lm(bias ~ late_move, data = t3)
s3 <- summary(m3)$coefficients
cat(sprintf("\nT3  n=%d  slope=%+.3f (se %.3f, p=%.4g)  cor=%+.3f\n",
            nrow(t3), s3["late_move", 1], s3["late_move", 2], s3["late_move", 4],
            stats::cor(t3$late_move, t3$bias)))
T3_FIRES <- s3["late_move", 4] < 0.05
cat(sprintf("T3  %s\n", if (T3_FIRES) "FIRES: bias tracks late movement"
                        else "does not fire"))

cat(sprintf("\nOB1  fired: %s\n",
            paste(c("T1", "T2", "T3")[c(T1_FIRES, T2_FIRES, T3_FIRES)],
                  collapse = ", ")))
if (sum(c(T1_FIRES, T2_FIRES, T3_FIRES)) == 0L) {
  cat("OB1  nothing fired -- per the plan this is a legitimate outcome and is\n",
      "    recorded as measured-and-unexplained, not explained after the fact.\n")
}

# ---------------------------------------------------------------------------
# OB2  where did the published -3.60 come from?
#
# OB0 does not reproduce it, so the difference has to be explained rather than
# shrugged at. The obvious suspect is the completeness filter, because a cycle
# whose recorded actuals omit parties leaves that vote sitting in the listed
# "Others" row -- inflating actual OTH while the fitted value is unaffected.
# That is a data artefact wearing the shape of a modelling bias, and it is the
# exact confound the plan's threats section says the filter exists to remove.
#
# This is diagnosis of a discrepancy, NOT a re-specification: the filter stays,
# and OB0/T1-T3 above are unchanged.
inc <- dt_all[complete == FALSE]
cat(sprintf("\nOB2  %d (cycle, party) rows from %d cycles with INCOMPLETE actuals\n",
            nrow(inc), uniqueN(inc[, .(region, year)])))
if (nrow(inc)) {
  cat(sprintf("OB2  their actuals sum to %.1f on average (complete cycles: %.1f)\n",
              mean(unique(inc[, .(region, year, act_sum)])$act_sum),
              mean(unique(dt[, .(region, year, act_sum)])$act_sum)))
  both <- dt_all[, .(n = .N, bias = mean(bias)), by = party][order(bias)]
  cat("OB2  bias with NO completeness filter (this is what -3.60 looks like):\n")
  print(both)
  cat(sprintf("OB2  OTH bias: complete-only %+.2f, all cycles %+.2f, published %+.2f\n",
              dt[party == "OTH", mean(bias)],
              dt_all[party == "OTH", mean(bias)], -3.60))
}

out <- file.path("output", "others-bias-tests.csv")
dir.create("output", showWarnings = FALSE)
data.table::fwrite(dt_all, out)
cat(sprintf("\nWrote %s\n", out))
