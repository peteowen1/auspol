# Official distributions of preferences (count-by-count transfers) for four
# state elections that feed preference-flow estimates for new backtest pairs:
#
#   vec    Victoria 2006       VEC blob archive, one HTML page per district
#   nswec  New South Wales 2011 NSWEC "past results" site, one PDF countsheet per
#                              district (the HTML "dop" pages are empty stubs)
#   ecsa   South Australia 2010 and 2014   see section 3: no distribution exists
#
# Raw downloads are kept as received under external/reference/<commission>/raw/
# <election>/ and are never fetched twice. Parsed transfers go to
# external/elections/ in the schema of the existing transfer files
# (election, seat, round, from, to, votes; `from`/`to` are classify_party()
# classes), and a "-detail" file beside each keeps every field the source has
# (candidate names, party text, exhausted votes, progressive totals).
#
# Run from the repo root, one section or all:
#   powershell.exe -Command 'Rscript "scripts/fetch_state_distributions.R"'
#   powershell.exe -Command 'Rscript "scripts/fetch_state_distributions.R" vec'
#
# Emits SQ-free codes: this script uses the prefix "DD" (distribution data).
#   DQ1x = Victoria, DQ2x = NSW, DQ3x = SA.  ("SQ" is taken by fit_seats_full.R.)

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
SECTIONS <- if (length(args)) args else c("vec", "nswec", "ecsa")
OUT <- election_data_path()
UA  <- "auspol-research-fetch/1.0 (Australian election forecast research; polite 1 request/second)"

# ---- shared helpers ---------------------------------------------------------
strip_tags <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("&nbsp;", " ",
                gsub("<[^>]+>", " ", x))))
tables_of  <- function(h) regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
rows_of    <- function(t) regmatches(t, gregexpr("(?s)<tr.*?</tr>", t, perl = TRUE))[[1]]
cells_of   <- function(r) strip_tags(regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]])
num        <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", x)))
read_all   <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# A download counts as complete only if it ends the way its type ends: HTML with
# a closing </html>, PDF with %%EOF, XML with its closing tag. A non-empty file
# is not enough (a 65,536-byte truncation once passed a size guard here).
complete_ok <- function(dest, kind) {
  if (!file.exists(dest) || file.info(dest)$size < 200) return(FALSE)
  sz <- file.info(dest)$size
  tl <- readBin(dest, "raw", n = sz)[max(1, sz - 2000):sz]
  tail_txt <- rawToChar(tl[tl != as.raw(0)])           # PDFs carry NUL bytes
  switch(kind,
         html = grepl("</html>", tail_txt, ignore.case = TRUE, useBytes = TRUE),
         pdf  = grepl("%%EOF", tail_txt, fixed = TRUE, useBytes = TRUE),
         xml  = grepl("</EnumerationResults>", tail_txt, fixed = TRUE, useBytes = TRUE),
         TRUE)
}

FETCH_LOG <- list()
# One request per second. Returns TRUE when the file is on disk and complete.
grab <- function(url, dest, kind = "html") {
  if (complete_ok(dest, kind)) return(TRUE)           # never refetch what is on disk
  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
  for (k in 1:3) {
    h <- curl::new_handle(useragent = UA, timeout = 60, followlocation = TRUE)
    r <- tryCatch(curl::curl_fetch_memory(url, h), error = function(e) NULL)
    Sys.sleep(1)
    if (!is.null(r) && r$status_code == 200L) {
      writeBin(r$content, dest)
      if (complete_ok(dest, kind)) return(TRUE)
      unlink(dest)                                     # truncated: do not keep it
      status <- "incomplete"
    } else status <- if (is.null(r)) "error" else as.character(r$status_code)
    if (status %in% c("404", "403", "410")) break      # a block or absence is final
    Sys.sleep(3 * k)
  }
  FETCH_LOG[[length(FETCH_LOG) + 1L]] <<- data.table(url = url, status = status)
  FALSE
}

# Compare the last two candidates left in a distribution with a published
# two-candidate figure. Returns one row per seat.
fail_if_bad_class <- function(x, what) {
  if (anyNA(x)) stop(what, ": party class is NA for ", sum(is.na(x)), " candidate(s)")
}

# =============================================================================
# 1. VICTORIA 2006  (VEC)
# =============================================================================
run_vec <- function() {
  RAW <- file.path("external", "reference", "vec", "raw", "2006")
  BASE <- "https://itsitecoreblobvecprd01.blob.core.windows.net/public-files"
  PFX  <- "historical-results/state2006"
  dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

  lst <- file.path(RAW, "container-listing-state2006.xml")
  if (!complete_ok(lst, "xml")) {
    grab(sprintf("%s?restype=container&comp=list&prefix=%s&maxresults=5000", BASE, PFX),
         lst, "xml")
  }
  nm <- regmatches(read_all(lst), gregexpr("<Name>[^<]*</Name>", read_all(lst)))[[1]]
  nm <- sub("^.*/", "", gsub("</?Name>", "", nm))
  slugs <- sort(sub("district[.]html$", "", sub("^state2006distribution", "",
                  grep("^state2006distribution.*district[.]html$", nm, value = TRUE))))
  cat(sprintf("DQ10 VEC listing: %d districts with a distribution page\n", length(slugs)))
  stopifnot(length(slugs) == 88L)

  for (s in slugs) {
    for (kind in c("distribution", "result")) {
      f <- sprintf("state2006%s%sdistrict.html", kind, s)
      ok <- grab(sprintf("%s/%s/%s", BASE, PFX, f), file.path(RAW, f), "html")
      if (!ok) cat("DQ10 FAILED", f, "\n")
    }
  }

  parse_result <- function(h) {
    seat <- trimws(sub(" District.*$", "", strip_tags(regmatches(h, regexpr("(?s)<h2[^>]*>.*?</h2>", h, perl = TRUE)))))
    seat <- if (!nzchar(seat)) NA_character_ else seat
    note <- regmatches(h, regexpr("(?s)Note:.*?</td>", h, perl = TRUE))
    lut <- character(0)
    if (length(note)) {
      txt <- sub(" (Recheck|Primary|Recount|Preliminary) first preference votes.*$", "",
                 sub("^Note: *", "", strip_tags(note)))
      parts <- strsplit(txt, ", *(?=[^,=]+ = )", perl = TRUE)[[1]]
      has <- grepl(" = ", parts, fixed = TRUE)
      lut <- stats::setNames(trimws(sub("^[^=]+ = ", "", parts[has])),
                             trimws(sub(" = .*$", "", parts[has])))
    }
    tb <- tables_of(h)
    fp <- Filter(function(t) { r <- rows_of(t); length(r) && grepl("1st pref votes", paste(cells_of(r[1]), collapse = " ")) }, tb)
    if (!length(fp)) return(NULL)
    rr <- Filter(function(z) length(z) == 4L && !identical(z[1], "Candidate"), lapply(rows_of(fp[[1]]), cells_of))
    code <- vapply(rr, `[`, "", 2)
    full <- ifelse(nzchar(code) & code %in% names(lut), unname(lut[code]), code)
    # "After distribution" and two-candidate-preferred tables: 4 columns too.
    pick <- function(pat) {
      t <- Filter(function(t) { r <- rows_of(t); length(r) && grepl(pat, paste(cells_of(r[1]), collapse = " ")) }, tb)
      if (!length(t)) return(NULL)
      x <- Filter(function(z) length(z) == 4L && !identical(z[1], "Candidate"), lapply(rows_of(t[[1]]), cells_of))
      data.table(candidate = vapply(x, `[`, "", 1), votes = num(vapply(x, `[`, "", 3)))
    }
    list(seat = seat,
         cand = data.table(candidate = vapply(rr, `[`, "", 1), party_code = code, party_name = full,
                           fp = num(vapply(rr, `[`, "", 3))),
         after = pick("Votes after distribution"), tcp = pick("Preferred votes"))
  }

  parse_dist <- function(h) {
    seat <- trimws(sub(" District.*$", "", strip_tags(regmatches(h, regexpr("(?s)<h2[^>]*>.*?</h2>", h, perl = TRUE)))))
    if (!length(seat)) seat <- NA_character_      # the older stub layout has no <h2>
    tb <- Filter(function(t) grepl("title=\"Distribution of preference votes\"", t), tables_of(h))
    # A district won on first preferences has a stub page (heading, no table):
    # there is nothing to distribute, and that is recorded rather than skipped.
    has_rows <- length(tb) && any(grepl("^Total first preference", vapply(rows_of(tb[[1]]), function(r) cells_of(r)[1], "")))
    if (!has_rows) return(list(seat = seat, none = TRUE,
        elected = trimws(sub("^.*Elected member : *", "", strip_tags(h)))))
    rr <- lapply(rows_of(tb[[1]]), cells_of)
    cand <- rr[[1]][-c(1, length(rr[[1]]))]
    out <- list(); rnd <- 0L; fp <- NULL; prog_last <- NULL; final_tot <- NULL
    for (r in rr[-1]) {
      lab <- r[1]; vals <- r[-1]
      v <- num(vals[-length(vals)]); v[is.na(v)] <- 0
      tot <- num(vals[length(vals)])
      if (grepl("^Total first preference", lab)) { fp <- v; next }
      if (grepl("^Transfer of ", lab)) {
        rnd <- rnd + 1L
        if (!is.finite(tot) || sum(v) != tot)
          stop(seat, " round ", rnd, ": transfers sum to ", sum(v), " but the row total is ", tot)
        frm <- trimws(sub(".*ballot-papers of (.*) [(].*", "\\1", lab))
        excl_n <- as.integer(sub("^.*[(]([0-9]+)(st|nd|rd|th) excluded.*$", "\\1", lab))
        out[[rnd]] <- data.table(seat = seat, round = rnd, order_excluded = excl_n, from_name = frm,
                                 to_name = cand, votes = v, row_total = tot)
        next
      }
      if (grepl("^Progressive", lab)) { prog_last <- v; next }
      if (grepl("^FINAL TOTAL", lab, ignore.case = TRUE)) { final_tot <- v; next }
    }
    list(seat = seat, cand = cand, fp = fp, final = final_tot, prog = prog_last,
         tx = if (length(out)) rbindlist(out) else NULL)
  }

  res <- lapply(slugs, function(s) parse_result(read_all(file.path(RAW, sprintf("state2006result%sdistrict.html", s)))))
  dst <- lapply(slugs, function(s) parse_dist(read_all(file.path(RAW, sprintf("state2006distribution%sdistrict.html", s)))))
  names(res) <- names(dst) <- slugs
  stopifnot(!any(vapply(res, is.null, NA)), !any(vapply(dst, is.null, NA)))

  detail <- list(); checks <- list(); cand_all <- list()
  for (s in slugs) {
    r <- res[[s]]; d <- dst[[s]]
    seat <- r$seat                      # the result page always names the district
    if (!is.na(d$seat) && d$seat != seat) stop(seat, ": distribution page names ", d$seat)
    r$cand[, class := classify_party(party_name, party_code)]
    fail_if_bad_class(r$cand$class, seat)
    if (anyDuplicated(r$cand$candidate)) stop(seat, ": duplicate candidate names")
    cand_all[[s]] <- data.table(seat = seat, r$cand)
    # candidate names in the distribution must match the result page exactly
    if (isTRUE(d$none)) {
      top <- r$cand[which.max(fp)]
      checks[[s]] <- data.table(seat = seat, n_cand = nrow(r$cand), n_rounds = 0L,
        fp_match = TRUE, replay_vs_after_table = NA, replay_vs_final_row = NA,
        final_two = "", final_two_votes = sprintf("top first pref %.1f%%", 100 * top$fp / sum(r$cand$fp)),
        max_abs_diff_vs_tcp_table = NA_real_, no_dist_ok = top$fp > sum(r$cand$fp) / 2 &&
          identical(top$candidate, d$elected))
      next
    }
    if (!setequal(d$cand, r$cand$candidate)) stop(seat, ": distribution and result candidates differ")
    if (!is.null(d$tx)) {
      tx <- copy(d$tx)
      tx <- merge(tx, r$cand[, .(from_name = candidate, from = class, from_party = party_name)], by = "from_name")
      tx <- merge(tx, r$cand[, .(to_name = candidate, to = class, to_party = party_name)], by = "to_name")
      detail[[s]] <- tx
    }
    # check 1: first preferences, distribution page vs result page
    fp_ok <- all(d$fp[match(r$cand$candidate, d$cand)] == r$cand$fp)
    # check 2: replay the distribution -> the last two candidates' totals vs the
    # published "results after distribution" table, and vs the TCP table
    prog <- setNames(d$fp, d$cand)
    if (!is.null(d$tx)) for (k in sort(unique(d$tx$round))) {
      t <- d$tx[round == k]
      prog[t$from_name[1]] <- 0
      prog[t$to_name] <- prog[t$to_name] + t$votes
    }
    left <- prog[prog > 0]
    last2 <- sort(left, decreasing = TRUE)
    aft <- r$after
    aft_ok <- !is.null(aft) && nrow(aft) == length(last2) &&
      all(aft$votes[match(names(last2), aft$candidate)] == as.numeric(last2))
    fin_ok <- !is.null(d$final) && all(sort(d$final[d$final > 0], decreasing = TRUE) == as.numeric(last2))
    tcp <- r$tcp
    tcp_diff <- if (!is.null(tcp) && all(names(last2) %in% tcp$candidate))
      max(abs(tcp$votes[match(names(last2), tcp$candidate)] - as.numeric(last2))) else NA_real_
    checks[[s]] <- data.table(seat = seat, n_cand = nrow(r$cand), n_rounds = if (is.null(d$tx)) 0L else max(d$tx$round),
                              fp_match = fp_ok, replay_vs_after_table = aft_ok, replay_vs_final_row = fin_ok,
                              final_two = paste(names(last2), collapse = " v "),
                              final_two_votes = paste(as.numeric(last2), collapse = "/"),
                              max_abs_diff_vs_tcp_table = tcp_diff, no_dist_ok = NA)
  }
  chk <- rbindlist(checks, fill = TRUE); det <- rbindlist(detail); cands <- rbindlist(cand_all)
  det[, election := "vic2006"]
  agg <- det[votes > 0, .(votes = sum(votes)), by = .(election, seat, round, from, to)]
  setorder(agg, seat, round, from, to)
  fwrite(agg, file.path(OUT, "vec-2006-vic-transfers.csv"))
  setcolorder(det, c("election", "seat", "round", "order_excluded", "from_name", "from_party", "from",
                     "to_name", "to_party", "to", "votes", "row_total"))
  fwrite(det[order(seat, round)], file.path(OUT, "vec-2006-vic-transfers-detail.csv"))
  fwrite(cands, file.path(OUT, "vec-2006-vic-candidates.csv"))
  fwrite(chk, file.path(OUT, "vec-2006-vic-checks.csv"))
  cat(sprintf("DQ11 wrote vec-2006-vic-transfers.csv: %d rows, %d seats, %s votes moved\n",
              nrow(agg), uniqueN(agg$seat), format(sum(agg$votes), big.mark = ",")))
  cat(sprintf("DQ12 seats parsed %d / 88 | first prefs match %d | replay = after-table %d | replay = FINAL row %d\n",
              nrow(chk), sum(chk$fp_match), sum(chk$replay_vs_after_table, na.rm = TRUE), sum(chk$replay_vs_final_row, na.rm = TRUE)))
  cat(sprintf("DQ12 seats with no distribution (winner on first preferences): %d, of which winner holds >50 pct and is the elected member: %d
",
              sum(chk$n_rounds == 0L), sum(chk$no_dist_ok, na.rm = TRUE)))
  cat(sprintf("DQ12 TCP table (first-count figures, rechecks differ): %d comparable, max diff %s, %d differ by >50\n",
              sum(!is.na(chk$max_abs_diff_vs_tcp_table)), max(chk$max_abs_diff_vs_tcp_table, na.rm = TRUE),
              sum(chk$max_abs_diff_vs_tcp_table > 50, na.rm = TRUE)))
  cat("DQ12 largest differences from the published two-candidate-preferred table:
")
  print(chk[order(-max_abs_diff_vs_tcp_table)][1:5, .(seat, final_two, final_two_votes, max_abs_diff_vs_tcp_table)])
  print(chk[n_rounds > 0 & !(fp_match & replay_vs_after_table & replay_vs_final_row)])
  print(agg[, .(votes = sum(votes)), by = from][order(-votes)])
  invisible(chk)
}

# =============================================================================
# 2. NEW SOUTH WALES 2011  (NSWEC past results site)
# =============================================================================
# The commission's HTML "preferential count" page (la_dop-<District>.htm) is an
# empty stub for every district on this site (checked: identical 8.7 KB shell
# with no table). The counts are only in the PDF countsheet it links to
# (laPDF/<District>.pdf), one per district, which this section reads by word
# position because the PDF's text order is scrambled.
NSW_BASE <- "https://pastvtr.elections.nsw.gov.au/SGE2011"
NSW_RAW  <- file.path("external", "reference", "nswec", "raw", "2011")

nsw_districts <- function() {
  f <- file.path(NSW_RAW, "la_landing.htm")
  grab(paste0(NSW_BASE, "/la_landing.htm"), f, "html")
  h <- read_all(f)
  unique(sub("[.]htm$", "", sub("^la/la_district_summary-", "",
        regmatches(h, gregexpr("la/la_district_summary-[^\"]+[.]htm", h))[[1]])))
}

fetch_nsw <- function() {
  ds <- nsw_districts()
  cat(sprintf("DQ20 NSW landing page lists %d districts\n", length(ds)))
  stopifnot(length(ds) == 93L)
  grab(sprintf("%s/la/la_dop-Balmain.htm", NSW_BASE), file.path(NSW_RAW, "stub-la_dop-Balmain.htm"), "html")
  for (d in ds) {
    ok1 <- grab(sprintf("%s/laPDF/%s.pdf", NSW_BASE, d), file.path(NSW_RAW, "pdf", paste0(d, ".pdf")), "pdf")
    ok2 <- grab(sprintf("%s/la/la_post_election_night-%s.htm", NSW_BASE, d), file.path(NSW_RAW, "fp", paste0(d, ".htm")), "html")
    ok3 <- grab(sprintf("%s/la/la_post_election_night_tcp-%s.htm", NSW_BASE, d), file.path(NSW_RAW, "tcp", paste0(d, ".htm")), "html")
    if (!(ok1 && ok2 && ok3)) cat("DQ20 FAILED for", d, ok1, ok2, ok3, "\n")
  }
  cat("DQ20 NSW download pass finished\n")
  invisible(ds)
}

# Parse one countsheet PDF into candidates, cell values and the excluded
# candidate of each count. Cell values are assigned to columns by the right edge
# of the number (they are right-aligned) and to candidates by row position.
parse_nsw_pdf <- function(path, district) {
  pgs <- pdftools::pdf_data(path)
  has_sheet <- vapply(pgs, function(p) any(p$text == "Countsheet"), NA)
  if (sum(has_sheet) != 1L) stop(district, ": expected one countsheet page, found ", sum(has_sheet))
  w <- as.data.table(pgs[[which(has_sheet)]])
  w[, r := x + width]

  hy <- as.integer(names(sort(table(w[text == "DISTRIBUTED", y]), decreasing = TRUE))[1])
  if (is.na(hy)) stop(district, ": no DISTRIBUTED header")
  dist_a <- w[text == "DISTRIBUTED" & y == hy][order(x), r]
  prog_a <- w[text == "TOTALS" & y == hy][order(x), r]
  stopifnot(length(dist_a) == length(prog_a))
  fp_a <- w[text == "Votes" & y == hy][order(x), r][1]       # "First Preference Votes"
  ncount <- 1L + length(dist_a)
  anchors <- data.table(kind = c("fp", rep("dist", length(dist_a)), rep("prog", length(prog_a))),
                        count = c(1L, 2:ncount, 2:ncount), a = c(fp_a, dist_a, prog_a))

  y_tf <- w[text == "Formal" & x < 120][order(y)]$y[1]       # the "Total Formal Votes" row
  lab <- w[r < fp_a - 25 & y > hy + 6 & y < y_tf - 4][order(y, x)]
  lab[, ln := cumsum(c(1L, diff(y) > 2L))]
  lines <- lab[, .(y = min(y), txt = paste(text, collapse = " ")), by = ln]
  cands <- list(); cur_name <- character(0); cur_y <- NA_real_; party <- NULL
  for (i in seq_len(nrow(lines))) {
    t <- lines$txt[i]
    if (!is.null(party)) {
      party <- paste(party, t)
      if (grepl("[)]$", t)) { cands[[length(cands) + 1L]] <- list(name = cur_name, y = cur_y, party = party)
                              cur_name <- character(0); party <- NULL }
    } else if (grepl("^[(]", t)) {
      if (grepl("[)]$", t)) { cands[[length(cands) + 1L]] <- list(name = cur_name, y = cur_y, party = t); cur_name <- character(0) }
      else party <- t
    } else {
      # A name line more than 12 points below the previous line starts a new row:
      # the earlier candidate printed no "(party)" line at all (an unaffiliated
      # candidate), which is recorded as a blank party and not merged.
      if (length(cur_name) && lines$y[i] - lines$y[i - 1L] > 12) {
        cands[[length(cands) + 1L]] <- list(name = cur_name, y = cur_y, party = "()"); cur_name <- character(0)
      }
      if (!length(cur_name)) cur_y <- lines$y[i]
      cur_name <- paste(c(cur_name, t), collapse = " ")
    }
  }
  if (length(cur_name) && is.null(party)) cands[[length(cands) + 1L]] <- list(name = cur_name, y = cur_y, party = "()")
  else if (!is.null(party) || length(cur_name)) stop(district, ": unparsed label lines left over")
  cd <- data.table(cand = vapply(cands, function(z) trimws(z$name), ""),
                   party = sub("^[(](.*)[)]$", "\\1", vapply(cands, function(z) z$party, "")),
                   ytop = vapply(cands, function(z) z$y, 0))
  cd[, id := .I]

  nums <- w[x > fp_a - 45 & grepl("^[0-9][0-9,]*$", text) & y > hy + 6]
  nums[, v := as.numeric(gsub(",", "", text))]
  dm <- outer(nums$r, anchors$a, function(a, b) abs(a - b))
  best <- max.col(-dm, ties.method = "first")
  nums[, `:=`(kind = anchors$kind[best], count = anchors$count[best], adist = apply(dm, 1, min))]
  if (any(nums$adist > 9)) stop(district, ": ", sum(nums$adist > 9), " numeric cell(s) fit no column")
  cell <- nums[y < y_tf - 4]
  cell[, id := findInterval(y, c(cd$ytop, Inf) - 1)]
  cell <- cell[id >= 1L & id <= nrow(cd)]

  trow <- function(first_word, second_word = NULL) {
    k <- w[x < 120 & text == first_word][order(y)]
    if (!is.null(second_word)) {
      ok <- vapply(seq_len(nrow(k)), function(i) any(w$text == second_word & abs(w$y - k$y[i]) < 2 & w$x > k$x[i]), NA)
      k <- k[ok]
    }
    if (!nrow(k)) return(data.table(kind = character(), count = integer(), v = numeric()))
    nums[abs(y - k$y[1]) <= 4, .(kind, count, v)]
  }
  tfv <- trow("Total", "Formal")
  exh <- trow("Exhausted")

  exc_w <- w[text == "Excluded"][order(x)]
  blocks <- data.table(count = 2:ncount, x0 = dist_a - 36)
  excl <- rbindlist(lapply(seq_len(nrow(exc_w)), function(i) {
    xe <- exc_w$x[i]; ye <- exc_w$y[i]
    cnt <- blocks$count[which.min(abs(blocks$x0 - (xe - 4)))]
    nmw <- w[y < ye - 3 & y > ye - 16 & x >= xe - 6 & x < xe + 78][order(x)]
    nv <- w[abs(y - (ye + 11)) < 3 & x >= xe - 6 & x < xe + 78 & grepl("^[0-9]+$", text)]
    data.table(count = cnt, name = paste(nmw$text, collapse = " "),
               n_dist = if (nrow(nv)) as.numeric(nv$text[1]) else NA_real_)
  }))
  elected <- w[text == "ELECTED"]
  # The commission's own declaration is the footer line "NAME (Party) will be
  # elected"; the green ELECTED cell is missing on sheets where the count stopped
  # early (Charlestown), so the footer is the one read.
  txt <- unlist(strsplit(pdftools::pdf_text(path)[which(has_sheet)], "\n"))
  foot <- grep("will be elected", txt, value = TRUE)
  foot_name <- if (length(foot)) trimws(sub(" [(].*$", "", trimws(foot[1]))) else NA_character_
  partial <- any(grepl("full distribution of preferences was not undertaken",
                       paste(unlist(strsplit(paste(pdftools::pdf_text(path), collapse = " "), "\n")), collapse = " ")))
  list(district = district, foot_name = foot_name, partial = partial, cands = cd, cells = cell[, .(id, kind, count, v)],
       totals_formal = tfv, exhausted = exh, excluded = excl,
       elected_id = if (nrow(elected)) findInterval(elected$y[1] + 6, c(cd$ytop, Inf) - 1) else NA_integer_,
       ncount = ncount)
}

run_nswec <- function() {
  ds <- fetch_nsw()
  PDFS <- file.path(NSW_RAW, "pdf")
  missing_pdf <- ds[!file.exists(file.path(PDFS, paste0(ds, ".pdf")))]
  if (length(missing_pdf)) cat("DQ21 NO PDF for:", paste(missing_pdf, collapse = ", "), "\n")
  for (d in missing_pdf) {     # does the seat need a distribution at all? read its first preferences
    hh <- read_all(file.path(NSW_RAW, "fp", paste0(d, ".htm")))
    tt <- Filter(function(t) grepl("First Preference Votes Summary", t), tables_of(hh))
    rr <- Filter(function(z) length(z) >= 3 && !identical(z[1], "Candidate"), lapply(rows_of(tt[[1]]), cells_of))
    vv <- num(vapply(rr, `[`, "", 3)); nm <- vapply(rr, `[`, "", 1)
    cat(sprintf("DQ21 %s: leader %s holds %.2f%% of first preferences (%d candidates) -> %s\n", d, nm[which.max(vv)],
                100 * max(vv) / sum(vv), length(vv), if (max(vv) > sum(vv) / 2) "no distribution needed" else "DISTRIBUTION MISSING"))
  }

  fp_page <- function(d) {
    h <- read_all(file.path(NSW_RAW, "fp", paste0(d, ".htm")))
    t <- Filter(function(t) grepl("First Preference Votes Summary", t), tables_of(h))
    rr <- Filter(function(z) length(z) >= 3 && !identical(z[1], "Candidate"), lapply(rows_of(t[[1]]), cells_of))
    rawrows <- Filter(function(r) grepl("<td", r) && !grepl("Candidate</th>", r), rows_of(t[[1]]))
    ttl <- vapply(rawrows, function(r) { m <- regmatches(r, regexpr("title=\"[^\"]*\"", r)); if (length(m)) substring(m, 8L, nchar(m) - 1L) else "" }, "")
    data.table(name = sub(" [+]$", "", vapply(rr, `[`, "", 1)), code = sub(" [+]$", "", vapply(rr, `[`, "", 2)),
               votes = num(vapply(rr, `[`, "", 3)), party_full = ttl)
  }
  tcp_page <- function(d) {
    h <- read_all(file.path(NSW_RAW, "tcp", paste0(d, ".htm")))
    t <- Filter(function(t) grepl("Two Candidate Preferred", t) && grepl("Candidate", t), tables_of(h))
    if (!length(t)) return(NULL)
    rr <- Filter(function(z) length(z) >= 3 && !identical(z[1], "Candidate"), lapply(rows_of(t[[1]]), cells_of))
    rr <- Filter(function(z) grepl("^[0-9][0-9,]*$", z[3]), rr)
    if (!length(rr)) return(NULL)
    data.table(name = sub(" [+]$", "", vapply(rr, `[`, "", 1)), votes = num(vapply(rr, `[`, "", 3)))
  }
  words_of <- function(x) sort(strsplit(trimws(gsub("[[:space:]]+", " ", x)), " ")[[1]])

  out_tx <- list(); out_cells <- list(); out_chk <- list(); out_cands <- list()
  for (d in setdiff(ds, missing_pdf)) {
    seat <- gsub("_", " ", d)
    p <- parse_nsw_pdf(file.path(PDFS, paste0(d, ".pdf")), d)
    cd <- p$cands
    fpp <- fp_page(d)
    # candidates: the FP page lists SURNAME only, in the same ballot order
    if (nrow(fpp) != nrow(cd) || !all(startsWith(cd$cand, fpp$name))) stop(seat, ": PDF and FP page candidates differ")
    cd[, code := fpp$code]
    cd[, party_full := fpp$party_full]
    cd[, class := classify_party(ifelse(nzchar(party_full), party_full, party), code)]
    fail_if_bad_class(cd$class, seat)

    cl <- dcast(p$cells, id ~ kind + count, value.var = "v")
    getc <- function(kind, k) { nm <- sprintf("%s_%d", kind, k); if (nm %in% names(cl)) cl[[nm]][match(cd$id, cl$id)] else rep(NA_real_, nrow(cd)) }
    fp1 <- getc("fp", 1L)
    K <- max(c(1L, p$cells[kind == "prog", count]))        # last count with any progressive total
    ex <- p$excluded
    prob <- character(0)

    # --- C1: first preferences vs the commission's own post-election-night page
    c1 <- all(fp1 == fpp$votes) && isTRUE(sum(fp1) == p$totals_formal[kind == "fp", v][1])
    if (!c1) prob <- c(prob, "first preferences differ from the FP page or the formal total")

    tx <- list(); prog_prev <- fp1; alive <- rep(TRUE, nrow(cd))
    if (K >= 2L) for (k in 2:K) {
      e <- ex[count == k]
      if (nrow(e) != 1L) { prob <- c(prob, sprintf("count %d: %d excluded names found", k, nrow(e))); next }
      ei <- which(vapply(cd$cand, function(z) identical(words_of(z), words_of(e$name)), NA))
      if (length(ei) != 1L) { prob <- c(prob, sprintf("count %d: excluded name '%s' not matched", k, e$name)); next }
      dk <- getc("dist", k); pk <- getc("prog", k)
      exh_k <- p$exhausted[kind == "dist" & count == k, v]; if (!length(exh_k)) exh_k <- 0
      # --- C2: the excluded candidate's accumulated votes are what is distributed
      if (!isTRUE(prog_prev[ei] == e$n_dist)) prob <- c(prob, sprintf("count %d: excluded holds %s but header says %s", k, prog_prev[ei], e$n_dist))
      # --- C3: transfers plus exhausted equal the votes distributed
      dd <- ifelse(is.na(dk), 0, dk)
      if (sum(dd) + exh_k != e$n_dist) prob <- c(prob, sprintf("count %d: transfers %s + exhausted %s != %s distributed", k, sum(dd), exh_k, e$n_dist))
      # --- C4: progressive total = previous total + transfer, for every continuing candidate
      cont <- alive; cont[ei] <- FALSE
      if (!isTRUE(all(pk[cont] == prog_prev[cont] + dd[cont]))) prob <- c(prob, sprintf("count %d: progressive totals do not add", k))
      # --- C5: the excluded candidate really is the lowest of those left
      if (prog_prev[ei] > min(prog_prev[alive])) prob <- c(prob, sprintf("count %d: excluded candidate is not the lowest", k))
      keep <- !is.na(dk) & dk > 0
      if (any(keep)) tx[[length(tx) + 1L]] <- data.table(
        seat = seat, round = k - 1L, count = k, from_name = cd$cand[ei], from_party = cd$party[ei], from = cd$class[ei],
        votes_distributed = e$n_dist, to_name = cd$cand[keep], to_party = cd$party[keep], to = cd$class[keep],
        votes = dk[keep], to_progressive = pk[keep])
      if (exh_k > 0) tx[[length(tx) + 1L]] <- data.table(
        seat = seat, round = k - 1L, count = k, from_name = cd$cand[ei], from_party = cd$party[ei], from = cd$class[ei],
        votes_distributed = e$n_dist, to_name = "EXHAUSTED", to_party = "", to = "EXHAUSTED",
        votes = exh_k, to_progressive = p$exhausted[kind == "prog" & count == k, v][1])
      prog_prev[cont] <- pk[cont]; alive <- cont
    }
    # --- C6: final result. The candidate marked ELECTED leads the last count
    # and holds more than half of the votes still in it.
    last <- if (K >= 2L) prog_prev else fp1
    lead <- which.max(ifelse(alive, last, -1))
    elected_ok <- identical(p$foot_name, cd$cand[lead]) && last[lead] > sum(last[alive]) / 2
    if (!elected_ok) prob <- c(prob, "declared winner is not the majority leader of the last count")
    marker_agrees <- if (is.na(p$elected_id)) NA else p$elected_id == lead
    # --- C7: the commission's published two-candidate-preferred figures
    tcp <- tcp_page(d)
    fin <- cd[alive][, `:=`(votes = last[alive])]
    tcp_note <- "no TCP table"; tcp_diff <- NA_real_
    if (!is.null(tcp) && K >= 2L) {
      if (all(tcp$votes == 0)) tcp_note <- "TCP suspended (zero votes published)"
      else {
        m <- vapply(tcp$name, function(z) { i <- which(startsWith(fin$cand, z)); if (length(i) == 1L) i else NA_integer_ }, 1L)
        if (anyNA(m) || nrow(fin) != 2L) tcp_note <- sprintf("TCP pair [%s] differs from final candidates [%s]",
                                                             paste(tcp$name, collapse = "/"), paste(fin$cand, collapse = "/"))
        else { tcp_diff <- max(abs(tcp$votes - fin$votes[m])); tcp_note <- "compared" }
      }
    }
    out_chk[[d]] <- data.table(seat = seat, n_cand = nrow(cd), counts = K, n_excluded = nrow(ex), n_transfer_rows = length(tx),
      fp_ok = c1, elected_ok = elected_ok, elected = p$foot_name, elected_cell_agrees = marker_agrees, partial_distribution = p$partial, final = paste(fin$cand, last[alive], sep = " ", collapse = " v "),
      tcp_note = tcp_note, tcp_max_abs_diff = tcp_diff, problems = paste(prob, collapse = "; "))
    if (length(tx)) out_tx[[d]] <- rbindlist(tx)
    cc <- p$cells[, .(id, kind, count, v)]
    cc <- merge(cc, cd[, .(id, candidate = cand, party, class)], by = "id")
    out_cells[[d]] <- data.table(seat = seat, cc[, .(candidate, party, class, kind, count, votes = v)])
    out_cands[[d]] <- data.table(seat = seat, cd[, .(candidate = cand, party, party_code = code, party_full, class, first_pref = fp1)])
  }
  chk <- rbindlist(out_chk); det <- rbindlist(out_tx); cells <- rbindlist(out_cells); cands <- rbindlist(out_cands)
  det[, election := "nsw2011"]
  agg <- det[to != "EXHAUSTED" & votes > 0, .(votes = sum(votes)), by = .(election, seat, round, from, to)]
  setorder(agg, seat, round, from, to)
  fwrite(agg, file.path(OUT, "nswec-2011-nsw-transfers.csv"))
  setcolorder(det, c("election", "seat", "round", "count", "from_name", "from_party", "from", "votes_distributed",
                     "to_name", "to_party", "to", "votes", "to_progressive"))
  fwrite(det[order(seat, round)], file.path(OUT, "nswec-2011-nsw-transfers-detail.csv"))
  fwrite(cells, file.path(OUT, "nswec-2011-nsw-countsheets.csv"))
  fwrite(cands, file.path(OUT, "nswec-2011-nsw-candidates.csv"))
  fwrite(chk, file.path(OUT, "nswec-2011-nsw-checks.csv"))
  print(unique(cands[, .(party, party_code, party_full, class)])[order(class, party)], nrows = 100)
  cat(sprintf("DQ22 wrote nswec-2011-nsw-transfers.csv: %d rows, %d seats with transfers, %s votes moved (exhausted excluded)\n",
              nrow(agg), uniqueN(agg$seat), format(sum(agg$votes), big.mark = ",")))
  cat(sprintf("DQ22 districts parsed %d / 93 | no exclusions (won on first preferences) %d | first prefs match FP page %d | declared winner = majority leader %d | sheets marked partial %d | green ELECTED cell disagrees %d\n",
              nrow(chk), sum(chk$counts == 1L), sum(chk$fp_ok), sum(chk$elected_ok), sum(chk$partial_distribution),
              sum(chk$elected_cell_agrees == FALSE, na.rm = TRUE)))
  cat(sprintf("DQ22 TCP: compared %d (max abs diff %s, %d differ by >50), suspended %d, different pair %d\n",
              sum(chk$tcp_note == "compared"), max(chk$tcp_max_abs_diff, na.rm = TRUE),
              sum(chk$tcp_max_abs_diff > 50, na.rm = TRUE), sum(grepl("suspended", chk$tcp_note)),
              sum(grepl("differs", chk$tcp_note))))
  cat(sprintf("DQ22 districts with arithmetic or identity problems: %d\n", sum(nzchar(chk$problems))))
  print(chk[nzchar(problems), .(seat, problems)])
  print(chk[tcp_max_abs_diff > 50, .(seat, final, tcp_max_abs_diff)])
  print(agg[, .(votes = sum(votes)), by = from][order(-votes)])
  invisible(chk)
}

if ("nswec" %in% SECTIONS) run_nswec()
# =============================================================================
# 3. SOUTH AUSTRALIA 2010 and 2014  (ECSA)
# =============================================================================
# FINDING: ECSA's past-results pages for these two elections carry first
# preferences and a single two-candidate-preferred (TCP) table per district, and
# NO count-by-count distribution. This section downloads every district page the
# index offers, reads every table, and records whether any of them is a
# distribution. No transfers file is written for SA 2010 or 2014 because there
# is nothing to put in it; writing one from the TCP table would invent rounds.
# The first-preference and TCP figures are kept as a by-product
# (ecsa-<year>-sa-firstprefs-tcp.csv) for cross-checking.
ECSA_BASE  <- "https://www.ecsa.sa.gov.au/elections/past-state-election-results"
ECSA_INDEX <- paste0(ECSA_BASE, "?view=article&id=655:past-state-election-results-2009-2015&catid=9:ecsa")

run_ecsa <- function() {
  idx <- file.path("external", "reference", "ecsa", "raw", "2014", "index.html")
  grab(ECSA_INDEX, idx, "html")
  h <- read_all(idx)
  lk <- unique(regmatches(h, gregexpr("id=[0-9]+:20(10|14)-state-election-(results-)?[a-z-]+&amp;catid=12:elections", h))[[1]])
  lk <- sub("&amp;", "&", lk)
  nm <- sub("^id=[0-9]+:", "", sub("&catid.*$", "", lk))
  pages <- data.table(link = lk, slug = nm, year = as.integer(substr(nm, 1, 4)), id = as.integer(sub("^id=([0-9]+):.*$", "\\1", lk)))
  pages[, district := sub("^20(10|14)-state-election-(results-)?", "", slug)]
  pages <- pages[!grepl("polling-place", slug)]
  cat(sprintf("DQ30 ECSA index: %d district-result pages (2010: %d, 2014: %d)\n", nrow(pages), sum(pages$year == 2010), sum(pages$year == 2014)))
  res <- list(); fpl <- list()
  for (i in seq_len(nrow(pages))) {
    pg <- pages[i]
    f <- file.path("external", "reference", "ecsa", "raw", as.character(pg$year), paste0(pg$district, ".html"))
    ok <- grab(sprintf("%s?view=article&%s&catid=12:elections", ECSA_BASE, sub("&catid.*$", "", pg$link)), f, "html")
    if (!ok) { res[[i]] <- data.table(year = pg$year, district = pg$district, fetched = FALSE); next }
    tb <- tables_of(read_all(f))
    hdrs <- vapply(tb, function(t) paste(cells_of(rows_of(t)[1]), collapse = " | "), "")
    body <- vapply(tb, strip_tags, "")
    dist_like <- any(grepl("Excluded|Transfer|Distribution of preferences|Count [0-9]", body, ignore.case = TRUE))
    res[[i]] <- data.table(year = pg$year, district = pg$district, fetched = TRUE, n_tables = length(tb),
                           headers = paste(hdrs, collapse = " || "), looks_like_distribution = dist_like)
    # keep first preferences (first candidate table) and the TCP (last candidate table);
    # the votes column is the one headed "Ballot Papers" (its position differs by year)
    cand_tables <- Filter(function(t) identical(cells_of(rows_of(t)[1])[1], "Candidate"), tb)
    take <- function(t, label) {
      hd <- cells_of(rows_of(t)[1]); vc <- grep("Ballot Papers", hd)[1]
      r <- Filter(function(z) length(z) >= vc && !identical(z[1], "Candidate"), lapply(rows_of(t), cells_of))
      r <- Filter(function(z) grepl("^[0-9][0-9,]*$", z[vc]), r)
      data.table(year = pg$year, district = pg$district, table = label, candidate = vapply(r, `[`, "", 1),
                 party = vapply(r, `[`, "", 2), votes = num(vapply(r, function(z) z[vc], "")))
    }
    if (length(cand_tables) >= 2L) {
      fpl[[length(fpl) + 1L]] <- take(cand_tables[[1]], "first_preferences")
      fpl[[length(fpl) + 1L]] <- take(cand_tables[[length(cand_tables)]], "tcp")
    }
  }
  rs <- rbindlist(res, fill = TRUE)
  fwrite(rs, file.path(OUT, "ecsa-2010-2014-sa-page-inventory.csv"))
  for (y in c(2010, 2014)) {
    x <- rbindlist(fpl)[year == y]
    if (nrow(x)) fwrite(x, file.path(OUT, sprintf("ecsa-%d-sa-firstprefs-tcp.csv", y)))
    r <- rs[year == y]
    cat(sprintf("DQ31 SA %d: district pages listed %d, fetched %d, with a table that looks like a distribution: %d, table counts: %s\n",
                y, nrow(r), sum(r$fetched), sum(r$looks_like_distribution, na.rm = TRUE),
                paste(names(table(r$n_tables)), table(r$n_tables), sep = "x", collapse = ", ")))
  }
  invisible(rs)
}

if ("ecsa" %in% SECTIONS) run_ecsa()
if ("vec" %in% SECTIONS) run_vec()
if (length(FETCH_LOG)) {
  fl <- rbindlist(FETCH_LOG)
  cat(sprintf("\nDD99 %d download(s) failed:\n", nrow(fl))); print(fl)
}
