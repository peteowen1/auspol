# State preference flows estimated from a previous election's own results ------
#
# Most state elections here have no published distribution of preferences, so a
# pair whose previous election has none borrows federal exclusion events (the
# sa2022 and qld2020 precedent). scripts/estimate_flows_from_results.R also
# produces, per election and minor-party class, a state-specific estimate of the
# share of that class's preferences reaching Labor in an ALP-v-LNP count
# (`output/flows-estimated.csv`: `flow_alp`, `exhaust`, `n_seats`). Nothing read
# that file until this function.
#
# The harness flow matrix is built from EVENT rows
# (election, seat, round, from, to, votes), so a party-level estimate cannot enter
# [build_flow_matrix()] directly. This turns it into events: for each class with an
# estimate, `n_seats` synthetic exclusion events in which that class is excluded
# with only ALP and LNP left, each carrying as many ballots as the average real
# exclusion of that class in `reference` and splitting them `flow_alp` : (100 -
# `flow_alp` - `exhaust`). Appended to the federal events, the cell
# `<class>|ALP+LNP` becomes a vote-weighted blend of the federal rate and the state
# estimate, with the estimate's weight set by the number of seats it was fitted on
# (the estimate is itself already partly pooled toward a federal prior).
#
# What it does NOT supply: flows out of ALP or LNP, flows between minor classes,
# and any cell with a third survivor. Those stay with the federal events.

#' Synthetic exclusion events from a state flow estimate
#'
#' @param election Election label whose estimate to use, e.g. `"sa2014"`. For a
#'   backtest of election Y this must be the PREVIOUS election (the estimate for
#'   Y itself is built from Y's results, which are what is being predicted).
#' @param reference Real exclusion events (same columns as the input to
#'   [build_flow_matrix()]) used only to size a typical exclusion per class.
#' @param estimates Path to the estimate table.
#' @param min_seats Estimates fitted on fewer seats than this are skipped.
#' @return A `data.table` with `election`, `seat`, `round`, `from`, `to`, `votes`;
#'   zero rows when the election has no estimate. Attribute `summary` lists what
#'   was added per class.
#' @export
estimated_flow_events <- function(election, reference,
                                  estimates = file.path("output", "flows-estimated.csv"),
                                  min_seats = 5L) {
  if (!file.exists(estimates)) stop("estimated_flow_events: missing ", estimates)
  est <- data.table::fread(estimates, showProgress = FALSE)
  need <- c("election", "party", "flow_alp", "exhaust", "n_seats")
  if (length(setdiff(need, names(est)))) stop("flows-estimated.csv is missing column(s): ",
                                              paste(setdiff(need, names(est)), collapse = ", "))
  el <- election                                   # not a bare column name inside `[`
  e <- est[est$election == el & est$n_seats >= min_seats, ]
  empty <- data.table::data.table(election = character(), seat = character(), round = integer(),
                                  from = character(), to = character(), votes = numeric())
  if (!nrow(e)) return(empty)
  stopifnot(!anyDuplicated(e$party), all(is.finite(e$flow_alp)), all(is.finite(e$exhaust)),
            all(e$flow_alp >= 0 & e$flow_alp <= 100), all(e$exhaust >= 0 & e$flow_alp + e$exhaust <= 100))
  ref <- data.table::as.data.table(reference)
  ev <- ref[, list(rv = sum(get("votes"))), by = c("election", "seat", "round", "from")]
  per_class <- ev[, list(v = mean(get("rv"))), by = "from"]
  overall <- mean(ev$rv)
  rows <- list(); smry <- list()
  for (i in seq_len(nrow(e))) {
    k <- e$party[i]
    v <- per_class$v[match(k, per_class$from)]
    sized <- !is.na(v)
    if (!sized) v <- overall
    n <- as.integer(e$n_seats[i])
    alp <- v * e$flow_alp[i] / 100
    lnp <- v * (100 - e$flow_alp[i] - e$exhaust[i]) / 100
    seat <- sprintf("est-%s-%s-%03d", el, k, seq_len(n))
    rows[[i]] <- data.table::data.table(
      election = el, seat = rep(seat, 2L), round = 1L, from = k,
      to = rep(c("ALP", "LNP"), each = n), votes = c(rep(alp, n), rep(lnp, n)))
    smry[[i]] <- data.table::data.table(class = k, n_events = n, flow_alp = e$flow_alp[i],
                                        exhaust = e$exhaust[i], votes_per_event = round(v),
                                        sized_from_reference = sized)
  }
  out <- data.table::rbindlist(rows)
  out <- out[out$votes > 0, ]
  attr(out, "summary") <- data.table::rbindlist(smry)
  out
}
