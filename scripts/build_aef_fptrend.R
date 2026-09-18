# AE Forecasts' own per-party primary vote prediction, per seat -- the
# companion to build_aef_tcp.R for the primary stage instead of TCP.
#
# WHY THIS EXISTS. build_aef_tcp.R's own header flagged this as unparsed:
# AEF's cached *-summary.json carries `seatFpBands[seat] = list of
# [partyIndex, 15 percentile points]` for every party's predicted primary
# vote, keyed by the SAME global party index space as `seatTcpScenarios`
# (partyAbbr/partyName) -- not the per-seat candidate index in
# seatCandidateNames, which is a different, local numbering. Verified
# against a real seat before trusting it (Frankston, vic2022): AEF's median
# ALP/LNP/GRN read 44.7/32.4/6.6 against our 40.3/32.1/8.8 and the real
# 41.5/29.4/12.7 -- same ballpark as ours, not garbage.
#
# A seat can carry MULTIPLE party-index entries that map to the SAME class
# (Frankston has index -1 AND -3 both classifying as OTH, for two different
# minor candidates AEF tracks separately) -- these are SUMMED to the class
# level before comparing against our own class-level pred_share, the same
# aggregation our own model already uses.
#
# Pete asked 2026-09-18 for the AEF side of the ledger's weighted primary
# RMSE, which needed this parser built, not guessed at.
#
# Emits AFT codes. Writes output/aef7-fptrend.csv.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

RAW <- file.path("external", "reference", "aef")
OUT <- "output"
AEF_CODE <- c(fed2022 = "2022fed", fed2025 = "2025fed", nsw2023 = "2023nsw",
              qld2024 = "2024qld", sa2026  = "2026sa",  vic2022 = "2022vic",
              wa2025  = "2025wa")

aef_class_lookup <- function(pa, pn) {
  idx  <- vapply(pa, function(p) as.character(p[[1]]), character(1))
  abbr <- vapply(pa, function(p) as.character(p[[2]]), character(1))
  nm_idx <- vapply(pn, function(p) as.character(p[[1]]), character(1))
  name <- vapply(pn, function(p) as.character(p[[2]]), character(1))
  stopifnot(identical(idx, nm_idx))
  stats::setNames(classify_party(name = name, code = abbr), idx)
}

build_one <- function(pair_label, code) {
  fs <- file.path(RAW, sprintf("%s-summary.json", code))
  if (!file.exists(fs)) { message("build_aef_fptrend: missing ", fs, " for ", pair_label); return(NULL) }
  j <- fromJSON(fs, simplifyVector = FALSE)$report
  seats <- unlist(j$seatNames)
  lookup <- aef_class_lookup(j$partyAbbr, j$partyName)
  fb <- j$seatFpBands
  stopifnot(length(fb) == length(seats))

  rows <- vector("list", length(seats))
  for (i in seq_along(seats)) {
    entries <- fb[[i]]
    if (!length(entries)) next
    idx <- vapply(entries, function(e) as.character(e[[1]]), character(1))
    cls <- unname(lookup[idx])
    med <- vapply(entries, function(e) {
      p <- unlist(e[[2]])
      if (length(p) != 15) return(NA_real_)
      p[8]
    }, numeric(1))
    ok <- !is.na(cls) & !is.na(med)
    if (!any(ok)) next
    dt <- data.table(seat = seats[i], party = cls[ok], aef_fp_pred = med[ok])
    rows[[i]] <- dt[, .(aef_fp_pred = sum(aef_fp_pred)), by = .(seat, party)]
  }
  out <- rbindlist(rows, fill = TRUE)
  out[, pair := pair_label]
  out
}

all <- rbindlist(Map(build_one, names(AEF_CODE), unname(AEF_CODE)), fill = TRUE)
stopifnot(nrow(all) > 0)
cat(sprintf("AFT1 parsed AEF fpBands for %d (seat,party) cells across %d pairs\n",
            nrow(all), uniqueN(all$pair)))
print(all[, .N, by = pair][order(pair)])

fwrite(all, file.path(OUT, "aef7-fptrend.csv"))
cat(sprintf("AFT2 wrote %s (%d rows)\n", file.path(OUT, "aef7-fptrend.csv"), nrow(all)))

# Quick sanity check against the real result, same shape as fit-time checks
# elsewhere in this repo -- printed, not asserted, since AEF's own numbers
# are allowed to differ from ours.
sd <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)
chk <- merge(all, sd, by = c("pair", "seat", "party"))
cat(sprintf("\nAFT3 sanity: %d of %d parsed cells joined to a real actual_share\n", nrow(chk), nrow(all)))
cat(sprintf("AFT3 mean |AEF pred - actual| = %.2f (ours, for comparison, = %.2f)\n",
            mean(abs(chk$aef_fp_pred - chk$actual_share)),
            mean(abs(chk$pred_share - chk$actual_share))))
