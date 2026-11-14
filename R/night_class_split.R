# Two candidates of one minor class counted separately ON THE NIGHT (docs/plans/prereg-night-class-split-2026-11-14.md).
# The pre-election split (R/class_split.R, AUSPOL_CLASS_SPLIT, refused 6 Nov) predicted the junior candidate's share of
# the class; on the night it is counted. Same simulator elements (coalition_split$cls, cls_r, cls_sd, cls_f).
# Data.table NSE: no local shares a column name inside [...].

#' Night class-split parameters for an election (time-forward)
#'
#' @param target_election Election label.
#' @return List `sd0` (the error of a pre-election junior fraction, earlier elections) and `f` (same-class flow, named
#'   by class), from [class_split_fit()]; `NULL` when either is missing.
#' @export
night_class_split_params <- function(target_election) {
  fit <- class_split_fit(target_election)
  if (!is.finite(fit$sd) || !length(fit$f) || all(is.na(fit$f))) return(NULL)
  list(sd0 = fit$sd, f = fit$f)
}

#' The night's class split, from the counted booth figures
#'
#' @param live Booth table (`district, booth, booth_type, candidate, party, votes`).
#' @param units Named list, seat -> counted units (`booth` for ordinary booths, else `booth_type`), as
#'   [night_booth_update()] returns them.
#' @param counted Named numeric, seat -> share of the night vote counted.
#' @param params From [night_class_split_params()].
#' @param seats The simulation's seats.
#' @param classes Minor classes that can be split.
#' @return `NULL` when no seat qualifies, else a list `cls`, `cls_r`, `cls_sd`, `cls_f`, each named by seat (`NA`
#'   where no split), and attribute `detail` (one row per split seat).
#' @export
night_class_split <- function(live, units, counted, params, seats, classes = c("IND", "OTH", "OTH_RIGHT")) {
  if (is.null(params) || !length(units)) return(NULL)
  if (!"candidate" %in% names(live)) stop("NCS1! the night class split needs a `candidate` column in the booth table", call. = FALSE)
  L <- data.table::as.data.table(live)
  L <- L[!is.na(L$votes) & L$votes > 0 & !is.na(L$candidate) & nzchar(trimws(L$candidate))]
  L[, "cls" := classify_party(get("party"))]
  L <- L[L$cls %in% classes]
  L[, "unit" := ifelse(get("booth_type") == "ordinary", get("booth"), get("booth_type"))]
  na <- stats::setNames(rep(NA_real_, length(seats)), seats)
  cls <- stats::setNames(rep(NA_character_, length(seats)), seats)
  r <- na; sdv <- na; f <- na
  rows <- list()
  for (s in intersect(names(units), seats)) {
    u <- units[[s]]
    x <- L[L$district == s & L$unit %in% u]
    if (!nrow(x)) next
    v <- x[, list(v = sum(get("votes"))), by = c("cls", "candidate")]
    v <- v[, list(n = .N, tot = sum(get("v")), jun = sort(get("v"), decreasing = TRUE)[2]), by = "cls"]
    v <- v[v$n >= 2L & is.finite(v$jun) & v$jun > 0]
    if (!nrow(v)) next
    v <- v[order(-v$jun)][1]
    fk <- unname(params$f[v$cls])
    if (!is.finite(fk)) next
    cs <- unname(counted[s]); if (!is.finite(cs)) cs <- 0
    cls[s] <- v$cls
    r[s] <- min(v$jun / v$tot, 0.5)
    sdv[s] <- params$sd0 * sqrt(max(0, 1 - cs))
    f[s] <- fk
    rows[[length(rows) + 1]] <- data.table::data.table(seat = s, cls = v$cls, n_cand = v$n, r = r[s], sd = sdv[s], f = fk, counted = cs)
  }
  if (!length(rows)) return(NULL)
  out <- list(cls = cls, cls_r = r, cls_sd = sdv, cls_f = f)
  attr(out, "detail") <- data.table::rbindlist(rows)
  out
}

#' Merge the night class split into a state's `coalition_split` (the Coalition elements are kept)
#' @keywords internal
.night_merge_split <- function(cs0, ncs, seats) {
  if (is.null(ncs)) return(cs0)
  # the simulator needs the Coalition's r, sd and f whenever a split list is passed: none (r all NA, f 0) if the state has none
  base <- if (is.null(cs0)) list(r = stats::setNames(rep(NA_real_, length(seats)), seats),
                                 sd = stats::setNames(rep(NA_real_, length(seats)), seats), f = 0)
          else cs0[setdiff(names(cs0), c("cls", "cls_r", "cls_sd", "cls_f"))]
  c(base, ncs[c("cls", "cls_r", "cls_sd", "cls_f")])
}
