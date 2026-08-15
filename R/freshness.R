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
#' Two different things look identical from the newest poll's date alone: our
#' copy of the data being out of date, and nobody having published a poll. The
#' source file's own modification time separates them, so `file_age_days` is
#' reported alongside. A recently-written file whose newest poll is old means
#' the field simply is not polling — which is normal for a state 19 months from
#' an election, and not a problem to fix.
#'
#' @param region Region code, e.g. "vic".
#' @param as_of Date to measure against.
#' @return List: `latest` (date of the most recent poll), `age_days`,
#'   `file_age_days` (how long since the source file was written),
#'   `n_recent` (polls in the last 60 days), `region`.
#' @export
poll_data_age <- function(region, as_of = Sys.Date()) {
  path <- anchor_data_path(sprintf("poll-data-%s.csv", region))
  polls <- suppressMessages(load_polls(region))
  latest <- max(polls$date, na.rm = TRUE)
  list(region = region, latest = latest,
       age_days = as.integer(as_of - latest),
       file_age_days = as.integer(as_of - as.Date(file.info(path)$mtime)),
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
                           age_days = a$age_days,
                           file_age_days = a$file_age_days,
                           n_recent = a$n_recent)
  }))
  info[, status := data.table::fifelse(
    age_days >= stale_days, "STALE",
    data.table::fifelse(age_days >= warn_days, "ageing", "ok"))]
  # Which of the two problems it is, rather than guessing: a file written
  # recently that still has no new polls means the field is not polling.
  info[, cause := data.table::fifelse(
    status == "ok", "",
    data.table::fifelse(file_age_days > warn_days,
                        " - our copy is old, pull external/",
                        " - no new polls published"))]

  for (i in seq_len(nrow(info))) {
    message(sprintf("  polls[%s]: newest %s (%d days old), %d in the last 60  [%s%s]",
                    info$region[i], info$latest[i], info$age_days[i],
                    info$n_recent[i], info$status[i], info$cause[i]))
  }
  bad <- info[which(info$status == "STALE"), ]
  if (nrow(bad)) {
    msg <- sprintf("Poll data is stale for %s (%s days old)%s.",
                   paste(bad$region, collapse = ", "),
                   paste(bad$age_days, collapse = ", "),
                   bad$cause[1])
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
