# Per-class deviation slopes, estimated HELD OUT by region.
#
# LEAKAGE. Slopes fitted across all 17 election pairs include the very elections
# the harnesses score, so a harness run with them would be graded partly on its
# own answer. CLAUDE.md records three instances of this, one introduced while
# fixing another.
#
# So each region gets a slope vector estimated from the OTHER regions only. The
# federal harness runs on slopes derived from state elections and vice versa;
# no election contributes to the slope used to predict it.
#
# Writes output/dev-slopes-heldout.csv. Emits DS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
mk <- function(rg, yr) {
  d <- C[region == rg & year == yr, .(votes = sum(votes)), by = .(seat, party)]
  if (!nrow(d)) return(NULL)
  d[, pcv := 100 * votes / sum(votes), by = seat][, .(seat, party, pcv)]
}
E <- unique(C[, .(region, year)])[order(region, year)]
rows <- list()
for (k in seq_len(nrow(E))) {
  rg <- E$region[k]; yr <- E$year[k]
  py <- suppressWarnings(max(C[region == rg & year < yr, year]))
  if (!is.finite(py)) next
  N <- mk(rg, yr); P <- mk(rg, py)
  if (is.null(N) || is.null(P)) next
  sh <- intersect(N$seat, P$seat)
  if (length(sh) < 30) next
  cls <- sort(unique(c(N$party, P$party)))
  D <- CJ(seat = sh, party = cls, unique = TRUE)
  D <- merge(merge(D, N, by = c("seat","party"), all.x = TRUE),
             P, by = c("seat","party"), all.x = TRUE, suffixes = c("_now","_prev"))
  D[is.na(pcv_now), pcv_now := 0][is.na(pcv_prev), pcv_prev := 0]
  # centre WITHIN class and election: the slope describes the deviation, and the
  # statewide level is supplied separately by the model.
  D[, `:=`(dn = pcv_now - mean(pcv_now), dp = pcv_prev - mean(pcv_prev)), by = party]
  rows[[length(rows) + 1L]] <- D[, .(region = rg, pair = paste0(rg, yr), party, dn, dp)]
}
A <- rbindlist(rows)
cat(sprintf("DS1  %d pairs across %d regions | %d rows\n",
            uniqueN(A$pair), uniqueN(A$region), nrow(A)))

regions <- sort(unique(A$region))
out <- list()
for (rg in regions) {
  B <- A[region != rg]
  t <- B[, {
    m <- stats::lm(dn ~ 0 + dp, .SD); s <- coef(summary(m))
    .(slope = s[1,1], se = s[1,2], n = .N, pairs = uniqueN(pair))
  }, by = party]
  t[, `:=`(held_out = rg, t_vs_1 = (slope - 1) / se)]
  out[[rg]] <- t
}
S <- rbindlist(out)
fwrite(S, "output/dev-slopes-heldout.csv")

cat("\nDS2  slope by class, with the scored region HELD OUT\n")
W <- dcast(S, party ~ held_out, value.var = "slope")
num <- setdiff(names(W), "party")
for (j in num) set(W, j = j, value = round(W[[j]], 3))
print(W, row.names = FALSE)

cat("\nDS3  is a slope of 1 rejected in every held-out fit? (t vs 1)\n")
T <- dcast(S, party ~ held_out, value.var = "t_vs_1")
for (j in setdiff(names(T), "party")) set(T, j = j, value = round(T[[j]], 1))
print(T, row.names = FALSE)

cat("\nDS4  the spec string each harness should run with\n")
for (rg in regions) {
  v <- S[held_out == rg][order(party)]
  cat(sprintf("  %-4s %s\n", rg,
      paste(sprintf("%s=%.3f", v$party, v$slope), collapse = ",")))
}
