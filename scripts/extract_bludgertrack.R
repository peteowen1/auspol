#!/usr/bin/env Rscript
# Poll Bludger's own poll tables (BludgerTrack "Poll data"), parsed to rows and scored against AE.
#
# WHY: moving off AE's hand-authored poll files (docs/reviews/ae-dependence-audit-2026-10-13.md).
# BludgerTrack publishes, for the current cycles only, the poll table its aggregate is built on:
# start, end, pollster, mode, scope (national, each state, and demographic cuts), sample, primaries,
# undecided, published and respondent-allocated two-party. Fetched as raw XML by hand on 2026-10-13
# into external/reference/polls/pollbludger/raw/bludgertrack/ (fed2025, fed2028, vic2026; the 2019
# file, fed2019-bt-output.xml, holds weekly trend points, not polls; earlier cycles return 404).
#
# Every attribute and child of every <point> is kept (CLAUDE.md "Capture EVERY field"); parsed
# dates and numbers sit beside the raw text. Dates come as ISO in fed2025 and DD/MM/YYYY in the
# later files, so each is parsed by its own shape and a value that fails to parse is counted.
#
# Then the answer-key check: every BludgerTrack national (or Victorian) poll is matched to the
# shipped layered poll set by firm and midpoint (within 4 days), and the primaries are compared
# where both have them, split by whose numbers the layered row carries (ours from Wikipedia, or
# AE). The count that matters for moving off AE: layered rows still carrying AE's numbers that
# BludgerTrack also has.
#
# Output: external/reference/polls/pollbludger/bludgertrack_polls.csv (all rows, all scopes),
#         output/bludgertrack-vs-layered.csv (one row per matched poll).
# Check codes: BJ1 parse, BJ2! unparsed dates, BJ3 match summary.

suppressPackageStartupMessages({ library(xml2); library(data.table) })
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))

raw_dir <- "external/reference/polls/pollbludger/raw/bludgertrack"
files <- c(fed2025 = "fed2025-current.xml", fed2028 = "fed2028-current.xml", vic2026 = "vic2026-current.xml")

parse_bt <- function(f, cycle) {
  x <- read_xml(file.path(raw_dir, f))
  pts <- xml_find_all(x, "//table/point")
  d <- rbindlist(lapply(pts, function(p) {
    a <- as.list(xml_attrs(p)); ch <- xml_children(p)
    v <- as.list(xml_text(ch)); names(v) <- xml_name(ch); c(a, v)
  }), fill = TRUE)
  d[, `:=`(cycle = cycle, section = vapply(pts, function(p) xml_name(xml_parent(xml_parent(p))), ""),
           file = f, file_stamp = xml_attr(x, "date"))]
  d
}
bt <- rbindlist(Map(parse_bt, files, names(files)), fill = TRUE)
pdate <- function(s) {
  out <- as.Date(rep(NA_character_, length(s)))
  iso <- grepl("^\\d{4}-\\d{2}-\\d{2}$", s); dmy <- grepl("^\\d{2}/\\d{2}/\\d{4}$", s)
  out[iso] <- as.Date(s[iso], format = "%Y-%m-%d"); out[dmy] <- as.Date(s[dmy], format = "%d/%m/%Y")
  out
}
for (k in c("start", "end", "median")) bt[[paste0(k, "_date")]] <- pdate(bt[[k]])
num_cols <- intersect(c("sample", "ALP", "LNC", "GRN", "PHON", "ONP", "UND", "ALP2", "LNC2", "ALPra", "LNCra", "UNDra",
                        "pmSAT", "pmDIS", "olSAT", "olDIS", "pmPREF", "olPREF"), names(bt))
for (k in num_cols) bt[[paste0(k, "_n")]] <- suppressWarnings(as.numeric(bt[[k]]))
if (!"scope" %in% names(bt)) bt$scope <- NA_character_
bt[section == "victoria" & is.na(scope), scope := "VIC-STATE"]
bad_d <- bt[!is.na(end) & nzchar(end) & is.na(end_date)]
cat(sprintf("BJ1 parsed %d rows: %s\n", nrow(bt), paste(bt[, sprintf("%s/%s %d", cycle, section, .N), by = .(cycle, section)]$V1, collapse = ", ")))
if (nrow(bad_d)) { cat(sprintf("BJ2! %d end dates did not parse:\n", nrow(bad_d))); print(head(bad_d[, .(cycle, Id, start, end)])) }
fwrite(bt, "external/reference/polls/pollbludger/bludgertrack_polls.csv")

## Answer-key check against the shipped layered poll set.
alias <- fread("external/reference/polls/statewide-samples/firm_alias.csv", showProgress = FALSE)
polls_bt <- bt[section %in% c("federal", "victoria") & scope %in% c("NAT", "VIC-STATE") & !grepl("^Election$", pollster) & is.finite(ALP_n)]
polls_bt[, region := ifelse(section == "federal", "fed", "vic")]
polls_bt[, mid := median_date]; polls_bt[is.na(mid), mid := start_date + as.integer(end_date - start_date) %/% 2L]
polls_bt[, canon := .ps_canon(pollster, alias)]
polls_bt[, ONP_bt := if ("ONP_n" %in% names(polls_bt)) fifelse(is.finite(ONP_n), ONP_n, PHON_n) else PHON_n]
# BludgerTrack carries undecided separately on some polls (UND); the layered set has it divided out.
polls_bt[, und := fifelse(is.finite(UND_n), UND_n, 0)]
polls_bt[, scale := 100 / (100 - und)]

out <- list()
for (rg in c("fed", "vic")) {
  L <- suppressMessages(load_polls(rg)); P <- attr(L, "provenance")
  L <- data.table(li = seq_len(nrow(L)), date = L$date, firm = L$firm, ALP = L$ALP, LNP = L$LNP, GRN = L$GRN,
                  ONP = if ("ONP" %in% names(L)) L$ONP else NA_real_, source = P$source)
  L[, canon := .ps_canon(firm, alias)]
  B <- polls_bt[region == rg]; B[, bi := .I]
  cand <- B[, .(bi, canon, d_b = mid)][L[, .(li, canon, d_l = date)], on = "canon", allow.cartesian = TRUE, nomatch = NULL]
  cand <- cand[abs(as.integer(d_b - d_l)) <= 4L]
  numd <- abs(B$ALP_n[cand$bi] * B$scale[cand$bi] - L$ALP[cand$li]) + abs(B$LNC_n[cand$bi] * B$scale[cand$bi] - L$LNP[cand$li])
  cand[, score := abs(as.integer(d_b - d_l)) + fifelse(is.finite(numd), numd, 50) / 2]
  setorder(cand, score)
  ub <- logical(nrow(B)); ul <- logical(nrow(L)); keep <- logical(nrow(cand))
  for (k in seq_len(nrow(cand))) { b <- cand$bi[k]; l <- cand$li[k]; if (ub[b] || ul[l]) next; ub[b] <- ul[l] <- keep[k] <- TRUE }
  m <- cand[keep]
  r <- data.table(region = rg, bt_id = B$Id[m$bi], bt_cycle = B$cycle[m$bi], date = L$date[m$li], firm = L$firm[m$li],
                  pollster_bt = B$pollster[m$bi], mode_bt = B$mode[m$bi], sample_bt = B$sample_n[m$bi], source = L$source[m$li],
                  und_bt = B$und[m$bi])
  for (p in c("ALP", "LNP", "GRN", "ONP")) {
    bcol <- switch(p, ALP = "ALP_n", LNP = "LNC_n", GRN = "GRN_n", ONP = "ONP_bt")
    r[[paste0(p, "_bt")]] <- B[[bcol]][m$bi] * B$scale[m$bi]
    r[[paste0(p, "_layered")]] <- L[[p]][m$li]
  }
  # The window the comparison can speak for: BludgerTrack's own span.
  span <- range(B$mid, na.rm = TRUE)
  inspan <- L[date >= span[1] & date <= span[2]]
  cat(sprintf("BJ3 %s: BludgerTrack %d polls (%s to %s), layered %d in that span; matched %d. Layered rows in span by source, and how many BludgerTrack has:\n",
              rg, nrow(B), span[1], span[2], nrow(inspan), nrow(m)))
  print(inspan[, .(layered = .N, bt_has = sum(ul[li])), by = source][order(-layered)])
  unb <- B[!ub & mid >= span[1]]
  cat(sprintf("  BludgerTrack polls with no layered match: %d (by pollster: %s)\n", nrow(unb),
              paste(unb[, .N, by = pollster][order(-N), sprintf("%s %d", pollster, N)], collapse = ", ")))
  out[[rg]] <- r
}
R <- rbindlist(out, fill = TRUE)
for (p in c("ALP", "LNP", "GRN", "ONP")) R[[paste0(p, "_d")]] <- R[[paste0(p, "_bt")]] - R[[paste0(p, "_layered")]]
fwrite(R, "output/bludgertrack-vs-layered.csv")
cat("\nAgreement where both have the poll: absolute difference in primary points, BludgerTrack (undecided divided out) minus layered; lower is closer.\n")
agg <- R[, .(polls = .N,
             ALP_mean_abs = round(mean(abs(ALP_d), na.rm = TRUE), 2), LNP_mean_abs = round(mean(abs(LNP_d), na.rm = TRUE), 2),
             GRN_mean_abs = round(mean(abs(GRN_d), na.rm = TRUE), 2), ONP_mean_abs = round(mean(abs(ONP_d), na.rm = TRUE), 2),
             any_gt1 = sum(pmax(abs(ALP_d), abs(LNP_d), abs(GRN_d), abs(ONP_d), na.rm = TRUE) > 1),
             any_gt2 = sum(pmax(abs(ALP_d), abs(LNP_d), abs(GRN_d), abs(ONP_d), na.rm = TRUE) > 2)), by = .(region, source)]
print(agg[order(region, -polls)])
cat("\nLargest disagreements:\n")
R[, maxd := pmax(abs(ALP_d), abs(LNP_d), abs(GRN_d), abs(ONP_d), na.rm = TRUE)]
print(R[order(-maxd)][1:15, .(region, date, firm, source, und_bt, ALP_bt = round(ALP_bt, 1), ALP_layered, LNP_bt = round(LNP_bt, 1), LNP_layered,
                              GRN_bt = round(GRN_bt, 1), GRN_layered, ONP_bt = round(ONP_bt, 1), ONP_layered)])
