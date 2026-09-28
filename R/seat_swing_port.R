#' Time-forward seat-swing port: how much of the preceding federal swing a
#' state seat carries into its own swing
#'
#' `SEAT_SWING_COEF` (0.7452) was fitted once across every state cycle, so a
#' backtest applying it to vic2022 used vic2022's own swing. This refits it for
#' each target on EARLIER state cycles only: the seat's two-party swing relative
#' to its state's (from `output/seat-tpp-estimates.csv`) regressed through the
#' origin on the seat's transposed federal swing relative to its cycle's mean
#' (`fed-swing-transposed.csv`), shrunk toward 0 by its precision across
#' cycles (at least 3 cycles, else 0). docs/plans/prereg-seat-swing-port-v2-2026-09-29.md.
#'
#' @param target_election Label such as `"vic2022"`.
#' @return list: `coef`, `k` (earlier cycles), `n` (seats), `b` (unshrunk), `se`.
#' @export
seat_swing_port_coef <- function(target_election) {
  fs <- data.table::fread(file.path(election_data_path(), "fed-swing-transposed.csv"), showProgress = FALSE)
  fs[, label := paste0(region, cycle)]
  tp <- data.table::fread(out_path("seat-tpp-estimates.csv"), showProgress = FALSE)
  d <- election_dates()
  cyc <- unique(fs$label)
  cyc <- cyc[cyc %in% names(d)]
  cyc <- cyc[elections_before(cyc, target_election)]
  rows <- data.table::rbindlist(lapply(cyc, function(lab) {
    rg <- sub("[0-9]{4}$", "", lab)
    prior <- names(d)[startsWith(names(d), rg) & as.Date(unname(d)) < as.Date(unname(d[lab]))]
    if (!length(prior)) return(NULL)
    prv <- prior[which.max(as.Date(unname(d[prior])))]
    a <- tp[tp$election == lab, list(s, t_now = tpp)]
    b <- tp[tp$election == prv, list(s, t_prev = tpp)]
    f <- fs[fs$label == lab, list(s = normalise_seat(seat), fed_swing)]
    m <- merge(merge(a, b, by = "s"), f, by = "s")
    m <- m[is.finite(t_now) & is.finite(t_prev) & is.finite(fed_swing)]
    if (nrow(m) < 5L) return(NULL)
    m[, `:=`(yy = (t_now - t_prev) - mean(t_now - t_prev), dev = fed_swing - mean(fed_swing), pair = lab)]
    m
  }), fill = TRUE)
  if (!nrow(rows)) return(list(coef = 0, k = 0L, n = 0L, b = NA_real_, se = NA_real_))
  G <- length(unique(rows$pair))
  if (G < 3L) return(list(coef = 0, k = G, n = nrow(rows), b = NA_real_, se = NA_real_))
  b <- sum(rows$dev * rows$yy) / sum(rows$dev^2)
  e <- rows$yy - b * rows$dev
  se2_cl <- sum(tapply(rows$dev * e, rows$pair, sum)^2) / sum(rows$dev^2)^2 * G / (G - 1)
  se2_ols <- (sum(e^2) / max(1, nrow(rows) - 1)) / sum(rows$dev^2)
  se2 <- max(se2_cl, se2_ols)
  list(coef = b * b^2 / (b^2 + se2), k = G, n = nrow(rows), b = b, se = sqrt(se2))
}

#' Per-seat two-party adjustment from the time-forward seat-swing port
#'
#' @param target_election Label such as `"vic2022"`.
#' @param seats Seat names in the order of the caller's share matrix.
#' @return Numeric vector (points toward Labor), centred over matched seats;
#'   0 where a seat has no transposed federal swing.
#' @export
seat_swing_port_adj <- function(target_election, seats) {
  cf <- seat_swing_port_coef(target_election)
  fs <- data.table::fread(file.path(election_data_path(), "fed-swing-transposed.csv"), showProgress = FALSE)
  fs <- fs[paste0(fs$region, fs$cycle) == target_election]
  fsv <- fs$fed_swing[match(normalise_seat(seats), normalise_seat(fs$seat))]
  adj <- rep(0, length(seats))
  ok <- is.finite(fsv)
  if (any(ok)) adj[ok] <- cf$coef * (fsv[ok] - mean(fsv[ok]))
  adj[ok] <- adj[ok] - mean(adj[ok])
  cat(sprintf("SP2  %s: seat-swing port coef %.3f (unshrunk %s, se %s, %d earlier cycles, %d seats); %d of %d seats matched\n",
              target_election, cf$coef, format(round(cf$b, 3)), format(round(cf$se, 3)), cf$k, cf$n, sum(ok), length(seats)))
  adj
}

#' Apply the time-forward seat-swing port to a seat-by-party share matrix
#'
#' Moves `adj` points from LNP to Labor per seat (`seat_swing_port_adj()`) and
#' renormalises rows to 100. Callers apply it AFTER the xgb primary override,
#' because `xgb_primary_override()` replaces every ALP/LNP cell it has a
#' prediction for and would erase an adjustment applied before it.
#'
#' @param shares Matrix of primary shares, rownames = seats, columns include
#'   `ALP` and `LNP`.
#' @param target_election Label such as `"vic2022"`.
#' @return `shares`, adjusted, or unchanged when `AUSPOL_SEAT_SWING_PORT` is not "2".
#' @export
seat_swing_port_apply <- function(shares, target_election) {
  if (!identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "2")) return(shares)
  stopifnot(all(c("ALP", "LNP") %in% colnames(shares)))
  adj <- seat_swing_port_adj(target_election, rownames(shares))
  stopifnot(all(is.finite(adj)))
  cat(sprintf("SP2  %s: adjustment mean %+.3f sd %.3f range %+.2f..%+.2f\n",
              target_election, mean(adj), stats::sd(adj), min(adj), max(adj)))
  shares[, "ALP"] <- pmax(0, shares[, "ALP"] + adj)
  shares[, "LNP"] <- pmax(0, shares[, "LNP"] - adj)
  100 * shares / rowSums(shares)
}
