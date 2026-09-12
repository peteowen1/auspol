# SHAP inside the IND model, and an ablation of whatever is dragging Spender.
# Pete, 2026-09-12: "in the non major primary prediction model what the shap for
# spender is it the same things giving her issue? Try removing them from the
# model see how it looks (maybe these aren't as relevant for a non-major model)"
#
# THE PUZZLE. The salience curve, fitted leave-one-pair-out and now isotonic so
# it matches the band means almost exactly, says an independent at Spender's
# 0.9948 percentile polls 30.3. The candidate-driven model is handed that number
# and outputs 13.8. Something inside is taking 16 points off her.
#
# "IND model" throughout = the candidate_driven group (IND, OTH, OTH_RIGHT).
# Pete's name for it, and it is the population the salience machinery serves.
#
# Emits XI* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
FE <- fread(file.path(OUT, "xgb-primary-v7-features.csv"), showProgress = FALSE)
CAND_DRIVEN <- c("IND", "OTH", "OTH_RIGHT")
FE <- FE[party %in% CAND_DRIVEN]
feat <- setdiff(names(FE), c("pair", "seat", "party", "actual_share"))
# Columns that are constant once the majors are gone carry no information and
# only clutter a SHAP table.
const <- feat[vapply(feat, function(f) {
  v <- FE[[f]]; all(!is.finite(v)) || length(unique(v[is.finite(v)])) <= 1
}, TRUE)]
feat <- setdiff(feat, const)
cat(sprintf("XI1  IND model population: %d cells (%s), %d usable features\n",
            nrow(FE), paste(CAND_DRIVEN, collapse = "/"), length(feat)))
if (length(const)) cat(sprintf("XI1  dropped as constant here: %s\n", paste(const, collapse = ", ")))

HOLD <- "fed2022"
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
fit_arm <- function(cols, tag) {
  M <- as.matrix(FE[, cols, with = FALSE])
  tr <- which(FE$pair != HOLD); te <- which(FE$pair == HOLD)
  set.seed(42)
  m <- xgb.train(params, xgb.DMatrix(M[tr, , drop = FALSE],
                                     label = FE$actual_share[tr], missing = NA),
                 nrounds = 120, verbose = 0)
  p <- predict(m, M[te, , drop = FALSE])
  list(model = m, M = M, te = te, pred = p, tag = tag, cols = cols)
}

base <- fit_arm(feat, "all features")
iw <- which(FE$pair == HOLD & FE$seat == "Wentworth" & FE$party == "IND")
stopifnot(length(iw) == 1)
row_in_te <- match(iw, base$te)

SH <- predict(base$model, base$M[iw, , drop = FALSE], predcontrib = TRUE)
colnames(SH) <- c(base$cols, "BIAS")
v <- SH[1, ]; bias <- v[["BIAS"]]; v <- v[names(v) != "BIAS"]
cat(sprintf("\nXI2  SPENDER inside the IND model: base %.2f + contributions %.2f = %.2f (actual 35.8)\n",
            bias, sum(v), bias + sum(v)))
cat("XI2  every feature, points of primary vote, biggest mover first.\n")
full <- data.table(feature = names(v),
                   value = round(unlist(FE[iw, names(v), with = FALSE]), 3),
                   shap_points = round(unname(v), 3))
print(full[order(-abs(shap_points))], nrows = 60)

# ---- the ablation Pete asked for ------------------------------------------
# Drop the features that are pulling her down and see what the model says. Each
# is removed on its own AND cumulatively, because they are correlated -- taking
# out dev_prev alone may just push the same effect through x.
drags <- full[shap_points < 0][order(shap_points)]$feature
drags <- head(intersect(drags, feat), 6)
cat(sprintf("\nXI3  ablation. The six features costing her most: %s\n",
            paste(drags, collapse = ", ")))
cat("XI3  pred is what the IND model says for Wentworth; actual 35.8. RMSE is\n")
cat("XI3  over ALL held-out fed2022 cells of this group -- the do-no-harm guard,\n")
cat("XI3  because removing a feature that helps everywhere to fix one seat is a loss.\n")
rows <- list(data.table(dropped = "nothing", n_feat = length(feat),
                        wentworth = round(base$pred[row_in_te], 1),
                        rmse_fed2022 = round(sqrt(mean((base$pred - FE$actual_share[base$te])^2)), 3)))
for (d in drags) {
  a <- fit_arm(setdiff(feat, d), d)
  rows[[length(rows) + 1]] <- data.table(
    dropped = d, n_feat = length(a$cols),
    wentworth = round(a$pred[row_in_te], 1),
    rmse_fed2022 = round(sqrt(mean((a$pred - FE$actual_share[a$te])^2)), 3))
}
cum <- feat
for (d in drags) {
  cum <- setdiff(cum, d)
  a <- fit_arm(cum, paste("cumulative through", d))
  rows[[length(rows) + 1]] <- data.table(
    dropped = paste0("+ ", d, " (cumulative)"), n_feat = length(cum),
    wentworth = round(a$pred[row_in_te], 1),
    rmse_fed2022 = round(sqrt(mean((a$pred - FE$actual_share[a$te])^2)), 3))
}
print(rbindlist(rows))

# ---- what if the model had ONLY the salience evidence? --------------------
cat("\nXI4  the opposite test: give it only salience and the seat's own history.\n")
cat("XI4  If this beats the full model on fed2022 IND cells, the other 40 features\n")
cat("XI4  are net harmful for this population, which is a real finding.\n")
small <- intersect(c("sal_exp", "jump_pctile", "x", "ret_exp", "cand_all_new",
                     "n_cand_now", "party_IND", "party_OTH", "party_OTH_RIGHT"), feat)
a <- fit_arm(small, "salience only")
ind_te <- which(FE$pair == HOLD & FE$party == "IND")
ind_in_te <- match(ind_te, base$te)
cat(sprintf("XI4  features: %s\n", paste(small, collapse = ", ")))
print(data.table(
  model = c("all features", "salience only"),
  n_feat = c(length(feat), length(small)),
  wentworth = c(round(base$pred[row_in_te], 1), round(a$pred[row_in_te], 1)),
  rmse_all_cells = c(round(sqrt(mean((base$pred - FE$actual_share[base$te])^2)), 3),
                     round(sqrt(mean((a$pred - FE$actual_share[a$te])^2)), 3)),
  rmse_IND_only = c(round(sqrt(mean((base$pred[ind_in_te] - FE$actual_share[ind_te])^2)), 3),
                    round(sqrt(mean((a$pred[ind_in_te] - FE$actual_share[ind_te])^2)), 3))))

TEALS <- c("Wentworth", "Mackellar", "Kooyong", "Curtin", "North Sydney", "Goldstein")
tl <- which(FE$pair == HOLD & FE$party == "IND" & FE$seat %in% TEALS)
cat("\nXI5  all six teals under both models:\n")
print(data.table(seat = FE$seat[tl], actual = round(FE$actual_share[tl], 1),
                 sal_exp = round(FE$sal_exp[tl], 1),
                 all_features = round(base$pred[match(tl, base$te)], 1),
                 salience_only = round(a$pred[match(tl, a$te)], 1))[order(-actual)])
