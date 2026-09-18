# Build the data behind the "AEF-7 Seat Ledger" artifact -- Pete's main
# day-to-day debugging tool for comparing our forecast against AE Forecasts
# seat by seat, across the 7 elections we have an external benchmark for.
#
# WRITTEN 2026-09-17 because the tool existed only as a hand-assembled
# scratchpad script from an earlier session that no longer exists by the
# time the ledger needed its next refresh -- exactly the "an experiment
# that never ran looks like one with no effect" family of failure, but for
# an artifact instead of a measurement. This script is the committed
# replacement: run it whenever the model changes and the ledger needs
# fresh numbers.
#
# WHAT THIS SCRIPT DOES NOT DO: it does not re-derive the final-two
# pairings or AEF's own TCP scenario data (output/aef7-final-two-and-tcp-
# reference.csv) or the hand-assigned failure-group labels (output/aef7-
# seat-groups.csv). Neither depends on our model, so neither needs
# regenerating when our forecast changes -- see the .gitignore entry for
# both files, which is the only place they are safe from being lost again.
#
# PREREQUISITE: scripts/build_aef_comparison.R must have been run against
# fresh backtests for all seven AEF7 pairs (fed2022, fed2025, nsw2023,
# qld2024, sa2026, vic2022, wa2025) at the FULL sim count -- not an
# AUSPOL_N_SIMS=5000 exploratory run. Check output/pooled-backtest.csv's
# mtimes and codes match a run you trust before relying on this.
#
# Emits AEFL* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(jsonlite))

OUT <- "output"
eps <- 1e-6

MAP <- data.table(
  pair = c("fed2022","nsw2023","vic2022","qld2024","fed2025","wa2025","sa2026"),
  aef_code = c("2022fed","2023nsw","2022vic","2024qld","2025fed","2025wa","2026sa"))
JURIS_PREFIX <- c(sa2026 = "sa", wa2025 = "wa", vic2022 = "vic")

comp <- fread(file.path(OUT, "aef-comparison-full.csv"), showProgress = FALSE)
comp <- comp[pair %in% MAP$pair]
if (!nrow(comp)) stop("aef-comparison-full.csv has no AEF7 rows -- run scripts/build_aef_comparison.R first")
cat(sprintf("AEFL0 %d comparison rows across %d AEF7 pairs\n", nrow(comp), uniqueN(comp$pair)))

groups <- fread(file.path(OUT, "aef7-seat-groups.csv"), showProgress = FALSE)
ref <- fread(file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), showProgress = FALSE)

# OUR OWN FAVOURITE'S probability and primary share, for seats where we
# called it wrong (our_pred != actual). Every file comes from the SAME
# harness run as the pair's win file -- scripts/ledger_inputs.R explains the
# three-vintage page that "newest file by name" produced on 2026-09-18.
source("scripts/ledger_inputs.R")
fav_for <- function(pr) {
  ap <- run_table(pr, "allprobs")
  sd <- run_table(pr, "sharedetail")
  if (is.null(ap)) { cat(sprintf("AEFL1! %s: no allprobs file -- our_p_fav will equal our_p_win\n", pr)); return(NULL) }
  fav <- ap[, .SD[which.max(prob)], by = seat][, .(seat, fav = party, our_p_fav = prob)]
  if (!is.null(sd)) {
    if ("xgb_primary_on" %in% names(sd) && any(sd$xgb_primary_on != 1))
      stop(pr, ": the run's sharedetail has xgb_primary_on != 1 -- this is a stage-1 (base_pred only) run, not the shipped model")
    sd <- sd[, .(pred_share = mean(pred_share)), by = .(seat, party)]
    fav <- merge(fav, sd, by.x = c("seat","fav"), by.y = c("seat","party"), all.x = TRUE)
    setnames(fav, "pred_share", "our_fp_fav")
  }
  fav[, pair := pr][]
}
fav_all <- rbindlist(lapply(MAP$pair, fav_for), fill = TRUE)
cat(sprintf("AEFL1 our-favourite lookup built for %d/%d pairs\n",
            uniqueN(fav_all$pair[!is.na(fav_all$fav)]), nrow(MAP)))

# OUR OWN top-scenario final-two pick, for the TCP error metric. Unlike
# win/sharedetail/allprobs, the ourtcp files are named with the full PAIR
# (not the region), even for the multi-pair harnesses -- a different
# convention, checked directly rather than assumed.
tcp_for <- function(pr) {
  x <- run_table(pr, "ourtcp")
  if (is.null(x)) { cat(sprintf("AEFL4! %s: no ourtcp file -- our TCP%% left NA\n", pr)); return(NULL) }
  x[, .SD[which.max(freq)], by = seat][, .(seat, our_tcp_f1 = f1, our_tcp_f2 = f2, our_tcp_pct = f1_tcp_pct, our_tcp_freq = freq)][, pair := pr][]
}
tcp_all <- rbindlist(lapply(MAP$pair, tcp_for), fill = TRUE)

ALL <- merge(comp, fav_all, by = c("pair","seat"), all.x = TRUE)
# Where we called it RIGHT, our favourite IS the winner -- fav-side numbers
# equal win-side numbers exactly, not approximately.
ALL[our_pred == actual, `:=`(fav = actual, our_p_fav = our_p, our_fp_fav = our_primary)]
if (anyNA(ALL$fav)) cat(sprintf("AEFL1! %d row(s) still missing a favourite after the lookup+correct-call fill\n", sum(is.na(ALL$fav))))

ALL <- merge(ALL, groups, by = c("pair","seat"), all.x = TRUE)
ALL[is.na(grp), grp := ""]
ALL <- merge(ALL, ref, by = c("pair","seat"), all.x = TRUE)
ALL <- merge(ALL, tcp_all, by = c("pair","seat"), all.x = TRUE)

# TCP scored against the pairing that ACTUALLY happened, not just each
# side's own #1 guess -- scripts/build_aef7_tcp_actual.R, built 2026-09-18
# after Pete asked for TCP scored on all 660 seats, not the ~86% subset
# where a side's top pick happened to match. NA for the 28 seats (27
# vic2022, 1 nsw2023) with no resolved official final-two at all.
tcp_actual_f <- file.path(OUT, "aef7-tcp-actual.csv")
if (file.exists(tcp_actual_f)) {
  tcpa <- fread(tcp_actual_f, showProgress = FALSE)
  tcpa <- tcpa[, .(pair, seat, our_tcp_actual_freq, our_tcp_pred_pct, our_tcp_actual_share,
                    our_tcp_pick, our_tcp_pick_pct,
                    aef_tcp_actual_freq, aef_tcp_pred_pct, aef_tcp_actual_share,
                    aef_tcp_pick, aef_tcp_pick_pct)]
  ALL <- merge(ALL, tcpa, by = c("pair","seat"), all.x = TRUE)
} else {
  cat("AEFL6! output/aef7-tcp-actual.csv missing -- run scripts/build_aef7_tcp_actual.R first; actual-pairing TCP columns left NA\n")
  ALL[, `:=`(our_tcp_actual_freq = NA_real_, our_tcp_pred_pct = NA_real_, our_tcp_actual_share = NA_real_,
             our_tcp_pick = NA_character_, our_tcp_pick_pct = NA_real_,
             aef_tcp_actual_freq = NA_real_, aef_tcp_pred_pct = NA_real_, aef_tcp_actual_share = NA_real_,
             aef_tcp_pick = NA_character_, aef_tcp_pick_pct = NA_real_)]
}

SEATS <- ALL[, .(
  pair, seat,
  winner = actual, fav, correct = (our_pred == actual),
  our_p_win = our_p, our_p_fav,
  aef_p_win = aef_p, aef_p_fav = if ("aef_p_fav" %in% names(ALL)) aef_p_fav else aef_p,   # favourite's own probability (pred_p) since 2026-09-19
  our_fp_win = our_primary, aef_fp_win = aef_primary, act_fp_win = actual_primary,
  miss = actual_primary - our_primary,
  aef_miss = actual_primary - aef_primary,
  # SAME CONVENTION AS THE PAGE'S OWN "delta loss" (seat log loss): our
  # error minus AEF's, on the ABSOLUTE miss so direction doesn't cancel a
  # comparison -- negative means we did better on primary here, positive
  # means AEF did.
  primary_delta = abs(actual_primary - our_primary) - abs(actual_primary - aef_primary),
  ll = -log(pmin(pmax(our_p, eps), 1)), aef_ll = -log(pmin(pmax(aef_p, eps), 1)),
  grp,
  f1, f2, f2cp, fsrc,
  our_fp_fav, aef_fp_fav = aef_primary, act_fp_fav = actual_primary,
  aef_tcp_f1, aef_tcp_f2, aef_tcp_pct, aef_tcp_scenario_freq, aef_tcp_p05, aef_tcp_p95,
  our_tcp_f1, our_tcp_f2, our_tcp_pct, our_tcp_freq,
  our_tcp_actual_freq, our_tcp_pred_pct, our_tcp_actual_share,
  aef_tcp_actual_freq, aef_tcp_pred_pct, aef_tcp_actual_share,
  our_tcp_pick, our_tcp_pick_pct, aef_tcp_pick, aef_tcp_pick_pct
)]
# AEF'S OWN aef_p/aef_pred is already "AEF's favourite and AEF's probability
# for it" (build_aef_comparison.R's read from aef_scores), so aef_p_fav ==
# aef_p_win and aef_fp_fav == aef_fp_win always -- AEF's own comparison data
# never distinguishes the two the way ours does, because build_aef_
# comparison.R only ever reads AEF's stated top pick. Not a bug in this
# script; a real asymmetry in what the two sources publish.

setorder(SEATS, pair, seat)
out_path <- file.path(OUT, "aef7-ledger-data.json")
write(toJSON(SEATS, dataframe = "rows", auto_unbox = TRUE, digits = 6), out_path)
cat(sprintf("AEFL2 wrote %s: %d seats\n", out_path, nrow(SEATS)))

pooled <- SEATS[, .(n = .N, our_ll = mean(ll), aef_ll = mean(aef_ll)), by = pair]
setorder(pooled, pair)
print(pooled[, .(pair, n, our_ll = round(our_ll,4), aef_ll = round(aef_ll,4))])
cat(sprintf("\nAEFL3 pooled over all %d AEF7 seats: ours %.4f vs AEF %.4f\n",
            nrow(SEATS), mean(SEATS$ll), mean(SEATS$aef_ll)))

# POOLED SUMMARY STATS, for the ledger's own header strip. Three metrics,
# each with the count of seats it's actually computed on -- per this
# repo's own rule, never quote a derived stat without the n behind it.
rmse <- function(x, y) sqrt(mean((x - y)^2, na.rm = TRUE))

primary_rmse <- SEATS[, .(our = rmse(our_fp_win, act_fp_win), aef = rmse(aef_fp_win, act_fp_win), n = .N)]

# TCP absolute error is only meaningful where the PREDICTED pairing is the
# one that actually happened (f1/f2 unordered) -- comparing a percentage
# for a pairing that never occurred to anyone's real share would not be
# measuring the same thing. Scored separately for ours and AEF, since the
# two sources will not always predict the same pairing for the same seat.
#
# THE NAMED PARTY IS NOT ALWAYS THE ACTUAL WINNER, even when the pairing
# matches -- AEF's own "pick" can be the pairing's LOSER (Wentworth
# fed2025: "AEF pick" LNP at 43.5% means AEF actually predicted IND, the
# other finalist, to win -- and IND did). f2cp is defined as the WINNER's
# real share, so comparing a LOSER-named percentage against it compares two
# different things and inflates the error. actual_share_of() picks f2cp
# when the named party IS the actual winner, and 100-f2cp (the actual
# runner-up's own real share of the same two-candidate count) otherwise.
# Found while explaining the Wentworth case to Pete -- the first version of
# this metric had exactly this bug for AEF's side.
pair_matches <- function(a1, a2, b1, b2) (a1 == b1 & a2 == b2) | (a1 == b2 & a2 == b1)
actual_share_of <- function(named, w, r, wshare) fifelse(named == w, wshare, fifelse(named == r, 100 - wshare, NA_real_))
our_tcp_hit  <- SEATS[!is.na(our_tcp_pct) & pair_matches(our_tcp_f1, our_tcp_f2, f1, f2)]
aef_tcp_hit  <- SEATS[!is.na(aef_tcp_pct) & pair_matches(aef_tcp_f1, aef_tcp_f2, f1, f2)]
our_tcp_hit[, our_actual_share := actual_share_of(our_tcp_f1, f1, f2, f2cp)]
aef_tcp_hit[, aef_actual_share := actual_share_of(aef_tcp_f1, f1, f2, f2cp)]
tcp_mae <- list(
  our = mean(abs(our_tcp_hit$our_tcp_pct - our_tcp_hit$our_actual_share)), our_n = nrow(our_tcp_hit),
  aef = mean(abs(aef_tcp_hit$aef_tcp_pct - aef_tcp_hit$aef_actual_share)), aef_n = nrow(aef_tcp_hit))


# WEIGHTED PRIMARY RMSE, every party in every seat, weighted by that party's
# ACTUAL vote share -- not just the eventual winner. Pete's request 2026-09-18:
# the winner-only primary_rmse above misses how well-calibrated the WHOLE
# primary vote distribution is (a seat where we nail the winner's share but
# badly misjudge everyone else's slice looks perfect on primary_rmse alone).
# OUR side is fully computable from output/pooled-sharedetail.csv, which
# already carries one row per (pair, seat, party) with pred_share/actual_share.
# AEF'S side needs their fpTrend field parsed out of external/reference/aef/
# *-summary.json -- flagged as unparsed in build_aef_tcp.R's own header
# comment and genuinely not built yet, so AEF is reported as unavailable
# rather than guessed at or silently omitted.
primary_wrmse <- list(our = NA_real_, our_n = 0L, aef = NA_real_, aef_n = 0L)
# From the SAME runs as everything else on the page -- NOT pooled-sharedetail.csv,
# which pool_sharedetail.R only accepts at xgb_primary_on = 0 and is therefore
# base_pred without the xgb layer. Until 2026-09-18 this card compared AEF
# against our PRE-xgb baseline (5.28) and called it "ours"; the shipped model
# is 4.80 on the same rows.
sdw <- rbindlist(lapply(MAP$pair, function(pr) { x <- run_table(pr, "sharedetail"); if (!is.null(x)) x[, pair := pr] }), fill = TRUE)
sdw <- sdw[!is.na(actual_share)]
if (nrow(sdw)) {
  if ("xgb_primary_on" %in% names(sdw) && any(sdw$xgb_primary_on != 1))
    stop("weighted primary RMSE: a run's sharedetail has xgb_primary_on != 1 -- not the shipped model")
  primary_wrmse$our <- sqrt(sum(sdw$actual_share * (sdw$pred_share - sdw$actual_share)^2) / sum(sdw$actual_share))
  primary_wrmse$our_n <- nrow(sdw)
} else {
  cat("AEFL7! no sharedetail rows from the chosen runs -- weighted primary RMSE (ours) left NA\n")
}
# AEF's side: scripts/build_aef_fptrend.R, built 2026-09-18, parses their
# per-party seatFpBands medians. Verified against a real seat (Frankston,
# vic2022) before trusting it -- see that script's own header.
aft_f <- file.path(OUT, "aef7-fptrend.csv")
if (file.exists(aft_f) && exists("sdw")) {
  aft <- fread(aft_f, showProgress = FALSE)
  aftw <- merge(aft, sdw[, .(pair, seat, party, actual_share)], by = c("pair", "seat", "party"))
  if (nrow(aftw)) {
    primary_wrmse$aef <- sqrt(sum(aftw$actual_share * (aftw$aef_fp_pred - aftw$actual_share)^2) / sum(aftw$actual_share))
    primary_wrmse$aef_n <- nrow(aftw)
  }
} else {
  cat("AEFL8! output/aef7-fptrend.csv missing -- run scripts/build_aef_fptrend.R first; weighted primary RMSE (AEF) left NA\n")
}

summary_stats <- list(
  n_seats = nrow(SEATS),
  seat_logloss = list(our = mean(SEATS$ll), aef = mean(SEATS$aef_ll), n = nrow(SEATS)),
  primary_rmse = list(our = primary_rmse$our, aef = primary_rmse$aef, n = primary_rmse$n),
  primary_wrmse = primary_wrmse,
  tcp_mae = tcp_mae,
  accuracy = list(our = mean(SEATS$correct), aef = mean(SEATS$aef_p_win >= 0.5), n = nrow(SEATS)))

write(toJSON(summary_stats, auto_unbox = TRUE, digits = 4), file.path(OUT, "aef7-ledger-summary.json"))
cat(sprintf("\nAEFL5 pooled summary: seat log loss ours %.4f vs AEF %.4f (n=%d) | primary RMSE (all parties, weighted) ours %.3f (n=%d) vs AEF %.3f (n=%d) | TCP MAE ours %.2f (n=%d) vs AEF %.2f (n=%d)\n",
            summary_stats$seat_logloss$our, summary_stats$seat_logloss$aef, summary_stats$seat_logloss$n,
            primary_wrmse$our, primary_wrmse$our_n, primary_wrmse$aef, primary_wrmse$aef_n,
            summary_stats$tcp_mae$our, summary_stats$tcp_mae$our_n, summary_stats$tcp_mae$aef, summary_stats$tcp_mae$aef_n))
