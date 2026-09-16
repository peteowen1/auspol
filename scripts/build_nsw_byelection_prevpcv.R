# own_prev_pcv (fit_xgb_primary_v6.R) matches a candidate against the PRIOR
# GENERAL election only, so a member who first won at a by-election has no
# match and comes back NA -- exactly nsw2019's two worst misses. Orange's
# member won a 2016 by-election, Wagga Wagga's a 2018 by-election
# (docs/reviews/incumbent-classification-bug-2026-09-16.md). Neither
# candidate contested nsw2015, so there is no general-to-general match to
# find; the only real personal-vote data available is the by-election result
# itself.
#
# No candidate-level by-election result existed anywhere on disk before this
# script (checked docs/DATA-REGISTRY.md and the anchor clone's
# by-elections.csv, which is seat-level SWING only, 87 rows, wrong events).
# Two by-elections only -- Orange (SB1602) and Wagga Wagga (SB1801) -- fetched
# by hand from the NSWEC's own results pages, not a generic multi-jurisdiction
# fetcher. Extending to federal/QLD by-elections is future scope, not this.
#
# WHY THIS STAYS A FALLBACK, NOT A REPLACEMENT: a by-election personal vote is
# not the same quantity as a general-election one -- Donato won Orange with
# 23.76% of first preferences (on 48,344 formal votes, a low-turnout,
# single-issue contest) and then took 56.2% of the seat two and a half years
# later at the general election. The by-election number is a genuine personal
# vote, real and better than nothing, but it will UNDERSTATE the eventual
# sophomore-surge level. Do not expect this to close the whole gap.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

RAW <- file.path("external", "reference", "nsw", "byelections")
strip <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", x)))

# ---- Orange (SB1602): results.elections.nsw.gov.au's wide format, one column
# per candidate, header cell "SURNAME Given(CODE)", totals in the
# "Total Votes / Ballot Papers" summaryRow. ----------------------------------
parse_orange <- function() {
  h <- paste(readLines(file.path(RAW, "SB1602-orange-fp.html"), warn = FALSE), collapse = "\n")
  hdr_block <- regmatches(h, regexpr('(?s)<tr class="generalHeader">.*?</tr>', h, perl = TRUE))
  hdr_cells <- strip(regmatches(hdr_block, gregexpr("(?s)<th.*?</th>", hdr_block, perl = TRUE))[[1]])
  cand <- hdr_cells[grepl("^[A-Z]+ .+\\([A-Z]+\\)$", hdr_cells)]
  name <- sub("\\([A-Z]+\\)$", "", cand)
  code <- sub(".*\\(([A-Z]+)\\)$", "\\1", cand)

  tot_block <- regmatches(h, regexpr('(?s)<tr class="summaryRow">\\s*<td>\\s*Total Votes / Ballot Papers.*?</tr>',
                                      h, perl = TRUE))
  vals <- strip(regmatches(tot_block, gregexpr("(?s)<span>.*?</span>", tot_block, perl = TRUE))[[1]])
  votes <- suppressWarnings(as.numeric(gsub("[^0-9]", "", vals)))
  votes <- votes[seq_along(cand)]  # trailing spans are informal/total/status, not per-candidate

  stopifnot(length(name) == length(votes), all(is.finite(votes)))
  data.table(election_to = "nsw2019", seat = "Orange", name = trimws(name), code = code, votes = votes)
}

# ---- Wagga Wagga (SB1801): the standard pastvtr LA table, one row per
# candidate, same shape fetch_transfers_nsw.R already parses. -----------------
parse_wagga <- function() {
  h <- paste(readLines(file.path(RAW, "SB1801-wagga-wagga-fp.html"), warn = FALSE), collapse = "\n")
  tb <- regmatches(h, regexpr("(?s)<table class=\"list\".*?</table>", h, perl = TRUE))
  trs <- regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]
  rows <- list()
  for (tr in trs) {
    cells <- strip(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]])
    if (length(cells) < 4) next
    # Same skip-list fetch_transfers_nsw.R uses for the general-election DOP
    # pages -- a leading-uppercase-run check ("^[A-Z]{2,}") instead would have
    # let "TOTAL FORMAL VOTES" through as a fake candidate AND dropped every
    # real "Mc"-surname candidate (McGIRR fails a 2-uppercase-letter test).
    if (grepl("^(Candidate|Total|Exhausted|Informal|Absolute)", cells[1], ignore.case = TRUE)) next
    v <- suppressWarnings(as.numeric(gsub("[^0-9]", "", cells[3])))
    if (!is.finite(v)) next
    rows[[length(rows) + 1L]] <- data.table(election_to = "nsw2019", seat = "Wagga Wagga",
                                             name = cells[1], party_raw = cells[2], votes = v)
  }
  rbindlist(rows)
}

orange <- parse_orange()
orange[, party := classify_party(rep(NA_character_, .N), code)]
wagga <- parse_wagga()
wagga[, party := classify_party(party_raw)]

both <- rbindlist(list(orange[, .(election_to, seat, name, party, votes)],
                        wagga[, .(election_to, seat, name, party, votes)]))
both[, formal := sum(votes), by = seat]
both[, own_prev_pcv_byelection := 100 * votes / formal]

cat("BY1  parsed by-election first preferences:\n")
print(both[order(seat, -votes)])

# The DECLARED WINNER, not the first-preference leader: Orange's Barrett (NP)
# led first preferences 31.6% to Donato's 23.8% and LOST the seat on
# preference distribution -- exactly the trap CLAUDE.md records ("truth for a
# backtest must not come from our own exclusion machinery"). Cross-checked
# against load_seats(2019,"nsw")$incumbent, which already carries the real
# declared winner (SFF for Orange, IND for Wagga Wagga).
winners <- both[grepl("^DONATO", name) | grepl("^McGIRR|^MCGIRR", name, ignore.case = TRUE)]
cat("\nBY2  declared-winner sanity check against known results (Donato SFF ~23.76%, McGirr IND ~25.42%):\n")
print(winners[, .(seat, name, party, own_prev_pcv_byelection = round(own_prev_pcv_byelection, 2))])
stopifnot(nrow(winners) == 2,
          abs(winners[seat == "Orange"]$own_prev_pcv_byelection - 23.76) < 0.1,
          abs(winners[seat == "Wagga Wagga"]$own_prev_pcv_byelection - 25.42) < 0.1)

# Only the winners are written: own_prev_pcv's gap is specifically the
# by-election-installed incumbent's row, and every other candidate in these
# two seats either has a real general-election history already (Barrett
# stood again in 2019) or is irrelevant to the party class they'd be matched
# under here.
f <- file.path("output", "nsw-byelection-prevpcv.csv")
fwrite(winners[, .(election_to, seat, party, own_prev_pcv_byelection)], f)
cat(sprintf("\nBY3  wrote %s\n", f))
