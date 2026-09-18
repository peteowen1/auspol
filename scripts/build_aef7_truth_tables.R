# Pete asked directly: do we have ONE table, per seat, with our prediction
# (ITG), AEF's prediction, and TWO independent sources of truth (the
# official commission data we already ingest, and ABC's scrape as a second,
# cross-checking source) -- for both TCP and primary vote? Answer before
# this file existed: the pieces existed on disk, unmerged, in at least four
# different files, and ABC wasn't one of them at all. This is that table,
# built twice (TCP and primary), not just described.
#
# TCP source per column:
#   itg_tcp_*      backtest-<pair>-ourtcp-*.csv, OUR top-scenario pick
#   aef_tcp_*      output/aef7-final-two-and-tcp-reference.csv's aef_tcp_*
#                  (AEF's own cached scenario data)
#   official_*     the SAME reference file's f1/f2/f2cp/fsrc -- the real
#                  declared result, built 2026-09-18 from NSWEC/ECQ/WAEC/
#                  AEC/ECSA sources (scripts/build_aef7_tcp_official.R,
#                  build_aef7_tcp_backfill.R)
#   abc_tcp_*      scripts/fetch_abc_seat_guides.R's scrape, parsed directly
#                  from whatever raw HTML is cached so far (the scrape's own
#                  CSV write only happens once at the very end of its run --
#                  a design gap, noted, not yet fixed -- so this script reads
#                  external/reference/abc/<pair>/*.html directly instead of
#                  waiting for it). NA for any pair not yet scraped.
#
# Primary source per column, one row per (pair, seat, party class):
#   itg_primary       output/pooled-sharedetail.csv's pred_share
#   aef_primary       output/aef7-fptrend.csv's aef_fp_pred
#   official_primary  the SAME pooled-sharedetail.csv's actual_share -- this
#                     is already commission-sourced (built from candidacies.csv,
#                     itself from AEC/state EC downloads), not a third thing
#   abc_primary       ABC scrape, aggregated to OUR party classes via
#                     classify_party() since ABC reports by candidate/party
#                     name, not by our LNP/ALP/GRN/... scheme
#
# Emits TT0-TT4 log codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(rvest))

OUT <- "output"
AEF7 <- c("fed2022","fed2025","nsw2023","qld2024","sa2026","vic2022","wa2025")
JURIS_PREFIX <- list(nsw2023 = "nsw", qld2024 = "qld", sa2026 = "sa", vic2022 = "vic", wa2025 = "wa")

newest_file <- function(pr, kind) {
  pat <- if (pr %in% names(JURIS_PREFIX)) sprintf("^backtest-%s-%s", JURIS_PREFIX[[pr]], kind)
         else sprintf("^backtest-fed-%s", kind)
  g <- list.files(OUT, pattern = pat, full.names = TRUE)
  if (!length(g)) return(NULL)
  g[which.max(file.mtime(g))]
}

# ---- ABC: parse whatever's cached on disk right now, per pair -----------
#
# Seat identity comes from the page's OWN <h1> ("Narracan (Supplementary) -
# VIC Election 2022"), NOT from reconstructing a name out of the 4-letter
# slug. A first version matched on the slug's first 4 letters, which folded
# BOTH "Narre Warren North" and "Narre Warren South" onto whichever single
# page the crude match hit first -- narr.html, which turned out to be a
# completely unrelated seat, "Narracan (Supplementary)". That produced 3
# false "winner disagreements" that were a matching bug, not a data problem,
# caught only by opening the actual page behind one of them. Any parenthetical
# suffix ("(Key Seat)", "(Supplementary)") is stripped; a "(Supplementary)"
# seat is a by-election held on a different date and excluded entirely, since
# it does not correspond to any of our AEF7 seats.
parse_abc_seat <- function(html) {
  doc <- read_html(html)
  h1 <- html_text2(html_elements(doc, "h1[data-component='Typography']"))
  # Two title formats seen across the 7 elections: "Seat - State Election
  # YYYY" (fed2022/nsw2023/qld2024/sa2026/vic2022/wa2025) and "Seat Federal
  # Election YYYY Results" (fed2025, no dash at all) -- the fed2025 case was
  # missed on the first pass (0/150 seats parsed) because the regex required
  # " - ", silently dropping an entire election.
  h1 <- h1[grepl(" - .*Election |Election \\d{4} Results", h1)][1]
  if (is.na(h1) || is.null(h1)) return(list(seat = NA_character_, primary = NULL, tcp = NULL))
  seat_raw <- if (grepl(" - ", h1)) trimws(sub(" - .*$", "", h1))
              else trimws(sub("\\s+(Federal|NSW|QLD|SA|VIC|WA)\\s+Election.*$", "", h1))
  is_supp <- grepl("\\(Supplementary\\)", seat_raw)
  # Some seats carry TWO trailing parenthetical tags, e.g. "Hughes (*) (Key
  # Seat)" -- a single strip leaves "Hughes (*)" behind, so this repeats
  # until no trailing "(...)" remains.
  seat <- seat_raw
  repeat {
    stripped <- trimws(sub("\\s*\\([^)]*\\)\\s*$", "", seat))
    if (identical(stripped, seat)) break
    seat <- stripped
  }

  primary <- rbindlist(lapply(seq_along(html_elements(doc, "h4[class^='Candidate_candidateName']")), function(i) {
    party_el <- html_elements(doc, "span[class^='Candidate_longName']")
    pct_el   <- html_elements(doc, "span[class^='Candidate_votes__']")
    if (i > length(party_el) || i > length(pct_el)) return(NULL)
    data.table(party_name = trimws(html_text2(party_el[[i]])),
               pct = suppressWarnings(as.numeric(gsub("[^0-9.]", "", html_text2(pct_el[[i]])))))
  }), fill = TRUE)
  tcp_name  <- html_elements(doc, "h4[class^='AfterPreferenceCandidate_candidateName']")
  tcp_party <- html_elements(doc, "h3[class^='AfterPreferenceCandidate_candidateParty']")
  tcp_pct   <- html_elements(doc, "p[class^='AfterPreferenceCandidate_votePct']")
  tcp_cnt   <- html_elements(doc, "p[class^='AfterPreferenceCandidate_voteCount']")
  tcp <- NULL
  if (length(tcp_name) == 2 && length(tcp_pct) == 2) {
    # pct is rounded to 1dp and a real near-50/50 seat (fed2025 Bradfield:
    # Liberal 56,088 vs Independent 56,114, decided by 26 votes after a full
    # recount) rounds to an EXACT 50.0/50.0 tie -- ranking on pct then breaks
    # the tie on DOM order, not the actual result, and called the seat for
    # whichever candidate the page happened to list first (Liberal). Pete
    # caught this from the actual ABC page, which shows Boele (IND) 26 votes
    # ahead. Ranking on the raw vote count instead resolves it correctly.
    votes <- if (length(tcp_cnt) == 2) suppressWarnings(as.numeric(gsub("[^0-9]", "", html_text2(tcp_cnt)))) else c(NA_real_, NA_real_)
    tcp <- data.table(party_name = trimws(html_text2(tcp_party)),
                       pct = suppressWarnings(as.numeric(gsub("[^0-9.]", "", html_text2(tcp_pct)))),
                       votes = votes)
  }
  list(seat = seat, is_supp = is_supp, primary = primary, tcp = tcp)
}

abc_dirs <- list.dirs(file.path("external", "reference", "abc"), recursive = FALSE)
abc_primary_l <- list(); abc_tcp_l <- list()
for (d in abc_dirs) {
  pr <- basename(d)
  files <- list.files(d, pattern = "\\.html$", full.names = TRUE)
  for (f in files) {
    seat_slug <- sub("\\.html$", "", basename(f))
    html <- tryCatch(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"), error = function(e) NULL)
    if (is.null(html)) next
    p <- tryCatch(parse_abc_seat(html), error = function(e) NULL)
    if (is.null(p) || is.na(p$seat) || isTRUE(p$is_supp)) next  # supplementary/by-elections don't match any AEF7 seat
    if (!is.null(p$primary) && nrow(p$primary)) abc_primary_l[[paste(pr, seat_slug)]] <- p$primary[, `:=`(pair = pr, seat = p$seat)]
    if (!is.null(p$tcp) && nrow(p$tcp)) abc_tcp_l[[paste(pr, seat_slug)]] <- p$tcp[, `:=`(pair = pr, seat = p$seat)]
  }
  cat(sprintf("TT0 abc/%s: %d pages cached, %d parsed for TCP\n", pr, length(files), sum(grepl(paste0("^", pr, " "), names(abc_tcp_l)))))
}
abc_primary <- rbindlist(abc_primary_l, fill = TRUE)
abc_tcp <- rbindlist(abc_tcp_l, fill = TRUE)
if (nrow(abc_primary)) abc_primary[, cls := classify_party(party_name)]
if (nrow(abc_tcp)) abc_tcp[, cls := classify_party(party_name)]

n_scraped_pairs <- length(abc_dirs)
cat(sprintf("TT1 ABC scrape covers %d of %d AEF7 pairs so far (%s); the rest are NA below until it finishes\n",
            n_scraped_pairs, length(AEF7), paste(basename(abc_dirs), collapse = ", ")))

# ================= TCP TRUTH TABLE ========================================
# na.strings: see the note by this file's own fwrite() below -- the same
# blank-vs-NA round-trip trap applies on the way IN from the reference file.
ref <- fread(file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), na.strings = c("NA", ""), showProgress = FALSE)

itg_tcp <- rbindlist(lapply(AEF7, function(pr) {
  g <- list.files(OUT, pattern = sprintf("^backtest-%s-ourtcp-", pr), full.names = TRUE)
  if (!length(g)) return(NULL)
  x <- fread(g[which.max(file.mtime(g))], showProgress = FALSE)
  x[, .SD[which.max(freq)], by = seat][, .(pair = pr, seat, itg_tcp_f1 = f1, itg_tcp_f2 = f2,
                                             itg_tcp_pct = f1_tcp_pct, itg_tcp_freq = freq)]
}), fill = TRUE)

# ABC's TCP winner/runner-up. `seat` here is the real name parsed from each
# page's own <h1>, not a name reconstructed from the slug (see parse_abc_seat
# header note on the Narracan/Narre Warren collision that motivated this).
# Matched to our reference by exact name; anything that doesn't match is
# printed rather than silently dropped, since a naming mismatch (accents,
# "Mount" vs "Mt", a dash variant) needs a human decision, not a guess.
abc_tcp_named <- NULL
if (nrow(abc_tcp)) {
  # Rank on raw votes, not the rounded percentage -- see parse_abc_seat's
  # note on Bradfield, an exact 50.0/50.0 by rounding that a real 26-vote
  # margin decides. Per-ROW fallback to pct (not an all-or-nothing check
  # across the whole table) so one seat missing a vote count doesn't
  # degrade every other seat's ranking back to the tie-prone rounded pct.
  abc_tcp[, rank_key := ifelse(!is.na(votes), -votes, -pct * 1e6)]
  abc_tcp[, rk := frank(rank_key, ties.method = "first"), by = .(pair, seat)]
  wide <- dcast(abc_tcp[rk <= 2], pair + seat ~ rk, value.var = c("cls", "pct"))
  setnames(wide, c("cls_1","cls_2","pct_1"), c("abc_tcp_f1","abc_tcp_f2","abc_tcp_pct"))
  abc_tcp_named <- wide[, .(pair, seat, abc_tcp_f1, abc_tcp_f2, abc_tcp_pct)]
  unmatched <- fsetdiff(abc_tcp_named[, .(pair, seat)], ref[, .(pair, seat)])
  if (nrow(unmatched)) cat(sprintf("TT1! %d ABC seat name(s) not found in our reference (dropped): %s\n",
                                    nrow(unmatched), paste(paste(unmatched$pair, unmatched$seat), collapse = "; ")))
}

tt <- merge(ref[, .(pair, seat, official_f1 = f1, official_f2 = f2, official_f2cp = f2cp, official_fsrc = fsrc,
                     aef_tcp_f1, aef_tcp_pct, aef_tcp_freq = aef_tcp_scenario_freq)],
            itg_tcp, by = c("pair","seat"), all.x = TRUE)
if (!is.null(abc_tcp_named) && nrow(abc_tcp_named)) {
  tt <- merge(tt, abc_tcp_named, by = c("pair","seat"), all.x = TRUE)
} else {
  tt[, `:=`(abc_tcp_f1 = NA_character_, abc_tcp_f2 = NA_character_, abc_tcp_pct = NA_real_)]
}
# fwrite() writes NA_character_ as an empty field, and fread()'s default
# na.strings=c("NA") does NOT read an empty field back as NA -- a re-read of
# this file with default fread() will see "" (a real, non-missing string),
# not a missing value, so an "!is.na(abc_tcp_f1)" check downstream silently
# passes for every row. Write "NA" explicitly so a plain fread() round-trips.
fwrite(tt, file.path(OUT, "aef7-tcp-truth-table.csv"), na = "NA")
cat(sprintf("TT2 wrote output/aef7-tcp-truth-table.csv (%d rows); abc_tcp_f1 populated for %d seats\n",
            nrow(tt), sum(!is.na(tt$abc_tcp_f1))))

# ================= PRIMARY TRUTH TABLE ====================================
sd <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)
sd <- sd[pair %in% AEF7]
aef_fp <- fread(file.path(OUT, "aef7-fptrend.csv"), showProgress = FALSE)

pt <- merge(sd[, .(pair, seat, party, itg_primary = pred_share, official_primary = actual_share)],
            aef_fp[, .(pair, seat, party, aef_primary = aef_fp_pred)],
            by = c("pair","seat","party"), all.x = TRUE)

abc_primary_named <- NULL
if (nrow(abc_primary)) {
  abc_primary_named <- abc_primary[, .(abc_primary = sum(pct)), by = .(pair, seat, party = cls)]
}
if (!is.null(abc_primary_named) && nrow(abc_primary_named)) {
  pt <- merge(pt, abc_primary_named, by = c("pair","seat","party"), all.x = TRUE)
} else {
  pt[, abc_primary := NA_real_]
}
fwrite(pt, file.path(OUT, "aef7-primary-truth-table.csv"), na = "NA")
cat(sprintf("TT3 wrote output/aef7-primary-truth-table.csv (%d rows); abc_primary populated for %d rows\n",
            nrow(pt), sum(!is.na(pt$abc_primary))))

cat("TT4 done. Re-run this script once scripts/fetch_abc_seat_guides.R finishes all 7 pairs to fill in the rest.\n")
