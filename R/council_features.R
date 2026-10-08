#' Council history of a seat's candidates, by party class, as xgb features
#'
#' For each (pair, seat, party): whether a candidate of that class in that seat
#' had been elected MAYOR, elected a COUNCILLOR (not mayor), or STOOD AND LOST
#' at a council election before this election, in a council overlapping the
#' seat; and the best council first-preference share among them. Built by
#' scripts/build_council_history.py from every state's council results
#' (2005-2024) matched by name and geography; time-forward by construction
#' (only council elections before the election being predicted, within 10 years).
#'
#' Why: emergences are the largest single primary misses, and many were mayors
#' or councillors first. Against v57's error, independent and minor candidates
#' who had been elected councillors beat the prediction by +3.6 points at state
#' elections (n 117), mayors by +8.9 (n 9), federal councillors +1.8 (n 81);
#' those who stood and lost were close to zero. plans/prereg-council-2026-10-02.md.
#'
#' A class with no matched candidate gets 0 on every column -- "no council record
#' found". But a SEAT with no council data at all (`council_coverage` FALSE: no
#' council election in its state within the window -- fed2004, sa2018, WA before
#' 2008, and federal seats in Tas/ACT/NT) gets NA, not 0: a zero there would mean
#' "old election" or "small territory" and a tree would use it as that label
#' (review, 2026-10-02). xgboost treats NA as missing.
#'
#' @param keys data.table with `pair`, `seat`, `party`.
#' @param hist The council-history table; read from `output/` when `NULL`.
#' @return `keys` with `council_mayor`, `council_elected`, `council_lost`,
#'   `council_pct` added (row order kept).
#' @export
council_features <- function(keys, hist = NULL) {
  out <- data.table::copy(data.table::as.data.table(keys))
  out[, `.ord` := .I]
  if (is.null(hist)) {
    f <- out_path("council-history.csv")
    # The daily run has only the target election's slice, shipped by
    # promote_rebuild.R (council-history-<pair>.csv): read the one for the pair
    # asked for, not Victoria's by name, or an nsw2027 run reads vic2026 rows
    # and every council feature comes back empty.
    if (!file.exists(f)) {
      .pr <- unique(as.character(out$pair))
      .sl <- out_path(sprintf("council-history-%s.csv", .pr))
      .sl <- .sl[file.exists(.sl)]
      if (length(.sl)) {
        hist <- data.table::rbindlist(lapply(.sl, data.table::fread, showProgress = FALSE), use.names = TRUE, fill = TRUE)
        f <- .sl[1]
      }
    }
    if (!file.exists(f)) {
      cat("CF0! output/council-history.csv missing -- council features are all 0 (run scripts/build_council_history.py)\n")
      out[, `:=`(council_mayor = 0, council_elected = 0, council_lost = 0, council_pct = 0)]
      out[, `.ord` := NULL]
      return(out[])
    }
    if (is.null(hist)) hist <- data.table::fread(f, showProgress = FALSE)
  }
  # hist_tab, not hist: a bare argument name inside `[` would bind to a column
  hist_tab <- data.table::as.data.table(hist)
  tf <- function(z) toupper(as.character(z)) == "TRUE"
  h <- hist_tab[, list(council_mayor   = as.numeric(any(tf(council_mayor))),
                       council_elected = as.numeric(any(tf(council_elected) & !tf(council_mayor))),
                       council_lost    = as.numeric(any(tf(council_any) & !tf(council_elected))),
                       council_pct     = suppressWarnings(max(c(0, as.numeric(council_pct)), na.rm = TRUE))),
                by = list(pair = election, k = normalise_seat(seat), party)]
  # a class with a mayor is not also counted as a plain councillor or a loser
  h[council_mayor == 1, `:=`(council_elected = 0, council_lost = 0)]
  h[council_elected == 1, council_lost := 0]
  out[, k := normalise_seat(seat)]
  out <- merge(out, h, by = c("pair", "k", "party"), all.x = TRUE, sort = FALSE)
  for (cc in c("council_mayor", "council_elected", "council_lost", "council_pct"))
    data.table::set(out, which(is.na(out[[cc]])), cc, 0)
  # seats with no council data at all -> NA (see above). A table built before
  # the coverage column existed keeps the old all-zero behaviour.
  if ("council_coverage" %in% names(hist_tab)) {
    cov <- hist_tab[, list(covered = any(tf(council_coverage))), by = list(pair = election, k = normalise_seat(seat))]
    out <- merge(out, cov, by = c("pair", "k"), all.x = TRUE, sort = FALSE)
    nc <- which(is.na(out$covered) | !out$covered)
    for (cc in c("council_mayor", "council_elected", "council_lost", "council_pct"))
      data.table::set(out, nc, cc, NA_real_)
    out[, covered := NULL]
  }
  data.table::setorder(out, `.ord`)
  out[, c("k", ".ord") := NULL]
  out[]
}
