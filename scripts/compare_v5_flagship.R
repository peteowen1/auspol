# One-off comparison: shipped vs xgb v1 (pure) vs xgb v5, on the flagship
# weak cases (sa2026 ONP, vic2014, WA has_prior split). Scratch analysis for
# docs/reviews/xgb-primary-v5-seat-features-2026-09-10.md -- not a repo script.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

v1 <- fread("output/xgb-primary-oof-predictions.csv", showProgress = FALSE)
v5 <- fread("output/xgb-primary-v5-oof-predictions.csv", showProgress = FALSE)
setnames(v1, "xgb_pred", "xgb_v1")
setnames(v5, "xgb_pred", "xgb_v5")
m <- merge(v1, v5[, .(pair, seat, party, xgb_v5)], by = c("pair", "seat", "party"))

cat("=== SA2026 ONP: shipped vs v1 vs v5 ===\n")
onp <- m[pair == "sa2026" & party == "ONP"]
cat(sprintf("n=%d\nMAE shipped=%.3f  v1=%.3f  v5=%.3f\n",
            nrow(onp),
            mean(abs(onp$pred_share - onp$actual_share)),
            mean(abs(onp$xgb_v1 - onp$actual_share)),
            mean(abs(onp$xgb_v5 - onp$actual_share))))
cat(sprintf("mean pred at seats ONP actually contests (all): shipped=%.3f v1=%.3f v5=%.3f actual=%.3f\n",
            mean(onp$pred_share), mean(onp$xgb_v1), mean(onp$xgb_v5), mean(onp$actual_share)))

cat("\n=== vic2014: pooled RMSE shipped vs v1 vs v5 ===\n")
v14 <- m[pair == "vic2014"]
cat(sprintf("n=%d\nRMSE shipped=%.4f  v1=%.4f  v5=%.4f\n",
            nrow(v14),
            sqrt(mean((v14$pred_share - v14$actual_share)^2)),
            sqrt(mean((v14$xgb_v1 - v14$actual_share)^2)),
            sqrt(mean((v14$xgb_v5 - v14$actual_share)^2))))

cat("\n=== WA: has_prior split (x > 0 vs x == 0), shipped vs v1 vs v5 RMSE ===\n")
v5feat <- fread("output/xgb-primary-features-v5.csv", showProgress = FALSE)
wa <- v5feat[region == "wa", .(pair, seat, party, x, pred_share, actual_share)]
wa <- merge(wa, v1[, .(pair, seat, party, xgb_v1)], by = c("pair", "seat", "party"))
wa <- merge(wa, v5[, .(pair, seat, party, xgb_v5)], by = c("pair", "seat", "party"))
wa[, has_prior := x > 0]
print(wa[, .(n = .N,
             shipped_rmse = sqrt(mean((pred_share - actual_share)^2)),
             v1_rmse = sqrt(mean((xgb_v1 - actual_share)^2)),
             v5_rmse = sqrt(mean((xgb_v5 - actual_share)^2))), by = has_prior])

cat("\n=== Pooled primary RMSE, all 22 pairs: shipped vs v1 vs v5 ===\n")
cat(sprintf("shipped=%.4f  v1=%.4f  v5=%.4f\n",
            sqrt(mean((m$pred_share - m$actual_share)^2)),
            sqrt(mean((m$xgb_v1 - m$actual_share)^2)),
            sqrt(mean((m$xgb_v5 - m$actual_share)^2))))
