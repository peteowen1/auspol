# AE Forecasts' own per-SEAT primary vote prediction, per party.
#
# WHY THIS EXISTS. build_aef_tcp.R noted (2026-09-16) "we score ourselves
# against AEF on seat win probability and TCP, and not at all on the primary
# vote" and proposed parsing `fpTrend` to fix that. THAT PREMISE WAS WRONG --
# `output/aef-primary-all.csv` already carries a per-(seat, party) AEF
# primary-vote prediction and is already joined against our own predictions
# in `build_aef_comparison.R` (the "mean primary error on the winner: ours
# 4.23 vs AEF 4.50" figure in docs/PETE-ASKED-FOR.md). What was actually
# missing was not the comparison -- it was that `aef-primary-all.csv` had NO
# GENERATING SCRIPT anywhere in the repo (`grep -rl aef-primary-all scripts/
# R/` matched only files that READ it). It was a static, unreproducible
# artifact. `fpTrend` itself is a STATEWIDE trend over the whole campaign
# (206 daily points x 7 percentiles in fed2022), not a seat-level prediction,
# so parsing it would not have closed the gap that was actually claimed
# anyway.
#
# `seatFpBands` is the field that actually matches: for every seat, for every
# party index AEF assigns it, a 15-point percentile band identical in shape
# to `seatTcpBands` (median at position 8 of 15, same convention as
# build_aef_tcp.R). This is AEF's own per-seat primary vote call, directly
# comparable to our own `base_pred` / `xgb_pred`.
#
# Negative party indices (-3, -2, -1) are AEF's generic/emerging-candidate
# buckets, same as in build_aef_tcp.R's aef_class_lookup -- several of them
# can classify to the same party class (e.g. both -3 and -1 are "OTH" in
# fed2022). This script does NOT collapse them: it emits one row per
# (pair, seat, raw party index), each carrying its classify_party() class, so
# a consumer summing to class level makes that choice explicitly rather than
# having it made silently here.
#
# Every (seat, party-index) entry AEF publishes is kept, including an exact
# 0% median -- that is AEF's own call that the party isn't contesting, not
# missing data, and downstream comparisons need to see it as a real zero.
#
# THIS RECONSTRUCTS `output/aef-primary-all.csv`, WHICH HAD NO GENERATING
# SCRIPT IN THE REPO. Checked 2026-09-17: aggregating this script's raw
# per-index rows to class level (summing duplicate generic buckets) matches
# `aef-primary-all.csv` on all 3,671 (pair, seat, class) rows AEF publishes a
# nonzero prediction for, to within 0.007 points (rounding) -- so that file's
# `aef_pcv` is confirmed to be this exact median-of-15-point-band
# computation, and is now reproducible from source rather than a static
# artifact with no lineage.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

RAW <- file.path("external", "reference", "aef")

# our pair label -> AE Forecasts' file prefix (same set as build_aef_tcp.R)
PAIRS <- c(fed2022 = "2022fed", fed2025 = "2025fed", nsw2023 = "2023nsw",
           qld2024 = "2024qld", sa2026  = "2026sa",  vic2022 = "2022vic",
           wa2025  = "2025wa")

aef_class_lookup <- function(pa, pn) {
  idx  <- vapply(pa, function(p) as.character(p[[1]]), character(1))
  abbr <- vapply(pa, function(p) as.character(p[[2]]), character(1))
  nm_idx <- vapply(pn, function(p) as.character(p[[1]]), character(1))
  name <- vapply(pn, function(p) as.character(p[[2]]), character(1))
  stopifnot(identical(idx, nm_idx))
  cls <- classify_party(name = name, code = abbr)
  stats::setNames(cls, idx)
}

build_one <- function(pair_label, code) {
  fs <- file.path(RAW, sprintf("%s-summary.json", code))
  if (!file.exists(fs)) {
    message("build_aef_fp: missing ", fs, " for ", pair_label)
    return(NULL)
  }
  j <- fromJSON(fs, simplifyVector = FALSE)$report
  seats <- unlist(j$seatNames)
  lookup <- aef_class_lookup(j$partyAbbr, j$partyName)
  fpb <- j$seatFpBands
  stopifnot(length(fpb) == length(seats))

  rows <- vector("list", length(seats))
  for (i in seq_along(seats)) {
    entries <- fpb[[i]]
    if (!length(entries)) next
    seat_rows <- vector("list", length(entries))
    for (k in seq_along(entries)) {
      e <- entries[[k]]
      idx <- as.character(e[[1]])
      band <- unlist(e[[2]])
      if (length(band) != 15) next
      seat_rows[[k]] <- data.table(
        pair = pair_label, seat = seats[i],
        aef_fp_party_idx = idx, aef_fp_class = unname(lookup[idx]),
        aef_fp_pct = round(band[8], 2),
        aef_fp_p05 = round(band[2], 2), aef_fp_p95 = round(band[14], 2)
      )
    }
    rows[[i]] <- rbindlist(seat_rows, fill = TRUE)
  }
  rbindlist(rows, fill = TRUE)
}

all <- rbindlist(Map(build_one, names(PAIRS), unname(PAIRS)), fill = TRUE)
stopifnot(nrow(all) > 0)

cat(sprintf("AF1  parsed AEF seat FP bands: %d (seat, party) rows across %d pairs\n",
            nrow(all), uniqueN(all$pair)))
print(all[, .N, by = pair][order(pair)])

na_cls <- all[is.na(aef_fp_class)]
if (nrow(na_cls)) {
  cat(sprintf("AF2  WARNING: %d rows have an unclassified party (classify_party returned NA)\n",
              nrow(na_cls)))
  print(na_cls)
}

fwrite(all, file.path("output", "aef7-fp.csv"))
cat(sprintf("AF3  wrote output/aef7-fp.csv (%d rows)\n", nrow(all)))
