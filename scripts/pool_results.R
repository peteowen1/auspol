# ONE canonical, always-current, per-seat-per-party results table --
# win probability AND predicted primary share AND actual, for every pair,
# in one file. Written 2026-09-17 after tracing one seat's wrong number on
# the AEF-7 Seat Ledger cost five manual greps through differently-
# fingerprinted CSVs before finding that a comparison script had picked up
# a stale pooled file. Pete's own words: "we should save all the results of
# the forecast for every seat for exactly this reason! this should now just
# be a quick query in our results table and should take less than a second
# to find out."
#
# WHAT MAKES THIS DIFFERENT FROM pool_backtests.R / pool_sharedetail.R:
# those each pool ONE file type "newest per pair", independently of each
# other -- which is exactly how the bug above happened. A win-probability
# file and a sharedetail file can each be individually "the newest one for
# this pair" while coming from DIFFERENT arms, if one was regenerated and
# the other was not. This script instead: finds the newest WIN file per
# pair, reads that file's OWN arm fingerprint out of its filename, and
# requires the sharedetail/allprobs files it joins to carry the SAME
# fingerprint -- refusing the join outright if they don't, rather than
# silently mixing arms.
#
# OUTPUT: output/results-current.csv, one row per (pair, seat, party):
#   pair, seat, party, is_winner, is_our_pick, our_prob, our_primary,
#   actual_primary, arm_fingerprint, code, mtime
#
# QUERY IT DIRECTLY instead of grepping output/ for a specific seat:
#   fread("output/results-current.csv")[seat=="Murray" & pair=="nsw2023"]
#
# Run this after any backtest rerun, before trusting any per-seat lookup.
#
# KNOWN LIMITATION, per CITIUS's design feedback on this exact idea
# (cross-session exchange 2026-09-17, its own forecast_archive.parquet):
# the fingerprint here is parsed out of each SOURCE FILE'S NAME via regex,
# not read from an internal column -- fragile, and "the specific failure
# you hit" per their words. The OUTPUT of this script does the right thing
# (arm_fingerprint is a real column results-current.csv can be filtered
# on), but the underlying win/allprobs/sharedetail files would need each
# harness to write .arm_fingerprint as its own CSV column, not just bake
# it into the filename, to close this properly. Not done here -- retrofitting
# six harnesses is a separate, bigger change. Noted as the next step.
#
# Emits PR* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"

PAIRS <- c("fed2007","fed2010","fed2013","fed2016","fed2019","fed2022","fed2025",
           "nsw2019","nsw2023","qld2020","qld2024","sa2022","sa2026",
           "vic2014","vic2018","vic2022","wa2001","wa2005","wa2008","wa2013",
           "wa2017","wa2021","wa2025")
# ONLY the harnesses that run several pairs in ONE invocation by default
# (fed, sa, vic, wa -- each writes one file per run with an internal `pair`
# column) use the REGION name in their filename. nsw and qld each run
# exactly one pair per invocation (AUSPOL_NSW_PAIR/AUSPOL_QLD_PAIR), so
# their filename embeds the full pair name directly (e.g.
# "backtest-nsw2023-...csv") -- NOT a shared "backtest-nsw-...csv". Getting
# this wrong matches nsw2019 and nsw2023 to the SAME file (whichever is
# newest) and silently mislabels one of them.
PREFIX <- c(sa="sa", vic="vic", wa="wa")

region_of <- function(pr) if (grepl("^fed", pr)) "fed" else sub("[0-9]+$", "", pr)

# The newest WIN file that ACTUALLY CONTAINS this pair -- not just the
# newest file overall. A multi-pair harness restricted to fewer pairs
# (AUSPOL_FED_PAIRS=2022,2025, used earlier today) writes a file that is
# newer than the last full run but covers none of the OTHER pairs, so
# picking "newest" blindly would report those as missing even though a
# perfectly good, slightly older file has them. Search newest-first and
# take the first candidate whose own `pair` column (or filename, for a
# single-pair file) actually includes the target.
newest_win_file <- function(pr) {
  rg <- region_of(pr)
  pat <- if (rg == "fed") "^backtest-fed-"
         else if (rg %in% names(PREFIX)) sprintf("^backtest-%s-", PREFIX[[rg]])
         else sprintf("^backtest-%s-", pr)
  g <- list.files(OUT, pattern = pat, full.names = TRUE)
  g <- g[!grepl("sharedetail|allprobs|totals|-seatsd|-diag|ourtcp", g)]
  if (!length(g)) return(NULL)
  g <- g[order(file.mtime(g), decreasing = TRUE)]
  for (f in g) {
    x <- tryCatch(fread(f, showProgress = FALSE, nrows = 5), error = function(e) NULL)
    if (is.null(x)) next
    if ("pair" %in% names(x)) {
      full <- tryCatch(fread(f, select = "pair", showProgress = FALSE), error = function(e) NULL)
      if (!is.null(full) && pr %in% full$pair) return(f)
    } else if (grepl(pr, basename(f), fixed = TRUE)) {
      return(f)
    }
  }
  NULL
}

# This pair's arm fingerprint, read out of the win file's own name --
# the "-a<hex>" hash every harness appends (see any backtest_candidate_*.R's
# .arm_fingerprint block). Two files sharing this tag came from the same run.
fingerprint_of <- function(f) {
  m <- regmatches(basename(f), regexpr("-a[0-9a-f]{6}", basename(f)))
  if (!length(m)) NA_character_ else m
}
code_of <- function(f) {
  m <- regmatches(basename(f), regexpr("-g[0-9a-f]{7}x?(?=\\.csv$)", basename(f), perl = TRUE))
  if (!length(m)) NA_character_ else sub("^-g", "", m)
}

matched_file <- function(pr, kind, fp) {
  rg <- region_of(pr)
  pat <- if (rg == "fed") sprintf("^backtest-fed-.*%s.*%s", kind, fp)
         else if (rg %in% names(PREFIX)) sprintf("^backtest-%s-.*%s.*%s", PREFIX[[rg]], kind, fp)
         else sprintf("^backtest-%s.*%s.*%s", pr, kind, fp)
  g <- list.files(OUT, pattern = pat, full.names = TRUE)
  if (!length(g)) return(NULL)
  g[which.max(file.mtime(g))]
}

rows <- list(); skipped <- character(0); stale_report <- list()
for (pr in PAIRS) {
  wf <- newest_win_file(pr)
  if (is.null(wf)) { skipped <- c(skipped, pr); next }
  fp <- fingerprint_of(wf); cd <- code_of(wf)
  if (is.na(fp)) { cat(sprintf("PR1! %s: win file has no arm fingerprint in its name (%s) -- skipped\n", pr, basename(wf))); skipped <- c(skipped, pr); next }

  win <- fread(wf, showProgress = FALSE)
  if ("pair" %in% names(win)) win <- win[win$pair == pr]
  pcol <- if ("prob" %in% names(win)) "prob" else if ("p" %in% names(win)) "p" else NA_character_
  if (is.na(pcol) || !nrow(win)) { cat(sprintf("PR1! %s: win file unreadable/empty -- skipped\n", pr)); skipped <- c(skipped, pr); next }
  win <- unique(win[, .(seat, actual, our_pick = pred, our_pick_prob = get(pcol))])

  af <- matched_file(pr, "allprobs", fp)
  sf <- matched_file(pr, "sharedetail", fp)
  if (is.null(af)) cat(sprintf("PR2! %s: no allprobs file matching fingerprint %s -- per-party win probability limited to the favourite\n", pr, fp))
  if (is.null(sf)) cat(sprintf("PR2! %s: no sharedetail file matching fingerprint %s -- no primary-share column\n", pr, fp))

  ap <- if (!is.null(af)) { x <- fread(af, showProgress = FALSE); if ("pair" %in% names(x)) x <- x[x$pair == pr]; unique(x[, .(seat, party, our_prob = prob)]) } else NULL
  sd <- if (!is.null(sf)) { x <- fread(sf, showProgress = FALSE); if ("pair" %in% names(x)) x <- x[x$pair == pr]; x[, .(our_primary = mean(pred_share), actual_primary = mean(actual_share)), by = .(seat, party)] } else NULL

  seats <- win$seat
  parties <- unique(c(if (!is.null(ap)) ap$party, if (!is.null(sd)) sd$party, win$actual, win$our_pick))
  base <- CJ(seat = seats, party = parties, sorted = FALSE)
  base <- merge(base, win, by = "seat", all.x = TRUE)
  if (!is.null(ap)) base <- merge(base, ap, by = c("seat","party"), all.x = TRUE) else base[, our_prob := NA_real_]
  if (!is.null(sd)) base <- merge(base, sd, by = c("seat","party"), all.x = TRUE) else base[, `:=`(our_primary = NA_real_, actual_primary = NA_real_)]
  # Where allprobs is missing, the favourite's own probability from the win
  # file is the only value we have -- fill it in for that one row so the
  # table is not falsely empty for the seat's actual outcome.
  base[is.na(our_prob) & party == our_pick, our_prob := our_pick_prob]
  base[, `:=`(is_winner = party == actual, is_our_pick = party == our_pick,
              pair = pr, arm_fingerprint = fp, code = cd, mtime = as.character(file.mtime(wf)))]
  rows[[pr]] <- base[, .(pair, seat, party, is_winner, is_our_pick,
                          our_prob, our_primary, actual_primary,
                          arm_fingerprint, code, mtime)]
}

if (length(skipped)) cat(sprintf("PR0! %d pair(s) had no readable win file: %s\n", length(skipped), paste(skipped, collapse=", ")))

RESULTS <- rbindlist(rows, fill = TRUE)
setorder(RESULTS, pair, seat, -is_winner, -is_our_pick)
out_path <- file.path(OUT, "results-current.csv")
fwrite(RESULTS, out_path)

age_days <- round(as.numeric(difftime(Sys.time(), as.POSIXct(RESULTS[, max(mtime), by = pair]$V1), units = "days")), 1)
cat(sprintf("PR3 wrote %s: %d rows, %d pairs, %d seats\n", out_path, nrow(RESULTS), uniqueN(RESULTS$pair), uniqueN(RESULTS$seat)))
age_tbl <- RESULTS[, .(age_days = round(as.numeric(difftime(Sys.time(), max(as.POSIXct(mtime)), units = "days")), 1)), by = pair]
setorder(age_tbl, -age_days)
cat("PR4 freshness (days since this pair's file was written) -- oldest first:\n")
print(age_tbl)
