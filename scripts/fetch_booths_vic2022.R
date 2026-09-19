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
  tbl <- regmatches(h, regexpr("(?s)<table.*?</table>", h, perl = TRUE))
  if (!length(tbl)) stop("FB3! ", district, " ", kind, ": no table")
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
  if (!isTRUE(all(ours == tot))) stop("FB4! ", district, " ", kind, ": parsed totals ", paste(ours, collapse = ","), " vs page ", paste(tot, collapse = ","))
  out
}

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
