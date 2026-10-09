# EVERY PUBLISHED PREDICTION IN ONE FILE: one row per (election, seat, party
# class), from the same scored runs the ledger and biggest_misses.R read
# (scripts/ledger_inputs.R, one harness run per pair).
#
# WHY (Pete, 2026-10-09): "What's our up to date file of every prediction?"
# There was none. pooled-sharedetail.csv looks like it, but it is the stage-1
# base_pred pool at AUSPOL_XGB_PRIMARY=0 -- training input, deliberately NOT
# the published numbers -- and the published ones lived in 22 separate
# backtest-*-sharedetail / -allprobs files. The biggest misses are often not
# the winner (an over-called independent, an under-called minor), so the
# ledger also needs every candidate, not just the winner.
#
# Output:
#   output/published-predictions.csv   all pairs; every column below
#   output/published-predictions-aef7.json   the AEF-7 subset, for the ledger
# Columns: pair, seat, party, candidate (leading candidate of the class by
# actual vote, "+k" when the class had more), n_cands, ours, actual,
# miss (actual - ours, points; positive = we under-called), p_win (our
# probability this class wins the seat), won, aef, aef_miss (AEF-7 pairs only).
#
# Run after pool_backtests.R (rebuild stage 8). Emits PP* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
OUT <- "output"
AEF7 <- c("fed2022", "fed2025", "nsw2023", "qld2024", "sa2026", "vic2022", "wa2025")
source("scripts/ledger_inputs.R")   # .PB, run_table()
pairs <- .PB$pair

sd <- rbindlist(lapply(pairs, function(pr) {
  x <- run_table(pr, "sharedetail")
  if (is.null(x)) stop("PP1! ", pr, ": no sharedetail file for the scored run")
  if ("xgb_primary_on" %in% names(x) && any(x$xgb_primary_on != 1))
    stop("PP1! ", pr, ": sharedetail has xgb_primary_on != 1 -- a base_pred-only stage-1 run, not the published model")
  x[, .(pair = pr, seat, party, ours = pred_share, actual = actual_share)]
}))
ap <- rbindlist(lapply(pairs, function(pr) {
  x <- run_table(pr, "allprobs")
  if (is.null(x)) stop("PP1! ", pr, ": no allprobs file for the scored run")
  x[, .(pair = pr, seat, party, p_win = prob, winner = actual)]
}))
if (anyDuplicated(sd[, .(pair, seat, party)])) stop("PP2! duplicate (pair, seat, party) in sharedetail")
if (anyDuplicated(ap[, .(pair, seat, party)])) stop("PP2! duplicate (pair, seat, party) in allprobs")

# Every seat the probabilities cover must have primaries, and the reverse.
s_sd <- unique(sd[, .(pair, seat)]); s_ap <- unique(ap[, .(pair, seat)])
lost <- rbind(fsetdiff(s_sd, s_ap)[, side := "no allprobs"], fsetdiff(s_ap, s_sd)[, side := "no sharedetail"])
if (nrow(lost)) { print(head(lost, 20)); stop(sprintf("PP3! %d seat(s) are in one file and not the other", nrow(lost))) }

P <- merge(sd, ap, by = c("pair", "seat", "party"), all = TRUE)
P[is.na(p_win), p_win := 0]
# The winner's class can be missing from allprobs when we gave it 0 (Denison
# 2010, Indi 2013): take the seat's winner from any of its rows, not is_actual.
W <- unique(ap[, list(pair, seat, winner)])
if (anyDuplicated(W[, list(pair, seat)])) stop("PP2! a seat names two different winners in allprobs")
P[, winner := NULL]
P <- merge(P, W, by = c("pair", "seat"), all.x = TRUE)
P[, won := party == winner][, winner := NULL]

# Candidate names: classes can hold several people; show the leader by vote.
cands <- fread(file.path(OUT, "candidacies.csv"), select = c("election", "seat", "name", "party", "pcv"),
               showProgress = FALSE, encoding = "UTF-8")
cands <- cands[order(-pcv)][, list(candidate = name[1L], n_cands = .N), by = list(pair = election, seat, party)]
cands[n_cands > 1L, candidate := sprintf("%s +%d", candidate, n_cands - 1L)]
P <- merge(P, cands, by = c("pair", "seat", "party"), all.x = TRUE)

aef <- fread(file.path(OUT, "aef7-fptrend.csv"), showProgress = FALSE)
P <- merge(P, aef[, list(pair, seat, party, aef = aef_fp_pred)], by = c("pair", "seat", "party"), all.x = TRUE)
P[, `:=`(miss = actual - ours, aef_miss = actual - aef)]
setcolorder(P, c("pair", "seat", "party", "candidate", "n_cands", "ours", "actual", "miss", "p_win", "won", "aef", "aef_miss"))
setorder(P, pair, seat, -actual)

# Coverage, not presence (global CLAUDE.md): every column, and the checks
# that would catch a join that silently matched nothing.
pw <- P[, list(s = sum(p_win)), by = list(pair, seat)]
won_n <- P[, list(w = sum(won)), by = list(pair, seat)]
cat(sprintf("PP4  %d rows, %d seats, %d pairs; win probabilities sum to %.3f-%.3f per seat; seats with exactly one winner: %d of %d\n",
            nrow(P), nrow(pw), uniqueN(P$pair), min(pw$s), max(pw$s), sum(won_n$w == 1L), nrow(won_n)))
cov <- P[, lapply(.SD, function(v) round(100 * mean(!is.na(v)), 1)), .SDcols = c("candidate", "ours", "actual", "aef")]
cat(sprintf("PP5  coverage %%: candidate %.1f | ours %.1f | actual %.1f | aef (AEF-7 pairs only) %.1f of those rows\n",
            cov$candidate, cov$ours, cov$actual, 100 * mean(!is.na(P[pair %in% AEF7]$aef))))
if (any(abs(pw$s - 1) > 0.02)) stop("PP4! a seat's win probabilities do not sum to 1")
# A class with no candidate (actual 0) has no name by construction, so names
# are checked on classes that stood: 99.9% on 2026-10-09, the gap being
# Narracan 2022 (deferred supplementary election) and one Giles row.
stood <- P[actual > 0]
if (mean(!is.na(stood$candidate)) < 0.98) stop("PP5! candidate names joined on under 98% of classes that stood -- check candidacies.csv labels")
# AEF folds some classes (One Nation, minor right) into OTH in some pairs, so
# a missing AEF value is often real; a pair where it is mostly missing is a join failure.
ac <- stood[pair %in% AEF7, list(cov = mean(!is.na(aef))), by = pair]
cat(sprintf("PP5  AEF primary present on classes that stood: %s\n", paste(sprintf("%s %.0f%%", ac$pair, 100 * ac$cov), collapse = ", ")))
if (any(ac$cov < 0.5)) stop("PP5! AEF primaries joined on under half of one pair's standing classes -- check aef7-fptrend.csv")
no1 <- won_n[w != 1L]
if (nrow(no1)) cat(sprintf("PP4! %d seat(s) without exactly one winning class in allprobs: %s\n", nrow(no1),
                           paste(sprintf("%s %s (%d)", no1$pair, no1$seat, no1$w), collapse = ", ")))

num <- c("ours", "actual", "miss", "p_win", "aef", "aef_miss")
P[, (num) := lapply(.SD, function(v) round(v, 4)), .SDcols = num]
fwrite(P, file.path(OUT, "published-predictions.csv"))
A <- P[pair %in% AEF7, list(pair, seat, party, candidate, ours = round(ours, 2), actual = round(actual, 2),
                            p_win = round(p_win, 4), won, aef = round(aef, 2))]
writeLines(jsonlite::toJSON(A, dataframe = "rows", na = "null", auto_unbox = TRUE), file.path(OUT, "published-predictions-aef7.json"))
cat(sprintf("PP6  wrote output/published-predictions.csv (%d rows, %.0f KB) and the AEF-7 subset (%d rows)\n",
            nrow(P), file.size(file.path(OUT, "published-predictions.csv")) / 1024, nrow(A)))
