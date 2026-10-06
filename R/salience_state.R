#' State-election Google Trends salience, built from the raw weekly series on disk
#'
#' `output/salience-v6.csv` keeps one number per candidate (`jump`). The raw
#' weekly series behind it are cached by `scripts/fetch_salience_v6.R` in
#' `external/reference/trends/`, one RDS per query batch. This module rebuilds
#' the fuller set of statistics (level, jump, rise, peak, share of the window's
#' search interest that fell in the last eight weeks, and within-election
#' percentiles) for STATE elections, from those files, with NO fetching. See
#' `docs/reviews/state-salience-2026-10-06.md` for what it found.
#'
#' Rules this module is built around:
#' * Time-forward: a point dated on or after polling day never counts. The
#'   cached windows end the day before polling day already, and this is
#'   enforced again here and counted in the diagnostics.
#' * Raw series are never summarised away: everything is derived from the
#'   cached weekly points.
#' * A candidate with no series gets `NA`, never a constant. A constant on rows
#'   where a feature does not apply is a label for the subgroup, and a tree
#'   splits on it (docs on `state_elec_gap = 999`).
#' * Percentiles are ranked among NON-ZERO values only
#'   (`AUSPOL_SALIENCE_PCTILE_NZ`): the field is mostly exact zeros, and ranking
#'   them mid-scale hands any non-zero value a high percentile automatically.
#'
#' @name salience_state
NULL

#' The state elections whose Trends series are cached
#'
#' Polling days, geography and the head-of-government anchor query used for
#' cross-batch linking, copied from `ELS` in `scripts/fetch_salience_v6.R`
#' (that list is local to the script, so cannot be reused).
#' @return A `data.table` with `election`, `poll`, `geo`, `anchor`.
#' @export
state_trends_elections <- function() {
  data.table::data.table(
    election = c("nsw2019", "nsw2023", "sa2022", "sa2026", "vic2014", "vic2018",
                 "vic2022", "qld2020", "qld2024", "wa2005", "wa2008", "wa2013",
                 "wa2017", "wa2021", "wa2025"),
    poll = c("2019-03-23", "2023-03-25", "2022-03-19", "2026-03-21",
             "2014-11-29", "2018-11-24", "2022-11-26", "2020-10-31",
             "2024-10-26", "2005-02-26", "2008-09-06", "2013-03-09",
             "2017-03-11", "2021-03-13", "2025-03-08"),
    geo = c("AU-NSW", "AU-NSW", "AU-SA", "AU-SA", "AU-VIC", "AU-VIC", "AU-VIC",
            "AU-QLD", "AU-QLD", "AU-WA", "AU-WA", "AU-WA", "AU-WA", "AU-WA",
            "AU-WA"),
    anchor = c("Gladys Berejiklian", "Chris Minns", "Steven Marshall",
               "Peter Malinauskas", "Denis Napthine", "Daniel Andrews",
               "Daniel Andrews", "Annastacia Palaszczuk", "Steven Miles",
               "Geoff Gallop", "Alan Carpenter", "Colin Barnett",
               "Colin Barnett", "Mark McGowan", "Roger Cook"))
}

#' Load the cached query batches for one state election
#'
#' Files are matched on the cache's own key prefix
#' (`v6-<geo>-<from>-<to>-`, non-alphanumerics as `_`), where `to` is the day
#' before polling day and `from` is 400 days earlier -- the window
#' `fetch_salience_v6.R` queried.
#'
#' @param poll Polling day, `Date`.
#' @param geo Trends geography, e.g. `"AU-NSW"`.
#' @param cache_dir The Trends cache directory.
#' @return A list of `data.table`s (`keyword`, `date`, `hits`), one per cached
#'   batch; empty responses are skipped.
#' @export
state_trends_load <- function(poll, geo, cache_dir) {
  to <- as.Date(poll) - 1L
  from <- to - 400L
  prefix <- gsub("[^A-Za-z0-9]", "_", sprintf("v6-%s-%s-%s-", geo, from, to))
  fs <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  fs <- fs[startsWith(basename(fs), prefix)]
  out <- list()
  for (f in sort(fs)) {
    z <- readRDS(f)
    if (isTRUE(z$empty) || is.null(z$series)) next
    s <- data.table::as.data.table(z$series)[, c("keyword", "date", "hits")]
    s[, date := as.Date(date)]
    s[, fetched := as.Date(if (is.null(z$fetched)) NA else z$fetched)]
    out[[basename(f)]] <- s
  }
  out
}

# Per-keyword camp/base means over the SAME windows as fetch_salience_v6.R's
# jump_of(): campaign = the 8 weeks to polling day, base = the 300 days before.
# `pd` (not `poll`) so no argument name can collide with a column.
.ss_window_stats <- function(s, pd) {
  camp_w <- s[s$date > pd - 56L & s$date <= pd]
  base_w <- s[s$date > pd - 300L & s$date <= pd - 56L]
  camp <- camp_w[, list(camp = mean(hits), camp_sum = sum(hits)), by = "keyword"]
  base <- base_w[, list(base = mean(hits)), by = "keyword"]
  tot <- s[, list(tot_sum = sum(hits), peak = max(hits)), by = "keyword"]
  pk <- s[, list(peak_date = date[which.max(hits)]), by = "keyword"]
  m <- merge(camp, base, by = "keyword", all.x = TRUE)
  m[is.na(base), base := 0]
  m <- merge(m, tot, by = "keyword", all.x = TRUE)
  m <- merge(m, pk, by = "keyword", all.x = TRUE)
  m[, jump := camp - base]
  m[, fetched := suppressWarnings(max(s$fetched))]
  m[]
}

# Rank among strictly positive values only; non-positive finite values score 0;
# NA where the field has fewer than `min_nz` positive values (said, not filled).
.ss_pctile_nz <- function(x, min_nz = 10L) {
  out <- rep(NA_real_, length(x))
  pos <- which(is.finite(x) & x > 0)
  if (length(pos) < min_nz) return(out)
  out[is.finite(x) & x <= 0] <- 0
  out[pos] <- rank(x[pos], ties.method = "average") / length(pos)
  out
}

#' Statistics for every cached keyword of one state election
#'
#' Reproduces `fetch_salience_v6.R`'s two-stage scale -- batches of five
#' candidates each normalised on their own loudest member, then one linking
#' query per batch representative against the head-of-government anchor -- from
#' the cached files, so values from different batches share one scale.
#'
#' A batch whose loudest member has no usable link (or whose jump is not
#' positive) cannot be put on the common scale: its `level`, `base`, `peak` are
#' `NA`. Its `jump` is kept only where the batch is silent or falling (jump <= 0,
#' scale-free as a sign) and is `NA` otherwise. `rise` and `share8` are ratios
#' within one batch and need no scale.
#'
#' @param batches List of `data.table`s from [state_trends_load()].
#' @param poll_date Polling day, `Date`.
#' @param anchor The anchor query used for linking.
#' @param min_nz Minimum positive values before a percentile is reported.
#' @return A list: `stats` (one row per keyword) and `diag` (counts).
#' @export
state_salience_stats <- function(batches, poll_date, anchor, min_nz = 10L) {
  pd <- as.Date(poll_date)
  n_future <- 0L
  batches <- lapply(batches, function(s) {
    keep <- s$date < pd
    n_future <<- n_future + sum(!keep)
    s[keep]
  })
  is_link <- vapply(batches, function(s) anchor %in% s$keyword, TRUE)

  # Stage 1: batch-local statistics, representative = loudest jump.
  bstats <- lapply(batches[!is_link], .ss_window_stats, pd = pd)
  reps <- vapply(bstats, function(b) b$keyword[which.max(b$jump)], "")
  live <- vapply(bstats, function(b) max(b$jump) > 0, TRUE)

  # Stage 2: link ratios, jump relative to the anchor's jump in the same query.
  link_ratio <- NULL
  link_only <- list()
  for (s in batches[is_link]) {
    m <- .ss_window_stats(s, pd)
    a <- m$jump[m$keyword == anchor]
    if (length(a) != 1L || !is.finite(a) || a <= 0) next
    r <- m[m$keyword != anchor]
    link_ratio <- rbind(link_ratio, data.table::data.table(keyword = r$keyword, ratio = r$jump / a))
    r[, unit := 1 / a]
    link_only[[length(link_only) + 1L]] <- r
  }
  if (!is.null(link_ratio)) link_ratio <- link_ratio[, list(ratio = max(ratio)), by = "keyword"]

  out <- list()
  for (j in seq_along(bstats)) {
    b <- data.table::copy(bstats[[j]])
    scale <- NA_real_
    if (live[j] && !is.null(link_ratio)) {
      v <- link_ratio$ratio[link_ratio$keyword == reps[j]]
      own <- b$jump[b$keyword == reps[j]]
      if (length(v) == 1L && length(own) == 1L && own > 0) scale <- v / own
    }
    b[, `:=`(scale = scale, batch = j, rep = reps[j], live = live[j])]
    out[[length(out) + 1L]] <- b
  }
  # Keywords that only appear in an anchor-containing query have a scale given
  # by that query alone (anchor jump = 1 unit).
  have <- if (length(out)) unique(unlist(lapply(out, function(b) b$keyword))) else character(0)
  for (r in link_only) {
    r <- r[!r$keyword %in% have]
    if (!nrow(r)) next
    r[, `:=`(scale = unit, batch = NA_integer_, rep = NA_character_, live = NA)]
    r[, unit := NULL]
    out[[length(out) + 1L]] <- r
    have <- c(have, r$keyword)
  }
  if (!length(out)) return(list(stats = NULL, diag = list(n_future = n_future)))
  S <- data.table::rbindlist(out, use.names = TRUE)
  # A keyword fetched in several runs (candidate lists changed between runs, so
  # batches were re-cut): keep the instance from the LATEST run.
  data.table::setorderv(S, "fetched", order = -1L, na.last = TRUE)
  n_dup <- sum(duplicated(S$keyword))
  S <- S[!duplicated(S$keyword)]

  # jump keeps its sign-only meaning where the batch could not be scaled but
  # is not rising; otherwise it needs a scale.
  S[, jump_s := ifelse(is.finite(scale), jump * scale,
                       ifelse(!is.na(live) & !live, jump, NA_real_))]
  S[, `:=`(level = camp * scale, base_level = base * scale, peak_s = peak * scale)]
  S[, `:=`(rise = camp / pmax(base, 0.5),
           share8 = ifelse(tot_sum > 0, camp_sum / tot_sum, NA_real_),
           peak_weeks_before = as.integer(floor(as.numeric(pd - peak_date) / 7)))]
  S[, `:=`(jump_pctile = .ss_pctile_nz(jump_s, min_nz),
           level_pctile = .ss_pctile_nz(level, min_nz))]
  stats <- S[, list(keyword, batch, rep, scaled = is.finite(scale), level, base_level,
                    jump = jump_s, rise, peak = peak_s, share8, peak_weeks_before,
                    jump_pctile, level_pctile)]
  list(stats = stats,
       diag = list(n_future = n_future, n_link_files = sum(is_link),
                   n_batches = sum(!is_link), n_live = sum(live),
                   n_live_batches_unscaled = sum(vapply(out[seq_along(bstats)],
                     function(b) is.na(b$scale[1]) && isTRUE(b$live[1]), TRUE)),
                   n_dup_keywords = n_dup,
                   n_nonzero_jump = sum(S$jump_s > 0, na.rm = TRUE)))
}

#' Build the state salience population, one row per candidacy
#'
#' Every candidacy of every cached state election gets a row. Candidacies with
#' no cached series carry `NA` in every statistic and `has_series = FALSE`.
#'
#' @param cache_dir Trends cache directory (`external/reference/trends`).
#' @param cand The candidacy table (`output/candidacies.csv`).
#' @param elections Registry from [state_trends_elections()].
#' @return A list: `pop` (`data.table`, one row per candidacy) and `diag`
#'   (one row per election).
#' @export
build_state_salience <- function(cache_dir, cand, elections = state_trends_elections()) {
  cand <- data.table::as.data.table(cand)
  pops <- list(); dg <- list()
  for (i in seq_len(nrow(elections))) {
    el <- elections$election[i]
    target_election <- el
    batches <- state_trends_load(elections$poll[i], elections$geo[i], cache_dir)
    cd <- cand[cand$election == target_election]
    if (!nrow(cd)) next
    cd[, keyword := search_form(given, surname, name)]
    res <- if (length(batches)) state_salience_stats(batches, elections$poll[i], elections$anchor[i]) else NULL
    st <- if (is.null(res)) NULL else res$stats
    pop <- cd[, list(election, seat, party, name, keyword, pcv, elected)]
    if (!is.null(st) && nrow(st)) {
      pop <- merge(pop, st, by = "keyword", all.x = TRUE, sort = FALSE)
      pop[, has_series := !is.na(batch) | !is.na(level) | !is.na(jump) | !is.na(rise)]
    } else {
      pop[, has_series := FALSE]
    }
    pop[, poll := as.character(elections$poll[i])]
    pops[[el]] <- pop
    dg[[el]] <- data.table::data.table(
      election = el, candidacies = nrow(cd), with_series = sum(pop$has_series),
      cached_keywords = if (is.null(st)) 0L else nrow(st),
      nonzero_jump = if (is.null(res)) 0L else res$diag$n_nonzero_jump,
      future_points_dropped = if (is.null(res)) 0L else res$diag$n_future)
  }
  list(pop = data.table::rbindlist(pops, fill = TRUE),
       diag = data.table::rbindlist(dg, fill = TRUE))
}

#' State salience features for the primary-vote xgb model
#'
#' Looks up, per (pair, seat, party), the strongest candidate of that class on
#' each state-salience statistic. `NA` where the pair has no state series or the
#' class had no candidate with a series -- never a constant. (xgboost treats
#' `NA` as missing; the federal and Victoria-2026 rows are structurally `NA`
#' too, which a tree could in principle use as a jurisdiction label -- the
#' prereg must test that.)
#'
#' @param keys `data.table` with `pair`, `seat`, `party`.
#' @param tab The class-level table (`output/state-salience-features.csv`);
#'   read from `output/` when `NULL`.
#' @return `keys` with `ss_level`, `ss_rise`, `ss_peak`, `ss_share8`,
#'   `ss_jump_pctile`, `ss_level_pctile` (row order kept).
#' @export
state_salience_features <- function(keys, tab = NULL) {
  cols <- c("ss_level", "ss_rise", "ss_peak", "ss_share8", "ss_jump_pctile", "ss_level_pctile")
  out <- data.table::copy(data.table::as.data.table(keys))
  out[, `.ord` := .I]
  if (is.null(tab)) {
    f <- out_path("state-salience-features.csv")
    if (!file.exists(f)) {
      stop("AUSPOL_SALIENCE_STATE=1 but ", f, " is missing -- run scripts/build_state_salience.R", call. = FALSE)
    }
    tab <- data.table::fread(f, showProgress = FALSE)
  }
  ss_tab <- data.table::as.data.table(tab)
  e <- unique(ss_tab[, c("pair", "seat", "party", cols), with = FALSE], by = c("pair", "seat", "party"))
  e[, k := normalise_seat(seat)][, seat := NULL]
  out[, k := normalise_seat(seat)]
  out <- merge(out, e, by = c("pair", "k", "party"), all.x = TRUE, sort = FALSE)
  data.table::setorder(out, `.ord`)
  out[, c("k", ".ord") := NULL]
  out[]
}

#' Collapse the candidacy population to one row per (pair, seat, party)
#'
#' The model has one row per class in a seat, so the strongest candidate of the
#' class on each statistic is used (`NA` if none had one).
#' @param pop The `pop` table from [build_state_salience()].
#' @return A `data.table` with `pair`, `seat`, `party` and the `ss_*` columns.
#' @export
state_salience_class_table <- function(pop) {
  mx <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
  p <- data.table::as.data.table(pop)
  p[, list(ss_level = mx(level), ss_rise = mx(rise), ss_peak = mx(peak),
           ss_share8 = mx(share8), ss_jump_pctile = mx(jump_pctile),
           ss_level_pctile = mx(level_pctile)),
    by = list(pair = election, seat, party)]
}

#' Names of the state-salience feature columns
#' @return Character vector.
#' @export
state_salience_cols <- function() {
  c("ss_level", "ss_rise", "ss_peak", "ss_share8", "ss_jump_pctile", "ss_level_pctile")
}

#' Add the state-salience feature columns to a feature table, behind a switch
#'
#' With `AUSPOL_SALIENCE_STATE` unset or `"0"` (the default) `dt` is returned
#' untouched -- same object, no new columns -- so the switch-off feature table
#' is byte-identical to one built without this function. With `"1"` the six
#' `ss_*` columns are added (`NA` where there is no series), row count and order
#' asserted unchanged.
#'
#' @param dt Feature table with `pair`, `seat`, `party`.
#' @param tab Class-level table; read from `output/` when `NULL`.
#' @param on Whether the switch is on; defaults to `AUSPOL_SALIENCE_STATE == "1"`.
#' @return `dt` (with the columns added when on).
#' @export
add_state_salience <- function(dt, tab = NULL,
                               on = identical(Sys.getenv("AUSPOL_SALIENCE_STATE", "0"), "1")) {
  if (!isTRUE(on)) return(dt)
  n0 <- nrow(dt)
  ss <- state_salience_features(dt[, list(pair, seat, party)], tab)
  stopifnot(nrow(ss) == n0)
  for (cc in state_salience_cols()) data.table::set(dt, j = cc, value = ss[[cc]])
  cat(sprintf("SSF1 state salience features ON: %d rows; ss_level non-NA on %d, ss_rise on %d, ss_jump_pctile on %d\n",
              n0, sum(!is.na(dt$ss_level)), sum(!is.na(dt$ss_rise)), sum(!is.na(dt$ss_jump_pctile))))
  dt
}
