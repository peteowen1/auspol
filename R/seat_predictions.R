#' This rebuild's as-at seat predictions, for the post-xgb corrections to learn from
#'
#' The seat-poll blend, the demographic correction and the leader-seat bonus
#' each learn from earlier elections' misses of the as-at xgb prediction. They
#' used to read `output/forecasts.csv`, which is written at rebuild stage 7,
#' so stage 6 always learned from the PREVIOUS rebuild's predictions and every
#' result depended on the run before it (vic2026's leader bonus 2.33 or 1.05
#' depending on which rebuild came first). Stage 4 writes the same predictions
#' for THIS run to `output/xgb-primary-asat-predictions.csv` (identical to the
#' forecasts table within a run, 11,643 of 11,643 rows, 2026-09-30); this reads
#' that, falling back to the forecasts table only when it is absent.
#'
#' Under `AUSPOL_POSTXGB_RESID_NET=1` (audit F8, default "0") the seat-swing
#' port's adjustment is added back into each state election's prediction
#' ([postxgb_net_port()]), so the corrections applied after the port (seat-poll
#' blend, demographic, leader seat, and anything else reading this) learn from
#' what is left once the port has acted, which is what they are applied to.
#' docs/plans/prereg-postxgb-resid-net-2026-10-25.md.
#'
#' @param net Net the port out (default: the switch). The port's own residual
#'   fit (`AUSPOL_SEAT_SWING_PORT_RESID`) passes `FALSE`, so it never reads a
#'   prediction that already contains itself.
#' @return data.table `election`, `seat`, `party`, `xgb_pred_seat`,
#'   `actual_share`, or NULL when neither file exists.
#' @export
current_seat_predictions <- function(net = postxgb_resid_net_on()) {
  x <- .current_seat_predictions_raw()
  if (is.null(x) || !isTRUE(net)) return(x)
  postxgb_net_port(x)
}

#' Whether the post-xgb corrections learn from residuals net of the port (audit F8)
#' @return `TRUE` when `AUSPOL_POSTXGB_RESID_NET` is "1"; an error for any value
#'   other than "0" or "1".
#' @keywords internal
postxgb_resid_net_on <- function() {
  v <- Sys.getenv("AUSPOL_POSTXGB_RESID_NET", "0")
  if (!v %in% c("0", "1")) stop("AUSPOL_POSTXGB_RESID_NET must be \"0\" or \"1\", not \"", v, "\"")
  identical(v, "1")
}

#' Add the seat-swing port's adjustment into as-at seat predictions
#'
#' For every state election in `x` where the port acts
#' ([seat_swing_port_on()]; federal elections never get the port), moves
#' `adj` points from the Coalition to Labor in each seat and renormalises the
#' seat to 100, exactly as [seat_swing_port_apply()] does to the live shares.
#' Each election's `adj` comes from the port fitted on cycles BEFORE that
#' election, so a correction fitted for a later target on these rows still uses
#' only what was knowable at each earlier election. Seats lacking an ALP or LNP
#' row are left as they are and counted in the log line.
#'
#' @param x [current_seat_predictions()] output, un-netted.
#' @param adj_fun `function(election, seats)` returning one finite number per
#'   seat (points toward Labor). Defaults to the port, memoised.
#' @return `x` with `xgb_pred_seat` netted; prints a `PXN1` line saying what it
#'   applied.
#' @export
postxgb_net_port <- function(x, adj_fun = .port_adj_memo) {
  x <- data.table::copy(data.table::as.data.table(x))
  el_v <- as.character(x[["election"]])
  els <- unique(el_v)
  els <- els[!startsWith(els, "fed") & vapply(els, seat_swing_port_on, logical(1))]
  n_seat <- 0L; n_skip <- 0L; tot_abs <- 0; moved <- character(0)
  for (e_i in els) {
    rows_e <- which(el_v == e_i)
    seats_e <- unique(x[["seat"]][rows_e])
    adj <- adj_fun(e_i, seats_e)
    if (length(adj) != length(seats_e) || any(!is.finite(adj)))
      stop("postxgb_net_port: adjustment for ", e_i, " is not one finite number per seat (",
           length(adj), " for ", length(seats_e), " seats)")
    if (any(adj != 0)) moved <- c(moved, e_i)
    for (j in seq_along(seats_e)) {
      if (adj[j] == 0) next   # no port here (coefficient 0, or no federal swing): leave the row exact
      r <- rows_e[x[["seat"]][rows_e] == seats_e[j]]
      pty <- x[["party"]][r]
      ia <- r[pty == "ALP"]; il <- r[pty == "LNP"]
      if (length(ia) != 1L || length(il) != 1L) { n_skip <- n_skip + 1L; next }
      v <- x[["xgb_pred_seat"]][r]
      v[pty == "ALP"] <- max(0, v[pty == "ALP"] + adj[j])
      v[pty == "LNP"] <- max(0, v[pty == "LNP"] - adj[j])
      data.table::set(x, i = r, j = "xgb_pred_seat", value = 100 * v / sum(v))
      n_seat <- n_seat + 1L; tot_abs <- tot_abs + abs(adj[j])
    }
  }
  cat(sprintf("PXN1 post-xgb residuals net of the seat-swing port (AUSPOL_POSTXGB_RESID_NET=1): %d state elections checked, %d with a non-zero port (%s), %d seats netted, mean |adj| %.3f; %d seats skipped (no ALP or LNP row)\n",
              length(els), length(moved), paste(moved, collapse = ","), n_seat, if (n_seat) tot_abs / n_seat else 0, n_skip))
  x
}

# The port's per-seat adjustment, silenced (its SP2 lines would print once per
# election per call) and memoised for the session. The key holds every AUSPOL_*
# variable and the size and mtime of every file the port reads, so a changed
# switch or a rebuilt input misses the cache.
.port_memo <- new.env(parent = emptyenv())

# Every file the port's adjustment can read, for any target: the two transposed
# federal swing tables, the seat TPP estimates, the as-at predictions and
# forecasts table (the residual fit, AUSPOL_SEAT_SWING_PORT_RESID), and every
# shipped seat-swing-port-<target>.csv. ONE list, used by .port_adj_memo() and by
# .seat_poll_memo_key(), so a cache over current_seat_predictions(net = TRUE)
# cannot miss a rebuilt port input.
.port_input_files <- function() {
  c(election_data_path("fed-swing-transposed.csv"),
    Sys.getenv("AUSPOL_SEAT_SWING_WA_FILE", election_data_path("fed-swing-transposed-wa.csv")),
    out_path(c("seat-tpp-estimates.csv", "xgb-primary-asat-predictions.csv", "forecasts.csv")),
    sort(list.files(out_path(), pattern = "^seat-swing-port-.*\\.csv$", full.names = TRUE)),
    # AUSPOL_SEAT_SWING_PORT_3C also reads the candidate corpus and the booth
    # files (R/seat_swing_port_3c.R); only under the arm, so default keys are unchanged.
    if (seat_swing_port_3c_mode() != "0") c(
      out_path("candidacies.csv"), election_data_path(c("fed-booth-map.csv", "fed-booth-map-wa.csv")),
      sort(list.files(file.path(pkg_root(), "external", "reference", "aec", "booths"),
                      pattern = "^(tpp|pp)-fed[0-9]{4}\\.csv$", full.names = TRUE)),
      sort(list.files(file.path(pkg_root(), "external", "reference", "correspondences"),
                      pattern = "^booths-[0-9]{4}wa.*\\.csv$", full.names = TRUE))))
}
.port_adj_memo <- function(election, seats) {
  ev <- Sys.getenv()
  ev <- ev[startsWith(names(ev), "AUSPOL_")]
  files <- .port_input_files()
  fi <- file.info(files)
  key <- paste(c(election, seats, paste(names(ev), ev, sep = "="), files, fi$size, format(fi$mtime, "%Y%m%d%H%M%OS6")),
               collapse = "\r")
  if (!is.null(.port_memo[[key]])) return(.port_memo[[key]])
  adj <- NULL
  utils::capture.output(adj <- seat_swing_port_adj(election, seats))
  assign(key, adj, envir = .port_memo)
  adj
}

.current_seat_predictions_raw <- function() {
  f <- out_path("xgb-primary-asat-predictions.csv")
  if (file.exists(f)) {
    a <- data.table::fread(f, showProgress = FALSE)
    a[, xgb_pred_seat := 100 * xgb_pred / sum(xgb_pred), by = list(pair, seat)]
    return(a[, list(election = pair, seat, party, xgb_pred_seat, actual_share)])
  }
  fc <- out_path("forecasts.csv")
  if (!file.exists(fc)) return(NULL)
  cat("SPR0! xgb-primary-asat-predictions.csv absent: corrections learn from the previous rebuild's forecasts.csv\n")
  x <- data.table::fread(fc, showProgress = FALSE)
  x[, list(xgb_pred_seat = sum(xgb_pred_seat), actual_share = sum(actual_share)), by = list(election, seat, party)]
}

#' Whether this machine has seat predictions to learn from (else: shipped tables)
#' @keywords internal
.has_seat_predictions <- function() {
  file.exists(out_path("xgb-primary-asat-predictions.csv")) || file.exists(out_path("forecasts.csv"))
}
