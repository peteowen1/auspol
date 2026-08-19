# Seat-by-seat against YouGov's MRP, on their own terms: winner and runner-up.
#
# YouGov publish a POINT projection per seat (winner, runner-up, two-party
# margin between those two). We publish a probability per party. Those are not
# the same object, so the comparison is stated two ways and neither is called
# "accuracy" -- no forecast here has been scored against a result.
#
# Their table is extracted from the published PDF into external/reference/,
# which is gitignored: the same treatment the VEC and anchor data get. Their
# numbers are NOT committed. Only this comparison's output is.
#
# Emits YG* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

YG_F <- "external/reference/yougov-seats.csv"
if (!file.exists(YG_F)) {
  stop("Missing ", YG_F, ". Rebuild it with:\n",
       "  curl -sL -o external/reference/yougov-vic-mrp-2026.pdf \\n",
       "    https://actionnetwork.org/user_files/user_files/000/146/615/original/",
       "yougov-vic-mrp-treaty-report-state-voting-intetion-treaty-support.pdf\n",
       "  pdftotext -layout external/reference/yougov-vic-mrp-2026.pdf ",
       "external/reference/yougov.txt\n",
       "then re-run the parser in scripts/parse_yougov.py.")
}
yg <- fread(YG_F)

# Their parties, mapped onto ours. Liberal and National are both LNP to us.
yg[, yg_win := fifelse(winner %in% c("Liberal", "National", "Coalition"), "LNP",
              fifelse(winner == "Labor", "ALP",
              fifelse(winner == "One Nation", "ONP",
              fifelse(winner == "Greens", "GRN", "IND"))))]

# ANCHOR CHECK, against figures YouGov published in prose. If the extraction is
# wrong these will not match, and every number below would be built on it.
tot <- yg[, .N, by = yg_win]
cat("\nYG0  extraction anchor check\n")
for (k in list(c("LNP", "39"), c("ALP", "29"), c("ONP", "17"), c("GRN", "3"))) {
  got <- tot[yg_win == k[1], N]; got <- if (length(got)) got else 0L
  cat(sprintf("     %-4s parsed %2d, YouGov states %2s  %s\n", k[1], got, k[2],
              if (as.character(got) == k[2]) "OK" else "MISMATCH"))
  if (as.character(got) != k[2]) {
    stop("The YouGov extraction disagrees with their own published totals for ",
         k[1], ". Fix the parse before reading anything below it.")
  }
}
stopifnot(nrow(yg) == 88L, uniqueN(yg$seat) == 88L)

wp <- fread("output/seat-probs-vic-2026.csv")
# Narracan is absent from our candidate model; we assign it to the Coalition.
wp <- rbind(wp, data.table(seat = "Narracan", party = "LNP", prob = 1))
ours <- wp[, .SD[which.max(prob)], by = seat][, .(seat, our_win = party, our_p = prob)]
# Our probability for whoever THEY pick, which is the fairer question.
m <- merge(ours, yg[, .(seat, yg_win, yg_tpp = tpp, status)], by = "seat")
m <- merge(m, wp[, .(seat, party, p_for_their_pick = prob)],
           by.x = c("seat", "yg_win"), by.y = c("seat", "party"), all.x = TRUE)
m[is.na(p_for_their_pick), p_for_their_pick := 0]
stopifnot(nrow(m) == 88L)

agree <- m[our_win == yg_win]
cat(sprintf("\nYG1  same winner in %d of 88 seats (%.0f%%)\n",
            nrow(agree), 100 * nrow(agree) / 88))
cat("\nYG2  where the two models disagree, by the pairing\n")
print(m[our_win != yg_win, .N, by = .(ours = our_win, yougov = yg_win)][order(-N)])

cat(sprintf("\nYG3  our mean probability for THEIR winner: %.3f (agreeing seats %.3f, disagreeing %.3f)\n",
            mean(m$p_for_their_pick), mean(agree$p_for_their_pick),
            mean(m[our_win != yg_win, p_for_their_pick])))

cat("\nYG4  the 17 seats YouGov gives One Nation -- what we say about each\n")
on <- m[yg_win == "ONP"][order(-p_for_their_pick)]
print(on[, .(seat, our_win, our_p = round(our_p, 3),
             our_p_ONP = round(p_for_their_pick, 3), yg_tpp)])
cat(sprintf("YG4  we give One Nation the win in %d of those 17; mean ONP probability %.3f\n",
            nrow(on[our_win == "ONP"]), mean(on$p_for_their_pick)))
cat(sprintf("YG4  our expected seats across those 17 = %.2f\n", sum(on$p_for_their_pick)))

cat("\nYG5  seats WE give One Nation that YouGov does not\n")
print(m[our_win == "ONP" & yg_win != "ONP", .(seat, our_p = round(our_p, 3), yg_win)])

cat("\nYG6  their closest calls (2pp under 52) and our probability for their pick\n")
print(m[yg_tpp < 52][order(yg_tpp)][, .(seat, yg_win, yg_tpp, our_win,
                                        our_p_their_pick = round(p_for_their_pick, 3))])

fwrite(m[order(seat)], file.path("output", "yougov-comparison.csv"))
cat("\nWrote output/yougov-comparison.csv\n")
