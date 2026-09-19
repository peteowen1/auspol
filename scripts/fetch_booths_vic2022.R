# BOOTH-LEVEL RESULTS, VICTORIA 2022: first preferences and two-candidate-
# preferred per voting centre, for the election-night model
# (docs/plans/election-night-booth-model.md).
#
# Sources, linked from every cached district results page
# (external/elections/cache/vec-2022-vic/<slug>-results.html):
#   <District> District-Results by Voting Centre.xls   one sheet: header
#       rows, a candidate header row (name\nparty), booth rows, "Total
#       Ordinary Votes", then declaration rows (Absent, Early Vote, Postal
#       Vote, Marked as Voted, Provisional), "Total Declaration Votes",
#       "TOTAL ALL VOTE TYPES".
#   .../<slug>-2cp-results-by-voting-centre                 one HTML table:
#       row 1 the two candidates, row 2 their parties, booth rows,
#       "Ordinary votes total", declaration rows, "Total".
#
# Raw files are kept (the raw-scrape rule) under
# external/reference/vec/2022/booths/; parsed long tables go to
#   output/booths-vic2022.csv      district, booth, booth_type, candidate, party, votes
#   output/booths-vic2022-2cp.csv  district, booth, booth_type, candidate, party, votes
# booth_type: ordinary | absent | early | postal | marked_as_voted | provisional
#
# Narracan (2022 poll deferred, January 2023 supplementary) has no 2022
# results page in the cache and is skipped; 87 districts.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); library(readxl) })
CACHE <- "external/elections/cache/vec-2022-vic"
RAW <- "external/reference/vec/2022/booths"; dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
pages <- list.files(CACHE, pattern = "-results[.]html$", full.names = TRUE)
stopifnot(length(pages) >= 80)

polite_get <- function(url, dest) {
  if (file.exists(dest) && file.size(dest) > 2000) return(FALSE)
  utils::download.file(url, dest, mode = "wb", quiet = TRUE); Sys.sleep(0.4); TRUE
}
decl_map <- c("absent" = "absent", "early vote" = "early", "early votes" = "early",
              "postal vote" = "postal", "postal votes" = "postal",
              "marked as voted" = "marked_as_voted", "marked as voted votes" = "marked_as_voted",
              "provisional" = "provisional", "provisional votes" = "provisional")

parse_fp <- function(f, district) {
  x <- suppressMessages(as.data.frame(read_excel(f, sheet = 1, col_names = FALSE), stringsAsFactors = FALSE))
  lab <- trimws(as.character(x[[2]])); lab[is.na(lab)] <- ""
  hdr <- which(apply(x, 1, function(r) any(grepl("\n", r, fixed = TRUE))))[1]
  stopifnot(is.finite(hdr))
  cand_cols <- which(!is.na(x[hdr, ]) & grepl("\n", as.character(x[hdr, ]), fixed = TRUE))
  cands <- vapply(cand_cols, function(j) { p <- strsplit(as.character(x[hdr, j]), "\n", fixed = TRUE)[[1]]
    c(name = trimws(p[1]), party = if (length(p) > 1) trimws(p[2]) else "") }, character(2))
  tot_ord <- which(grepl("^Total Ordinary Votes", lab))[1]; stopifnot(is.finite(tot_ord))
  booth_rows <- (hdr + 1):(tot_ord - 1); booth_rows <- booth_rows[nzchar(lab[booth_rows])]
  decl_rows <- which(tolower(lab) %in% names(decl_map))
  take <- function(rows, type) rbindlist(lapply(rows, function(i) data.table(
    district = district, booth = if (type == "ordinary") lab[i] else NA_character_,
    booth_type = if (type == "ordinary") "ordinary" else decl_map[[tolower(lab[i])]],
    candidate = cands["name", ], party = cands["party", ],
    votes = suppressWarnings(as.integer(unlist(x[i, cand_cols]))))))
  out <- rbind(take(booth_rows, "ordinary"), take(decl_rows, "decl"))
  # reconcile with the sheet's own TOTAL ALL VOTE TYPES row
  tot <- which(grepl("^TOTAL ALL VOTE TYPES", lab))[1]
  sheet_tot <- suppressWarnings(as.integer(unlist(x[tot, cand_cols])))
  ours <- out[, .(v = sum(votes, na.rm = TRUE)), by = candidate]$v
  if (!isTRUE(all(ours == sheet_tot))) stop("FB2! ", district, ": parsed totals ", paste(ours, collapse = ","), " vs sheet ", paste(sheet_tot, collapse = ","))
  out
}

parse_2cp <- function(f, district) {
  h <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl("</html>", h, fixed = TRUE)) stop("FB3! ", district, ": 2CP page truncated (no closing tag)")
  tbl <- regmatches(h, regexpr("(?s)<table.*?</table>", h, perl = TRUE))
  rows <- regmatches(tbl, gregexpr("(?s)<tr.*?</tr>", tbl, perl = TRUE))[[1]]
  cells <- lapply(rows, function(r) { cc <- regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]]
    trimws(gsub("&nbsp;|&amp;", " ", gsub("<[^>]+>", "", cc))) })
  cands <- cells[[1]][2:3]; parties <- cells[[2]][2:3]
  body <- cells[-(1:2)]
  rec <- function(cl, booth, type) data.table(district = district, booth = booth, booth_type = type,
    candidate = cands, party = parties, votes = suppressWarnings(as.integer(gsub(",", "", cl[2:3]))))
  out <- list(); for (cl in body) {
    l <- tolower(cl[1]); if (!nzchar(l) || grepl("^total|^percentage|^ordinary votes total", l)) next
    if (l %in% names(decl_map)) out[[length(out) + 1]] <- rec(cl, NA_character_, decl_map[[l]])
    else out[[length(out) + 1]] <- rec(cl, cl[1], "ordinary")
  }
  out <- rbindlist(out)
  tot_row <- body[[which(vapply(body, function(cl) tolower(cl[1]) == "total", logical(1)))[1]]]
  page_tot <- suppressWarnings(as.integer(gsub(",", "", tot_row[2:3])))
  ours <- out[, .(v = sum(votes, na.rm = TRUE)), by = candidate]$v
  if (!isTRUE(all(ours == page_tot))) stop("FB4! ", district, ": 2CP parsed totals ", paste(ours, collapse = ","), " vs page ", paste(page_tot, collapse = ","))
  out
}

FP <- list(); TCP <- list(); fetched <- 0L
for (pg in pages) {
  slug <- sub("-results[.]html$", "", basename(pg))
  h <- paste(readLines(pg, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  district <- trimws(sub(" District.*$", "", regmatches(h, regexpr("[A-Za-z' -]+ District-Results by Voting Centre", h))))
  xls_url <- regmatches(h, regexpr('https://[^"]*Results by Voting Centre[.]xls', h))
  tcp_url <- paste0("https://www.vec.vic.gov.au", regmatches(h, regexpr('/results/[^"]*2cp-results-by-voting-centre', h)))
  if (!length(xls_url) || !nzchar(district)) { cat("FB1! no booth links on ", basename(pg), "\n"); next }
  f_x <- file.path(RAW, paste0(slug, "-fp.xls")); f_t <- file.path(RAW, paste0(slug, "-2cp.html"))
  fetched <- fetched + polite_get(utils::URLencode(xls_url), f_x) + polite_get(tcp_url, f_t)
  FP[[slug]] <- parse_fp(f_x, district); TCP[[slug]] <- parse_2cp(f_t, district)
}
FP <- rbindlist(FP); TCP <- rbindlist(TCP)
cat(sprintf("FB1  %d districts, %d new downloads; FP %d rows (%d ordinary booths), 2CP %d rows (%d ordinary booths)\n",
            uniqueN(FP$district), fetched, nrow(FP), uniqueN(FP[booth_type == "ordinary", .(district, booth)]),
            nrow(TCP), uniqueN(TCP[booth_type == "ordinary", .(district, booth)])))
# booth names must agree between the two sources within a district
mism <- FP[booth_type == "ordinary", .(district, booth)][!TCP[booth_type == "ordinary", .(district, booth)], on = c("district", "booth")]
cat(sprintf("FB5  ordinary booths in FP but not in 2CP: %d\n", nrow(unique(mism))))
# vote-type shares statewide (what a night count will and will not include)
sh <- FP[, .(votes = sum(votes, na.rm = TRUE)), by = booth_type][, share := round(100 * votes / sum(votes), 1)][order(-votes)]
cat("FB6  statewide share of the first-preference vote by vote type:\n"); print(sh)
fwrite(FP, "output/booths-vic2022.csv"); fwrite(TCP, "output/booths-vic2022-2cp.csv")
cat("FB7  wrote output/booths-vic2022.csv and output/booths-vic2022-2cp.csv\n")
