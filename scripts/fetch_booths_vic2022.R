# BOOTH-LEVEL RESULTS, VICTORIA 2022: first preferences and two-candidate-
# preferred per voting centre, for the election-night model
# (docs/plans/election-night-booth-model.md).
#
# Source: two HTML pages per district, linked from every cached district
# results page (external/elections/cache/vec-2022-vic/<slug>-results.html):
#   .../<slug>-district-results-by-voting-centre       first preferences
#   .../<slug>-2cp-results-by-voting-centre            two-candidate-preferred
# Both have the same one-table shape: row 1 candidate names, row 2 parties,
# then one row per ordinary voting centre, "Ordinary votes total", the
# declaration rows (Absent, Early, Marked As Voted, Postal, Provisional
# votes), "Total", and a percentage row. Non-candidate columns (Mis-sorts,
# Informal votes, Total votes polled) have an empty row-1 cell.
#
# NOT the ".xls" the same page links: "<District>-Results by Voting
# Centre.xls" is a blob whose NAME does not carry the election, and Nepean's
# had been overwritten by the May 2026 by-election (13 booths, print date
# 08/05/2026) -- found 2026-09-19 when its booth list disagreed with the 2CP
# page. The HTML pages sit under the 2022 URL path, so the vintage is in the
# address.
#
# Raw pages are kept (the raw-scrape rule) under
# external/reference/vec/2022/booths/; parsed long tables go to
#   output/booths-vic2022.csv      district, booth, booth_type, candidate, party, votes
#   output/booths-vic2022-2cp.csv  same columns, two candidates per district
# booth_type: ordinary | absent | early | postal | marked_as_voted | provisional
#
# Narracan (2022 poll deferred, January 2023 supplementary) has no 2022
# results page in the cache and is skipped; 87 districts.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
CACHE <- "external/elections/cache/vec-2022-vic"
RAW <- "external/reference/vec/2022/booths"; dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
pages <- list.files(CACHE, pattern = "-results[.]html$", full.names = TRUE)
stopifnot(length(pages) >= 80)

polite_get <- function(url, dest) {
  if (file.exists(dest) && file.size(dest) > 2000) return(FALSE)
  utils::download.file(url, dest, mode = "wb", quiet = TRUE); Sys.sleep(0.4); TRUE
}
decl_map <- c("absent votes" = "absent", "early votes" = "early", "postal votes" = "postal",
              "marked as voted votes" = "marked_as_voted", "provisional votes" = "provisional")

parse_vc <- function(f, district, kind) {
  h <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl("</html>", h, fixed = TRUE)) stop("FB3! ", district, " ", kind, ": page truncated (no closing tag)")
  tbls <- regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
  tbl <- tbls[grepl("Voting Centres", tbls, ignore.case = TRUE)]     # 2018 pages carry two summary tables first
  if (!length(tbl)) stop("FB3! ", district, " ", kind, ": no voting-centre table")
  tbl <- tbl[1]
  rows <- regmatches(tbl, gregexpr("(?s)<tr.*?</tr>", tbl, perl = TRUE))[[1]]
  cells <- lapply(rows, function(r) {
    cc <- regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]]
    v <- gsub("<[^>]+>", "", cc)
    v <- gsub("&#39;|&rsquo;", "'", gsub("&amp;", "&", gsub("&nbsp;", " ", v)))
    trimws(v) })
  names_row <- cells[[1]]; party_row <- cells[[2]]
  cc <- which(nzchar(names_row)); cc <- cc[cc > 1]      # candidate columns: a name in row 1
  cands <- names_row[cc]; parties <- party_row[cc]
  body <- cells[-(1:2)]
  rec <- function(cl, booth, type) data.table(district = district, booth = booth, booth_type = type,
    candidate = cands, party = parties, votes = suppressWarnings(as.integer(gsub(",", "", cl[cc]))))
  out <- list(); tot <- NULL
  for (cl in body) {
    l <- tolower(cl[1])
    if (!nzchar(l) || grepl("^percentage|^ordinary votes total", l)) next
    if (l == "total") { tot <- suppressWarnings(as.integer(gsub(",", "", cl[cc]))); next }
    if (grepl("^all votes", l)) { cat("FB4  ", district, " ", kind, ": skipping row '", cl[1], "'\n", sep = ""); next }
    if (l %in% names(decl_map)) out[[length(out) + 1]] <- rec(cl, NA_character_, decl_map[[l]])
    else out[[length(out) + 1]] <- rec(cl, cl[1], "ordinary")
  }
  out <- rbindlist(out)
  if (is.null(tot)) stop("FB4! ", district, " ", kind, ": no Total row")
  ours <- out[, .(v = sum(votes, na.rm = TRUE)), by = candidate]$v
  if (all(ours == 0) && any(tot > 0)) {
    # Ripon 2018 (a recount): every booth row published as zero, only the
    # Total carries votes. No booth reference exists for that district.
    cat("FB4! ", district, " ", kind, ": booth rows all zero against a non-zero Total -- no booth-level data, district SKIPPED\n", sep = "")
    return(out[0])
  }
  if (!isTRUE(all(ours == tot))) stop("FB4! ", district, " ", kind, ": parsed totals ", paste(ours, collapse = ","), " vs page ", paste(tot, collapse = ","))
  # ROW-WIDE CHECK (review gate 2026-09-19): `cands` and `tot` are built from
  # the same column index, so a candidate whose name cell is blank would drop
  # out of BOTH sides and the check above could not see it. The page's own
  # "Total votes polled" column is independent of that index: every other
  # numeric column (candidates, mis-sorts, informal) must sum to it.
  tot_row <- body[[which(vapply(body, function(cl) tolower(cl[1]) == "total", logical(1)))[1]]]
  tv <- which(tolower(party_row) == "total votes polled")
  if (length(tv) == 1) {
    allnum <- suppressWarnings(as.integer(gsub(",", "", tot_row[-1])))
    others <- sum(allnum[-(tv - 1)], na.rm = TRUE); polled <- allnum[tv - 1]
    if (!isTRUE(others == polled)) stop("FB4! ", district, " ", kind, ": columns sum to ", others, " but Total votes polled is ", polled,
                                        " -- a column was dropped (blank name cell?) or gained")
  } else cat("FB4  ", district, " ", kind, ": no 'Total votes polled' column, row-wide check skipped\n", sep = "")
  out
}

years <- strsplit(Sys.getenv("AUSPOL_BOOTH_YEARS", "2022,2018"), ",")[[1]]
if ("2022" %in% years) {
FP <- list(); TCP <- list(); fetched <- 0L
for (pg in pages) {
  slug <- sub("-results[.]html$", "", basename(pg))
  h <- paste(readLines(pg, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  fp_path <- regmatches(h, regexpr('/results/2022[^"]*|/results/state-election-results/2022[^"]*-district-results-by-voting-centre', h))
  fp_path <- regmatches(h, regexpr('/results/state-election-results/2022-state-election-results/results-by-district/[^"]*-district-results-by-voting-centre', h))
  tcp_path <- regmatches(h, regexpr('/results/state-election-results/2022-state-election-results/results-by-district/[^"]*-2cp-results-by-voting-centre', h))
  if (!length(fp_path) || !length(tcp_path)) { cat("FB1! no booth links on ", basename(pg), "\n"); next }
  district <- gsub("-", " ", sub("-district-results-by-voting-centre$", "", basename(fp_path)))
  district <- gsub("\\b([a-z])", "\\U\\1", district, perl = TRUE)
  f_f <- file.path(RAW, paste0(slug, "-fp.html")); f_t <- file.path(RAW, paste0(slug, "-2cp.html"))
  fetched <- fetched + polite_get(paste0("https://www.vec.vic.gov.au", fp_path), f_f) +
                       polite_get(paste0("https://www.vec.vic.gov.au", tcp_path), f_t)
  FP[[slug]] <- parse_vc(f_f, district, "fp"); TCP[[slug]] <- parse_vc(f_t, district, "2cp")
}
FP <- rbindlist(FP); TCP <- rbindlist(TCP)
cat(sprintf("FB1  %d districts, %d new downloads; FP %d rows (%d ordinary booths), 2CP %d rows (%d ordinary booths)\n",
            uniqueN(FP$district), fetched, nrow(FP), uniqueN(FP[booth_type == "ordinary", .(district, booth)]),
            nrow(TCP), uniqueN(TCP[booth_type == "ordinary", .(district, booth)])))
a <- unique(FP[booth_type == "ordinary", .(district, booth)]); b <- unique(TCP[booth_type == "ordinary", .(district, booth)])
cat(sprintf("FB5  ordinary booths in FP not in 2CP: %d; in 2CP not in FP: %d\n", nrow(a[!b, on = c("district", "booth")]), nrow(b[!a, on = c("district", "booth")])))
# per-district formal totals must agree between the two pages (same vintage)
ft <- merge(FP[, .(fp = sum(votes, na.rm = TRUE)), by = district],
            TCP[candidate != "Mis-sorts", .(tcp = sum(votes, na.rm = TRUE)), by = district], by = "district")
cat(sprintf("FB5  districts whose FP and 2CP formal totals differ by more than 0.5%%: %d\n", sum(abs(ft$fp - ft$tcp) > 0.005 * ft$fp)))
sh <- FP[, .(votes = sum(votes, na.rm = TRUE)), by = booth_type][, share := round(100 * votes / sum(votes), 1)][order(-votes)]
cat("FB6  statewide share of the first-preference vote by vote type:\n"); print(sh)
fwrite(FP, "output/booths-vic2022.csv"); fwrite(TCP, "output/booths-vic2022-2cp.csv")
cat("FB7  wrote output/booths-vic2022.csv and output/booths-vic2022-2cp.csv\n")
}

# ---- 2018: the dress-rehearsal REFERENCE, from the historical-results blob ----
# The container lists publicly; per district there are
# fpvbyvotingcentre<slug>district.html and tcpbyvotingcentre<slug>district.html
# with the same table shape (after two summary tables). Parties are upper case
# there; the harness classifies them with classify_party() anyway.
if ("2018" %in% years) {
  BLOB <- "https://itsitecoreblobvecprd01.blob.core.windows.net/public-files/historical-results/state2018"
  RAW18 <- "external/reference/vec/2018/booths"; dir.create(RAW18, showWarnings = FALSE, recursive = TRUE)
  lst <- tempfile(fileext = ".xml")
  utils::download.file("https://itsitecoreblobvecprd01.blob.core.windows.net/public-files?restype=container&comp=list&prefix=historical-results/state2018/tcpbyvotingcentre&maxresults=1000", lst, quiet = TRUE)
  ll <- paste(readLines(lst, warn = FALSE), collapse = "")
  slugs <- unique(sub("^tcpbyvotingcentre(.*)district[.]html$", "\\1", regmatches(ll, gregexpr("tcpbyvotingcentre[a-z-]+district[.]html", ll))[[1]]))
  stopifnot(length(slugs) >= 85)
  FP18 <- list(); TCP18 <- list(); f18 <- 0L
  for (s in slugs) {
    district <- gsub("\\b([a-z])", "\\U\\1", gsub("-", " ", s), perl = TRUE)
    f_f <- file.path(RAW18, paste0(s, "-fp.html")); f_t <- file.path(RAW18, paste0(s, "-2cp.html"))
    f18 <- f18 + polite_get(sprintf("%s/fpvbyvotingcentre%sdistrict.html", BLOB, s), f_f) +
                 polite_get(sprintf("%s/tcpbyvotingcentre%sdistrict.html", BLOB, s), f_t)
    FP18[[s]] <- parse_vc(f_f, district, "fp"); TCP18[[s]] <- parse_vc(f_t, district, "2cp")
  }
  FP18 <- rbindlist(FP18); TCP18 <- rbindlist(TCP18)
  cat(sprintf("FB8  2018: %d districts, %d new downloads; FP %d rows (%d ordinary booths), 2CP %d rows\n",
              uniqueN(FP18$district), f18, nrow(FP18), uniqueN(FP18[booth_type == "ordinary", .(district, booth)]), nrow(TCP18)))
  fwrite(FP18, "output/booths-vic2018.csv"); fwrite(TCP18, "output/booths-vic2018-2cp.csv")
  cat("FB9  wrote output/booths-vic2018.csv and output/booths-vic2018-2cp.csv\n")
}
