# Does a "middle" One Nation fill have support? On the 4 new-party surges, fit a major's vote change d on BOTH the
# proportional term (prev_share * s / 100) and a flat term (s), per election and pooled with election effects.
# A middle version is supported if the flat term is clearly negative alongside the proportional one.
suppressMessages(library(data.table))
P <- fread("output/published-predictions.csv")
cat("rows", nrow(P), "pairs", uniqueN(P$pair), "\n")
cases <- list(sa2026 = "ONP", qld2017 = "ONP", qld2024 = "ONP", sa2018 = "IND")
out <- list()
for (e in names(cases)) {
  np <- cases[[e]]; X <- P[P$pair == e]
  s <- X[X$party == np, .(seat, s = actual)]
  for (maj in c("ALP", "LNP")) {
    m <- X[X$party == maj & !is.na(prev_share) & prev_share > 0, .(seat, prev = prev_share, act = actual)]
    d <- merge(m, s, by = "seat", all.x = TRUE); d[is.na(s), s := 0]; d[, dd := act - prev]
    d[, prop := prev * s / 100]; d$election <- e; d$major <- maj
    out[[paste(e, maj)]] <- d
  }
}
D <- rbindlist(out)
rmse <- function(f) sqrt(mean(residuals(f)^2))
for (maj in c("ALP", "LNP")) {
  cat("\n==", maj, "\n")
  for (e in names(cases)) {
    d <- D[D$major == maj & D$election == e]
    f1 <- lm(dd ~ prop, d); f2 <- lm(dd ~ s, d); f3 <- lm(dd ~ prop + s, d)
    c3 <- summary(f3)$coefficients
    cat(sprintf("  %-8s n %3d | prop-only RMSE %.2f | flat-only RMSE %.2f | both RMSE %.2f: prop b %+.2f (se %.2f), flat b %+.3f (se %.3f)\n",
                e, nrow(d), rmse(f1), rmse(f2), rmse(f3), c3["prop", 1], c3["prop", 2], c3["s", 1], c3["s", 2]))
  }
  d <- D[D$major == maj]
  f <- lm(dd ~ prop + s + factor(election), d); c <- summary(f)$coefficients
  cat(sprintf("  POOLED (election effects) n %d: prop b %+.2f (se %.2f), flat b %+.3f (se %.3f)\n", nrow(d), c["prop", 1], c["prop", 2], c["s", 1], c["s", 2]))
}
