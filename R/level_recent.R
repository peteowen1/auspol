# AUSPOL_LEVEL_RECENT: blend the day-before statewide level toward the polls of
# the last 28 days. plans/prereg-level-recent-blend-2026-10-10.md.
#
# The trend lagged the late polls: Victoria 2022 Coalition trend 31.4, last-28-
# day poll mean 34.1, actual 34.5 (reviews/trend-lag-day-before-2026-10-10.md),
# which under-called every Liberal primary and, where Liberal preferences went
# to the Greens, put Labor's two-candidate share 5-8 points too high. For ALP,
# LNP and GRN the level becomes (1 - w) x trend + w x avg28, w = n28 / (n28 + k),
# k fitted on earlier elections only; no cut-off on the number of polls.

.LR_CLS <- c("ALP", "LNP", "GRN")

#' Is the recent-poll level blend on?
#'
#' @return `"1"` (shipped 2026-10-11: 28-day window), `"decay"` (every poll of
#'   the cycle weighted by age, prereg Amendment 2) or `"0"` (off).
#' @export
level_recent_mode <- function() {
  v <- Sys.getenv("AUSPOL_LEVEL_RECENT", "1")
  if (!v %in% c("0", "1", "decay")) stop("AUSPOL_LEVEL_RECENT must be \"0\", \"1\" or \"decay\", not ", v)
  v
}

.lr_poll_memo <- new.env(parent = emptyenv())

# A region's polls with the Nationals folded into LNP (NA when neither is
# reported), read once per process.
#' @noRd
.lr_polls <- function(region) {
  if (!is.null(.lr_poll_memo[[region]])) return(.lr_poll_memo[[region]])
  p <- data.table::as.data.table(suppressMessages(load_polls(region)))
  if ("NAT" %in% names(p)) {
    both_na <- is.na(p$LNP) & is.na(p$NAT)
    p$LNP <- rowSums(cbind(p$LNP, p$NAT), na.rm = TRUE)
    p$LNP[both_na] <- NA_real_
  }
  assign(region, p, envir = .lr_poll_memo)
  p
}

#' Age-weighted mean of a cycle's polls (no window)
#'
#' Every poll fielded after `cycle_start` and before the as-at date counts,
#' weighted `2^(-age / half_life)`, age in days before the as-at date.
#'
#' @param region Poll region.
#' @param election_date Polling day.
#' @param half_life Days.
#' @param cycle_start The previous election's polling day.
#' @param as_at End of the data (exclusive); polling day in the backtests, today live.
#' @return list `avg` (named ALP/LNP/GRN) and `n_eff` (summed weights).
#' @export
level_recent_decay_avg <- function(region, election_date, half_life, cycle_start, as_at = election_date) {
  p <- .lr_polls(region)
  aa <- min(as.Date(as_at), as.Date(election_date))
  w <- p[p$date < aa & p$date > as.Date(cycle_start)]
  wt <- 2^(-as.numeric(aa - w$date) / half_life)
  avg <- vapply(.LR_CLS, function(k) {
    if (!nrow(w) || !k %in% names(w)) return(NA_real_)
    ok <- is.finite(w[[k]]); if (!any(ok)) return(NA_real_)
    sum(wt[ok] * w[[k]][ok]) / sum(wt[ok])
  }, 0)
  list(avg = avg, n_eff = sum(wt))
}

#' Half-life and blend constant for the decayed level, fitted on earlier elections
#'
#' Grid over the half-life (days) and `k`, minimising squared error of the
#' blended ALP/LNP/GRN level against the actual over every election in `tab`
#' dated before `target` (the unblended trend and actual come from `tab`).
#'
#' @param target Election label.
#' @param tab `output/level-recent.csv` when NULL.
#' @return list `half_life`, `k` (Inf with no earlier election), `n_el`.
#' @export
level_recent_decay_fit <- function(target, tab = NULL) {
  if (is.null(tab)) {
    f <- out_path("level-recent.csv")
    if (!file.exists(f)) stop("AUSPOL_LEVEL_RECENT=decay needs ", f, " -- run scripts/build_level_recent_table.R")
    tab <- data.table::fread(f, showProgress = FALSE)
  }
  d <- tab[elections_before(tab$election, target) & is.finite(tab$trend) & is.finite(tab$actual)]
  if (!nrow(d)) return(list(half_life = NA_real_, k = Inf, n_el = 0L))
  prs <- all_election_pairs(); prev <- stats::setNames(vapply(prs, `[[`, "", "prev"), vapply(prs, `[[`, "", "election"))
  eds <- election_dates()
  hs <- c(1, 1.5, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 90, 150)
  ks <- exp(seq(log(0.01), log(400), length.out = 90))
  best <- list(sse = Inf)
  for (h in hs) {
    A <- data.table::rbindlist(lapply(unique(d$election), function(e) {
      r <- level_recent_decay_avg(d$region[d$election == e][1], as.Date(unname(eds[e])), h, as.Date(unname(eds[prev[[e]]])))
      data.table::data.table(election = e, cls = names(r$avg), avg = unname(r$avg), n_eff = r$n_eff)
    }))
    m <- merge(d[, list(election, cls, trend, actual)], A, by = c("election", "cls"))
    m <- m[is.finite(m$avg) & m$n_eff > 0]
    if (!nrow(m)) next
    for (k in ks) {
      w <- m$n_eff / (m$n_eff + k)
      sse <- sum((m$trend + w * (m$avg - m$trend) - m$actual)^2)
      if (sse < best$sse) best <- list(sse = sse, half_life = h, k = k)
    }
  }
  if (!is.finite(best$sse)) return(list(half_life = NA_real_, k = Inf, n_el = 0L))
  list(half_life = best$half_life, k = best$k, n_el = data.table::uniqueN(d$election))
}

#' Mean of the polls fielded in the 28 days before polling day
#'
#' The Nationals are folded into LNP where a poll file reports them separately
#' (WA), as the trend already does; otherwise WA's LNP column is Liberals only.
#'
#' @param region Poll region (`"vic"`, `"fed"`, ...).
#' @param election_date Polling day (Date). Only polls fielded before it are read.
#' @param days Window length in days.
#' @param as_at End of the window (exclusive); polling day in the backtests, today
#'   for the live forecast (a window ending on a future polling day holds nothing).
#' @return list `avg` (named ALP/LNP/GRN, NA where absent) and `n` (polls in the window).
#' @export
level_recent_avg <- function(region, election_date, days = 28L, as_at = election_date) {
  p <- data.table::as.data.table(suppressMessages(load_polls(region)))
  ed <- as.Date(election_date); aa <- min(as.Date(as_at), ed)
  w <- p[p$date < aa & p$date >= aa - days]
  if ("NAT" %in% names(w)) {   # NA when a poll reports neither, not 0 (review 2026-10-11)
    both_na <- is.na(w$LNP) & is.na(w$NAT)
    w$LNP <- rowSums(cbind(w$LNP, w$NAT), na.rm = TRUE)
    w$LNP[both_na] <- NA_real_
  }
  avg <- vapply(.LR_CLS, function(k) if (nrow(w) && k %in% names(w)) mean(w[[k]], na.rm = TRUE) else NA_real_, 0)
  list(avg = avg, n = nrow(w))
}

#' The blend constant k, fitted on earlier elections
#'
#' Grid search of `k` (log-spaced) minimising the squared error of the blended
#' ALP/LNP/GRN level against the actual over every election in `tab` dated
#' before `target`. No earlier election: `Inf` (weight 0, the trend alone).
#'
#' @param target Election label.
#' @param tab The table from `scripts/build_level_recent_table.R`; read from
#'   `output/level-recent.csv` when NULL.
#' @return list `k`, `n_el` (earlier elections used), `sse`.
#' @export
level_recent_k <- function(target, tab = NULL) {
  if (is.null(tab)) {
    f <- out_path("level-recent.csv")
    if (!file.exists(f)) stop("AUSPOL_LEVEL_RECENT=1 needs ", f, " -- run scripts/build_level_recent_table.R")
    tab <- data.table::fread(f, showProgress = FALSE)
  }
  d <- tab[elections_before(tab$election, target) & is.finite(tab$trend) & is.finite(tab$avg28) &
             is.finite(tab$actual) & tab$n28 > 0]
  if (!nrow(d)) return(list(k = Inf, n_el = 0L, sse = NA_real_))
  grid <- exp(seq(log(0.25), log(400), length.out = 120))
  sse <- vapply(grid, function(k) { w <- d$n28 / (d$n28 + k); sum((d$trend + w * (d$avg28 - d$trend) - d$actual)^2) }, 0)
  list(k = grid[which.min(sse)], n_el = data.table::uniqueN(d$election), sse = min(sse))
}

#' Blend a statewide level toward the last 28 days of polls
#'
#' A no-op unless `AUSPOL_LEVEL_RECENT` is "1". ALP, LNP and GRN move toward
#' the poll mean by `w = n28 / (n28 + k)`; every other class absorbs the change
#' pro rata, so the level keeps its total.
#'
#' @param levels Named numeric statewide level (share points).
#' @param target Election label (for the time-forward k).
#' @param region Poll region.
#' @param election_date Polling day.
#' @param code Log prefix.
#' @param tab Optional pre-read table for [level_recent_k()].
#' @param as_at Passed to [level_recent_avg()].
#' @return `levels`, blended (attributes kept).
#' @export
level_recent_apply <- function(levels, target, region, election_date, code = "LR0", tab = NULL,
                               as_at = election_date) {
  mode <- level_recent_mode()
  if (identical(mode, "0")) return(levels)
  if (identical(mode, "decay")) {
    fit <- .lr_decay_fit_cached(target, tab)
    cs <- .lr_prev_date(target)
    ra <- if (is.finite(fit$half_life) && !is.na(cs))
      level_recent_decay_avg(region, election_date, fit$half_life, cs, as_at = as_at) else list(avg = stats::setNames(rep(NA_real_, 3), .LR_CLS), n_eff = 0)
    n <- ra$n_eff; k <- fit$k
    note <- sprintf("half-life %s days, n_eff %.2f, k %.2f (fitted on %d earlier elections)",
                    if (is.finite(fit$half_life)) format(fit$half_life) else "-", n, k, fit$n_el)
  } else {
    ra <- level_recent_avg(region, election_date, as_at = as_at)
    kf <- level_recent_k(target, tab)
    n <- ra$n; k <- kf$k
    note <- sprintf("%d polls in 28 days, k %.2f (fitted on %d earlier elections)", ra$n, kf$k, kf$n_el)
  }
  w <- if (n > 0 && is.finite(k)) n / (n + k) else 0
  out <- levels
  hit <- intersect(.LR_CLS, names(levels))
  hit <- hit[is.finite(ra$avg[hit])]
  if (w > 0 && length(hit)) {
    new <- (1 - w) * levels[hit] + w * ra$avg[hit]
    delta <- sum(new - levels[hit])
    oth <- setdiff(names(levels), hit)
    out[hit] <- new
    if (length(oth) && sum(levels[oth]) > 0) out[oth] <- levels[oth] * max(0, sum(levels[oth]) - delta) / sum(levels[oth])
  }
  cat(sprintf("%s  recent-poll level blend (%s) for %s: %s, w %.2f: %s\n",
              code, if (identical(mode, "decay")) "decay" else "28-day window", target, note, w,
              paste(sprintf("%s %.1f->%.1f (polls %.1f)", hit, levels[hit], out[hit], ra$avg[hit]), collapse = ", ")))
  out
}

.lr_fit_memo <- new.env(parent = emptyenv())
#' @noRd
.lr_decay_fit_cached <- function(target, tab = NULL) {
  if (!is.null(tab)) return(level_recent_decay_fit(target, tab))
  f <- out_path("level-recent.csv")
  key <- paste(target, if (file.exists(f)) paste(file.info(f)$mtime, file.info(f)$size) else "none")
  if (is.null(.lr_fit_memo[[key]])) assign(key, level_recent_decay_fit(target, NULL), envir = .lr_fit_memo)
  .lr_fit_memo[[key]]
}

# The previous election's polling day in the target's region (works for live
# targets that are not in all_election_pairs()).
#' @noRd
.lr_prev_date <- function(target) {
  ed <- election_dates(); reg <- sub("[0-9]{4}$", "", target)
  same <- ed[sub("[0-9]{4}$", "", names(ed)) == reg]
  td <- as.Date(unname(ed[target])); d <- as.Date(unname(same)); d <- d[is.finite(d) & d < td]
  if (!length(d)) NA else max(d)
}
