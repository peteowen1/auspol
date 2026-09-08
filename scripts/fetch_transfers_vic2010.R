# Victoria 2010: preference distributions, for the flow matrix a vic2010 ->
# vic2014 pair needs.
#
# Run scripts/fetch_preferences_vic2010.R FIRST. This script reads the result
# pages that one caches, because the distribution pages identify candidates by
# NAME ONLY and the party is on the result page. A name with no party would
# reach classify_party() with an empty name and be bucketed as IND, which is
# how four real parties became independents in the New South Wales fetcher.
#
# COVERAGE IS PARTIAL AND THAT IS STATED, NOT HIDDEN. The Internet Archive holds
# distribution pages for 43 of the 88 districts. A flow matrix is pooled across
# seats, so 43 districts still yield thousands of transfer observations, but a
# flow estimated from half a chamber is not the same object as one estimated
# from all of it. The coverage is printed and written into the output so a later
# reader cannot mistake one for the other.
#
# Emits VT* codes.

options(auspol.root = normalizePath("."))
options(timeout = max(600, getOption("timeout")))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "vec", "2010")
OUT <- election_data_path()

strip_tags <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", " ", x)))
tables_of  <- function(h) regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
rows_of    <- function(t) regmatches(t, gregexpr("(?s)<tr.*?</tr>", t, perl = TRUE))[[1]]
cells_of   <- function(r) strip_tags(regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]])
num        <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", x)))

grab <- function(url, dest, min_size = 2000, tries = 4L) {
  ok <- function() {
    if (!file.exists(dest) || file.info(dest)$size < min_size) return(NULL)
    h <- paste(readLines(dest, warn = FALSE), collapse = "\n")
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

idx <- file.path(RAW, "cdx-vec.txt")
if (!file.exists(idx)) {
  stop("Run scripts/fetch_preferences_vic2010.R first: it caches the Internet ",
       "Archive index this script reads, at ", idx)
}
ix <- readLines(idx, warn = FALSE)

# ---- candidate -> party, from the cached result pages ---------------------
res_files <- list.files(RAW, pattern = "^result-.*[.]html$", full.names = TRUE)
if (length(res_files) < 88L) {
  stop("Only ", length(res_files), " of 88 cached result pages found in ", RAW,
       ". Run scripts/fetch_preferences_vic2010.R to completion first: without ",
       "every district's candidate-to-party map, a name that fails to match ",
       "would be classified from an empty party name and silently become IND.")
}
who <- rbindlist(lapply(res_files, function(f) {
  h <- paste(readLines(f, warn = FALSE), collapse = "\n")
  seat <- strip_tags(regmatches(h, regexpr("(?s)<h1[^>]*>.*?</h1>", h, perl = TRUE)))
  seat <- trimws(sub(" District$", "", trimws(sub(".*:", "", seat))))
  note <- regmatches(h, regexpr("(?s)Note:.*?</div>", h, perl = TRUE))
  lut <- character(0)
  if (length(note)) {
    txt <- sub(" Recheck first preference votes.*$", "", sub("^Note: *", "", strip_tags(note)))
    parts <- strsplit(txt, ", *(?=[^,=]+ = )", perl = TRUE)[[1]]
    kv <- regmatches(parts, regexpr("^[^=]+ = ", parts))
    ok <- vapply(regexpr("^[^=]+ = ", parts), function(z) z > 0L, logical(1))
    if (any(ok)) lut <- stats::setNames(trimws(sub("^[^=]+ = ", "", parts[ok])),
                                        trimws(sub(" = $", "", kv)))
  }
  tb <- Filter(function(t) grepl("title=\"First preference votes\"", t), tables_of(h))
  if (!length(tb)) return(NULL)
  rr <- Filter(function(c) length(c) == 4L && !identical(c[1], "Candidate"),
               lapply(rows_of(tb[[1]]), cells_of))
  if (!length(rr)) return(NULL)
  code <- vapply(rr, function(z) z[2], character(1))
  full <- ifelse(nzchar(code), unname(lut[code]), "")
  data.table(seat = seat,
             candidate = vapply(rr, function(z) z[1], character(1)),
             party = classify_party(ifelse(is.na(full), "", full), code))
}))
cat(sprintf("VT1  candidate-to-party map: %d candidates across %d districts\n",
            nrow(who), uniqueN(who$seat)))

# ---- the distribution pages that survive ----------------------------------
dx <- grep("state2010distribution[A-Za-z-]+District[.]html ", ix, value = TRUE)
SNAP <- unique(data.table(
  slug = sub("District$", "", sub("^.*state2010distribution", "", sub("[.]html .*$", "", dx))),
  url  = sub(" .*$", "", dx),
  ts   = sub("^.* ", "", dx)), by = "slug")
cat(sprintf("VT1  %d of 88 districts have an archived distribution page (%.0f%%)\n",
            nrow(SNAP), 100 * nrow(SNAP) / 88))

parse_dop <- function(i) {
  # A DIFFERENTLY-NAMED LOCAL is not needed here because SNAP is indexed by
  # position rather than filtered on a column, which is the safer shape: no
  # bare symbol ever reaches the `i` expression.
  r <- SNAP[i, ]
  f <- file.path(RAW, sprintf("dop-%s.html", r$slug))
  h <- grab(sprintf("https://web.archive.org/web/%sid_/%s", r$ts, r$url), f)
  if (is.null(h)) return(NULL)
  # ANYTHING AFTER "District" GOES TOO. The distribution page's heading reads
  # "Albert Park District Distribution of preference votes", so an anchored
  # sub(" District$", ...) strips nothing and the seat name never matches the
  # result page's. That failure showed up as eight candidates with no party,
  # which reads as a name-matching problem rather than a seat-naming one.
  seat <- strip_tags(regmatches(h, regexpr("(?s)<h1[^>]*>.*?</h1>", h, perl = TRUE)))
  seat <- trimws(sub(" District.*$", "", trimws(sub(".*:", "", seat))))

  tb <- Filter(function(t) grepl("title=\"Distribution of preference votes\"", t),
               tables_of(h))
  if (!length(tb)) return(NULL)
  rr <- lapply(rows_of(tb[[1]]), cells_of)
  hdr <- rr[[1]]
  cand <- hdr[-c(1, length(hdr))]          # drop the label column and TOTAL
  out <- list(); round <- 0L
  for (k in seq_along(rr)[-1]) {
    lab <- rr[[k]][1]
    if (!grepl("^Transfer of ", lab)) next
    round <- round + 1L
    from_name <- trimws(sub(".*ballot-papers of (.*) [(].*", "\\1", lab))
    vals <- num(rr[[k]][-c(1, length(rr[[k]]))])
    tot  <- num(rr[[k]][length(rr[[k]])])
    # The row's own TOTAL is the check: a parser that loses a column still
    # produces a plausible set of transfers, and only the total disagrees.
    if (!is.finite(tot) || abs(sum(vals, na.rm = TRUE) - tot) > 0) {
      stop(seat, " round ", round, ": transfers sum to ",
           sum(vals, na.rm = TRUE), " and the row's own total says ", tot)
    }
    keep <- is.finite(vals) & vals > 0
    if (!any(keep)) next
    out[[length(out) + 1L]] <- data.table(
      seat = seat, round = round, from_name = from_name,
      to_name = cand[keep], votes = vals[keep])
  }
  if (!length(out)) return(NULL)
  rbindlist(out)
}

cat("VT2  fetching distribution pages\n")
tx <- rbindlist(lapply(seq_len(nrow(SNAP)), function(i) {
  if (i %% 10L == 0L) cat(sprintf("VT2  ... %d of %d\n", i, nrow(SNAP)))
  d <- parse_dop(i)
  Sys.sleep(1.5)
  d
}), fill = TRUE)
cat(sprintf("VT2  parsed %d districts, %d transfer rows\n",
            uniqueN(tx$seat), nrow(tx)))

# ---- attach parties, refusing on any unmatched name -----------------------
tx <- merge(tx, who[, .(seat, from_name = candidate, from = party)],
            by = c("seat", "from_name"), all.x = TRUE)
tx <- merge(tx, who[, .(seat, to_name = candidate, to = party)],
            by = c("seat", "to_name"), all.x = TRUE)
miss <- tx[is.na(from) | is.na(to)]
if (nrow(miss)) {
  stop("Candidate name(s) in a distribution table with no match on the result ",
       "page for the same district: ",
       paste(utils::head(unique(c(miss$from_name, miss$to_name)), 8), collapse = ", "),
       ". Classifying them without a party would silently make them IND.")
}

# The election label is added as a COLUMN before grouping. A length-1 constant
# inside `by` is not recycled by data.table; it errors on the length mismatch.
tx[, election := "vic2010"]
res <- tx[, .(votes = sum(votes)), by = .(election, seat, round, from, to)]
setcolorder(res, c("election", "seat", "round", "from", "to", "votes"))
fwrite(res[order(seat, round, from, to)], file.path(OUT, "vec-2010-vic-transfers.csv"))
cat(sprintf("\nVT3  wrote %s: %d rows, %d districts, %s votes moved\n",
            file.path(OUT, "vec-2010-vic-transfers.csv"), nrow(res),
            uniqueN(res$seat), format(sum(res$votes), big.mark = ",")))
cat(sprintf("VT3  COVERAGE: %d of 88 districts (%.0f%%). A flow matrix from this file\n",
            uniqueN(res$seat), 100 * uniqueN(res$seat) / 88))
cat("VT3  is estimated from half the chamber, not all of it. Say so when quoting it.\n")
print(res[, .(votes = sum(votes)), by = from][order(-votes)])
