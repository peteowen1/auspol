# Fetch every House download the AEC Tally Room menu offers, for eight federal
# elections (2004-2025), RAW and unmodified, one request at a time with a 1 s
# pause. Menu pages are saved raw too, and the file list is parsed FROM the menu
# so nothing the AEC offers is guessed. Skips files already on disk (>0 bytes).
# Output: external/reference/aec/tallyroom/<eventid>/ (original filenames) and
# external/reference/aec/tallyroom/fetch-log.csv (one row per request).
# .txt twins of the .csv files are the same data in another delimiter; not fetched.
UA <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
ROOT <- file.path("external", "reference", "aec", "tallyroom")
EL <- data.frame(year = c(2004,2007,2010,2013,2016,2019,2022,2025),
                 id = c(12246,13745,15508,17496,20499,24310,27966,31496),
                 seg = c("results", rep("Website", 7)))
log_rows <- list()
get <- function(url, dest) {
  if (file.exists(dest) && file.info(dest)$size > 0) return(list(status = "on_disk", bytes = file.info(dest)$size))
  tmp <- paste0(dest, ".part")
  r <- tryCatch(suppressWarnings(utils::download.file(url, tmp, mode = "wb", quiet = TRUE,
        headers = c("User-Agent" = UA))), error = function(e) 1L)
  Sys.sleep(1)
  if (!identical(as.integer(r), 0L) || !file.exists(tmp)) { if (file.exists(tmp)) file.remove(tmp)
    return(list(status = "error_or_404", bytes = 0)) }
  sz <- file.info(tmp)$size
  b <- readBin(tmp, "raw", 200); b[b == as.raw(0)] <- as.raw(32)
  head <- iconv(rawToChar(b), "latin1", "ASCII", sub = " ")
  if (grepl("[.]csv$", dest) && grepl("^[[:space:]]*<(!|html)", head, ignore.case = TRUE)) {
    file.remove(tmp); return(list(status = "html_not_found", bytes = sz)) }
  file.rename(tmp, dest); list(status = "ok", bytes = sz)
}
for (i in seq_len(nrow(EL))) {
  id <- EL$id[i]; d <- file.path(ROOT, id); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  base <- sprintf("https://results.aec.gov.au/%d/%s/", id, EL$seg[i])
  menu <- file.path(d, sprintf("HouseDownloadsMenu-%d-Csv.htm", id))
  r <- get(paste0(base, basename(menu)), menu)
  html <- paste(readLines(menu, warn = FALSE), collapse = "\n")
  hr <- unique(regmatches(html, gregexpr('href="(Downloads|External)/[^"]+"', html))[[1]])
  hr <- sub('^href="', "", sub('"$', "", hr)); hr <- hr[grepl("[.](csv|zip)$", hr)]
  cat(EL$year[i], id, length(hr), "files on menu\n")
  for (h in hr) {
    r <- get(paste0(base, h), file.path(d, basename(h)))
    log_rows[[length(log_rows) + 1]] <- data.frame(year = EL$year[i], event = id, file = basename(h),
      url = paste0(base, h), status = r$status, bytes = r$bytes)
    cat(sprintf("  %-75s %s %s\n", basename(h), r$status, r$bytes))
  }
}
lg <- do.call(rbind, log_rows)
utils::write.csv(lg, file.path(ROOT, "fetch-log.csv"), row.names = FALSE)
print(table(lg$status))
cat("MB ok:", round(sum(lg$bytes[lg$status %in% c("ok","on_disk")]) / 1e6, 1), "\n")

# NOTE (2026-10-30): the 2004-2013 menu pages do NOT list the General* files
# (enrolment, declaration votes, polling places with lat/long, party details),
# but they exist at the same URL pattern for ALL eight elections. They were
# fetched by a direct probe (tallyroom/probe-undocumented-log.csv): the menu is
# not the full list. Truly absent (404): NominationsByDivision 2004/2007,
# NonClassicDivisions 2004/2007, PartyRepresentationLeading 2004-2010,
# TppByDivisionByVoteType 2004-2013.
