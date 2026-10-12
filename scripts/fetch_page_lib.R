# Shared by the poll scrapers (fetch_statewide_poll_samples.R, fetch_pollbludger_tracker_polls.R).
#
# fetch_page() downloads to a tempfile, learns the real HTTP status, and moves the body into
# `dest` only if it is a complete document. Only 404/410 count as "not found"; a timeout, 429,
# 5xx, DNS failure or a 200 with a truncated body is "fetch_failed" (nothing is written, so
# the next run retries). Before 2026-10-11 every failure was cached as a 404 forever.
page_complete <- function(f, closing = "</html>") {
  if (!file.exists(f) || file.size(f) == 0) return(FALSE)
  grepl(closing, readChar(f, file.size(f), useBytes = TRUE), fixed = TRUE, useBytes = TRUE)
}
# `complete`: function(path) -> TRUE when the body is whole (default: ends with </html>).
fetch_page <- function(url, dest, ua, complete = page_complete) {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  h <- curl::new_handle(useragent = ua, followlocation = TRUE, timeout = 60)
  res <- tryCatch(curl::curl_fetch_disk(url, tmp, h), error = function(e) NULL)
  code <- if (is.null(res)) NA_integer_ else as.integer(res$status_code)
  if (identical(code, 200L) && complete(tmp)) {
    file.copy(tmp, dest, overwrite = TRUE)
    return(list(status = "on_disk", code = code))
  }
  if (!is.na(code) && code %in% c(404L, 410L)) return(list(status = "not_found", code = code))
  list(status = "fetch_failed", code = code)
}
