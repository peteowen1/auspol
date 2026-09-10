# v4: same features as v3 (salience + surge-v2), but rows flagged as rare/
# emergent (permit==1 or is_recipient==1) get upweighted in training via
# xgb.DMatrix's weight argument, so the loss doesn't let ~14,000 ordinary
# rows drown out the few hundred that actually matter for the worst-20-seats
# problem. Everything else identical to v3 for a clean comparison.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
ALL <- fread(file.path(OUT, "xgb-primary-features.csv"), showProgress = FALSE)
ALL <- ALL[is.finite(level_prev) & is.finite(level_now)]

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
  list(election = "vic2022", prev = "vic2018", region = "vic")
)
SURGE_CANON <- list(
  list(election = "fed2010", prev = "fed2007", region = "fed"),
  list(election = "fed2013", prev = "fed2010", region = "fed"),
  list(election = "fed2016", prev = "fed2013", region = "fed"),
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "vic2022", prev = "vic2018", region = "vic"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa"),
  list(election = "wa2008",  prev = "wa2005",  region = "wa")
)

sal_rows <- list()
for (pr in PAIRS) {
  s <- tryCatch(governed_population(pr$election, pr$prev, pr$region), error = function(e) NULL)
  if (is.null(s) || !nrow(s)) next
  s[, permit := salience_screen(jump, governed)]
  sal_rows[[pr$election]] <- s[, .(pair = pr$election, seat, party, jump, governed = as.integer(governed), permit = as.integer(permit))]
}
SAL <- rbindlist(sal_rows, fill = TRUE)
# governed_population() emits one row per NAMED CANDIDATE (R/salience_screen.R's
# own docstring), while ALL is one row per (pair, seat, party) -- several
# independents/minor candidates bucketed into the same class in one seat means
# SAL can carry more than one row per merge key. An uncontrolled merge()
# against that silently fans a single ALL row out into duplicates (found by
# docs/reviews/xgb-primary-flag-bugfixes-2026-09-10.md: 904 of 14,495 rows,
# discovered only in that review's own scratch analysis and never patched back
# here). Collapsed to "any candidate in the cell fires" BEFORE merging, with a
# row-count assertion so a future change to governed_population()'s grain
# fails loudly here instead of silently inflating the training population again.
SAL <- SAL[, .(permit = as.integer(any(permit == 1)),
               governed = as.integer(any(governed == 1)),
               jump = max(jump, na.rm = TRUE)),
           by = .(pair, seat, party)]
n_before <- nrow(ALL)
ALL <- merge(ALL, SAL, by = c("pair","seat","party"), all.x = TRUE)
stopifnot(nrow(ALL) == n_before)
ALL[, jump := ifelse(is.na(jump), 0, jump)]
# GOVERNED, same direction as PERMIT below: "no claim" is not "definitely not
# governed" -- but governed's own screening semantics (a candidate of a
# surging class is deliberately marked NOT governed, per governed_population()'s
# docstring) mean flipping this default the same way as permit would falsely
# mark every unmatched row as a surging-class candidate. Left at 0 (not
# governed) deliberately for that reason, not an oversight -- unlike permit,
# where 0 falsely claimed "verified safe" rather than "no information."
ALL[, governed := ifelse(is.na(governed), 0L, governed)]
# FIXED 2026-09-10: an unmatched cell (no SAL row -- no salience/candidacy
# data at all for this class in this seat) used to default permit to 0,
# i.e. "not flagged, safe for xgb to predict freely." That inverts
# salience_screen()'s own convention -- "no claim about this candidate"
# means permit=TRUE everywhere else in this codebase (an ungoverned
# candidate gets permit=TRUE unconditionally; see R/salience_screen.R).
# No data should default to "protect this row," not "we checked and it's
# ordinary." Docs/reviews/xgb-primary-challenger-followup-2026-09-10.md.
ALL[, permit := ifelse(is.na(permit), 1L, permit)]

# SURGING-CLASS FLAG, separate from is_recipient. is_recipient (below) comes
# from surge_hazard_for()'s governed-population-gated ridge model, which by
# design (R/party_surge.R's own docstring, using SA2026 One Nation as its
# motivating example) EXCLUDES a class whose statewide vote is itself
# surging -- a party-level swing is not a personal, name-search-detectable
# emergence, and asking the salience signal to explain it is the exact
# failure R/party_surge.R was written to avoid. So SA2026 ONP can never be
# `is_recipient`, correctly -- not a bug. But it IS exactly the case a
# rare-row flag protecting xgb's blind spot needs to catch, so add it
# directly from surging_parties() rather than mutating the live surge-hazard
# mechanism (which also feeds fit_seats_full.R, the published forecast).
surging_rows <- list()
for (pr in PAIRS) {
  py <- as.integer(sub("^[a-z]+", "", pr$prev)); yr <- as.integer(sub("^[a-z]+", "", pr$election))
  sp <- tryCatch(surging_parties(pr$region, py, yr), error = function(e) character(0))
  if (!length(sp)) next
  surging_rows[[pr$election]] <- data.table(pair = pr$election, party = sp, surging = 1L)
}
SURGING <- rbindlist(surging_rows, fill = TRUE)
ALL <- merge(ALL, SURGING, by = c("pair","party"), all.x = TRUE)
ALL[, surging := ifelse(is.na(surging), 0L, surging)]

surge_rows <- list()
for (pr in PAIRS) {
  in_canon <- any(vapply(SURGE_CANON, function(p) identical(p$election, pr$election), TRUE))
  if (!in_canon) next
  train_pairs <- Filter(function(p) !identical(p$election, pr$election), SURGE_CANON)
  hz <- tryCatch(surge_hazard_for(pr$election, pr$prev, pr$region, train_pairs), error = function(e) NULL)
  if (is.null(hz)) next
  sh <- hz$seat_hazard[, .(pair = pr$election, seat, surge_h)]
  rc <- hz$seat_recipient[, .(pair = pr$election, seat, recipient_party = party)]
  surge_rows[[pr$election]] <- merge(sh, rc, by = c("pair","seat"), all = TRUE)
}
SURGE <- rbindlist(surge_rows, fill = TRUE)
ALL <- merge(ALL, SURGE, by = c("pair","seat"), all.x = TRUE)
ALL[, surge_h := ifelse(is.na(surge_h), 0, surge_h)]
ALL[, is_recipient := as.integer(!is.na(recipient_party) & recipient_party == party)]

base_rmse <- sqrt(mean((ALL$pred_share - ALL$actual_share)^2))
cat(sprintf("BASELINE (shipped model) pooled primary RMSE, this population: %.4f  (n=%d)\n", base_rmse, nrow(ALL)))

ALL[, same_i := as.integer(same)]
ALL[, same_mp_i := as.integer(same_mp)]
ALL[, is_major_i := as.integer(is_major)]
party_levels <- sort(unique(ALL$party))
region_levels <- sort(unique(ALL$region))
for (p in party_levels) ALL[[paste0("party_", p)]] <- as.integer(ALL$party == p)
for (r in region_levels) ALL[[paste0("region_", r)]] <- as.integer(ALL$region == r)

feat_cols <- c("pred_share", "x", "level_prev", "level_now", "dev_prev",
               "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
               "jump", "governed", "permit", "surge_h", "is_recipient",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share

# THE WEIGHT: rows the model already has an advance signal are rare (permit
# or named recipient) get upweighted so the loss can't just average them
# away against ~14,000 ordinary rows.
W <- rep(1, nrow(ALL))
W[ALL$permit == 1] <- 8
W[ALL$is_recipient == 1] <- 8
cat(sprintf("\nrow weighting: %d rows at weight 8 (permit or recipient), %d at weight 1\n",
            sum(W > 1), sum(W == 1)))

pairs <- sort(unique(ALL$pair))
fold_id <- match(ALL$pair, pairs)
dtrain <- xgb.DMatrix(data = X, label = y, weight = W)
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

cat("\nrunning xgb.cv WITH row weighting, leave-one-pair-out...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 2000, folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)
best_n <- cv$early_stop$best_iteration
oof_pred <- cv$cv_predict$pred[, 1]
# score UNWEIGHTED (the weighting is a training-time device; the evaluation
# must not also weight, or a win could just be "we scored our own weights")
xgb_rmse <- sqrt(mean((oof_pred - y)^2))
cat(sprintf("best nrounds: %d\n", best_n))
cat(sprintf("XGBOOST v4 (+ weighting) pooled primary RMSE (UNWEIGHTED eval): %.4f  (n=%d)\n", xgb_rmse, length(y)))
cat(sprintf("improvement vs shipped model: %.2f%%\n", 100 * (base_rmse - xgb_rmse) / base_rmse))

ALL[, xgb_pred_v4 := oof_pred]
fwrite(ALL[, .(pair, seat, party, pred_share, actual_share, xgb_pred_v4, jump, governed, permit, surge_h, is_recipient)],
       file.path(OUT, "xgb-primary-oof-predictions-v4.csv"))

cat("\n=== weighted-row RMSE specifically (the population we upweighted) ===\n")
hi <- ALL[permit == 1 | is_recipient == 1]
cat(sprintf("n=%d  shipped RMSE %.3f  xgb v4 RMSE %.3f\n", nrow(hi),
            sqrt(mean((hi$pred_share - hi$actual_share)^2)),
            sqrt(mean((hi$xgb_pred_v4 - hi$actual_share)^2))))

cat("\n=== SA2026 ONP specifically ===\n")
sa <- ALL[pair == "sa2026" & party == "ONP"]
sa[, err_shipped := abs(pred_share - actual_share)]
sa[, err_v4 := abs(xgb_pred_v4 - actual_share)]
print(sa[order(-err_shipped), .(seat, actual_share = round(actual_share,1), pred_share = round(pred_share,1),
                                 xgb_v4 = round(xgb_pred_v4,1), is_recipient, permit)][1:10])
cat(sprintf("\nSA ONP mean abs error: shipped %.2f -> xgb v1 5.52 -> xgb v4 (weighted) %.2f\n",
            mean(sa$err_shipped), mean(sa$err_v4)))
