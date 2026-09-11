# v6: v5's full feature set (seat-file + personal-vote + candidacy features)
# PLUS the salience/emergence features from v4 (jump, governed, permit,
# surge_h, is_recipient). Built to test a specific hypothesis: v5's live
# smoke-test showed a severe, previously-underappreciated side effect --
# statewide IND/OTH_RIGHT share collapses ~10x/~180x across Victoria's 87
# seats, 55 of 87 predicting IND=0 AND OTH_RIGHT=0 exactly. v5's features
# describe individual candidates/seats but give the model no way to say
# "this specific independent/minor candidate is showing real signs of a
# genuine emergence" -- exactly what jump/governed/permit/surge_h/is_recipient
# exist to signal. Without that, xgb has nothing to justify a non-trivial
# IND/OTH_RIGHT prediction anywhere and shrinks the whole class toward its
# typical near-zero outcome.
#
# Reuses v5's base-feature loop (scripts/fit_xgb_primary_v5.R) and v4's
# salience-population logic (scripts/fit_xgb_primary_v4.R) EXACTLY, including
# both bugs already found and fixed this session in v4: the SAL merge is
# deduplicated to one row per (pair,seat,party) before merging (an
# uncontrolled merge against governed_population()'s one-row-per-candidate
# output silently duplicated 6% of rows before this fix), and permit's
# NA-default is 1 (protect/flag), not 0 ("no claim" must not mean "verified
# safe" -- inverts salience_screen()'s own convention).
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
# Salience/surge population is NOT available for WA (no seat-level salience
# corpus built there -- same gap already found for v1-v4). Kept as its own
# list, matching v4 exactly, rather than silently extending to WA with data
# that does not exist.
SAL_PAIRS <- Filter(function(p) p$region != "wa", PAIRS)
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

cat("=== building v6 feature matrix (v5 base + salience/surge from v4) ===\n")
rows <- list()
seat_file_hits <- 0L; seat_file_pairs <- character(0)
for (pr in PAIRS) {
  lp <- state_level(pr$prev); ln <- state_level(pr$election)
  if (is.null(lp) || is.null(ln)) { cat(sprintf("XG6! no state level for %s -> skip\n", pr$election)); next }
  prevc <- C[C$election == pr$prev][, list(x = sum(pcv, na.rm = TRUE), n_cand_prev = .N), by = list(seat, party)]
  nowc  <- C[C$election == pr$election][, list(n_cand_now = .N), by = list(seat, party)]
  ret <- tryCatch(candidate_returns(pr$prev, pr$election), error = function(e) NULL)
  pv  <- tryCatch(personal_prior_vote(pr$prev, pr$election), error = function(e) NULL)
  sd_pair <- SD[pair == pr$election]
  if (!nrow(sd_pair)) { cat(sprintf("XG6! no sharedetail rows for %s -> skip\n", pr$election)); next }

  m <- merge(sd_pair, prevc, by = c("seat", "party"), all.x = TRUE)
  m <- merge(m, nowc, by = c("seat", "party"), all.x = TRUE)
  m <- merge(m, lp[, list(party, level_prev = level)], by = "party", all.x = TRUE)
  # THE STATEWIDE THE MODEL IS ALLOWED TO SEE. AUSPOL_LEVEL_MODE:
  #   "pred" (default) -- output/level-pred.csv, the poll trend plus
  #        leave-one-out fundamentals as at the day BEFORE polling day. Nothing
  #        here sees the result. Mean absolute error 2.06 points per class.
  #   "now"  -- state_level(pr$election), the ACTUAL statewide result. This is
  #        the original behaviour and it is leakage; kept only so the cost can
  #        be re-measured, never as a default.
  #   "none" -- neither. Measured and REJECTED as the fix: deleting the feature
  #        removes the model's only route to knowing what is happening
  #        nationally, and sa2026 went 0.4200 -> 0.6309. Pete's instruction was
  #        to substitute a prediction, not to remove the information.
  .lvl_mode <- Sys.getenv("AUSPOL_LEVEL_MODE", "pred")
  if (!.lvl_mode %in% c("pred", "now", "none"))
    stop("AUSPOL_LEVEL_MODE must be pred, now or none; got ", .lvl_mode)
  if (identical(.lvl_mode, "now")) {
    m <- merge(m, ln[, list(party, level_now = level)], by = "party", all.x = TRUE)
  } else if (identical(.lvl_mode, "pred")) {
    lpf <- file.path(OUT, "level-pred.csv")
    if (!file.exists(lpf)) stop("AUSPOL_LEVEL_MODE=pred needs ", lpf,
                                " -- run scripts/build_level_pred.R first")
    LPRED <- data.table::fread(lpf, showProgress = FALSE)
    lp1 <- LPRED[LPRED$pair == pr$election, list(party, level_now = level_pred,
                                                  level_from_polls = from_polls)]
    if (!nrow(lp1)) stop("no predicted statewide for ", pr$election,
                         " -- a pair silently missing here becomes a column of NAs ",
                         "that xgboost splits on as though it were a value")
    m <- merge(m, lp1, by = "party", all.x = TRUE)
  }
  # The column keeps the name `level_now` in every mode so the feature list,
  # the saved models and every downstream reader stay on one name. What CHANGES
  # is where it comes from, which is recorded in the run banner below rather
  # than left to be inferred from a filename.
  if (!is.null(ret)) m <- merge(m, ret, by = c("seat", "party"), all.x = TRUE)
  if (!is.null(pv))  m <- merge(m, pv[, list(seat, party, own_prev_pcv)], by = c("seat", "party"), all.x = TRUE)

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

# ============================ salience/surge, from v4 =======================
sal_rows <- list()
for (pr in SAL_PAIRS) {
  s <- tryCatch(governed_population(pr$election, pr$prev, pr$region), error = function(e) NULL)
  if (is.null(s) || !nrow(s)) next
  s[, permit := salience_screen(jump, governed)]
  sal_rows[[pr$election]] <- s[, .(pair = pr$election, seat, party, jump, governed = as.integer(governed), permit = as.integer(permit))]
}
SAL <- rbindlist(sal_rows, fill = TRUE)
# governed_population() emits one row per NAMED CANDIDATE; ALL is one row per
# (pair, seat, party). Collapsed to "any candidate in the cell fires" BEFORE
# merging, with a row-count assertion -- see fit_xgb_primary_v4.R's identical
# fix and its comment for why an uncontrolled merge here is dangerous.
SAL <- SAL[, .(permit = as.integer(any(permit == 1)),
               governed = as.integer(any(governed == 1)),
               jump = max(jump, na.rm = TRUE)),
           by = .(pair, seat, party)]
n_before <- nrow(ALL)
ALL <- merge(ALL, SAL, by = c("pair","seat","party"), all.x = TRUE)
stopifnot(nrow(ALL) == n_before)
ALL[, jump := ifelse(is.na(jump), 0, jump)]
ALL[, governed := ifelse(is.na(governed), 0L, governed)]
# "No claim" must default to "protect this row", not "verified safe" -- see
# fit_xgb_primary_v4.R's identical fix and docs/reviews/
# xgb-primary-flag-bugfixes-2026-09-10.md for why the other direction is a bug.
ALL[, permit := ifelse(is.na(permit), 1L, permit)]

surging_rows <- list()
for (pr in SAL_PAIRS) {
  py <- as.integer(sub("^[a-z]+", "", pr$prev)); yr <- as.integer(sub("^[a-z]+", "", pr$election))
  sp <- tryCatch(surging_parties(pr$region, py, yr), error = function(e) character(0))
  if (!length(sp)) next
  surging_rows[[pr$election]] <- data.table(pair = pr$election, party = sp, surging = 1L)
}
SURGING <- rbindlist(surging_rows, fill = TRUE)
ALL <- merge(ALL, SURGING, by = c("pair","party"), all.x = TRUE)
ALL[, surging := ifelse(is.na(surging), 0L, surging)]

surge_rows <- list()
for (pr in SAL_PAIRS) {
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

cat(sprintf("\nbuilt %d rows across %d pairs, %d cols\n", nrow(ALL), length(unique(ALL$pair)), ncol(ALL)))

fwrite(ALL, file.path(OUT, "xgb-primary-features-v6.csv"))
cat(sprintf("wrote %s\n\n", file.path(OUT, "xgb-primary-features-v6.csv")))

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

# AUSPOL_NO_LEVEL_NOW=1 drops `level_now`, which is state_level(pr$election) --
# the party's ACTUAL statewide share at the election being predicted.
#
# Pete, 2026-09-11: "its not deliberate - you decided this without telling me
# ---- everything for an election forecast shold be predictive!!!"  He is
# right. The harness banner calls the oracle statewide "this harness's whole
# design", but that was a choice made in code and never put to him, and
# describing it afterwards as deliberate let the decision stand unexamined.
#
# Measured cost of the oracle statewide overall, federal, 7 pairs: seat log
# loss 0.2936 told-the-answer vs 0.2982 predicting it from polls, +0.0047, and
# actually BETTER in 3 of 7. So the model does not lean on it -- but "small"
# is not "allowed", and a forecast feature has to be knowable before the vote.
.lvl_mode <- Sys.getenv("AUSPOL_LEVEL_MODE", "pred")
cat(sprintf("\n=== STATEWIDE SOURCE: %s === %s\n", .lvl_mode,
            switch(.lvl_mode,
                   pred = "predicted from polls the day before -- leakage-free",
                   now  = "the ACTUAL result -- LEAKED, for measurement only",
                   none = "no statewide feature at all")))
if (identical(.lvl_mode, "pred") && "level_from_polls" %in% names(ALL))
  cat(sprintf("    %d of %d rows have a poll-based prediction; the rest fall back to no-swing\n",
              sum(ALL$level_from_polls == 1L, na.rm = TRUE), nrow(ALL)))
feat_cols <- c("pred_share", "x", "level_prev",
               if (!identical(.lvl_mode, "none")) "level_now",
               # `level_from_polls` marks the rows whose statewide is the
               # no-swing fallback rather than a poll-based projection -- it
               # tells the model how much to trust level_now on that row.
               # Dropping it costs 0.014 of primary RMSE (3.9201 -> 3.9341),
               # so it stays, and xgb_primary_predict_live() sets it to 1L to
               # match: a live forecast always has polls, or it would not be
               # running. Both models therefore carry the SAME feature set,
               # which is the train/serve consistency this change exists for.
               if (identical(.lvl_mode, "pred")) "level_from_polls",
               "dev_prev",
               "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
               "margin", "fed_swing", "retirement_i", "soph_cand_i", "soph_party_i",
               "prev_swing", "is_incumbent_party_i", "own_prev_pcv",
               "historic_elected_i", "ballot_pos_min",
               "jump", "governed", "permit", "surge_h", "is_recipient",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share

# PERSIST THE FEATURE MATRIX. scripts/fit_xgb_flows_v1.R writes its own
# (xgb-flows-v1-features.csv) and this script did not, so anything wanting to
# model something ELSE about these rows had to either re-run this whole script
# or make do with the eleven columns the oof file carries.
#
# That is not hypothetical: on 2026-09-11 the emergence model was built on
# those eleven columns -- 7 real predictors out of the 25 here -- and the
# missing ones were exactly the plausible ones (retirement_i, margin,
# same_mp_i, own_prev_pcv, n_cand_now, historic_elected_i). It then concluded
# "we cannot predict who surges", which is a claim about the crippled feature
# set, not about the problem. Same shape as benchmarking a deliberately limited
# implementation and calling the result evidence about the design.
fwrite(ALL[, c("pair", "seat", "party", "actual_share", ..feat_cols)],
       file.path(OUT, "xgb-primary-v6-features.csv"))
cat(sprintf("wrote %s/xgb-primary-v6-features.csv (%d rows, %d features)\n",
            OUT, nrow(ALL), length(feat_cols)))

pairs <- sort(unique(ALL$pair))
fold_id <- match(ALL$pair, pairs)
dtrain <- xgb.DMatrix(data = X, label = y, missing = NA)

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

cat("\nrunning xgb.cv, grouped folds by election pair (leave-one-pair-out), same params as v5...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 2000, folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)

best_n <- cv$early_stop$best_iteration
cat(sprintf("best nrounds: %d\n", best_n))
oof_pred <- cv$cv_predict$pred[, 1]
xgb_rmse <- sqrt(mean((oof_pred - y)^2))
cat(sprintf("\nXGBOOST v6 (leave-one-pair-out) pooled primary RMSE: %.4f  (n=%d)\n", xgb_rmse, length(y)))
cat(sprintf("improvement vs shipped model: %.2f%%\n", 100 * (base_rmse - xgb_rmse) / base_rmse))

final <- xgb.train(params = params, data = dtrain, nrounds = best_n, verbose = 0)
imp <- xgb.importance(feature_names = feat_cols, model = final)
cat("\ntop 20 features by gain:\n")
print(head(imp, 20))

ALL[, xgb_pred := oof_pred]
fwrite(ALL[, .(pair, seat, party, pred_share, actual_share, xgb_pred, jump, governed, permit, surge_h, is_recipient)],
       file.path(OUT, "xgb-primary-v6-oof-predictions.csv"))
cat(sprintf("\nwrote %s\n", file.path(OUT, "xgb-primary-v6-oof-predictions.csv")))

cat("\nRMSE by jurisdiction (shipped vs xgb v6):\n")
print(ALL[, .(n = .N,
              shipped_rmse = sqrt(mean((pred_share - actual_share)^2)),
              xgb_rmse = sqrt(mean((xgb_pred - actual_share)^2))), by = region])

cat("\nsa2026 ONP check:\n")
sa_onp <- ALL[pair == "sa2026" & party == "ONP"]
sa_onp[, err_shipped := abs(pred_share - actual_share)]
sa_onp[, err_v6 := abs(xgb_pred - actual_share)]
print(sa_onp[order(-err_shipped), .(seat, actual_share = round(actual_share,1), pred_share = round(pred_share,1),
                                     xgb_v6 = round(xgb_pred,1), permit, is_recipient)])
cat(sprintf("\nSA ONP mean abs error: shipped %.3f -> xgb v6 %.3f\n",
            mean(sa_onp$err_shipped), mean(sa_onp$err_v6)))

cat("\nvic2022 IND/OTH_RIGHT degeneracy check:\n")
vic <- ALL[pair == "vic2022" & party %in% c("IND", "OTH_RIGHT")]
print(vic[, .(sum_pred_share = sum(pred_share), sum_xgb_pred = sum(xgb_pred),
              n_zero_pred = sum(xgb_pred < 0.05)), by = party])
