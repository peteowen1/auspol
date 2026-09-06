# Follow-up to compare_fed2025_vs_aef.R: WHERE do the log-loss and primary-RMSE
# gaps against AE Forecasts actually live, seat by seat? Ad-hoc, requested
# directly 2026-09-04. Needs output/backtest-fed2025-baseline-correct.csv,
# output/aef-seat-scores.csv and output/dump-shares-fed2025.csv already built
# (see compare_fed2025_vs_aef.R's header for the exact commands -- SHRINK and
# DEV_SLOPE_MODE matter, the bare harness defaults do not match what ships).
#
# Emits FVB* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

EPS <- 1e-6
ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))

# ---- FVB1: per-seat log loss, ours vs AEF -----------------------------------
B <- fread("output/backtest-fed2025-baseline-correct.csv", showProgress = FALSE)
B[, `:=`(.s = ns(seat), our_ll = -log(pmax(prob, EPS)))]

A <- fread("output/aef-seat-scores.csv", showProgress = FALSE)[election == "2025fed"]
A[, `:=`(.s = ns(seat), aef_ll = -log(pmax(prob, EPS)))]

LL <- merge(B[, .(.s, seat, our_pred = pred, actual, our_prob = prob, our_ll)],
           A[, .(.s, aef_pred = pred, aef_prob = prob, aef_ll)], by = ".s")
LL[, gap := our_ll - aef_ll]  # positive: we lose here

cat(sprintf("FVB1 %d seats compared on log loss (ours has %d, AEF has %d, before matching)\n",
            nrow(LL), nrow(B), nrow(A)))

cat("\nFVB1a our 10 worst individual log-loss seats:\n")
print(LL[order(-our_ll)][1:10, .(seat, actual, our_pred, our_prob = round(our_prob,3),
                                  aef_pred, aef_prob = round(aef_prob,3),
                                  our_ll = round(our_ll,2), aef_ll = round(aef_ll,2))])

cat("\nFVB1b biggest log-loss GAP -- we lose most here relative to AEF:\n")
print(LL[order(-gap)][1:10, .(seat, actual, our_pred, our_prob = round(our_prob,3),
                              aef_pred, aef_prob = round(aef_prob,3), gap = round(gap,2))])

cat("\nFVB1c biggest log-loss gap the OTHER way -- where we clearly beat AEF:\n")
print(LL[order(gap)][1:10, .(seat, actual, our_pred, our_prob = round(our_prob,3),
                             aef_pred, aef_prob = round(aef_prob,3), gap = round(gap,2))])

# ---- FVB2: per-seat-party primary vote error, ours vs AEF ------------------
# CA = Centre Alliance (Sharkie, Mayo), maps to IND -- see compare_fed2025_vs_aef.R.
AEF_MAP <- c(ALP = "ALP", LNP = "LNP", NAT = "NAT", GRN = "GRN", IND = "IND",
            OTH = "OTH", ON = "ONP", UAP = "OTH_RIGHT", KAP = "OTH_RIGHT",
            CA = "IND", DLP = "OTH_RIGHT", DEM = "OTH")
C <- fread("output/candidacies.csv", showProgress = FALSE)
actual_pv <- C[election == "fed2025", .(seat = ns(seat), party, pcv)][, .(pcv = sum(pcv)), by = .(seat, party)]

j <- fromJSON(file.path("external", "reference", "aef", "2025fed-summary.json"),
             simplifyVector = FALSE)$report
lookup <- setNames(vapply(j$partyAbbr, function(p) p[[2]], character(1)),
                   vapply(j$partyAbbr, function(p) as.character(p[[1]]), character(1)))
seat_names <- unlist(j$seatNames)
fp <- j$seatFpBands
aef_rows <- list()
for (i in seq_along(seat_names)) {
  entry <- fp[[i]]
  if (!length(entry)) next
  for (pair in entry) {
    idx <- as.character(pair[[1]]); bands <- unlist(pair[[2]])
    if (length(bands) < 8 || !idx %in% names(lookup)) next
    cls <- AEF_MAP[unname(lookup[idx])]
    if (is.na(cls)) next
    aef_rows[[length(aef_rows) + 1L]] <- data.table(
      seat = ns(seat_names[i]), party = cls, aef_pcv = bands[8])
  }
}
AEFPV <- rbindlist(aef_rows)[, .(aef_pcv = sum(aef_pcv)), by = .(seat, party)]

OURS <- fread("output/dump-shares-fed2025.csv", showProgress = FALSE)
OURS[, seat := ns(seat)]

PV <- merge(actual_pv, AEFPV, by = c("seat", "party"))
PV <- merge(PV, OURS[, .(seat, party, our_pcv = projected_share)], by = c("seat", "party"))
PV[, `:=`(our_err = our_pcv - pcv, aef_err = aef_pcv - pcv)]
PV[, `:=`(our_abserr = abs(our_err), aef_abserr = abs(aef_err))]
PV[, gap := our_abserr - aef_abserr]

cat(sprintf("\nFVB2 %d (seat, party) primary-vote rows compared on both sides\n", nrow(PV)))

cat("\nFVB2a our 10 worst individual primary-vote misses:\n")
print(PV[order(-our_abserr)][1:10, .(seat, party, pcv = round(pcv,1), our_pcv = round(our_pcv,1),
                                     our_err = round(our_err,1), aef_pcv = round(aef_pcv,1),
                                     aef_err = round(aef_err,1))])

cat("\nFVB2b biggest primary-vote error GAP -- we lose most here relative to AEF:\n")
print(PV[order(-gap)][1:10, .(seat, party, pcv = round(pcv,1), our_err = round(our_err,1),
                              aef_err = round(aef_err,1), gap = round(gap,1))])

cat("\nFVB2c biggest gap the OTHER way -- where we clearly beat AEF on primary vote:\n")
print(PV[order(gap)][1:10, .(seat, party, pcv = round(pcv,1), our_err = round(our_err,1),
                             aef_err = round(aef_err,1), gap = round(gap,1))])

# ---- FVB3: is the log-loss gap concentrated by predicted party? -----------
cat("\nFVB3 mean log-loss gap by OUR predicted party (positive = we lose there):\n")
print(LL[, .(n = .N, mean_gap = round(mean(gap), 3), mean_our_ll = round(mean(our_ll), 3),
            mean_aef_ll = round(mean(aef_ll), 3)), by = our_pred][order(-mean_gap)])
