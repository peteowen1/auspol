# The independent/minor EMERGENCE case list -- the 93% of our AEF gap.
#
# WHY. On the 7 AEF-comparable elections we BEAT AE Forecasts on the 601 seats
# a major party won (0.2429 vs 0.2525) and lose the overall on the other 58.
# Total log-loss damage against AEF by winner: IND +5.21, ONP +3.49, GRN +2.97,
# against LNP -6.25. And the cause is the primary vote, not the flows -- mean
# absolute error on the winner's own primary is 8.3 points for us against AEF's
# 5.7 on IND-won seats, while on ALP and LNP we are BETTER than AEF.
#
# One more split says what KIND of problem it is: fed2022's non-major log-loss
# delta is +0.55 and fed2025's is -0.22. In 2022 the teals were new; by 2025
# they were incumbents. We handle non-major RETENTION and fail at non-major
# EMERGENCE.
#
# So this builds the case list to design against, and prints a handful in full
# rather than a summary -- per CLAUDE.md, a model gets designed WITH Pete on
# real rows before any rule is written, and a leaderboard is not an example.
#
# Emits EM* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

OUT <- "output"
SD <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)
cat(sprintf("EM1  %d (pair, seat, party) rows over %d pairs\n", nrow(SD), uniqueN(SD$pair)))

# Previous election in the same jurisdiction, so "what did this class poll here
# last time" is answerable. Seat names are normalised because the corpus is not
# internally consistent about them (vic2014 "albertpark" vs vic2022
# "Albert Park") -- an exact join matched ZERO Victorian seats once and read as
# a real finding.
SD[, region := sub("[0-9]{4}$", "", pair)]
SD[, yr := as.integer(sub("^[a-z]+", "", pair))]
SD[, sn := normalise_seat(seat)]

# "LAST TIME" COMES FROM THE CANDIDATE CORPUS, NOT FROM pooled-sharedetail.
# pooled-sharedetail only holds the 22 TARGET pairs, so any pair that is the
# earliest of its jurisdiction in that set has no predecessor there and every
# prev_share lands NA. That silently emptied the column for all 52 sa2026
# cases -- the single largest group -- and an emergence is defined by what came
# before, so those cases were being classified on a missing value.
# output/candidacies.csv carries 29 elections including sa2022, vic2010 and
# wa1996, which is exactly the set of predecessors needed.
CAND <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
CAND <- CAND[, .(share = sum(pcv, na.rm = TRUE)), by = .(election, seat, party)]
CAND[, sn := normalise_seat(seat)]
CAND[, region := sub("[0-9]{4}$", "", election)]
CAND[, yr := as.integer(sub("^[a-z]+", "", election))]

prev_of <- function(pr) {
  rg <- sub("[0-9]{4}$", "", pr); y <- as.integer(sub("^[a-z]+", "", pr))
  cand_yrs <- sort(unique(CAND[region == rg & yr < y]$yr), decreasing = TRUE)
  if (!length(cand_yrs)) return(NA_character_)
  paste0(rg, cand_yrs[1])
}
ord <- unique(SD[, .(pair)])
ord[, prev_pair := vapply(pair, prev_of, character(1))]
cat(sprintf("EM1  previous election resolved for %d of %d pairs%s\n",
            sum(!is.na(ord$prev_pair)), nrow(ord),
            if (any(is.na(ord$prev_pair))) sprintf(" (none for: %s)",
              paste(ord[is.na(prev_pair)]$pair, collapse = ", ")) else ""))
SD <- merge(SD, ord, by = "pair", all.x = TRUE)

prev <- CAND[, .(prev_pair = election, sn, party, prev_share = share)]
X <- merge(SD, prev, by = c("prev_pair", "sn", "party"), all.x = TRUE)

# WHO WON THE SEAT -- which is NOT who led on primaries, and getting that wrong
# would have inverted the whole design question. Curtin fed2022: LNP led the
# primaries 41.3 to the independent's 29.5, and the INDEPENDENT won the seat on
# preferences. Taking which.max(actual_share) labelled both Curtin and
# Goldstein "winner: LNP", which is exactly backwards for the cases this file
# exists to study.
#
# The backtest outputs carry the real winner in their `actual` column, so read
# it from the promoted arm rather than re-deriving it. Falls back to the
# primary leader only if those files are absent, and says so.
SHIPDIR <- file.path(OUT, "shipped")
wf <- list.files(SHIPDIR, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
wf <- grep("sharedetail|allprobs|totals|-seatsd|-diag", wf, value = TRUE, invert = TRUE)
win <- NULL
if (length(wf)) {
  win <- unique(rbindlist(lapply(wf, function(f) {
    d <- fread(f, showProgress = FALSE)
    if (!all(c("seat", "actual") %in% names(d))) return(NULL)
    if (!"pair" %in% names(d)) {
      m <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
      if (!length(m)) return(NULL)
      d[, pair := m]
    }
    d[, .(pair = as.character(pair), seat = as.character(seat), winner = as.character(actual))]
  }), fill = TRUE))
}
if (is.null(win) || !nrow(win)) {
  cat("EM1! no promoted backtest files -- falling back to the PRIMARY LEADER as 'winner', which is wrong for any seat decided on preferences\n")
  win <- X[, .SD[which.max(actual_share)], by = .(pair, seat)][, .(pair, seat, winner = party)]
}
X <- merge(X, win, by = c("pair", "seat"), all.x = TRUE)
cat(sprintf("EM1  winner known for %d of %d (pair, seat) combinations\n",
            uniqueN(X[!is.na(winner), .(pair, seat)]), uniqueN(X[, .(pair, seat)])))

NONMAJOR <- c("IND", "GRN", "ONP", "OTH_RIGHT", "OTH")
# AN EMERGENCE, defined so it can be checked rather than argued about: a
# non-major class that was small or absent here last time and is substantial
# now. The thresholds are a starting point for Pete to move, not a result --
# they are printed with the counts they produce so the effect of moving them
# is visible.
LOW <- as.numeric(Sys.getenv("AUSPOL_EMERGE_LOW", "10"))
HIGH <- as.numeric(Sys.getenv("AUSPOL_EMERGE_HIGH", "15"))
E <- X[party %in% NONMAJOR &
       actual_share >= HIGH &
       (is.na(prev_share) | prev_share < LOW)]
E[, jump := actual_share - fifelse(is.na(prev_share), 0, prev_share)]
E[, we_missed_by := actual_share - pred_share]
E[, won := party == winner]
setorder(E, -jump)

cat(sprintf("\nEM2  %d emergence cases (non-major, was <%.0f%% here last time, polled >=%.0f%% this time)\n",
            nrow(E), LOW, HIGH))
cat(sprintf("EM2  %d of them WON the seat\n", sum(E$won)))
cat("\nEM3  by class -- we_missed_by is actual minus our prediction, in points; POSITIVE means we under-predicted them\n")
print(E[, .(cases = .N, won = sum(won), mean_jump = round(mean(jump), 1),
            mean_missed = round(mean(we_missed_by), 1),
            median_missed = round(median(we_missed_by), 1)), by = party][order(-cases)])
cat("\nEM4  by election\n")
print(E[, .(cases = .N, won = sum(won), mean_missed = round(mean(we_missed_by), 1)), by = pair][order(-cases)])

fwrite(E[, .(pair, seat, party, prev_share, actual_share, pred_share, jump,
             we_missed_by, won, winner)],
       file.path(OUT, "emergence-cases.csv"))
cat(sprintf("\nEM5  wrote %s (%d rows)\n", file.path(OUT, "emergence-cases.csv"), nrow(E)))

# THREE WORKED EXAMPLES, printed in full. Not the three biggest -- one that we
# missed badly and that won, one we missed badly that did NOT win, and one we
# got roughly right -- because a rule fitted only on the spectacular cases will
# fire on the quiet ones too, and the false-positive side is where the last
# salience criterion went wrong.
cat("\n\nEM6  ===== THREE WORKED EXAMPLES =====\n")
show_seat <- function(pr, st) {
  R <- X[pair == pr & seat == st][order(-actual_share)]
  if (!nrow(R)) { cat(sprintf("  (no rows for %s / %s)\n", pr, st)); return(invisible()) }
  cat(sprintf("\n--- %s / %s   (winner: %s)\n", pr, st, R$winner[1]))
  print(R[, .(party,
              last_time = round(prev_share, 1),
              we_said = round(pred_share, 1),
              actual = round(actual_share, 1),
              error = round(pred_share - actual_share, 1))])
}
picks <- list(c("fed2022", "Curtin"), c("fed2022", "Goldstein"), c("sa2026", "Narungga"))
for (p in picks) show_seat(p[1], p[2])
