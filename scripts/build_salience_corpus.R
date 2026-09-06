# Turn output/candidacies.csv into the corpus the salience gate needs.
#
# The gate scores the CHALLENGER / SITTING MEMBER search ratio, because Google
# Trends normalises 0-100 within a query: two candidates from two different
# queries are not comparable, and the paired ratio is the only quantity that
# carries across. So every candidacy needs the name of the person sitting in
# that seat going into the election.
#
# DERIVING `sitting`. The winners files give the winning PARTY per seat per
# election, not a name. The name is the candidate of that party in that seat --
# unique in almost every case, and where it is not, the row is dropped rather
# than guessed, because attaching the wrong incumbent silently inverts the ratio
# the whole signal is built on.
#
# COVERAGE IS REPORTED AT EVERY JOIN. The previous corpus was untracked and
# unreproducible; this one says how many rows survived each step so a partial
# join cannot pass as a complete one.
#
# Emits SC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
cat(sprintf("SC1  %d candidacies, %d elections\n", nrow(C), uniqueN(C$election)))

# Seat names come from six commissions with six spacing conventions, and the
# Victorian 2014/2018 rows are unspaced filenames. Join on a normalised key and
# keep the original for display.
norm <- function(x) gsub("[^a-z]", "", tolower(x))
C[, seat_key := norm(seat)]

# ---- winners: party per seat per election -----------------------------------
ED <- tryCatch(election_data_path(), error = function(e) "external/elections")
wf <- list.files(ED, pattern = "winners\\.csv$", full.names = TRUE)
W <- rbindlist(lapply(wf, function(f) {
  d <- fread(f, showProgress = FALSE)
  if (!"election" %in% names(d)) {
    # vec-2014-vic-winners.csv style: the election is in the filename only.
    y <- sub("^[a-z]+-([0-9]{4})-.*$", "\\1", basename(f))
    r <- sub("^[a-z]+-[0-9]{4}-([a-z]+)-.*$", "\\1", basename(f))
    d[, election := paste0(r, y)]
  }
  d[, .(election, seat, winner)]
}), fill = TRUE)
W[, seat_key := norm(seat)]
cat(sprintf("SC2  %d winner rows across %d elections\n", nrow(W), uniqueN(W$election)))

# ---- the winning CANDIDATE's name -------------------------------------------
m <- merge(C, W[, .(election, seat_key, win_party = winner)],
           by = c("election", "seat_key"), all.x = TRUE)
cat(sprintf("SC3  candidacies matched to a winning party: %d of %d (%.0f%%)\n",
            sum(!is.na(m$win_party)), nrow(m), 100 * mean(!is.na(m$win_party))))
# Report the RATE per election, not just which elections have any unmatched row.
# The first version of this line printed "elections with NO winner data:
# qld2020, qld2024, vic2022" when Queensland 2020 had in fact matched 93 of its
# 94 seats -- the single miss being "Aurukun Shire Division 1", a local
# government division that leaked into the ECQ XML and is not a state district.
# A message that says "no data" when it means "one row unmatched" sends the
# reader looking for a missing file.
um <- m[, .(rows = .N, unmatched = sum(is.na(win_party))), by = election][unmatched > 0]
if (nrow(um)) {
  cat("SC3  elections with unmatched seats:\n")
  for (i in seq_len(nrow(um)))
    cat(sprintf("       %-9s %d of %d unmatched%s\n", um$election[i],
                um$unmatched[i], um$rows[i],
                if (um$unmatched[i] == um$rows[i]) "  <- NO winners file at all" else ""))
}

cands_of_winner <- m[!is.na(win_party) & party == win_party,
                     .(n = .N, name = name[1]), by = .(election, seat_key)]
amb <- cands_of_winner[n > 1]
cat(sprintf("SC4  seats where the winning party ran >1 candidate (dropped): %d\n", nrow(amb)))
winner_name <- cands_of_winner[n == 1, .(election, seat_key, winner_name = name)]
cat(sprintf("SC4  seat-elections with an identified winning candidate: %d\n",
            nrow(winner_name)))

# ---- sitting member = the previous election's winner in that seat -----------
ord <- unique(C[, .(region, year, election)])[order(region, year)]
ord[, prev := shift(election), by = region]
sit <- merge(winner_name, ord[, .(election, prev, region)], by = "election")
setnames(sit, "winner_name", "won_here")
prev_win <- merge(ord[, .(election, prev)],
                  winner_name[, .(prev = election, seat_key,
                                  sitting = winner_name)],
                  by = "prev", allow.cartesian = TRUE)

S <- merge(m, prev_win[, .(election, seat_key, sitting)],
           by = c("election", "seat_key"), all.x = TRUE)
cat(sprintf("SC5  candidacies with a known sitting member: %d of %d (%.0f%%)\n",
            sum(!is.na(S$sitting)), nrow(S), 100 * mean(!is.na(S$sitting))))

# The gate EXCLUDES candidacies where the independent IS the sitting member:
# that is incumbency, not emergence, and the ratio would be 1.0 by construction.
S[, is_sitting := !is.na(sitting) & name == sitting]
G <- S[!is.na(sitting) & !is_sitting & !party %in% c("ALP", "LNP", "NAT")]
cat(sprintf("SC6  gate-eligible non-major candidacies: %d (%d breakouts)\n",
            nrow(G), sum(G$breakout)))
print(G[, .(candidacies = .N, breakouts = sum(breakout)),
        by = .(region)][order(-breakouts)], row.names = FALSE)

fwrite(G[, .(election, region, year, seat, name, party, pcv, breakout, sitting)],
       "output/salience-corpus.csv")
cat(sprintf("\nSC9  wrote output/salience-corpus.csv: %d rows, %d breakouts\n",
            nrow(G), sum(G$breakout)))
cat(sprintf("SC9  the corpus the AUC of 0.87 was measured on had 21 breakouts,\n"))
cat(sprintf("SC9  all federal. This one spans %d elections in %d regions.\n",
            uniqueN(G$election), uniqueN(G$region)))
