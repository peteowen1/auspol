#' Derive a two-party-preferred (ALP) trend from first-preference trends
#'
#' Matches the anchor methodology: published poll TPPs are ignored; TPP is
#' ALP FP plus each minor party's FP weighted by its estimated preference flow
#' to ALP. Parties missing a flow estimate use the "OTH" flow. FP means are
#' first rescaled so the day's FP total is 100 (trends are fitted
#' independently, so their sum drifts slightly from 100).
#'
#' Uncertainty is propagated assuming independence across party trends —
#' an approximation (shares are negatively correlated by construction), so
#' the TPP band is mildly conservative.
#'
#' @param fits Named list from [fit_cycle_trends()]; must include "ALP".
#' @param flows data.table from [load_preference_flows()], already filtered to
#'   the cycle's year and region.
#' @return data.table: date, mean, sd, lo95, hi95.
#' @export
derive_tpp <- function(fits, flows) {
  stopifnot("ALP" %in% names(fits))
  parties <- names(fits)
  minors <- setdiff(parties, c("ALP", "LNP", "LIB", "NAT"))
  oth_flow <- flows[flows$party == "OTH", flow_alp]
  if (length(oth_flow) == 0) oth_flow <- 50

  # Align all trends on common dates
  dates <- Reduce(intersect, lapply(fits, function(f) f$trend$date))
  dates <- as.Date(dates, origin = "1970-01-01")
  get_on <- function(p, col) {
    tr <- fits[[p]]$trend
    tr[[col]][match(dates, tr$date)]
  }

  fp_mat <- vapply(parties, function(p) get_on(p, "mean"), numeric(length(dates)))
  total <- rowSums(fp_mat)
  fp_mat <- fp_mat * (100 / total) # renormalise to 100

  flow_of <- function(p) {
    fl <- flows[flows$party == p, flow_alp]
    if (length(fl) == 0) oth_flow[1] else fl[1]
  }
  tpp_mean <- fp_mat[, "ALP"]
  var_tpp <- get_on("ALP", "sd")^2
  for (p in minors) {
    w <- flow_of(p) / 100
    tpp_mean <- tpp_mean + w * fp_mat[, p]
    var_tpp <- var_tpp + (w * get_on(p, "sd"))^2
  }
  out <- data.table::data.table(
    date = dates, mean = tpp_mean, sd = sqrt(var_tpp)
  )
  out[, `:=`(lo95 = mean - 1.96 * sd, hi95 = mean + 1.96 * sd)]
  out[]
}
