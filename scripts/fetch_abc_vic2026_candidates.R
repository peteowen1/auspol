# Fetch ABC's Victorian 2026 candidate guide and keep EVERY column of it.
#
# WHY. Nominations for 28 Nov 2026 close 9 Nov, so until then the only candidate
# lists are provisional. Wikipedia's (parse_wikipedia_candidates.py) was 379
# candidacies; ABC's guide carries 489 -- ONP 78 candidates against Wikipedia's
# 30 -- so neither source alone is the list. scripts/build_candidacies.R (BC10)
# takes the UNION.
#
# Usage (one command refreshes the ABC half; then rebuild the corpus):
#   powershell.exe -Command 'Rscript "scripts/fetch_abc_vic2026_candidates.R"'
#   powershell.exe -Command 'Rscript "scripts/build_candidacies.R"'
# Offline re-parse of a saved page (no network):
#   Rscript scripts/fetch_abc_vic2026_candidates.R --offline external/reference/abc-vic2026/candidates-20261003.html
# Test into another directory: add --out-dir <dir>.
#
# STORES THE RAW PAGE, dated, before parsing (a rate-limited refetch may be
# unavailable when a later question needs another column). A download is
# accepted only if it ends with the closing </html> tag -- a size floor cannot
# tell a truncated page from a short one. The parse must produce exactly as many
# rows as the page has `<tr style="--pc` rows, or the script stops.
#
# Output columns (all kept): candidate (ABC display name without the badge),
# given, surname (ABC's own family-name span, so multi-word surnames survive),
# sitting_mp (ABC's "Sitting MP" badge), party_abbrev, seat_code, seat,
# fetched_at, source_url. Emits AB* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(xml2))

URL  <- "https://www.abc.net.au/news/elections/vic/2026/guide/candidates"
args <- commandArgs(trailingOnly = TRUE)
arg  <- function(flag) { i <- match(flag, args); if (is.na(i) || i == length(args)) NA_character_ else args[i + 1L] }
offline <- arg("--offline")
out_dir <- arg("--out-dir"); if (is.na(out_dir)) out_dir <- file.path("external", "reference", "abc-vic2026")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# A dated file is never silently replaced by different bytes: a second fetch the
# same day gets an HHMM suffix.
dated_path <- function(stem, ext, bytes = NULL) {
  p <- file.path(out_dir, sprintf("%s-%s.%s", stem, format(Sys.Date(), "%Y%m%d"), ext))
  if (file.exists(p) && !is.null(bytes) && !identical(readBin(p, "raw", file.info(p)$size), bytes))
    p <- file.path(out_dir, sprintf("%s-%s.%s", stem, format(Sys.time(), "%Y%m%d-%H%M"), ext))
  p
}

if (!is.na(offline)) {
  raw_path <- offline
  html <- readLines(raw_path, warn = FALSE, encoding = "UTF-8")
  html <- paste(html, collapse = "\n")
  stamp <- regmatches(basename(raw_path), regexpr("[0-9]{8}", basename(raw_path)))
  fetched_at <- if (length(stamp)) as.character(as.Date(stamp, "%Y%m%d")) else as.character(Sys.Date())
  cat(sprintf("AB0  OFFLINE parse of %s (fetched_at taken from its file name: %s)\n", raw_path, fetched_at))
} else {
  suppressMessages(library(httr))
  resp <- GET(URL, user_agent("auspol-research (fptpost@gmail.com)"), timeout(60))
  if (status_code(resp) != 200L) stop("AB1! HTTP ", status_code(resp), " from ", URL)
  bytes <- content(resp, "raw")
  html  <- rawToChar(bytes); Encoding(html) <- "UTF-8"
  # Closing tag, not length. 65,536 bytes once passed a size guard and parsed to nothing.
  if (!grepl("</html>\\s*$", html)) stop("AB1! response does not end with </html>: truncated (", length(bytes), " bytes)")
  raw_path <- dated_path("candidates", "html", bytes)
  writeBin(bytes, raw_path)                       # raw first, parse second
  fetched_at <- as.character(Sys.Date())
  cat(sprintf("AB0  fetched %d bytes, ends in </html>, raw saved -> %s\n", length(bytes), raw_path))
}
if (!grepl("</html>", html, fixed = TRUE)) stop("AB1! saved page has no closing </html>")

n_tr <- lengths(regmatches(html, gregexpr('<tr style="--pc', html, fixed = TRUE)))
doc  <- read_html(html)
trs  <- xml_find_all(doc, "//tr[starts-with(@style, '--pc')]")
if (length(trs) != n_tr) stop("AB2! parsed ", length(trs), " rows but the page has ", n_tr, " `<tr style=\"--pc` rows")
if (n_tr < 100L) stop("AB2! only ", n_tr, " candidate rows -- the page layout has probably changed")

txt <- function(x) trimws(gsub("[[:space:]]+", " ", xml_text(x)))
one <- function(tr) {
  cd   <- xml_find_first(tr, "./td[contains(concat(' ', normalize-space(@class), ' '), ' candidate ')]")
  fam  <- txt(xml_find_first(cd, ".//span[@class='familyname']"))
  sit  <- any(txt(xml_find_all(cd, ".//span[not(@class='familyname')]")) == "Sitting MP")
  giv  <- trimws(gsub("[[:space:]]+", " ", paste(xml_text(xml_find_all(cd, "./text()")), collapse = " ")))
  pty  <- txt(xml_find_first(tr, "./td[contains(@class, 'party')]/span"))
  a    <- xml_find_first(tr, "./td[contains(@class, 'electorate')]//a")
  href <- xml_attr(a, "href")
  data.frame(candidate = trimws(paste(giv, fam)), given = giv, surname = fam, sitting_mp = sit,
             party_abbrev = pty, seat_code = sub("^.*/guide/([^/]+)/?$", "\\1", href),
             seat = txt(a), fetched_at = fetched_at, source_url = URL, stringsAsFactors = FALSE)
}
D <- do.call(rbind, lapply(trs, one))

# Every column must be populated: an empty one means the layout moved, not that
# the data is absent.
for (cn in c("candidate", "given", "surname", "party_abbrev", "seat_code", "seat")) {
  bad <- sum(is.na(D[[cn]]) | !nzchar(D[[cn]]))
  if (bad) stop("AB3! column ", cn, " is empty on ", bad, " of ", nrow(D), " rows")
}
if (anyDuplicated(D[, c("seat_code", "candidate")])) stop("AB3! duplicate (seat, candidate) rows")
cat(sprintf("AB2  parsed %d rows == %d `<tr style=\"--pc` rows | %d seats | %d sitting MPs\n",
            nrow(D), n_tr, length(unique(D$seat_code)), sum(D$sitting_mp)))
print(table(D$party_abbrev))

csv_path <- dated_path("abc-candidates", "csv")
if (file.exists(csv_path)) {
  old <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  if (!isTRUE(all.equal(old[order(old$seat_code, old$candidate), c("candidate", "party_abbrev")],
                        D[order(D$seat_code, D$candidate), c("candidate", "party_abbrev")], check.attributes = FALSE)))
    csv_path <- file.path(out_dir, sprintf("abc-candidates-%s.csv", format(Sys.time(), "%Y%m%d-%H%M")))
}
utils::write.csv(D, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("AB4  wrote %s (%d rows, %d columns)\n", csv_path, nrow(D), ncol(D)))
