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
#' Two switches, both default off (this function is unchanged when both are):
#' * `AUSPOL_SEAT_SWING_PORT_WA`: "1" adds the five Western Australian cycles
#'   (`fed-swing-transposed-wa.csv`, built by `scripts/transpose_fed_swing.R`
#'   with `TRANSPOSE_REGION=wa`) to every target's pooled fit; "2" adds them only
#'   when the target is itself a WA election, so no other target moves.
#' * `AUSPOL_SEAT_SWING_PORT_NOCLIFF`: "1" replaces the "fewer than 3 earlier
#'   cycles gives 0" cliff with pure shrinkage. With 1 or 2 earlier cycles the
#'   cluster-robust error cannot be estimated, so the error is the ordinary
#'   seat-level one (or the cluster one with two cycles, whichever is larger)
#'   multiplied by `SEAT_SWING_NOCLIFF_SE_INFLATE` (2): a thin fit gets a
#'   quarter of the weight its own error would give it, not zero.
#'
#' @param target_election Label such as `"vic2022"`.
#' @return list: `coef`, `k` (earlier cycles), `n` (seats), `b` (unshrunk), `se`.
#' @export
seat_swing_port_coef <- function(target_election) {
  fs <- seat_swing_port_fs(target_election)
  fs$label <- paste0(fs$region, fs$cycle)
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
  thin <- G < 3L
  noc <- identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT_NOCLIFF", "0"), "1")
  if (thin && !noc) return(list(coef = 0, k = G, n = nrow(rows), b = NA_real_, se = NA_real_))
  b <- sum(rows$dev * rows$yy) / sum(rows$dev^2)
  e <- rows$yy - b * rows$dev
  # One cycle has no between-cycle spread to cluster on (G / (G - 1) is infinite).
  se2_cl <- if (G >= 2L) sum(tapply(rows$dev * e, rows$pair, sum)^2) / sum(rows$dev^2)^2 * G / (G - 1) else 0
  se2_ols <- (sum(e^2) / max(1, nrow(rows) - 1)) / sum(rows$dev^2)
  se2 <- max(se2_cl, se2_ols)
  if (thin) se2 <- se2 * SEAT_SWING_NOCLIFF_SE_INFLATE^2
  list(coef = b * b^2 / (b^2 + se2), k = G, n = nrow(rows), b = b, se = sqrt(se2))
}

#' Standard-error multiplier for a port fit on fewer than 3 earlier cycles
#' (`AUSPOL_SEAT_SWING_PORT_NOCLIFF=1`). A judgement, not a fitted constant:
#' with at most two cycles the cluster-robust error is unidentified, and 2 means
#' a thin fit carries a quarter of the weight its own error would give it.
#' @export
SEAT_SWING_NOCLIFF_SE_INFLATE <- 2

#' Whether the port includes Western Australia for a target
#' @param target_election Label such as `"wa2025"`.
#' @return `"1"` (WA cycles pooled for every target), `"2"` (WA only for WA
#'   targets) or `"0"`.
#' @keywords internal
seat_swing_port_wa_mode <- function(target_election) {
  m <- Sys.getenv("AUSPOL_SEAT_SWING_PORT_WA", "0")
  if (m == "1" || (m == "2" && sub("[0-9]{4}$", "", target_election) == "wa")) m else "0"
}

#' The transposed federal swing table the port reads for one target
#'
#' `fed-swing-transposed.csv`, plus the WA table when
#' `AUSPOL_SEAT_SWING_PORT_WA` asks for it. The WA file defaults to
#' `fed-swing-transposed-wa.csv` beside the main one; `AUSPOL_SEAT_SWING_WA_FILE`
#' points elsewhere. A missing WA file is an error, never a silent skip.
#' @param target_election Label such as `"wa2025"`.
#' @keywords internal
seat_swing_port_fs <- function(target_election) {
  fs <- data.table::fread(file.path(election_data_path(), "fed-swing-transposed.csv"), showProgress = FALSE)
  if (seat_swing_port_wa_mode(target_election) != "0") {
    f <- Sys.getenv("AUSPOL_SEAT_SWING_WA_FILE", file.path(election_data_path(), "fed-swing-transposed-wa.csv"))
    if (!file.exists(f)) stop("AUSPOL_SEAT_SWING_PORT_WA is on but ", f, " does not exist; run scripts/transpose_fed_swing.R with TRANSPOSE_REGION=wa")
    fs <- data.table::rbindlist(list(fs, data.table::fread(f, showProgress = FALSE)), fill = TRUE)
  }
  fs
}

#' The seat-swing port's inputs for one target: each seat's transposed federal
#' swing plus the fitted coefficient
#'
#' Computed from `fed-swing-transposed.csv` and `output/seat-tpp-estimates.csv`
#' when both exist (a developer machine). The daily GitHub run has neither, so
#' the rebuild's promote step writes this table to
#' `output/seat-swing-port-<target>.csv` and ships it with the models; it is
#' read back when the sources are absent. Neither available is an error.
#'
#' @param target_election Label such as `"vic2026"`.
#' @param write Write the table to `output/seat-swing-port-<target>.csv`.
#' @return data.table (`seat`, `fed_swing`) with attribute `coef` (the list
#'   from [seat_swing_port_coef()]).
#' @export
seat_swing_port_table <- function(target_election, write = FALSE) {
  src_fs <- file.path(election_data_path(), "fed-swing-transposed.csv")
  src_tp <- out_path("seat-tpp-estimates.csv")
  cache <- out_path(sprintf("seat-swing-port-%s.csv", target_election))
  if (file.exists(src_fs) && file.exists(src_tp)) {
    cf <- seat_swing_port_coef(target_election)
    fs <- seat_swing_port_fs(target_election)
    tb <- fs[paste0(fs$region, fs$cycle) == target_election, list(seat, fed_swing)]
    if (write) {
      out <- data.table::copy(tb)
      out$coef <- cf$coef; out$coef_unshrunk <- cf$b; out$coef_se <- cf$se
      out$cycles <- cf$k; out$n_fit <- cf$n
      data.table::fwrite(out, cache)
    }
  } else if (file.exists(cache)) {
    raw <- data.table::fread(cache, showProgress = FALSE)
    if (!nrow(raw) || length(unique(raw$coef)) != 1L) stop(cache, " is empty or has more than one coefficient")
    cf <- list(coef = raw$coef[1], k = raw$cycles[1], n = raw$n_fit[1],
               b = raw$coef_unshrunk[1], se = raw$coef_se[1])
    tb <- raw[, list(seat, fed_swing)]
    cat(sprintf("SP2  %s: port inputs read from %s (sources absent)
", target_election, basename(cache)))
  } else {
    stop("seat-swing port for ", target_election, ": neither the sources (", src_fs, ", ", src_tp,
         ") nor the shipped table (", cache, ") exist")
  }
  attr(tb, "coef") <- cf
  tb
}

#' Per-seat two-party adjustment from the time-forward seat-swing port
#'
#' @param target_election Label such as `"vic2022"`.
#' @param seats Seat names in the order of the caller's share matrix.
#' @return Numeric vector (points toward Labor), centred over matched seats;
#'   0 where a seat has no transposed federal swing.
#' @export
seat_swing_port_adj <- function(target_election, seats) {
  tb <- seat_swing_port_table(target_election)
  cf <- attr(tb, "coef")
  fsv <- tb$fed_swing[match(normalise_seat(seats), normalise_seat(tb$seat))]
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
#' @return `shares`, adjusted, or unchanged when the port is off for this
#'   target: `AUSPOL_SEAT_SWING_PORT` is not "2" (WA targets: when
#'   `AUSPOL_SEAT_SWING_PORT_WA` is "0").
#' @export
seat_swing_port_apply <- function(shares, target_election) {
  if (sub("[0-9]{4}$", "", target_election) == "wa") {
    if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT_WA", "0"), "0")) return(shares)
  } else if (!identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "2"), "2")) return(shares)
  stopifnot(all(c("ALP", "LNP") %in% colnames(shares)))
  adj <- seat_swing_port_adj(target_election, rownames(shares))
  stopifnot(all(is.finite(adj)))
  cat(sprintf("SP2  %s: adjustment mean %+.3f sd %.3f range %+.2f..%+.2f\n",
              target_election, mean(adj), stats::sd(adj), min(adj), max(adj)))
  shares[, "ALP"] <- pmax(0, shares[, "ALP"] + adj)
  shares[, "LNP"] <- pmax(0, shares[, "LNP"] - adj)
  100 * shares / rowSums(shares)
}
