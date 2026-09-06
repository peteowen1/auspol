# The per-cycle volatility threshold, against
# docs/plans/prereg-nsw-onp-walk-threshold.md
#
# `walk_of()` decides which parties estimate their OWN per-cycle volatility
# rather than inheriting a pooled/default random walk. NSW gates it on an
# intersect of two counts; Victoria gates it on one and defaults the other.
# One Nation in NSW 2027 fails BOTH, which is why lowering either alone would
# change nothing -- see the plan's diagnosis section.
#
# The grid, criterion, decision rule and four refusal conditions are in the
# plan and are NOT restated here, so they cannot drift toward whatever comes
# out.
#
# STEP 1 IS A GATE. The plan requires the affected-row count to be reported
# and the run ABORTED under 10 rows, before any MAE is read. That ordering is
# enforced below rather than left to whoever reads the output.
#
# Emits WT* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

THRESHOLDS <- c(8L, 10L, 12L, 15L, 20L)
STATUS_QUO <- 15L
MIN_AFFECTED <- 10L          # plan's abort gate
REGIONS <- c("fed", "nsw", "vic", "qld", "sa", "wa")
MIN_YEAR <- 1990

cycles <- load_election_cycles()
ev <- load_eventual_results()
pol <- load_polled_elections()
pri_all <- load_prior_results()

cat("\n=== per-cycle volatility threshold ===\n")
cat("grid:", paste(THRESHOLDS, collapse = ", "),
    "| status quo:", STATUS_QUO, "| abort under", MIN_AFFECTED, "affected rows\n\n")

# ---- STEP 1: the affected-row count, BEFORE any MAE ------------------------
# A row is AFFECTED if the party would estimate its own per-cycle sigmas at
# some threshold in the grid but not at another -- i.e. its cycle poll count
# falls between the smallest and largest threshold. Only scorable rows count:
# a row the eventual results cannot break out separately cannot move the
# criterion, so counting it would overstate this experiment's power.
rows <- list()
for (rg in REGIONS) {
  f <- anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE)
  if (!file.exists(f)) next
  polls <- suppressMessages(load_polls(rg))
  ps_all <- attr(polls, "parties")
  for (y in sort(pol$year[which(pol$region == rg & pol$year >= MIN_YEAR)])) {
    if (!any(cycles$region == rg & cycles$year == y)) next
    ka <- ev$region == rg & ev$year == y & ev$party != "@TPP"
    act <- ev[which(ka), ]
    if (!nrow(act) || abs(sum(act$actual) - 100) > 5) next
    cp <- cycle_polls(polls, y, cycles)
    cnt <- vapply(ps_all, function(q) sum(!is.na(cp[[q]])), 1L)
    for (p in names(cnt)) {
      if (cnt[[p]] == 0L) next
      rows[[length(rows) + 1L]] <- data.table(
        region = rg, year = y, party = p, n_polls = cnt[[p]],
        scorable = any(act$party == p))
    }
  }
}
allrows <- rbindlist(rows)
stopifnot(nrow(allrows) > 0)

lo <- min(THRESHOLDS); hi <- max(THRESHOLDS)
affected <- allrows[n_polls >= lo & n_polls < hi]
aff_scor <- affected[scorable == TRUE]

cat(sprintf("WT1  %d (cycle, party) rows in the scorable corpus\n", nrow(allrows)))
cat(sprintf("WT1  %d rows have a poll count in [%d, %d) -- their treatment CHANGES across the grid\n",
            nrow(affected), lo, hi))
cat(sprintf("WT1  of those, %d are SCORABLE (the eventual result breaks the party out)\n",
            nrow(aff_scor)))
cat("\nWT1  affected rows by threshold band:\n")
print(affected[, .(n = .N, scorable = sum(scorable)),
               by = .(band = cut(n_polls, breaks = c(THRESHOLDS, Inf),
                                 right = FALSE))][order(band)])
cat("\nWT1  the scorable affected rows themselves:\n")
print(aff_scor[order(region, year, party)])

# THE GATE, AND ITS UNIT WAS WRONG AS PRE-REGISTERED.
#
# The plan fixed "abort under 10 affected ROWS" and, separately, "standard
# error clustered on the CYCLE, because first preferences sum to 100 within a
# cycle". Those two clauses are inconsistent: a row gate cannot protect a
# cluster-clustered SE. 15 rows passes the gate as literally written; those 15
# rows sit in 6 cycles, so the criterion's SE has 6 independent observations
# and about 5 degrees of freedom, where a 2 SE bar is not a 95% test at all
# (t(5) needs 2.57).
#
# This is EXACTLY the failure CLAUDE.md records twice -- a tolerance written
# without computing its size in SE -- committed in a plan written the same day
# that rule was re-read. Named here rather than quietly fixed.
#
# The amendment is visible and the original clause is left unedited above.
# Checked, per CLAUDE.md, whether it favours the answer found later: it does
# NOT. Aborting leaves NSW's build red and the problem unsolved, which is the
# inconvenient outcome, not the convenient one.
n_clusters <- uniqueN(aff_scor[, paste(region, year)])
cat(sprintf("\nWT2  affected rows sit in %d distinct cycles -- the SE's real n.\n",
            n_clusters))
print(aff_scor[, .(rows = .N, parties = paste(sort(party), collapse = ", ")),
               by = .(cycle = paste(region, year))][order(cycle)])
cat(sprintf("\nWT2  and only %d of the %d rows are the case this experiment is ABOUT\n",
            nrow(aff_scor[party == "ONP"]), nrow(aff_scor)))
cat("     (a thinly-polled MINOR party moving fast). In the other cycles every\n")
cat("     party shares one poll count, so the whole cycle is thinly polled and\n")
cat("     the change is not party-specific at all.\n")

if (n_clusters < MIN_AFFECTED) {
  cat(sprintf(paste0(
    "\nWT2  ABORT on the corrected unit: %d independent cycles against a floor\n",
    "     of %d. The row gate passed (%d >= %d) and was measuring the wrong\n",
    "     thing.\n"), n_clusters, MIN_AFFECTED, nrow(aff_scor), MIN_AFFECTED))
  fwrite(allrows, file.path("output", "walk-threshold-rows.csv"))
  cat("\nWrote output/walk-threshold-rows.csv (the counts, no scores)\n")
  quit(save = "no", status = 0)
}

if (nrow(aff_scor) < MIN_AFFECTED) {
  cat(sprintf(paste0(
    "\nWT2  ABORT: %d scorable affected rows against a pre-registered floor of %d.\n",
    "     The plan requires this run to stop here rather than report a number\n",
    "     it has no power to support. This is NOT a refusal of the change --\n",
    "     it is 'this cannot be decided on the available record'. Any fix to\n",
    "     the NSW walk gate must be argued on mechanism and correctness, not\n",
    "     on a held-out score this corpus cannot produce.\n"),
    nrow(aff_scor), MIN_AFFECTED))
  fwrite(allrows, file.path("output", "walk-threshold-rows.csv"))
  cat("\nWrote output/walk-threshold-rows.csv (the counts, no scores)\n")
  quit(save = "no", status = 0)
}

cat(sprintf("\nWT2  gate PASSED: %d scorable affected rows >= %d. Proceeding to score.\n",
            nrow(aff_scor), MIN_AFFECTED))
fwrite(allrows, file.path("output", "walk-threshold-rows.csv"))
cat("\nWrote output/walk-threshold-rows.csv\n")
cat("\nWT3  scoring arms is NOT yet implemented -- the gate above decides\n")
cat("     whether it is worth writing. See the plan.\n")
