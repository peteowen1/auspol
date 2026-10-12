#!/usr/bin/env Rscript
# Build bludgertrack_polls.csv: The Poll Bludger's own poll tables (BludgerTrack "Poll data"), one row per
# poll and breakdown, every field kept. Read by bludgertrack_polls() in R/poll_source.R (AUSPOL_POLL_BT).
#
# BludgerTrack publishes the table its aggregate is built on for the CURRENT cycles only: fed2025 (frozen at the
# 2025 election), fed2028 and vic2026 (both live). Older cycles return 404 (checked 2026-10-13; the 2019 file
# holds weekly trend points, not polls). Raw XML: external/reference/polls/pollbludger/raw/bludgertrack/
# <cycle>-current.xml, plus a dated copy of every fetch (<cycle>-<YYYY-MM-DD>.xml) so a revised poll can be traced.
#
#   Rscript scripts/build_bludgertrack_polls.R                       # parse the raw files on disk
#   Rscript scripts/build_bludgertrack_polls.R --fetch=fed2028,vic2026  # refetch those cycles first
#   ... --keep=<published csv>   rows of cycles NOT parsed this run are kept from that file (the daily CI job
#                                refetches the two live cycles and keeps fed2025 from the published table)
# Env: AUSPOL_BT_RAW (raw folder), AUSPOL_BT_OUT (output csv). No package code needed (runs in CI before the fit).
# Check codes: BK1 per file, BK2! date that did not parse / fetch failure, BK3 written.

suppressPackageStartupMessages({ library(xml2); library(data.table) })
args    <- commandArgs(trailingOnly = TRUE)
arg_val <- function(k, d) { a <- grep(paste0("^--", k, "="), args, value = TRUE); if (length(a)) sub(".*=", "", a[1]) else d }
raw_dir <- Sys.getenv("AUSPOL_BT_RAW", "external/reference/polls/pollbludger/raw/bludgertrack")
out_csv <- Sys.getenv("AUSPOL_BT_OUT", "external/reference/polls/pollbludger/bludgertrack_polls.csv")
fetch   <- strsplit(arg_val("fetch", ""), ",")[[1]]; fetch <- fetch[nzchar(fetch)]
keep_f  <- arg_val("keep", "")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

for (cy in fetch) {
  u <- sprintf("https://www.pollbludger.net/%s/bludgertrack/xml/current.xml", cy)
  tf <- tempfile(fileext = ".xml")
  ok <- tryCatch(utils::download.file(u, tf, quiet = TRUE, mode = "wb", headers = c("User-Agent" = "Mozilla/5.0 (auspol election research)")) == 0,
                 error = function(e) FALSE)
  # complete only if the root element closes (a size floor is not a completeness check)
  ok <- ok && file.exists(tf) && grepl("</root>\\s*$", paste(utils::tail(readLines(tf, warn = FALSE), 3), collapse = ""))
  if (!ok) { cat(sprintf("BK2! fetch of %s failed or truncated; the copy on disk (if any) is used\n", cy)); next }
  file.copy(tf, file.path(raw_dir, sprintf("%s-current.xml", cy)), overwrite = TRUE)
  file.copy(tf, file.path(raw_dir, sprintf("%s-%s.xml", cy, format(Sys.Date()))), overwrite = TRUE)
}

files <- list.files(raw_dir, pattern = "^[a-z]+[0-9]{4}-current\\.xml$", full.names = TRUE)
if (nzchar(keep_f) && length(fetch)) files <- files[sub("-current\\.xml$", "", basename(files)) %in% fetch]
if (!length(files)) stop("BK2! no BludgerTrack XML in ", raw_dir)
pdate <- function(s) {
  out <- as.Date(rep(NA_character_, length(s)))
  iso <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", s); dmy <- grepl("^[0-9]{2}/[0-9]{2}/[0-9]{4}$", s)
  out[iso] <- as.Date(s[iso], format = "%Y-%m-%d"); out[dmy] <- as.Date(s[dmy], format = "%d/%m/%Y")
  out
}
bt <- rbindlist(lapply(files, function(f) {
  cy <- sub("-current\\.xml$", "", basename(f))
  x <- read_xml(f); pts <- xml_find_all(x, "//table/point")
  d <- rbindlist(lapply(pts, function(p) {
    a <- as.list(xml_attrs(p)); ch <- xml_children(p); v <- as.list(xml_text(ch)); names(v) <- xml_name(ch); c(a, v)
  }), fill = TRUE)
  d[, `:=`(cycle = cy, section = vapply(pts, function(p) xml_name(xml_parent(xml_parent(p))), ""),
           file_stamp = xml_attr(x, "date"))]
  cat(sprintf("BK1 %s: %d rows (file stamp %s)\n", cy, nrow(d), xml_attr(x, "date")))
  d
}), fill = TRUE)
for (k in c("start", "end", "median")) if (k %in% names(bt)) bt[[paste0(k, "_date")]] <- pdate(bt[[k]])
bad <- bt[!is.na(end) & nzchar(end) & is.na(end_date)]
if (nrow(bad)) cat(sprintf("BK2! %d end dates did not parse (first: %s)\n", nrow(bad), bad$end[1]))
if (!"scope" %in% names(bt)) bt$scope <- NA_character_
bt[section != "federal" & section != "leaders" & is.na(scope), scope := "STATEWIDE"]
if (nzchar(keep_f) && file.exists(keep_f)) {
  old <- fread(keep_f, colClasses = "character")
  old <- old[!old$cycle %in% unique(bt$cycle)]
  bt <- rbind(old, bt[, lapply(.SD, as.character)], fill = TRUE)
  cat(sprintf("BK1 kept %d rows of %s from %s\n", nrow(old), paste(unique(old$cycle), collapse = ","), keep_f))
}
fwrite(bt, out_csv)
cat(sprintf("BK3 wrote %s: %d rows, cycles %s\n", out_csv, nrow(bt), paste(sort(unique(bt$cycle)), collapse = ",")))
