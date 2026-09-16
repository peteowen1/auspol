# AE Forecasts' own TCP (two-candidate-preferred) prediction, per seat.
#
# WHY THIS EXISTS. Pete pointed out AEForecasts.com's live site shows a TCP
# scenario table with confidence ranges -- score_aeforecasts.R only ever
# parsed seatPartyWinFrequencies (win probability) and fpTrend (primary
# vote). The TCP data was sitting in our own cached
# external/reference/aef/*-summary.json all along, unparsed:
#   seatTcpScenarios[seat] = list of [[partyA, partyB], frequency] -- which
#     pairing AEF's simulation thinks reaches the final two, and how often.
#   seatTcpBands[seat]     = for each such pairing, party A's TCP% at 15
#     percentile points (index 7 is the median, points symmetric around it).
# Both indexed positionally against seatNames, party indices resolved via
# partyAbbr/partyName (own lookup table per file, negative indices are
# generic/emerging candidates of that type).
#
# For each seat this takes AEF's SINGLE most-likely pairing (highest
# scenario frequency) and reports party A's median predicted TCP% for it --
# the same "headline number" the site displays. A seat with a closely split
# scenario distribution (e.g. 55/45 between two different pairings) is
# reported on its majority pairing only; scenario_freq is included so that
# ambiguity is visible rather than hidden.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

RAW <- file.path("external", "reference", "aef")

# our pair label -> AE Forecasts' file prefix
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
    message("build_aef_tcp: missing ", fs, " for ", pair_label)
    return(NULL)
  }
  j <- fromJSON(fs, simplifyVector = FALSE)$report
  seats <- unlist(j$seatNames)
  lookup <- aef_class_lookup(j$partyAbbr, j$partyName)
  scen <- j$seatTcpScenarios
  band <- j$seatTcpBands
  stopifnot(length(scen) == length(seats), length(band) == length(seats))

  rows <- vector("list", length(seats))
  for (i in seq_along(seats)) {
    sc <- scen[[i]]
    if (!length(sc)) next
    freqs <- vapply(sc, function(x) as.numeric(x[[2]]), numeric(1))
    best <- which.max(freqs)
    pr <- sc[[best]][[1]]
    idxA <- as.character(pr[[1]]); idxB <- as.character(pr[[2]])

    bd <- band[[i]]
    bmatch <- NULL
    for (b in bd) {
      bp <- b[[1]]
      if (as.character(bp[[1]]) == idxA && as.character(bp[[2]]) == idxB) { bmatch <- b; break }
    }
    if (is.null(bmatch)) next
    pctiles <- unlist(bmatch[[2]])
    if (length(pctiles) != 15) next
    median_a <- pctiles[8]  # 0-indexed 7th -> R's 8th, symmetric middle of 15 points

    rows[[i]] <- data.table(
      pair = pair_label, seat = seats[i],
      aef_tcp_f1 = unname(lookup[idxA]), aef_tcp_f2 = unname(lookup[idxB]),
      aef_tcp_pct = round(median_a, 1),
      aef_tcp_scenario_freq = round(freqs[best], 4),
      aef_tcp_p05 = round(pctiles[2], 1), aef_tcp_p95 = round(pctiles[14], 1)
    )
  }
  rbindlist(rows, fill = TRUE)
}

all <- rbindlist(Map(build_one, names(PAIRS), unname(PAIRS)), fill = TRUE)
stopifnot(nrow(all) > 0)

cat(sprintf("AT1  parsed AEF TCP scenarios for %d seats across %d pairs\n",
            nrow(all), uniqueN(all$pair)))
print(all[, .N, by = pair][order(pair)])

na_cls <- all[is.na(aef_tcp_f1) | is.na(aef_tcp_f2)]
if (nrow(na_cls)) {
  cat(sprintf("AT2  WARNING: %d rows have an unclassified party (classify_party returned NA)\n",
              nrow(na_cls)))
  print(na_cls)
}

fwrite(all, file.path("output", "aef7-tcp.csv"))
cat(sprintf("AT3  wrote output/aef7-tcp.csv (%d rows)\n", nrow(all)))
