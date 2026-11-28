# LIVE upper-house forecast inputs (28 Nov 2026, 10:15pm): the pre-election upper-house model
# (scripts/build_upper_house_forecast.R, unchanged) fed the LIVE lower-house first preferences from the night file
# instead of the pre-election seat shares, with the statewide swing draws narrowed (k) because the count has removed
# most of the statewide uncertainty. Writes <out dir>/seat-shares-vic-2026.csv and night-state-vic-2026.rds.
#   Rscript mk_live.R <night json> <pre dir> <out dir> [k=0.3]
suppressMessages(library(data.table)); a <- commandArgs(TRUE); k <- if (length(a) >= 4) as.numeric(a[4]) else 0.3
n <- jsonlite::fromJSON(a[1], simplifyVector = FALSE); pre <- fread(file.path(a[2], "seat-shares-vic-2026.csv"))
cls <- setdiff(names(pre), "seat")
L <- rbindlist(lapply(n$seats, function(s) { v <- setNames(rep(0, length(cls)), cls); for (p in s$parties) if (p$party %in% cls && !is.null(p$primary)) v[[p$party]] <- p$primary
  as.data.table(c(list(seat = s$seat), as.list(v))) }))
stopifnot(nrow(L) == 88, setequal(L$seat, pre$seat))
L <- L[match(pre$seat, seat)]
cat(sprintf("night file %s, mean counted %.1f%%; statewide seat-average first preferences, pre-election -> live:\n", n$night$snapshot_stamp, mean(vapply(n$seats, function(s) if (is.null(s$counted_pct)) 0 else s$counted_pct, 0))))
print(rbind(pre = round(colMeans(pre[, ..cls]), 1), live = round(colMeans(L[, ..cls]), 1)))
fwrite(L, file.path(a[3], "seat-shares-vic-2026.csv"))
ns <- readRDS(file.path(a[2], "night-state-vic-2026.rds")); sw <- as.matrix(ns$swd); m <- colMeans(sw)
ns$swd <- sweep(sweep(sw, 2, m) * k, 2, m, "+"); saveRDS(ns, file.path(a[3], "night-state-vic-2026.rds"))
cat(sprintf("statewide swing draws narrowed to %.0f%% of their pre-election spread\n", 100 * k))
