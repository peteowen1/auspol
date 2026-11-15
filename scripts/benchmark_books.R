# Shared bookmaker-capture readers for the vic2026 benchmark scripts: snapshot_benchmarks.R,
# compare_bookmaker_odds.R and value_odds_vic2026.R all source this file, so a fix to how a capture is
# read reaches all three (15 Nov 2026: each script had its own copy, and all three read only one Betfair file).
#
# Check codes: BK1 (what was read), BK2! (seat markets left out as not real books), BK3! (a name we cannot match).

# Betfair prices arrive in chunks, one file per request (chunk = 10 since 15 Nov). Read EVERY markets file and
# keep each market from the newest file that has it: reading only the newest file scored one chunk's seats and
# dropped the rest with nothing said. Returns the parsed table with a `file` column (basename it came from).
bk_read_betfair <- function(dir, rd) {
  fs <- list.files(dir, "^markets-.*\\.json$", full.names = TRUE)
  if (!length(fs)) return(NULL)
  fs <- fs[order(file.mtime(fs), decreasing = TRUE)]
  o <- data.table::rbindlist(lapply(seq_along(fs), function(i)
    oddsdata::bf_parse_prices(rd(fs[i]))[, `:=`(.file_rank = i, file = basename(fs[i]))]))
  o <- o[o[, .I[.file_rank == min(.file_rank)], by = market_id]$V1][, .file_rank := NULL]
  cat(sprintf("BK1 betfair: %d raw file(s), %d markets\n", length(fs), data.table::uniqueN(o$market_id)))
  o[]
}

# A book whose 1/price sums past 1.5 is not a market. On 15 Nov, 33 of 82 priced Betfair seats showed a best back
# of 1.01 on three or more candidates (placeholder offers, summing to as much as 392%), and the power devig has no
# root for them. Those seats are dropped and named, never devigged. `by` identifies one book.
bk_drop_unreal_books <- function(o, by, src, limit = 1.5) {
  s <- o[, .(s = sum(ifelse(is.finite(price) & price > 1, 1 / price, 0))), by = by]
  junk <- s[s > limit]
  if (!nrow(junk)) return(o)
  seats <- sort(unique(junk[[if ("seat" %in% names(junk)) "seat" else utils::tail(by, 1)]]))
  cat(sprintf("BK2! %s: %d seat market(s) left out, book over %.0f%% (no real prices): %s\n", src, nrow(junk),
              100 * limit, paste(seats, collapse = ", ")))
  o[!junk, on = by]
}

# Bookie seat name -> our spelling. Case, hyphens and spaces are ignored ("South West Coast" is our
# "South-West Coast"); anything still unmatched is an error, not a silent drop.
bk_our_seat <- function(x, ours) {
  key <- function(v) gsub("[- ]+", "", toupper(trimws(v)))
  canon <- stats::setNames(unique(ours), key(unique(ours)))
  if (anyDuplicated(names(canon))) stop("BK3! two of our seat names collide once hyphens and spaces are ignored")
  out <- unname(canon[key(x)])
  if (anyNA(out)) stop("BK3! bookie seat names we do not have: ", paste(unique(x[is.na(out)]), collapse = ", "))
  out
}
