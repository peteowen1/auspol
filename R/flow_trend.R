#' Extrapolate each flow cell along its own trend over prior elections
#'
#' `build_flow_matrix()` averages every election it is given, so a preference
#' rate that is *moving* is estimated at the middle of its own history and then
#' applied to an election at the end of it. That is a bias, not noise, and
#' widening the draw around it does not help -- measured: per-source flow
#' uncertainty at k = 0.25 and 0.50 scored 0.3043 and 0.3051 against a 0.3042
#' baseline, monotonically worse, because symmetric noise around a biased centre
#' only blurs the answer.
#'
#' The bias is real and it is directional. Within the EXACT survivor set
#' `ALP+GRN+LNP`, One Nation's share to the Coalition ran 35.5, 45.4, 52.3,
#' 49.7, 61.1 across federal elections -- and `OTH_RIGHT` to the Coalition ran
#' the other way, 49.2, 49.2, 42.5, 46.3, 43.3, 35.8, 20.4. Both are trends, in
#' opposite directions, which is why this is written as a general mechanism
#' rather than an One Nation adjustment.
#'
#' Fitted on pre-2025 elections only, a weighted linear trend predicts 72.2 for
#' `ONP|ALP+LNP` in 2025 against an actual 71.4, where carrying the last value
#' forward gives 63.8.
#'
#' @section Why the cells and not the margin:
#'   The pooled marginal for a class is contaminated by which survivor sets
#'   happened to occur. For One Nation, fed2022's rates re-weighted to fed2025's
#'   mix move 47.6 -> 51.1, so about a third of the apparent 14-point swing is
#'   composition and two thirds is real within-cell movement. Trending the
#'   margin would fit the composition; trending the cells does not.
#'
#' @param fm A flow matrix from [build_flow_matrix()], built on `tx`.
#' @param tx Transfer rows for PRIOR elections only. Every row must belong to an
#'   election held before `target_year`; this is asserted, not assumed.
#' @param target_year Integer year being forecast.
#' @param weight Blend weight in `[0, 1]` on the trend-extrapolated rate against
#'   the flat estimate already in `fm`. 0 returns `fm` unchanged.
#' @param min_el Minimum distinct elections a cell needs before a trend is fitted
#'   for it. Below this the cell keeps its flat value.
#' @param max_shift Cap, in percentage points, on how far one destination may be
#'   moved. A trend fitted on three points can extrapolate absurdly; this bounds
#'   the damage when it does.
#' @param classes Optional character vector of source classes to adjust. `NULL`
#'   adjusts every class. Applying the trend to every class was measured FIRST
#'   and is monotonically worse on fed2025 (0.3042 flat, 0.3040 at w = 0.25,
#'   0.3045 at 0.50, 0.3065 at 1.00), so a restricted arm is only meaningful for
#'   a class named in advance -- `docs/reviews/fed2025-closing-the-aef-gap`
#'   already identified One Nation as the entire residual before this was
#'   written, which is what makes `classes = "ONP"` a test of that claim rather
#'   than a threshold chosen after seeing the answer.
#' @return `fm` with `conditional`, `superset`, `pairwise` and `pooled` cells
#'   adjusted and renormalised to sum to 100.
#' @export
trend_flow_matrix <- function(fm, tx, target_year, weight = 1,
                              min_el = 3L, max_shift = 15, classes = NULL) {
  stopifnot(is.list(fm), is.data.frame(tx), length(target_year) == 1L)
  if (!is.finite(weight) || weight < 0 || weight > 1)
    stop("weight must be in [0, 1]; got ", weight)
  if (weight == 0) return(fm)
  tx <- data.table::as.data.table(tx)
  yr <- suppressWarnings(as.integer(sub("^[a-z]+", "", tx$election)))
  # LEAKAGE GUARD. Asserted rather than documented: three leaks have been found
  # in this repo, one introduced while fixing another.
  if (anyNA(yr) || any(yr >= target_year))
    stop("trend_flow_matrix(): tx contains elections at or after ", target_year)
  if (data.table::uniqueN(tx$election) < min_el) return(fm)

  # Per-election rate for every (from, survivor set, to). The survivor set is
  # the set of destinations present in that exclusion round, which is what a
  # conditional cell is keyed on.
  ev <- tx[, list(votes = sum(votes)), by = c("election", "seat", "round", "from", "to")]
  sv <- ev[, list(surv = paste(sort(unique(to)), collapse = "+")),
           by = c("election", "seat", "round", "from")]
  ev <- merge(ev, sv, by = c("election", "seat", "round", "from"))
  cellwise <- ev[, list(v = sum(votes)), by = c("election", "from", "surv", "to")]
  cellwise[, tot := sum(v), by = c("election", "from", "surv")]
  cellwise[, pct := 100 * v / tot]
  cellwise[, year := as.integer(sub("^[a-z]+", "", election))]
  # And the same collapsed over survivor sets, as the fallback for a thin cell.
  margin <- ev[, list(v = sum(votes)), by = c("election", "from", "to")]
  margin[, tot := sum(v), by = c("election", "from")]
  margin[, pct := 100 * v / tot]
  margin[, year := as.integer(sub("^[a-z]+", "", election))]

  # Weighted least-squares slope through (year, pct), weighted by vote mass, and
  # the value it implies at target_year. Returns NA when it cannot be fitted --
  # never a filled-in number, which is how a slope for zero observations got
  # shipped once already.
  predict_at <- function(d) {
    d <- as.data.frame(d)
    d <- d[is.finite(d$pct) & is.finite(d$year) & d$tot > 0, , drop = FALSE]
    if (length(unique(d$year)) < min_el) return(NA_real_)
    f <- stats::lm(pct ~ year, data = d, weights = d$tot)
    if (!all(is.finite(stats::coef(f)))) return(NA_real_)
    unname(stats::predict(f, data.frame(year = target_year)))
  }

  # PLAIN DATA FRAMES FROM HERE, and never a bare column-name symbol inside `[`.
  # The first version of adjust() took arguments called `from` and `surv` and
  # wrote cellwise[cellwise$from == from & cellwise$surv == surv, ]. data.table
  # scopes the subsetted table's columns into the WHOLE `i` expression, so the
  # bare `from` on the right resolved to cellwise's own column and the test was
  # column == column -- always TRUE. Every cell silently received the trend of
  # the entire pooled dataset, which sent One Nation's share to the Coalition
  # DOWN 50.1 -> 37.1 when its own cell was rising. Seventh instance of this
  # trap in this repo; the `$` on one side does not save you.
  CW <- as.data.frame(cellwise); MG <- as.data.frame(margin)
  adjust <- function(vec, src_class, surv_key) {
    if (is.null(vec) || !length(vec)) return(vec)
    dest <- names(vec)
    if (is.null(dest)) return(vec)
    out <- vec
    mg_src <- MG[MG$from == src_class, , drop = FALSE]
    cw_src <- if (is.null(surv_key)) NULL else
      CW[CW$from == src_class & CW$surv == surv_key, , drop = FALSE]
    for (j in seq_along(dest)) {
      p <- if (is.null(cw_src)) predict_at(mg_src[mg_src$to == dest[j], , drop = FALSE])
           else predict_at(cw_src[cw_src$to == dest[j], , drop = FALSE])
      if (is.na(p) && !is.null(cw_src))        # thin cell: fall back to the margin
        p <- predict_at(mg_src[mg_src$to == dest[j], , drop = FALSE])
      if (is.na(p)) next
      shift <- weight * (p - vec[[j]])
      out[[j]] <- max(0, vec[[j]] + max(-max_shift, min(max_shift, shift)))
    }
    s <- sum(out)
    if (s > 0) out * 100 / s else vec
  }

  wanted <- function(cl) is.null(classes) || cl %in% classes
  for (nm in names(fm$conditional)) {
    src <- sub("[|].*$", "", nm); sk <- sub("^[^|]*[|]", "", nm)
    if (wanted(src)) fm$conditional[[nm]] <- adjust(fm$conditional[[nm]], src, sk)
  }
  for (nm in names(fm$superset)) {
    src <- sub("[|].*$", "", nm); sk <- sub("^[^|]*[|]", "", nm)
    if (wanted(src)) fm$superset[[nm]] <- adjust(fm$superset[[nm]], src, sk)
  }
  # pairwise and pooled are marginal objects: trend them on the margin.
  for (nm in names(fm$pairwise)) if (wanted(nm)) fm$pairwise[[nm]] <- adjust(fm$pairwise[[nm]], nm, NULL)
  for (nm in names(fm$pooled))   if (wanted(nm)) fm$pooled[[nm]]   <- adjust(fm$pooled[[nm]], nm, NULL)
  fm
}
