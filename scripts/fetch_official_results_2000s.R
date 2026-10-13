# Official seat-level results for 2000s elections where our only copy was the
# AEF archive (external/elections/archive/, AE Forecasts: a cross-check and a
# last-resort filler, never the primary source).
#
# Source rule (docs/plans/coverage-program-2026-10-13.md, "Naming and source
# rule"): results come from the commission. Sections, one per commission:
#
#   vec   Victoria 2006  VEC blob archive, result pages already on disk
#                        (external/reference/vec/raw/2006/, fetched by
#                        scripts/fetch_state_distributions.R, never refetched here)
#         Victoria 2002  VEC "Report to Parliament" PDF: district two-party
#                        preferred only (no candidate first preferences in it)
#   nswec NSW 2003/2007  NO usable source: pastvtr.elections.nsw.gov.au has only
#                        2011+, the NSW Parliament 1856-2007 database and the
#                        Parliamentary Library PDFs sit behind a Cloudflare
#                        challenge. Recorded, not worked around.
#   ecsa  SA 2002/2006   Jaensch, "History of South Australian elections 1857-2006:
#                        House of Assembly", published by ECSA (PDF, parsed text)
#   ecq   Qld 2001       ECQ "2001 Statistical Returns" PDF (candidate first
#                        preferences by party code, final two-candidate counts)
#   waec  WA 2001/2005/2008, ecq 2004-2015, aec 2001/2004, nswec 2011: official
#                        files already exist in external/elections/ -> skipped.
#   xcheck  every new election against external/elections/archive/.
#
# Run from the repo root, one section or all:
#   powershell.exe -Command 'Rscript "scripts/fetch_official_results_2000s.R"'
#   powershell.exe -Command 'Rscript "scripts/fetch_official_results_2000s.R" sa'
#
# Check-code prefix: "KQ" (KQ1x Vic, KQ2x NSW, KQ3x SA, KQ4x Qld, KQ5x cross-check).
# Output schema = the commission's existing files: <c>-<year>-<st>-firstprefs.csv
# (seat, party, votes; party = classify_party() class) and -tcp.csv (seat, party,
# votes). A "-detail" file beside each keeps every field the source has.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
SECTIONS <- if (length(args)) args else c("vec", "nswec", "ecsa", "ecq", "xcheck")
OUT <- election_data_path()
UA  <- "auspol-research-fetch/1.0 (Australian election forecast research; polite 1 request/second)"

strip_tags <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("&nbsp;", " ", gsub("<[^>]+>", " ", x))))
tables_of  <- function(h) regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
rows_of    <- function(t) regmatches(t, gregexpr("(?s)<tr.*?</tr>", t, perl = TRUE))[[1]]
cells_of   <- function(r) strip_tags(regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]])
num        <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", x)))
read_all   <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# A download counts as complete only if it ends the way its type ends.
complete_ok <- function(dest, kind) {
  if (!file.exists(dest) || file.info(dest)$size < 200) return(FALSE)
  sz <- file.info(dest)$size
  tl <- readBin(dest, "raw", n = sz)[max(1, sz - 2000):sz]
  tail_txt <- rawToChar(tl[tl != as.raw(0)])
  switch(kind, pdf = grepl("%%EOF", tail_txt, fixed = TRUE, useBytes = TRUE),
         html = grepl("</html>", tail_txt, ignore.case = TRUE, useBytes = TRUE), TRUE)
}
# One request per second; never refetch what is on disk; a block is final.
grab <- function(url, dest, kind = "pdf") {
  if (complete_ok(dest, kind)) return(TRUE)
  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
  h <- curl::new_handle(useragent = UA, timeout = 120, followlocation = TRUE)
  r <- tryCatch(curl::curl_fetch_memory(url, h), error = function(e) NULL)
  Sys.sleep(1)
  if (!is.null(r) && r$status_code == 200L) {
    writeBin(r$content, dest)
    if (complete_ok(dest, kind)) return(TRUE)
    unlink(dest)
  }
  FALSE
}
pdf_text_raw <- function(pdf, txt) {      # pdftotext -raw keeps one candidate per line
  if (!file.exists(txt)) system2("pdftotext", c("-raw", shQuote(pdf), shQuote(txt)))
  readLines(txt, warn = FALSE, encoding = "latin1")
}
cls <- function(name, code) classify_party(name, code)
to_votes <- function(x) as.numeric(gsub("[ ,]", "", x))

# =============================================================================
# 1. VICTORIA  (VEC)
# =============================================================================
run_vec <- function() {
  RAW <- file.path("external", "reference", "vec", "raw", "2006")
  files <- list.files(RAW, pattern = "^state2006result.*district[.]html$", full.names = TRUE)
  cat(sprintf("KQ10 VEC 2006: %d result pages on disk (expect 88)\n", length(files)))
  stopifnot(length(files) == 88L)
  one <- function(f) {
    h <- read_all(f)
    stopifnot(grepl("</html>", h, fixed = TRUE))                       # complete page
    seat <- trimws(sub(" District.*$", "", strip_tags(regmatches(h, regexpr("(?s)<h2[^>]*>.*?</h2>", h, perl = TRUE)))))
    note <- regmatches(h, regexpr("(?s)Note:.*?</td>", h, perl = TRUE))
    lut <- character(0)
    if (length(note)) {
      txt <- sub(" (Recheck|Primary|Recount|Preliminary) first preference votes.*$", "", sub("^Note: *", "", strip_tags(note)))
      parts <- strsplit(txt, ", *(?=[^,=]+ = )", perl = TRUE)[[1]]
      has <- grepl(" = ", parts, fixed = TRUE)
      lut <- stats::setNames(trimws(sub("^[^=]+ = ", "", parts[has])), trimws(sub(" = .*$", "", parts[has])))
    }
    tb <- tables_of(h)
    get <- function(title) {
      t <- Filter(function(t) grepl(sprintf('title="%s"', title), t, fixed = TRUE), tb)
      if (!length(t)) return(NULL)
      Filter(function(z) length(z) >= 4L && !identical(z[1], "Candidate"), lapply(rows_of(t[[1]]), cells_of))
    }
    fp <- get("First preference votes")
    code <- vapply(fp, `[`, "", 2)
    full <- ifelse(nzchar(code) & code %in% names(lut), unname(lut[code]), code)
    cand <- data.table(seat = seat, candidate = vapply(fp, `[`, "", 1), party_code = code,
                       party_name = full, votes = num(vapply(fp, `[`, "", 3)))
    # the Vic 2006 result page carries the declared 'Party' as a short label
    cand[, party := cls(party_name, party_code)]
    sel <- function(rows, col) if (is.null(rows)) NULL else
      data.table(seat = seat, candidate = vapply(rows, `[`, "", 1), party_code = vapply(rows, `[`, "", 2),
                 votes = num(vapply(rows, `[`, "", 3)), source = col)
    aft <- sel(get("Results after distribution of preferences"), "after_distribution")
    tcp <- sel(get("Two candidate preferred vote"), "tcp_first_count")
    sm <- cells_of(regmatches(h, regexpr("(?s)Formal Votes:.*?Informal", h, perl = TRUE)))
    formal <- num(sub("^.*Formal Votes: *([0-9]+).*$", "\\1", strip_tags(h)))
    list(cand = cand, aft = aft, tcp = tcp, formal = formal)
  }
  res <- lapply(files, one)
  cand <- rbindlist(lapply(res, `[[`, "cand"))
  if (anyNA(cand$party) || anyNA(cand$votes)) stop("KQ11 NA party class or votes")
  formal <- vapply(res, `[[`, 0, "formal")
  chk <- cand[, .(sum = sum(votes)), by = seat]
  chk[, formal := formal[match(seat, vapply(res, function(r) r$cand$seat[1], ""))]]
  cat(sprintf("KQ11 VEC 2006: %d seats, candidates summing to the page's Formal Votes figure: %d of %d\n",
              nrow(chk), sum(chk$sum == chk$formal), nrow(chk)))
  stopifnot(nrow(chk) == 88L)
  fp <- cand[, .(votes = sum(votes)), by = .(seat, party)][order(seat, party)]
  fwrite(fp, file.path(OUT, "vec-2006-vic-firstprefs.csv"))
  # every source field, per candidate (the earlier vec-2006-vic-candidates.csv has the same facts)
  fwrite(cand[, .(seat, candidate, party_code, party_name, party_class = party, votes)],
         file.path(OUT, "vec-2006-vic-firstprefs-detail.csv"))
  # two-candidate-preferred: the final two after the distribution (rechecked); the
  # published 'two candidate preferred vote' table is a first-count figure and is kept in the detail
  aft <- rbindlist(lapply(res, `[[`, "aft")); tcp <- rbindlist(lapply(res, `[[`, "tcp"), fill = TRUE)
  if (!nrow(aft)) stop("KQ12 no after-distribution tables")
  seats_no_aft <- setdiff(cand$seat |> unique(), aft$seat)
  cat(sprintf("KQ12 seats with an after-distribution table: %d of 88; with a TCP table: %d\n",
              uniqueN(aft$seat), uniqueN(tcp$seat)))
  allx <- rbind(aft, tcp, fill = TRUE)
  allx[cand, on = .(seat, candidate), `:=`(party = i.party, party_name = i.party_name)]
  if (anyNA(allx$party)) stop("KQ12 TCP candidate not in the first-preference table")
  fwrite(allx[, .(seat, source, candidate, party_code, party_name, party_class = party, votes)],
         file.path(OUT, "vec-2006-vic-tcp-detail.csv"))
  # The 'after distribution' table lists every candidate still standing when a majority was
  # reached (3-4 rows in 5 seats), not the final two, so the published 'Two candidate preferred
  # vote' table (first-count figures; rechecked districts differ slightly) is the two-candidate
  # record. One row per finalist, not per class: Rodney is a Liberal v National final.
  # Where the after-distribution table is exactly two candidates it is the FINAL (rechecked)
  # two-candidate count and replaces the first-count figure (Ferntree Gully: the first-count
  # table has Labor ahead by 30, the rechecked final has the Liberal ahead by 27).
  naft <- allx[source == "after_distribution", .N, by = seat]
  use_aft <- naft[N == 2L, seat]
  tcpf <- rbind(allx[source == "after_distribution" & seat %in% use_aft, .(seat, party, votes, basis = "final_after_distribution")],
                allx[source == "tcp_first_count" & !(seat %in% use_aft), .(seat, party, votes, basis = "tcp_table_first_count")])
  cat(sprintf("KQ12 TCP basis: %d seats final after-distribution count, %d seats first-count TCP table\n",
              length(use_aft), 88L - length(use_aft)))
  fwrite(tcpf[, .(seat, party, votes, basis)][order(seat, -votes)], file.path(OUT, "vec-2006-vic-tcp-basis.csv"))
  tcpf <- tcpf[, .(seat, party, votes)][order(seat, -votes)]
  cat(sprintf("KQ12 TCP rows %d over %d seats (%d seats are single-class finals)
", nrow(tcpf), uniqueN(tcpf$seat),
              sum(tcpf[, .(n = uniqueN(party)), by = seat]$n == 1L)))
  stopifnot(uniqueN(tcpf$seat) == 88L, all(tcpf[, .N, by = seat]$N == 2L))
  fwrite(tcpf, file.path(OUT, "vec-2006-vic-tcp.csv"))

  # ---- Victoria 2002: district two-party-preferred from the VEC report ----------
  RAW2 <- file.path("external", "reference", "vec", "raw", "2002")
  pdf <- file.path(RAW2, "vec-2002-report-to-parliament.pdf")
  ok <- grab("https://www.vec.vic.gov.au/-/media/ed23702c5dab40338a19978fadc93470.pdf", pdf, "pdf")
  if (!ok) { cat("KQ13 VEC 2002 report not available\n"); return(invisible()) }
  tx <- pdf_text_raw(pdf, file.path(RAW2, "vec-2002-report.txt"))
  st <- grep("Figure 30 . Legislative Assembly: two-party-preferred vote at the 2002", tx)[1]
  rows <- tx[st:(st + 140)]
  k <- grep("^District Labor votes % Non-Labor", rows)
  if (length(k)) rows <- rows[seq_len(k[1] - 1L)]
  m <- regmatches(rows, regexec("^([A-Z][A-Za-z' .-]+?) ([0-9]{2},[0-9]{3}) ([0-9.]+)% ([0-9]{1,2},[0-9]{3}) ([0-9.]+)% ([0-9.]+) to (Labor|Liberal)", rows))
  m <- Filter(length, m)
  d <- data.table(seat = vapply(m, `[`, "", 2), alp = to_votes(vapply(m, `[`, "", 3)),
                  lnp = to_votes(vapply(m, `[`, "", 5)))
  d <- unique(d, by = "seat")[seq_len(min(.N, 88L))]
  cat(sprintf("KQ13 VEC 2002 two-party-preferred rows parsed: %d of 88 districts\n", nrow(d)))
  if (nrow(d) != 88L) cat("KQ13 WARNING: not all 88 districts parsed:", paste(setdiff(
    c(), d$seat), collapse = ""), "\n")
  fwrite(rbind(d[, .(seat, party = "ALP", votes = alp)], d[, .(seat, party = "LNP", votes = lnp)])[order(seat, party)],
         file.path(OUT, "vec-2002-vic-tcp.csv"))
  invisible()
}

# =============================================================================
# 2. NEW SOUTH WALES 2003 / 2007  (NSWEC)  -- no scriptable official source
# =============================================================================
run_nswec <- function() {
  cat("KQ20 NSW 2003/2007: no scriptable official source (see docs/reviews/official-results-2000s-2026-10-13.md)\n")
  cat("KQ20   pastvtr.elections.nsw.gov.au/SGE2003|SGE2007 -> 404; the NSWEC page 'NSW State election results 1856 - 2007' links to\n")
  cat("KQ20   the Parliament database, whose page is gated by a Cloudflare challenge and whose PDFs return 403 to a scripted client.\n")
  invisible()
}

# =============================================================================
# 3. SOUTH AUSTRALIA 2002 / 2006  (ECSA, Jaensch History vol. 1)
# =============================================================================
run_ecsa <- function() {
  RAW <- file.path("external", "reference", "ecsa", "raw", "2006")
  pdf <- file.path(RAW, "jaensch-1857-2006-house-of-assembly-v1.pdf")
  ok <- grab("https://www.ecsa.sa.gov.au/component/edocman/1857-2006-house-of-assembly-v1-by-dean-jaensch/download?Itemid=0", pdf, "pdf")
  stopifnot(ok)
  tx <- pdf_text_raw(pdf, file.path(RAW, "jaensch-house-of-assembly.txt"))
  starts <- grep("^ELECTORATE RESULTS", tx)
  cat("KQ30 ELECTORATE RESULTS headings:", paste(sub("^ELECTORATE RESULTS .{1,3}", "", tx[starts]), collapse = " | "), "\n")
  parse_block <- function(start_pat, year, n_seats = 47L) {
    s <- grep(start_pat, tx)
    s <- s[length(s)]
    ends <- starts[starts > s]
    # the section runs until the next election section's first heading or the summary tables
    nxt <- grep("^(THE )?[0-9]{4} (GENERAL )?ELECTION|^SUMMARY|^APPENDIX", tx)
    nxt <- nxt[nxt > s + 50]
    e <- if (length(nxt)) min(nxt, s + 2500) else s + 2500
    x <- trimws(tx[s:e]); x <- x[nzchar(x)]
    stat_re <- "^[0-9]{1,3}( [0-9]{3})* [0-9]{1,3}( [0-9]{3})* [0-9.]+ [0-9]{1,3}( [0-9]{3})* [0-9.]+ [0-9]{1,3}( [0-9]{3})* [0-9.]+$"
    cand_re <- "^(.+?) (?:([A-Z][A-Z0-9]{1,4}) )?([0-9]{1,3}(?: [0-9]{3})*) ([0-9]{1,3}\\.[0-9])$"
    recs <- list(); seat <- NA_character_; mode <- "fp"; formal <- NA_real_; k <- 0L; seen <- character(0); skip <- FALSE
    for (i in seq_along(x)) {
      ln <- x[i]
      if (grepl(stat_re, ln)) {
        j <- if (i > 2 && grepl("^Enrolled Voted", x[i - 1])) i - 2L else i - 1L   # first block of a page repeats the column header
        if (j >= 1 && !grepl("^[0-9]", x[j]) && !grepl(cand_re, x[j], perl = TRUE)) seat <- x[j]
        pieces <- strsplit(ln, " [0-9]+\\.[0-9] ?")[[1]]                  # split on the percent tokens
        pieces <- gsub(" ", "", pieces[nzchar(pieces)])
        formal <- as.numeric(pieces[2]); mode <- "fp"
        # a seat met twice is the NEXT election's block (the 2006 section follows 2002): stop there
        if (seat %in% seen) { skip <- TRUE } else seen <- c(seen, seat)
        next
      }
      if (grepl("^Result after preferences", ln)) { mode <- "tcp"; next }
      if (skip) next
      mm <- regmatches(ln, regexec(cand_re, ln, perl = TRUE))[[1]]
      if (length(mm) && !is.na(seat) && !grepl("^(Enrolled|Voted|Formal|Informal)", ln)) {
        recs[[length(recs) + 1L]] <- data.table(seat = seat, mode = mode, name = mm[2], code = mm[3],
                                                votes = to_votes(mm[4]), pct = as.numeric(mm[5]), formal = formal)
      }
    }
    d <- rbindlist(recs)
    # a two-to-five letter token is only a party code if it recurs; otherwise it was the
    # candidate's initials (an independent has no affiliation printed)
    freq <- d[nzchar(code), .N, by = code]
    codes <- freq[N >= 3, code]
    d[!(code %in% codes) & nzchar(code), `:=`(name = paste(name, code), code = "")]
    d[, elected := grepl("[*]$", name)]
    d[, name := sub("[*]$", "", name)]
    d[, election_year := year]
    d
  }
  names_map <- c(ALP = "Australian Labor Party", LIB = "Liberal Party", GRN = "Australian Greens",
                 DEM = "Australian Democrats", FFP = "Family First Party", NAT = "National Party",
                 ONP = "One Nation", D4D = "Dignity for Disability", SAF = "SA First", `NO` = "")
  for (spec in list(list("^ELECTORATE RESULTS .{1,3} 9 FEBRUARY", 2002), list("^ELECTORATE RESULTS .{1,3} 18 MARCH", 2006))) {
    yr <- spec[[2]]
    d <- parse_block(spec[[1]], yr)
    # fix: stop at 47 seats (anything after the last district is summary tables)
    ordr <- unique(d$seat)
    fpd <- d[mode == "fp"]
    chk <- fpd[, .(sum = sum(votes), formal = formal[1], n = .N), by = seat]
    good <- chk[abs(sum - formal) <= 2, seat]      # Jaensch has a few 1-vote typos (flagged below)
    cat(sprintf("KQ31 SA %d: %d seat blocks found, %d with candidate votes summing to the printed formal vote\n",
                yr, nrow(chk), length(good)))
    bad <- chk[sum != formal]; cat(sprintf("KQ31 blocks off by 1-2 votes (kept): %s
", paste(chk[sum != formal & abs(sum - formal) <= 2, seat], collapse = ", ")))
    if (nrow(bad)) { cat("KQ31 mismatching blocks:\n"); print(bad) }
    good <- head(good, 47L)
    fpd <- fpd[seat %in% good]
    fpd[, party_name := ifelse(code == "", "Independent", names_map[code])]
    fpd[is.na(party_name), party_name := code]
    fpd[, party := cls(party_name, ifelse(code == "", "IND", code))]
    fp <- fpd[, .(votes = sum(votes)), by = .(seat, party)][order(seat, party)]
    fwrite(fp, file.path(OUT, sprintf("ecsa-%d-sa-firstprefs.csv", yr)))
    fwrite(fpd[, .(seat, candidate = name, party_code = code, party_name, party_class = party, votes, pct, elected, formal_votes = formal)],
           file.path(OUT, sprintf("ecsa-%d-sa-firstprefs-detail.csv", yr)))
    td <- d[mode == "tcp" & seat %in% good]
    td[fpd, on = .(seat, name), `:=`(party = i.party, party_name = i.party_name, party_code_fp = i.code)]
    # a finalist whose name is spelled differently in the two tables (Jaensch typos) is matched on
    # seat + party code when that is unique within the seat; this is reported, not silent
    fb <- fpd[nzchar(code), .(party_fb = party[1], pname_fb = party_name[1], n = .N), by = .(seat, code)][n == 1L]
    rr <- td[is.na(party) & nzchar(code)]
    if (nrow(rr)) {
      td[fb, on = .(seat, code), `:=`(party = fifelse(is.na(party), i.party_fb, party), party_name = fifelse(is.na(party_name), i.pname_fb, party_name))]
      cat(sprintf("KQ32 finalists matched on seat+party code because the name differs: %s
", paste(rr$seat, rr$name, collapse = "; ")))
    }
    cat(sprintf("KQ32 SA %d: TCP rows %d over %d seats; unmatched finalists %d\n", yr, nrow(td), uniqueN(td$seat), sum(is.na(td$party))))
    if (any(is.na(td$party))) { cat("KQ32 unmatched finalists:
"); print(td[is.na(party), .(seat, name, code, votes)]) }
    td <- td[!is.na(party)]
    td <- td[seat %in% td[, .N, by = seat][N == 2L, seat]]               # a finalist pair is two candidates
    fwrite(td[, .(seat, party, votes)][order(seat, -votes)],   # one row per finalist (Liberal v National finals stay two rows)
           file.path(OUT, sprintf("ecsa-%d-sa-tcp.csv", yr)))
    fwrite(td[, .(seat, candidate = name, party_code = party_code_fp, party_name, party_class = party, votes, pct, elected)],
           file.path(OUT, sprintf("ecsa-%d-sa-tcp-detail.csv", yr)))
    cat(sprintf("KQ33 SA %d: %d seats written; seats missing: %s\n", yr, uniqueN(fp$seat), "see doc"))
  }
  invisible()
}

# =============================================================================
# 4. QUEENSLAND 2001  (ECQ Statistical Returns)
# =============================================================================
run_ecq <- function() {
  RAW <- file.path("external", "reference", "ecq", "raw", "2001")
  pdf <- file.path(RAW, "ecq-2001-statistical-returns.pdf")
  ok <- grab("https://www.ecq.qld.gov.au/__data/assets/pdf_file/0017/2654/2001-Statistical-Returns.pdf", pdf, "pdf")
  stopifnot(ok)
  tx <- trimws(pdf_text_raw(pdf, file.path(RAW, "ecq-2001-statistical-returns.txt")))
  # Table 1.2: per district "n enrolment ... formal informal total turnout informal%"
  # (the seat name is the line above). Formal and informal identify each district.
  re_t <- "^[0-9]{1,2} ([0-9,]+) ([0-9,]+) ([0-9,]+) ([0-9,]+) [0-9.]+% [0-9.]+%$"
  idx <- grep(re_t, tx)
  dist <- rbindlist(lapply(idx, function(i) { m <- regmatches(tx[i], regexec(re_t, tx[i]))[[1]]
    data.table(seat = sub("^[*] ?", "", tx[i - 1L]), enrolment = to_votes(m[2]), formal = to_votes(m[3]), informal = to_votes(m[4]), total = to_votes(m[5])) }))
  dist <- unique(dist, by = "seat")
  cat(sprintf("KQ40 Qld 2001: %d districts in the votes-cast table (expect 89)
", nrow(dist)))
  stopifnot(nrow(dist) == 89L, !anyDuplicated(dist[, .(formal, informal)]))
  # Table 1.3: one result line per district, in a text order that varies by page, so the
  # line is tied to its district by (formal votes, informal votes), never by the name above it
  tail_re <- "^(.*?)([0-9,]+) ([0-9,]+) ([0-9,]+) ([0-9.]+)% ([0-9.]+)% ([A-Z]{2,4})$"
  lines <- grep("%", tx[1700:2200], value = TRUE); lines <- lines[grepl(tail_re, lines)]
  orph <- grep("^[0-9,]+ [A-Z]{3}$|^[A-Za-z* ]+ [0-9,]+ [A-Z]{3}$", tx[1700:2200], value = TRUE)
  orph <- orph[!grepl("%", orph)]
  orph <- data.table(votes = to_votes(sub("^.*?([0-9,]+) ([A-Z]{3})$", "\\1", orph, perl = TRUE)), code = sub("^.* ([A-Z]{3})$", "\\1", orph))
  cat(sprintf("KQ41 result lines %d; stray candidate fragments %d (%s)
", length(lines), nrow(orph), paste(orph$votes, orph$code, collapse = ", ")))
  recs <- list(); used <- 0L
  for (ln in lines) {
    tl <- regmatches(ln, regexec(tail_re, ln))[[1]]
    inf <- to_votes(tl[5]); body <- tl[2]
    pr <- regmatches(body, gregexpr("[0-9,]+ [A-Z]{2,4}", body))[[1]]
    v <- to_votes(sub(" .*", "", pr)); cd <- sub("^.* ", "", pr)
    sd <- dist[informal == inf]
    hit <- sd[formal == sum(v)]
    if (!nrow(hit) && nrow(orph)) {                 # add stray fragments until the formal vote is met
      for (k in 1:3) { cb <- combn(nrow(orph), k, simplify = FALSE)
        for (c in cb) if (nrow(sd[formal == sum(v) + sum(orph$votes[c])])) { hit <- sd[formal == sum(v) + sum(orph$votes[c])]; v <- c(v, orph$votes[c]); cd <- c(cd, orph$code[c]); break }
        if (nrow(hit)) break }
    }
    if (nrow(hit) != 1L) { cat("KQ41 UNMATCHED result line:", ln, "
"); next }
    recs[[length(recs) + 1L]] <- data.table(seat = hit$seat, votes = v, code = cd, formal = hit$formal, informal = inf,
      tcp_winner = to_votes(tl[3]), tcp_loser = to_votes(tl[4]), tcp_winner_pct = as.numeric(tl[7]), winner_code = tl[8], informal_pct = as.numeric(tl[6]))
  }
  d <- rbindlist(recs)
  cat(sprintf("KQ41 parsed fp rows %d, districts %d of 89; candidate votes equal formal in %d
", nrow(d), uniqueN(d$seat),
              sum(d[, .(ok = sum(votes) == formal[1]), by = seat]$ok)))
  stopifnot(uniqueN(d$seat) == 89L)
  nm <- c(ALP = "Australian Labor Party", NPA = "National Party", LIB = "Liberal Party", ONP = "Pauline Hanson's One Nation",
          GRN = "The Greens", DEM = "Australian Democrats", CDP = "Christian Democratic Party", CCA = "City Country Alliance",
          IND = "Independent")
  d[, party_name := nm[code]]; d[is.na(party_name), party_name := code]
  d[, party := cls(party_name, code)]
  fwrite(d[, .(votes = sum(votes)), by = .(seat, party)][order(seat, party)], file.path(OUT, "ecq-2001-qld-firstprefs.csv"))
  fwrite(d[, .(seat, party_code = code, party_name, party_class = party, votes, formal_votes = formal, informal_votes = informal,
               tcp_winner_votes = tcp_winner, tcp_loser_votes = tcp_loser, tcp_winner_pct, tcp_winner_code = winner_code)],
         file.path(OUT, "ecq-2001-qld-firstprefs-detail.csv"))
  # The table gives the winner's party and both finalists' votes but NOT the loser's party, and under
  # optional preferential voting the loser need not be second on first preferences. A two-row TCP
  # entry is written only where the loser is certain: districts with exactly two candidates, or where
  # the winner's code is among exactly two printed parties.
  tc <- d[, .(winner_code = winner_code[1], w = tcp_winner[1], l = tcp_loser[1], n = .N, codes = list(code)), by = seat]
  tc[, certain := n == 2L]
  rows <- rbindlist(lapply(seq_len(nrow(tc[certain == TRUE])), function(i) { z <- tc[certain == TRUE][i]
    oth <- setdiff(z$codes[[1]], z$winner_code)
    if (length(oth) != 1L) return(NULL)
    data.table(seat = z$seat, code = c(z$winner_code, oth), votes = c(z$w, z$l)) }))
  rows[, party := cls(nm[code], code)]
  rows[is.na(party), party := "OTH"]
  fwrite(rows[, .(seat, party, votes)], file.path(OUT, "ecq-2001-qld-tcp.csv"))
  wn <- unique(d[, .(seat, code = winner_code, votes = tcp_winner)])
  wn[, party := cls(nm[code], code)]
  fwrite(wn[, .(seat, party, votes)], file.path(OUT, "ecq-2001-qld-tcp-winner.csv"))
  cat(sprintf("KQ42 TCP written for %d two-candidate districts of 89; the rest have winner party + both finalists' votes in the detail file only
", uniqueN(rows$seat)))
  invisible(d)
}

# =============================================================================
# 5. CROSS-CHECK against the AEF archive
# =============================================================================
run_xcheck <- function() {
  ARCH <- file.path(OUT, "archive")
  jobs <- list(
    list("vic2006", "vec-2006-vic", "2006vic"), list("vic2002", "vec-2002-vic", "2002vic"),
    list("sa2002", "ecsa-2002-sa", "2002sa"), list("sa2006", "ecsa-2006-sa", "2006sa"),
    list("qld2001", "ecq-2001-qld", "2001qld"))
  rows <- list(); wm <- list()
  for (j in jobs) {
    fo <- file.path(OUT, paste0(j[[2]], "-firstprefs.csv")); fa <- file.path(ARCH, paste0(j[[3]], "-firstprefs.csv"))
    to <- file.path(OUT, paste0(j[[2]], if (j[[1]] == "qld2001") "-tcp-winner.csv" else "-tcp.csv"));        ta <- file.path(ARCH, paste0(j[[3]], "-tcp.csv"))
    r <- list(election = j[[1]])
    fd <- sub("-firstprefs.csv", "-firstprefs-detail.csv", fo, fixed = TRUE)
    if (file.exists(fd) && file.exists(fa)) {
      # candidate-level: the sorted vote vector of each seat, official against archive. This ignores
      # party LABELS (the archive and classify_party() disagree on OTH vs OTH_RIGHT vs IND), so it
      # isolates the numbers; the class-level agreement is reported on its own.
      od <- fread(fd); ad <- fread(fa)
      common <- intersect(od$seat, ad$seat)
      sv <- function(z) z[seat %in% common, .(v = list(sort(votes, decreasing = TRUE))), by = seat]
      mv <- merge(sv(od), sv(ad), by = "seat", suffixes = c("_o", "_a"))
      mv[, dif := mapply(function(a, b) { n <- max(length(a), length(b)); max(abs(c(a, rep(0, n - length(a))) - c(b, rep(0, n - length(b))))) }, v_o, v_a)]
      oc <- od[seat %in% common, .(votes = sum(votes)), by = .(seat, party = party_class)]
      ac <- ad[seat %in% common, .(votes = sum(votes)), by = .(seat, party)]
      mc <- merge(oc, ac, by = c("seat", "party"), all = TRUE); mc[is.na(votes.x), votes.x := 0]; mc[is.na(votes.y), votes.y := 0]
      cls_exact <- mc[, .(ok = all(votes.x == votes.y)), by = seat]
      r <- c(r, list(fp_official_seats = uniqueN(od$seat), fp_archive_seats = uniqueN(ad$seat), fp_compared = length(common),
                     fp_exact_votes = sum(mv$dif == 0), fp_max_vote_diff = max(mv$dif), fp_exact_with_party_class = sum(cls_exact$ok),
                     fp_only_official = paste(setdiff(od$seat, ad$seat), collapse = "; "),
                     fp_only_archive = paste(setdiff(ad$seat, od$seat), collapse = "; ")))
      big <- head(mv[dif > 0][order(-dif)], 8)
      if (nrow(big)) cat(sprintf("KQ51 %s largest first-preference differences (votes): %s
", j[[1]], paste(big$seat, big$dif, collapse = "; ")))
    }
    if (file.exists(to) && file.exists(ta)) {
      o <- fread(to); a <- fread(ta)
      if (j[[1]] == "vic2002") {            # official = two-party-preferred ALP v LNP; compare only archive finals that were ALP v LNP
        okseats <- a[, .(ok = setequal(party, c("ALP", "LNP"))), by = seat][ok == TRUE, seat]
        r$tcp_archive_seats_not_alp_v_lnp <- uniqueN(a$seat) - length(okseats); a <- a[seat %in% okseats]
      }
      if (j[[1]] == "qld2001") a <- a[order(seat, -votes)][, .SD[1], by = seat]   # official file is winner-only (loser's party is not printed)
      w <- function(z) z[order(seat, -votes)][, .SD[1], by = seat][, .(seat, win = party)]
      mm <- merge(w(o), w(a), by = "seat", suffixes = c("_off", "_arch"))
      mm[, ok := win_off == win_arch]
      pv <- function(z) z[, .(v = list(sort(votes, decreasing = TRUE))), by = seat]
      mp <- merge(pv(o), pv(a), by = "seat", suffixes = c("_o", "_a"))
      mp[, dif := mapply(function(a, b) { n <- max(length(a), length(b)); max(abs(c(a, rep(0, n - length(a))) - c(b, rep(0, n - length(b))))) }, v_o, v_a)]
      r <- c(r, list(tcp_official_seats = uniqueN(o$seat), tcp_winners_compared = nrow(mm), tcp_winner_mismatch = sum(!mm$ok),
                     tcp_exact_votes = sum(mp$dif == 0), tcp_max_vote_diff = max(mp$dif)))
      big <- head(mp[dif > 0][order(-dif)], 6)
      if (nrow(big)) cat(sprintf("KQ51 %s largest TCP differences (votes): %s
", j[[1]], paste(big$seat, big$dif, collapse = "; ")))
      if (any(!mm$ok)) wm[[j[[1]]]] <- data.table(election = j[[1]], mm[ok == FALSE, .(seat, official = win_off, archive = win_arch)])
    }
    rows[[j[[1]]]] <- as.data.table(r)
  }
  res <- rbindlist(rows, fill = TRUE)
  fwrite(res, file.path("deciding-runs", "official-results-2000s-xcheck-2026-10-13.csv"))
  print(res, width = 250)
  if (length(wm)) { cat("KQ50 winner mismatches (official wins):\n"); print(rbindlist(wm)) } else cat("KQ50 no TCP winner mismatches\n")
  invisible(res)
}

for (s in SECTIONS) switch(s, vec = run_vec(), nswec = run_nswec(), ecsa = run_ecsa(), sa = run_ecsa(),
                           ecq = run_ecq(), xcheck = run_xcheck(), stop("unknown section ", s))
