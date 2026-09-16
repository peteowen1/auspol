# How much does a preference flow actually MOVE between elections?
#
# WHY. simulate_seat_contests() applies one flow rate identically in every
# draw, so a wrong rate is wrong in all 20,000 of them and the simulation
# cannot be uncertain about it -- the over-confidence its own docstring
# names. `flow_sd` exists to fix that but is a single global number, and
# measured 2026-09-16 a blanket flow_sd=15 made federal log loss WORSE
# (0.2543 -> 0.2607): it charges a rate backed by 43 events the same
# uncertainty as one backed by 1, and the corpus is mostly well-measured.
#
# So fit the uncertainty instead of picking it. Measured over 3,711
# consecutive observations of the same (from, survivors, to) cell, a flow
# drifts a mean 7.6 POINTS between elections, and that drift has real
# structure the model can use:
#
#   events behind the rate   1 -> 9.3pts   3-5 -> 7.2   11+ -> 6.7
#   gap since last seen    <=3y -> 7.4     9-12y -> 9.8  13y+ -> 9.7
#
# Mean |drift| in points by party class, with n, over the same 3,711
# observations. Both marginals are shown because the interesting thing is
# that they say nearly the same thing:
#
#   as DESTINATION  OTH_RIGHT 9.4 (388) · IND 8.4 (379) · ONP 8.4 (297)
#                   LNP 8.1 (900) · GRN 6.7 (607) · ALP 6.7 (878) · OTH 6.7 (262)
#   as SOURCE       LNP 9.3 (249) · ONP 8.0 (292) · OTH_RIGHT 7.8 (956)
#                   OTH 7.6 (862) · IND 7.2 (903) · GRN 7.1 (363) · ALP 6.0 (86)
#
# The intuition this was built on was that an unpredictable SOURCE -- an
# independent, a new minor -- is where the uncertainty lives. It is not:
# IND as a source sits at 7.2, below the 7.6 corpus mean, and the two
# marginals span almost the same range (6.0-9.3 as source, 6.7-9.4 as
# destination). Party class of either end is a weak signal. What the model
# actually leans on is how well the rate is MEASURED and how stale it is --
# see the FD3 gain table this script prints, where prev_n, n_surv and gap
# come out on top and no class feature is near them. Measuring first is the
# only reason that is known rather than assumed.
#
# Emits FD* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
feat_f <- file.path(OUT, "xgb-flows-v1-features.csv")
if (!file.exists(feat_f)) stop("run scripts/fit_xgb_flows_v1.R first -- need ", feat_f)
TX <- fread(feat_f, showProgress = FALSE)
TX[, el_year := as.integer(sub("^[a-z]+", "", election))]

# One rate per (cell, election), then the drift between consecutive sightings.
cell_el <- TX[, .(rate = mean(y), n_events = uniqueN(paste(seat, round)),
                  year = el_year[1], region = region[1], n_surv = n_survivors[1]),
              by = .(from, surv, to, election)]
setorder(cell_el, from, surv, to, year)
cell_el[, `:=`(prev_rate = shift(rate), prev_year = shift(year),
               prev_n = shift(n_events)), by = .(from, surv, to)]
D <- cell_el[!is.na(prev_rate) & year > prev_year]
D[, `:=`(drift = abs(rate - prev_rate), gap = year - prev_year)]
cat(sprintf("FD1  %d drift observations over %d cells; mean |drift| %.1f points\n",
            nrow(D), uniqueN(D[, paste(from, surv, to)]), 100 * mean(D$drift)))
# FD1b exists so the two class breakdowns in this file's header are
# REPRODUCIBLE rather than a number someone typed once. The header's claim is
# that class of either end is a weak signal; that is only checkable if the
# script prints both marginals with their counts.
cat("FD1b mean |drift| in points by class, with n -- header table's source:\n")
for (.end in c("from", "to")) {
  .b <- D[, .(pts = round(100 * mean(drift), 1), n = .N), by = c(.end)][order(-pts)]
  cat(sprintf("     as %-11s %s\n", if (.end == "from") "SOURCE" else "DESTINATION",
              paste(sprintf("%s %.1f (%d)", .b[[1]], .b$pts, .b$n), collapse = " · ")))
}

CLASSES <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
for (cl in CLASSES) D[[paste0("f_", cl)]] <- as.integer(D$from == cl)
for (cl in CLASSES) D[[paste0("t_", cl)]] <- as.integer(D$to == cl)
regions <- sort(unique(D$region))
for (r in regions) D[[paste0("r_", r)]] <- as.integer(D$region == r)
feat <- c("prev_n", "gap", "n_surv", paste0("f_", CLASSES), paste0("t_", CLASSES),
          paste0("r_", regions))

X <- as.matrix(D[, ..feat]); y <- D$drift
folds <- split(seq_len(nrow(D)), match(D$election, sort(unique(D$election))))
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 3,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 20)
set.seed(42)
cv <- xgb.cv(params = params, data = xgb.DMatrix(X, label = y), nrounds = 600,
             folds = folds, early_stopping_rounds = 30, prediction = TRUE, verbose = 0)
best_n <- max(cv$early_stop$best_iteration, 30L)
oof <- pmax(0, cv$cv_predict$pred[, 1])

# Is a FITTED sd better than the constant one flow_sd would use? The constant
# baseline is the corpus mean drift -- what a single global flow_sd amounts to.
rmse_fit <- sqrt(mean((oof - y)^2)); rmse_const <- sqrt(mean((mean(y) - y)^2))
cat(sprintf("FD2  predicting drift: fitted RMSE %.4f vs constant-mean %.4f (%+.1f%%)\n",
            rmse_fit, rmse_const, 100 * (rmse_fit - rmse_const) / rmse_const))
cat(sprintf("FD2  nrounds %d | fitted drift ranges %.1f to %.1f points\n",
            best_n, 100 * min(oof), 100 * max(oof)))

final <- xgb.train(params = params, data = xgb.DMatrix(X, label = y),
                   nrounds = best_n, verbose = 0)
xgb.save(final, file.path(OUT, "flow-drift-v1.model"))
writeLines(jsonlite::toJSON(feat), file.path(OUT, "flow-drift-v1-cols.json"))
imp <- xgb.importance(feature_names = feat, model = final)
cat("\nFD3  what actually predicts drift (top 8 by gain):\n"); print(head(imp, 8))

D[, drift_pred := oof]
fwrite(D[, .(from, surv, to, election, year, gap, prev_n, drift, drift_pred)],
       file.path(OUT, "flow-drift-v1-oof.csv"))
cat(sprintf("\nFD4  wrote %s/flow-drift-v1.model and its out-of-fold predictions\n", OUT))

# MEAN ABSOLUTE DEVIATION IS NOT A STANDARD DEVIATION. The target here is
# |drift|; for a normal variate sd = MAD * sqrt(pi/2) ~ 1.2533 * MAD. The
# consumer applies that conversion rather than feeding a MAD in where the
# simulator expects an sd, which would understate the spread by 20%.
cat(sprintf("FD5  consumers: sd = predicted_drift * %.4f (MAD -> sd)\n", sqrt(pi / 2)))
