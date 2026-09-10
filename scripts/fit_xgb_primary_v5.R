# v5: v1's feature set (pred_share, x, level_prev, level_now, dev_prev,
# n_cand_prev, n_cand_now, same, same_mp, is_major, party/region dummies)
# PLUS proven-or-plausible features identified in
# docs/plans/xgb-flows-variable-inventory-2026-09-10.md that never reached
# any xgb primary variant:
#   - margin, fed_swing, retirement, soph_cand, soph_party, prev_swing
#     (load_seats() -- the SAME six fields that cut seat-swing MAE 3.948 ->
#     3.425 in the retired two-party model, docs/plans/prereg-seat-swing-
#     predictors.md. NOTE: that result describes the RETIRED simulate_seats()
#     path (CLAUDE.md: "never improve, tune, measure or reason about the
#     two-party seat model... a finding that only moves it is not a
#     finding"), not the candidate model this script actually feeds. Treat
#     the 3.948->3.425 number as motivation that these fields carry SOME
#     signal, not as evidence they help THIS model -- that is exactly what
#     this script measures fresh.
#   - is_incumbent_party, a derived flag this script adds because
#     retirement/soph_cand/soph_party describe the INCUMBENT's situation and
#     are meaningless to a row unless the row's own party is (or isn't) the
#     incumbent.
#   - own_prev_pcv (personal_prior_vote() -- the identity-matched candidate's
#     OWN prior share, distinct from the seat/class-level `x` v1 already
#     uses).
#   - historic_elected (any candidate of this class in THIS contest has
#     been elected before, at any prior point) and ballot_position (public
#     draw before polling day) from candidacies.csv, aggregated from
#     candidate-level to (seat, party)-class level for the TARGET election.
#
# DELIBERATELY EXCLUDED: candidacies.csv's `swing` column. Per
# docs/DATA-DICTIONARY.md it is "the AEC's own seat-level swing, per
# candidate per division" -- i.e. computed FROM the target election's own
# result. Using it to predict that same election's primary share would be
# textbook target leakage (CLAUDE.md's leakage rule: "anything in the
# backtest must use only what was knowable before the election being
# predicted"). `historic_elected`/`ballot_position` were checked and are
# genuinely pre-election facts (career history; a public pre-poll draw) --
# `swing` is not, and is the one candidate feature this session's inventory
# flagged as needing verification rather than being taken on the name alone.
#
# WA HAS NO `load_seats()` EQUIVALENT (backtest_candidate_wa.R's own
# comment: "there is no WA equivalent"), so all six load_seats()-derived
# features are NA for every WA row -- xgb's native missing-value routing
# handles this, but it means WA gets zero benefit from this feature set,
# same shape as the WA feature-coverage gap already found for xgb v1.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
SD <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)

PAIRS <- list(
  list(election = "fed2007", prev = "fed2004", region = "fed"),
  list(election = "fed2010", prev = "fed2007", region = "fed"),
  list(election = "fed2013", prev = "fed2010", region = "fed"),
  list(election = "fed2016", prev = "fed2013", region = "fed"),
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "fed2025", prev = "fed2022", region = "fed"),
  list(election = "nsw2019", prev = "nsw2015", region = "nsw"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "qld2020", prev = "qld2017", region = "qld"),
  list(election = "qld2024", prev = "qld2020", region = "qld"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa"),
  list(election = "vic2014", prev = "vic2010", region = "vic"),
  list(election = "vic2018", prev = "vic2014", region = "vic"),
  list(election = "vic2022", prev = "vic2018", region = "vic"),
  list(election = "wa2001",  prev = "wa1996",  region = "wa"),
  list(election = "wa2005",  prev = "wa2001",  region = "wa"),
  list(election = "wa2008",  prev = "wa2005",  region = "wa"),
  list(election = "wa2013",  prev = "wa2008",  region = "wa"),
  list(election = "wa2017",  prev = "wa2013",  region = "wa"),
  list(election = "wa2021",  prev = "wa2017",  region = "wa"),
  list(election = "wa2025",  prev = "wa2021",  region = "wa")
)

# Anchor's incumbent strings distinguish LIB/NAT/LNP where our classify_party()
# buckets all three as "LNP" -- map so is_incumbent_party can actually match.
to_class <- function(p) ifelse(p %in% c("LIB", "NAT", "LNP"), "LNP", p)

state_level <- function(el) {
  d <- C[C$election == el]
  if (!nrow(d) || !all(c("votes", "tot") %in% names(d))) return(NULL)
  d <- d[is.finite(d$votes)]
  st <- unique(d[, list(seat, tot)]); den <- sum(st$tot, na.rm = TRUE)
  if (!is.finite(den) || den <= 0) return(NULL)
  d[, list(level = 100 * sum(votes, na.rm = TRUE) / den), by = party]
}

cat("=== building v5 feature matrix (base + seat-file + personal-vote + candidacy features) ===\n")
rows <- list()
seat_file_hits <- 0L; seat_file_pairs <- character(0)
for (pr in PAIRS) {
  lp <- state_level(pr$prev); ln <- state_level(pr$election)
  if (is.null(lp) || is.null(ln)) { cat(sprintf("XG5! no state level for %s -> skip\n", pr$election)); next }
  prevc <- C[C$election == pr$prev][, list(x = sum(pcv, na.rm = TRUE), n_cand_prev = .N), by = list(seat, party)]
  nowc  <- C[C$election == pr$election][, list(n_cand_now = .N), by = list(seat, party)]
  ret <- tryCatch(candidate_returns(pr$prev, pr$election), error = function(e) NULL)
  pv  <- tryCatch(personal_prior_vote(pr$prev, pr$election), error = function(e) NULL)
  sd_pair <- SD[pair == pr$election]
  if (!nrow(sd_pair)) { cat(sprintf("XG5! no sharedetail rows for %s -> skip\n", pr$election)); next }

  m <- merge(sd_pair, prevc, by = c("seat", "party"), all.x = TRUE)
  m <- merge(m, nowc, by = c("seat", "party"), all.x = TRUE)
  m <- merge(m, lp[, list(party, level_prev = level)], by = "party", all.x = TRUE)
  m <- merge(m, ln[, list(party, level_now  = level)], by = "party", all.x = TRUE)
  if (!is.null(ret)) m <- merge(m, ret, by = c("seat", "party"), all.x = TRUE)
  if (!is.null(pv))  m <- merge(m, pv[, list(seat, party, own_prev_pcv)], by = c("seat", "party"), all.x = TRUE)

  # seat-level, from load_seats() -- absent entirely for WA
  yr <- as.integer(sub("^[a-z]+", "", pr$election))
  sf <- tryCatch(as.data.table(load_seats(yr, pr$region)), error = function(e) NULL)
  if (!is.null(sf) && nrow(sf)) {
    seat_file_hits <- seat_file_hits + 1L; seat_file_pairs <- c(seat_file_pairs, pr$election)
    sf[, incumbent_class := to_class(incumbent)]
    m <- merge(m, sf[, list(seat, margin, fed_swing, retirement, soph_cand,
                             soph_party, prev_swing, incumbent_class)],
               by = "seat", all.x = TRUE)
    m[, is_incumbent_party := party == incumbent_class]
    m[, incumbent_class := NULL]
  } else {
    m[, `:=`(margin = NA_real_, fed_swing = NA_real_, retirement = NA,
              soph_cand = NA, soph_party = NA, prev_swing = NA_real_,
              is_incumbent_party = NA)]
  }

  # candidacy-level, aggregated to (seat, party), TARGET election only.
  # `swing` DELIBERATELY excluded -- see header comment, it is target leakage.
  cand_now <- C[C$election == pr$election]
  cand_now[, historic_elected_l := toupper(as.character(historic_elected)) %in% c("Y", "TRUE", "1")]
  agg_now <- cand_now[, list(
    historic_elected_any = any(historic_elected_l, na.rm = TRUE),
    ballot_pos_min = suppressWarnings(min(as.numeric(ballot_position), na.rm = TRUE))
  ), by = list(seat, party)]
  agg_now[!is.finite(ballot_pos_min), ballot_pos_min := NA_real_]
  m <- merge(m, agg_now, by = c("seat", "party"), all.x = TRUE)

  m[, `:=`(pair = pr$election, prev_pair = pr$prev, region = pr$region)]
  rows[[pr$election]] <- m
}
ALL <- rbindlist(rows, fill = TRUE)

cat(sprintf("\nseat-file (load_seats) coverage: %d of %d pairs -- %s\n",
            seat_file_hits, length(PAIRS), paste(seat_file_pairs, collapse = ", ")))

ALL[, x := ifelse(is.na(x), 0, x)]
ALL[, n_cand_prev := ifelse(is.na(n_cand_prev), 0L, n_cand_prev)]
ALL[, n_cand_now  := ifelse(is.na(n_cand_now), 1L, n_cand_now)]
ALL[, dev_prev := x - level_prev]
ALL[, same := ifelse(is.na(same), FALSE, same)]
ALL[, same_mp := ifelse(is.na(same_mp), FALSE, same_mp)]
ALL[, is_major := party %in% c("ALP", "LNP", "NAT")]

cat(sprintf("\nbuilt %d rows across %d pairs, %d cols\n", nrow(ALL), length(unique(ALL$pair)), ncol(ALL)))
cat("NA counts, new features (NA is honest 'unknown', not imputed -- xgb routes it natively):\n")
new_feat_check <- c("margin", "fed_swing", "retirement", "soph_cand", "soph_party",
                     "prev_swing", "is_incumbent_party", "own_prev_pcv",
                     "historic_elected_any", "ballot_pos_min")
print(sapply(ALL[, ..new_feat_check], function(v) sum(is.na(v))))

fwrite(ALL, file.path(OUT, "xgb-primary-features-v5.csv"))
cat(sprintf("wrote %s\n\n", file.path(OUT, "xgb-primary-features-v5.csv")))

# ============================== fit + CV =====================================
before <- nrow(ALL)
ALL <- ALL[is.finite(level_prev) & is.finite(level_now)]
cat(sprintf("dropped %d of %d rows with no state level; %d remain\n", before - nrow(ALL), before, nrow(ALL)))

base_rmse <- sqrt(mean((ALL$pred_share - ALL$actual_share)^2))
cat(sprintf("\nBASELINE (shipped model) pooled primary RMSE: %.4f  (n=%d)\n", base_rmse, nrow(ALL)))

ALL[, same_i := as.integer(same)]
ALL[, same_mp_i := as.integer(same_mp)]
ALL[, is_major_i := as.integer(is_major)]
ALL[, retirement_i := as.integer(retirement)]
ALL[, soph_cand_i := as.integer(soph_cand)]
ALL[, soph_party_i := as.integer(soph_party)]
ALL[, is_incumbent_party_i := as.integer(is_incumbent_party)]
ALL[, historic_elected_i := as.integer(historic_elected_any)]
party_levels <- sort(unique(ALL$party))
region_levels <- sort(unique(ALL$region))
for (p in party_levels) ALL[[paste0("party_", p)]] <- as.integer(ALL$party == p)
for (r in region_levels) ALL[[paste0("region_", r)]] <- as.integer(ALL$region == r)

feat_cols <- c("pred_share", "x", "level_prev", "level_now", "dev_prev",
               "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
               "margin", "fed_swing", "retirement_i", "soph_cand_i", "soph_party_i",
               "prev_swing", "is_incumbent_party_i", "own_prev_pcv",
               "historic_elected_i", "ballot_pos_min",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share

pairs <- sort(unique(ALL$pair))
fold_id <- match(ALL$pair, pairs)
dtrain <- xgb.DMatrix(data = X, label = y, missing = NA)

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

cat("\nrunning xgb.cv, grouped folds by election pair (leave-one-pair-out), same params as v1...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 2000, folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)

best_n <- cv$early_stop$best_iteration
cat(sprintf("best nrounds: %d\n", best_n))
oof_pred <- cv$cv_predict$pred[, 1]
xgb_rmse <- sqrt(mean((oof_pred - y)^2))
cat(sprintf("\nXGBOOST v5 (leave-one-pair-out) pooled primary RMSE: %.4f  (n=%d)\n", xgb_rmse, length(y)))
cat(sprintf("improvement vs shipped model: %.2f%%\n", 100 * (base_rmse - xgb_rmse) / base_rmse))

final <- xgb.train(params = params, data = dtrain, nrounds = best_n, verbose = 0)
imp <- xgb.importance(feature_names = feat_cols, model = final)
cat("\ntop 20 features by gain:\n")
print(head(imp, 20))

ALL[, xgb_pred := oof_pred]
fwrite(ALL[, .(pair, seat, party, pred_share, actual_share, xgb_pred)],
       file.path(OUT, "xgb-primary-v5-oof-predictions.csv"))
cat(sprintf("\nwrote %s\n", file.path(OUT, "xgb-primary-v5-oof-predictions.csv")))

cat("\nRMSE by jurisdiction (shipped vs xgb v5):\n")
print(ALL[, .(n = .N,
              shipped_rmse = sqrt(mean((pred_share - actual_share)^2)),
              xgb_rmse = sqrt(mean((xgb_pred - actual_share)^2))), by = region])

cat("\nsa2026 ONP check:\n")
print(ALL[pair == "sa2026" & party == "ONP", .(seat, pred_share, xgb_pred, actual_share)])
