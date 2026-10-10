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
#' @return `"1"` (shipped 2026-10-11) or `"0"` (off).
#' @export
level_recent_mode <- function() {
  v <- Sys.getenv("AUSPOL_LEVEL_RECENT", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_LEVEL_RECENT must be \"0\" or \"1\", not ", v)
  v
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
  if ("NAT" %in% names(w)) w$LNP <- rowSums(cbind(w$LNP, w$NAT), na.rm = TRUE)
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
  if (!identical(level_recent_mode(), "1")) return(levels)
  ra <- level_recent_avg(region, election_date, as_at = as_at)
  kf <- level_recent_k(target, tab)
  w <- if (ra$n > 0 && is.finite(kf$k)) ra$n / (ra$n + kf$k) else 0
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
  cat(sprintf("%s  recent-poll level blend for %s: %d polls in 28 days, k %.2f (fitted on %d earlier elections), w %.2f: %s\n",
              code, target, ra$n, kf$k, kf$n_el, w,
              paste(sprintf("%s %.1f->%.1f (polls %.1f)", hit, levels[hit], out[hit], ra$avg[hit]), collapse = ", ")))
  out
}
