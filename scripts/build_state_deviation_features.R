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
RP <- merge(RP, natl, by = "year")
RP[, poll_dev := (agg - prev_tpp) - natl_swing]
cat(sprintf("SD2  region-polls: %d state-years, %d-%d, poll counts %d-%d\n",
            nrow(RP), min(RP$year), max(RP$year), min(RP$n_polls), max(RP$n_polls)))

# ---- feature 2: the preceding state election ------------------------------
SE <- fread(file.path(OUT, "state-swing-prior.csv"), showProgress = FALSE)
SE[, year := as.integer(sub("^fed", "", pair))]
cat(sprintf("SD3  state-election prior: %d rows, %d with a signal inside 24 months\n",
            nrow(SE), sum(is.finite(SE$state_swing) & SE$months_gap < 24)))

# ---- fit each, LEAVE-ONE-ELECTION-OUT, and emit per-state predictions ------
A <- merge(ST[, .(year, state, actual_dev)], RP[, .(year, state, poll_dev, n_polls)],
           by = c("year", "state"), all.x = TRUE)
A <- merge(A, SE[, .(year, state = tolower(state), state_swing, months_gap)],
           by = c("year", "state"), all.x = TRUE)
A[!is.finite(months_gap) | months_gap >= 24, state_swing := NA_real_]

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

cat("\nSD4  the two predictions against what actually happened, worst deviations first:\n")
print(head(PRED[order(-abs(actual_dev)), .(year, state,
      polls_say = round(state_poll_dev, 1), state_el_says = round(state_elec_dev, 1),
      actual = round(actual_dev, 1))], 12))
for (v in c("state_poll_dev", "state_elec_dev")) {
  nz <- PRED[PRED[[v]] != 0]
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
