# Shared bookmaker-capture readers for the vic2026 benchmark scripts: snapshot_benchmarks.R,
# compare_bookmaker_odds.R and value_odds_vic2026.R all source this file, so a fix to how a capture is
# read reaches all three (15 Nov 2026: each script had its own copy, and all three read only one Betfair file).
#
# Check codes: VBK1 (what was read; VBK1! when its files span more than 15 minutes of fetches), VBK2! (seat
# markets left out as not real books), VBK3! (a name we cannot match).

# Betfair prices arrive in chunks, one file per request (chunk = 10 since 15 Nov). Read EVERY markets file and
# keep each market from the most recently FETCHED file that has it (the manifest's fetched_utc; file mtime only
# where a file is not in the manifest): reading only the newest file scored one chunk's seats and dropped the rest
# with nothing said. Prints the fetch-time range of the files used, so a market kept from an older run is visible.
# Returns the parsed table with `file` and `fetched` columns.
bk_read_betfair <- function(dir, rd) {
  fs <- list.files(dir, "^markets-.*\\.json$", full.names = TRUE)
  if (!length(fs)) return(NULL)
  man_f <- file.path(dirname(dir), "manifest.tsv")
  man <- if (file.exists(man_f)) data.table::fread(man_f, sep = "\t") else NULL
  ft <- if (is.null(man)) rep(NA_character_, length(fs)) else
    man$fetched_utc[match(file.path(basename(dir), basename(fs)), man$file)]
  when <- as.POSIXct(ft, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  n_unlisted <- sum(is.na(when))
  when[is.na(when)] <- file.mtime(fs[is.na(when)])
  ord <- order(when, decreasing = TRUE)
  fs <- fs[ord]; when <- when[ord]
  o <- data.table::rbindlist(lapply(seq_along(fs), function(i)
    oddsdata::bf_parse_prices(rd(fs[i]))[, `:=`(.file_rank = i, file = basename(fs[i]), fetched = when[i])]))
  o <- o[o[, .I[.file_rank == min(.file_rank)], by = market_id]$V1][, .file_rank := NULL]
  used <- range(o$fetched)
  span <- as.numeric(difftime(used[2], used[1], units = "mins"))
  cat(sprintf("VBK1%s betfair: %d raw file(s), %d markets, fetched %s to %s UTC (%.0f min)%s\n",
              if (span > 15) "!" else "", length(fs), data.table::uniqueN(o$market_id),
              format(used[1], "%H:%M:%S"), format(used[2], "%H:%M:%S"), span,
              paste0(if (span > 15) "; markets come from more than one capture" else "",
                     if (n_unlisted) sprintf("; %d file(s) not in the manifest, dated by mtime", n_unlisted) else "")))
  o[]
}

# Books that are not markets are dropped and named, never devigged:
#  - fewer than two priced runners: a lone price devigs to probability 1 (oddsdata's devig() returns 1 for one
#    price), which would publish as a certain call (45 of 88 Betfair seats on 15 Nov);
#  - 1/price summing past `limit` (1.5): 33 Betfair seats showed a best back of 1.01 on three or more candidates
#    (placeholder offers, up to 392%), where the power devig has no root;
#  - a placeholder price (at or below 1.02) beside other runners worth more than 0.3 between them: a real 1.01
#    favourite leaves almost nothing for the rest (Eildon 139% and Brighton 149% on 15 Nov had a 1.01 offer).
# `by` identifies one book.
bk_drop_unreal_books <- function(o, by, src, limit = 1.5) {
  s <- o[, {
    q <- ifelse(is.finite(price) & price > 1, 1 / price, NA_real_)
    lo <- is.finite(price) & price > 1 & price <= 1.02
    list(s = sum(q, na.rm = TRUE), n = sum(!is.na(q)), rest = sum(q[!lo], na.rm = TRUE), has_lo = any(lo))
  }, by = by]
  junk <- s[n < 2L | s > limit | (has_lo & rest > 0.3)]
  if (!nrow(junk)) return(o)
  name_col <- if ("seat" %in% names(junk)) "seat" else utils::tail(by, 1)
  why <- function(ok) sort(unique(junk[[name_col]][ok]))
  cat(sprintf("VBK2! %s: %d seat market(s) left out as not real books (%d with fewer than two prices, %d over %.0f%%, %d with a 1.01-style placeholder): %s\n",
              src, nrow(junk), sum(junk$n < 2L), sum(junk$n >= 2L & junk$s > limit),
              100 * limit, sum(junk$n >= 2L & junk$s <= limit), paste(why(TRUE), collapse = ", ")))
  o[!junk, on = by]
}

# Bookie seat name -> our spelling. Case, hyphens and spaces are ignored ("South West Coast" is our
# "South-West Coast"); anything still unmatched is an error, not a silent drop.
bk_our_seat <- function(x, ours) {
  key <- function(v) gsub("[- ]+", "", toupper(trimws(v)))
  canon <- stats::setNames(unique(ours), key(unique(ours)))
  if (anyDuplicated(names(canon))) stop("VBK3! two of our seat names collide once hyphens and spaces are ignored")
  out <- unname(canon[key(x)])
  if (anyNA(out)) stop("VBK3! bookie seat names we do not have: ", paste(unique(x[is.na(out)]), collapse = ", "))
  out
}
