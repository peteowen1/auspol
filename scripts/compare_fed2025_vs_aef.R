# Ad-hoc: how does our fed2025 forecast compare to AE Forecasts, on primary
# vote RMSE, seat win-probability log loss/Brier, and national TPP error?
# Requested directly by Pete 2026-09-04. Not a pre-registered test -- a status
# comparison against an existing public benchmark, using infrastructure that
# already exists (scripts/score_aeforecasts.R, scripts/backtest_candidate_fed.R's
# AUSPOL_FORECAST_MODE, output/dump-shares-fed2025.csv from AUSPOL_DUMP_SHARES=1).
#
# FORECAST MODE, not the oracle backtest: docs/reviews/aeforecasts-benchmark-2026-08-22.md
# already found the oracle backtest (fed statewide result fed in as ground truth)
# is not a fair comparison to a real forecaster. AUSPOL_FORECAST_MODE=1 uses only
# what a poll-trend as of the day before the election would have known -- the
# same information AEF had. Requires:
#   AUSPOL_FORECAST_MODE=1 AUSPOL_FED_PAIRS=2025 AUSPOL_SHRINK=0.10 \
#     AUSPOL_DEV_SLOPE_MODE=screened AUSPOL_DUMP_SHARES=1 \
#     Rscript scripts/backtest_candidate_fed.R
# run first (this script does not run it, to keep the two runs separable and
# because the harness needs its own time to fit trend models). SHRINK and
# DEV_SLOPE_MODE matter: the harness's bare defaults (shrink=0, uniform swing)
# do NOT match the published model (shrink=0.10, screened slopes) -- found
# 2026-09-04 when Mayo's returning MP scored exactly 0% under the bare
# defaults, purely because the candidate-identity override was never active.
# Copy the resulting output/backtest-fed-p2025*.csv to
# output/backtest-fed2025-baseline-correct.csv before rerunning with a
# different arm (e.g. surge-v2), or the next run overwrites it.
#
# Emits FVA* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

# CA = Centre Alliance (Rebekha Sharkie, Mayo) -- NOT a Christian-right party
# despite the abbreviation's look. Confirmed against AEF's own partyName field
# ("Centre Alliance"), not guessed. We classify her as IND (candidacies.csv
# has no CA class of its own), so CA maps there, not OTH_RIGHT -- got this
# wrong on the first pass 2026-09-04, which made the Mayo comparison read as
# "AEF called it CA at 83.5%" instead of what it actually was: AEF and our own
# classify_party() agree on what Sharkie's seat is, and only our own
# projection (before the config fix below) said 0%.
AEF_MAP <- c(ALP = "ALP", LNP = "LNP", NAT = "NAT", GRN = "GRN", IND = "IND",
            OTH = "OTH", ON = "ONP", UAP = "OTH_RIGHT", KAP = "OTH_RIGHT",
            CA = "IND", DLP = "OTH_RIGHT", DEM = "OTH")

# ---- FVA1: primary vote RMSE ------------------------------------------------
ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))
C <- fread("output/candidacies.csv", showProgress = FALSE)
actual <- C[election == "fed2025", .(seat = ns(seat), party, pcv)]
# Same-seat-same-class candidates already summed by classify_party() upstream?
# No -- collapse defensively: two OTH candidates in one seat must sum, not
# silently pick one via a keyed join.
actual <- actual[, .(pcv = sum(pcv)), by = .(seat, party)]

j <- fromJSON(file.path("external", "reference", "aef", "2025fed-summary.json"),
             simplifyVector = FALSE)$report
lookup <- setNames(vapply(j$partyAbbr, function(p) p[[2]], character(1)),
                   vapply(j$partyAbbr, function(p) as.character(p[[1]]), character(1)))
seat_names <- unlist(j$seatNames)
fp <- j$seatFpBands
# voteTotalThresholds confirms the 15-band index for the MEDIAN (50th
# percentile): position 8 (1-indexed) / index 7 (0-indexed).
stopifnot(abs(unlist(j$voteTotalThresholds)[8] - 50) < 1e-6)
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
AEF <- rbindlist(aef_rows)[, .(aef_pcv = sum(aef_pcv)), by = .(seat, party)]

m_aef <- merge(actual, AEF, by = c("seat", "party"))
cat(sprintf("FVA1 AEF primary-vote match: %d of %d actual (seat,party) rows matched\n",
            nrow(m_aef), nrow(actual)))
aef_rmse <- sqrt(mean((m_aef$pcv - m_aef$aef_pcv)^2))
aef_mae  <- mean(abs(m_aef$pcv - m_aef$aef_pcv))

dump_f <- "output/dump-shares-fed2025.csv"
if (!file.exists(dump_f)) {
  stop("FVA1 needs ", dump_f, " -- run:\n",
      "  AUSPOL_FORECAST_MODE=1 AUSPOL_FED_PAIRS=2025 AUSPOL_DUMP_SHARES=1 ",
      "Rscript scripts/backtest_candidate_fed.R")
}
OURS <- fread(dump_f, showProgress = FALSE)
OURS[, seat := ns(seat)]
m_ours <- merge(actual, OURS[, .(seat, party, our_pcv = projected_share)],
               by = c("seat", "party"))
cat(sprintf("FVA1 our primary-vote match: %d of %d actual (seat,party) rows matched\n",
            nrow(m_ours), nrow(actual)))
our_rmse <- sqrt(mean((m_ours$pcv - m_ours$our_pcv)^2))
our_mae  <- mean(abs(m_ours$pcv - m_ours$our_pcv))

cat("\nFVA1 SEAT PRIMARY VOTE, fed2025:\n")
print(data.table(model = c("ours (forecast mode)", "AE Forecasts"),
                 n = c(nrow(m_ours), nrow(m_aef)),
                 rmse = round(c(our_rmse, aef_rmse), 2),
                 mae = round(c(our_mae, aef_mae), 2)))

# ---- FVA2: seat win-probability log loss / Brier / accuracy ---------------
if (!file.exists("output/aef-seat-scores.csv")) {
  message("FVA2 run scripts/score_aeforecasts.R first for AEF win-prob scores")
} else {
  A <- fread("output/aef-seat-scores.csv", showProgress = FALSE)
  A <- A[election == "2025fed"]
  EPS <- 1e-6
  cat(sprintf("\nFVA2 AE Forecasts, fed2025, %d seats: accuracy %.1f%% | Brier %.4f | log loss %.4f\n",
              nrow(A), 100 * mean(A$pred == A$actual), mean((1 - A$prob)^2),
              -mean(log(pmax(A$prob, EPS)))))
}
bf_f <- "output/backtest-fed2025-baseline-correct.csv"
if (!file.exists(bf_f)) {
  message("FVA2 ", bf_f, " not found -- rerun the harness with ",
         "AUSPOL_DEV_SLOPE_MODE=screened AUSPOL_SHRINK=0.10 (see header)")
} else {
  B <- fread(bf_f, showProgress = FALSE)
  B <- B[pair == "2022-2025" | grepl("2025", pair)]
  if (!nrow(B)) B <- fread(file.path("output", bf_files[1]), showProgress = FALSE)
  EPS <- 1e-6
  cat(sprintf("FVA2 ours (forecast mode), fed2025, %d seats: accuracy %.1f%% | Brier %.4f | log loss %.4f\n",
              nrow(B), 100 * mean(B$pred == B$actual), mean((1 - B$prob)^2),
              -mean(log(pmax(B$prob, EPS)))))
}

# ---- FVA3: national TPP -----------------------------------------------------
tpp_median <- unlist(j$tppTrend[[length(j$tppTrend)]])[4]  # trendProbBands index for 50th pctile
cat(sprintf("\nFVA3 AE Forecasts final ALP TPP median: %.2f\n", tpp_median))
cat("FVA3 our own trend_as_at() TPP point estimate: see docs/reviews/forecast-mode-2026-08-22.md ",
   "(52.48 as of that measurement) -- rerun trend_as_at() fresh if a current number is needed.\n", sep = "")
