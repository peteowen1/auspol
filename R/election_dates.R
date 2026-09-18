#' Polling day for every election the corpus knows about
#'
#' ONE table, in the package. Before 2026-09-18 each backtest harness carried
#' its own copy (`FED_DATE`, `WA_DATE`, `VIC_DATE`, `V2_DATES`, the Queensland
#' and SA `asof`/`flow_before` literals) -- the same six-copies-drift shape
#' `all_election_pairs()` exists to prevent for the pair list, and nothing
#' outside a harness could ask "what date was fed2022" without grepping one.
#' The point-in-time XGBoost training (`scripts/fit_xgb_primary_asat.R`) needs
#' exactly that question answered for every target at once: a model "as at"
#' election T may train only on pairs whose target polling day is strictly
#' before T's.
#'
#' @param labels Optional character vector of election labels (`"fed2022"`);
#'   `NULL` returns the whole table.
#' @return Named `Date` vector, names are election labels. Unknown labels
#'   are an error, not `NA` -- a silently missing date would let a model
#'   train on the future.
#' @export
election_dates <- function(labels = NULL) {
  d <- c(
    fed2004 = "2004-10-09", fed2007 = "2007-11-24", fed2010 = "2010-08-21",
    fed2013 = "2013-09-07", fed2016 = "2016-07-02", fed2019 = "2019-05-18",
    fed2022 = "2022-05-21", fed2025 = "2025-05-03",
    nsw2015 = "2015-03-28", nsw2019 = "2019-03-23", nsw2023 = "2023-03-25",
    qld2017 = "2017-11-25", qld2020 = "2020-10-31", qld2024 = "2024-10-26",
    sa2018  = "2018-03-17", sa2022  = "2022-03-19", sa2026  = "2026-03-21",
    vic2010 = "2010-11-27", vic2014 = "2014-11-29", vic2018 = "2018-11-24",
    vic2022 = "2022-11-26", vic2026 = "2026-11-28",
    wa1996  = "1996-12-14", wa2001  = "2001-02-10", wa2005  = "2005-02-26",
    wa2008  = "2008-09-06", wa2013  = "2013-03-09", wa2017  = "2017-03-11",
    wa2021  = "2021-03-13", wa2025  = "2025-03-08"
  )
  out <- stats::setNames(as.Date(d), names(d))
  if (is.null(labels)) return(out)
  miss <- setdiff(labels, names(out))
  if (length(miss)) stop("election_dates(): no polling day recorded for ",
                         paste(miss, collapse = ", "), call. = FALSE)
  out[labels]
}
