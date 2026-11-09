# The VEC's final Lower House candidate list, from its WEBSITE: one "<district> candidates" page per district, in
# ballot-paper order, with each candidate's party (no party line = independent).
#
#   Rscript scripts/fetch_vec_candidates_web.R --year=2026 [--out=<dir>] [--from=<folder of saved pages>]
#
# Why (9 Nov 2026): nominations closed at noon and the VEC published the list on its district pages that evening,
# while the media-feed set-up file (`*MediaFileCandidates*.xml`, scripts/fetch_vec_candidates.R) needs feed access
# the VEC has not yet granted. Same official source, same output: external/reference/vec/<year>/vec-candidates-<year>.csv
# with the XML loader's columns (ids the website does not carry are NA), so scripts/build_candidacies.R and
# scripts/nomination_day.sh read it unchanged. When the XML arrives, rerun fetch_vec_candidates.R: it overwrites
# this file with the feed's richer copy, and the two must agree (same names, order and parties).
#
# Raw pages are kept exactly as received under external/reference/vec/<year>/web/<stamp>/ (the district index, all 88
# district pages and the all-candidates spreadsheet the pages link to). --from=<that folder> re-parses a saved copy
# with no network. The spreadsheet carries names but no party; it is the cross-check that the pages are complete.
suppressPackageStartupMessages({ library(data.table); library(xml2) })
a <- commandArgs(trailingOnly = TRUE)
arg <- function(k, d = NULL) { v <- sub(paste0("^--", k, "="), "", a[startsWith(a, paste0("--", k, "="))]); if (length(v)) v[1] else d }
yr <- arg("year"); if (is.null(yr)) stop("usage: fetch_vec_candidates_web.R --year=<YYYY> [--out=<dir>] [--from=<saved folder>]")
out_dir <- arg("out", file.path("external", "reference", "vec", yr))
from <- arg("from")
BASE <- "https://www.vec.vic.gov.au"
UA <- "auspol election forecast (research; contact via github.com/peteowen1/auspol)"

get <- function(url, dest) {
  h <- curl::new_handle(useragent = UA, followlocation = TRUE)
  curl::curl_download(url, dest, handle = h, quiet = TRUE)
  Sys.sleep(0.5)   # polite: one request at a time, half a second apart
  dest
}

if (is.null(from)) {
  raw_dir <- file.path(out_dir, "web", format(Sys.time(), "%Y%m%d-%H%M"))
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  get(paste0(BASE, "/electoral-boundaries/state-districts"), file.path(raw_dir, "state-districts.html"))
} else raw_dir <- from
idx <- read_html(file.path(raw_dir, "state-districts.html"))
slugs <- unique(sub("^.*/state-districts/", "", grep("/state-districts/[a-z-]+-district$", xml_attr(xml_find_all(idx, "//a"), "href"), value = TRUE)))
cat(sprintf("VW1  district links on the index: %d\n", length(slugs)))
if (length(slugs) != 88L) stop("VW1! ", length(slugs), " district links, Victoria has 88")

pages <- file.path(raw_dir, paste0(slugs, "-nominations.html"))
if (is.null(from)) for (i in seq_along(slugs))
  get(sprintf("%s/electoral-boundaries/state-districts/%s/nominations", BASE, slugs[i]), pages[i])
miss <- pages[!file.exists(pages)]
if (length(miss)) stop("VW2! missing saved page(s): ", paste(basename(miss), collapse = ", "))

rows <- rbindlist(lapply(seq_along(pages), function(i) {
  txt <- readLines(pages[i], warn = FALSE, encoding = "UTF-8")
  # a size floor is not a completeness check: the closing tag is (CLAUDE.md, the 65536-byte truncation)
  if (!any(grepl("</html>", txt, fixed = TRUE))) stop("VW2! ", basename(pages[i]), " has no closing </html>: truncated")
  doc <- read_html(pages[i])
  h1 <- trimws(xml_text(xml_find_first(doc, "//h1")))
  tr <- xml_find_all(doc, "//tr[contains(concat(' ', normalize-space(@class), ' '), ' candidate-row ') and td]")
  if (!length(tr)) stop("VW3! no candidate rows on ", basename(pages[i]), " (", h1, "): the list is not up yet, or the page changed")
  td1 <- lapply(tr, function(r) xml_find_first(r, "td"))
  nm <- vapply(td1, function(td) trimws(paste(xml_text(xml_find_all(td, "text()")), collapse = " ")), "")
  pa <- vapply(td1, function(td) { p <- xml_find_first(td, "p"); if (inherits(p, "xml_missing")) "" else trimws(xml_text(p)) }, "")
  data.table(slug = slugs[i], heading = h1, ballot_position = seq_along(tr), name = gsub("\\s+", " ", nm), party_web = pa)
}))
# Headings are not uniform ("Ringwood District candidates", "Candidates for Albert Park District", and on 9 Nov
# "Lowan District canddiates"), so take the words before "District" and check them against the page's address.
rows[, district := trimws(sub(" District.*$", "", sub("^Candidates for ", "", heading)))]
.lk <- function(x) gsub("[^a-z]", "", tolower(x))
bad_h <- unique(rows[.lk(district) != .lk(sub("-district$", "", slug)), .(slug, heading)])
if (nrow(bad_h)) stop("VW4! heading and address disagree: ", paste(bad_h$slug, bad_h$heading, sep = " / ", collapse = "; "))
rows[, independent := ifelse(nzchar(party_web), "no", "yes")]
rows[, registered_name := ifelse(nzchar(party_web), party_web, NA_character_)]
# one fingerprint for the whole set of pages: the md5 of their sorted md5s
.mf <- tempfile(); writeLines(sort(unname(tools::md5sum(pages))), .mf); md5 <- unname(tools::md5sum(.mf)); unlink(.mf)

# ---- checks: say what is wrong, never write a partial list ------------------------------------------------------
nd <- uniqueN(rows$district)
cat(sprintf("VW4  %d Lower House candidates in %d districts\n", nrow(rows), nd))
if (nd != 88L) stop("VW4! ", nd, " districts, Victoria has 88")
if (any(!nzchar(rows$name))) stop("VW5! candidate(s) with no name")
# A person with one registered name has no comma (9 Nov: "DAVINDER KAUR"); allowed, and said out loud.
if (!all(grepl(",", rows$name)))
  cat(sprintf("VW5  %d name(s) not in 'SURNAME, Given' form (kept as listed): %s\n", sum(!grepl(",", rows$name)),
              paste(rows$district[!grepl(",", rows$name)], rows$name[!grepl(",", rows$name)], sep = "/", collapse = "; ")))
.pk <- paste(tolower(rows$district), gsub("[^a-z]", "", tolower(sub(",.*$", "", rows$name))),
             substr(gsub("[^a-z]", "", tolower(sub("^[^,]*,", "", rows$name))), 1, 1))
if (anyDuplicated(.pk)) stop("VW7! two candidates in one district share surname and first initial: ",
                             paste(rows$district[duplicated(.pk) | duplicated(.pk, fromLast = TRUE)], rows$name[duplicated(.pk) | duplicated(.pk, fromLast = TRUE)], collapse = "; "))

# Cross-check against the all-candidates spreadsheet the pages link to (names only; it also lists the Upper House).
xl_href <- unique(unlist(lapply(pages[1], function(p) grep("[.]xlsx?$", xml_attr(xml_find_all(read_html(p), "//a"), "href"), value = TRUE))))
xl <- file.path(raw_dir, "all-candidates.xls")
if (is.null(from) && length(xl_href)) get(paste0(BASE, xl_href[1]), xl)
if (file.exists(xl)) {
  X <- as.data.table(readxl::read_excel(xl, col_names = FALSE, col_types = "text"))
  v1 <- X[[1]]
  asat <- grep("^As at ", v1, value = TRUE)[1]
  hd <- grep(" District$", v1)                      # Lower House block headers ("Albert Park District")
  sx <- rbindlist(lapply(hd, function(h) {
    j <- h + 3L; nm <- character(0)                 # header, "(1 vacancy, n candidates)", "Candidates" row, then names
    while (j <= length(v1) && !is.na(v1[j]) && nzchar(v1[j])) { nm <- c(nm, v1[j]); j <- j + 1L }
    data.table(district = sub(" District$", "", v1[h]), name = nm)
  }))
  cat(sprintf("VW8  spreadsheet (%s): %d Lower House names in %d districts\n", asat, nrow(sx), uniqueN(sx$district)))
  k1 <- paste(rows$district, rows$name); k2 <- paste(sx$district, sx$name)
  if (!setequal(k1, k2)) stop("VW8! pages and spreadsheet disagree. Only on pages: ", paste(head(setdiff(k1, k2), 8), collapse = "; "),
                              " | only in spreadsheet: ", paste(head(setdiff(k2, k1), 8), collapse = "; "))
  cat("VW8  pages and spreadsheet list the same candidates in every district\n")
} else stop("VW8! no all-candidates spreadsheet linked or saved: completeness cannot be cross-checked, so nothing is written")

cat(sprintf("VW9  %d independents; parties: %s\n", sum(rows$independent == "yes"),
            paste(sprintf("%s %d", names(sort(table(rows$registered_name), decreasing = TRUE)), sort(table(rows$registered_name), decreasing = TRUE)), collapse = "; ")))
rows[, `:=`(year = as.integer(yr), affiliation_id = NA_character_, candidate_id = NA_character_, contest_id = NA_character_,
            contest_name = paste(district, "District"), polling_district_id = NA_character_, enrolment = NA_integer_,
            elected_historic = NA_character_, event = paste("State Election", yr), source_file = paste0("web:", basename(raw_dir)),
            source_md5 = md5)]
rows <- rows[, c("year", "district", "ballot_position", "name", "independent", "registered_name", "affiliation_id",
                 "candidate_id", "contest_id", "contest_name", "polling_district_id", "enrolment", "elected_historic",
                 "event", "source_file", "source_md5"), with = FALSE]
setorder(rows, district, ballot_position)
out <- file.path(out_dir, sprintf("vec-candidates-%s.csv", yr))
tmp <- paste0(out, ".tmp"); fwrite(rows, tmp)
back <- fread(tmp, showProgress = FALSE)
if (nrow(back) != nrow(rows)) stop("VW9! read-back has ", nrow(back), " rows, wrote ", nrow(rows))
if (!file.rename(tmp, out)) stop("VW9! could not move ", tmp, " to ", out)
cat(sprintf("VW9  wrote %s (%d rows) from %s\n", out, nrow(rows), raw_dir))
