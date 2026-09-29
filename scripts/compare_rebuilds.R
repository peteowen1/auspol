# Compare two rebuild snapshots: seat log loss per election (winner's
# probability, clamped at 1e-6 as everywhere else), paired by seat, plus the
# AEF-7 ledger summary. Usage: Rscript scripts/compare_rebuilds.R <dirA> <dirB>
suppressMessages(library(data.table))
a <- commandArgs(TRUE)
if (length(a) != 2L) stop("usage: Rscript scripts/compare_rebuilds.R <dirA> <dirB>")
A <- a[1]; B <- a[2]
ll <- function(d) {
  f <- fread(file.path(d, "forecasts-seats.csv"), showProgress = FALSE)
  ks <- paste(f$election, f$seat)
  nw <- setdiff(unique(ks), unique(ks[f$is_winner %in% TRUE]))
  w <- f[is_winner == TRUE, .(p = sum(win_prob)), by = .(election, seat)]
  # A winner the model never listed scores at the floor, as in pool_backtests.R.
  if (length(nw)) {
    cat(sprintf("CR0f %s: %d seat(s) with no winner row scored at p = 0: %s\n",
                basename(d), length(nw), paste(nw, collapse = ", ")))
    w <- rbind(w, data.table(election = sub(" .*", "", nw), seat = sub("^[^ ]+ ", "", nw), p = 0))
  }
  w[, ll := -log(pmax(1e-6, pmin(1, p)))][]
}
x <- merge(ll(A), ll(B), by = c("election", "seat"), suffixes = c("_a", "_b"))
cat(sprintf("CR0 %d seat-elections matched across %d elections\n", nrow(x), uniqueN(x$election)))
per <- x[, .(n = .N, ll_a = mean(ll_a), ll_b = mean(ll_b), d = mean(ll_b - ll_a),
             se = sd(ll_b - ll_a) / sqrt(.N), moved = sum(abs(p_b - p_a) > 1e-9)), by = election][order(election)]
cat("CR1 seat log loss per election (lower is better); d = B - A, negative favours B; moved = seats whose winner probability changed\n")
print(per[, lapply(.SD, function(v) if (is.numeric(v) && !is.integer(v)) round(v, 4) else v)], nrows = 100)
cat(sprintf("CR2 all elections: A %.4f  B %.4f  per-election mean d %+.4f (SE %.4f, better in %d of %d)\n",
            mean(x$ll_a), mean(x$ll_b), mean(per$d), sd(per$d) / sqrt(nrow(per)), sum(per$d < 0), nrow(per)))
for (d in c(A, B)) {
  s <- jsonlite::fromJSON(file.path(d, "aef7-ledger-summary.json"))
  cat(sprintf("CR3 %s ledger: log loss %.4f  wRMSE %.3f  TCP MAE %.3f  accuracy %.4f\n",
              basename(d), s$seat_logloss$our, s$primary_wrmse$our, s$tcp_mae$our, s$accuracy$our))
}
