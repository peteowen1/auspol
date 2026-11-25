# The 2026 Legislative Council (upper house) groups, by region, in ballot order, from the VEC's nomination pages.
#
#   Rscript scripts/build_council_groups_2026.R [--from=<saved folder>]
# Fetches the 8 region nomination pages (one request each, half a second apart), saves each page exactly as received
# under external/reference/vec/2026/web-regions/<stamp>/, then parses the saved copies. --from re-parses a saved folder.
# Out: external/reference/vec/2026/council-groups-2026.csv      one row per group: region, letter, group, candidates, class
#      external/reference/vec/2026/council-candidates-2026.csv  one row per candidate: region, letter, group, position, name
# Check codes: CG1! (a page is missing, truncated or has no groups), CG2! (counts do not match the page), CG3 (summary).
suppressPackageStartupMessages({library(data.table); library(xml2)})
a <- commandArgs(trailingOnly = TRUE)
arg <- function(k, d = NULL) { v <- sub(paste0("^--", k, "="), "", a[startsWith(a, paste0("--", k, "="))]); if (length(v)) v[1] else d }
BASE <- "https://www.vec.vic.gov.au/electoral-boundaries/state-regions"
UA <- "auspol election forecast (research; contact via github.com/peteowen1/auspol)"
SLUGS <- c("eastern-victoria", "north-eastern-metropolitan", "northern-metropolitan", "northern-victoria",
           "south-eastern-metropolitan", "southern-metropolitan", "western-metropolitan", "western-victoria")
out_dir <- file.path("external", "reference", "vec", "2026")
raw_dir <- arg("from")
if (is.null(raw_dir)) {
  raw_dir <- file.path(out_dir, "web-regions", format(Sys.time(), "%Y%m%d-%H%M"))
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  for (s in SLUGS) {
    curl::curl_download(sprintf("%s/%s-region/nominations", BASE, s), file.path(raw_dir, paste0(s, "-region-nominations.html")),
                        handle = curl::new_handle(useragent = UA, followlocation = TRUE), quiet = TRUE)
    Sys.sleep(0.5)
  }
}
sq <- function(x) trimws(gsub("[[:space:]]+", " ", x))
has_class <- function(node, cl) grepl(paste0("(^| )", cl, "( |$)"), xml_attr(node, "class"))
one <- function(s) {
  f <- file.path(raw_dir, paste0(s, "-region-nominations.html"))
  if (!file.exists(f)) stop("CG1! missing saved page ", f)
  txt <- readLines(f, warn = FALSE, encoding = "UTF-8")
  if (!any(grepl("</html>", txt, fixed = TRUE))) stop("CG1! ", basename(f), " has no closing </html>: truncated")
  doc <- read_html(f, encoding = "UTF-8")
  region <- sub("^Candidates for ", "", sq(xml_text(xml_find_first(doc, "//h1")))); region <- sub(" Region$", "", region)
  rows <- xml_find_all(doc, "//tbody/tr")
  # group rows come twice (desktop and mobile copies): keep the desktop one. Candidate rows carry "candidate-row" alone.
  rows <- rows[vapply(rows, function(r) !has_class(r, "mobile"), NA)]
  grp <- NA_character_; pos <- 0L; res <- list()
  for (r in rows) {
    if (has_class(r, "party-row")) { grp <- sq(xml_text(xml_find_first(r, "td"))); pos <- 0L; next }
    if (!has_class(r, "candidate-row")) next
    if (is.na(grp)) stop("CG1! ", basename(f), ": a candidate row before any group row")
    pos <- pos + 1L
    td <- xml_find_first(r, "td")
    res[[length(res) + 1L]] <- data.table(region = region, group_raw = grp, position = pos, name = sq(paste(xml_text(xml_find_all(td, "text()")), collapse = " ")))
  }
  if (!length(res)) stop("CG1! no candidate rows parsed from ", basename(f))
  rbindlist(res)
}
cand <- rbindlist(lapply(SLUGS, one))
# "A. Legalise Cannabis Victoria" -> letter A, group name. A group with no registered name shows a letter only;
# candidates outside any group sit under "Ungrouped".
cand[, letter := ifelse(grepl("^[A-Z]{1,2}[.]", group_raw), sub("^([A-Z]{1,2})[.].*$", "\\1", group_raw), "")]
cand[, group := sq(sub("^[A-Z]{1,2}[.]", "", group_raw))]
cand[group == "", group := paste0("Group ", letter, " (no name)")]
cand[, group := gsub("[^ -~]+", "-", group)]   # the page's long dash in one party name is not plain text
klass <- function(g) fifelse(grepl("^Australian Labor Party", g), "ALP",
                     fifelse(grepl("^Liberal|^The Nationals", g), "LNP",
                     fifelse(grepl("Greens", g), "GRN", fifelse(grepl("One Nation", g), "ONP", "MINOR"))))
cand[, class := klass(group)]
groups <- cand[, .(candidates = .N), by = .(region, letter, group, class)]
if (uniqueN(groups$region) != 8L) stop("CG2! ", uniqueN(groups$region), " regions parsed, Victoria has 8")
for (k in c("ALP", "LNP", "GRN", "ONP")) {
  n <- groups[class == k, .N, by = region]
  if (nrow(n) != 8L || any(n$N != 1L)) stop("CG2! class ", k, " is not exactly one group in each of the 8 regions")
}
fwrite(groups, file.path(out_dir, "council-groups-2026.csv")); fwrite(cand[, .(region, letter, group, class, position, name)], file.path(out_dir, "council-candidates-2026.csv"))
cat(sprintf("CG3  %d groups and %d candidates in 8 regions, from %s\n", nrow(groups), nrow(cand), raw_dir))
print(groups[, .(groups = .N, candidates = sum(candidates), no_name = sum(grepl("no name", group)), ungrouped = sum(candidates[group == "Ungrouped"])), by = region], row.names = FALSE)
cat("CG3  groups standing, by number of regions:\n"); print(groups[, .(regions = .N, candidates = sum(candidates)), by = .(group, class)][order(-regions, group)], row.names = FALSE)
