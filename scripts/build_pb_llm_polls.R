#!/usr/bin/env Rscript
# Consolidate the polls a model read from Poll Bludger posts into one table the poll layer reads (AUSPOL_POLL_PB).
#
# Inputs: external/reference/polls/pollbludger/llm-extracted/<cycle>[-p<k>]-polls.csv, one per post chunk, written by
# Sonnet agents (docs/reviews/pb-llm-extraction-2026-10-13.md). Every column is kept.
#
# STATED, NOT INFERRED: a few agents filled a figure from a neighbouring post ("no change on the previous fortnight").
# A row's primaries count as stated only if each of Labor's and the Coalition's figures appears in the row's own
# quoted source sentence; otherwise `stated` is FALSE and the poll layer ignores the row.
# WA was re-read with Liberal and National separate (workflow wf_805ce2a2-2b0, 2026-10-13); see below.
#
# Output: external/reference/polls/pollbludger/pb_llm_polls.csv. Check codes: PJ1 per cycle, PJ2 written.

suppressPackageStartupMessages(library(data.table))
src <- Sys.getenv("AUSPOL_PB_LLM_DIR", "external/reference/polls/pollbludger/llm-extracted")
out <- Sys.getenv("AUSPOL_PB_LLM_OUT", "external/reference/polls/pollbludger/pb_llm_polls.csv")
fs <- list.files(src, pattern = "-polls\\.csv$", full.names = TRUE)
# WA: the agents' own files (<cycle>-wa-polls.csv) keep Liberal and National apart; the converted <cycle>-polls.csv
# sets coalition = Liberal (load_polls("wa") keeps LIB as LNP and NAT apart), so a combined-only figure is blank there
# and the row fails the stated test. Read only the converted file.
fs <- fs[!grepl("-wa-polls\\.csv$", basename(fs))]
if (!length(fs)) stop("PJ1! no extraction files in ", src)
# fill = TRUE: an agent's stray comma gives one row an extra field; without it fread stops there and silently drops
# every later row of the file (fed2010-p4, 2026-10-13). Such a row is flagged malformed and left out, counted.
rd <- function(f) {
  hdr <- names(fread(f, nrows = 0))
  x <- fread(f, colClasses = "character", fill = TRUE)
  extra <- setdiff(names(x), hdr)
  x[, malformed := if (length(extra)) Reduce(`|`, lapply(extra, function(k) !is.na(x[[k]]) & nzchar(x[[k]]))) else FALSE]
  # fread can still stop early when the stray-comma row lies past its column-detection sample: a row count below the
  # file's record count stops the build rather than losing the tail quietly
  # records = lines of fields, quotes respected (read.csv would wrap a 15-field row onto a second record)
  n_rec <- length(utils::count.fields(f, sep = ",", quote = "\"", blank.lines.skip = TRUE, comment.char = "")) - 1L
  if (nrow(x) < n_rec) stop(sprintf("PJ1! %s: fread read %d rows of %d records; rows would be lost", basename(f), nrow(x), n_rec))
  x[, (extra) := NULL][, src_file := basename(f)]
}
X <- rbindlist(lapply(fs, rd), fill = TRUE)
if (any(X$malformed)) cat(sprintf("PJ1! %d malformed rows left out: %s\n", sum(X$malformed),
                                  paste(unique(X$src_file[X$malformed]), collapse = ", ")))
X <- X[malformed == FALSE]
X[, cycle := sub("(-p[0-9]+)?-polls\\.csv$", "", src_file)]
X[, region := sub("[0-9]+$", "", cycle)]
X[, post_date := as.Date(post_date)]
num <- function(v) suppressWarnings(as.numeric(v))
for (k in c("alp", "coalition", "greens", "one_nation", "others", "undecided", "alp_2pp", "coalition_2pp", "sample"))
  if (k %in% names(X)) X[[paste0(k, "_n")]] <- num(gsub(",", "", X[[k]]))
# a figure is stated when it appears in the quote as a whole number token ("40", "40.5"), not inside another number
# ("40" is not stated by "40.5": a following "." must not start decimals)
in_quote <- function(v, q) is.finite(v) & mapply(function(x, s) grepl(sprintf("(^|[^0-9.])%s([^0-9.]|\\.[^0-9]|\\.?$)", gsub(".", "\\.", format(x), fixed = TRUE)), s),
                                                  v, ifelse(is.na(q), "", q))
stopifnot(in_quote(40, "Labor on 40 per cent"), !in_quote(40, "Labor on 40.5 per cent"), in_quote(40.5, "Labor 40.5%"),
          in_quote(40, "Labor 40."), !in_quote(4, "Greens 4.5"), !in_quote(40, "140 votes"))
X[, stated := in_quote(alp_n, quote) & in_quote(coalition_n, quote)]
# a poll reported in two chunks: same pollster, same primaries, posts within 10 days
setorder(X, region, post_date)
key <- paste(X$region, tolower(X$pollster), X$alp_n, X$coalition_n)
X[, dup := FALSE]
for (i in seq_len(nrow(X))) {
  j <- which(key[seq_len(i - 1)] == key[i] & abs(as.integer(X$post_date[seq_len(i - 1)] - X$post_date[i])) <= 10 & !X$dup[seq_len(i - 1)])
  if (!length(j) || !is.finite(X$alp_n[i])) next
  # keep a stated copy over an unstated one
  if (X$stated[i] && !any(X$stated[j])) X$dup[j] <- TRUE else X$dup[i] <- TRUE
}
X <- X[dup == FALSE]
for (cy in unique(X$cycle)) {
  z <- X[cycle == cy]
  both <- is.finite(z$alp_n) & is.finite(z$coalition_n)
  cat(sprintf("PJ1 %s: %d polls; %d with Labor and Coalition primaries, of which %d stated in their quote and %d not (inferred, ignored)\n",
              cy, nrow(z), sum(both), sum(both & z$stated), sum(both & !z$stated)))
}
fwrite(X, out)
cat(sprintf("PJ2 wrote %s: %d rows (%d stated)\n", out, nrow(X), sum(X$stated)))
