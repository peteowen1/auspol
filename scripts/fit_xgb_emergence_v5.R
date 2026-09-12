# Emergence model, CANDIDATE level -- what Pete asked for on 2026-08-27.
#
# WHO THIS MODELS, and it is a short list: IND, OTH, OTH_RIGHT.
#
# ALP, LNP and NAT are dropped upstream in build_emergence_cases_v2.R. GRN and
# ONP are dropped HERE, on Pete's instruction (2026-09-12): they are organised
# parties that run a candidate in most seats under a brand the voter already
# knows, so the pipeline forecasts their statewide primary from polling and
# distributes it to seats exactly as it does for Labor and the Coalition. They
# do not need a surge mechanism, and giving them one double-counts.
#
# The surge exists for the candidate who appears from nowhere -- an independent
# or a micro-party vehicle with no statewide poll behind it. That is why the
# baseline is always the PERSON's own previous vote in that seat: for these
# classes the vote travels with the individual, not the label.
#
# WHY v1-v4 FAILED. They modelled the party CLASS in a seat. Wentworth's IND
# vote went 33.0 -> 35.8, a rise of 2.8, so it scored as a non-event -- while
# Kerryn Phelps (32.4% in 2019) did not stand and Allegra SPENDER went from
# nothing to 35.8%. Three of the six 2022 teals were TRAINING NEGATIVES in the
# model built to predict teals, and v4 gave Wentworth a 1.1% hazard.
#
# Three models, all leave-one-pair-out:
#   1. hazard    P(this candidate's own vote jumps >= 10 points)
#   2. magnitude how big the jump is, given that it happens
#   3. spread    how uncertain that magnitude is
# then a per-seat step choosing one recipient and calibrating its hazard.
#
# NOTE ON level_now. The v6 feature file carries a column called `level_now`
# which is the ACTUAL statewide share under AUSPOL_LEVEL_MODE="now" and a
# PREDICTION under "pred". The file on disk does not record which mode wrote
# it, so it is excluded here rather than assumed clean. `level_from_polls` is
# poll-derived in every mode and carries most of the same signal.
#
# Emits X5* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
RISE <- as.numeric(Sys.getenv("AUSPOL_EMERGE_RISE", "10"))  # same default and
                                    # same env var as build_emergence_cases_v2.R
# The classes the surge is for. Everything else is forecast from polling.
SURGE_CLASSES <- c("IND", "OTH", "OTH_RIGHT")

A <- fread(file.path(OUT, "emergence-cases-v2.csv"), showProgress = FALSE)
cat(sprintf("X51  %d non-major candidate-rows on disk, classes: %s\n",
            nrow(A), paste(sort(unique(A$party)), collapse = " ")))
A <- A[party %in% SURGE_CLASSES]
cat(sprintf("X51  %d rows after dropping GRN/ONP (polled parties, not surge candidates)\n", nrow(A)))
stopifnot(nrow(A) > 0)

FE <- fread(file.path(OUT, "xgb-primary-v6-features.csv"), showProgress = FALSE)

# Seat-level context from the primary model's feature matrix, joined by
# (pair, seat, party). These describe the CONTEST, so every candidate of a
# class in a seat shares them -- the candidate-level columns are what separate
# one IND from the four others on the same ballot.
#   jump/governed/permit/surge_h/is_recipient are the Google Trends salience
#   block: campaign rise in search interest, and whether the nomination gate
#   lets it count. That is the block most likely to see a teal.
ctx <- c("margin", "fed_swing", "retirement_i", "soph_cand_i", "soph_party_i",
         "prev_swing", "is_incumbent_party_i", "same_mp_i", "dev_prev",
         "level_prev", "level_from_polls", "n_cand_prev", "n_cand_now",
         "historic_elected_i", "ballot_pos_min", "pred_share",
         "jump", "governed", "permit", "surge_h", "is_recipient")
ctx <- intersect(ctx, names(FE))
stopifnot(!"level_now" %in% ctx, !"actual_share" %in% ctx)
FE[, ctx_row := 1L]   # explicit merge indicator: never infer "did the join hit?"
                      # from whether some column is populated -- `margin` needs a
                      # prior two-party result and is legitimately NA on 13 pairs,
                      # which read as 0% join coverage and sent me chasing a
                      # seat-name mismatch that did not exist.
X <- merge(A, FE[, c("pair", "seat", "party", "ctx_row", ..ctx)],
           by = c("pair", "seat", "party"), all.x = TRUE)
stopifnot(nrow(X) == nrow(A))   # many-to-one; a blow-up here means dup context rows
X[is.na(ctx_row), ctx_row := 0L]
cat(sprintf("X51  %d rows, %d matched a seat-context row (%.1f%%)\n",
            nrow(X), sum(X$ctx_row), 100 * mean(X$ctx_row)))
# Join coverage and FILL are different questions. Print per-column fill so a
# feature that is present but empty cannot hide behind xgboost's NA handling.
fill <- X[, lapply(.SD, function(v) round(100 * mean(!is.na(v)), 1)), .SDcols = ctx]
cat("X51  per-feature fill %, lowest first (100 = always populated):\n")
print(head(data.table(feature = names(fill), fill_pct = unlist(fill))[order(fill_pct)], 8))

CLASSES <- sort(unique(X$party))
X[, region := sub("[0-9]{4}$", "", pair)]
REGIONS <- sort(unique(X$region))
for (p in CLASSES) X[[paste0("cls_", p)]] <- as.integer(X$party == p)
for (r in REGIONS) X[[paste0("reg_", r)]] <- as.integer(X$region == r)
X[, ballot_pos := suppressWarnings(as.numeric(ballot_position))]

feat <- c("own_prev", "cls_prev", "stood_before", "ballot_pos", ctx,
          paste0("cls_", CLASSES), paste0("reg_", REGIONS))
feat <- intersect(feat, names(X))
M <- as.matrix(X[, ..feat])
PAIRS <- sort(unique(X$pair))
fold <- match(X$pair, PAIRS)
folds <- split(seq_len(nrow(M)), fold)
cat(sprintf("X51  %d features over %d pairs | %d emergences of %d = %.2f%% base rate\n",
            length(feat), length(PAIRS), sum(X$emerged), nrow(X), 100 * mean(X$emerged)))
cat("X51  target: this PERSON's own vote rose >= 10 points on what THEY polled in THIS seat\n")
cat("X51  last time, counting zero if they did not stand.\n")
print(X[, .(candidates = .N, emerged = sum(emerged),
            rate = sprintf("%.1f%%", 100 * mean(emerged)),
            first_time = sprintf("%.0f%%", 100 * mean(stood_before == 0)),
            mean_rise = round(mean(rise[emerged == 1]), 1)), by = party][order(-emerged)])

auc <- function(s, l) {
  r <- rank(s); n1 <- sum(l); n0 <- sum(!l)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  (sum(r[l == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# ---- 1. hazard: does THIS candidate jump? ---------------------------------
pc <- list(objective = "binary:logistic", eval_metric = "logloss", eta = 0.05,
           max_depth = 5, subsample = 0.8, colsample_bytree = 0.8,
           min_child_weight = 10)
set.seed(42)
cv1 <- xgb.cv(params = pc, data = xgb.DMatrix(M, label = X$emerged, missing = NA),
              nrounds = 800, folds = folds, early_stopping_rounds = 30,
              prediction = TRUE, verbose = 0)
X[, p_emerge := cv1$cv_predict$pred[, 1]]
cat(sprintf("\nX52  hazard: %d rounds | out-of-fold AUC %.3f\n",
            max(cv1$early_stop$best_iteration, 20L), auc(X$p_emerge, X$emerged)))
cat("X52  AUC is rank accuracy: P(a real emergence scores above a non-emergence). 0.5 is a coin toss.\n")
cat("X52  v4's 0.931 is NOT comparable -- different population and a 1.5% base rate, far easier to rank.\n")
print(X[, .(n = .N, emerged = sum(emerged), auc = round(auc(p_emerge, emerged), 3),
            p_if_emerged = round(mean(p_emerge[emerged == 1]), 3),
            p_if_not = round(mean(p_emerge[emerged == 0]), 3)),
        by = party][order(-emerged)])

# ---- 2+3. magnitude and spread, given a jump ------------------------------
# Leave-one-pair-out by hand rather than xgb.cv, because these two models train
# ONLY on emerged rows but must score EVERY row -- the simulator needs a jump
# size for every candidate it might fire on, not just the ones that did jump.
# xgb.cv would only ever hand back predictions for the training population.
pr <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
           subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 10)
X[, `:=`(mu = NA_real_, sd = NA_real_)]
for (i in seq_along(PAIRS)) {
  tr <- X$pair != PAIRS[i] & X$emerged == 1L
  if (sum(tr) < 50) { cat(sprintf("X53! %s: only %d training emergences -- skipped\n",
                                  PAIRS[i], sum(tr))); next }
  Mtr <- M[tr, , drop = FALSE]
  set.seed(42)
  fm <- xgb.train(pr, xgb.DMatrix(Mtr, label = X$rise[tr], missing = NA),
                  nrounds = 200, verbose = 0)
  # Spread from the absolute residual of the magnitude fit. E|e| = sd*sqrt(2/pi)
  # for a normal, so dividing by that constant turns a mean-absolute-error
  # prediction back into the sd the simulator wants.
  res <- abs(X$rise[tr] - predict(fm, Mtr))
  set.seed(42)
  fs <- xgb.train(pr, xgb.DMatrix(Mtr, label = res, missing = NA),
                  nrounds = 200, verbose = 0)
  te <- which(X$pair == PAIRS[i])
  Mte <- M[te, , drop = FALSE]
  set(X, te, "mu", pmax(1, predict(fm, Mte)))
  set(X, te, "sd", pmax(1, predict(fs, Mte) / sqrt(2 / pi)))
}
ok <- X[emerged == 1L & !is.na(mu)]
cat(sprintf("\nX53  magnitude: trained on %d emergences (v4 had 201).\n", sum(X$emerged)))
cat(sprintf("X53  held-out RMSE %.2f pts against a %.2f-point spread in the truth. Lower is better;\n",
            sqrt(mean((ok$mu - ok$rise)^2)), sd(ok$rise)))
cat("X53  RMSE at or above the spread means the model is not beating a flat mean.\n")
cat(sprintf("X53  spread model: mean predicted sd %.2f pts\n", mean(X$sd, na.rm = TRUE)))

# ---- the test that matters ------------------------------------------------
cat("\nX54  THE SIX fed2022 TEALS. v4 gave Wentworth 1.1%, Mackellar 1.3%.\n")
TEALS <- c("Wentworth", "Mackellar", "Kooyong", "Curtin", "North Sydney", "Goldstein")
tl <- X[pair == "fed2022" & party == "IND" & seat %in% TEALS]
tl <- tl[, .SD[which.max(pcv)], by = seat][order(-p_emerge)]
cat("X54  chance is the hazard; pred_jump and pred_sd are points of primary vote.\n")
print(tl[, .(seat, candidate = name, first_time = stood_before == 0,
             own_prev = round(own_prev, 1), actual = round(pcv, 1),
             chance = sprintf("%.1f%%", 100 * p_emerge),
             pred_jump = round(mu, 1), pred_sd = round(sd, 1))])
cat(sprintf("X54  flagged %d of 6 in the training data.\n", sum(tl$emerged)))

# ---- per-seat: who receives, and how often does it really happen ----------
# The simulator fires at ONE candidate per seat, so the recipient is the
# highest-hazard candidate there. But taking a maximum SELECTS on the
# prediction, so the winner's realised rate beats its stated probability --
# feeding the raw argmax into surge_h under-fires.
SEAT <- X[, .(hit = as.integer(emerged[which.max(p_emerge)] == 1L),
              max_p = max(p_emerge), n_cand = .N,
              top_class = party[which.max(p_emerge)]), by = .(pair, seat)]
S <- X[, .SD[which.max(p_emerge)], by = .(pair, seat)]
stopifnot(nrow(SEAT) == nrow(S),
          identical(paste(SEAT$pair, SEAT$seat), paste(S$pair, S$seat)))
cat(sprintf("\nX55  %d seats. raw argmax hazard %.3f against a %.1f%% realised rate -- the gap\n",
            nrow(SEAT), mean(SEAT$max_p), 100 * mean(SEAT$hit)))
cat("X55  is the selection effect, corrected below.\n")
print(SEAT[, .(seats = .N, raw_hazard = round(mean(max_p), 3),
               hit_rate = sprintf("%.1f%%", 100 * mean(hit))), by = top_class][order(-seats)])

# WHY ISOTONIC AND NOT ANOTHER XGBOOST. An xgboost seat model was tried first
# and scored AUC 0.665 -- WORSE at ranking seats than max_p alone at 0.739, the
# single feature it was built on. Early stopping on log loss reached a
# well-calibrated but badly-ranked point and quit at 20 rounds; it bought
# calibration by destroying signal.
#
# max_p already ranks seats well and only its LEVEL is wrong. Isotonic
# regression is the right tool: monotone, so it cannot reorder seats, and it
# fits the level freely. Leave-one-pair-out, and fitted WITHIN recipient class
# so each class answers for its own record rather than borrowing another's.
SEAT[, seat_h := NA_real_]
for (cl in CLASSES) {
  for (i in seq_along(PAIRS)) {
    tr <- which(SEAT$pair != PAIRS[i] & SEAT$top_class == cl)
    te <- which(SEAT$pair == PAIRS[i] & SEAT$top_class == cl)
    if (!length(te)) next
    if (length(tr) < 30) {
      cat(sprintf("X56! %s/%s: only %d training seats -- using class base rate\n",
                  PAIRS[i], cl, length(tr)))
      set(SEAT, te, "seat_h", if (length(tr)) mean(SEAT$hit[tr]) else mean(SEAT$hit))
      next
    }
    o <- order(SEAT$max_p[tr])
    ir <- isoreg(SEAT$max_p[tr][o], SEAT$hit[tr][o])
    # approx() with rule=2 clamps outside the training range rather than
    # returning NA, so a held-out seat more extreme than anything seen keeps the
    # nearest fitted rate instead of dropping out of the simulator entirely.
    set(SEAT, te, "seat_h",
        approx(ir$x, ir$yf, xout = SEAT$max_p[te], rule = 2, ties = "ordered")$y)
  }
}
stopifnot(all(is.finite(SEAT$seat_h)))
cat(sprintf("\nX56  RECIPIENT hazard, isotonic within class | AUC %.3f | base rate %.1f%% (%d of %d seats)\n",
            auc(SEAT$seat_h, SEAT$hit), 100 * mean(SEAT$hit),
            sum(SEAT$hit), nrow(SEAT)))
cat("X56  mean_h should now track hit_rate within each class:\n")
print(SEAT[, .(seats = .N, mean_h = round(mean(seat_h), 3),
               hit_rate = sprintf("%.1f%%", 100 * mean(hit))),
           by = top_class][order(-seats)])
cat("X56  calibration by predicted band. mean_pred and actual should match; n is seats.\n")
SEAT[, band := cut(seat_h, c(0, .02, .05, .10, .20, .40, 1), include.lowest = TRUE)]
print(SEAT[, .(seats = .N, mean_pred = round(mean(seat_h), 3),
               actual = round(mean(hit), 3)), by = band][order(band)])
cat("\nX56  PER PAIR. pred is the mean recipient hazard, actual the share of seats whose\n")
cat("X56  chosen recipient really emerged. Sorted by pred - actual: top rows UNDER-fire.\n")
print(SEAT[, .(seats = .N, pred = round(mean(seat_h), 3),
               actual = round(mean(hit), 3)), by = pair][order(pred - actual)])

fwrite(X[, .(pair, seat, party, name, pk, own_prev, cls_prev, pcv, rise,
             emerged, stood_before, p_emerge, mu, sd)],
       file.path(OUT, "xgb-emergence-v5-oof.csv"))
# The simulator's four per-seat parameters: whether (surge_h), who
# (surge_party), how big (surge_mu), how uncertain (surge_sd).
fwrite(SEAT[, .(pair, seat, surge_h = seat_h, surge_party = top_class,
                surge_mu = S$mu, surge_sd = S$sd, hit)],
       file.path(OUT, "xgb-emergence-v5-seat.csv"))
cat(sprintf("\nX57  wrote %s/xgb-emergence-v5-oof.csv (%d candidate rows)\n", OUT, nrow(X)))
cat(sprintf("X57  wrote %s/xgb-emergence-v5-seat.csv (%d seats, the simulator's shape)\n",
            OUT, nrow(SEAT)))
