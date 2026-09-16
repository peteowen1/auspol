# Our own final-two scenario distribution --------------------------------
#
# simulate_seat_contests() already computes, per draw, which two parties a
# seat came down to (`tcp_winner`/`tcp_runnerup`) -- the exact same
# information AE Forecasts publishes as `seatTcpScenarios` and that
# scripts/build_aef_tcp.R parses out of their cached data. Every harness
# discards it after computing the single-scenario TCP share; this recovers
# it as a comparable "how often does this seat land on THIS pairing" table.
#
# Built 2026-09-16, prompted by Pete asking whether we track how often a
# seat goes into each possible head-to-head -- we compute the draws, we just
# never counted them.

#' Per-seat final-two scenario frequencies from a simulate_seat_contests() run
#'
#' @param sim The list returned by [simulate_seat_contests()]. Must have been
#'   run with the default TCP tracking (always on; there is no flag to turn
#'   it off).
#' @return A `data.table` with one row per (seat, scenario), where a
#'   "scenario" is an unordered party pair, sorted so `"ALP+LNP"` and
#'   `"LNP+ALP"` are the same row. Columns: `seat`, `f1`, `f2` (`f1` is
#'   whichever party won the MAJORITY of that pairing's own draws, so it
#'   reads as "the pairing's own favourite", not an artefact of party
#'   order), `freq` (share of ALL draws for that seat landing on this
#'   pairing -- frequencies for one seat sum to 1, uncontested seats
#'   excepted), `f1_tcp_pct` (median [f1]'s two-candidate-preferred share
#'   across just the draws in this pairing). Ordered by seat then
#'   descending `freq`, so `[seat == "X"][1]` is always that seat's
#'   most-likely pairing -- the same "headline scenario" AEF's own site
#'   shows and `scripts/build_aef_tcp.R` extracts from their data.
#' @export
tcp_scenarios <- function(sim) {
  need <- c("tcp_winner", "tcp_runnerup", "tcp_share")
  miss <- setdiff(need, names(sim))
  if (length(miss)) {
    stop("tcp_scenarios() needs simulate_seat_contests()'s own return value ",
         "(missing: ", paste(miss, collapse = ", "), ")", call. = FALSE)
  }
  w <- sim$tcp_winner; r <- sim$tcp_runnerup; s <- sim$tcp_share
  seats <- colnames(w)
  if (is.null(seats)) stop("sim$tcp_winner has no seat column names", call. = FALSE)
  n_sims <- nrow(w)

  out <- data.table::rbindlist(lapply(seats, function(sn) {
    wv <- w[, sn]; rv <- r[, sn]; sv <- s[, sn]
    keep <- !is.na(wv) & !is.na(rv)
    if (!any(keep)) return(NULL)
    wv <- wv[keep]; rv <- rv[keep]; sv <- sv[keep]
    pair_key <- ifelse(wv < rv, paste0(wv, "+", rv), paste0(rv, "+", wv))
    n_draw <- sum(keep)
    pairs <- unique(pair_key)
    rows <- lapply(pairs, function(pk) {
      idx <- pair_key == pk
      wv_p <- wv[idx]; sv_p <- sv[idx]
      # the pairing's own favourite: whichever side won MORE of ITS OWN
      # draws, not an artefact of which party's name sorts first.
      tab <- sort(table(wv_p), decreasing = TRUE)
      f1i <- names(tab)[1]
      f2i <- setdiff(strsplit(pk, "+", fixed = TRUE)[[1]], f1i)
      # tcp_share is always the WINNER's share of that draw's final two, so
      # f1's own share needs 1-share on draws where the OTHER party won.
      f1_share <- ifelse(wv_p == f1i, sv_p, 1 - sv_p)
      data.table::data.table(seat = sn, f1 = f1i, f2 = f2i,
                             freq = sum(idx) / n_draw,
                             f1_tcp_pct = 100 * stats::median(f1_share))
    })
    data.table::rbindlist(rows)
  }))
  if (is.null(out) || !nrow(out)) return(out)
  data.table::setorder(out, seat, -freq)
  out[]
}
