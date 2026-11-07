# Seat flow persistence (AUSPOL_SEAT_FLOW_PERSIST, an arm, 8 Nov 2026;
# plans/prereg-seat-flow-persistence-2026-11-08.md).
#
# A seat whose minor-party votes reached Labor more (or less) than we predicted last time tends to do
# so again: our miss r_{T-1} (share of the other votes reaching Labor, actual minus ours) persists with
# slope w_T ~ 0.35-0.45, fitted on earlier federal pairs only (scripts/build_seat_flow_persistence.R).
# In every flow row of that seat where a minor candidate is excluded with both Labor and the Coalition
# still in the count, w_T * r_{T-1} of the row's votes move from the Coalition to Labor (negative: the
# other way), clamped so neither share goes below 0.

#' Apply seat flow persistence to a per-seat conditional flow override
#'
#' @param ov Per-seat override list (NULL means none yet), as from
#'   `xgb_flow_conditional_override_for()` / `htv_flow_override()`.
#' @param fm The flow matrix (its `$conditional` is the starting table for seats without an override).
#' @param target_election,prev_election Labels such as "fed2025", "fed2022".
#' @param seats Seat names of the target, in the shares' row order.
#' @param tend,wt Tables from `output/seat-flow-persistence.csv` and `-w.csv` (read if NULL).
#' @return The override list, with attribute `seat_flow_persist`.
#' @noRd
seat_flow_persist_override <- function(ov, fm, target_election, prev_election, seats, tend = NULL, wt = NULL) {
  if (is.null(tend)) tend <- data.table::fread(out_path("seat-flow-persistence.csv"))
  if (is.null(wt)) wt <- data.table::fread(out_path("seat-flow-persistence-w.csv"))
  tgt_lab <- target_election; prv_lab <- prev_election
  w <- wt$w[wt$target == tgt_lab]
  if (!length(w) || !is.finite(w[1])) {
    cat(sprintf("SFP9  %s: no time-forward weight (too few earlier pairs) -- flow rows unchanged\n", tgt_lab))
    return(ov)
  }
  w <- w[1]
  if (w < 0 || w > 1) stop(sprintf("SFP9! %s: fitted weight %.3f outside [0, 1] -- the term is broken, not tuned", tgt_lab, w))
  prev <- tend[tend$election == prv_lab & is.finite(tend$r)]
  rmap <- stats::setNames(prev$r, prev$seat)
  out <- if (is.null(ov)) list() else ov
  applied <- 0L; shifts <- numeric(0)
  for (s in seats) {
    rp <- rmap[s]
    if (is.na(rp)) next
    L <- if (!is.null(out[[s]])) out[[s]] else fm$conditional
    touched <- FALSE
    for (k in names(L)) {
      from <- sub("[|].*$", "", k)
      if (from %in% c("ALP", "LNP")) next
      r <- L[[k]]
      if (!all(c("ALP", "LNP") %in% names(r))) next
      S <- sum(r, na.rm = TRUE)
      if (!is.finite(S) || S <= 0) next
      delta <- w * unname(rp) * S
      delta <- max(min(delta, r[["LNP"]]), -r[["ALP"]])
      r[["ALP"]] <- r[["ALP"]] + delta; r[["LNP"]] <- r[["LNP"]] - delta
      L[[k]] <- r; touched <- TRUE
    }
    if (touched) { out[[s]] <- L; applied <- applied + 1L; shifts <- c(shifts, w * unname(rp)) }
  }
  if (!is.null(ov)) for (a in setdiff(names(attributes(ov)), "names")) attr(out, a) <- attr(ov, a)
  attr(out, "seat_flow_persist") <- list(w = w, applied = applied, shifts = shifts)
  cat(sprintf("SFP9  %s: seat flow persistence w %.3f applied to %d of %d seats (from %s misses); shift mean %+.3f, range %+.3f to %+.3f\n",
              tgt_lab, w, applied, length(seats), prv_lab,
              if (length(shifts)) mean(shifts) else 0, if (length(shifts)) min(shifts) else 0, if (length(shifts)) max(shifts) else 0))
  out
}
