#!/usr/bin/env Rscript
# Build docs/POLL-REGISTRY.md and output/poll-registry.csv: for every scored election (and the live cycles), how
# many statewide voting-intention polls the trend reads, and WHOSE NUMBERS each one carries.
#
# Pete, 2026-10-13: "do we have a poll registry? we should if we dont - that tracks all these things". Generated
# from what load_polls() actually returns under the published settings (its provenance attribute, R/poll_source.R),
# never hand-edited: rerun after any change to the poll sources, like DATA-REGISTRY.md.
#
# Columns (whole cycle = polls dated after the previous election, up to polling day; f30 = final 30 days):
#   polls          rows with primaries for Labor and the Coalition (two-party-only rows are listed separately)
#   wiki / bt / both   numbers from Wikipedia / BludgerTrack / both (BludgerTrack's row kept)
#   ae             numbers from AE: no Wikipedia or BludgerTrack copy found (ae_only), AE won a dispute, or our
#                  copy failed its own two-party check
#   ae_party       ours, but one party (UAP, NXT, One Nation ...) filled from AE because our page folds it in Others
#   label_ae       firm label (methodology era) taken from AE, which sets the house effect
#   pb_post        of the f30 polls, how many a Poll Bludger post confirms (scripts/extract_pollbludger.R, rules;
#                  matched within 2 points). Read from output/pollbludger-vs-layered.csv; its date is printed.
# Check codes: RY1 per region, RY2 written, RY3! stale input.

suppressPackageStartupMessages(library(data.table))
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))

eds <- election_dates()
pairs <- rbindlist(lapply(all_election_pairs(), as.data.table))[, .(election, prev)]
pairs <- rbind(pairs, data.table(election = c("vic2026", "nsw2027"), prev = c("vic2022", "nsw2023")))
pairs[, `:=`(region = sub("[0-9]+$", "", election), start = as.Date(eds[prev]), end = pmin(as.Date(eds[election]), Sys.Date()),
             live = as.Date(eds[election]) > Sys.Date())]

pbf <- "output/pollbludger-vs-layered.csv"
PB <- if (file.exists(pbf)) fread(pbf) else NULL
if (!is.null(PB)) {
  PB[, ok := pmax(abs(ALP_pb - ALP_l), abs(LNP_pb - LNP_l), na.rm = TRUE) <= 2]
  PB <- PB[ok == TRUE]
}

rows <- list(); firms <- list()
for (rg in unique(pairs$region)) {
  L <- suppressMessages(load_polls(rg)); P <- attr(L, "provenance")
  d <- data.table(date = L$date, firm = L$firm, has_fp = is.finite(L$ALP) & is.finite(L$LNP), source = P$source,
                  origin = P$origin, ae_filled = nzchar(P$ae_filled), label_ae = P$label_from_ae)
  cat(sprintf("RY1 %s: %d rows from load_polls()\n", rg, nrow(d)))
  for (i in which(pairs$region == rg)) {
    e <- pairs$election[i]
    z <- d[date > pairs$start[i] & date <= pairs$end[i]]
    f <- z[date > pairs$end[i] - 30]
    cnt <- function(x) list(polls = sum(x$has_fp), tpp_only = sum(!x$has_fp),
                            wiki = sum(x$has_fp & x$origin %in% c("wiki", "wiki+bludgertrack") & !x$ae_filled),
                            bt = sum(x$has_fp & x$origin == "bludgertrack" & !x$ae_filled),
                            both = sum(x$has_fp & x$origin == "bludgertrack+wiki" & !x$ae_filled),
                            ae = sum(x$has_fp & x$origin == "ae"), ae_party = sum(x$has_fp & x$origin != "ae" & x$ae_filled),
                            label_ae = sum(x$has_fp & x$label_ae))
    a <- cnt(z); b <- cnt(f); names(b) <- paste0("f30_", names(b))
    pb_hit <- function(x) if (is.null(PB) || !nrow(x)) logical(nrow(x)) else
      vapply(seq_len(nrow(x)), function(k) any(PB$region == rg & PB$poll_date == x$date[k] & PB$firm == x$firm[k]), TRUE)
    fp <- f[has_fp == TRUE]; zp <- z[has_fp == TRUE & origin == "ae"]
    pbn <- if (is.null(PB)) NA_integer_ else sum(pb_hit(fp))
    # AE-only polls a Poll Bludger post confirms: the ones that could carry Poll Bludger's numbers instead of AE's
    pb_ae <- if (is.null(PB)) NA_integer_ else sum(pb_hit(zp))
    rows[[e]] <- as.data.table(c(list(election = e, live = pairs$live[i], from = pairs$start[i] + 1, to = pairs$end[i]), a, b,
                                 list(f30_pb_post = pbn, ae_pb_post = pb_ae)))
    if (nrow(z)) firms[[e]] <- z[has_fp == TRUE, .N, by = .(firm)][order(-N)][, .(election = e, firms = paste(sprintf("%s %d", firm, N), collapse = ", "))]
  }
}
R <- rbindlist(rows)
R[, ae_share := round(100 * ae / pmax(polls, 1))]; R[, f30_ae_share := round(100 * f30_ae / pmax(f30_polls, 1))]
setorder(R, live, election)
fwrite(R, "output/poll-registry.csv")

pct <- function(n, d) if (d > 0) sprintf("%d (%d%%)", n, round(100 * n / d)) else as.character(n)
tab <- function(x, f30 = FALSE) {
  p <- if (f30) "f30_" else ""
  hdr <- if (f30) "| election | polls | Wikipedia | BludgerTrack | both | AE's numbers | AE filled a party | two-party only |" else
    "| election | polls | Wikipedia | BludgerTrack | both | AE's numbers | of which a Poll Bludger post confirms | AE filled a party | two-party only |"
  if (f30) hdr <- sub("two-party only \\|$", "two-party only | Poll Bludger post confirms |", hdr)
  # the whole-cycle table's extra column: of the polls carrying AE's numbers, how many a Poll Bludger post confirms
  out <- c(hdr, paste0("|", strrep("---|", 9)))
  cell <- function(v, d) if (is.na(v)) "-" else pct(v, d)
  for (k in seq_len(nrow(x))) {
    g <- function(n) x[[paste0(p, n)]][k]
    lab <- paste0(x$election[k], if (x$live[k]) " (live)" else "")
    line <- if (f30)
      sprintf("| %s | %d | %d | %d | %d | %s | %d | %d | %s |", lab, g("polls"), g("wiki"), g("bt"), g("both"),
              pct(g("ae"), g("polls")), g("ae_party"), g("tpp_only"), cell(x$f30_pb_post[k], g("polls")))
    else
      sprintf("| %s | %d | %d | %d | %d | %s | %s | %d | %d |", lab, g("polls"), g("wiki"), g("bt"), g("both"),
              pct(g("ae"), g("polls")), cell(x$ae_pb_post[k], g("ae")), g("ae_party"), g("tpp_only"))
    out <- c(out, line)
  }
  tot <- function(n) sum(x[[paste0(p, n)]])
  totl <- if (f30)
    sprintf("| **all** | %d | %d | %d | %d | %s | %d | %d | %s |", tot("polls"), tot("wiki"), tot("bt"), tot("both"),
            pct(tot("ae"), tot("polls")), tot("ae_party"), tot("tpp_only"), pct(sum(x$f30_pb_post, na.rm = TRUE), tot("polls")))
  else
    sprintf("| **all** | %d | %d | %d | %d | %s | %s | %d | %d |", tot("polls"), tot("wiki"), tot("bt"), tot("both"),
            pct(tot("ae"), tot("polls")), pct(sum(x$ae_pb_post, na.rm = TRUE), tot("ae")), tot("ae_party"), tot("tpp_only"))
  c(out, totl)
}
sc <- R[live == FALSE]
md <- c("# Poll registry",
  "",
  sprintf("Generated by `scripts/build_poll_registry.R` on %s from what `load_polls()` returns under the published settings (AUSPOL_POLL_SOURCE=%s, AUSPOL_POLL_BT=%s). Never hand-edit; rerun after any change to a poll source.",
          format(Sys.time(), "%Y-%m-%d %H:%M"), poll_source_mode(), Sys.getenv("AUSPOL_POLL_BT", "1")),
  "",
  "Counts are statewide (federal: national) voting-intention polls with Labor and Coalition primaries, dated after the previous election up to polling day (live cycles: up to today). Each poll is counted once, by whose numbers the trend reads:",
  "",
  "- **Wikipedia**: our scrape of the election's Wikipedia poll tables (`scripts/fetch_statewide_poll_samples.R`).",
  "- **BludgerTrack**: The Poll Bludger's own poll table (`scripts/build_bludgertrack_polls.R`; fed2025, fed2028, vic2026 only). **both**: the two agree it exists; BludgerTrack's row is kept.",
  "- **AE's numbers**: AE Forecasts' hand-authored poll file, used where we have no copy of the poll, where AE won a dispute, or where our copy failed its own two-party check. Lower is better: the goal is zero.",
  "- **AE filled a party**: our numbers, but one party (UAP, NXT, One Nation) came from AE because our source folds it into Others.",
  "- **two-party only**: rows with no primaries; they do not feed the primary-vote trend.",
  "",
  sprintf("Scored elections: %d. Live cycles: %s.", nrow(sc), paste(R[live == TRUE]$election, collapse = ", ")),
  "",
  "## Whole cycle", "", tab(R), "",
  "## Final 30 days", "",
  sprintf("Poll Bludger post confirms: a post read by `scripts/extract_pollbludger.R` (rules) gives the same Labor and Coalition primaries within 2 points. Source file: `%s`%s.",
          pbf, if (file.exists(pbf)) sprintf(", written %s", format(file.info(pbf)$mtime, "%Y-%m-%d %H:%M")) else " (missing)"),
  "", tab(R, f30 = TRUE), "",
  "## Pollsters per election (whole cycle, polls with primaries)", "",
  "| election | pollsters |", "|---|---|",
  vapply(rbindlist(firms)$election, function(e) sprintf("| %s | %s |", e, rbindlist(firms)[election == e]$firms), ""),
  "",
  "## Sources on disk", "",
  "| source | where | what |", "|---|---|---|",
  "| Wikipedia poll tables | `external/reference/polls/statewide-samples/statewide_polls_wiki.csv` (raw pages in `raw/`) | every election's opinion-poll and main articles; the live pages refetched daily by `forecast.yaml` |",
  "| BludgerTrack poll tables | `external/reference/polls/pollbludger/bludgertrack_polls.csv` (raw XML in `raw/bludgertrack/`) | fed2025, fed2028, vic2026; breakdowns by state, age, gender and more |",
  "| Poll Bludger posts | `external/reference/polls/pollbludger/posts.csv` (raw day pages in `raw/days/`) | every post in each election's final 90 days since 2004 (1,890 posts) |",
  "| AE Forecasts poll files | `external/aus-polling-analyser/` | hand-authored; being retired (`docs/reviews/ae-dependence-audit-2026-10-13.md`) |",
  "")
writeLines(md, "docs/POLL-REGISTRY.md")
cat(sprintf("RY2 wrote docs/POLL-REGISTRY.md and output/poll-registry.csv: %d elections (%d scored). Scored, whole cycle: %d polls, AE's numbers on %d; final 30 days: %d polls, AE's numbers on %d\n",
            nrow(R), nrow(sc), sum(sc$polls), sum(sc$ae), sum(sc$f30_polls), sum(sc$f30_ae)))
