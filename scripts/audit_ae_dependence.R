# How much of the poll data still comes from AE Forecasts' file? (Pete, 2026-10-13: "the end game is to move off
# AE data".) Under the shipped layered source (R/poll_source.R), counts every poll in each election cycle by where
# its numbers came from, for the whole cycle and the final 30 days, and names the cause of each AE dependence:
#   no_wiki    AE-only poll in a cycle Wikipedia has no polls for at all (cause 1: a source for that era)
#   missing    AE-only poll in a cycle Wikipedia covers, but not this poll (cause 5: coverage gap)
#   dispute    both have it, they disagree, and AE's row fits the two-party figure better (cause 2: parser)
#   suspect    both have it, ours failed its own two-party check (cause 2: parser)
#   ae_filled  ours, but a party our page folds into Others came from AE (cause 3: original release needed)
#   label      firm label taken from AE (methodology eras set house effects; cause 4: our own era rules)
# Writes output/ae-dependence-audit.csv. Run: powershell.exe -Command 'Rscript scripts/audit_ae_dependence.R'
# Emits AD* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
Sys.setenv(AUSPOL_POLL_SOURCE = "layered")
cyc <- load_election_cycles(); eds <- election_dates()
targets <- c(vapply(all_election_pairs(), `[[`, "", "election"), "vic2026", "nsw2027")
rows <- list(); fills <- list()
for (rg in c("fed", "nsw", "qld", "sa", "vic", "wa")) {
  P <- attr(suppressMessages(load_polls(rg)), "provenance")
  if (is.null(P)) stop("AD0! no provenance for ", rg, ": is AUSPOL_POLL_SOURCE layered?")
  for (e in targets[startsWith(targets, rg)]) {
    yr <- as.integer(sub("^[a-z]+", "", e)); cy <- cyc[cyc$region == rg & cyc$year == yr]
    if (!nrow(cy)) next
    ed <- as.Date(unname(eds[e])); end <- if (is.finite(ed) && ed <= Sys.Date()) ed else Sys.Date()
    inc <- P$date > cy$start[1] & P$date < end
    x <- P[inc]
    covered <- sum(x$source %in% c("ours", "ours_only", "ours_only_oth_blank", "ae_dispute", "ae_suspect")) >= 5   # fed2007 has one stray Newspoll: not coverage
    tally <- function(z) data.table(polls = nrow(z),
      ours = sum(z$source %in% c("ours", "ours_only", "ours_only_oth_blank") & !nzchar(z$ae_filled)),
      ae_filled = sum(nzchar(z$ae_filled)), dispute = sum(z$source == "ae_dispute"), suspect = sum(z$source == "ae_suspect"),
      no_wiki = if (covered) 0L else sum(z$source == "ae_only"), missing = if (covered) sum(z$source == "ae_only") else 0L,
      label_ae = sum(z$label_from_ae))
    a <- tally(x); f <- tally(x[x$date >= end - 30])
    rows[[length(rows) + 1L]] <- cbind(data.table(election = e), a, setnames(f, paste0("f30_", names(f))))
    if (any(nzchar(x$ae_filled))) fills[[length(fills) + 1L]] <- data.table(election = e, party = unlist(strsplit(x$ae_filled[nzchar(x$ae_filled)], " ")))
  }
}
R <- rbindlist(rows)
R[, ae_share := round(100 * (polls - ours) / pmax(polls, 1))]
R[, f30_ae_share := round(100 * (f30_polls - f30_ours) / pmax(f30_polls, 1))]
setorder(R, -f30_ae_share, -ae_share)
cat(sprintf("AD1 %d elections, %d polls in their cycles; numbers entirely ours: %d (%.0f%%); final 30 days: %d of %d (%.0f%%)\n",
            nrow(R), sum(R$polls), sum(R$ours), 100 * sum(R$ours) / sum(R$polls), sum(R$f30_ours), sum(R$f30_polls), 100 * sum(R$f30_ours) / sum(R$f30_polls)))
cat("AD2 AE dependence by cause (whole cycles | final 30 days):\n")
for (cc in c("no_wiki", "missing", "dispute", "suspect", "ae_filled", "label_ae"))
  cat(sprintf("     %-9s %5d | %4d\n", cc, sum(R[[cc]]), sum(R[[paste0("f30_", cc)]])))
if (length(fills)) { Fl <- rbindlist(fills)[nzchar(party)]; cat("AD3 parties AE had to fill (polls):", paste(Fl[, .N, by = party][order(-N), sprintf("%s %d", party, N)], collapse = ", "), "\n") }
print(R[, .(election, polls, ours, no_wiki, missing, dispute, suspect, ae_filled, ae_share, f30_polls, f30_ours, f30_ae_share)], nrows = 40)
fwrite(R, out_path("ae-dependence-audit.csv"))
cat(sprintf("AD4 wrote %s\n", out_path("ae-dependence-audit.csv")))
