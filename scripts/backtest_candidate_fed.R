# Backtest the candidate-level seat model on the federal corpus.
#
# WHY. Every feature decision made on this model has rested on
# backtest_candidate_vic.R and backtest_candidate_nsw.R -- 166 seats across TWO
# elections. The repo holds seven federal elections with first preferences,
# transfers and declared winners, which is SIX consecutive pairs at ~150
# divisions each. That data has never been pointed at the seat model.
#
# The consequence showed up on 2026-08-20: the seat-swing port came back
# "positive but short of the bar" on an election-clustered standard error with
# ONE degree of freedom. That is not a finding about the port, it is a finding
# about the sample. Six clusters is still small; it is three times what every
# decision so far has had.
#
# NOTHING LEAKS. Each pair swings from the EARLIER election's district first
# preferences, uses the EARLIER election's flow matrix, and is scored against
# the AEC's declared winners for the later one.
#
# ONE DELIBERATE EXCEPTION, gated to !FORECAST_MODE. The default ("oracle")
# path already reads the LATER election's statewide result (`st_b`) as the
# true swing to apply -- that is this harness's whole design, not a leak of
# its own. It also reads the later election's first preferences (`fb`) for
# one further fact: whether ANY independent stood, to zero IND's win
# probability in seats where none did. Nomination is knowable before polling
# day in a real forecast, unlike vote share, so this is a narrower fact than
# the oracle swing already uses -- but there is no actual pre-election
# nomination list in this pipeline, only "IND received a nonzero recorded
# vote in `fb`" as a proxy for it, so it is still target-year data and is
# switched OFF under FORECAST_MODE, whose entire point is not seeing eb yet.
#
# WHAT THIS CANNOT TEST, CORRECTED 2026-08-26. `seat_swing_adjustment()` needs
# `fed_swing` -- how a seat swung at the preceding FEDERAL election -- and the
# federal seat files carry it for ZERO seats. That much is still true.
#
# But "no federal analogue" was wrong twice over. The AEC ships a per-candidate
# `Swing` column in the same first-preferences file this pipeline already
# downloads, for all seven elections; it was being aggregated away, and is now
# carried through by scripts/build_candidacies.R. So the analogue -- a seat's
# own swing at the PREVIOUS federal election, knowable on the night and
# therefore leak-free -- is available.
#
# MEASURED, AND DELIBERATELY NOT WIRED IN. Over 882 seat-elections the prior
# departure predicts the next one with slope **-0.264** (SE 0.033, t = -8.0),
# negative in all six elections: seats REVERT rather than persist.
# SEAT_SWING_COEF is +0.7452, so importing the state-fitted coefficient here
# would apply it with the wrong sign and make the federal forecast worse.
#
# It is also too small to matter: R2 0.068, cutting seat-level error 4.560 ->
# 4.402 points, a 3.5% reduction. And it is concentrated in two elections
# (2013 R2 0.33, 2019 R2 0.24) against near-zero in three others, so the pooled
# slope describes no individual election well. Part of it is regression to the
# mean rather than behaviour, which needs a t-2 baseline to separate.
#
# So this harness still does not test the seat-swing port -- not for want of
# data, but because the predictor has the opposite sign and 3.5% of the error.
#
# Emits BF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# LEVEL-DEPENDENT SEAT VARIANCE, off by default. AUSPOL_LEVEL_SD="1.10,8.67"
# makes the per-seat deviation sd = a + b*sqrt(p(1-p)) instead of a flat
# seat_sd. Pre-registered in docs/plans/prereg-level-dependent-variance.md;
# unset reproduces the published model exactly.
.level_sd <- local({
  # ADOPTED 2026-08-27. Default ON at the fitted values; AUSPOL_LEVEL_SD="off"
  # reproduces the flat seat_sd exactly. See
  # docs/reviews/level-variance-2026-08-27.md -- federal seats called 99%+ and
  # LOST fall from 23 to 12 over 886 seat-elections, and Brier and log loss
  # improve in every subset on both federal and NSW.
  raw <- Sys.getenv("AUSPOL_LEVEL_SD", "1.10,8.67")
  if (identical(tolower(raw), "off") || !nzchar(raw)) NULL else {
    v <- suppressWarnings(as.numeric(strsplit(raw, ",")[[1]]))
    if (length(v) != 2L || !all(is.finite(v)))
      stop("AUSPOL_LEVEL_SD must be two finite numbers, e.g. 1.10,8.67")
    v
  }
})
cat(sprintf("LV1  level_sd: %s
", if (is.null(.level_sd)) "OFF (flat seat_sd)" else
            sprintf("a=%.2f b=%.2f", .level_sd[1], .level_sd[2])))

# PER-CLASS SLOPE MULTIPLIER, both 1 by default so this is a no-op until an arm
# sets it. AUSPOL_LEVEL_MULT_IND and AUSPOL_LEVEL_MULT_OTH scale level_sd's
# slope for independents and for every other non-major; majors are never
# touched. Pre-registered in docs/plans/prereg-class-specific-variance.md.
#
# WHY IT EXISTS. level_sd above ships ONE curve for every party, and the review
# that adopted it measured that the seats it fixed were not the seats it
# widened: on NSW the calibration slope went 0.565 -> 0.720 across all seats but
# 0.959 -> 1.272 EXCLUDING seats an independent won. The majors were already
# almost right and got widened past 1 anyway.
.level_mult <- local({
  g <- function(v) {
    x <- suppressWarnings(as.numeric(Sys.getenv(v, "1")))
    if (!is.finite(x) || x < 0) stop(v, " must be a finite, non-negative number")
    x
  }
  c(ind = g("AUSPOL_LEVEL_MULT_IND"), oth = g("AUSPOL_LEVEL_MULT_OTH"))
})
# Printed unconditionally, including when it is off. An arm that silently did
# not apply is indistinguishable from an arm that made no difference -- the
# failure CLAUDE.md records under "an experiment that never ran".
cat(sprintf("LV2  level_mult: %s
",
            if (all(.level_mult == 1)) "OFF (one curve for every class)" else
              sprintf("IND x%.2f, other non-major x%.2f",
                      .level_mult[["ind"]], .level_mult[["oth"]])))
# Built per call site from that seat file's own columns, because
# simulate_seat_contests() rejects a name that is not a share column.
.lm <- function(sh) level_mult_for(colnames(sh), .level_mult[["ind"]],
                                   .level_mult[["oth"]])


# ---- other jurisdictions' flows, date-filtered ------------------------------
# Against docs/plans/prereg-qld-flows.md and docs/plans/prereg-wa-flows.md.
# Queensland 2020 and 2024 add 750 exclusion events; Western Australia's seven
# admissible elections add 1,634 and take One Nation's from 198 to 359.
#
# Either may only be used to predict an election held AFTER it. That rule lives
# in pool_configured_flows() rather than in a copy per harness -- there were
# four byte-identical copies, one of which had rotted into a gate that was
# defined and never called, and it is the one rule here that must never be
# wrong. Both sources default OFF.

# Polling day for each federal election, which is what decides what a backtest
# may see. Hand-entered, and the only ones here not covered by the year check
# in EXTERNAL_FLOWS, so they are asserted against their own keys below.
FED_DATE <- c("2010"="2010-08-21","2013"="2013-09-07","2016"="2016-07-02",
              "2019"="2019-05-18","2022"="2022-05-21","2025"="2025-05-03")
stopifnot(names(FED_DATE) == format(as.Date(FED_DATE), "%Y"))

# ARM B of docs/plans/prereg-calibration.md. A multiplier on the per-seat
# spread, so the simulation carries more genuine seat-level uncertainty. Default
# 1 reproduces the published behaviour exactly; the run prints what it applied,
# because CLAUDE.md records an experiment whose edit never ran and whose
# byte-identical output read as "this input does not matter".
SEAT_SD_MULT <- as.numeric(Sys.getenv("AUSPOL_SEAT_SD_MULT", "1"))
if (SEAT_SD_MULT != 1) cat(sprintf("CAL  seat_sd multiplier %.2f applied
", SEAT_SD_MULT))

# OUTPUT FILENAME CARRIES THE CONFIG, and it must. These harnesses used to write
# to one fixed name, so running an experimental arm SILENTLY OVERWROTE the
# baseline it was meant to be compared against. That happened on 2026-08-21: a
# seat_sd sweep overwrote backtest-fed.csv and backtest-vic.csv, and the
# resulting comparison showed a difference of EXACTLY +0.0000 for all six
# federal elections because both arms were the same file. It read as "this
# input does not matter", which is the failure mode CLAUDE.md already records
# for an experiment that never ran.
#
# A default run still writes the plain name, so nothing downstream changes.
# N_SIMS is settable so the federal harness -- six pairs at ~150 divisions --
# can be swept across arms in minutes rather than an hour. Monte Carlo error at
# 5,000 draws is far below the log-score differences under test.
#
# THE ARMS OF ONE ELECTION MUST SHARE IT. A paired comparison between arms is
# valid at any n_sims, but only if both arms of the SAME election used the same
# one; the tag below records it in the filename so a mismatched pair cannot be
# compared by accident.
N_SIMS <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))
# Forecast mode: statewide vote from the poll trend rather than from the result.
FORECAST_MODE <- identical(Sys.getenv("AUSPOL_FORECAST_MODE", "0"), "1")
# The projection the statewide draws are anchored to, built once. The
# fundamentals prediction is LEAVE-ONE-OUT: fitting on every election and then
# predicting one of them would leak that election's own result into its
# forecast through the prior, which is the same leak as using its polls.
# `actual - loo_errors` is the held-out prediction, and is the pattern
# scripts/compare_backtest_model.R already uses.
if (FORECAST_MODE) {
  .mix <- fread("output/projection-mix.csv", showProgress = FALSE)
  .m   <- fit_fundamentals(build_fundamentals_data(), "@TPP")
  FUND_LOO <- data.table(year = .m$data$year, region = .m$data$region,
                         fund = .m$data$actual - .m$loo_errors)
}


# ARM B/C of docs/plans/prereg-statewide-covariance.md. AUSPOL_PARTY_COR=shrunk
# correlates the parties' statewide deviations instead of drawing them
# independently. Empty (the default) reproduces the previous behaviour exactly.
PARTY_COR <- NULL
if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", ""))) {
  .co <- readRDS("output/statewide-cov.rds")
  PARTY_COR <- if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) .co$cor else .co$cor_shrunk
  cat(sprintf("COV  party correlation ON (%s): cor(ONP,LNP) = %+.2f
",
              Sys.getenv("AUSPOL_PARTY_COR"), PARTY_COR["ONP", "LNP"]))
}

# THE HARNESS HAS NEVER PASSED `shrink`. fit_seats_full.R passes SHRINK = 0.10 --
# the per-draw calibration shrink adopted after measuring over-confidence on
# 1,187 seats -- and simulate_seat_contests() defaults it to 0, so every backtest
# figure this repo has quoted was computed WITHOUT it. That is the same
# divergence as statewide_draws, in a second place.
#
# Defaulted to 0 here so nothing changes silently and past runs stay comparable.
# The published value is in the grid of docs/plans/prereg-seat-calibration.md and
# gets measured rather than assumed.
SHRINK <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0"))

# Per-seat insurgency risk, loaded once. Default OFF, so nothing moves unless
# AUSPOL_INSURGENCY_SHRINK=1 is set.
RISK_FILE <- "output/fed-insurgency-risk.csv"
RISK <- if (identical(Sys.getenv("AUSPOL_INSURGENCY_SHRINK", "0"), "1") &&
            file.exists(RISK_FILE))
  data.table::fread(RISK_FILE, showProgress = FALSE) else NULL
# INSURGENCY SURGE, against docs/plans/prereg-insurgency-surge.md. A fat tail
# rather than a wider bell: with probability SURGE_H the strongest eligible
# non-major gains N(15.6, 6.1) and the count then decides, so a surge that falls
# short loses and no ceiling is imposed. Default 0 leaves every past run
# reproducible.
SURGE_H <- as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0"))

# PER-SEAT SURGE HAZARD FROM SALIENCE, against
# docs/plans/prereg-salience-surge-hazard.md.
#
# A FLAT hazard is the wrong shape, and that is measured rather than assumed:
# docs/reviews/shrink-vs-surge-2026-08-26.md shows the surge helping where
# non-majors emerged (SA's four One Nation seats, NSW's nine independents) and
# costing Brier in WA and Victoria, where they did not. Applying a 5.08% chance
# to every seat adds probability where nothing is happening.
#
# Salience conditions it: high in Curtin and North Sydney, zero in the ~130
# seats where nobody is being searched for. Seats with no salience row fall back
# to SURGE_H, so setting AUSPOL_SURGE_H=0 alongside this means "surge ONLY where
# there is a signal" -- which is the arm worth testing.
SALIENCE_HAZ <- NULL
if (identical(Sys.getenv("AUSPOL_SALIENCE_SURGE", "0"), "1")) {
  hf <- "output/salience-hazard.csv"
  if (!file.exists(hf))
    stop("AUSPOL_SALIENCE_SURGE=1 but ", hf, " is missing; ",
         "run scripts/fit_salience_hazard.R")
  SALIENCE_HAZ <- data.table::fread(hf, showProgress = FALSE)
  cat(sprintf("BF0h salience hazard loaded: %d seats | median %.4f | max %.4f
",
              nrow(SALIENCE_HAZ), stats::median(SALIENCE_HAZ$surge_h),
              max(SALIENCE_HAZ$surge_h)))
}

# ARM SURGE-V2: multi-feature, governed-population-gated hazard replacing
# fit_salience_hazard.R's single-feature (`ratio`), ungated, stale-instrument
# fit. See R/salience_surge.R and docs/plans/prereg-salience-surge-v2.md.
# Computed FRESH per target election below (not loaded from a file), fit on
# every OTHER available election so the target never leaks into its own fit.
SURGE_V2 <- identical(Sys.getenv("AUSPOL_SALIENCE_SURGE_V2", "0"), "1")
SURGE_V2_PAIRS <- list(
  list(election = "fed2010", prev = "fed2007", region = "fed"),
  list(election = "fed2013", prev = "fed2010", region = "fed"),
  list(election = "fed2016", prev = "fed2013", region = "fed"),
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "vic2022", prev = "vic2018", region = "vic"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa"),
  list(election = "wa2008",  prev = "wa2005",  region = "wa"))
if (SURGE_H > 0)
  cat(sprintf("BF0s surge hazard %.4f, size N(15.6, 6.1), floor 2%%
", SURGE_H))
SMOOTH <- as.numeric(Sys.getenv("AUSPOL_SMOOTH", "0.15"))
stopifnot(is.finite(SHRINK), SHRINK >= 0, SHRINK < 1,
          is.finite(SMOOTH), SMOOTH >= 0, SMOOTH <= 1)
cat(sprintf("CAL  shrink %.2f (published model uses 0.10), smooth %.2f\n",
            SHRINK, SMOOTH))

# THE FLOW FIXES, PORTED. `fallback_smooth` and `flow_sd` were added to the
# South Australian harness on 2026-08-25 and existed NOWHERE ELSE, so setting
# them in the environment for a cross-harness comparison silently did nothing
# here -- an experiment that never ran, reading as an input that does not
# matter. That is the failure CLAUDE.md records under "A fix to one harness is
# a fix to ALL of them", and it recurred in the same session the rule was
# written. Both default to 0, which reproduces the previous behaviour exactly.
FB_SMOOTH <- as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0"))
FLOW_SD   <- as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0"))
cat(sprintf("BS1f fallback_smooth %.2f | flow_sd %.2f
", FB_SMOOTH, FLOW_SD))

# ARM FINGERPRINT. CAL_TAG names the parameters someone remembered to add, and
# twice now a new one was not: AUSPOL_LEVEL_SD and AUSPOL_DEV_SLOPE both wrote
# over another arm's per-seat output, silently, so a comparison read two copies
# of the same run. This appends a short hash of every AUSPOL_* variable that is
# set, so a NEW parameter cannot repeat that without anyone touching this line.
.arm_fingerprint <- local({
  e <- Sys.getenv()
  e <- e[grepl("^AUSPOL_", names(e)) & nzchar(e)]
  e <- e[!names(e) %in% c("AUSPOL_OUT_SUFFIX")]
  if (!length(e)) "" else {
    s <- paste(sort(paste0(names(e), "=", e)), collapse = ";")
    sprintf("-a%s", substr(tolower(paste0(as.hexmode(
      sum(utils::head(utf8ToInt(s), 4000) * seq_along(utils::head(utf8ToInt(s), 4000)))
    ))), 1, 6))
  }
})
CAL_TAG <- paste0(
  if (nzchar(Sys.getenv("AUSPOL_FED_PAIRS", ""))) sprintf("-p%s", gsub("[^0-9]", "", Sys.getenv("AUSPOL_FED_PAIRS"))) else "",
  if (!is.null(.level_sd)) sprintf("-lv%s", gsub("[.]", "", paste(format(.level_sd, nsmall=2), collapse="_"))) else "",
  if (identical(Sys.getenv("AUSPOL_SALIENCE_SURGE", "0"), "1")) "-salsurge" else "",
  if (as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0")) > 0)
    sprintf("-surge%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_SURGE_H")), nsmall = 4)))
  else "",
  if (identical(Sys.getenv("AUSPOL_INSURGENCY_SHRINK", "0"), "1")) "-insurg" else "",
  # NO shrink clause here: this file already has one further down, keyed on the
  # SHRINK variable. Adding a second produced "-sh10-...-sh10" in the filename.
  # Victoria and NSW genuinely had none, which is why they needed one added.
  if (as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0")) != 0)
    sprintf("-el%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER")), nsmall = 1)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0")) != 0)
    sprintf("-fb%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0")) != 0)
    sprintf("-fsd%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_FLOW_SD")), nsmall = 1)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5")) != 1.5)
    sprintf("-psd%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_PARTY_SD")), nsmall = 2)))
  else "",
  if (SEAT_SD_MULT != 1) sprintf("-m%s", format(SEAT_SD_MULT, nsmall = 1)) else "",
  if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")) "-port" else "",
  if (N_SIMS != 20000L) sprintf("-n%d", N_SIMS) else "",
  # "-corraw" and "-cor" are DIFFERENT correlation matrices. Both used to tag
  # "-cor", so running the raw arm and then the shrunk one wrote the second over
  # the first and a before/after comparison compared an arm with itself. Fixed
  # in nsw/sa/vic and missed here, which is the sister-script trap: patch one
  # copy, grep for the rest.
  if (!is.null(PARTY_COR))
    (if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "-corraw" else "-cor")
  else "",
  if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1")) "-qld" else "",
  if (identical(Sys.getenv("AUSPOL_WA_FLOWS", "0"), "1")) "-wa" else "",
  # The control arm of refusal W1 runs with the flows switched ON and a cutoff
  # that admits nothing. Without this it would write to the same "-wa" name as
  # the real arm and overwrite it -- the baseline-clobbering that has already
  # produced four byte-identical comparisons here.
  if (nzchar(Sys.getenv("AUSPOL_WA_CUTOFF", "")) ||
      nzchar(Sys.getenv("AUSPOL_QLD_CUTOFF", ""))) "-cut" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_3C", "0"), "1")) "-no3c" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_LNP", "0"), "1")) "-nolnp" else "",
  if (FORECAST_MODE) "-fc" else "",
  if (SHRINK != 0) sprintf("-sh%s", sub("0[.]", "", format(SHRINK, nsmall = 2))) else "",
  if (SMOOTH != 0.15) sprintf("-sm%s", sub("0[.]", "", format(SMOOTH, nsmall = 2))) else "", .arm_fingerprint)

# SEED settable so the Monte Carlo error on a reported figure can be measured
# rather than assumed. At 20,000 sims over ~150 divisions the standard error
# on mean log loss is a few thousandths -- enough to matter when comparing
# against an external benchmark at that precision. Default unchanged.
SEED <- as.integer(Sys.getenv("AUSPOL_SEED", "42")); eps <- 1e-6
P <- election_data_path()

PAIRS <- list(
  list(from = 2007, to = 2010), list(from = 2010, to = 2013),
  list(from = 2013, to = 2016), list(from = 2016, to = 2019),
  list(from = 2019, to = 2022), list(from = 2022, to = 2025))

FP  <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)
TX  <- fread(file.path(P, "aec-fed-transfers.csv"), showProgress = FALSE)
WIN <- fread(file.path(P, "aec-fed-winners.csv"), showProgress = FALSE)

# The federal files are already in this repo's party classes, so no
# classify_party() call is needed -- confirmed against the value sets. The
# Coalition fold is kept anyway because a future refetch could reintroduce
# LIB/NAT/CLP and the failure would be silent: those seats would simply never
# match a predicted party.
coal <- function(x) fifelse(x %in% c("NAT", "LIB", "LNP", "CLP"), "LNP", x)

# Per-seat idiosyncratic spread. Taken from the seat file of the election being
# predicted where one exists (2019, 2022, 2025); the earlier pairs have no
# federal seat file, so they use the MEDIAN of those that do rather than a
# number invented here. It is a variance parameter, not a prediction, and it is
# reported per pair so a pair running on the fallback is visible.
spread_for <- function(yr, swing) {
  s <- tryCatch(as.data.table(load_seats(yr, "fed")), error = function(e) NULL)
  if (is.null(s)) return(NA_real_)
  tryCatch(seat_swing_spread(s, swing)$sd_within, error = function(e) NA_real_)
}

out_all <- list(); seat_sds <- c()
# RESTRICT TO CHOSEN PAIRS. Salience currently exists for fed2022 only, so a
# full six-election run spends ten minutes recomputing five unchanged controls.
# AUSPOL_FED_PAIRS=2022 runs just that pair. Default is every pair, so nothing
# changes unless asked.
.want <- Sys.getenv("AUSPOL_FED_PAIRS", "")
if (nzchar(.want)) {
  .keep <- as.integer(trimws(strsplit(.want, ",")[[1]]))
  PAIRS <- Filter(function(k) k$to %in% .keep, PAIRS)
  cat(sprintf("BF0p restricted to %d pair(s): %s
", length(PAIRS),
              paste(vapply(PAIRS, function(k) k$to, numeric(1)), collapse = ", ")))
  if (!length(PAIRS)) stop("AUSPOL_FED_PAIRS matched no pair")
}
for (K in PAIRS) {
  ea <- sprintf("fed%d", K$from); eb <- sprintf("fed%d", K$to)
  fa <- FP[election == ea, .(votes = sum(votes)), by = .(seat, party)]
  fb <- FP[election == eb, .(votes = sum(votes)), by = .(seat, party)]
  # POOL THE TWO MOST RECENT PRIOR ELECTIONS, off by default
  # (AUSPOL_FLOW_PRIORS=2). Flows are built from one prior election, which
  # leaves most exact cells below min_n and sends the rest to a fallback.
  # Audited against every fed2025 exclusion, vote-weighted absolute flow
  # error: one prior 7.66 points, two priors 7.35, three 7.52 -- two is the
  # optimum, and three is worse because older flows have genuinely drifted.
  # LEAKAGE: only elections strictly BEFORE the target are admitted, checked
  # here rather than assumed.
  tx <- TX[election == ea]
  .np <- suppressWarnings(as.integer(Sys.getenv("AUSPOL_FLOW_PRIORS", "1")))
  if (is.finite(.np) && .np > 1L) {
    .yr <- function(e) suppressWarnings(as.integer(sub("^[a-z]+", "", e)))
    cand <- unique(TX$election)
    cand <- cand[grepl("^fed", cand) & .yr(cand) < K$to]
    cand <- cand[order(-.yr(cand))][seq_len(min(.np, length(cand)))]
    stopifnot(all(.yr(cand) < K$to))
    tx <- TX[election %in% cand]
    cat(sprintf("BF0f flows pooled from %d prior election(s): %s
",
                length(cand), paste(sort(cand), collapse = ", ")))
  }
  # LEAKAGE GUARD, asserted on the filtered result AND on its size: an empty
  # table trivially satisfies an all() check, which is the guard-that-cannot-
  # fail pattern CLAUDE.md records.
  # LEAKAGE GUARD, generalised from "== ea" to "strictly before the target"
  # when flows are pooled across priors. Still asserted on the filtered result
  # AND its size: an empty table trivially satisfies an all() check, which is
  # the guard-that-cannot-fail pattern CLAUDE.md records.
  .yrq <- function(e) suppressWarnings(as.integer(sub("^[a-z]+", "", e)))
  stopifnot(nrow(tx) > 100L, all(.yrq(tx$election) < K$to))
  tx <- pool_configured_flows(tx, FED_DATE[[as.character(K$to)]])
  fm <- build_flow_matrix(tx, min_n = 3L)
  # PER-CLASS FLOW POOLING, off by default (AUSPOL_FLOW_POOL_VOLATILE=1).
  # Pooling every class across two prior elections cuts raw flow error
  # (7.66 -> 7.35 points) but WORSENS the seat forecast, because it smooths
  # classes whose flows are stable and where recency is what matters.
  # Volatility differs enormously between classes, and it is measurable from
  # PRIOR elections only -- fed2013-2022, nothing from the target:
  #
  #   ONP 13.59 | ALP 12.82 | LNP 7.92 | OTH_RIGHT 4.88 | OTH 3.55 | IND 3.47 | GRN 0.61
  #   (vote-weighted sd of destination shares across those elections)
  #
  # So average more where the estimate is unstable and stay recent where it
  # is not -- ordinary shrinkage, and the ranking that decides which classes
  # get it uses no information from the election being forecast.
  if (identical(Sys.getenv("AUSPOL_FLOW_POOL_VOLATILE", "0"), "1")) {
    .yv <- function(e) suppressWarnings(as.integer(sub("^[a-z]+", "", e)))
    pri <- unique(TX$election)[grepl("^fed", unique(TX$election))]
    pri <- pri[.yv(pri) < K$to]
    if (length(pri) >= 3L) {
      hist <- TX[election %in% pri, .(v = sum(votes)), by = .(election, from, to)]
      hist[, pct := 100 * v / sum(v), by = .(election, from)]
      vv <- hist[, .(n_el = .N, sd = stats::sd(pct), mean = mean(pct)), by = .(from, to)]
      vv <- vv[n_el >= 3L]
      cls_v <- vv[, .(vol = sum(sd * mean) / sum(mean)), by = from]
      thr <- as.numeric(Sys.getenv("AUSPOL_FLOW_VOL_THRESHOLD", "10"))
      hot <- cls_v[is.finite(vol) & vol > thr, from]
      recent2 <- pri[order(-.yv(pri))][seq_len(min(2L, length(pri)))]
      stopifnot(all(.yv(recent2) < K$to))
      if (length(hot)) {
        fm2 <- build_flow_matrix(TX[election %in% recent2], min_n = 3L)
        swap <- function(a, b) {
          if (is.null(b)) return(a)
          for (nm in names(b)) {
            f <- sub("[|].*$", "", nm)
            if (f %in% hot) a[[nm]] <- b[[nm]]
          }
          a
        }
        fm$conditional <- swap(fm$conditional, fm2$conditional)
        fm$superset    <- swap(fm$superset,    fm2$superset)
        for (f in hot) {
          if (!is.null(fm2$pooled[[f]]))   fm$pooled[[f]]   <- fm2$pooled[[f]]
          if (!is.null(fm2$pairwise[[f]])) fm$pairwise[[f]] <- fm2$pairwise[[f]]
        }
        cat(sprintf("BF0v flows pooled over %s for volatile class(es): %s (threshold %.1f)
",
                    paste(sort(recent2), collapse = "+"),
                    paste(sort(hot), collapse = ", "), thr))
      }
    }
  }

  win <- WIN[election == eb, .(seat, winner = coal(winner))]
  stopifnot(nrow(win) > 100L)

  # NOTIONAL BASELINE FOR A REDISTRIBUTED/NEW SEAT, off by default
  # (AUSPOL_NOTIONAL=1). A seat created by a redistribution has no prior
  # result under its new name, so it is dropped below and never forecast --
  # Bullwinkel at fed2025, and any new Victorian seat in 2026. AE Forecasts
  # called Bullwinkel at 0.748 and was right; on a 150-seat basis that one
  # seat was 85% of our entire remaining log-loss deficit to them.
  # scripts/build_notional_baselines.R reconstructs the prior result on the
  # TARGET election's boundaries from booth-level AEC data (97.3% of fed2022
  # votes map forward). Adding it makes the comparison honest -- it scores a
  # seat we currently get a free pass on -- so it may WORSEN the headline
  # number while removing a real blind spot.
  # ON BY DEFAULT since 2026-09-05 (Pete's call): without it a seat created by
  # a redistribution is silently DROPPED from the forecast, which is a wrong
  # answer rather than a missing one. Set AUSPOL_NOTIONAL=0 to restore the
  # previous drop-the-seat behaviour.
  if (identical(Sys.getenv("AUSPOL_NOTIONAL", "1"), "1") &&
      file.exists("output/notional-baselines.csv")) {
    NB <- fread("output/notional-baselines.csv", showProgress = FALSE)
    NB <- NB[election == eb & prior == ea]
    if (nrow(NB)) {
      missing_seats <- setdiff(unique(fb$seat), unique(fa$seat))
      add <- NB[seat %in% missing_seats, .(seat, party, votes)]
      if (nrow(add)) {
        cat(sprintf("BF0n notional baseline supplied for %d seat(s): %s
",
                    uniqueN(add$seat), paste(sort(unique(add$seat)), collapse = ", ")))
        fa <- rbind(fa, add, fill = TRUE)
      }
    }
  }
  wide <- dcast(fa, seat ~ party, value.var = "votes", fill = 0)
  mat <- as.matrix(wide[, -1, with = FALSE]); rownames(mat) <- wide$seat
  mat <- 100 * mat / rowSums(mat)
  st_a <- fa[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  st_b <- fb[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

  # ---- FORECAST MODE, against docs/plans/prereg-forecast-mode.md -----------
  # Default OFF, in which case the block below is the original: shift each
  # seat by the actual statewide swing, which is the answer.
  #
  # ON, the statewide vector comes from the poll trend as at the day before the
  # election and its uncertainty is carried into the simulation through
  # statewide_draws -- which is what fit_seats_full.R does and what no harness
  # has ever done. That is the point: every calibration figure this repo has
  # quoted describes a tighter variant than the model it ships.
  DEV_SLOPE <- dev_slopes_for(union(colnames(mat), names(st_b)))
  # ARM C: slopes conditional on whether the SAME candidate stands again. A
  # single per-class slope averages two populations that behave nothing alike --
  # IND 0.907 returning against 0.326 new -- so it is wrong for every seat.
  .cond <- Sys.getenv("AUSPOL_DEV_SLOPE_MODE", "") %in% c("conditional", "screened")
  .screened <- identical(Sys.getenv("AUSPOL_DEV_SLOPE_MODE", ""), "screened")
  .returns <- if (.cond) tryCatch(candidate_returns(ea, eb), error = function(e) {
    cat(sprintf("BF1c! conditional slopes unavailable for %s->%s: %s
", ea, eb,
                conditionMessage(e))); NULL }) else NULL
  if (.cond && !is.null(.returns))
    cat(sprintf("BF1c conditional slopes ON %s->%s: %d of %d seat-classes returning
",
                ea, eb, sum(.returns$same), nrow(.returns)))
  # THE BASE VALUE, not just the slope. A returning candidate correctly gets
  # the gentler "same" slope, but that slope was still multiplying the seat's
  # CLASS-level prior vote -- 0% for Orange/IND in 2019, since Philip Donato
  # was registered OTH_RIGHT (Shooters) then, not IND. A five-year sitting
  # member with 49.1% projected near zero because the slope had nothing
  # correct to act on. See personal_prior_vote()'s docs -- this gap was
  # already named in candidate_returns()'s own docstring ("which label they
  # stand under ... belongs to the party swing") and never actually built.
  # MAJOR-PARTY DEFECTOR DISCOUNT, off by default (AUSPOL_DEFECT_DISCOUNT=1).
  # personal_prior_vote() excludes a prior ALP/LNP/NAT registration entirely,
  # so a sitting member who goes independent keeps NO history and is projected
  # off the class-level base -- near zero in a seat with no prior independent.
  # Calare 2025 is the case: Andrew Gee held it for the Nationals, took 39.5%
  # as an independent, and the model gave the seat 0.122 against AE Forecasts'
  # 0.411. Measured over 12 sitting members who did this, retention is 0.284
  # of their major-party vote (sd 0.191); the 5 non-members are unusable
  # (mean 2.32, sd 4.38), so this is restricted to members inside
  # personal_prior_vote(). Estimated leave-one-election-out so the target
  # election never sets its own discount.
  .defect <- NULL
  if (identical(Sys.getenv("AUSPOL_DEFECT_DISCOUNT", "0"), "1")) {
    .defect <- tryCatch({
      MJ <- c("ALP", "LNP", "NAT")
      kk <- function(d) match_key(surname_of(d$surname, d$name),
                                  given_of(d$given, d$name), "initial")
      CB <- fread("output/candidacies.csv", showProgress = FALSE)
      els <- unique(CB$election)
      rr <- rbindlist(lapply(els, function(e1) {
        yr1 <- suppressWarnings(as.integer(sub("^[a-z]+", "", e1)))
        rg  <- sub("[0-9]+$", "", e1)
        nxt <- els[sub("[0-9]+$", "", els) == rg &
                   suppressWarnings(as.integer(sub("^[a-z]+", "", els))) > yr1]
        if (!length(nxt)) return(NULL)
        e2 <- nxt[which.min(suppressWarnings(as.integer(sub("^[a-z]+", "", nxt))))]
        if (identical(e2, eb)) return(NULL)   # never the target election
        A <- copy(CB[election == e1])[, `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
        B <- copy(CB[election == e2])[, `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
        a <- A[nzchar(.k) & party %in% MJ & elected %in% TRUE,
               .(.s, .k, prev = pcv)][, .SD[which.max(prev)], by = .(.s, .k)]
        b <- B[nzchar(.k) & !party %in% MJ, .(.s, .k, now = pcv)]
        m <- merge(a, b, by = c(".s", ".k"))
        if (!nrow(m)) NULL else m[, .(ratio = now / prev)]
      }), fill = TRUE)
      if (is.null(rr) || nrow(rr) < 5L) NULL else {
        v <- stats::median(rr$ratio, na.rm = TRUE)
        cat(sprintf("BF0d defector discount %.3f from %d cases (target excluded)
",
                    v, nrow(rr)))
        v
      }
    }, error = function(e) NULL)
  }
  .own_prev <- if (.cond) tryCatch(personal_prior_vote(ea, eb, major_discount = .defect),
                                   error = function(e) NULL) else NULL
  .own_x <- function(p, seats, x) {
    if (is.null(.own_prev)) return(x)
    ov <- .own_prev[.own_prev$party == p, ]
    v <- stats::setNames(ov$own_prev_pcv, ov$seat)[seats]
    out <- x
    hit <- !is.na(v)
    out[hit] <- unname(v[hit])
    out
  }
  # ARM CS: arm C plus the salience screen, protecting the rare emergent that
  # arm C's harsh new-candidate slope crushed. See screened_slopes().
  .permit <- if (.screened) salience_permit_for(eb, ea, "fed") else NULL
  # `permit_tbl`, not `permit`: a parameter whose NAME is literally identical to
  # one of its own data.table columns ("permit") triggers a data.table $-typo
  # check that throws "$ operator is invalid for atomic vectors" -- not an NSE
  # miscompute this time, an outright crash. Confirmed by isolated repro: same
  # body, only the parameter name changed, and the collision is what breaks it.
  # SITTING-MEMBER SLOPE TIER, off by default (AUSPOL_MP_SLOPE=1). See
  # conditional_slopes()'s own comment: a returning MEMBER (0.954) and a
  # returning also-ran (0.800) are 2.9 SE apart and the shipped value pools
  # them at 0.907, systematically shrinking entrenched independents.
  .MP_SLOPE <- if (identical(Sys.getenv("AUSPOL_MP_SLOPE", "0"), "1"))
    c(IND = 0.954, OTH_RIGHT = 0.954, GRN = 0.994, ONP = 0.610) else NULL
  .fed_slope <- function(p, seats, cond, screened, returns, permit_tbl) {
    if (screened && !is.null(permit_tbl)) {
      pv <- permit_tbl[permit_tbl$party == p, ]
      lut <- stats::setNames(as.logical(pv$permit), pv$seat)
      pm <- unname(lut[seats])
      pm[is.na(pm)] <- TRUE
      return(screened_slopes(p, seats, returns, pm, same_mp = .MP_SLOPE))
    }
    if (cond && !is.null(returns))
      return(conditional_slopes(p, seats, returns, same_mp = .MP_SLOPE))
    DEV_SLOPE[[p]]
  }
  cat(sprintf("BF1d  dev slopes: %s%s
",
              if (all(DEV_SLOPE == 1)) "all 1.000 (uniform swing)" else
                paste(sprintf("%s=%.3f", names(DEV_SLOPE), DEV_SLOPE), collapse=" "),
              if (length(attr(DEV_SLOPE, "absent")))
                paste0(" | not contested here: ",
                       paste(attr(DEV_SLOPE, "absent"), collapse=",")) else ""))
  parties <- colnames(mat); shares <- mat
  # Per-class national LEVEL rescale, so a class whose level was re-forecast
  # (AUSPOL_IND_SALIENCE) also reaches the seats where .own_x() substitutes a
  # returning candidate's OWN prior vote. Without this the uplift is applied
  # to mat[, p] and then discarded in exactly the sitting-independent seats it
  # exists to help -- which is why the harness gain (0.3588 -> 0.3567) was far
  # smaller than the same national level scored in isolation (-> 0.3259).
  lvl_scale <- stats::setNames(rep(1, length(parties)), parties)
  sw_draws <- NULL
  if (FORECAST_MODE) {
    ed <- as.Date(FED_DATE[[as.character(K$to)]])
    fr <- FUND_LOO[year == K$to & region == "fed", fund]
    if (length(fr) != 1L || !is.finite(fr)) {
      stop("No leave-one-out fundamentals prediction for fed", K$to,
           ". Anchoring to a projection built on this election's own result ",
           "would be the same leak as using its polls.")
    }
    # One day out. project_result() blends trend and fundamentals by horizon,
    # so the horizon must be the real one rather than a convenient default.
    tpp_fn <- function(trend_tpp) {
      pj <- project_result(trend_tpp, fr, .mix, horizon = 1L)
      list(mean = pj$mean, sd = pj$sd)
    }
    FC <- statewide_draws_as_at("fed", K$to, as_at = ed - 1, election_date = ed,
                                parties = parties, n_sims = N_SIMS, seed = SEED,
                                tpp_target = tpp_fn)
    if (is.null(FC)) {
      stop("No trend could be fitted for fed", K$to, " at ", as.character(ed - 1),
           ". A thin cycle must be reported, not silently scored as if the ",
           "forecast had succeeded.")
    }
    # A party under the poll-inclusion floor (no national series -- true for
    # IND always, since no pollster publishes an independent voting-intention
    # figure) has no forecast level OF ITS OWN, only inside the fitted OTH.
    # DELETING that party's column, as this used to do, does not just fold its
    # VOTE into OTH -- it removes the class from the simulation entirely, so
    # the model can never output "IND wins" for any seat, no matter how safe.
    # Measured: fed2025 forecast-mode log loss 1.2914, with 71.8% of it coming
    # from 10 sitting independent MPs (Ryan, Chaney, Daniel, Scamps, Tink,
    # Steggall, Spender, Wilkie, Haines, Katter) simply being re-elected and
    # scoring EXACTLY zero probability -- not unlikely, structurally
    # impossible, since IND was not a column to win.
    #
    # fit_seats_full.R (the PUBLISHED model) never had this bug: it RESCALES
    # an unmodelled class to the forecast's aggregate OTH total instead of
    # deleting it, keeping IND as its own simulateable column
    # (scripts/fit_seats_full.R:522-557). Ported here, so the backtest this
    # repo measures itself against AE Forecasts with is the same mechanism as
    # what actually ships.
    sw_draws <- FC$draws
    st_fc <- colMeans(sw_draws)
    unmodelled <- character(0)
    if (length(FC$folded) && "OTH" %in% parties) {
      unmodelled <- FC$folded
      bucket <- c(unmodelled, "OTH")
      base_share <- sum(st_a[unmodelled], st_a[["OTH"]], na.rm = TRUE)
      scale_to <- if (isTRUE(base_share > 0)) st_fc[["OTH"]] / base_share else 1
      ratio <- stats::setNames(
        if (isTRUE(base_share > 0)) unlist(st_a[bucket]) / base_share
        else rep(1 / length(bucket), length(bucket)),
        bucket)
      # EVERY DRAW, not just the point estimate. simulate_seat_contests()
      # requires statewide_draws to cover every column in `parties` or it
      # errors, so an unmodelled class needs its own draw column, not just a
      # target level. There is no genuine trend-model draw for it -- no
      # pollster publishes an independent series -- so each simulated OTH
      # draw is SPLIT by the PRIOR election's ratio within this bucket,
      # preserving that draw's total (the ratios sum to 1) and giving
      # IND/OTH_RIGHT variation correlated with, not independent of, OTH's
      # own uncertainty -- the most this data supports. oth_draw is already
      # on the CURRENT (forecast) scale, so it is split by ratio only, not
      # multiplied by scale_to again -- scale_to converts a PRIOR-election
      # level to a forecast one, and oth_draw already is one.
      oth_draw <- sw_draws[, "OTH"]
      new_cols <- matrix(0, nrow(sw_draws), length(unmodelled),
                         dimnames = list(NULL, unmodelled))
      for (p in unmodelled) new_cols[, p] <- oth_draw * ratio[[p]]
      sw_draws[, "OTH"] <- oth_draw * ratio[["OTH"]]
      sw_draws <- cbind(sw_draws, new_cols)
      # THE LEVEL, separately from the draws' spread. simulate_seat_contests()
      # centres statewide_draws on ITS OWN column means internally (each
      # draw's contribution is `draw - colMeans(draws)`), so the draws above
      # only need to supply a reasonable SHAPE of uncertainty -- the actual
      # level for dev_slope()'s `prev`/`level_now` is set explicitly here,
      # matching fit_seats_full.R's own choice for an unmodelled class: no
      # separately-implied statewide movement beyond the rescale itself,
      # i.e. level_prev == level_now (mirrors `tgt <- a22[[p]] * scale_to`
      # used for both arguments at fit_seats_full.R:550-551).
      # TREND DRIFT FOR AN UNMODELLED CLASS, off by default
      # (AUSPOL_IND_TREND=1). `scale_to` pins a folded class to the PRIOR
      # election's share of the minor bucket, so it can never GROW -- it only
      # moves with the bucket. Independents are not stationary: nationally
      # 2.22, 2.52, 1.40, 4.66, 3.70, 5.54, 7.52 across fed2007-2025, up in
      # five of the last six. In fed2025 they rose 5.54 -> 7.52 (+36%) while
      # this pinning forecast 5.23, i.e. 30% low, applied to every independent
      # in every seat -- and those are exactly the seats where this model
      # loses log loss to AE Forecasts.
      #
      # A linear trend fitted on the PRIOR elections only (never the target)
      # predicts 5.68 for 2025. That is short of the true 7.52 but well above
      # the pinned 5.23, and it uses nothing a forecaster lacks. Measured on
      # fed2025: 5.23 -> log 0.3587, trend 5.68 -> 0.3473, true 7.52 -> 0.3225.
      #
      # Fitted per class across every earlier election of this region, and
      # only applied when there are 4+ prior points and the fit is upward --
      # a downward extrapolation of a floor-bounded minor vote is not a
      # forecast, it is an artefact.
            # Classes whose level has already been set by the salience model below,
      # so the pinning loops afterwards must NOT scale them a second time.
      done_lvl <- character(0)
      # SALIENCE-PREDICTED NATIONAL LEVEL for a folded class, off by default
      # (AUSPOL_IND_SALIENCE=1). Scored against
      # docs/plans/prereg-nonmajor-bloc-level.md.
      #
      # `scale_to` pins a folded class to the PRIOR election's share of the
      # minor bucket, so it cannot grow. Independents went 5.54 -> 7.52
      # nationally in 2025 while this pinning said 5.23, and that error lands
      # on every independent in every seat.
      #
      # Predicts the class's national level from PRE-ELECTION observables:
      # seats contested (known at nomination close) and aggregate campaign
      # salience (output/salience-v6.csv). Fitted leave-one-election-out --
      # the target election never enters its own fit.
      #
      # IND ONLY, by refusal R3 of the pre-registration: the same model is
      # WORSE than predicting the mean for OTH_RIGHT (LOO RMSE 2.358 vs
      # 2.108), which is the class a naive trend already broke. Measured LOO
      # RMSE: IND 0.426 against a 1.977 mean-baseline and 1.136 for a
      # year-only model, so it is not merely a time trend (refusal R1).
      #
      # fed2025 seat log loss: pinned 0.3516 -> predicted 0.3259, accuracy
      # 84.7% -> 86.7%.
      if (identical(Sys.getenv("AUSPOL_IND_SALIENCE", "0"), "1")) {
        SAL_F <- file.path("output", "salience-v6.csv")
        if (file.exists(SAL_F)) {
          SV <- fread(SAL_F, showProgress = FALSE)
          SV[, yr := suppressWarnings(as.integer(sub("^[a-z]+", "", election)))]
          # FIT ON THE BASIS THE SALIENCE CORPUS USES, then apply as a RATIO.
          # output/candidacies.csv and aec-fed-firstprefs.csv DISAGREE about
          # which candidates are independents: the Nick Xenophon Team is IND
          # in the first and not the second, which alone is the whole 2016
          # gap (2.81 vs 4.66, and NXT was 1.85% of the national vote).
          # salience-v6.csv inherits candidacies.csv's classification, so
          # fitting its salience against FP's levels mixes two definitions.
          # Fitting on candidacies and applying the predicted-to-pinned RATIO
          # keeps the units consistent and is invariant to which basis the
          # harness itself uses. The classification split is a real defect in
          # its own right and is NOT fixed here.
          CB <- tryCatch(fread("output/candidacies.csv", showProgress = FALSE),
                         error = function(e) NULL)
          if (is.null(CB)) CB <- FP[, .(year = NA_integer_)][0]
          natl <- CB[region == "fed", .(v = sum(votes)), by = .(yr = year, party)]
          natl[, lvl := 100 * v / sum(v), by = yr]
          nsts <- CB[region == "fed", .(n_seats = uniqueN(seat)), by = .(yr = year, party)]
          sj <- SV[grepl("^fed", election), .(sum_jump = sum(jump, na.rm = TRUE)),
                   by = .(yr, party)]
          for (p in intersect(unmodelled, "IND")) {
            Dd <- merge(merge(natl[party == p, .(yr, lvl)],
                              nsts[party == p, .(yr, n_seats)], by = "yr"),
                        sj[party == p, .(yr, sum_jump)], by = "yr")
            tr <- Dd[yr != K$to]
            te <- Dd[yr == K$to]
            prev_lvl <- Dd[yr == K$from, lvl]
            if (nrow(tr) >= 5L && nrow(te) == 1L && length(prev_lvl) == 1L) {
              fit <- stats::lm(lvl ~ n_seats + sum_jump, data = tr)
              pred_cb <- unname(stats::predict(fit, te))
              # RATIO against what pinning would say ON THE SAME BASIS.
              pinned_cb <- prev_lvl * scale_to
              ratio <- if (is.finite(pinned_cb) && pinned_cb > 0) pred_cb / pinned_cb else NA_real_
              cur <- st_a[[p]] * scale_to
              pred <- cur * ratio
              # R5: refuse a downward correction to a floor-bounded minor vote.
              if (is.finite(pred) && pred > cur) {
                cat(sprintf("BF0s fed%d %s: pinned %.2f -> salience-predicted %.2f (ratio %.3f, LOO on %d elections)
",
                            K$to, p, cur, pred, ratio, nrow(tr)))
                sp <- pred / st_a[[p]]
                mat[, p] <- mat[, p] * sp; st_a[[p]] <- st_a[[p]] * sp
                # AND THE DRAWS. sw_draws[, p] was built as oth_draw * the
                # PRIOR election's ratio, so without this the point estimate
                # moves to the re-forecast level while its uncertainty stays
                # scaled to the pinned one -- the same class described two
                # different ways in the same object.
                # OWN UNCERTAINTY, not OTH's. sw_draws[, p] is built as
                # oth_draw * ratio, i.e. a deterministic multiple of OTH --
                # so a class re-forecast by a DIFFERENT model still carried
                # OTH's poll spread, perfectly correlated, and none of its
                # own. The salience model's error is measured (leave-one-
                # election-out RMSE, computed here from the same fit), so use
                # that, centred on the prediction. Falls back to the old
                # rescale if the LOO residuals cannot be formed.
                if (p %in% colnames(sw_draws)) {
                  loo_res <- tryCatch(sapply(tr$yr, function(yy) {
                    f2 <- stats::lm(lvl ~ n_seats + sum_jump, data = tr[yr != yy])
                    unname(stats::predict(f2, tr[yr == yy])) - tr[yr == yy, lvl]
                  }), error = function(e) NULL)
                  sd_lvl <- if (!is.null(loo_res) && length(loo_res) >= 3L &&
                                is.finite(stats::sd(loo_res)))
                    sqrt(mean(loo_res^2)) else NA_real_
                  if (is.finite(sd_lvl) && sd_lvl > 0) {
                    cat(sprintf("BF0s fed%d %s: statewide draws from the level model's own LOO RMSE %.3f (was OTH-locked)
",
                                K$to, p, sd_lvl))
                    sw_draws[, p] <- pmax(0, stats::rnorm(nrow(sw_draws), pred, sd_lvl))
                  } else {
                    sw_draws[, p] <- sw_draws[, p] * sp
                  }
                }
                if (p %in% names(lvl_scale)) lvl_scale[[p]] <- sp
                done_lvl <- c(done_lvl, p)
              }
            }
          }
        }
      }
      if (identical(Sys.getenv("AUSPOL_IND_TREND", "0"), "1")) {
        for (p in setdiff(unmodelled, done_lvl)) {
          hist <- FP[election != eb & party == p,
                     .(v = sum(votes)), by = election]
          tot <- FP[election != eb, .(tv = sum(votes)), by = election]
          h <- merge(hist, tot, by = "election")[, pct := 100 * v / tv]
          h[, yr := as.integer(sub("^[a-z]+", "", election))]
          h <- h[yr < K$to][order(yr)]
          if (nrow(h) >= 4L) {
            fit <- stats::lm(pct ~ yr, data = h)
            pred <- unname(stats::predict(fit, data.frame(yr = K$to)))
            cur <- st_a[[p]] * scale_to
            if (is.finite(pred) && pred > cur) {
              cat(sprintf("BF0t fed%d %s: pinned %.2f -> trend %.2f (%d prior elections)
",
                          K$to, p, cur, pred, nrow(h)))
              scale_p <- pred / st_a[[p]]
              mat[, p] <- mat[, p] * scale_p; st_a[[p]] <- st_a[[p]] * scale_p
              next
            }
          }
          mat[, p] <- mat[, p] * scale_to; st_a[[p]] <- st_a[[p]] * scale_to
        }
      } else {
      for (p in setdiff(unmodelled, done_lvl)) { mat[, p] <- mat[, p] * scale_to; st_a[[p]] <- st_a[[p]] * scale_to }
      }
      st_a[["OTH"]] <- st_a[["OTH"]] * scale_to
      for (p in bucket) st_fc[[p]] <- st_a[[p]]
      cat(sprintf("BF0  fed%d minor field scaled x%.2f: %s at prior %.1f%% -> forecast %.1f%%\n",
                  K$to, scale_to, paste(bucket, collapse = "+"),
                  base_share, st_a[["OTH"]] + sum(unlist(st_a[unmodelled]))))
    }
    # F4: folded parties are REPORTED, never silently absorbed.
    cat(sprintf("BF0  fed%d forecast mode: %d polls to %s; folded into OTH: %s\n",
                K$to, FC$n_polls, as.character(ed - 1),
                if (length(FC$folded)) paste(FC$folded, collapse = ", ") else "none"))
    cat(sprintf("BF0  trend TPP %.2f, fundamentals (LOO) %.2f, projection %.2f, draws realise %.2f\n",
                FC$tpp, fr, FC$anchor$mean, FC$implied_tpp))
  # FLOW AS A FUNCTION OF THE PARTY'S OWN PRIMARY, off by default
  # (AUSPOL_FLOW_ON_PRIMARY=1). Pete's idea, and the measurements back it.
  #
  # Flows are taken as constants from the prior election, but One Nation's
  # share to the Coalition has moved with its own vote:
  #
  #   ONP primary  0.26  0.22  0.17  1.29  3.08  4.96  6.41
  #   ONP -> LNP   28.3  33.9  22.5  47.4  60.4  47.6  61.6
  #
  # Fitted on pre-2025 elections ONLY: slope +5.31 per point of primary
  # (t = 2.17, R2 0.54), predicting 65.2% for 2025 against an actual 61.6%
  # and the 47.6% a fed2022-constant gives. Leave-one-out over all seven
  # elections, RMSE 10.6 points against 14.8 for "carry the last election
  # forward" -- so this is better out of sample, not just on the target.
  #
  # Uses the FORECAST primary (st_fc), never the realised one, so nothing
  # from the election being predicted enters. The fit excludes the target
  # election explicitly.
  if (identical(Sys.getenv("AUSPOL_FLOW_ON_PRIMARY", "0"), "1")) {
    .yp <- function(e) suppressWarnings(as.integer(sub("^[a-z]+", "", e)))
    flh <- TX[, .(v = sum(votes)), by = .(election, from, to)]
    flh[, pct := 100 * v / sum(v), by = .(election, from)]
    flh[, yr := .yp(election)]
    CBp <- fread("output/candidacies.csv", showProgress = FALSE)
    prm <- CBp[region == "fed", .(v = sum(votes)), by = .(yr = year, party)]
    prm[, pr := 100 * v / sum(v), by = yr]
    adj_pairs <- list(c("ONP", "LNP"))
    for (ap in adj_pairs) {
      fc <- ap[1]; tc <- ap[2]
      Dp <- merge(flh[from == fc & to == tc, .(yr, flow = pct)],
                  prm[party == fc, .(yr, pr)], by = "yr")
      Dp <- Dp[yr < K$to]
      fcast <- if (fc %in% names(st_fc)) st_fc[[fc]] else NA_real_
      if (nrow(Dp) >= 5L && is.finite(fcast)) {
        ff <- stats::lm(flow ~ pr, data = Dp)
        tgt <- unname(stats::predict(ff, data.frame(pr = fcast)))
        tgt <- max(5, min(90, tgt))
        cur <- Dp[which.max(yr), flow]
        cat(sprintf("BF0p %s->%s: flow %.1f -> %.1f (forecast %s primary %.2f, fit on %d prior elections)
",
                    fc, tc, cur, tgt, fc, fcast, nrow(Dp)))
        rescale_row <- function(r) {
          if (is.null(r) || !(tc %in% names(r)) || sum(r) <= 0) return(r)
          rr <- 100 * r / sum(r)
          othr <- setdiff(names(rr), tc)
          rem <- 100 - tgt
          if (sum(rr[othr]) > 0) rr[othr] <- rr[othr] * rem / sum(rr[othr])
          rr[tc] <- tgt
          rr
        }
        for (nm in names(fm$conditional))
          if (sub("[|].*$", "", nm) == fc) fm$conditional[[nm]] <- rescale_row(fm$conditional[[nm]])
        if (!is.null(fm$superset)) for (nm in names(fm$superset))
          if (sub("[|].*$", "", nm) == fc) fm$superset[[nm]] <- rescale_row(fm$superset[[nm]])
        if (!is.null(fm$pooled[[fc]]))   fm$pooled[[fc]]   <- rescale_row(fm$pooled[[fc]])
        if (!is.null(fm$pairwise[[fc]])) fm$pairwise[[fc]] <- rescale_row(fm$pairwise[[fc]])
      }
    }
  }


    for (p in parties) {
      prev <- if (p %in% names(st_a)) st_a[[p]] else 0
      .sl <- .fed_slope(p, rownames(mat), .cond, .screened, .returns, .permit)
      .s_p <- if (p %in% names(lvl_scale)) lvl_scale[[p]] else 1
      shares[, p] <- dev_slope(.own_x(p, rownames(mat), mat[, p] / .s_p) * .s_p,
                               prev, st_fc[[p]], .sl)
    }
  } else {
    for (p in parties) if (p %in% names(st_b) && p %in% names(st_a)) {
      .sl <- .fed_slope(p, rownames(mat), .cond, .screened, .returns, .permit)
      .s_p <- if (p %in% names(lvl_scale)) lvl_scale[[p]] else 1
      shares[, p] <- dev_slope(.own_x(p, rownames(mat), mat[, p] / .s_p) * .s_p,
                               st_a[[p]], st_b[[p]], .sl)
    }
  }
  # Zero IND wherever nobody actually stood at the TARGET election. This is
  # nomination data, not the result being predicted: which classes contest a
  # seat is knowable from the ballot before polling day (nominations close
  # weeks in advance), unlike the vote SHARE those classes go on to get, which
  # stays the forecast's job. Without this, the model swings the PRIOR
  # election's independent vote forward with no check that anyone
  # recontested: Nicholls fed2025 carried 19.5% IND win probability for a
  # class that was not on the ballot, Hughes 8.2%.
  #
  # !FORECAST_MODE ONLY -- see the file banner. There is no real pre-election
  # nomination list here, only "IND has a nonzero vote in `fb`" as a proxy for
  # it, and `fb` is the target election's own result. That is an accepted
  # oracle input in the default path (which already reads `st_b` the same
  # way) but is exactly what FORECAST_MODE exists to avoid.
  if (!FORECAST_MODE && "IND" %in% colnames(shares)) {
    ind_seats <- fb[party == "IND" & votes > 0, unique(seat)]
    no_ind <- setdiff(rownames(shares), ind_seats)
    zeroed <- no_ind[shares[no_ind, "IND"] > 0]
    shares[no_ind, "IND"] <- 0
    if (length(zeroed)) {
      cat(sprintf("BF0  fed%d: zeroed IND in %d seat(s) with no independent nominated: %s\n",
                  K$to, length(zeroed), paste(sort(zeroed), collapse = ", ")))
    }
  }
  shares <- 100 * shares / rowSums(shares)
  keep <- intersect(rownames(shares), win$seat)
  shares <- shares[keep, , drop = FALSE]
  truth <- setNames(win$winner, win$seat)[keep]

  # DIAGNOSTIC DUMP: the POINT ESTIMATE (before any Monte Carlo/surge draw)
  # that actually feeds simulate_seat_contests(), so it can be compared
  # directly against salience jump and the actual result. AUSPOL_DUMP_SHARES=1.
  if (identical(Sys.getenv("AUSPOL_DUMP_SHARES", "0"), "1")) {
    sdt <- data.table::as.data.table(shares, keep.rownames = "seat")
    sdt <- data.table::melt(sdt, id.vars = "seat", variable.name = "party", value.name = "projected_share")
    sdt[, election := paste0("fed", K$to)]
    dump_f <- sprintf("output/dump-shares-fed%d.csv", K$to)
    data.table::fwrite(sdt, dump_f)
    cat(sprintf("DUMP wrote %s: %d rows\n", dump_f, nrow(sdt)))
  }

  cat(sprintf("\nBF1  federal %d -> %d: %d divisions scored\n",
              K$from, K$to, length(keep)))
  dropped <- setdiff(win$seat, rownames(mat))
  if (length(dropped)) {
    cat(sprintf("BF1  %d divisions have no %d baseline and are not scored: %s\n",
                length(dropped), K$from, paste(sort(dropped), collapse = ", ")))
  }
  # Redistributions rename and create divisions every cycle -- eight appeared
  # between 2016 and 2019 alone. A floor well below the chamber size allows for
  # that; falling under it means the NAMES stopped matching, not that the
  # chamber changed.
  if (length(keep) < 110L) {
    stop("Only ", length(keep), " divisions could be scored for ", eb,
         ". Redistribution churn has never exceeded a handful, so this means ",
         "the division names stopped matching.")
  }

  sd_w <- spread_for(K$to, unname(st_b[["ALP"]] - st_a[["ALP"]]))
  seat_sds <- c(seat_sds, sd_w)
  out_all[[length(out_all) + 1L]] <- list(K = K, shares = shares, fm = fm,
                                          truth = truth, keep = keep,
                                          parties = parties, sd_w = sd_w,
                                          sw_draws = sw_draws)
}

fallback <- stats::median(seat_sds, na.rm = TRUE)
if (!is.finite(fallback)) {
  stop("No federal seat file yielded a within-region seat-swing spread, so ",
       "there is no measured value to fall back on and one would have to be ",
       "invented here.")
}
cat(sprintf("\nBF2  seat_sd per pair: %s | fallback (median) %.3f\n",
            paste(sprintf("%.2f", seat_sds), collapse = ", "), fallback))

res_all <- list(); tot_all <- list()
for (X in out_all) {
  K <- X$K
  sd_w <- if (is.finite(X$sd_w)) X$sd_w else fallback
  # STATEWIDE UNCERTAINTY, MEASURED. All four harnesses hardcoded 1.5 with no
  # derivation. The realised statewide first-preference error over 139
  # party-cycles (33 independent cycles) is sd 2.33, so the harnesses were 1.6x
  # over-confident BEFORE any seat-level modelling. That is upstream of `shrink`,
  # which is a post-hoc patch for uncertainty that should have been present.
  # fit_seats_full.R already uses a per-party state_sd and falls back to 1.5 only
  # when it is NA. See docs/plans/prereg-party-sd-from-data.md.
  PARTY_SD <- as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5"))
  psd <- setNames(rep(PARTY_SD, length(X$parties)), X$parties)
  cat(sprintf("BS1p party_sd %.2f (realised statewide sd is 2.33)
", PARTY_SD))
  # PER-SEAT SHRINK, against docs/plans/prereg-insurgency-conditional-shrink.md.
  # A flat SHRINK caps every seat at 1 - SHRINK/2, charging 672 seats whose
  # measured non-major win rate is under 1.5% for a risk carried by a few dozen.
  # The risk comes from scripts/fit_insurgency_risk.R, fitted LEAVE-ONE-
  # ELECTION-OUT, so the fold being scored here never contributed to it.
  shrink_arg <- SHRINK
  if (identical(Sys.getenv("AUSPOL_INSURGENCY_SHRINK", "0"), "1")) {
    if (!file.exists(RISK_FILE))
      stop("AUSPOL_INSURGENCY_SHRINK=1 but ", RISK_FILE,
           " is missing; run scripts/fit_insurgency_risk.R")
    # X$K$to is the bare year (2010); the risk file keys on "fed2010".
    want <- paste0("fed", X$K$to)
    rk <- RISK[pair == want]
    if (!nrow(rk))
      stop("no insurgency risk rows for ", want, "; risk file has: ",
           paste(sort(unique(RISK$pair)), collapse = ", "))
    sn <- rownames(X$shares)
    if (is.null(sn) && is.data.frame(X$shares)) sn <- as.character(X$shares$seat)
    miss <- setdiff(sn, rk$seat)
    # A silent recycle here would give the wrong seat's ceiling to the wrong
    # seat and nothing downstream would show it, so this aborts rather than
    # falling back to the flat rate.
    if (length(miss))
      stop(want, ": insurgency risk missing for ", length(miss), " seat(s): ",
           paste(utils::head(miss, 5), collapse = ", "))
    shrink_arg <- setNames(rk$shrink_i, rk$seat)[sn]
    cat(sprintf("BF2i %s per-seat shrink: median %.3f | mean %.3f | max %.3f | seats above the flat %.2f: %d\n",
                want, median(shrink_arg), mean(shrink_arg), max(shrink_arg),
                SHRINK, sum(shrink_arg > SHRINK)))
    cat(sprintf("BF2i %s seats whose ceiling now exceeds 0.99: %d of %d\n",
                want, sum(shrink_arg < 0.02), length(shrink_arg)))
  }
  # Resolve the per-seat hazard. Seats absent from the salience table keep the
  # flat SURGE_H, and a missing seat is REPORTED -- a silent fallback to the flat
  # rate would make a partial salience corpus look like a complete one.
  surge_arg <- SURGE_H
  surge_mu_arg <- 15.6; surge_sd_arg <- 6.1
  if (SURGE_V2) {
    target_el <- paste0("fed", X$K$to)
    train_pairs <- Filter(function(p) p$election != target_el, SURGE_V2_PAIRS)
    hz <- tryCatch(
      surge_hazard_for(target_el, paste0("fed", X$K$from), "fed", train_pairs),
      error = function(e) { cat(sprintf("BF0v! surge-v2 failed for %s: %s\n", target_el, conditionMessage(e))); NULL })
    if (!is.null(hz)) {
      sn <- rownames(X$shares)
      if (is.null(sn) && is.data.frame(X$shares)) sn <- as.character(X$shares$seat)
      v <- setNames(hz$seat_hazard$surge_h, hz$seat_hazard$seat)[sn]
      miss <- sum(is.na(v))
      v[is.na(v)] <- 0
      surge_arg <- unname(v)
      surge_mu_arg <- hz$surge_mu; surge_sd_arg <- hz$surge_sd
      cat(sprintf("BF0v %s: surge-v2 hazard for %d of %d seats (%d absent -> 0) | mean %.4f | mu %.2f sd %.2f | lambda %.1f | train winners %d\n",
                  target_el, length(sn) - miss, length(sn), miss, mean(surge_arg),
                  surge_mu_arg, surge_sd_arg, hz$lambda, hz$n_train_winners))
      # THE POINT ESTIMATE ITSELF, not just the simulated tail. surge_h above
      # only widens the Monte Carlo draw -- the deterministic estimate that
      # feeds it (dev_slope()'s output) was otherwise blind to salience
      # entirely (correlation(jump, projected share) measured at 0.050 on
      # fed2022 -- essentially zero). Governed winners with real salience were
      # projected at 7-37% of their actual result: Zoe Daniel 3.2% projected
      # vs 34.5% actual. Blend toward surge_mu using the SAME p_hat already
      # fitted for the hazard, landed on the right (seat, party) column via
      # seat_party_hazard rather than the party-collapsed seat_hazard.
      for (pp in unique(hz$seat_party_hazard$party)) {
        if (!pp %in% colnames(X$shares)) next
        ph <- hz$seat_party_hazard[hz$seat_party_hazard$party == pp]
        w <- setNames(ph$p_hat, ph$seat)[sn]
        w[is.na(w)] <- 0
        X$shares[, pp] <- surge_blend_estimate(X$shares[, pp], unname(w), surge_mu_arg)
      }
      X$shares <- 100 * X$shares / rowSums(X$shares)
      cat(sprintf("BF0v %s: point estimate blended toward surge_mu for %d (seat,party) cells\n",
                  target_el, sum(hz$seat_party_hazard$p_hat > 0.001)))
      if (identical(Sys.getenv("AUSPOL_DUMP_SHARES", "0"), "1")) {
        sdt <- data.table::as.data.table(X$shares, keep.rownames = "seat")
        sdt <- data.table::melt(sdt, id.vars = "seat", variable.name = "party", value.name = "projected_share")
        sdt[, election := target_el]
        dump_f <- sprintf("output/dump-shares-blended-%s.csv", target_el)
        data.table::fwrite(sdt, dump_f)
        cat(sprintf("DUMP wrote %s: %d rows\n", dump_f, nrow(sdt)))
      }
    }
  } else if (!is.null(SALIENCE_HAZ)) {
    sn <- rownames(X$shares)
    if (is.null(sn) && is.data.frame(X$shares)) sn <- as.character(X$shares$seat)
    h <- SALIENCE_HAZ[election == paste0("fed", X$K$to)]
    v <- setNames(h$surge_h, h$seat)[sn]
    miss <- sum(is.na(v))
    v[is.na(v)] <- SURGE_H
    surge_arg <- unname(v)
    cat(sprintf("BF0h fed%d: salience hazard for %d of %d seats (%d fell back to %.4f) | mean %.4f
",
                X$K$to, length(sn) - miss, length(sn), miss, SURGE_H, mean(surge_arg)))
  }
  set.seed(SEED)
  sim <- simulate_seat_contests(level_sd = .level_sd, level_mult = .lm(X$shares), X$shares, X$fm, party_sd = psd, seat_sd = sd_w * SEAT_SD_MULT,
                                n_sims = N_SIMS, smooth = SMOOTH, seed = SEED,
                                shrink = shrink_arg, surge_h = surge_arg,
                                surge_mu = surge_mu_arg, surge_sd = surge_sd_arg,
                                party_cor = PARTY_COR, statewide_draws = X$sw_draws,
                                fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD)
  wp <- as.data.table(sim$win_prob)

  pa <- merge(data.table(seat = X$keep, actual = unname(X$truth)),
              wp[, .(seat, party, prob)],
              by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]
  pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
  res <- merge(pa, pr, by = "seat")
  stopifnot(nrow(res) == length(X$keep))
  res[, pair := sprintf("fed%d", K$to)]

  z <- data.frame(y = as.integer(res$pred == res$actual),
                  lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
  cat(sprintf("BF3  fed%d: accuracy %d/%d (%.1f%%) | Brier %.4f | log %.4f | slope %.3f%s\n",
              K$to, sum(res$pred == res$actual), nrow(res),
              100 * mean(res$pred == res$actual), mean((1 - res$prob)^2),
              -mean(log(pmax(res$prob, eps))), sl,
              if (is.finite(X$sd_w)) "" else "  [seat_sd fallback]"))
  # Seat TOTALS, not just per-seat probabilities. A covariance between
  # parties' statewide votes moves the joint distribution far more than any
  # single seat's marginal, so the criterion in
  # docs/plans/prereg-statewide-covariance.md is the total and it needs the
  # simulation's own totals matrix.
  tot_all[[length(tot_all) + 1L]] <- data.table::data.table(
    pair = sprintf("fed%d", K$to), as.data.table(sim$totals))
  res_all[[length(res_all) + 1L]] <- res
}

R <- rbindlist(res_all)
cat(sprintf("\nBF4  pooled over %d division-elections across %d elections: accuracy %.1f%%, Brier %.4f\n",
            nrow(R), uniqueN(R$pair), 100 * mean(R$pred == R$actual),
            mean((1 - R$prob)^2)))
cat("BF4  for comparison the two state backtests together hold 166 seats and 2 elections.\n")
per <- R[, .(n = .N, accuracy = round(100 * mean(pred == actual), 1),
             brier = round(mean((1 - prob)^2), 4)), by = pair]
print(per)
fwrite(R, file.path("output", sprintf("backtest-fed%s.csv", CAL_TAG)))
fwrite(rbindlist(tot_all, fill = TRUE), file.path("output", sprintf("backtest-fed-totals%s.csv", CAL_TAG)))
cat(sprintf("BF5  wrote output/backtest-fed%s.csv and its totals\n", CAL_TAG))
