# Victoria 2010: Legislative Assembly first preferences and winners.
#
# WHY THIS EXISTS, AND WHY THE FILES ALREADY ON DISK ARE NOT IT.
# docs/NEXT-STEPS.md recorded vic2010 as recovered from eight archived
# `state2010*RegionFPVbyVC.xls` workbooks "covering all 88 districts". They do
# cover all 88 districts, and they are the WRONG HOUSE: each workbook is one
# Legislative COUNCIL region, its eleven sheets are the eleven Assembly
# districts inside that region, and every sheet lists GROUP A, GROUP B, GROUP C
# with no candidate names at all. Checked 2026-09-07 across all eleven sheets of
# one workbook: 18 GROUP rows per sheet, zero candidate rows. Upper-house votes
# tabulated by lower-house district is not lower-house data, and the file name
# does not say which house it is.
#
# The Assembly results are on the Internet Archive, in the old VEC site's
# /Results/ directory, one page per district:
#
#   web.archive.org/web/2011id_/http://www.vec.vic.gov.au/Results/
#     state2010result<District>District.html
#
# THE SNAPSHOT DATE IS PART OF THE DATA. The archive's first capture of these
# pages is 4 December 2010, five days after polling, and it holds a PROVISIONAL
# count: Albert Park reads 30,302 first preferences against a final 39,790, and
# the page carries no elected member and no formal-vote line at all. Taking the
# earliest snapshot therefore produces a complete-looking file of 88 districts
# that is three-quarters counted. So a snapshot is used only if it proves it is
# final, by carrying BOTH an elected member and a formal-vote count, and the
# earliest qualifying capture is preferred so later site rebuilds cannot creep
# in. This is why the script asks the archive for every capture of each page
# rather than one.
#
# Each page carries the elected member, the formal and informal vote counts, a
# Note mapping every party ABBREVIATION used in the table to its registered
# name, and a first-preference table of candidate, party, votes and percent.
# Independents have an EMPTY party cell rather than a label.
#
# WHAT THIS UNLOCKS. vic2010 is the missing `from` side of a vic2010 -> vic2014
# pair, worth about 88 more seat-elections and a third Victorian pair.
# scripts/backtest_candidate_vic.R already handles a target year with no anchor
# seat file, which is what 2014 is, so nothing else is needed for the pair.
#
# Emits V10* codes.

options(auspol.root = normalizePath("."))
# The Internet Archive is slow and its index for this domain is ~10 MB. R's
# default 60-second timeout kills that download part-way, and download.file()
# reports it as a warning rather than an error, so the run continues with a
# truncated file and reports "0 districts".
options(timeout = max(600, getOption("timeout")))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "vec", "2010")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

# ONE index query for the whole domain, with TIMESTAMPS and 200s only. The
# per-prefix form of this API returns nothing for this host, and the undated
# "/web/2011id_/" form redirects to the nearest snapshot -- a redirect the
# archive answers with a bare 302 carrying no Location whenever it is
# throttling, which download.file() reports as a warning and leaves as a
# missing file. Asking for the exact snapshot removes the redirect hop and with
# it most of the failures: the first attempt got 39 of 88 pages.
CDX <- paste0("http://web.archive.org/cdx/search/cdx?url=vec.vic.gov.au",
              "&matchType=domain&limit=400000&collapse=urlkey",
              "&filter=statuscode:200&fl=original,timestamp&output=text")

strip_tags <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", " ", x)))
tables_of  <- function(h) regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
rows_of    <- function(t) regmatches(t, gregexpr("(?s)<tr.*?</tr>", t, perl = TRUE))[[1]]
cells_of   <- function(r) strip_tags(regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]])
num        <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", x)))

# THE INTERNET ARCHIVE THROTTLES. Its rate limiter answers with a bare 302
# carrying no Location and no body, which download.file() reports as a warning
# and leaves as a missing or tiny file -- so a throttled run looks exactly like
# a page that does not exist. The first attempt at these 88 pages got 39 of them
# and 49 warnings. So: retry with backoff, pause between pages, and treat a
# short or unterminated file as a failure rather than as data.
grab <- function(url, dest, min_size = 2000, tries = 4L) {
  ok <- function() {
    if (!file.exists(dest) || file.info(dest)$size < min_size) return(NULL)
    h <- paste(readLines(dest, warn = FALSE), collapse = "
")
    # A SIZE FLOOR IS NOT A COMPLETENESS CHECK. CLAUDE.md records a truncated
    # download of exactly 65536 bytes clearing a `> 2000` guard, parsing to zero
    # rows and dropping a seat with nothing reported. Check the closing tag.
    if (!grepl("</html>", h, ignore.case = TRUE)) return(NULL)
    h
  }
  h <- ok()
  if (!is.null(h)) return(h)
  for (k in seq_len(tries)) {
    try(utils::download.file(url, dest, quiet = TRUE, mode = "wb",
                             headers = c("User-Agent" = UA)), silent = TRUE)
    h <- ok()
    if (!is.null(h)) return(h)
    if (file.exists(dest)) unlink(dest)
    Sys.sleep(c(3, 10, 30, 60)[min(k, 4L)])
  }
  NULL
}

# ---- the district list, taken from the archive's own index ----------------
idx <- file.path(RAW, "cdx-vec.txt")
if (!file.exists(idx) || file.info(idx)$size < 100000) {
  try(utils::download.file(CDX, idx, quiet = TRUE, headers = c("User-Agent" = UA)),
      silent = TRUE)
}
if (!file.exists(idx)) stop("Could not fetch the Internet Archive index for vec.vic.gov.au")
ix <- readLines(idx, warn = FALSE)
# Drop the printer-friendly duplicates: "...District.html?print" is the same
# page and would give a slug a second, arbitrary snapshot.
# THE HYPHEN MATTERS. South-West Coast is the only 2010 district whose name
# carries one, and a letters-only pattern silently returns 87 districts rather
# than 88 -- a count that then reads as an archive gap instead of a regex bug.
# Found by taking the authoritative 88 names from the Council workbooks, which
# are the wrong house for votes but do name every district, and diffing.
ix <- grep("state2010result[A-Za-z-]+District[.]html ", ix, value = TRUE)
SNAP <- data.table(
  slug = sub("District$", "", sub("^.*state2010result", "", sub("[.]html .*$", "", ix))),
  url  = sub(" .*$", "", ix),
  ts   = sub("^.* ", "", ix))
# PREFER www.vec.vic.gov.au. The commission served the same site under a dozen
# hostnames -- enrolmentlookup, evote, votingcentrelookup and more -- and all of
# them are in the archive index, so taking whichever row happens to come first
# picks an arbitrary mirror. 81 of the 88 districts are on the canonical host;
# the remaining 7 exist ONLY on a mirror, so the mirror is a fallback rather
# than something to exclude.
SNAP[, canon := grepl("^https?://www[.]vec[.]vic[.]gov[.]au(:80)?/", url)]
setorder(SNAP, slug, -canon)
SNAP <- unique(SNAP, by = "slug")
cat(sprintf("V10h %d of %d districts come from www.vec.vic.gov.au; %d only exist on a mirror
",
            sum(SNAP$canon), nrow(SNAP), sum(!SNAP$canon)))
slugs <- sort(SNAP$slug)
# Artefacts of the archive index, dropped BY NAME and said out loud rather than
# absorbed into a count. "Ballarat" is not a 2010 district (there were Ballarat
# East and Ballarat West) and "Oakeigh" is the commission's own misspelled link
# to Oakleigh, archived only as a 404. Filtering to status 200 already removes
# both; naming them means a future index change that reintroduces one is visible
# rather than a silently different count.
for (bogus in c("Ballarat", "Oakeigh")) {
  if (bogus %in% slugs) {
    cat(sprintf("V10a dropping the slug '%s': not a 2010 district page
", bogus))
    slugs <- setdiff(slugs, bogus)
  }
}
cat(sprintf("V101 %d district pages listed in the archive index\n", length(slugs)))
if (length(slugs) != 88L) {
  stop("Expected 88 Victorian districts in 2010 and the index lists ", length(slugs),
       ": ", paste(utils::head(slugs, 10), collapse = ", "))
}

# ---- parse one district ---------------------------------------------------
# EVERY capture of one district page, oldest first. The domain-wide index is
# collapsed to one row per URL, which is what handed us the provisional
# December 2010 capture; this asks for the full history of the one page.
snapshots_for <- function(url, slug) {
  f <- file.path(RAW, sprintf("snap-%s.txt", slug))
  # A CACHED ERROR PAGE IS NOT A SNAPSHOT LIST. The archive answers overload
  # with an nginx 504 HTML page; download.file() stores it as a normal file and
  # the next run reads it back as cached data. Eight districts failed every
  # retry for exactly this reason. A snapshot list is 14-digit timestamps, so
  # anything else is discarded rather than trusted.
  if (file.exists(f) && !any(grepl("^[0-9]{14}", readLines(f, warn = FALSE))))
    unlink(f)
  if (!file.exists(f) || file.info(f)$size < 10) {
    q <- sprintf(paste0("http://web.archive.org/cdx/search/cdx?url=%s",
                        "&output=text&fl=timestamp,statuscode&filter=statuscode:200&limit=40"),
                 # The port must go. The archive stores these as
                 # "www.vec.vic.gov.au:80/..." and its index API returns NOTHING
                 # for a URL carrying an explicit port, silently -- an empty
                 # result that reads as "no snapshots" rather than as a bad
                 # query. The replay URL keeps the port quite happily.
                 sub("^https?://", "", sub(":80/", "/", url, fixed = TRUE)))
    for (k in 1:3) {
      try(utils::download.file(q, f, quiet = TRUE, headers = c("User-Agent" = UA)),
          silent = TRUE)
      if (file.exists(f) && file.info(f)$size >= 10) break
      Sys.sleep(c(3, 10, 30)[k])
    }
  }
  if (!file.exists(f)) return(character(0))
  ts <- sub(" .*$", "", readLines(f, warn = FALSE))
  ts <- ts[grepl("^[0-9]{14}$", ts)]
  sort(unique(ts[nzchar(ts)]))
}

# A page is FINAL only if it says so: an elected member and a formal-vote count.
# The provisional captures have neither, and a check that merely skips a
# district with no formal-vote figure passes on exactly the pages it exists to
# reject -- the escape-hatch guard CLAUDE.md warns about, which is how the
# provisional file cleared this script on its first run.
is_final <- function(h) {
  grepl("electedParty", h, fixed = TRUE) && grepl("Formal Votes:", h, fixed = TRUE)
}

parse_district <- function(slug) {
  want <- slug
  r <- SNAP[SNAP$slug == want, ]
  if (!nrow(r)) return(NULL)
  f <- file.path(RAW, sprintf("result-%s.html", slug))
  h <- NULL
  if (file.exists(f)) {
    hh <- paste(readLines(f, warn = FALSE), collapse = "
")
    if (grepl("</html>", hh, ignore.case = TRUE) && is_final(hh)) h <- hh
  }
  if (is.null(h)) {
    for (ts in snapshots_for(r$url[1], slug)) {
      if (ts < "2011") next        # the provisional captures are all 2010
      hh <- grab(sprintf("https://web.archive.org/web/%sid_/%s", ts, r$url[1]), f)
      if (!is.null(hh) && is_final(hh)) { h <- hh; break }
      if (file.exists(f)) unlink(f)
      Sys.sleep(1)
    }
  }
  if (is.null(h)) {
    cat(sprintf("V10! %s: no archived capture is a FINAL result page
", slug))
    return(NULL)
  }

  seat <- strip_tags(regmatches(h, regexpr("(?s)<h1[^>]*>.*?</h1>", h, perl = TRUE)))
  seat <- trimws(sub(".*:", "", seat))
  seat <- trimws(sub(" District$", "", seat))
  if (!nzchar(seat)) return(NULL)

  # The abbreviation -> registered-name map printed on the page itself. Passing
  # a bare code to classify_party() with no name is not a partial mapping, it is
  # a wrong one: an unrecognised code leaves the name empty and the classifier
  # buckets every such party as IND. That is how four real parties became
  # independents in the New South Wales fetcher.
  note <- regmatches(h, regexpr("(?s)Note:.*?</div>", h, perl = TRUE))
  lut <- character(0)
  if (length(note)) {
    txt <- strip_tags(note)
    txt <- sub("^Note: *", "", txt)
    txt <- sub(" Recheck first preference votes.*$", "", txt)
    parts <- strsplit(txt, ", *(?=[^,=]+ = )", perl = TRUE)[[1]]
    kv <- regmatches(parts, regexpr("^[^=]+ = ", parts))
    ok <- vapply(regexpr("^[^=]+ = ", parts), function(z) z > 0L, logical(1))
    if (any(ok)) {
      lut <- stats::setNames(trimws(sub("^[^=]+ = ", "", parts[ok])),
                             trimws(sub(" = $", "", kv)))
    }
  }

  tb <- Filter(function(t) grepl("title=\"First preference votes\"", t), tables_of(h))
  if (!length(tb)) return(NULL)
  rr <- lapply(rows_of(tb[[1]]), cells_of)
  rr <- Filter(function(c) length(c) == 4L && !identical(c[1], "Candidate"), rr)
  if (!length(rr)) return(NULL)
  d <- data.table(seat = seat,
                  candidate = vapply(rr, function(z) z[1], character(1)),
                  code = vapply(rr, function(z) z[2], character(1)),
                  votes = num(vapply(rr, function(z) z[3], character(1))))
  d <- d[is.finite(votes) & nzchar(candidate)]
  if (!nrow(d)) return(NULL)

  # The page's own formal-vote count, kept for a cross-check rather than trusted.
  # ONLY THE FIRST NUMBER AFTER THE LABEL. A fixed 200-character window swept
  # up the informal and total counts too, and num() strips non-digits from the
  # WHOLE window, so three numbers became one 21-digit value. It failed on
  # exactly the 7 districts served from a mirror host, whose markup spaces the
  # summary differently -- so the check fired on the pages most likely to differ,
  # which is the right outcome from the wrong cause. The first-preference sums
  # were correct throughout; it was the thing they were checked against that
  # was wrong.
  fv <- regmatches(h, regexpr("Formal Votes:[^0-9]{0,80}[0-9][0-9,]*", h))
  d[, formal := if (length(fv)) num(regmatches(fv, regexpr("[0-9][0-9,]*$", fv))) else NA_real_]

  # The elected member's name and party sit in two adjacent spans. Read each
  # span's inner text directly rather than stripping tags first: strip_tags()
  # turns the markup between them into whitespace, so there is no longer a
  # boundary to split the two values on.
  nm <- regmatches(h, regexpr("(?s)labelBlackBold\">[^<]*", h, perl = TRUE))
  pt <- regmatches(h, regexpr("(?s)electedParty\">[^<]*", h, perl = TRUE))
  d[, winner_name := if (length(nm)) trimws(sub("^[^>]*>", "", nm[1])) else NA_character_]
  d[, winner_party := if (length(pt)) trimws(sub("^[^>]*>", "", pt[1])) else NA_character_]
  d[, full := ifelse(nzchar(code), unname(lut[code]), "")]
  d[, unmapped := nzchar(code) & is.na(full)]
  d[]
}

cat("V102 fetching 88 district pages from the Internet Archive (slow; cached on disk)\n")
all <- rbindlist(lapply(seq_along(slugs), function(i) {
  if (i %% 10L == 0L) cat(sprintf("V102  ... %d of %d
", i, length(slugs)))
  d <- parse_district(slugs[i])
  Sys.sleep(1.5)
  d
}), fill = TRUE)
got <- unique(all$seat)
cat(sprintf("V102 parsed %d districts, %d candidate rows\n", length(got), nrow(all)))
if (length(got) != 88L) {
  stop("Parsed ", length(got), " districts, not 88. Missing slug(s): ",
       paste(utils::head(setdiff(slugs, gsub(" ", "", got)), 10), collapse = ", "))
}

bad <- unique(all[unmapped == TRUE, .(code)])
if (nrow(bad)) {
  stop("Party code(s) in the 2010 result tables with no registered name in the ",
       "page's own Note: ", paste(bad$code, collapse = ", "),
       ". Classifying them without a name would silently make them IND.")
}
n_ind <- all[!nzchar(code), .N]
cat(sprintf("V103 %d candidate rows have an EMPTY party cell; those are independents by construction\n",
            n_ind))

all[, party := classify_party(ifelse(nzchar(full), full, ""), code)]

# Every district's first preferences must add to the formal votes it reports.
# A per-district total that disagrees means a row was dropped by the parser,
# which is exactly the failure a row count cannot see.
# NO is.finite() ESCAPE HATCH. A district whose page carries no formal-vote
# figure is UNVERIFIABLE, not passing, and counting it as passing is how a
# three-quarters-counted file cleared this check on the first run.
chk <- all[, .(sum_votes = sum(votes), formal = formal[1]), by = seat][
  !is.finite(formal) | sum_votes != formal]
if (nrow(chk)) {
  stop("First preferences do not add to the page's own formal-vote count in ",
       nrow(chk), " district(s): ",
       paste(sprintf("%s %.0f vs %.0f", chk$seat, chk$sum_votes, chk$formal),
             collapse = "; "))
}
cat("V104 every district's first preferences add to the formal-vote count it reports\n")

fp <- all[, .(votes = sum(votes)), by = .(seat, party)]
fwrite(fp[order(seat, party)], file.path(OUT, "vec-2010-vic-firstprefs.csv"))
cat(sprintf("V105 wrote %s (%d rows, %d seats)\n",
            file.path(OUT, "vec-2010-vic-firstprefs.csv"), nrow(fp), uniqueN(fp$seat)))

st <- fp[, .(v = sum(votes)), by = party][, pct := round(100 * v / sum(v), 2)][order(-pct)]
cat("\nV106 statewide first preferences\n")
print(st)

win <- unique(all[, .(seat, winner_name, winner_party)])
# classify_party() requires code to be the same length as name, so the empty
# code has to be a vector, not a scalar.
win[, winner := classify_party(winner_party, rep("", .N))]
if (any(is.na(win$winner) | !nzchar(win$winner))) {
  stop("Could not classify the elected member's party in ",
       sum(is.na(win$winner) | !nzchar(win$winner)), " district(s)")
}
fwrite(win[order(seat), .(election = "vic2010", seat, winner, winner_name)],
       file.path(OUT, "vec-2010-vic-winners.csv"))
cat(sprintf("\nV107 wrote %s\n", file.path(OUT, "vec-2010-vic-winners.csv")))
print(win[, .N, by = winner][order(-N)])
