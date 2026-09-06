# Derive the Victorian 2022 declared winners by REPLAYING the VEC's own count.
#
# WHY. vic2022 is the only election in the corpus with no winners file, so its
# 731 candidacies carry elected = NA and the Victorian harness falls back to the
# 2026 seat file -- who holds each seat NOW. CLAUDE.md records exactly that trap:
# the current holder is not who won last time (by-elections change hands), and
# the seat file's party labels are not classify_party()'s. Victoria is the live
# target, so this is the worst place in the corpus to be using a proxy.
#
# HOW. vec-2022-vic-transfers.csv is the count itself: every exclusion round,
# the class excluded, and where its votes went. Starting from first preferences
# and applying each round in order leaves the surviving classes, and the one
# with the most votes is the winner. No proxy, no seat file, no by-elections.
#
# Emits DW* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P  <- election_data_path()
FP <- fread(file.path(P, "vec-2022-vic-firstprefs.csv"), showProgress = FALSE)
TX <- fread(file.path(P, "vec-2022-vic-transfers.csv"),  showProgress = FALSE)
cat(sprintf("DW1  %d first-preference rows in %d seats | %d transfer rows, %d rounds max\n",
            nrow(FP), uniqueN(FP$seat), nrow(TX), max(TX$round)))

winner_of <- function(sn) {
  v <- FP[seat == sn, .(votes = sum(votes)), by = party]
  tot <- stats::setNames(as.numeric(v$votes), v$party)
  tr <- TX[seat == sn][order(round)]
  for (rd in sort(unique(tr$round))) {
    r <- tr[round == rd]
    from <- unique(r$from)
    if (length(from) != 1L) return(list(w = NA_character_, why = "round has multiple sources"))
    if (!from %in% names(tot)) return(list(w = NA_character_, why = paste("excluded class absent:", from)))
    # SUBTRACT the moved votes; do NOT delete the class. Transfers are recorded
    # per CLASS, and a seat with three independents excludes IND in three
    # separate rounds. Deleting on the first exclusion made round two fail, and
    # 49 of 87 seats went unresolved -- caught by the anchor checks below, since
    # the Greens came out with 1 seat instead of 4.
    moved <- sum(r$votes)
    for (i in seq_len(nrow(r))) {
      d <- r$to[i]
      tot[[d]] <- (if (d %in% names(tot)) tot[[d]] else 0) + r$votes[i]
    }
    tot[[from]] <- tot[[from]] - moved
    # Gone only once the pile is spent. A small tolerance because the VEC's
    # published transfers are rounded per destination.
    if (tot[[from]] <= 1) tot <- tot[names(tot) != from]
  }
  if (!length(tot)) return(list(w = NA_character_, why = "everyone excluded"))
  list(w = names(tot)[which.max(tot)], why = sprintf("%d survivors", length(tot)))
}

seats <- sort(unique(FP$seat))
res <- rbindlist(lapply(seats, function(s) {
  o <- winner_of(s); data.table(seat = s, winner = o$w, note = o$why)
}))
cat(sprintf("DW2  %d seats resolved | %d unresolved\n",
            sum(!is.na(res$winner)), sum(is.na(res$winner))))
if (any(is.na(res$winner))) print(res[is.na(winner)], row.names = FALSE)

cat("\nDW3  seats won, by class\n")
print(res[!is.na(winner), .N, by = winner][order(-N)], row.names = FALSE)

# ANCHOR CHECKS -- facts about the 2022 Victorian election known independently.
ck <- function(lab, ok) cat(sprintf("   %-58s %s\n", lab, if (isTRUE(ok)) "PASS" else "*** FAIL ***"))
cat("\nDW4  anchor checks\n")
w <- res[!is.na(winner)]
ck("88 districts, less Narracan (deferred) = 87 or 88", nrow(res) %in% c(87L, 88L))
ck("Labor wins a majority (>=45)", w[winner == "ALP", .N] >= 45)
ck("the Greens win 4", w[winner == "GRN", .N] == 4)
ck("Greens hold Melbourne", w[seat == "Melbourne", winner] == "GRN")
ck("Greens hold Brunswick", w[seat == "Brunswick", winner] == "GRN")
ck("Greens hold Richmond", w[seat == "Richmond", winner] == "GRN")
ck("Greens hold Prahran", w[seat == "Prahran", winner] == "GRN")
ck("Coalition is second", w[winner == "LNP", .N] > w[winner == "GRN", .N])

if (all(!is.na(res$winner))) {
  fwrite(res[, .(seat, winner)], file.path(P, "vec-2022-vic-winners.csv"))
  cat(sprintf("\nDW9  wrote %s\n", file.path(P, "vec-2022-vic-winners.csv")))
} else {
  cat("\nDW9! NOT written -- unresolved seats above must be explained first\n")
}
