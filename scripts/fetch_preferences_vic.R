# Fetch Victorian 2022 preference distributions from the VEC.
#
# Two pages per district, both server-rendered static HTML -- no JavaScript and
# no browser needed:
#   {slug}-district-results                          candidates, party, first prefs
#   {slug}-district-results/{slug}-results-distribution   every exclusion
#
# The distribution table gives each exclusion by name with the exact ballots
# transferred to every remaining candidate, which is candidate-level rather
# than party-class level: Legalise Cannabis, Animal Justice, Family First and
# each independent are excluded separately with their own destinations.
#
# 11 districts have no distribution page and that is correct, not a failure: a
# candidate reaching an absolute majority on first preferences ends the count.
# Narracan has neither page -- its 2022 election failed after a candidate died
# and the January 2023 supplementary was not contested by Labor.
#
# Writes to external/elections/, gitignored alongside the anchor clone. The VEC
# publishes no copyright or terms statement and vec.vic.gov.au/copyright is a
# dead link, so none of it is committed -- see election_data_path().
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fetch_preferences_vic.R"'

suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

BASE <- paste0("https://www.vec.vic.gov.au/results/state-election-results/",
               "2022-state-election-results/results-by-district")
UA   <- "auspol-research/0.1 (+https://github.com/peteowen1/auspol)"
OUT   <- election_data_path()                     # external/elections
CACHE <- file.path(OUT, "cache", "vec-2022-vic")  # raw HTML, deletable
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

seats <- load_seats(2022, "vic")$seat
slug <- tolower(gsub(" +", "-", gsub("['.]", "", seats)))
cat(sprintf("districts to fetch: %d\n", length(slug)))

# A size floor is NOT a completeness check. Carrum arrived truncated at exactly
# 65536 bytes -- a clean 64 KB boundary -- sailed past a `> 2000` guard, then
# parsed to zero candidates and silently dropped the seat from the dataset.
# Require the closing tag instead, and retry rather than accept a partial file.
complete_html <- function(f) {
  if (!file.exists(f) || file.size(f) < 2000) return(FALSE)
  tail_txt <- suppressWarnings(
    readLines(f, warn = FALSE, n = -1L, encoding = "UTF-8"))
  any(grepl("</html>", utils::tail(tail_txt, 20), ignore.case = TRUE))
}

fetch <- function(url, dest, tries = 3L) {
  if (complete_html(dest)) return(TRUE)
  for (attempt in seq_len(tries)) {
    tryCatch({
      utils::download.file(url, dest, quiet = TRUE, mode = "wb",
                           headers = c("User-Agent" = UA))
    }, error = function(e) NULL, warning = function(w) NULL)
    Sys.sleep(0.3)
    if (complete_html(dest)) return(TRUE)
  }
  FALSE
}

# (?s) so `.` matches newlines: the VEC wraps cells across lines, and without
# it every one of these patterns matches nothing and the parse silently yields
# zero rows rather than erroring.
cells <- function(row) {
  m <- regmatches(row, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", row, perl = TRUE))[[1]]
  trimws(gsub("&nbsp;", " ", gsub("<[^>]+>", "", m)))
}
num <- function(x) suppressWarnings(as.numeric(gsub("[^0-9-]", "", x)))

party_rows <- list(); tx_rows <- list()
no_dist <- character(0); missing <- character(0)

for (i in seq_along(slug)) {
  s <- slug[i]
  fr <- file.path(CACHE, paste0(s, "-results.html"))
  fd <- file.path(CACHE, paste0(s, "-dist.html"))
  got_r <- fetch(sprintf("%s/%s-district-results", BASE, s), fr)
  got_d <- fetch(sprintf("%s/%s-district-results/%s-results-distribution",
                         BASE, s, s), fd)
  if (!got_r) { missing <- c(missing, seats[i]); next }

  html <- paste(readLines(fr, warn = FALSE), collapse = "\n")
  tabs <- regmatches(html, gregexpr("(?s)<table.*?</table>", html, perl = TRUE))[[1]]
  for (t in tabs) {
    rows <- regmatches(t, gregexpr("(?s)<tr.*?</tr>", t, perl = TRUE))[[1]]
    if (length(rows) < 2) next
    hdr <- tolower(paste(cells(rows[1]), collapse = " "))
    if (!grepl("candidate", hdr) || !grepl("1st pref|first pref", hdr)) next
    for (r in rows[-1]) {
      c4 <- cells(r)
      if (length(c4) < 3 || !nzchar(c4[1])) next
      v <- num(c4[3]); if (is.na(v)) next
      party_rows[[length(party_rows) + 1L]] <- data.table(
        seat = seats[i], cand = c4[1],
        party = classify_party(c4[2]),
        # First preferences are kept, not just the party label: projecting a
        # seat needs its 2022 vote by class, and rebuilding that from anywhere
        # else means a second source that can disagree with this one.
        fp_votes = v)
    }
    break
  }

  if (!got_d) { no_dist <- c(no_dist, seats[i]); next }
  h2 <- paste(readLines(fd, warn = FALSE), collapse = "\n")
  tabs2 <- regmatches(h2, gregexpr("(?s)<table.*?</table>", h2, perl = TRUE))[[1]]
  tab <- tabs2[grepl("first preference votes", tolower(tabs2))][1]
  if (is.na(tab)) { no_dist <- c(no_dist, seats[i]); next }
  rows <- regmatches(tab, gregexpr("(?s)<tr.*?</tr>", tab, perl = TRUE))[[1]]
  hdr <- cells(rows[1])
  cand <- hdr[-1]; cand <- cand[nzchar(cand) & toupper(cand) != "TOTAL"]
  rnd <- 0L
  for (r in rows[-1]) {
    cs <- cells(r)
    if (!length(cs)) next
    m <- regmatches(cs[1], regexec(
      "Transfer of ([0-9,]+) ballot papers of (.+?)[[:space:]]*[(]([0-9]+)(st|nd|rd|th) excluded",
      cs[1]))[[1]]
    if (length(m) < 4) next
    rnd <- as.integer(m[4]); pot <- num(m[2]); frm <- trimws(m[3])
    vals <- cs[2:(1 + length(cand))]
    got <- 0
    for (j in seq_along(cand)) {
      if (identical(cand[j], frm)) next
      v <- num(vals[j]); if (is.na(v) || v <= 0) next
      tx_rows[[length(tx_rows) + 1L]] <- data.table(
        election = "vic2022", seat = seats[i], round = rnd,
        from_cand = frm, to_cand = cand[j], votes = v)
      got <- got + v
    }
    # Every exclusion must reconcile against the excluded candidate's pile.
    # This is the check that caught a bad row in the SA data; it has never
    # failed on the VEC's tables, which is why the parse can be trusted.
    if (!is.na(pot) && abs(got - pot) > 0.5) {
      warning(sprintf("%s round %d: transferred %g against a pile of %g",
                      seats[i], rnd, got, pot), call. = FALSE)
    }
  }
}

pm <- rbindlist(party_rows)
tx <- rbindlist(tx_rows)
stopifnot(nrow(pm) > 0, nrow(tx) > 0)

look <- setNames(pm$party, paste(pm$seat, pm$cand))
tx[, from := look[paste(seat, from_cand)]]
tx[, to   := look[paste(seat, to_cand)]]
bad <- tx[is.na(from) | is.na(to)]
tx <- tx[!is.na(from) & !is.na(to)]
# PER-ROUND CLASS MULTIPLICITY, against docs/plans/prereg-survivor-
# multiplicity.md. `to_n` is how many CANDIDATES of that class received
# votes in this round. Our classes are buckets -- OTH_RIGHT holds every
# minor-right party and IND every independent -- so a seat with three
# minor-right candidates gives OTH_RIGHT three candidates' worth of
# preferences while keying identically to a seat with one. Counted HERE,
# before the aggregation below destroys the candidate rows.
tx[, to_n := data.table::uniqueN(to_cand),
   by = c("election","seat","round","to")]
tx <- tx[, list(votes = sum(votes), to_n = to_n[1]),
         by = c("election","seat","round","from","to")]

cat(sprintf("\nseats with a distribution : %d\nexclusion events          : %d\ntransfer rows             : %d\n",
            uniqueN(tx$seat), uniqueN(tx[, list(seat, round)]), nrow(tx)))
cat(sprintf("won on first preferences, no distribution held: %d\n", length(no_dist)))
if (length(missing)) cat("no results page at all:", paste(missing, collapse = ", "), "\n")
if (nrow(bad)) cat(sprintf("!! %d transfer rows dropped for an unmatched candidate\n", nrow(bad)))

f <- file.path(OUT, "vec-2022-vic-transfers.csv")
fwrite(tx, f); cat("wrote", f, "\n")
record_fetch("vec", "vec-2022-vic-transfers.csv", BASE, nrow(tx))
fwrite(pm, file.path(OUT, "vec-2022-vic-candidates.csv"))

fp <- pm[, list(votes = sum(fp_votes)), by = c("seat", "party")]
fwrite(fp, file.path(OUT, "vec-2022-vic-firstprefs.csv"))
record_fetch("vec", "vec-2022-vic-firstprefs.csv", BASE, nrow(fp))
cat(sprintf("first preferences: %d seat-party rows across %d seats
",
            nrow(fp), uniqueN(fp$seat)))
