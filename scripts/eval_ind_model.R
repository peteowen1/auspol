# Step one of the dedicated-independent-model test (2026-10-09): a time-forward xgboost on independent
# cells only (41 inputs + seat-poll figure) vs the current model, scored on those cells. Result: ties the
# current xgb stage (RMSE 6.38 vs 6.38, 892 cells, 18 elections); current published 5.91 is better.
# Writes output/ind-model-eval.csv and output/ind-model-eval-preds.csv.
#   powershell.exe -Command 'Rscript "scripts/eval_ind_model.R"'
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table)); suppressMessages(library(xgboost))
set.seed(42)
FT <- fread("output/xgb-primary-v6-features.csv", showProgress = FALSE)
nom <- .it_nominated()
D <- FT[FT$party == "IND" & paste(FT$pair, normalise_seat(FT$seat)) %in% nom]
D[, actual := as.numeric(actual_share)]
cat(sprintf("IND cells with a nominated independent: %d in %d elections\n", nrow(D), uniqueN(D$pair)))

# Seat-poll figure for the IND class where one exists (decay-weighted, as shipped).
sp <- rbindlist(lapply(unique(D$pair), function(e) {
  x <- NULL; utils::capture.output(x <- tryCatch(seat_poll_shares(e), error = function(err) NULL))
  if (is.null(x) || !nrow(x)) return(NULL)
  x <- x[x$class == "IND"]; if (!nrow(x)) return(NULL)
  data.table(pair = e, skey = normalise_seat(x$seat), seat_poll = x$poll)
}))
D[, skey := normalise_seat(seat)]
D <- merge(D, sp, by = c("pair", "skey"), all.x = TRUE)
cat(sprintf("cells with an IND seat poll: %d\n", sum(is.finite(D$seat_poll))))

drop <- c("pair", "seat", "skey", "party", "actual_share", "actual", grep("^party_", names(D), value = TRUE))
feats <- setdiff(names(D), drop)
num <- function(d) { m <- as.matrix(d[, ..feats]); storage.mode(m) <- "double"; m }
cat(sprintf("features: %d (%s)\n", length(feats), paste(feats, collapse = " ")))

# Current model on the same cells: xgb stage (forecasts.csv) and published final (newest sharedetail per pair).
FC <- fread("output/forecasts.csv", showProgress = FALSE)[party == "IND", .(pair = election, skey = normalise_seat(seat), cur_xgb = xgb_pred_seat)]
files <- list.files("output", pattern = "^backtest-.*-sharedetail-.*[.]csv$", full.names = TRUE)
files <- files[!grepl("-n[0-9]+-|-p[0-9]{4}-", files)]
SD <- rbindlist(lapply(files, function(f) { x <- fread(f, showProgress = FALSE); x[, mt := file.mtime(f)] }), fill = TRUE)
SD <- SD[party == "IND"][order(-mt)][, .SD[1], by = .(pair, seat)][, .(pair, skey = normalise_seat(seat), cur_final = pred_share)]
D <- merge(D, FC, by = c("pair", "skey"), all.x = TRUE)
D <- merge(D, SD, by = c("pair", "skey"), all.x = TRUE)

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 3, min_child_weight = 5,
               subsample = 0.8, colsample_bytree = 0.8, lambda = 5)
targets <- sort(unique(D$pair))
res <- list(); preds <- list()
for (tg in targets) {
  tr <- D[D$pair %in% targets[elections_before(targets, tg)] & is.finite(D$actual)]
  te <- D[D$pair == tg & is.finite(D$actual)]
  if (nrow(tr) < 150 || !nrow(te)) next
  dtr <- xgb.DMatrix(num(tr), label = tr$actual)
  cv <- xgb.cv(params, dtr, nrounds = 600, nfold = 5, early_stopping_rounds = 30, verbose = 0)
  nr <- which.min(cv$evaluation_log$test_rmse_mean)
  m <- xgb.train(params, dtr, nrounds = nr, verbose = 0)
  te[, new := pmax(predict(m, num(te)), 0)]
  preds[[tg]] <- te[, .(pair, seat, actual, new, cur_xgb, cur_final, base = base_pred, same_mp_i, c200, seat_poll)]
  ok <- is.finite(te$cur_xgb) & is.finite(te$cur_final)
  res[[tg]] <- data.table(target = tg, n = sum(ok), n_train = nrow(tr), rounds = nr,
    rmse_cur_xgb = sqrt(mean((te$cur_xgb[ok] - te$actual[ok])^2)),
    rmse_cur_final = sqrt(mean((te$cur_final[ok] - te$actual[ok])^2)),
    rmse_new = sqrt(mean((te$new[ok] - te$actual[ok])^2)),
    mad_cur_final = median(abs(te$cur_final[ok] - te$actual[ok])),
    mad_new = median(abs(te$new[ok] - te$actual[ok])),
    bias_cur_final = mean(te$cur_final[ok] - te$actual[ok]), bias_new = mean(te$new[ok] - te$actual[ok]))
}
R <- rbindlist(res)
print(R, digits = 3)
P <- rbindlist(preds)
cat(sprintf("\nPOOLED over %d cells in %d elections: RMSE current xgb %.3f | current published %.3f | new %.3f ; median abs miss current %.2f new %.2f ; bias current %+.2f new %+.2f\n",
            sum(R$n), nrow(R), sqrt(sum(R$n * R$rmse_cur_xgb^2) / sum(R$n)), sqrt(sum(R$n * R$rmse_cur_final^2) / sum(R$n)),
            sqrt(sum(R$n * R$rmse_new^2) / sum(R$n)),
            median(abs(P$cur_final - P$actual), na.rm = TRUE), median(abs(P$new - P$actual), na.rm = TRUE),
            mean(P$cur_final - P$actual, na.rm = TRUE), mean(P$new - P$actual, na.rm = TRUE)))
fwrite(P, "output/ind-model-eval-preds.csv"); fwrite(R, "output/ind-model-eval.csv")
cat("\nExample seats:\n")
print(P[seat %in% c("Bass", "Hawthorn", "Brunswick", "Mildura", "Benambra", "Pascoe Vale", "Werribee", "Goldstein", "Warringah", "Kooyong", "Mayo")][
  , .(pair, seat, actual = round(actual, 1), current = round(cur_final, 1), new = round(new, 1))][order(pair, seat)])
