# ONE NATION PAIRWISE FLOW CALIBRATION (AUSPOL_ONP_FLOW_CAL, default "0" = unchanged).
# docs/plans/prereg-onp-flow-calibration-2026-11-26.md
#
# The per-seat flow trees lean toward One Nation in every key that includes it: live vic2026, the other candidates'
# votes in One Nation v Coalition seats end 48% with the Coalition against 66.5% in sa2026's real counts. The trees
# have few One Nation rows per exact key and read a big One Nation primary as a reason to send it more.
#
# For every key whose survivors include ONP and a party X in {ALP, LNP, NAT}, excluded class f not X or ONP, the tree's
# split X : ONP moves toward the measured history rate for (f, X), pooled over every earlier survivor set where both
# were alive:  r_new = r_tree + w (r_hist - r_tree),  w = E / (E + k),  E = elections with such exclusions.
# Applied as an odds multiplier on X; X and ONP are rescaled to their original total, other survivors unchanged.

#' Measured pairwise split X vs One Nation, by excluded class, from earlier elections
#'
#' @param hist Flow-feature rows (columns election, event_id, from, surv, to, votes), already restricted to elections
#'   before the target.
#' @param target_date Date of the target election (recency weights).
#' @param hl Recency half-life in years (<= 0 or NA: equal weight per election).
#' @param dates Named Date vector of election dates.
#' @return data.table: from, x, r_hist (share to X of the votes reaching X or ONP), n_elec, n_excl.
#' @keywords internal
onp_pair_rates <- function(hist, target_date, hl, dates) {
  out <- list()
  sv <- strsplit(hist$surv, "+", fixed = TRUE)
  has_onp <- vapply(sv, function(s) "ONP" %in% s, logical(1))
  for (x_cls in c("ALP", "LNP", "NAT")) {
    has_x <- vapply(sv, function(s) x_cls %in% s, logical(1))
    sel <- has_onp & has_x & !(hist$from %in% c(x_cls, "ONP"))
    if (!any(sel)) next
    H <- hist[sel]
    to_x <- H$to == x_cls; to_o <- H$to == "ONP"
    H[, `:=`(vx = votes * to_x, vo = votes * to_o)]
    pe <- H[, list(vx = sum(vx), vo = sum(vo), n_ev = data.table::uniqueN(event_id)), by = c("election", "from")]
    pe <- pe[pe$vx + pe$vo > 0]
    if (!nrow(pe)) next
    pe[, r := vx / (vx + vo)]
    age <- as.numeric(target_date - dates[pe$election]) / 365.25
    if (anyNA(age)) stop("onp_pair_rates: no election date for ", paste(unique(pe$election[is.na(age)]), collapse = ", "))
    pe[, wt := if (is.finite(hl) && hl > 0) 0.5^(age / hl) else 1]
    agg <- pe[, list(r_hist = sum(wt * r) / sum(wt), n_elec = .N, n_excl = sum(n_ev),
                     r_min = min(r), r_max = max(r)), by = "from"]
    agg[, x := x_cls]
    out[[length(out) + 1L]] <- agg
  }
  if (!length(out)) return(data.table::data.table(from = character(), x = character(), r_hist = numeric(),
                                                  n_elec = integer(), n_excl = integer(), r_min = numeric(), r_max = numeric()))
  data.table::rbindlist(out, use.names = TRUE)
}

#' Apply the One Nation pairwise calibration to a per-seat conditional override list
#'
#' A no-op unless `AUSPOL_ONP_FLOW_CAL=1`.
#'
#' @param ov Per-seat override list from [xgb_flow_conditional_override_for()].
#' @param rates Output of [onp_pair_rates()].
#' @param k Shrinkage constant: weight E / (E + k) on the history rate, E = elections measured.
#' @param target_election For the log line.
#' @return `ov`, adjusted.
#' @keywords internal
onp_flow_cal_apply <- function(ov, rates, k, target_election) {
  if (!nrow(rates)) { cat(sprintf("ONC1! %s: no history rates for One Nation pairs, flows unchanged\n", target_election)); return(ov) }
  rkey <- paste(rates$from, rates$x)
  n_cells <- 0L; d_log <- list()
  for (si in seq_along(ov)) {
    so <- ov[[si]]
    if (is.null(so)) next
    for (ky in names(so)) {
      v <- so[[ky]]
      if (!"ONP" %in% names(v)) next
      f_cls <- sub("[|].*$", "", ky)
      if (f_cls == "ONP") next
      xs <- intersect(c("ALP", "LNP", "NAT"), setdiff(names(v), f_cls))
      if (!length(xs) || !(v[["ONP"]] > 0)) next
      grp <- c(xs, "ONP"); tot <- sum(v[grp])
      changed <- FALSE
      for (x_cls in xs) {
        j <- match(paste(f_cls, x_cls), rkey)
        if (is.na(j) || !(v[[x_cls]] > 0)) next
        r_tree <- v[[x_cls]] / (v[[x_cls]] + v[["ONP"]])
        w <- rates$n_elec[j] / (rates$n_elec[j] + k)
        r_new <- r_tree + w * (rates$r_hist[j] - r_tree)
        v[[x_cls]] <- v[[x_cls]] * (r_new / (1 - r_new)) / (r_tree / (1 - r_tree))
        changed <- TRUE
        d_log[[length(d_log) + 1L]] <- c(r_tree = r_tree, r_new = r_new)
      }
      if (changed) {
        v[grp] <- v[grp] * tot / sum(v[grp])
        so[[ky]] <- v; n_cells <- n_cells + 1L
      }
    }
    ov[[si]] <- so
  }
  if (length(d_log)) {
    d <- do.call(rbind, d_log)
    cat(sprintf("ONC1 %s: One Nation pairwise flow calibration (k %.2g): %d key-seat cells, %d pair splits; median split to the non-One-Nation side %.1f -> %.1f\n",
                target_election, k, n_cells, nrow(d), 100 * stats::median(d[, "r_tree"]), 100 * stats::median(d[, "r_new"])))
  } else cat(sprintf("ONC1 %s: One Nation pairwise flow calibration: no cell matched\n", target_election))
  ov
}

#' Gate for the calibration, called from [xgb_flow_conditional_override_for()]
#'
#' @param ov Per-seat override list.
#' @param hist Flow-feature rows of elections before the target.
#' @param target_election Target election label, e.g. "vic2026".
#' @return `ov`, adjusted when `AUSPOL_ONP_FLOW_CAL=1`, otherwise unchanged.
#' @keywords internal
onp_flow_cal <- function(ov, hist, target_election) {
  mode <- Sys.getenv("AUSPOL_ONP_FLOW_CAL", "0")
  if (!mode %in% c("0", "1")) stop("AUSPOL_ONP_FLOW_CAL must be \"0\" or \"1\", not '", mode, "'", call. = FALSE)
  if (identical(mode, "0")) return(ov)
  k <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_ONP_FLOW_CAL_K", "3")))
  if (!is.finite(k) || k < 0) stop("AUSPOL_ONP_FLOW_CAL_K must be a non-negative number", call. = FALSE)
  hl <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_FLOW_RATE_HL", "2")))
  d <- election_dates()
  rates <- onp_pair_rates(hist, d[[target_election]], hl, d)
  for (i in seq_len(nrow(rates)))
    cat(sprintf("ONC0 %s history: %-9s between %s and ONP: %.1f%% to %s (%d elections, %d exclusions, range %.1f-%.1f)\n",
                target_election, rates$from[i], rates$x[i], 100 * rates$r_hist[i], rates$x[i], rates$n_elec[i],
                rates$n_excl[i], 100 * rates$r_min[i], 100 * rates$r_max[i]))
  onp_flow_cal_apply(ov, rates, k, target_election)
}
