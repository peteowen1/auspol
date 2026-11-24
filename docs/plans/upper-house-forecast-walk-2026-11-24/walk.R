# First walk for an upper-house (Legislative Council) forecast: point estimates only, no simulation, no preferences.
# For each of the 8 regions: our lower-house forecast summed over its 11 districts, converted to an upper-house
# share with the ratios measured in docs/plans/upper-house-night-model.md, then expressed in quotas (5 seats,
# quota = one sixth of the vote). Run from the repo root.
suppressPackageStartupMessages(library(data.table))
sh <- fread("deciding-runs/20261124-early-share-screen/live-now/seat-shares-vic-2026.csv")
rg <- fread("external/reference/vec/vic-district-regions.csv"); en <- fread("external/reference/vec/2026/enrolment/enrolment-2026.csv")
x <- merge(merge(sh, rg, by.x = "seat", by.y = "district"), en, by.x = "seat", by.y = "district")
stopifnot(nrow(x) == 88, uniqueN(x$region) == 8, all(x[, .N, by = region]$N == 11))
cls <- c("ALP", "LNP", "ONP", "GRN"); x[, MINOR := IND + OTH + OTH_RIGHT]
A <- x[, c(lapply(.SD, function(v) sum(v * enrolment) / sum(enrolment)), .(enrolled = sum(enrolment))), by = region, .SDcols = c(cls, "MINOR")]
cat("1. LOWER-HOUSE forecast by region (% of primary vote, weighted by enrolment). MINOR = independents and every other party.\n")
print(A[, .(region, ALP = round(ALP, 1), LNP = round(LNP, 1), ONP = round(ONP, 1), GRN = round(GRN, 1), MINOR = round(MINOR, 1))][order(region)], row.names = FALSE)
# upper-house share = lower-house share x ratio (2018 and 2022 mean, design doc section 1). One Nation has NO
# Victorian measurement (it barely stood in the Assembly before 2026), so its ratio is FITTED (onp_ratio.R, 24 Nov):
# 516 division-elections where it stood in both houses, mostly federal 2001-2025; mean ratio 0.85 (median-type 0.79,
# 80% interval 0.65 to 0.96), flat in the size of its vote up to 20%. The first draft assumed 1.00. Only 2 divisions
# ever had One Nation above 20% in the lower house, so at Victoria's 2026 levels this is partly extrapolation.
RATIO <- c(ALP = 0.905, LNP = 0.845, GRN = 0.883, ONP = 0.85)
C <- copy(A); for (k in cls) C[, (k) := get(k) * RATIO[[k]]]
C[, MINOR := 100 - ALP - LNP - ONP - GRN]
Q <- 100 / 6
cat(sprintf("\n2. UPPER-HOUSE projection in QUOTAS (1 quota = %.2f%% of the vote wins a seat; 5 seats per region).\n", Q),
    "   Ratios: Labor x0.905, Coalition x0.845, Greens x0.883 (Victoria 2018 and 2022); One Nation x0.85 (fitted on 516 division-elections).\n",
    "   MINOR is every other group together, typically 15 to 20 groups, so no single one has this many quotas.\n", sep = "")
print(C[, .(region, ALP = round(ALP / Q, 2), LNP = round(LNP / Q, 2), ONP = round(ONP / Q, 2), GRN = round(GRN / Q, 2), MINOR_pool = round(MINOR / Q, 2))][order(region)], row.names = FALSE)
# seats: full quotas, then the largest remainders among the four named groups and ONE minor group holding 30% of the pool
alloc <- function(v) { s <- floor(v); rem <- v - s; left <- 5 - sum(s); if (left > 0) { o <- order(-rem)[seq_len(left)]; s[o] <- s[o] + 1 }; s }
R <- rbindlist(lapply(seq_len(nrow(C)), function(i) {
  v <- c(ALP = C$ALP[i], LNP = C$LNP[i], ONP = C$ONP[i], GRN = C$GRN[i], `Biggest minor` = 0.30 * C$MINOR[i]) / Q
  s <- alloc(v); rem <- v - floor(v); o <- order(-rem); left <- 5 - sum(floor(v))
  last_in <- names(v)[o][left]; first_out <- names(v)[o][left + 1]
  data.table(region = C$region[i], ALP = s[["ALP"]], LNP = s[["LNP"]], ONP = s[["ONP"]], GRN = s[["GRN"]], minor = s[["Biggest minor"]],
             last_seat = sprintf("%s (%.2f of a quota left)", last_in, rem[last_in]), first_loser = sprintf("%s (%.2f)", first_out, rem[first_out]),
             gap = round(rem[last_in] - rem[first_out], 2))
}))
cat("\n3. FIRST-CUT SEATS: whole quotas first, then the largest remainders. No preferences yet. 'Biggest minor' assumes one\n",
    "   minor group takes 30% of the minor pool (the 2018 and 2022 range was 14 to 29%). gap = quotas between the last seat\n",
    "   in and the first loser; under about 0.2 the seat is decided by preferences and this table cannot call it.\n", sep = "")
print(R[order(region)], row.names = FALSE)
cat(sprintf("\nTotal of 40: Labor %d, Coalition %d, One Nation %d, Greens %d, minor %d. Seats with a gap under 0.20: %d of 8 regions.\n",
            sum(R$ALP), sum(R$LNP), sum(R$ONP), sum(R$GRN), sum(R$minor), sum(R$gap < 0.2)))
cat("2022 result for comparison: Labor 15, Coalition 14, Greens 4, Legalise Cannabis 2, One Nation 1, and 4 other minors (40).\n")
