# Where does the reduced IND feature set win and where does it lose?
# Pete, 2026-09-12: "is this just for INDs yeah (the ind model) how many INDS we
# talking? can you split by salience bins?"
#
# The headline from the CV run -- 9 features scoring 4.2569 pooled against the
# full set's 3.8710 -- is an average over a population that is not homogeneous.
# The six teals improved a lot under it and everything else got worse, so the
# aggregate hides the only comparison that matters: does the small set win where
# salience is high and lose where it is absent? If so the answer is not to pick
# one, it is to gate on salience.
#
# THE IND MODEL here is IND/OTH/OTH_RIGHT. One Nation is NOT in it: it belongs
# with ALP/LNP/GRN in the poll-anchored model, per Pete and per its own RMSE.
#
# Three feature sets, identical leave-one-pair-out folds:
#   full    everything the split model normally gets
#   medium  full minus the six the SHAP showed dragging Spender down
#   small   salience and the seat's own history only, 9 columns
#
# Emits XC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
FE <- fread(file.path(OUT, "xgb-primary-v7-features.csv"), showProgress = FALSE)
CAND <- c("IND", "OTH", "OTH_RIGHT")
FE <- FE[party %in% CAND]
allf <- setdiff(names(FE), c("pair", "seat", "party", "actual_share"))
# Columns with no variation once the majors and ONP are gone inform nothing.
allf <- allf[vapply(allf, function(f) {
  v <- FE[[f]]; any(is.finite(v)) && length(unique(v[is.finite(v)])) > 1
}, TRUE)]

IND_DROP  <- c("ballot_pos_min", "n_cand_now", "cand_best_own_prev",
               "own_prev_pcv", "jump", "soph_cand_i")
IND_SMALL <- c("sal_exp", "jump_pctile", "x", "ret_exp", "cand_all_new",
               "n_cand_now", "party_IND", "party_OTH", "party_OTH_RIGHT")
SETS <- list(full = allf,
             medium = setdiff(allf, IND_DROP),
             small = intersect(IND_SMALL, allf))
cat(sprintf("XC1  population: %d cells (%s) over %d pairs\n",
            nrow(FE), paste(CAND, collapse = "/"), uniqueN(FE$pair)))
print(FE[, .(cells = .N,
             with_salience = sum(jump_pctile > 0),
             mean_actual = round(mean(actual_share), 1)), by = party][order(-cells)])
cat(sprintf("XC1  feature counts -- full %d, medium %d, small %d\n",
            length(SETS$full), length(SETS$medium), length(SETS$small)))

PAIRS <- sort(unique(FE$pair))
folds <- split(seq_len(nrow(FE)), match(FE$pair, PAIRS))
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
for (nm in names(SETS)) {
  M <- as.matrix(FE[, SETS[[nm]], with = FALSE])
  set.seed(42)
  cv <- xgb.cv(params = params, data = xgb.DMatrix(M, label = FE$actual_share, missing = NA),
               nrounds = 1500, folds = folds, early_stopping_rounds = 30,
               prediction = TRUE, verbose = 0)
  FE[[paste0("p_", nm)]] <- cv$cv_predict$pred[, 1]
  cat(sprintf("XC2  %s: %d features, %d rounds, RMSE %.4f\n", nm, length(SETS[[nm]]),
              cv$early_stop$best_iteration,
              sqrt(mean((cv$cv_predict$pred[, 1] - FE$actual_share)^2))))
  rm(cv, M); invisible(gc(verbose = FALSE))
}

rmse <- function(p, a) sqrt(mean((p - a)^2))
cat("\nXC3  RMSE BY CLASS, points of primary vote, lower is better.\n")
print(FE[, .(cells = .N,
             full = round(rmse(p_full, actual_share), 3),
             medium = round(rmse(p_medium, actual_share), 3),
             small = round(rmse(p_small, actual_share), 3)), by = party][order(-cells)])

cat("\nXC4  THE QUESTION: RMSE BY SALIENCE BIN. n is cells in that bin.\n")
cat("XC4  If small wins only in the top bins, the answer is to gate on salience\n")
cat("XC4  rather than to choose one feature set for the whole population.\n")
FE[, sb := cut(jump_pctile, c(-.01, 0.0001, .5, .9, .95, .98, .99, 1.01),
               labels = c("no salience data", "0-0.5", "0.5-0.9", "0.9-0.95",
                          "0.95-0.98", "0.98-0.99", "0.99-1.0"))]
print(FE[, .(cells = .N, mean_actual = round(mean(actual_share), 1),
             full = round(rmse(p_full, actual_share), 3),
             medium = round(rmse(p_medium, actual_share), 3),
             small = round(rmse(p_small, actual_share), 3),
             small_gain = round(rmse(p_full, actual_share) - rmse(p_small, actual_share), 3)),
         by = sb][order(sb)])

cat("\nXC5  SAME, IND ONLY -- Pete's question, since IND is the target class.\n")
print(FE[party == "IND", .(cells = .N, mean_actual = round(mean(actual_share), 1),
             full = round(rmse(p_full, actual_share), 3),
             medium = round(rmse(p_medium, actual_share), 3),
             small = round(rmse(p_small, actual_share), 3),
             small_gain = round(rmse(p_full, actual_share) - rmse(p_small, actual_share), 3)),
         by = sb][order(sb)])

cat("\nXC6  what each set predicts for the six teals:\n")
TEALS <- c("Wentworth", "Mackellar", "Kooyong", "Curtin", "North Sydney", "Goldstein")
print(FE[pair == "fed2022" & party == "IND" & seat %in% TEALS,
         .(seat, actual = round(actual_share, 1), sal_exp = round(sal_exp, 1),
           full = round(p_full, 1), medium = round(p_medium, 1),
           small = round(p_small, 1))][order(-actual)])

fwrite(FE[, .(pair, seat, party, actual_share, jump_pctile, sal_exp,
              p_full, p_medium, p_small)],
       file.path(OUT, "ind-featureset-comparison.csv"))
cat(sprintf("\nXC7  wrote %s/ind-featureset-comparison.csv\n", OUT))
