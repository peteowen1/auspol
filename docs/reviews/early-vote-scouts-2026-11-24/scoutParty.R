# For each party: shift ITS predicted primary by a slope on last election's early share (fitted on earlier elections),
# and score that party's own error. Same method as scout A, one party at a time.
src <- readLines("scripts/screen_early_vote.R")
eval(parse(text = src[1:(grep("^# ---- ideas", src)[1] - 1)]))   # builds D from the repo's own screen script
D <- D[is.finite(z_prev_early)]
D[, zc := z_prev_early - mean(z_prev_early), by = .(election, party)]
els <- unique(D[, .(election, when)])[order(when)]
res <- rbindlist(lapply(c("ALP", "LNP", "GRN", "IND", "ONP", "OTH_RIGHT", "OTH"), function(tg) {
  per <- rbindlist(lapply(seq_len(nrow(els)), function(i) {
    a <- D[party == tg & when < els$when[i]]; x <- D[party == tg & election == els$election[i]]
    if (uniqueN(a$election) < 2 || !nrow(x)) return(NULL)
    a[, m := miss - mean(miss), by = election]; b <- sum(a$zc * a$m) / sum(a$zc^2)
    adj <- pmax(0, x$ours + b * x$zc)
    data.table(election = els$election[i], b = b, n = nrow(x), before = mean((x$ours - x$actual)^2), after = mean((adj - x$actual)^2))
  }))
  if (!nrow(per)) return(NULL)
  d <- per$after - per$before
  data.table(party = tg, elections = nrow(per), seats = sum(per$n), slope_latest = round(per$b[nrow(per)], 2),
             rmse_before = round(sqrt(weighted.mean(per$before, per$n)), 3), rmse_after = round(sqrt(weighted.mean(per$after, per$n)), 3),
             sq_err_change = round(mean(d), 3), se = round(sd(d) / sqrt(length(d)), 3), better = sprintf("%d of %d", sum(d < 0), length(d)))
}))
cat("Each party's own primary error, in points, when ITS share is shifted by last election's early share (slope from earlier elections only). LOWER IS BETTER.\n",
    "slope_latest = points per 1 SD at the most recent election; sq_err_change negative = better; se across elections.\n", sep = "")
print(res)
