# Federal polls' state breakdowns for the recent-poll blend (AUSPOL_LEVEL_FED_R, shipped 0.15 2026-10-12;
# docs/plans/prereg-federal-breakdowns-in-blend-2026-10-12.md). Parses the archived Wikipedia federal
# opinion-polling pages (scripts/fetch_statewide_poll_samples.R) with fed_state_breakdowns_parse() and writes
# output/fed-state-breakdowns.csv, which the blend reads and the release carries. Rebuild stage 5b.
# Emits FK* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
src <- file.path("external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv")
out <- fed_state_breakdowns_parse(src)
cov <- out[, .(polls = .N, lnp = mean(is.finite(LNP)), grn = mean(is.finite(GRN)), from = min(end), to = max(end)), by = st][order(st)]
cat(sprintf("FK1  %d polls from %s (source modified %s)\n", nrow(out), src, format(file.info(src)$mtime, "%Y-%m-%d %H:%M")))
print(cov)
# Coverage, not presence: a column parsed to all-NA would pass a schema check and quietly drop that class.
mainland <- c("nsw", "vic", "qld", "wa", "sa")
if (!all(mainland %in% cov$st)) stop("FK2! a mainland state has no federal breakdowns: ", paste(setdiff(mainland, cov$st), collapse = ", "))
# Wikipedia DELETED the sub-national sections from the fed2028 page on 2026-10-24 (revision 1381724607, "excessive
# detail"), so a local refresh of fed2028_opinion parses to no breakdowns from May 2025 on. The 6 Oct set (471
# polls) is final; never overwrite it with fewer or older. Pre-deletion copy: raw/fed2028_opinion-oldid1381712590.html.
prev_f <- out_path("fed-state-breakdowns.csv")
if (file.exists(prev_f)) {
  prev <- fread(prev_f, select = "end")
  if (nrow(out) < nrow(prev) || max(out$end) < max(as.Date(prev$end)))
    stop(sprintf("FK2! would shrink %s: %d polls to %s now vs %d to %s on disk. The fed2028 page lost its state sections on 2026-10-24; restore raw/fed2028_opinion.html from raw/fed2028_opinion-oldid1381712590.html and re-run the fetcher. Delete the output file only if the shrink is intended.",
                 prev_f, nrow(out), format(max(out$end)), nrow(prev), format(max(as.Date(prev$end)))))
}
if (nrow(out) < 300) stop("FK2! only ", nrow(out), " polls parsed (439 on 2026-10-12): the source or the parser changed")
if (mean(is.finite(out$LNP)) < 0.9 || mean(is.finite(out$GRN)) < 0.8)
  stop(sprintf("FK2! coverage too low: LNP %.0f%%, GRN %.0f%% (2026-10-12: 100%% / ~97%%)", 100 * mean(is.finite(out$LNP)), 100 * mean(is.finite(out$GRN))))
age <- as.integer(Sys.Date() - max(out$end))
if (age > 45) cat(sprintf("FK3! newest federal breakdown is %d days old: refetch scripts/fetch_statewide_poll_samples.R\n", age))
fwrite(out, out_path("fed-state-breakdowns.csv"))
cat(sprintf("FK4  wrote %s\n", out_path("fed-state-breakdowns.csv")))
