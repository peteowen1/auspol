# Federal polls' state breakdowns for the recent-poll blend (AUSPOL_LEVEL_FED_R, shipped 0.15 2026-10-12;
# docs/plans/prereg-federal-breakdowns-in-blend-2026-10-12.md). Parses the archived Wikipedia federal
# opinion-polling pages (scripts/fetch_statewide_poll_samples.R) with fed_state_breakdowns_parse() and writes
# output/fed-state-breakdowns.csv, which the blend reads and the release carries. Rebuild stage 5b.
# --with-bt (OFF by default) adds BludgerTrack's federal state breakdowns that Wikipedia lacks
# (fed_state_breakdowns_bt(), fed_state_breakdowns_merge(); Wikipedia's row wins where both have the poll; column
# `src` says which). Wikipedia deleted its state sections on 2026-10-24; BludgerTrack still publishes them. NOT
# shipped (5 Nov 2026): +228 polls made qld2024, sa2026 and wa2025 each slightly worse (polling-day level RMSE
# 1.224 -> 1.231, 9 cells) and moved live Victoria 0.04 points (DECISIONS 2026-11-05).
#   Rscript scripts/build_fed_state_breakdowns.R [--with-bt] [--out=<path>]
# --out writes elsewhere (screens) and skips the shrink guard.
# Emits FK* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
args <- commandArgs(TRUE)
with_bt <- "--with-bt" %in% args
out_arg <- sub("^--out=", "", grep("^--out=", args, value = TRUE))
dest <- if (length(out_arg)) out_arg else out_path("fed-state-breakdowns.csv")
# The BludgerTrack merge is not shipped: it may only be written somewhere other than the blend's file (review nit, 5 Nov).
if (with_bt && !length(out_arg)) stop("FK2! --with-bt needs --out=<path>: the BludgerTrack merge is not shipped (DECISIONS 2026-11-05), so it must not overwrite ", out_path("fed-state-breakdowns.csv"))
src <- file.path("external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv")
out <- fed_state_breakdowns_parse(src)
if (with_bt) {
  P <- file.path("external", "reference", "polls")
  bt <- fed_state_breakdowns_bt(file.path(P, "pollbludger", "bludgertrack_polls.csv"),
                                raw_dir = file.path(P, "pollbludger", "raw", "bludgertrack"))
  alias <- fread(file.path(P, "statewide-samples", "firm_alias.csv"), showProgress = FALSE)
  n_wiki <- nrow(out)
  out <- fed_state_breakdowns_merge(out, bt, alias)
  cat(sprintf("FK0  BludgerTrack: %d state rows, %d already in Wikipedia, %d added (%d -> %d polls); newest BT end %s\n",
              nrow(bt), attr(out, "n_bt_matched"), attr(out, "n_bt_added"), n_wiki, nrow(out), format(max(bt$end))))
  print(out[src == "bt", .(added = .N, from = min(end), to = max(end)), by = st][order(st)])
}
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
if (!length(out_arg) && file.exists(prev_f)) {
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
fwrite(out, dest)
cat(sprintf("FK4  wrote %s\n", dest))
