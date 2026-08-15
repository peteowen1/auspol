# Data freshness ----------------------------------------------------------
#
# Every poll this package uses comes from a third party's hand-maintained CSVs
# in a local clone. Nothing in the pipeline notices if that clone stops being
# updated: the fit still runs, every pre-registered check still passes, and the
# forecast quietly describes the world as it was weeks ago. For a live forecast
# with an election date attached, that is the most likely way to be wrong
# without any error appearing.

#' How old is a region's most recent poll?
#'
#' @param region Region code, e.g. "vic".
#' @param as_of Date to measure against.
#' @return List: `latest` (date of the most recent poll), `age_days`,
#'   `n_recent` (polls in the last 60 days), `region`.
#' @export
poll_data_age <- function(region, as_of = Sys.Date()) {
  polls <- suppressMessages(load_polls(region))
  latest <- max(polls$date, na.rm = TRUE)
  list(region = region, latest = latest,
       age_days = as.integer(as_of - latest),
       n_recent = sum(polls$date >= (as_of - 60), na.rm = TRUE))
}

#' Refuse to publish a forecast built on stale polling
#'
#' Deliberately noisy. A stale forecast is not a degraded forecast — it is a
#' confident statement about a world that has moved on, and it looks identical
#' to a fresh one.
#'
#' @param regions Regions to check.
#' @param warn_days Age at which data counts as ageing.
#' @param stale_days Age at which data counts as stale.
#' @param strict Whether stale data stops the run. Set FALSE for a historical
#'   or validation run where old data is the point — the data is still
#'   REPORTED as stale, because "proceed anyway" and "it is not stale" are
#'   different claims and only one of them is true.
#' @param as_of Date to measure against.
#' @return data.table of `region`, `latest`, `age_days`, `n_recent`, `status`,
#'   invisibly.
#' @export
check_poll_freshness <- function(regions, warn_days = 21, stale_days = 60,
                                 strict = TRUE, as_of = Sys.Date()) {
  info <- data.table::rbindlist(lapply(regions, function(r) {
    a <- poll_data_age(r, as_of)
    data.table::data.table(region = a$region, latest = a$latest,
                           age_days = a$age_days, n_recent = a$n_recent)
  }))
  info[, status := data.table::fifelse(
    age_days >= stale_days, "STALE",
    data.table::fifelse(age_days >= warn_days, "ageing", "ok"))]

  for (i in seq_len(nrow(info))) {
    message(sprintf("  polls[%s]: newest %s (%d days old), %d in the last 60  [%s]",
                    info$region[i], info$latest[i], info$age_days[i],
                    info$n_recent[i], info$status[i]))
  }
  bad <- info[which(info$status == "STALE"), ]
  if (nrow(bad)) {
    msg <- sprintf(
      "Poll data is stale for %s (%s days old). The anchor clone under external/ probably needs a git pull.",
      paste(bad$region, collapse = ", "),
      paste(bad$age_days, collapse = ", "))
    if (strict) {
      stop(msg, " Pass strict = FALSE to proceed anyway.")
    }
    warning(msg, " Proceeding because strict = FALSE.")
  }
  if (any(info$status == "ageing")) {
    warning(sprintf("Poll data ageing for %s - consider refreshing the anchor clone.",
                    paste(info$region[info$status == "ageing"], collapse = ", ")))
  }
  invisible(info)
}
