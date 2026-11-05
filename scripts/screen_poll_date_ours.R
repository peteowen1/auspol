# Screen for AUSPOL_POLL_DATE_OURS (2026-11-05): a poll matched between AE's file and ours takes our fieldwork-midpoint
# date instead of AE's. Refits the published trend (trend_as_at(), defaults) the day before every scored election,
# polls loaded with the switch off and on, and scores the day-before first preferences against the result: mean
# absolute error over ALP, LNP, GRN, ONP and the remainder (the poll-lean screens' metric). Writes nothing to output/.
#   powershell.exe -Command 'Rscript "scripts/screen_poll_date_ours.R"'
# Check codes: PDO0 what the arm applied, PDO1 per election, PDO2 pooled.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
source("scripts/published_flags.R"); apply_published_flags()
# shipped "1" 2026-11-05; the loop below sets "0" (AE dates, the old behaviour) and "1" explicitly for each region
REGIONS <- c("fed", "nsw", "vic", "qld", "wa", "sa"); LIVE <- c("vic2026", "nsw2027"); MAIN <- c("ALP", "LNP", "GRN", "ONP")
cand <- fread("output/candidacies.csv", select = c("election", "region", "year", "party", "votes"))
cand[, votes := as.numeric(votes)]
tot <- cand[, .(tot = sum(votes, na.rm = TRUE)), by = .(election)]
act <- merge(cand[, .(v = sum(votes, na.rm = TRUE)), by = .(election, region, year, party)], tot, by = "election")
act[, share := 100 * v / tot]
cycles <- as.data.table(load_election_cycles()); pri <- as.data.table(load_prior_results()); pf <- load_preference_flows()
score_fit <- function(fit, a_row) {
  ends <- fit$fp; ps <- intersect(MAIN, names(ends))
  got <- setNames(a_row$share, a_row$party); a <- vapply(ps, function(p) if (p %in% names(got)) got[[p]] else 0, 1)
  e <- unname(ends[ps]) - unname(a)
  mean(abs(c(e, (100 - sum(ends[ps])) - (100 - sum(a)))))
}
rows <- list()
for (rg in REGIONS) {
  Sys.setenv(AUSPOL_POLL_DATE_OURS = "0"); p0 <- suppressMessages(load_polls(rg))
  Sys.setenv(AUSPOL_POLL_DATE_OURS = "1"); p1 <- load_polls(rg)
  Sys.setenv(AUSPOL_POLL_DATE_OURS = "0")
  cat(sprintf("PDO0 %s: %d polls; dates differing between off and on: %d\n", rg, nrow(p0), sum(sort(p0$date) != sort(p1$date))))
  for (el in unique(act[act$region == rg]$election)) {
    if (el %in% LIVE) next
    yr <- act[act$election == el]$year[1]; want_rg <- rg; want_yr <- yr
    ce <- cycles[which(cycles$region == want_rg & cycles$year == want_yr)]
    if (!nrow(ce)) next
    m <- which(pri$region == want_rg & pri$year == want_yr); priors <- setNames(pri$prev1[m], pri$party[m])
    flw <- tryCatch(flows_for(pf, yr, rg, as_of = ce$start[1], cycles = cycles, quiet = TRUE), error = function(e) NULL)
    asat <- ce$end[1] - 1
    b <- tryCatch(trend_as_at(p0, yr, cycles, asat, priors, flw), error = function(e) NULL)
    a <- tryCatch(trend_as_at(p1, yr, cycles, asat, priors, flw), error = function(e) NULL)
    if (is.null(b) || is.null(a)) next
    c0 <- cycle_polls(p0, yr, cycles); c1 <- cycle_polls(p1, yr, cycles)
    late0 <- sum(c0$date > asat - 60 & c0$date <= asat); late1 <- sum(c1$date > asat - 60 & c1$date <= asat)
    ar <- act[act$election == el]
    rows[[el]] <- data.table(election = el, polls_last60_off = late0, polls_last60_on = late1,
                             mae_off = score_fit(b, ar), mae_on = score_fit(a, ar))
  }
}
R <- rbindlist(rows); R[, d := mae_on - mae_off]
cat("\nPDO1 day-before first-preference error, mean absolute points (lower is better); d = on - off (negative = better)\n")
print(R[abs(d) > 1e-9][order(d)], digits = 3)
mv <- R[abs(d) > 1e-9]
cat(sprintf("\nPDO2 %d of %d elections move; on those: mean d %+.4f, SE %.4f (clustered on election), better %d, worse %d\n",
            nrow(mv), nrow(R), mean(mv$d), sd(mv$d) / sqrt(nrow(mv)), sum(mv$d < 0), sum(mv$d > 0)))
cat(sprintf("PDO2 all %d elections: mean MAE %.4f -> %.4f\n", nrow(R), mean(R$mae_off), mean(R$mae_on)))
