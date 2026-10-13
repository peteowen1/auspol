#!/usr/bin/env Rscript
# Score a model's extraction of polls from Poll Bludger posts (deciding-runs/pb-llm/<election>-polls.csv) against
# the poll set the trend reads (AE's numbers on most of these cycles: the answer key, one last time).
#
# Coverage program 2026-10-13: the rule extractor (extract_pollbludger.R) confirms only 15% of the polls that still
# carry AE's numbers; this measures whether a model reading the posts does better, before any of its numbers are used.
#
# Usage: Rscript scripts/score_pb_llm_extraction.R nsw2019
# Matching: same firm (firm_alias.csv), post date 0 to 14 days after the poll's midpoint, closest numbers first.
# Prints: polls extracted, matched, agreement (every party within 0.5 / 1 / off > 2), and the cycle's polls in the
# key that the extraction missed. Check codes: PLX1-PLX3.

suppressPackageStartupMessages(library(data.table))
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
e <- commandArgs(TRUE)[1]; rg <- sub("[0-9]+$", "", e)
# one file per election, or one per chunk (<e>-p<k>-polls.csv) when the posts were split for the reading agents
fx <- list.files("deciding-runs/pb-llm", pattern = sprintf("^%s(-p[0-9]+)?-polls\\.csv$", e), full.names = TRUE)
if (!length(fx)) stop("PLX1! no extraction files for ", e)
X <- rbindlist(lapply(fx, function(f) fread(f, colClasses = "character")[, src_file := basename(f)]), fill = TRUE)
X[, post_date := as.Date(post_date)]
# a poll reported in two chunks: same pollster and primaries within 10 days counts once
X <- X[order(post_date)]
X[, dup := duplicated(paste(tolower(pollster), alp, coalition, greens)) &
            vapply(seq_len(.N), function(i) any(abs(as.integer(post_date[i] - post_date[seq_len(i - 1)])) <= 10 &
                                                  tolower(pollster[seq_len(i - 1)]) == tolower(pollster[i]) &
                                                  alp[seq_len(i - 1)] == alp[i] & coalition[seq_len(i - 1)] == coalition[i]), TRUE)]
X[is.na(dup), dup := FALSE]
X <- X[dup == FALSE]
cat(sprintf("PLX1 %s: %d polls extracted from posts\n", e, nrow(X)))
alias <- fread("external/reference/polls/statewide-samples/firm_alias.csv", showProgress = FALSE)
L <- suppressMessages(load_polls(rg)); P <- attr(L, "provenance")
# Polling days election_dates() does not carry yet (checked against Wikipedia infoboxes 2026-10-13, 31 of 38 agree,
# 7 unchecked); to move into R/election_dates.R with the first new pair.
eds <- election_dates()
extra_eds <- c(fed2001 = "2001-11-10", nsw2003 = "2003-03-22", nsw2007 = "2007-03-24", nsw2011 = "2011-03-26",
  vic2002 = "2002-11-30", vic2006 = "2006-11-25", qld2001 = "2001-02-17", qld2004 = "2004-02-07", qld2006 = "2006-09-09",
  qld2009 = "2009-03-21", qld2012 = "2012-03-24", qld2015 = "2015-01-31", sa2002 = "2002-02-09", sa2006 = "2006-03-18",
  sa2010 = "2010-03-20", sa2014 = "2014-03-15", fed1998 = "1998-10-03")
extra_eds <- extra_eds[!names(extra_eds) %in% names(eds)]
eds <- c(eds, stats::setNames(as.Date(extra_eds), names(extra_eds)))
ed <- as.Date(eds[[e]])
prev <- max(eds[sub("[0-9]+$", "", names(eds)) == rg & eds < ed])
K <- data.table(li = seq_len(nrow(L)), d = L$date, firm = L$firm, ALP = L$ALP, LNP = L$LNP, GRN = L$GRN,
                ONP = if ("ONP" %in% names(L)) L$ONP else NA_real_, origin = P$origin)[d > prev & d <= ed & is.finite(ALP)]
K[, canon := .ps_canon(firm, alias)]; X[, canon := .ps_canon(pollster, alias)]; X[, xi := .I]
# One firm under two names across eras: AE files "YouGov Galaxy" as Galaxy and "uComms/ReachTEL" as ReachTEL.
same_firm <- c(yougov = "galaxy", ucomms = "reachtel")
K[canon %in% names(same_firm), canon := same_firm[canon]]; X[canon %in% names(same_firm), canon := same_firm[canon]]
num <- function(v) suppressWarnings(as.numeric(v))
X[, `:=`(alp = num(alp), coalition = num(coalition), greens = num(greens), one_nation = num(one_nation), undecided = num(undecided))]
# undecided divided out, as the key does
X[, sc := 100 / (100 - fifelse(is.finite(undecided) & undecided > 0 & undecided < 50, undecided, 0))]
cand <- X[, .(xi, canon, dp = post_date)][K[, .(li, canon, d)], on = "canon", allow.cartesian = TRUE, nomatch = NULL]
# Up to 45 days: Newspoll's state polls pool two or three months, so the post comes long after the midpoint.
# Closest numbers first, then closest date.
cand <- cand[as.integer(dp - d) >= -1L & as.integer(dp - d) <= 45L]
# AE is inconsistent about undecided (ReachTEL kept raw, others divided out), so each pair is compared both ways and
# the closer one counts; the scale used is recorded.
kk0 <- match(cand$li, K$li)
d_raw <- abs(X$alp[cand$xi] - K$ALP[kk0]) + abs(X$coalition[cand$xi] - K$LNP[kk0])
d_sc  <- abs(X$alp[cand$xi] * X$sc[cand$xi] - K$ALP[kk0]) + abs(X$coalition[cand$xi] * X$sc[cand$xi] - K$LNP[kk0])
cand[, use_raw := !is.na(d_raw) & (is.na(d_sc) | d_raw <= d_sc)]
cand[, score := pmin(d_raw, d_sc, na.rm = TRUE) + as.integer(dp - d) / 60]
setorder(cand, score)
ux <- logical(nrow(X)); uk <- logical(max(K$li)); keep <- logical(nrow(cand))
for (k in seq_len(nrow(cand))) { a <- cand$xi[k]; b <- cand$li[k]; if (ux[a] || uk[b]) next; ux[a] <- uk[b] <- keep[k] <- TRUE }
M <- cand[keep]
kk <- match(M$li, K$li)
s <- ifelse(M$use_raw, 1, X$sc[M$xi])
R <- data.table(date = K$d[kk], firm = K$firm[kk], origin = K$origin[kk], undecided_divided_out = !M$use_raw,
                ALP_x = X$alp[M$xi] * s, ALP_k = K$ALP[kk], LNP_x = X$coalition[M$xi] * s, LNP_k = K$LNP[kk],
                GRN_x = X$greens[M$xi] * s, GRN_k = K$GRN[kk])
R[, maxd := pmax(abs(ALP_x - ALP_k), abs(LNP_x - LNP_k), abs(GRN_x - GRN_k), na.rm = TRUE)]
cat(sprintf("PLX2 matched %d of %d extracted; key has %d polls in the cycle (%d carrying AE's numbers). Every party within 0.5: %d; within 1: %d; off by > 2: %d\n",
            nrow(R), nrow(X), nrow(K), sum(K$origin == "ae"), sum(R$maxd <= 0.5, na.rm = TRUE), sum(R$maxd <= 1, na.rm = TRUE), sum(R$maxd > 2, na.rm = TRUE)))
cat(sprintf("PLX3 AE-only polls confirmed: %d of %d; extracted polls with no match in the key: %d\n",
            sum(R$origin == "ae"), sum(K$origin == "ae"), sum(!ux)))
print(R[order(-maxd)][1:min(10, nrow(R))])
if (any(!ux)) { cat("\nExtracted, not in the key (new polls, or wrong):\n"); print(X[!ux, .(post_date, pollster, alp, coalition, greens, one_nation, undecided)]) }
fwrite(R, sprintf("deciding-runs/pb-llm/%s-scored.csv", e))
