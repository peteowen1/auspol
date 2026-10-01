#' Redistribution pairs at state elections, and the notional prior for them
#'
#' A state redistribution redraws or renames districts, so the previous
#' election's district results describe boundaries that no longer exist. The
#' state harnesses swung that raw prior forward and skipped every renamed
#' district (67 seat-elections). `scripts/build_state_notionals.py` rebuilds
#' each previous result on the NEXT election's boundaries from booth results,
#' matching polling places by venue name; on every redistribution pair it
#' beats the raw prior (`scripts/eval_state_notionals.py`).
#'
#' Mirrors the federal harness's `AUSPOL_NOTIONAL = "2"`: on a pair in
#' `STATE_REDISTRIBUTIONS`, the notional REPLACES the prior for every seat.
#' Pairs fought on unchanged boundaries keep the actual result, which the
#' notional only approximates.
#'
#' @param region "vic", "nsw", "qld", "sa" or "wa".
#' @param from,to Election years of the pair.
#' @param mode `AUSPOL_STATE_NOTIONAL`: "1" replaces, anything else leaves the
#'   prior alone.
#' @return A data.table `seat, party, votes` on `to`'s boundaries, or `NULL`
#'   when the switch is off, the pair had no redistribution, or no notional
#'   file exists (printed, so an arm that silently did nothing is visible).
#' @export
state_notional_prior <- function(region, from, to, mode = Sys.getenv("AUSPOL_STATE_NOTIONAL", "0")) {
  key <- sprintf("%s%d", region, as.integer(to))
  if (!identical(mode, "1")) return(NULL)
  if (!key %in% names(STATE_REDISTRIBUTIONS)) {
    cat(sprintf("SNP0  %s: no redistribution before this election -- actual prior kept\n", key))
    return(NULL)
  }
  f <- election_data_path(file.path("notional", sprintf("%s-%d-from-%d-firstprefs.csv", region, as.integer(to), as.integer(from))))
  if (!file.exists(f)) {
    cat(sprintf("SNP0! %s: notional file %s missing -- run scripts/build_state_notionals.py; actual prior kept\n", key, f))
    return(NULL)
  }
  nb <- data.table::fread(f, showProgress = FALSE)
  if (!nrow(nb) || !all(c("seat", "party", "votes") %in% names(nb))) stop("state_notional_prior: ", f, " is empty or malformed")
  cat(sprintf("SNP1  %s: prior REPLACED by the notional on %s boundaries (%s): %d seats\n",
              key, key, STATE_REDISTRIBUTIONS[[key]], data.table::uniqueN(nb$seat)))
  nb[, .(seat, party, votes)]
}

#' State elections preceded by a redistribution
#'
#' Elections whose districts differ from the previous election's. Each entry
#' names the redistribution. A pair NOT listed keeps its actual prior.
#' @format A named character vector.
#' @export
STATE_REDISTRIBUTIONS <- c(
  vic2014 = "2013 Victorian redivision",
  vic2022 = "2021 Victorian redivision",
  nsw2023 = "2021 NSW redistribution",
  sa2022  = "2020 SA redistribution",
  sa2026  = "2024 SA redistribution",
  wa2008  = "2007 WA redistribution (one vote one value)",
  wa2013  = "2011 WA redistribution",
  wa2017  = "2015 WA redistribution",
  wa2021  = "2019 WA redistribution",
  wa2025  = "2023 WA redistribution")

#' Every state notional, in the shape of `output/notional-baselines.csv`
#'
#' `election, prior, seat, party, votes, pcv` for each pair in
#' `STATE_REDISTRIBUTIONS` with a notional file on disk, so the xgb layer's
#' `x_notional_adj` (scripts/fit_xgb_primary_v6.R) sees state redistributions
#' as it already sees federal ones. Empty when `AUSPOL_STATE_NOTIONAL` is off.
#' @param mode As for [state_notional_prior()].
#' @export
state_notional_baselines <- function(mode = Sys.getenv("AUSPOL_STATE_NOTIONAL", "0")) {
  if (!identical(mode, "1")) return(data.table::data.table())
  d <- election_data_path("notional")
  ff <- list.files(d, pattern = "^[a-z]+-[0-9]{4}-from-[0-9]{4}-firstprefs[.]csv$", full.names = TRUE)
  out <- data.table::rbindlist(lapply(ff, function(f) {
    m <- regmatches(basename(f), regexec("^([a-z]+)-([0-9]{4})-from-([0-9]{4})", basename(f)))[[1]]
    if (!paste0(m[2], m[3]) %in% names(STATE_REDISTRIBUTIONS)) return(NULL)
    x <- data.table::fread(f, showProgress = FALSE)
    x[, `:=`(election = paste0(m[2], m[3]), prior = paste0(m[2], m[4]))]
    x[, pcv := 100 * votes / sum(votes), by = seat]
    x[, .(election, prior, seat, party, votes, pcv)]
  }))
  cat(sprintf("SNP2  state notional baselines: %d pairs, %d seat-party cells\n",
              data.table::uniqueN(out$election), nrow(out)))
  out
}
