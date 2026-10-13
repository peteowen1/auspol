# Defector over-call check (docs/reviews/defector-overcarry-2026-10-14.md): each defector case in
# output/defector-cases-all.csv joined to output/forecasts.csv on pair, seat and surname; prints over-call.
library(data.table)
dc <- fread("output/defector-cases-all.csv"); fc <- fread("output/forecasts.csv")
fc[, seat_l := tolower(seat)]; fc[, sur := toupper(sub(".* ", "", candidate))]
dc[, sur := toupper(sub(".* ", "", name))]
m <- merge(dc, fc[, .(pair = election, seat = seat_l, sur, party, base_pred, xgb_pred, actual_share)], by = c("pair", "seat", "sur"))
cat("cases", nrow(dc), "matched", nrow(m), "\n")
m[, `:=`(err_base = base_pred - actual_share, err_xgb = xgb_pred - actual_share)]
print(m[order(pair), .(pair, seat, name, party, prior = round(prior, 1), base = round(base_pred, 1), xgb = round(xgb_pred, 1), act = round(actual_share, 1), over = round(err_xgb, 1))])
cat(sprintf("mean over-call: base %+.2f, xgb %+.2f (n=%d); median xgb %+.2f; over-called %d of %d\n",
    mean(m$err_base), mean(m$err_xgb), nrow(m), median(m$err_xgb), sum(m$err_xgb > 0), nrow(m)))
cat("unmatched:\n"); print(dc[!paste(pair, seat, sur) %in% m[, paste(pair, seat, sur)], .(pair, seat, name)])
