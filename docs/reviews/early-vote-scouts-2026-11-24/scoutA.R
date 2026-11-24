# Scout A: a direct correction after the trees. Labor's predicted primary is shifted by
# b * (last election's early share, z-scored within election), b fitted on EARLIER elections only;
# the points removed from Labor go to the other parties in proportion to their predicted shares.
src <- readLines("scripts/screen_early_vote.R")
eval(parse(text = src[1:(grep("^# ---- ideas", src)[1] - 1)]))
stopifnot(FINAL)
D <- D[is.finite(z_prev_early)]
D[, zc := z_prev_early - mean(z_prev_early), by = .(election, party)]
els <- unique(D[, .(election, when)])[order(when)]
fit_b <- function(tg, before) {
  a <- D[party == tg & when < before]
  if (uniqueN(a$election) < 2) return(NA_real_)
  a[, m := miss - mean(miss), by = election]
  sum(a$zc * a$m) / sum(a$zc^2)
}
out <- list()
for (i in seq_len(nrow(els))) {
  e <- els$election[i]; b <- fit_b("ALP", els$when[i]); if (is.na(b)) next
  x <- copy(D[election == e])
  x[, adj := ours]
  x[party == "ALP", adj := pmax(0, ours + b * zc)]
  x[, d_alp := sum((adj - ours)[party == "ALP"]), by = seat]
  x[, oth_tot := sum(ours[party != "ALP"]), by = seat]
  x[party != "ALP" & oth_tot > 0, adj := ours - d_alp * ours / oth_tot]
  x[, b := b]; out[[e]] <- x
}
X <- rbindlist(out)
cat(sprintf("elections scored: %d (slope needs 2 earlier elections), seat-elections: %d\n", uniqueN(X$election), uniqueN(X[, .(election, seat)])))
rm_ <- function(p, a) sqrt(mean((p - a)^2))
per <- X[, .(seats = uniqueN(seat), slope = round(b[1], 2),
             alp_before = rm_(ours[party == "ALP"], actual[party == "ALP"]), alp_after = rm_(adj[party == "ALP"], actual[party == "ALP"]),
             all_before = rm_(ours, actual), all_after = rm_(adj, actual)), by = .(election, when)][order(when)]
cat("\nPrimary-vote RMSE in points, LOWER IS BETTER. slope = points taken off Labor per 1 SD of last election's early share (fitted on earlier elections).\n")
print(per[, .(election, seats, slope, alp_before = round(alp_before, 3), alp_after = round(alp_after, 3), alp_change = round(alp_after - alp_before, 3),
              all_before = round(all_before, 3), all_after = round(all_after, 3), all_change = round(all_after - all_before, 3))])
s <- function(v) sprintf("%+.4f (SE across elections %.4f, %d of %d elections better)", mean(v), sd(v) / sqrt(length(v)), sum(v < 0), length(v))
cat("Labor, change in squared error per election:      ", s(per$alp_after^2 - per$alp_before^2), "\n")
cat("All parties, change in squared error per election:", s(per$all_after^2 - per$all_before^2), "\n")
cat(sprintf("Pooled Labor RMSE %.3f -> %.3f; all parties %.3f -> %.3f\n", rm_(X[party == "ALP"]$ours, X[party == "ALP"]$actual), rm_(X[party == "ALP"]$adj, X[party == "ALP"]$actual), rm_(X$ours, X$actual), rm_(X$adj, X$actual)))
# seat-level proxy: Labor's lead over its strongest rival on primaries
L <- X[, .(lead_b = ours[party == "ALP"] - max(ours[party != "ALP"]), lead_a = adj[party == "ALP"] - max(adj[party != "ALP"]),
           lead_act = actual[party == "ALP"] - max(actual[party != "ALP"])), by = .(election, seat)]
cat(sprintf("\nSeat proxy (Labor's primary lead over its strongest rival), %d seats: lead RMSE %.3f -> %.3f; seats where 'Labor ahead or not' is called right %d -> %d; seats whose call flips %d\n",
            nrow(L), rm_(L$lead_b, L$lead_act), rm_(L$lead_a, L$lead_act), sum((L$lead_b > 0) == (L$lead_act > 0)), sum((L$lead_a > 0) == (L$lead_act > 0)), sum((L$lead_b > 0) != (L$lead_a > 0))))
cl <- L[abs(lead_b) < 5]
cat(sprintf("  close seats only (predicted lead within 5 points), %d seats: called right %d -> %d; lead RMSE %.3f -> %.3f\n",
            nrow(cl), sum((cl$lead_b > 0) == (cl$lead_act > 0)), sum((cl$lead_a > 0) == (cl$lead_act > 0)), rm_(cl$lead_b, cl$lead_act), rm_(cl$lead_a, cl$lead_act)))
cat(sprintf("  size of the correction: median |shift| %.2f points, 90th percentile %.2f, max %.2f\n", median(abs(X[party == "ALP"]$adj - X[party == "ALP"]$ours)), quantile(abs(X[party == "ALP"]$adj - X[party == "ALP"]$ours), 0.9), max(abs(X[party == "ALP"]$adj - X[party == "ALP"]$ours))))
