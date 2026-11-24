# Scout: does national federal VI before a state election predict the state polls' Labor miss?
options(auspol.root = normalizePath(".")); suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
L <- fread("output/level-recent.csv")
cat("level-recent.csv:", nrow(L), "rows,", uniqueN(L$election), "elections. Columns used: election, region, cls, trend (day-before poll trend, blend off), avg28, actual\n")
ED <- election_dates(); P <- .lr_polls("fed")   # fed polls, NAT folded into LNP; only a mid-date is available
cat("fed polls:", nrow(P), "rows", format(min(P$date)), "to", format(max(P$date)), "; ALP non-NA", sum(is.finite(P$ALP)), "\n")
fedA <- L[region == "fed" & cls == "ALP", .(election, a = actual)]; fedL <- L[region == "fed" & cls == "LNP", .(election, l = actual)]
fed <- merge(fedA, fedL); fed[, date := as.Date(unname(ED[election]))]; setorder(fed, date)
print(fed)
govfed <- function(d) if (d < as.Date("2007-11-24")) "LNP" else if (d < as.Date("2013-09-07")) "ALP" else if (d < as.Date("2022-05-21")) "LNP" else "ALP"
st <- unique(L[region != "fed", .(election, region)]); st[, date := as.Date(unname(ED[election]))]; setorder(st, date)
W <- 60
rows <- lapply(seq_len(nrow(st)), function(i) {
  e <- st$election[i]; d <- st$date[i]; r <- L[election == e & cls == "ALP"]
  w <- P[date < d & date >= d - W]
  prev <- fed[date < d][.N]; g <- govfed(d)
  lvA <- mean(w$ALP, na.rm = TRUE); lvL <- mean(w$LNP, na.rm = TRUE)
  data.table(election = e, date = d, nfed = sum(is.finite(w$ALP)), miss_trend = r$actual - r$trend, miss_avg28 = r$actual - r$avg28,
    fed_labor_level = lvA, prev_fed = if (nrow(prev)) prev$election else NA_character_,
    fed_labor_change = if (nrow(prev)) lvA - prev$a else NA_real_, gov = g,
    fed_gov_change_signed = if (!nrow(prev)) NA_real_ else if (g == "ALP") lvA - prev$a else -(lvL - prev$l))
})
D <- rbindlist(rows)
options(width = 200); print(D[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])
drop <- D[!is.finite(miss_trend) | nfed < 3, .(election, nfed, miss_trend)]
cat("\nDropped (no day-before poll figure or <3 fed polls in window):\n"); print(drop)
cat("No previous federal election in file (change predictors NA):", D[is.na(fed_labor_change)]$election, "\n")
cat("Federal election results in the file start at fed2007, so fed2004/2001 Labor primaries are unavailable here.\n")
sq <- function(x) x^2
for (y in c("miss_trend", "miss_avg28")) for (x in c("fed_labor_level", "fed_labor_change", "fed_gov_change_signed")) {
  d <- D[is.finite(get(y)) & is.finite(get(x)) & nfed >= 3][order(date)]; n <- nrow(d); yy <- d[[y]]; xx <- d[[x]]
  f <- lm(yy ~ xx); s <- summary(f)$coef
  loo <- sapply(seq_len(n), function(i) { b <- coef(lm(yy[-i] ~ xx[-i])); yy[i] - (b[1] + b[2] * xx[i]) })
  sse0 <- sum(yy^2); sse_loo <- sum(loo^2)
  tf <- NULL; if (n > 6) { idx <- 7:n; e1 <- sapply(idx, function(i) { b <- coef(lm(yy[1:(i-1)] ~ xx[1:(i-1)])); yy[i] - (b[1] + b[2] * xx[i]) }); tf <- c(sum(yy[idx]^2), sum(e1^2), length(idx)) }
  cat(sprintf("\n[%s ~ %s] n=%d  r=%.3f  slope=%.3f (SE %.3f, t=%.2f)  intercept=%.2f\n", y, x, n, cor(xx, yy), s[2,1], s[2,2], s[2,3], s[1,1]))
  cat(sprintf("  LOO: SSE zero-miss=%.1f, SSE model=%.1f, change=%+.1f (%+.1f%%)\n", sse0, sse_loo, sse_loo - sse0, 100 * (sse_loo / sse0 - 1)))
  if (!is.null(tf)) cat(sprintf("  time-forward (first %d scored from 7th): scored n=%d, SSE zero-miss=%.1f, SSE model=%.1f, change=%+.1f (%+.1f%%)\n", 6, tf[3], tf[1], tf[2], tf[2]-tf[1], 100*(tf[2]/tf[1]-1)))
  else cat("  time-forward: n<=6, not possible\n")
}
