# Two independent estimates of how much a STATE will swing differently from the
# nation at a federal election, as per-seat features.
#
# Pete, 2026-09-12: "could use both and let the xgboost decide the value of
# each?" -- yes, and for a reason that distinguishes this from the five features
# that failed earlier today. Those added correlated signal to a feature set that
# already covered the ground. This adds a dimension the model has NOTHING for:
# `level_pred` carries a single NATIONAL figure and the harness distributes it
# uniformly, so no feature can express "Western Australia is moving differently
# from Australia".
#
# THE MISS THAT MOTIVATED IT. fed2022 missed Hasluck by 11.4 points and Tangney
# by 12.9 on the Labor primary. WA swung +10.55 two-party against a national
# +3.66 -- and both files below saw it coming.
#
# FEATURE 1, state_poll_dev -- contemporaneous.
#   external/.../region-polls-fed.csv carries STATE-LEVEL federal poll readings
#   for 2007-2022. WA 2022 reads: previous 44.45, polls 53/55/54/53/53/47,
#   actual 55.00. Measured across 30 state-elections: r = +0.582, slope +0.379
#   (se 0.100, t = 3.79), R2 0.339.
#
# FEATURE 2, state_elec_dev -- prior mood.
#   The most recent STATE election before federal polling day, from our own
#   candidate corpus. Stronger per observation but far thinner: r = +0.769 on
#   n = 10, and only where a state election falls inside 24 months. Beyond that
#   window it is noise (r = -0.243), which is why the window exists.
#
# They disagree usefully. For WA 2022 the polls implied +3.5 and the state
# election implied +5.2, against an actual +6.9 -- both under-call, from
# different directions, and the model can weigh them.
#
# BOTH ARE TWO-PARTY QUANTITIES and the model works in PRIMARY shares, so a
# conversion factor is fitted here rather than assumed.
#
# NO LEAKAGE: every input strictly precedes its federal polling day, and both
# slopes are refitted per target election with that election excluded.
#
# Non-federal pairs get 0 -- a state election IS one state, so the concept does
# not apply. The model can learn that.
#
# Emits SD* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
ANCHOR <- "external/aus-polling-analyser/analysis/Data"
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)

# ---- national and per-state two-party results, back to 1980 ----------------
T <- fread(file.path(ANCHOR, "tpp-fed-regions.csv"), header = FALSE,
           col.names = c("year", "lvl", "state", "tpp", "swing"))
natl <- T[T$state == "all", .(year, natl_tpp = tpp, natl_swing = swing)]
ST <- merge(T[T$state != "all"], natl, by = "year")
ST[, actual_dev := swing - natl_swing]
cat(sprintf("SD1  tpp-fed-regions: %d state-years, %d federal elections (%d-%d)\n",
            nrow(ST), uniqueN(ST$year), min(ST$year), max(ST$year)))

# ---- feature 1: state-level federal polls ---------------------------------
raw <- readLines(file.path(ANCHOR, "region-polls-fed.csv"), warn = FALSE)
raw <- raw[nzchar(trimws(raw))]
RP <- rbindlist(lapply(raw, function(l) {
  x <- strsplit(l, ",")[[1]]
  if (length(x) < 7) return(NULL)
  polls <- suppressWarnings(as.numeric(x[8:length(x)]))
  data.table(year = as.integer(x[1]), state = x[3],
             prev_tpp = as.numeric(x[4]), agg = as.numeric(x[7]),
             n_polls = sum(is.finite(polls)))
}))
# ---- 2025 onward: Newspoll quarterly state breakdowns ----------------------
# The anchor's region-polls-fed.csv stops at 2022, so every fed2025 state read
# 0. external/reference/polls/newspoll-quarterly/breakdowns.csv carries the
# state two-party from each quarterly release (scripts/fetch_poll_breakdowns.R).
# For a federal election with no anchor rows: the aggregate is the latest
# Newspoll release ending before polling day, every pre-election release in
# the year before counts toward n_polls, and prev_tpp is the state's result
# at the previous federal election.
NQ_F <- "external/reference/polls/newspoll-quarterly/breakdowns.csv"
fed_dates <- election_dates()[grepl("^fed", names(election_dates()))]
if (file.exists(NQ_F)) {
  NQ <- fread(NQ_F, showProgress = FALSE)[dimension == "state" & party == "ALP" & is.finite(tpp_alp)]
  for (el in names(fed_dates)) {
    y <- as.integer(sub("^fed", "", el)); ed <- as.Date(fed_dates[[el]])
    if (y %in% RP$year) next
    q <- NQ[as.Date(period_end) < ed & as.Date(period_end) >= ed - 365]
    if (!nrow(q)) next
    py <- max(T$year[T$year < y])
    prv <- T[T$year == py & T$state != "all", .(state = tolower(state), prev_tpp = tpp)]
    lat <- q[pollster == "Newspoll"][as.Date(period_end) == max(as.Date(period_end))]
    add <- merge(lat[, .(state = tolower(group), agg = tpp_alp)],
                 q[, .(n_polls = .N), by = .(state = tolower(group))], by = "state")
    add <- merge(add, prv, by = "state")
    add[, year := y]
    RP <- rbind(RP, add[, .(year, state, prev_tpp, agg, n_polls)], fill = TRUE)
    cat(sprintf("SD2b %s: %d state rows from Newspoll quarterly (latest release ending %s): %s\n", el, nrow(add),
                max(as.Date(lat$period_end)), paste(sprintf("%s %s", add$state, add$agg), collapse = ", ")))
  }
}

# ---- every pollster's state crosstabs (AUSPOL_STATE_POLL_EXTRA=1) ---------
# Pete, 2026-10-02: "surely we have state level polling for all the federal
# polls as well? usually most of them have state level crosstabs?" -- the
# anchor and Newspoll quarterly cover the five mainland states only, so
# Tasmania read 0 in every federal election.
# external/reference/polls/state-federal/state-federal-polls.csv (1,095 rows,
# Wikipedia state-breakdown tables, Roy Morgan, Resolve, YouGov, RedBridge,
# DemosAU, ...). Rule, fixed before running
# (plans/prereg-state-polls-extra-2026-10-02.md): for each federal election
# and state, readings with a two-party figure and fieldwork ending in the 90
# days before polling day. A state-year the existing sources lack is ADDED; a
# state-year that only Newspoll quarterly covers (2025 onward) is REPLACED by
# the mean over every pollster. Anchor years (2007-2022) keep the anchor's own
# aggregate. prev_tpp as for Newspoll: the state's previous federal result.
XP_F <- "external/reference/polls/state-federal/state-federal-polls.csv"
xp_years <- integer(0)
if (Sys.getenv("AUSPOL_STATE_POLL_EXTRA", "0") %in% c("1", "2")) {
  if (!file.exists(XP_F)) stop("SD2d! AUSPOL_STATE_POLL_EXTRA=1 but ", XP_F, " is missing")
  XP <- fread(XP_F, showProgress = FALSE)
  XP <- XP[XP$scope == "state" & is.finite(suppressWarnings(as.numeric(XP$alp_tpp)))]
  XP[, alp_tpp := as.numeric(alp_tpp)]
  anchor_years <- unique(as.integer(substr(raw, 1, 4)))
  for (el in names(fed_dates)) {
    y <- as.integer(sub("^fed", "", el)); ed <- as.Date(fed_dates[[el]])
    .el <- el
    q <- XP[XP$election == .el & as.Date(XP$fieldwork_end) < ed & as.Date(XP$fieldwork_end) >= ed - 90]
    if (!nrow(q)) next
    agg_x <- q[, list(agg_x = mean(alp_tpp), n_x = .N), by = list(state = tolower(state))]
    py <- max(T$year[T$year < y])
    prv <- T[T$year == py & T$state != "all", list(state = tolower(state), prev_tpp = tpp)]
    for (j in seq_len(nrow(agg_x))) {
      st_j <- agg_x$state[j]
      have <- which(RP$year == y & RP$state == st_j)
      if (length(have) && y %in% anchor_years) next
      pv <- prv$prev_tpp[match(st_j, prv$state)]
      if (!is.finite(pv)) { cat(sprintf("SD2d! %s %s: no previous result, skipped
", el, st_j)); next }
      if (length(have)) RP <- RP[-have]
      RP <- rbind(RP, data.table(year = y, state = st_j, prev_tpp = pv, agg = agg_x$agg_x[j], n_polls = agg_x$n_x[j]), fill = TRUE)
      xp_years <- union(xp_years, y)
      cat(sprintf("SD2d %s %s: %s from %d crosstab readings, mean ALP two-party %.2f
", el, st_j,
                  if (length(have)) "REPLACED" else "ADDED", agg_x$n_x[j], agg_x$agg_x[j]))
    }
  }
}

# ---- the NATIONAL reference: POLLS, not the result -------------------------
# Until 2026-09-28 this subtracted `natl_swing` from tpp-fed-regions.csv, the
# ACTUAL national swing at the election being predicted -- so the feature was
# the state-vs-nation poll difference PLUS that election's national polling
# error, known only after the count (a leak in every federal backtest;
# docs/plans/prereg-state-dev-leak-fix-2026-09-28.md). The reference is now the
# federal trend's two-party the day before polling day, minus the previous
# election's actual national two-party, both knowable in advance.
# AUSPOL_STATE_POLL_NATL=actual rebuilds the old feature, for comparison only.
NATL_MODE <- Sys.getenv("AUSPOL_STATE_POLL_NATL", "polls")
natl_poll <- rbindlist(lapply(sort(unique(RP$year)), function(y) {
  el <- paste0("fed", y); ed <- as.Date(fed_dates[el])
  if (is.na(ed)) return(NULL)
  prev_nat <- T[T$state == "all" & T$year == max(T$year[T$year < y]), tpp]
  cycles <- load_election_cycles(); polls <- load_polls("fed")
  pri <- load_prior_results(); kp <- pri$region == "fed" & pri$year == y
  priors <- stats::setNames(pri$prev1[which(kp)], pri$party[which(kp)])
  cyc <- cycles[cycles$region == "fed" & cycles$year == y, ]
  fl <- flows_for(load_preference_flows(), y, "fed", as_of = if (nrow(cyc)) min(cyc$start) else ed - 1,
                  cycles = cycles, quiet = TRUE)
  tr <- tryCatch(suppressMessages(trend_as_at(polls, y, cycles, ed - 1, priors, fl)), error = function(e) NULL)
  if (is.null(tr)) return(data.table(year = y, natl_poll_swing = NA_real_))
  cp <- cycle_polls(polls, y, cycles)
  # the trend's OWN poll count against an independent count of polls dated
  # before polling day (re-applying trend_as_at()'s filter could never fire)
  if (tr$n_polls > sum(cp$date <= ed - 1)) stop("SD2c! a poll on or after polling day reached fed", y)
  data.table(year = y, natl_poll_tpp = tr$tpp, natl_prev_tpp = prev_nat, natl_poll_swing = tr$tpp - prev_nat)
}), fill = TRUE)
RP <- merge(RP, natl, by = "year", all.x = TRUE)
RP <- merge(RP, natl_poll, by = "year", all.x = TRUE)
RP[, poll_dev_actual := (agg - prev_tpp) - natl_swing]
RP[, poll_dev := if (NATL_MODE == "actual") poll_dev_actual else (agg - prev_tpp) - natl_poll_swing]
cat(sprintf("SD2c national reference: %s. Per election, polled national swing vs actual (the error the old feature carried):\n", NATL_MODE))
print(unique(RP[, .(year, natl_poll_tpp = round(natl_poll_tpp, 2), polled_swing = round(natl_poll_swing, 2),
                    actual_swing = natl_swing, error_leaked = round(natl_poll_swing - natl_swing, 2))]))
cat(sprintf("SD2  region-polls: %d state-years, %d-%d, poll counts %d-%d\n",
            nrow(RP), min(RP$year), max(RP$year), min(RP$n_polls), max(RP$n_polls)))

# ---- feature 2: the preceding state election ------------------------------
SE <- fread(file.path(OUT, "state-swing-prior.csv"), showProgress = FALSE)
SE[, year := as.integer(sub("^fed", "", pair))]
cat(sprintf("SD3  state-election prior: %d rows, %d with a signal inside 24 months\n",
            nrow(SE), sum(is.finite(SE$state_swing) & SE$months_gap < 24)))

# ---- fit each, LEAVE-ONE-ELECTION-OUT, and emit per-state predictions ------
# UNION of state-years, not ST's. The anchor's results table stops at 2022,
# so an all.x merge from it silently dropped every fed2025 state-year: the
# 2025 WA state election (Labor -18.5, two months before federal polling day)
# was sitting in state-swing-prior.csv and reached nobody, and every fed2025
# row in the output read 0 / 999 / 0. Found 2026-09-19 by the v2 plan's smoke
# test. A state-year with no ACTUAL result (2025 today) still gets its
# predictors; actual_dev is NA there and every fit below filters on it.
A <- merge(ST[, .(year, state, actual_dev)], RP[, .(year, state, poll_dev, n_polls)],
           by = c("year", "state"), all = TRUE)
A <- merge(A, SE[, .(year, state = tolower(state), state_swing, months_gap)],
           by = c("year", "state"), all = TRUE)
cat(sprintf("SD3  state-years with predictors but no actual result yet: %s\n",
            paste(unique(A[!is.finite(actual_dev), paste0(year, "-", state)]), collapse = " ")))
# The raw swing is kept at ANY gap and the gap is emitted beside it: the
# consumer decides the decay (v2 uses exp(-gap/24)). Until 2026-09-19 this
# line zeroed the swing at 24 months, which made v2's decay dead code past
# that point (review gate). Mode 1 never reads this column.
A[!is.finite(months_gap), state_swing := NA_real_]

# RAW QUANTITIES, NOT PRE-FITTED PREDICTIONS. Pete's point, and he is right.
#
# The first version regressed actual_dev on each predictor and emitted the
# FITTED value. That does two harmful things: it imposes a linear shrink, and it
# throws away the information xgboost would use to decide how much to trust each
# source in which circumstances. Measured cost: WA 2022 came out at +0.96 primary
# points when the truth was +5.8, because a slope of 0.379 fitted across 30 mixed
# state-years shrank a signal that in THAT case was understated by half (polls
# implied +3.5, actual +6.9).
#
# So emit what we observed and let the model weigh it:
#   state_poll_dev   what state-level federal polls implied, minus the national swing
#   state_elec_dev   the preceding state election's own ALP swing
#   state_elec_gap   how many months old that state election is -- beyond about
#                    24 it is noise (r = -0.243), and the model can learn the
#                    decay rather than having a hard window imposed
#   state_poll_n     how many polls the state reading rests on (1 in 2007, 12 in
#                    2019), so a thin reading can be discounted
PRED <- copy(A)
setnames(PRED, c("poll_dev", "state_swing", "months_gap", "n_polls"),
         c("state_poll_dev", "state_elec_dev", "state_elec_gap", "state_poll_n"),
         skip_absent = TRUE)
for (j in c("state_poll_dev", "state_elec_dev"))
  set(PRED, which(!is.finite(PRED[[j]])), j, 0)
# Gap and count are "how much should you trust the value next to me", so an
# absent source gets a gap that reads as ancient and a count of zero rather than
# a missing value xgboost would split on as if it meant something.
set(PRED, which(!is.finite(PRED$state_elec_gap)), "state_elec_gap", 999)
set(PRED, which(!is.finite(PRED$state_poll_n)), "state_poll_n", 0L)

# AMENDMENT A2 (AUSPOL_STATE_POLL_EXTRA=2), added after arm 1 FAILED
# (plans/prereg-state-polls-extra-2026-10-02.md): a 90-day all-pollster mean
# lags a late national move, so in 2025 every state read low for Labor and the
# correction pushed Labor down everywhere. Crosstabs identify a state RELATIVE
# to the rest; in EVERY federal election (anchor years too), subtract the
# seat-weighted mean of the state deviations, leaving the national level to
# the national model.
if (identical(Sys.getenv("AUSPOL_STATE_POLL_EXTRA", "0"), "2")) {
  nseat <- unique(C[grepl("^fed", C$election), .(election, seat, state)])[, .(n_seats = .N), by = .(election, state)]
  nseat[, `:=`(year = as.integer(sub("^fed", "", election)), state = tolower(state))]
  for (yy in sort(unique(PRED$year))) {   # EVERY year, so one coefficient sees one definition
    ii <- which(PRED$year == yy & PRED$state_poll_n > 0)
    if (length(ii) < 2) next
    w <- nseat$n_seats[match(paste(yy, PRED$state[ii]), paste(nseat$year, nseat$state))]
    w[!is.finite(w)] <- 0
    mu <- sum(w * PRED$state_poll_dev[ii]) / sum(w)
    set(PRED, ii, "state_poll_dev", PRED$state_poll_dev[ii] - mu)
    cat(sprintf("SD2e fed%d: state poll deviations made relative (seat-weighted mean %+.2f removed)\n", yy, mu))
  }
}

cat("\nSD4  the two predictions against what actually happened, worst deviations first:\n")
print(head(PRED[is.finite(actual_dev)][order(-abs(actual_dev)), .(year, state,
      polls_say = round(state_poll_dev, 1), state_el_says = round(state_elec_dev, 1),
      actual = round(actual_dev, 1))], 12))
for (v in c("state_poll_dev", "state_elec_dev")) {
  nz <- PRED[PRED[[v]] != 0 & is.finite(actual_dev)]
  if (nrow(nz) > 5)
    cat(sprintf("SD4  %-15s r = %+.3f over %d state-years\n", v,
                stats::cor(nz[[v]], nz$actual_dev), nrow(nz)))
}

# ---- TPP deviation -> PRIMARY deviation, fitted not assumed ---------------
fed <- C[grepl("^fed", C$election) & is.finite(votes) & is.finite(tot)]
stt <- unique(fed[, .(election, seat, state, tot)])
den <- stt[, .(d = sum(tot, na.rm = TRUE)), by = .(election, state)]
alp <- fed[fed$party == "ALP", .(v = sum(votes, na.rm = TRUE)), by = .(election, state)]
P <- merge(alp, den, by = c("election", "state"))[, .(election, state, alp = 100 * v / d)]
dn <- unique(fed[, .(election, seat, tot)])[, .(d = sum(tot, na.rm = TRUE)), by = election]
an <- fed[fed$party == "ALP", .(v = sum(votes, na.rm = TRUE)), by = election]
P <- merge(P, merge(an, dn, by = "election")[, .(election, natl = 100 * v / d)], by = "election")
setorder(P, state, election)
P[, prim_dev := (alp - shift(alp)) - (natl - shift(natl)), by = state]
P[, year := as.integer(sub("^fed", "", election))]
P[, state := tolower(state)]
Q <- merge(P[is.finite(prim_dev), .(year, state, prim_dev)],
           ST[, .(year, state, actual_dev)], by = c("year", "state"))
cf <- stats::lm(prim_dev ~ 0 + actual_dev, data = Q)
k <- unname(stats::coef(cf)[1])
cat(sprintf("\nSD5  TPP deviation -> ALP PRIMARY deviation: factor %.3f (n=%d, R2 %.3f)\n",
            k, nrow(Q), summary(cf)$r.squared))
cat("SD5  fitted through the origin -- zero two-party deviation means zero primary deviation.\n")

# ---- emit per seat --------------------------------------------------------
SR <- fread(file.path(ANCHOR, "seat-regions.csv"), header = FALSE,
            col.names = c("seat", "lvl", "state"))
SR <- SR[SR$lvl == "fed", .(seat, state)]
cells <- unique(fed[, .(pair = election, seat)])
cells[, year := as.integer(sub("^fed", "", pair))]
cells <- merge(cells, SR, by = "seat", all.x = TRUE)
cells[, state := tolower(state)]
cells <- merge(cells, PRED[, .(year, state, state_poll_dev, state_elec_dev,
                               state_elec_gap, state_poll_n)],
               by = c("year", "state"), all.x = TRUE)
for (j in c("state_poll_dev", "state_elec_dev"))
  set(cells, which(!is.finite(cells[[j]])), j, 0)
set(cells, which(!is.finite(cells$state_elec_gap)), "state_elec_gap", 999)
set(cells, which(!is.finite(cells$state_poll_n)), "state_poll_n", 0L)
# NOT rescaled and NOT centred. Both are left on their own two-party scale --
# the k factor below is reported so a consumer knows roughly how a two-party
# deviation maps to primary, but applying it here would bake in one more
# assumption the model is better placed to make.
cat(sprintf("\nSD6  %d federal seat-elections | %d matched a state (%d unmatched)\n",
            nrow(cells), sum(!is.na(cells$state)), sum(is.na(cells$state))))
print(cells[pair == "fed2022", .(seats = .N, polls = round(mean(state_poll_dev), 2),
      state_el = round(mean(state_elec_dev), 2), gap = round(mean(state_elec_gap)),
      n_polls = mean(state_poll_n)), by = state][order(-polls)])
fwrite(cells[, .(pair, seat, state, state_poll_dev, state_elec_dev,
                 state_elec_gap, state_poll_n)],
       file.path(OUT, "state-deviation-features.csv"))
cat(sprintf("\nSD7  wrote %s/state-deviation-features.csv\n", OUT))
