# Northern Territory Legislative Assembly results, 2012-2024, from the NT
# Electoral Commission (official) into external/elections/.
#
# WHY. The NT is the one jurisdiction left that the existing single-member,
# full-preferential candidate model can score without new machinery
# (docs/reviews/scoping-tas-nt-act-2026-10-13.md). It adds three pairs:
# nt2016 (prev nt2012), nt2020 (prev nt2016), nt2024 (prev nt2020).
#
# SOURCES, all kept raw on disk under external/reference/ntec/ (never re-fetched
# here; scripts/fetch_ntec_pages.sh downloads them, Wikipedia pages were taken
# with the MediaWiki API into wikipedia/):
#   2016, 2020, 2024  raw/div/<year>-<division>.html, one NTEC results page per
#                     division: the full distribution of preferences, the
#                     electorate summary (candidate, party code, primary, TCP)
#                     and the party-code table.
#   2012              raw/2012_la_general_election.pdf (NTEC's results book;
#                     raw/2012_la_general_election_raw.txt is `pdftotext -raw`
#                     of it) for the official first preferences and the
#                     distribution of preferences; candidate given names and
#                     the column-to-candidate mapping come from Wikipedia's
#                     results page (wikipedia/Results_of_the_2012_...wikitext),
#                     which carries every candidate's vote. Where the two
#                     disagree the NTEC number is used and the difference is
#                     printed (NTR1d).
#
# PARTY CLASS comes from classify_party() over the commission's own party
# NAME (from each page's party table), never from another source's label.
# Wikipedia files Kearney (Goyder) and Bussa (Johnston) 2012 as One Nation;
# the NTEC book lists both as "No Aff" (One Nation was not registered in the
# NT), so they are IND here.
#
# 2016 WAS OPTIONAL PREFERENTIAL (the only NT election since 2000 that was).
# Its distributions carry an "Exhausted" column. The class-to-class transfer
# file below drops exhausted ballots (build_flow_matrix() keys on recipients),
# and the detail file keeps them, so the exhaustion rate is on disk.
#
# Outputs (election_data_path()):
#   ntec-<year>-nt-candidates.csv   seat, candidate, surname, given, party_code,
#                                   party_name, fp, class, elected, tcp
#   ntec-<year>-nt-firstprefs.csv   seat, party (class), votes
#   ntec-nt-transfers.csv           election, seat, round, from, to, votes, to_n
#   ntec-nt-transfers-detail.csv    candidate-level, exhausted kept
#   ntec-nt-winners.csv             election, seat, winner (class)
#
# Emits NTR1* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xml2))

RAW <- file.path(pkg_root(), "external", "reference", "ntec")
if (!dir.exists(file.path(RAW, "raw", "div"))) stop("NTR1! raw NTEC pages missing under ", RAW)
OUT <- election_data_path()
num <- function(x) suppressWarnings(as.numeric(gsub("[^0-9.-]", "", x)))

# ---------------------------------------------------------------------------
# 2016, 2020, 2024: one HTML page per division
# ---------------------------------------------------------------------------
cell_text <- function(node) {
  tx <- trimws(xml_text(xml_find_all(node, ".//text()")))
  tx[nzchar(tx)]
}

parse_division <- function(f, year) {
  h <- read_html(f, encoding = "UTF-8")
  seat <- trimws(xml_text(xml_find_first(h, "//h1")))
  tabs <- xml_find_all(h, "//table")
  head_of <- function(t) trimws(xml_text(xml_find_first(t, "preceding::h3[1]")))
  heads <- vapply(tabs, head_of, "")
  # party code -> name
  pt <- tabs[[which(heads == "Parties")[1]]]
  prow <- xml_find_all(pt, ".//tr")[-1]
  pcode <- vapply(prow, function(r) trimws(xml_text(xml_find_all(r, "./td|./th"))[1]), "")
  pname <- vapply(prow, function(r) trimws(xml_text(xml_find_all(r, "./td|./th"))[2]), "")
  pmap <- setNames(pname, pcode)
  # electorate summary: Candidate | Party | Primary | TCP | %TCP
  st <- tabs[[which(heads == "Electorate summary")[1]]]
  srows <- lapply(xml_find_all(st, ".//tr"), function(r) trimws(xml_text(xml_find_all(r, "./td|./th"))))
  srows <- Filter(function(r) length(r) >= 3 && !r[1] %in% c("", "Candidate", "Formal", "Informal", "Total counted", "Enrolment", "Exhausted", "Vote Type"), srows)
  srows <- Filter(function(r) nzchar(r[2]) && is.finite(num(r[3])), srows)
  S <- rbindlist(lapply(srows, function(r) data.table(candidate = r[1], party_code = r[2], fp = num(r[3]),
                                                       tcp = if (length(r) >= 4) num(r[4]) else NA_real_)))
  # who won: "<Name> (<party>) elected ..." in the bold paragraph above the table
  key <- function(x) toupper(gsub("[^A-Za-z]", "", x))
  el <- xml_find_first(h, "//p/b[contains(., 'elected')]")
  if (inherits(el, "xml_missing")) {
    # Mulka 2020's page has no distribution and no "elected" line: decided on
    # first preferences, so the winner is the candidate with an absolute
    # majority -- and if nobody has one, stop rather than guess.
    wi <- which(S$fp > sum(S$fp) / 2)
    if (length(wi) != 1L) stop("no 'elected' line and no first-preference majority")
    cat(sprintf("NTR1m %d %s: no distribution on the page; %s won on first preferences (%.1f%%)\n",
                year, seat, S$candidate[wi], 100 * S$fp[wi] / sum(S$fp)))
  } else {
    wname <- trimws(sub("\\s*\\(.*$", "", xml_text(el)))
    wi <- match(key(wname), key(S$candidate))
    if (is.na(wi)) stop("NTR1! ", year, " ", seat, ": winner '", xml_text(el), "' not among the candidates")
  }
  S[, `:=`(seat = seat, party_name = unname(pmap[party_code]), elected = seq_len(.N) == wi)]
  if (anyNA(S$party_name)) stop("NTR1! ", year, " ", seat, ": party code(s) missing from the page's party table: ", paste(S$party_code[is.na(S$party_name)], collapse = ","))
  if (!"Distribution of preferences" %in% heads) return(list(S = S, cols = seq_len(nrow(S)), ev = list()))
  # distribution of preferences
  dt <- tabs[[which(heads == "Distribution of preferences")[1]]]
  rows <- xml_find_all(dt, ".//tr")
  hdr <- xml_find_all(rows[[1]], "./th|./td")
  hcells <- lapply(hdr, cell_text)
  lab <- vapply(hcells, function(x) paste(x, collapse = " "), "")
  cand_cols <- which(!lab %in% c("Count", "Comments", "Total", "Quota", "") & !grepl("^Exhausted$", lab))
  exh_col <- which(lab == "Exhausted")
  # header "Given SURNAME (PARTY)" -> match summary candidate by name with spaces removed
  hname <- vapply(hcells[cand_cols], function(x) paste(x[!grepl("^\\(.*\\)$", x)], collapse = " "), "")
  m <- match(key(hname), key(S$candidate))
  if (anyNA(m)) stop("NTR1! ", year, " ", seat, ": distribution header names not in the summary: ", paste(hname[is.na(m)], collapse = ", "))
  ev <- list()
  for (r in rows[-1]) {
    v <- trimws(xml_text(xml_find_all(r, "./td|./th")))
    if (length(v) < max(cand_cols)) next
    if (!nzchar(v[1]) || v[2] == "Progressive") next
    cnt <- as.integer(num(v[1]))
    if (!is.finite(cnt) || cnt < 2L) next
    d <- num(v[cand_cols]); d[is.na(d)] <- 0
    ex <- if (length(exh_col)) num(v[exh_col]) else 0
    if (is.na(ex)) ex <- 0
    ev[[length(ev) + 1L]] <- list(count = cnt, comment = v[2], delta = d, exhausted = ex)
  }
  list(S = S, cols = m, ev = ev)
}

split_name <- function(x) {
  # NTEC writes "Given SURNAME"; the surname is the run of upper-case words at the end
  w <- strsplit(trimws(x), "\\s+")
  sur <- vapply(w, function(z) { up <- z == toupper(z) & grepl("[A-Z]", z); paste(z[up], collapse = " ") }, "")
  giv <- vapply(w, function(z) { up <- z == toupper(z) & grepl("[A-Z]", z); paste(z[!up], collapse = " ") }, "")
  list(surname = sur, given = giv)
}

cands <- list(); tx_rows <- list(); det_rows <- list(); win_rows <- list()
add_events <- function(el, seat, Cd, ev) {
  # Cd: candidate rows in COLUMN order (class, candidate)
  for (k in seq_along(ev)) {
    e <- ev[[k]]; neg <- which(e$delta < 0)
    if (length(neg) != 1L) {
      cat(sprintf("NTR1x %s %s count %d: %d excluded columns ('%s') -- event skipped from the class transfers\n",
                  el, seat, e$count, length(neg), e$comment))
      next
    }
    rec <- which(e$delta > 0)
    det_rows[[length(det_rows) + 1L]] <<- data.table(
      election = el, seat = seat, round = k, count = e$count,
      from_candidate = Cd$candidate[neg], from_party = Cd$class[neg],
      to_candidate = c(Cd$candidate[rec], "EXHAUSTED"), to_party = c(Cd$class[rec], "EXH"),
      votes = c(e$delta[rec], e$exhausted), excluded_total = -e$delta[neg])
    if (!length(rec)) next
    # continuing candidates of each class (for to_n): every column still alive after this count
    alive <- which(seq_along(e$delta) != neg & !Cd$out_before[[k]])
    d <- data.table(cls = Cd$class[rec], v = e$delta[rec])[, .(votes = sum(v)), by = cls]
    n_alive <- table(Cd$class[alive])
    tx_rows[[length(tx_rows) + 1L]] <<- data.table(election = el, seat = seat, round = k,
      from = Cd$class[neg], to = d$cls, votes = d$votes, to_n = as.integer(n_alive[d$cls]))
  }
}

# columns excluded before count k (so to_n counts only continuing candidates)
out_before_list <- function(ev, ncol) {
  gone <- rep(FALSE, ncol); res <- vector("list", length(ev))
  for (k in seq_along(ev)) { res[[k]] <- gone; gone <- gone | ev[[k]]$delta < 0 }
  res
}

for (yr in c(2016L, 2020L, 2024L)) {
  ff <- list.files(file.path(RAW, "raw", "div"), pattern = sprintf("^%d-.*[.]html$", yr), full.names = TRUE)
  ff <- ff[!grepl("nt-summary", ff)]
  el <- sprintf("nt%d", yr)
  for (f in ff) {
    p <- tryCatch(parse_division(f, yr), error = function(e) stop("NTR1! parsing ", basename(f), ": ", conditionMessage(e)))
    S <- p$S
    nm <- split_name(S$candidate)
    S[, `:=`(surname = nm$surname, given = nm$given,
             class = classify_party(party_name, party_code), election = el)]
    cands[[length(cands) + 1L]] <- S
    Cd <- S[p$cols]
    ob <- out_before_list(p$ev, nrow(Cd))
    Cd <- list(candidate = Cd$candidate, class = Cd$class, out_before = ob)
    add_events(el, S$seat[1], Cd, p$ev)
    win_rows[[length(win_rows) + 1L]] <- data.table(election = el, seat = S$seat[1], winner = S$class[S$elected])
  }
  cat(sprintf("NTR1  %s: %d division pages parsed\n", el, length(ff)))
}

# ---------------------------------------------------------------------------
# 2012: Wikipedia candidate list, NTEC results-book numbers
# ---------------------------------------------------------------------------
wt <- readLines(file.path(RAW, "wikipedia", "Results_of_the_2012_Northern_Territory_general_election.wikitext"),
                warn = FALSE, encoding = "UTF-8")
sec <- cumsum(grepl("^=== .* ===$", wt))
W <- rbindlist(lapply(split(wt, sec)[-1], function(b) {
  seat <- trimws(gsub("=", "", b[1]))
  # first-preference boxes come before "Election box 2pp"
  cut <- which(grepl("Election box formal", b))[1]
  fpb <- if (is.na(cut)) b else b[seq_len(cut - 1L)]
  i <- which(grepl("^\\{\\{Election box candidate", fpb))
  rbindlist(lapply(i, function(j) {
    g <- function(k) { x <- fpb[j:(j + 6L)]; v <- x[grepl(paste0("^\\|", k, " *="), x)][1]; trimws(sub("^[^=]*=", "", v)) }
    cand <- gsub("\\[\\[(?:[^]|]*\\|)?([^]]*)\\]\\]", "\\1", g("candidate"), perl = TRUE)
    data.table(seat = seat, candidate = cand, wiki_party = g("party"), wiki_votes = num(g("votes")))
  }))
}))
W[is.na(wiki_party), wiki_party := ""]
cat(sprintf("NTR1w nt2012: %d Wikipedia candidates in %d divisions\n", nrow(W), uniqueN(W$seat)))
if (uniqueN(W$seat) != 25L) stop("NTR1! nt2012: expected 25 divisions in the Wikipedia results page")

rawtxt <- readLines(file.path(RAW, "raw", "2012_la_general_election_raw.txt"), warn = FALSE)
st <- which(rawtxt == "Distribution of Preferences")
ints <- function(s) { tk <- strsplit(trimws(s), "\\s+")[[1]]; tk <- tk[!grepl("%$", tk)]; num(tk[grepl("^-?[0-9]+$", tk)]) }
B <- lapply(st, function(i) {
  j <- i + 1L
  if (!grepl("^First Preference Votes", rawtxt[j])) stop("NTR1! 2012 book: unexpected line after Distribution of Preferences: ", rawtxt[j])
  fp <- ints(sub("^First Preference Votes", "", rawtxt[j]))
  tot <- fp[length(fp)]; fp <- fp[-length(fp)]
  ev <- list(); k <- j + 1L
  while (k <= length(rawtxt) && !grepl("^Total ", rawtxt[k])) {
    if (grepl(" excluded\\.", rawtxt[k])) {
      nm <- sub(" excluded\\..*$", "", rawtxt[k])
      d <- ints(sub("^.* excluded\\.", "", rawtxt[k]))
      if (length(d) != length(fp) + 1L || d[length(d)] != 0) stop("NTR1! 2012 book: malformed exclusion row: ", rawtxt[k])
      ev[[length(ev) + 1L]] <- list(count = length(ev) + 2L, comment = nm, delta = d[-length(d)], exhausted = 0)
    }
    k <- k + 1L
  }
  list(fp = fp, total = tot, ev = ev)
})
cat(sprintf("NTR1b nt2012: %d distribution blocks in the NTEC results book\n", length(B)))

# Table 1 of the book: formal votes per division (second number on the division's line)
lay <- readLines(file.path(RAW, "raw", "2012_la_general_election.txt"), warn = FALSE)
t1 <- which(grepl("Table 1:", lay))[1]; t2 <- which(grepl("Table 2a:", lay))[1]
FORMAL12 <- local({
  out <- c()
  for (ln in lay[t1:t2]) {
    m <- regmatches(ln, regexec("^([A-Z][A-Za-z ]+?)!?\\s+([0-9]+)\\s+([0-9]+)\\s+[0-9.]+%", ln))[[1]]
    if (length(m) == 4L && !trimws(m[2]) %in% c("Total")) out[trimws(m[2])] <- as.numeric(m[4])
  }
  out
})
if (length(FORMAL12) != 25L) stop("NTR1! nt2012: Table 1 gave ", length(FORMAL12), " divisions")

c12 <- list()
used <- logical(length(B))
for (s in unique(W$seat)) {
  w <- W[seat == s]
  # the block whose sorted first preferences sit within 3 votes of Wikipedia's, element by element
  hit <- which(vapply(B, function(b) length(b$fp) == nrow(w) && all(abs(sort(b$fp) - sort(w$wiki_votes)) <= 3), TRUE) & !used)
  if (!length(hit) && nrow(w) == 2L) {
    # Two candidates: no distribution in the book. Wikipedia's votes are kept only if they
    # add up to the book's formal total for the division (Table 1).
    if (!isTRUE(sum(w$wiki_votes) == FORMAL12[[s]])) stop("NTR1! nt2012 ", s, ": two-candidate seat, Wikipedia total ", sum(w$wiki_votes), " vs book formal ", FORMAL12[[s]])
    cat(sprintf("NTR1v nt2012 %s: two candidates, no distribution in the book; Wikipedia votes match the book's formal total %g\n", s, FORMAL12[[s]]))
    B[[length(B) + 1L]] <- list(fp = w$wiki_votes, total = sum(w$wiki_votes), ev = list()); used <- c(used, FALSE)
    hit <- length(B)
  }
  if (length(hit) != 1L) stop("NTR1! nt2012 ", s, ": ", length(hit), " matching distribution blocks in the NTEC book")
  used[hit] <- TRUE
  b <- B[[hit]]
  if (b$total != FORMAL12[[s]]) stop("NTR1! nt2012 ", s, ": distribution total ", b$total, " vs Table 1 formal ", FORMAL12[[s]])
  # column -> candidate by rank (ties impossible within the 3-vote tolerance unless equal; checked below)
  ord_b <- order(b$fp); ord_w <- order(w$wiki_votes)
  col_to_w <- integer(length(b$fp)); col_to_w[ord_b] <- ord_w
  w2 <- w[col_to_w]
  w2[, fp := b$fp]
  if (any(w2$fp != w2$wiki_votes))
    cat(sprintf("NTR1d nt2012 %s: NTEC differs from Wikipedia for %s -- NTEC kept\n", s,
                paste(sprintf("%s %g vs %g", w2$candidate[w2$fp != w2$wiki_votes], w2$fp[w2$fp != w2$wiki_votes],
                              w2$wiki_votes[w2$fp != w2$wiki_votes]), collapse = "; ")))
  # check the excluded surnames against the mapped columns
  # (exact containment, or within two letters of the surname: the book has WILLEY where
  # Wikipedia has Wiley -- the book's spelling is kept below)
  sur <- toupper(vapply(strsplit(w2$candidate, " "), function(z) z[length(z)], ""))
  book_sur <- rep(NA_character_, nrow(w2))
  for (e in b$ev) {
    ci <- which(e$delta < 0)
    ok <- length(ci) == 1L && (grepl(toupper(e$comment), toupper(gsub("[^A-Za-z -]", "", w2$candidate[ci])), fixed = TRUE) ||
                               utils::adist(toupper(e$comment), sur[ci]) <= 2)
    if (!ok) stop("NTR1! nt2012 ", s, ": exclusion '", e$comment, "' does not match column candidate ", w2$candidate[ci])
    if (!grepl(toupper(e$comment), toupper(w2$candidate[ci]), fixed = TRUE)) {
      cat(sprintf("NTR1s nt2012 %s: book spells %s, Wikipedia %s -- book kept\n", s, e$comment, w2$candidate[ci]))
      book_sur[ci] <- toupper(e$comment)
    }
  }
  # party names as the NTEC book has them; Wikipedia's "One Nation" and blank are NTEC's "No Aff"
  pn <- c("CLP" = "Country Liberals", "Labor NT" = "Australian Labor Party NT", "Greens NT" = "The Greens",
          "First Nations" = "First Nations Political Party", "Sex Party" = "Australian Sex Party",
          "Independent" = "Independent", "One Nation" = "No Affiliation", "Sex Party" = "Australian Sex Party")
  pc <- c("CLP" = "CLP", "Labor NT" = "ALP", "Greens NT" = "GRN", "First Nations" = "FNPP",
          "Sex Party" = "ASX", "Independent" = "IND", "One Nation" = "NOAFF")
  wp <- ifelse(nzchar(w2$wiki_party), w2$wiki_party, "One Nation")  # blank = unaffiliated, as One Nation here
  if (!all(wp %in% names(pc))) stop("NTR1! nt2012 ", s, ": unmapped Wikipedia party ", paste(setdiff(wp, names(pc)), collapse = ","))
  w2[, `:=`(party_code = unname(pc[wp]), party_name = unname(pn[wp]))]
  # "No Affiliation" classifies as OTH by name; the ballot carried no party, which is IND
  w2[, class := ifelse(party_code == "NOAFF", "IND", classify_party(party_name, party_code))]
  nm <- strsplit(w2$candidate, " ")
  w2[, `:=`(surname = toupper(vapply(nm, function(z) z[length(z)], "")),
            given = vapply(nm, function(z) paste(z[-length(z)], collapse = " "), ""),
            election = "nt2012", tcp = NA_real_)]
  w2[!is.na(book_sur), surname := book_sur[!is.na(book_sur)]]
  Cd <- list(candidate = w2$candidate, class = w2$class, out_before = out_before_list(b$ev, nrow(w2)))
  add_events("nt2012", s, Cd, b$ev)
  c12[[s]] <- w2
}
C12 <- rbindlist(c12)
# winners: Table 4 of the book (seats won by affiliation), read from the -layout text
lay <- readLines(file.path(RAW, "raw", "2012_la_general_election.txt"), warn = FALSE)
t4 <- which(grepl("Table 4: Seats won", lay)); t5 <- which(grepl("Table 5:", lay))
blk <- lay[(t4 + 1L):(t5 - 1L)]
aff <- NA_character_; WIN12 <- list()
for (ln in blk) {
  if (grepl("^Australian Labor Party", ln)) aff <- "ALP" else if (grepl("^Country Liberals", ln)) aff <- "LNP" else
    if (grepl("^Independent", ln)) aff <- "IND" else if (grepl("^Seats Won", ln)) aff <- NA_character_ else {
      m <- regmatches(ln, regexec("^([A-Z][A-Za-z ]+?)\\s{2,}([A-Z][A-Z' -]+),", ln))[[1]]
      if (length(m) == 3L && !is.na(aff)) WIN12[[length(WIN12) + 1L]] <- data.table(seat = trimws(m[2]), surname = trimws(m[3]), winner = aff)
    }
}
WIN12 <- rbindlist(WIN12)
if (nrow(WIN12) != 25L || !setequal(WIN12$seat, C12$seat)) stop("NTR1! nt2012: Table 4 gave ", nrow(WIN12), " winners")
C12[, elected := FALSE]
for (i in seq_len(nrow(WIN12))) {
  k <- which(C12$seat == WIN12$seat[i] & toupper(C12$surname) == toupper(sub(" .*$", "", WIN12$surname[i])) |
             C12$seat == WIN12$seat[i] & grepl(toupper(WIN12$surname[i]), toupper(C12$candidate), fixed = TRUE))
  if (length(unique(k)) != 1L) stop("NTR1! nt2012 ", WIN12$seat[i], ": winner ", WIN12$surname[i], " matched ", length(unique(k)), " candidates")
  C12$elected[unique(k)] <- TRUE
  if (C12$class[unique(k)] != WIN12$winner[i]) stop("NTR1! nt2012 ", WIN12$seat[i], ": book affiliation ", WIN12$winner[i], " vs class ", C12$class[unique(k)])
}
win_rows[[length(win_rows) + 1L]] <- C12[elected == TRUE, .(election = "nt2012", seat, winner = class)]
cands[[length(cands) + 1L]] <- C12[, .(candidate, party_code, fp, tcp, seat, party_name, elected, surname, given, class, election)]

# ---------------------------------------------------------------------------
# write
# ---------------------------------------------------------------------------
CA <- rbindlist(cands, use.names = TRUE, fill = TRUE)
TX <- rbindlist(tx_rows); DT <- rbindlist(det_rows); WN <- rbindlist(win_rows)
for (el in sort(unique(CA$election))) {
  y <- sub("^nt", "", el)
  x <- CA[CA$election == el]
  # every division one winner, 25 divisions
  if (uniqueN(x$seat) != 25L) stop("NTR1! ", el, ": ", uniqueN(x$seat), " divisions, expected 25")
  if (any(x[, sum(elected), by = seat]$V1 != 1L)) stop("NTR1! ", el, ": a division without exactly one winner")
  .cols <- c("seat", "candidate", "surname", "given", "party_code", "party_name", "fp", "class", "elected", "tcp")
  # 2012's results book publishes no two-candidate-preferred figures, so its tcp column was 100% empty and failed the
  # data dictionary's empty-column check (DD8!). A column with no data is left out, said here, rather than shipped empty.
  if (all(is.na(x$tcp))) { cat(sprintf("NTR3 %s: tcp column dropped (no two-candidate-preferred figures in the source)\n", y)); .cols <- setdiff(.cols, "tcp") }
  fwrite(x[, .cols, with = FALSE], file.path(OUT, sprintf("ntec-%s-nt-candidates.csv", y)))
  fp <- x[, .(votes = sum(fp)), by = .(seat, party = class)]
  fwrite(fp, file.path(OUT, sprintf("ntec-%s-nt-firstprefs.csv", y)))
  cat(sprintf("NTR2  %s: %d candidates, %d divisions, %s formal votes | %s\n", el, nrow(x), uniqueN(x$seat),
              format(sum(x$fp), big.mark = ","),
              paste(fp[, .(v = sum(votes)), by = party][order(-v), sprintf("%s %.1f%%", party, 100 * v / sum(v))], collapse = " ")))
}
fwrite(TX, file.path(OUT, "ntec-nt-transfers.csv"))
fwrite(DT, file.path(OUT, "ntec-nt-transfers-detail.csv"))
fwrite(WN, file.path(OUT, "ntec-nt-winners.csv"))
cat(sprintf("NTR3  transfers: %d class rows from %d exclusion events; detail %d rows (exhausted kept: %s votes, all nt2016)\n",
            nrow(TX), nrow(unique(TX[, .(election, seat, round)])), nrow(DT),
            format(sum(DT[to_party == "EXH"]$votes), big.mark = ",")))
print(WN[, .N, by = .(election, winner)][order(election, -N)])
