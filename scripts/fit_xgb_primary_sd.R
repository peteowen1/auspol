# Predict the per-cell primary vote SD with xgboost. Pete, 2026-09-12:
# "let's just get xgboost to predict primary and primary_sd -- it should predict
#  primary and primary sd a bit better for real inds let's see"
#
# WHAT THIS REPLACES. The surge mechanism -- a Bernoulli hazard that adds a
# N(mu, sd) jump to one candidate per seat -- is being binned. It could rank WHO
# emerges within a seat but not WHETHER a given election produces a wave, so it
# fired ~14% surges into all 143 fed2019 seats where almost nothing happened and
# cost 0.229 of log loss there to buy 0.027 on fed2022. Pooled federal went
# 0.3010 -> 0.3440, 14% worse.
#
# THE REPLACEMENT IS HONEST UNCERTAINTY, NOT A MIXTURE. If the model cannot say
# which year has a teal wave, it should say so by being WIDE on candidates who
# could plausibly emerge, not by firing a coin-flip jump. A seat where an
# independent might poll 8 or might poll 35 has a large SD; the simulator then
# draws the whole range and the tail carries the emergence on its own. No
# hazard, no recipient, no double-count with the point estimate.
#
# THE TARGET. |actual_share - xgb_pred|, the absolute error of the primary
# prediction that actually ships. For a normal, E|e| = sd * sqrt(2/pi), so
# dividing a predicted mean-absolute-error by that constant converts it back to
# the SD the simulator wants.
#
# Leave-one-pair-out throughout: a pair is scored by a model that never saw it.
#
# Emits XD* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
P  <- fread(file.path(OUT, "xgb-primary-v6-oof-predictions.csv"), showProgress = FALSE)
FE <- fread(file.path(OUT, "xgb-primary-v6-features.csv"), showProgress = FALSE)

# level_now is the ACTUAL statewide share under AUSPOL_LEVEL_MODE="now" and a
# prediction under "pred". The file does not record which mode wrote it, so it
# is excluded rather than assumed clean. actual_share is the answer itself.
feat_ctx <- c("pred_share", "level_prev", "level_from_polls", "dev_prev",
              "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
              "margin", "fed_swing", "retirement_i", "soph_cand_i",
              "soph_party_i", "prev_swing", "is_incumbent_party_i",
              "own_prev_pcv", "historic_elected_i", "ballot_pos_min",
              "jump", "governed", "permit", "surge_h", "is_recipient",
              paste0("party_", c("ALP","GRN","IND","LNP","ONP","OTH","OTH_RIGHT")),
              paste0("region_", c("fed","nsw","qld","sa","vic","wa")))
feat_ctx <- intersect(feat_ctx, names(FE))
stopifnot(!"level_now" %in% feat_ctx, !"actual_share" %in% feat_ctx)

X <- merge(P[, .(pair, seat, party, actual_share, xgb_pred)],
           FE[, c("pair", "seat", "party", ..feat_ctx)],
           by = c("pair", "seat", "party"), all.x = TRUE)
stopifnot(nrow(X) == nrow(P))
cat(sprintf("XD1  %d cells over %d pairs, %d classes\n",
            nrow(X), uniqueN(X$pair), uniqueN(X$party)))
X <- X[is.finite(actual_share) & is.finite(xgb_pred)]
X[, resid := actual_share - xgb_pred]
X[, abs_resid := abs(resid)]
cat(sprintf("XD1  %d cells with both a prediction and a truth\n", nrow(X)))
cat("XD1  absolute error of the SHIPPED primary prediction, in points of vote, by class.\n")
cat("XD1  This is what the SD model has to predict -- note IND is by far the widest.\n")
print(X[, .(cells = .N, mean_abs_err = round(mean(abs_resid), 2),
            sd_of_resid = round(sd(resid), 2),
            p90_abs_err = round(quantile(abs_resid, 0.9), 2),
            worst = round(max(abs_resid), 1)), by = party][order(-mean_abs_err)])

# The constant every cell would get if we did not model this at all. This is the
# bar: a predicted SD that cannot beat one number for the whole corpus is not
# worth wiring in.
FLAT <- sd(X$resid)
cat(sprintf("\nXD1  flat baseline SD (one number for every cell): %.2f points\n", FLAT))

M <- as.matrix(X[, ..feat_ctx])
PAIRS <- sort(unique(X$pair))
pr <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 5,
           subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 20)

X[, sd_hat := NA_real_]
for (i in seq_along(PAIRS)) {
  tr <- which(X$pair != PAIRS[i])
  te <- which(X$pair == PAIRS[i])
  set.seed(42)
  fm <- xgb.train(pr, xgb.DMatrix(M[tr, , drop = FALSE],
                                  label = X$abs_resid[tr], missing = NA),
                  nrounds = 300, verbose = 0)
  # /sqrt(2/pi) converts a mean-absolute-error prediction into the SD of a
  # normal with that MAE. Floored at 0.3 points: a cell the model thinks is
  # perfectly predictable still must not be given zero variance, or the
  # simulator treats it as certain and a single surprise costs -log(eps).
  set(X, te, "sd_hat", pmax(0.3, predict(fm, M[te, , drop = FALSE]) / sqrt(2 / pi)))
}
stopifnot(all(is.finite(X$sd_hat)))

# ---- does it beat a flat SD? ----------------------------------------------
# Gaussian log score on the held-out residuals. Lower is better. This is the
# metric that matters: it rewards being wide where the model is wrong and
# narrow where it is right, and punishes both over- and under-confidence.
nll <- function(e, s) mean(log(s) + e^2 / (2 * s^2))
cat(sprintf("\nXD2  Gaussian negative log likelihood on held-out cells, lower is better.\n"))
cat(sprintf("XD2  flat SD %.2f: %.4f | xgb SD: %.4f | improvement %.4f\n",
            FLAT, nll(X$resid, FLAT), nll(X$resid, X$sd_hat),
            nll(X$resid, FLAT) - nll(X$resid, X$sd_hat)))
cat("\nXD2  by class. A negative 'gain' column means the flat SD was better there.\n")
print(X[, .(cells = .N,
            flat_nll = round(nll(resid, FLAT), 4),
            xgb_nll = round(nll(resid, sd_hat), 4),
            gain = round(nll(resid, FLAT) - nll(resid, sd_hat), 4),
            mean_sd_hat = round(mean(sd_hat), 2),
            realised_sd = round(sd(resid), 2)), by = party][order(-gain)])

# ---- is it calibrated? ----------------------------------------------------
cat("\nXD3  calibration. Cells bucketed by predicted SD; realised is the actual\n")
cat("XD3  spread of residuals in that bucket. These two columns should match.\n")
# unique(): the 0.3 floor piles many cells on one value, so the lower deciles
# collapse to identical breaks and cut() errors on them.
X[, bnd := cut(sd_hat, unique(quantile(sd_hat, seq(0, 1, 0.1))), include.lowest = TRUE)]
print(X[, .(cells = .N, mean_pred_sd = round(mean(sd_hat), 2),
            realised_sd = round(sd(resid), 2)), by = bnd][order(bnd)])

cat("\nXD4  THE CASE PETE NAMED -- real independents. fed2022 teal seats:\n")
TEALS <- c("Wentworth", "Mackellar", "Kooyong", "Curtin", "North Sydney", "Goldstein")
cat("XD4  pred is the primary forecast, sd_hat its stated uncertainty, both in points.\n")
cat("XD4  z is how many SDs the truth sat away -- |z| under about 2 means the\n")
cat("XD4  interval covered the outcome without a surge mechanism.\n")
print(X[pair == "fed2022" & party == "IND" & seat %in% TEALS,
        .(seat, pred = round(xgb_pred, 1), actual = round(actual_share, 1),
          sd_hat = round(sd_hat, 1), flat = round(FLAT, 1),
          z = round(resid / sd_hat, 2))][order(-actual)])

cat("\nXD4  all IND cells, by how big the actual vote was. The model needs to be\n")
cat("XD4  wide on the cells that turned out large, and it cannot know which in advance.\n")
X[, ind_band := cut(actual_share, c(-0.1, 2, 5, 10, 20, 100),
                    labels = c("0-2", "2-5", "5-10", "10-20", "20+"))]
print(X[party == "IND", .(cells = .N, mean_pred = round(mean(xgb_pred), 1),
                          mean_actual = round(mean(actual_share), 1),
                          mean_sd_hat = round(mean(sd_hat), 1),
                          realised_sd = round(sd(resid), 1)), by = ind_band][order(ind_band)])

fwrite(X[, .(pair, seat, party, xgb_pred, actual_share, resid, sd_hat)],
       file.path(OUT, "xgb-primary-sd-oof.csv"))
cat(sprintf("\nXD5  wrote %s/xgb-primary-sd-oof.csv (%d cells)\n", OUT, nrow(X)))
