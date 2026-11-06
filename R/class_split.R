# Two candidates of one minor class counted separately (AUSPOL_CLASS_SPLIT).
# docs/plans/prereg-class-split-2026-11-06.md; walkthrough
# docs/reviews/two-candidates-one-class-2026-11-06.md.

.cls_cache <- new.env(parent = emptyenv())

#' Every same-class exclusion the class split's `f` is fitted from
#'
#' @param dir The elections directory.
#' @param classes Minor classes to keep.
#' @return A data.table `election, seat, round, from, to, votes`, rows whose
#'   `from` is one of `classes`.
#' @export
class_split_transfers <- function(dir = file.path("external", "elections"),
                                  classes = c("IND", "OTH", "OTH_RIGHT")) {
  cols <- c("election", "seat", "round", "from", "to", "votes")
  fs <- list.files(dir, "transfers[.]csv$", full.names = TRUE)
  x <- data.table::rbindlist(lapply(fs, function(f) {
    y <- data.table::fread(f)
    y[y$from %in% classes, cols, with = FALSE]
  }), fill = TRUE)
  data.table::setattr(x, "src", sprintf("%d transfers files", length(fs)))
  x
}

#' Fit the class split for one election
#'
#' For every seat of `target_election` where a minor class has two or more
#' candidates in the per-candidate predictions, the junior fraction
#' `r = second-largest prediction / sum of the class's predictions`. Its
#' spread is the root mean squared error of that fraction against the actual
#' one over EARLIER elections' seats, and `f` (the share of an excluded
#' same-class candidate's votes that reach the other) comes from earlier
#' elections' same-class transfers, shrunk by jurisdiction as [coalition_f()].
#' One class per seat: the one whose junior has the largest prediction.
#'
#' @param target_election Election label, e.g. `"sa2022"`.
#' @param oof Per-candidate predictions (`election, seat, cls, share,
#'   pred_xgb`); default `output/minor-candidate-oof-resid-v2.csv`.
#' @param transfers Same-class exclusions; default [class_split_transfers()].
#' @param classes Minor classes that can be split.
#' @return A list: `seats` (data.frame `seat, cls, r, sd, f, n_cand`), `sd`,
#'   `f` (named by class), `n_hist`, `n_target`, `missing` (TRUE when the
#'   election has no per-candidate predictions).
#' @export
class_split_fit <- function(target_election, oof = NULL, transfers = NULL,
                            classes = c("IND", "OTH", "OTH_RIGHT")) {
  tgt_el <- as.character(target_election)
  .yr <- function(e) as.integer(sub("^[a-z]+", "", e))
  .rg <- function(e) sub("[0-9]+$", "", e)
  tgt_year <- .yr(tgt_el)
  if (is.null(oof)) oof <- data.table::fread(out_path("minor-candidate-oof-resid-v2.csv"))
  o <- data.table::as.data.table(oof)
  o <- o[o$cls %in% classes & is.finite(o$pred_xgb)]
  o[, "p" := pmax(get("pred_xgb"), 0.01)]
  data.table::setorderv(o, c("election", "seat", "cls", "p"), c(1L, 1L, 1L, -1L))
  agg <- o[, list(n_cand = .N, sum_p = sum(get("p")), p2 = get("p")[2],
                  j_share = get("share")[2], all_share = sum(get("share"))),
           by = c("election", "seat", "cls")]
  agg <- agg[agg$n_cand >= 2L]
  agg[, "r" := pmin(get("p2") / get("sum_p"), 0.5)]
  agg[, "year" := .yr(get("election"))]
  empty <- list(seats = data.frame(seat = character(0), cls = character(0), r = numeric(0),
                                   sd = numeric(0), f = numeric(0), n_cand = integer(0)),
                sd = NA_real_, f = NA_real_, n_hist = 0L, n_target = 0L,
                missing = !tgt_el %in% o$election)

  hist <- agg[agg$year < tgt_year & is.finite(agg$j_share) & is.finite(agg$all_share) & agg$all_share > 0]
  empty$n_hist <- nrow(hist)
  if (nrow(hist) < 5L) return(empty)
  sdv <- sqrt(mean((hist$j_share / hist$all_share - hist$r)^2))

  tgt <- agg[agg$election == tgt_el]
  if (!nrow(tgt)) return(empty)
  data.table::setorderv(tgt, c("seat", "p2"), c(1L, -1L))
  tgt <- tgt[!duplicated(tgt$seat)]

  if (is.null(transfers)) transfers <- class_split_transfers(classes = classes)
  tx <- data.table::as.data.table(transfers)
  tx <- tx[.yr(tx$election) < tgt_year & tx$from %in% classes]
  ev <- tx[, list(tot = sum(get("votes")), to_lnp = sum(get("votes")[get("to") == get("from")])),
           by = c("election", "seat", "round", "from")]
  ev <- ev[ev$to_lnp > 0 & ev$tot > 0]
  mode <- Sys.getenv("AUSPOL_COALITION_SPLIT_F", "state")
  f_all <- if (nrow(ev)) coalition_f(ev, .rg(tgt_el), mode) else NA_real_
  f_by <- vapply(classes, function(k) {
    e <- ev[ev$from == k]
    # A class with no earlier same-class exclusion takes the all-class rate.
    if (nrow(e)) as.numeric(coalition_f(e, .rg(tgt_el), mode)) else as.numeric(f_all)
  }, 0)
  list(seats = data.frame(seat = tgt$seat, cls = tgt$cls, r = tgt$r, sd = rep(sdv, nrow(tgt)),
                          f = unname(f_by[tgt$cls]), n_cand = tgt$n_cand, stringsAsFactors = FALSE),
       sd = sdv, f = f_by, n_hist = nrow(hist), n_target = nrow(tgt), n_events = nrow(ev),
       missing = FALSE)
}

#' The class-split elements of the `coalition_split` argument
#'
#' Reads `AUSPOL_CLASS_SPLIT` (default `"0"`): anything but `"1"` returns
#' `NULL`. Prints the plumbing line `CS1` per election.
#'
#' @param target_election Election label.
#' @param seat_names The simulation's seats, in its order.
#' @return `NULL`, or a list `cls`, `cls_r`, `cls_sd`, `cls_f`, each named by
#'   seat (`NA` where no split).
#' @export
class_split_args <- function(target_election, seat_names) {
  if (!identical(Sys.getenv("AUSPOL_CLASS_SPLIT", "0"), "1")) return(NULL)
  src <- out_path("minor-candidate-oof-resid-v2.csv")
  tf <- list.files(file.path("external", "elections"), "transfers[.]csv$", full.names = TRUE)
  key <- paste(target_election, Sys.getenv("AUSPOL_COALITION_SPLIT_F", "state"),
               if (file.exists(src)) file.mtime(src) else "nofile",
               if (length(tf)) max(file.mtime(tf)) else "notx")
  fit <- .cls_cache[[key]]
  if (is.null(fit)) {
    if (!file.exists(src)) stop("AUSPOL_CLASS_SPLIT=1 needs ", src, " (scripts/fit_minor_candidates.R)")
    fit <- class_split_fit(target_election)
    assign(key, fit, envir = .cls_cache)
  }
  na <- stats::setNames(rep(NA_real_, length(seat_names)), seat_names)
  cls <- stats::setNames(rep(NA_character_, length(seat_names)), seat_names)
  r <- na; sdv <- na; f <- na
  s <- fit$seats[fit$seats$seat %in% seat_names & is.finite(fit$seats$f), ]
  cls[s$seat] <- s$cls; r[s$seat] <- s$r; sdv[s$seat] <- s$sd; f[s$seat] <- s$f
  miss <- setdiff(fit$seats$seat, seat_names)
  tab <- table(s$cls)
  cat(sprintf(paste0("CS1 class split %s: %d seat(s) [%s] of %d with 2+ candidates of one minor class%s%s;",
                     " sd=%.3f on %d earlier seat-classes; f %s; mean r=%.3f\n"),
              target_election, nrow(s), paste(names(tab), tab, sep = "=", collapse = " "), fit$n_target,
              if (isTRUE(fit$missing)) " (NO per-candidate predictions for this election: no class split)" else "",
              if (length(miss)) paste0(" (not in the simulation: ", paste(utils::head(miss, 5), collapse = ", "), ")") else "",
              fit$sd, fit$n_hist,
              if (all(is.na(fit$f))) "none" else paste(names(fit$f), sprintf("%.3f", fit$f), sep = "=", collapse = " "),
              if (nrow(s)) mean(s$r) else NA_real_))
  if (!nrow(s)) return(NULL)
  list(cls = cls, cls_r = r, cls_sd = sdv, cls_f = f)
}
