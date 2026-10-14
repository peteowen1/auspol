# build_archived_results.R
# Parse AE's archived per-seat results (external/aus-polling-analyser/analysis/
# Archived/elections/results_<year><state>.csv) into tidy CSVs under
# external/elections/archive/, then cross-check against our official files.
#
# Archive format: title line ("2022 Federal Election"), then repeated blocks:
#   Seat,<name> / fp / <candidate,party,votes,pct,swing>... / tcp / <rows>
# Check codes AV1..AV6 (unique prefix "AV").
suppressPackageStartupMessages(library(data.table))
if (!file.exists("R/parties.R")) stop("run from the repo root")
source("R/parties.R")

src_dir <- "external/aus-polling-analyser/analysis/Archived/elections"
out_dir <- "external/elections/archive"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
files <- sort(list.files(src_dir, pattern = "^results_[0-9]{4}[a-z]+[.]csv$", full.names = TRUE))
cat(sprintf("AV1 archive files found: %d (expected 74)\n", length(files)))

row_re <- "^(.*),([^,]*),([0-9]+),(-?[0-9.]+),(-?[0-9.]+|None|NA|nan|)$"

parse_one <- function(f) {
  id <- sub("^results_([0-9]{4}[a-z]+)[.]csv$", "\\1", basename(f))
  ln <- trimws(readLines(f, warn = FALSE, encoding = "UTF-8"), which = "right")
  ln <- ln[nzchar(ln)]
  seat <- NA_character_; blk <- NA_character_; title <- NA_character_
  rows <- vector("list", length(ln)); bad <- character(); k <- 0L
  for (l in ln) {
    if (grepl("^[0-9]{4} .*Election", l) && is.na(title)) { title <- l; next }
    if (grepl("^Seat,", l)) { seat <- sub("^Seat,", "", l); blk <- NA_character_; next }
    if (l %in% c("fp", "tcp")) { blk <- l; next }
    m <- regmatches(l, regexec(row_re, l))[[1]]
    if (length(m) == 6 && !is.na(seat) && !is.na(blk)) {
      k <- k + 1L
      rows[[k]] <- list(block = blk, seat = seat, candidate = m[2], party_raw = m[3],
                        votes = as.integer(m[4]), pct = as.numeric(m[5]),
                        swing = suppressWarnings(as.numeric(m[6])))
    } else bad <- c(bad, l)
  }
  dt <- rbindlist(rows[seq_len(k)])
  if (nrow(dt)) {
    dt[, election := sub("^([0-9]{4})([a-z]+)$", "\\2\\1", id)]
    dt[, party := classify_party(name = party_raw)]
  }
  list(id = id, dt = dt, bad = bad, title = title)
}

res <- lapply(files, parse_one)
names(res) <- vapply(res, `[[`, "", "id")

summ <- rbindlist(lapply(res, function(r) {
  d <- r$dt
  data.table(election = r$id, fp_rows = sum(d$block == "fp"), tcp_rows = sum(d$block == "tcp"),
             seats = uniqueN(d$seat), seats_tcp = uniqueN(d[block == "tcp"]$seat),
             fp_votes = sum(d[block == "fp"]$votes), unparsed = length(r$bad))
}))
cat("\nAV2 Parsed archive summary (rows, seats, first-preference vote totals per election)\n")
print(summ, nrows = 100)
cat(sprintf("\nAV2 TOTAL: %d elections, %d fp rows, %d tcp rows, %s fp votes, %d unparsed lines\n",
            nrow(summ), sum(summ$fp_rows), sum(summ$tcp_rows),
            format(sum(summ$fp_votes), big.mark = ","), sum(summ$unparsed)))
unp <- rbindlist(lapply(res, function(r) if (length(r$bad)) data.table(election = r$id, line = r$bad)))
if (!is.null(unp) && nrow(unp)) { cat("AV3 UNPARSED LINES:\n"); print(head(unp, 30)) } else cat("AV3 no unparsed lines\n")
empty <- summ[fp_rows == 0]
if (nrow(empty)) cat("AV3 FILES WITH NO FIRST PREFERENCES:", paste(empty$election, collapse = ", "), "\n")

# Write per-election files -------------------------------------------------
for (r in res) {
  d <- r$dt; if (!nrow(d)) next
  cols <- c("seat", "party", "votes", "election", "candidate", "party_raw", "pct", "swing")
  fwrite(d[block == "fp", ..cols], file.path(out_dir, paste0(r$id, "-firstprefs.csv")))
  if (any(d$block == "tcp"))
    fwrite(d[block == "tcp", .(election, seat, party, votes, candidate, party_raw, pct, swing)],
           file.path(out_dir, paste0(r$id, "-tcp.csv")))
}
cat(sprintf("AV4 wrote %d firstprefs and %d tcp files to %s\n",
            length(list.files(out_dir, "-firstprefs[.]csv$")), length(list.files(out_dir, "-tcp[.]csv$")), out_dir))
arch <- rbindlist(lapply(res, `[[`, "dt"))
cov <- arch[, lapply(.SD, function(x) mean(!is.na(x) & x != "")), .SDcols = c("seat", "candidate", "party_raw", "votes", "pct", "party")]
cat("AV4 column coverage (share non-empty):\n"); print(cov)
cat("AV4 party class counts:\n"); print(arch[block == "fp", .N, by = party][order(-N)])

# Cross-check ---------------------------------------------------------------
norm <- function(x) gsub("[^a-z0-9]", "", tolower(x))
ed <- "external/elections"
off_fp <- list()
ff <- list.files(ed, pattern = "^[a-z]+-[0-9]{4}-[a-z]+-firstprefs[.]csv$", full.names = TRUE)
for (f in ff) {
  m <- regmatches(basename(f), regexec("^[a-z]+-([0-9]{4})-([a-z]+)-firstprefs", basename(f)))[[1]]
  d <- fread(f); d[, election := paste0(m[3], m[2])]; off_fp[[f]] <- d[, .(election, seat, party, votes)]
}
fed <- fread(file.path(ed, "aec-fed-firstprefs.csv")); off_fp[["fed"]] <- fed[, .(election, seat, party, votes)]
off_fp <- rbindlist(off_fp)
cat("\nAV5 official first-pref elections available:", paste(sort(unique(off_fp$election)), collapse = " "), "\n")

rd <- function(f) fread(file.path(ed, f))
w <- list(rd("aec-fed-winners.csv")[, .(election, seat, winner)], rd("nswec-nsw-winners.csv")[, .(election, seat, winner)],
          rd("ecq-qld-winners.csv")[, .(election, seat, winner)], rd("ecsa-sa-winners.csv")[, .(election, seat, winner)],
          rd("waec-wa-winners.csv")[, .(election, seat, winner)])
for (f in list.files(ed, "^vec-[0-9]{4}-vic-winners[.]csv$")) {
  y <- sub("^vec-([0-9]{4}).*", "\\1", f); x <- rd(f); x[, election := paste0("vic", y)]
  w[[length(w) + 1]] <- x[, .(election, seat, winner)]
}
for (f in list.files(ed, "^wikipedia-[0-9]{4}-sa-winners[.]csv$")) {
  y <- sub("^wikipedia-([0-9]{4}).*", "\\1", f); x <- rd(f)
  if (!"election" %in% names(x)) x[, election := paste0("sa", y)]
  w[[length(w) + 1]] <- x[, .(election, seat, winner)]
}
off_w <- unique(rbindlist(w))
off_tcp <- fread(file.path(ed, "aec-fed-tcp.csv"))

fp_a <- arch[block == "fp"]; tcp_a <- arch[block == "tcp"]
win_a <- tcp_a[order(-votes), .SD[1], by = .(election, seat)][, .(election, seat, a_winner = party)]
fp_win <- fp_a[order(-votes), .SD[1], by = .(election, seat)][, .(election, seat, a_winner_fp = party)]
win_a <- merge(win_a, fp_win, by = c("election", "seat"), all = TRUE)
win_a[is.na(a_winner), a_winner := a_winner_fp]

els <- sort(intersect(unique(off_fp$election), unique(fp_a$election)))
tab <- list(); mism <- list(); wm <- list()
for (e in els) {
  o <- off_fp[election == e, .(votes = sum(votes)), by = .(seat, party)]; o[, k := norm(seat)]
  a <- fp_a[election == e, .(votes = sum(votes)), by = .(seat, party)]; a[, k := norm(seat)]
  seats_o <- unique(o$k); seats_a <- unique(a$k); both <- intersect(seats_o, seats_a)
  j <- merge(o[k %in% both, .(k, party, o = votes)], a[k %in% both, .(k, party, a = votes)], by = c("k", "party"), all = TRUE)
  j[is.na(o), o := 0L]; j[is.na(a), a := 0L]; j[, d := abs(o - a)]
  per <- j[, .(maxd = max(d), tot_o = sum(o), tot_a = sum(a)), by = k]
  per[, tot_d := abs(tot_o - tot_a)]
  ow <- off_w[election == e, .(k = norm(seat), o_winner = winner)]
  aw <- win_a[election == e, .(k = norm(seat), a_winner)]
  jw <- merge(ow, aw, by = "k"); jw <- jw[k %in% both]
  wmm <- jw[o_winner != a_winner]
  tcp_note <- NA_integer_
  if (grepl("^fed", e)) {
    ot <- off_tcp[election == e, .(votes = sum(votes)), by = .(seat, party)][, k := norm(seat)]
    at <- tcp_a[election == e, .(votes = sum(votes)), by = .(seat, party)][, k := norm(seat)]
    jt <- merge(ot, at, by = c("k", "party"), all = FALSE, suffixes = c("_o", "_a"))
    tcp_note <- sum(jt$votes_o != jt$votes_a)
  }
  tab[[e]] <- data.table(election = e, official_seats = length(seats_o), archive_seats = length(seats_a),
                         seats_compared = length(both), seats_exact = sum(per$maxd == 0),
                         max_vote_diff = if (nrow(j)) max(j$d) else NA_integer_,
                         winners_compared = nrow(jw), winner_mismatches = nrow(wmm), tcp_cell_diffs = tcp_note)
  if (nrow(per[maxd > 0])) mism[[e]] <- merge(per[maxd > 0], unique(a[, .(k, seat)]), by = "k")[
    , .(election = e, seat, max_vote_diff = maxd, total_vote_diff = tot_d)]
  if (nrow(wmm)) wm[[e]] <- merge(wmm, unique(a[, .(k, seat)]), by = "k")[, .(election = e, seat, official = o_winner, archive = a_winner)]
}
tab <- rbindlist(tab); mism <- rbindlist(mism); wm <- rbindlist(wm)
cat("\nAV5 Cross-check vs official files\n"); print(tab, nrows = 100)
cat(sprintf("AV5 headline: %d elections compared, %d seats compared, %d exact, %d winner mismatches of %d\n",
            nrow(tab), sum(tab$seats_compared), sum(tab$seats_exact), sum(tab$winner_mismatches), sum(tab$winners_compared)))

# Write the review doc ----------------------------------------------------------
md <- c("# Archived results cross-check (2026-10-13)", "",
        "Generated by `scripts/build_archived_results.R`. Source: AE's archived per-seat results, parsed to `external/elections/archive/`.",
        "Compared with our official files, per election: seat-level first-preference votes summed to our party classes, and the winner (archive = top two-candidate-preferred candidate's class).", "",
        "Columns: compared = seats found in both; exact = seats where every class's votes are identical; max vote diff = largest single seat-and-class difference in votes (lower is better); winner mismatches = seats where the winner's class differs (lower is better); tcp cell diffs = federal seat-party two-candidate-preferred vote cells that differ (lower is better).", "",
        sprintf("Headline: %d elections, %d seats compared, %d match exactly, %d winner mismatches of %d winners compared.", nrow(tab), sum(tab$seats_compared), sum(tab$seats_exact), sum(tab$winner_mismatches), sum(tab$winners_compared)), "",
        "| election | official seats | archive seats | compared | exact | max vote diff | winners compared | winner mismatches | tcp cell diffs |",
        "|---|---|---|---|---|---|---|---|---|",
        tab[, sprintf("| %s | %d | %d | %d | %d | %s | %d | %d | %s |", election, official_seats, archive_seats, seats_compared, seats_exact,
                      format(max_vote_diff, big.mark = ","), winners_compared, winner_mismatches, ifelse(is.na(tcp_cell_diffs), "n/a", tcp_cell_diffs))],
        "", "Archive elections with no official file here (not cross-checked): ",
        paste(setdiff(sort(unique(fp_a$election)), els), collapse = ", "), "",
        "## Winner mismatches", "",
        if (nrow(wm)) c("| election | seat | official | archive |", "|---|---|---|---|", wm[, sprintf("| %s | %s | %s | %s |", election, seat, official, archive)]) else "None.",
        "", "## Mismatching seats (any class differs; top 25 per election by max vote diff)", "",
        "| election | seat | max vote diff | seat total diff |", "|---|---|---|---|",
        if (nrow(mism)) mism[order(election, -max_vote_diff), head(.SD, 25), by = election][, sprintf("| %s | %s | %d | %d |", election, seat, max_vote_diff, total_vote_diff)] else character())
if (nrow(mism)) md <- c(md, "", "Mismatching seats per election (full count):", "", mism[, .N, by = election][, sprintf("- %s: %d", election, N)])
dir.create("docs/reviews", showWarnings = FALSE)
writeLines(md, "docs/reviews/archived-results-check-2026-10-13.md")
cat("AV6 wrote docs/reviews/archived-results-check-2026-10-13.md\n")
