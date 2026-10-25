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
#' @return `"decay"` (shipped 2026-10-11, 20-day half-life), `"1"` (28-day window, shipped earlier that day) or
#'   `"0"` (off).
#' @export
level_recent_mode <- function() {
  v <- Sys.getenv("AUSPOL_LEVEL_RECENT", "decay")
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
  fed <- .lr_fed_part(region, aa, half_life, cycle_start, w)
  avg <- vapply(.LR_CLS, function(k) {
    if (!nrow(w) || !k %in% names(w)) return(NA_real_)
    ok <- is.finite(w[[k]]); if (!any(ok)) return(NA_real_)
    num <- sum(wt[ok] * w[[k]][ok]); den <- sum(wt[ok])
    if (!is.null(fed) && is.finite(fed$sum[[k]])) { num <- num + fed$sum[[k]]; den <- den + fed$wt[[k]] }
    num / den
  }, 0)
  list(avg = avg, n_eff = sum(wt) + if (is.null(fed)) 0 else fed$n_eff)
}

#' Weight of a federal state breakdown against a state poll (AUSPOL_LEVEL_FED_R)
#'
#' SHIPPED 2026-10-12 at "0.15" (Pete). "0" leaves the blend without them. A positive number r adds federal voting-intention polls' state
#' breakdowns to [level_recent_decay_avg()] at weight r each, corrected by the state-minus-federal gap.
#' docs/plans/prereg-federal-breakdowns-in-blend-2026-10-12.md.
#' @return Numeric r (0 = off).
#' @export
level_recent_fed_r <- function() {
  r <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_LEVEL_FED_R", "0.15")))
  if (!is.finite(r) || r < 0) stop("AUSPOL_LEVEL_FED_R must be a non-negative number")
  r
}

.lr_fed_memo <- new.env(parent = emptyenv())
.LR_STATE_NAME <- c("New South Wales" = "nsw", "Victoria" = "vic", "Queensland" = "qld",
                    "Western Australia" = "wa", "South Australia" = "sa", "Tasmania" = "tas")

#' Federal polls' state breakdowns, parsed from the Wikipedia poll table
#'
#' One row per poll and state from the "Sub-national polling" tables of the federal opinion-polling pages:
#' `st`, `date` (fieldwork midpoint), `end` (fieldwork end), `firm`, `ALP`, `LNP`, `GRN`. Results rows dropped,
#' duplicates counted once. `scripts/build_fed_state_breakdowns.R` writes it to
#' `output/fed-state-breakdowns.csv`, which is what the blend reads (and what the release carries).
#' @param f Path to `statewide_polls_wiki.csv` (`scripts/fetch_statewide_poll_samples.R`).
#' @return data.table.
#' @export
fed_state_breakdowns_parse <- function(f) {
  if (!file.exists(f)) stop("fed_state_breakdowns_parse(): ", f, " not found (scripts/fetch_statewide_poll_samples.R)")
  w <- data.table::fread(f, showProgress = FALSE)
  # Polls only: the tables also carry each federal election's actual result (row_type "result", 62 rows).
  w <- w[w$region == "fed" & grepl("^Sub-national polling > ", w$section) & w$row_type == "poll"]
  pct <- function(x) suppressWarnings(as.numeric(sub("%", "", as.character(x))))
  gcols <- intersect(c("pv_Grn", "pv_GRN", "pv_Green", "pv_Gre"), names(w))
  grn <- if (length(gcols)) do.call(pmax, c(lapply(gcols, function(cc) pct(w[[cc]])), na.rm = TRUE)) else rep(NA_real_, nrow(w))
  lnp <- ifelse(is.finite(w$lnp_fp), w$lnp_fp,
                ifelse(is.finite(w$lib_fp) | is.finite(w$nat_fp), rowSums(cbind(w$lib_fp, w$nat_fp), na.rm = TRUE), NA_real_))
  # Dated at the fieldwork MIDPOINT: Newspoll's state figures are multi-month aggregates (up to 129 days), and
  # dating them at the end would count three months of fieldwork as last week's poll.
  fs <- as.Date(w$fieldwork_start); fe <- as.Date(w$fieldwork_end)
  half <- as.integer(fe) - as.integer(fs)
  mid <- ifelse(is.finite(fs) & is.finite(fe) & fs <= fe, as.integer(fs) + half %/% 2L, as.integer(fe))
  out <- data.table::data.table(st = unname(.LR_STATE_NAME[sub(" >.*", "", sub("^Sub-national polling > ", "", w$section))]),
                                date = as.Date(mid, origin = "1970-01-01"), firm = w$firm, end = fe,
                                ALP = as.numeric(w$alp_fp), LNP = lnp, GRN = grn)
  out <- out[!is.na(out$st) & is.finite(out$date) & is.finite(out$ALP)]
  # The same poll appears more than once in some tables (18 extra copies): count it once.
  out <- unique(out, by = c("st", "date", "end", "firm", "ALP", "LNP", "GRN"))
  if (!nrow(out)) stop("no federal state-breakdown rows parsed from ", f)
  out
}

# The blend's copy: output/fed-state-breakdowns.csv, read once per process.
#' @noRd
.lr_fed_polls <- function() {
  if (!is.null(.lr_fed_memo$tab)) return(.lr_fed_memo$tab)
  f <- out_path("fed-state-breakdowns.csv")
  if (!file.exists(f)) stop("AUSPOL_LEVEL_FED_R > 0 needs ", f, " -- run scripts/build_fed_state_breakdowns.R ",
                            "(rebuild stage 5b; the forecast workflow downloads it from shipped-models)")
  out <- data.table::fread(f, showProgress = FALSE)
  out[, `:=`(date = as.Date(date), end = as.Date(end))]
  if (!nrow(out) || !all(c("st", "date", "end", "ALP", "LNP", "GRN") %in% names(out))) stop(f, " is empty or lacks columns")
  assign("tab", out, envir = .lr_fed_memo)
  out
}

# The federal part of the decayed mean: per class, r * sum(w_f * (y_f + gap)) and r * sum(w_f). NULL when off,
# for a federal target, or with no breakdown in the cycle. gap = state minus federal, decayed means with the
# AUSPOL_LEVEL_FED_GAP_HL half-life (default 90 days), shrunk to 0 by n/(n+1), n = the smaller decayed weight.
#' @noRd
.lr_fed_part <- function(region, aa, half_life, cycle_start, state_polls) {
  r <- level_recent_fed_r()
  if (r <= 0 || identical(region, "fed")) return(NULL)
  ghl <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_LEVEL_FED_GAP_HL", "90")))
  if (!is.finite(ghl) || ghl <= 0) stop("AUSPOL_LEVEL_FED_GAP_HL must be a positive number of days")
  fp <- .lr_fed_polls()
  reg <- region
  # fieldwork END before the as-at date (the midpoint alone would admit a poll still in the field)
  f <- fp[fp$st == reg & fp$end < aa & fp$date > as.Date(cycle_start)]
  stopifnot(all(f$end < aa))
  if (!nrow(f)) return(NULL)
  wf <- 2^(-as.numeric(aa - f$date) / half_life)
  gf <- 2^(-as.numeric(aa - f$date) / ghl)
  gs <- 2^(-as.numeric(aa - state_polls$date) / ghl)
  res <- lapply(.LR_CLS, function(k) {
    okf <- is.finite(f[[k]])
    oks <- if (k %in% names(state_polls)) is.finite(state_polls[[k]]) else rep(FALSE, nrow(state_polls))
    if (!any(okf) || !any(oks)) return(c(sum = NA_real_, wt = 0))
    gap <- sum(gs[oks] * state_polls[[k]][oks]) / sum(gs[oks]) - sum(gf[okf] * f[[k]][okf]) / sum(gf[okf])
    n <- min(sum(gs[oks]), sum(gf[okf]))
    gap <- gap * n / (n + 1)
    c(sum = r * sum(wf[okf] * (f[[k]][okf] + gap)), wt = r * sum(wf[okf]))
  })
  names(res) <- .LR_CLS
  # n_eff counts every breakdown (all have ALP), the same convention as the state side, whose n_eff counts every
  # poll whatever classes it reports. The per-class `wt` is what weights each class's mean.
  list(sum = vapply(res, `[[`, 0, "sum"), wt = vapply(res, `[[`, 0, "wt"), n_eff = r * sum(wf))
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
  # AUSPOL_LEVEL_RECENT_HALFLIFE fixes the half-life (days) and fits only k
  # (prereg Amendment 3: the free fit ran to 1 day and was too jumpy). Unset or
  # "fit": the grid above.
  hl <- Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE", "20")
  if (!identical(hl, "fit")) {
    hv <- suppressWarnings(as.numeric(hl))
    if (!is.finite(hv) || hv <= 0) stop("AUSPOL_LEVEL_RECENT_HALFLIFE must be \"fit\" or a positive number of days, not ", hl)
    hs <- hv
  }
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
  key <- paste(target, Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE", "20"), Sys.getenv("AUSPOL_LEVEL_FED_R", "0.15"),
               Sys.getenv("AUSPOL_LEVEL_FED_GAP_HL", "90"), if (file.exists(f)) paste(file.info(f)$mtime, file.info(f)$size) else "none")
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

# ---- F12: the trees' level_pred against the recent-poll blend ---------------
# reviews/audit-f8-f19-status-2026-10-25.md F12; plans/prereg-live-level-pred-2026-10-25.md.
# Training level_pred (scripts/build_level_pred.R -> forecast_statewide_for()) has no recent-poll blend, while
# the live forecast serves the trees a level_pred built from the BLENDED state_mean. Two switches, both "0":
# AUSPOL_LIVE_LEVEL_PRED_TREND serves the live trees the pre-blend level (diagnostic, matches today's training);
# AUSPOL_LEVEL_PRED_RECENT blends the training level_pred (the fix; needs a stage-3 rebuild).

#' Serve the live trees the pre-blend statewide level? (AUSPOL_LIVE_LEVEL_PRED_TREND)
#'
#' @return `TRUE` when `"1"`, `FALSE` when `"0"` (default); anything else is an error.
#' @export
live_level_pred_trend <- function() {
  v <- Sys.getenv("AUSPOL_LIVE_LEVEL_PRED_TREND", "0")
  if (!v %in% c("0", "1")) stop("AUSPOL_LIVE_LEVEL_PRED_TREND must be \"0\" or \"1\", not ", v, call. = FALSE)
  identical(v, "1")
}

#' The statewide level the live xgb layer is served as `level_pred`
#'
#' Returns `blended` (the level after [level_recent_apply()], which the rest of the forecast uses) unless
#' `enabled`, when it returns `trend`, the same level captured just before the blend. That is the recipe the
#' trees were trained on while `scripts/build_level_pred.R` runs without `AUSPOL_LEVEL_PRED_RECENT=1`.
#' Either way it prints, per class, blended minus pre-blend and which one was served.
#'
#' @param blended,trend Named numeric statewide class shares (points), same classes.
#' @param enabled Logical; defaults to [live_level_pred_trend()].
#' @param code Check code for the printed line.
#' @return The served level (named numeric, in `blended`'s class order).
#' @export
live_level_pred_serve <- function(blended, trend, enabled = live_level_pred_trend(), code = "LLP1") {
  # OFF: the published path. Serve `blended` untouched and never stop -- a forced scenario (AUSPOL_FORCE_FP) can
  # legitimately make the two differ in total -- but still print the gap when it can be computed.
  if (!isTRUE(enabled)) {
    ok <- is.numeric(trend) && !is.null(names(trend)) && setequal(names(trend), names(blended)) &&
      !anyDuplicated(names(trend)) && all(is.finite(trend)) && all(is.finite(blended))
    cat(sprintf("%s  xgb level_pred served from the BLENDED level (AUSPOL_LIVE_LEVEL_PRED_TREND=0); blended minus pre-blend: %s\n",
                code, if (ok) {
                  d <- blended - trend[names(blended)]
                  sprintf("%s (max |diff| %.2f)", paste(sprintf("%s %+.2f", names(d), d), collapse = ", "), max(abs(d)))
                } else "not comparable (class sets differ)"))
    return(blended)
  }
  chk <- function(x, nm) {
    if (!is.numeric(x) || is.null(names(x)) || anyNA(names(x)) || anyDuplicated(names(x)) || !all(nzchar(names(x))))
      stop(sprintf("%s! live_level_pred_serve(): %s needs unique, non-empty class names", code, nm), call. = FALSE)
    if (!all(is.finite(x)) || any(x < 0))
      stop(sprintf("%s! live_level_pred_serve(): %s has a non-finite or negative share", code, nm), call. = FALSE)
  }
  chk(blended, "blended"); chk(trend, "trend")
  if (!setequal(names(blended), names(trend)))
    stop(sprintf("%s! live_level_pred_serve(): the pre-blend level has classes %s, the blended one %s", code,
                 paste(sort(names(trend)), collapse = "/"), paste(sort(names(blended)), collapse = "/")), call. = FALSE)
  trend <- trend[names(blended)]
  # The blend moves its net change into the other classes, so the totals agree. A gap means `trend` was
  # captured at a different point of the pipeline (before the rescale to 100, or before a forced scenario).
  if (abs(sum(trend) - sum(blended)) > 1e-6)
    stop(sprintf("%s! live_level_pred_serve(): pre-blend level sums to %.4f, blended to %.4f -- not the same pipeline point",
                 code, sum(trend), sum(blended)), call. = FALSE)
  d <- blended - trend
  cat(sprintf("%s  xgb level_pred served from the PRE-BLEND trend level, the training recipe (AUSPOL_LIVE_LEVEL_PRED_TREND=1); blended minus pre-blend: %s (max |diff| %.2f)\n",
              code, paste(sprintf("%s %+.2f", names(d), d), collapse = ", "), max(abs(d))))
  trend
}

#' Blend the TRAINING level_pred toward recent polls? (AUSPOL_LEVEL_PRED_RECENT)
#'
#' @return `TRUE` when `"1"`, `FALSE` when `"0"` (default); anything else is an error.
#' @export
level_pred_recent <- function() {
  v <- Sys.getenv("AUSPOL_LEVEL_PRED_RECENT", "0")
  if (!v %in% c("0", "1")) stop("AUSPOL_LEVEL_PRED_RECENT must be \"0\" or \"1\", not ", v, call. = FALSE)
  identical(v, "1")
}

#' The recent-poll blend for one training pair's level_pred, time-forward
#'
#' [level_recent_apply()] at `as_at = election_date`: only polls fielded BEFORE polling day count (state
#' polls by date, federal breakdowns by fieldwork end), and the blend constant is fitted on elections dated
#' before the pair ([level_recent_decay_fit()] through [elections_before()]). It is the call the state
#' harnesses make through [forecast_statewide_or_oracle()]. Errors propagate: a pair whose blend cannot be
#' computed must stop the build, not fall back to an unblended level that would be indistinguishable from it.
#'
#' @param levels Named numeric statewide class shares for the pair (`forecast_statewide_for()$st_fc`).
#' @param pair Election label, e.g. `"vic2022"`.
#' @param region Poll region.
#' @param election_date Polling day (Date or ISO string).
#' @param code Check code.
#' @param tab Optional `level-recent.csv` table (tests); NULL reads the file.
#' @return `levels` blended, with attribute `moved` = sum of absolute changes in points.
#' @export
level_pred_recent_apply <- function(levels, pair, region, election_date, code = "LPR1", tab = NULL) {
  ed <- as.Date(election_date)
  if (length(ed) != 1L || !is.finite(ed)) stop(sprintf("%s! %s: no polling day", code, pair), call. = FALSE)
  out <- level_recent_apply(levels, pair, region, ed, code = code, tab = tab, as_at = ed)
  if (!identical(names(out), names(levels)) || !all(is.finite(out)))
    stop(sprintf("%s! %s: the blend returned a different or non-finite class set", code, pair), call. = FALSE)
  attr(out, "moved") <- sum(abs(out - levels))
  out
}
