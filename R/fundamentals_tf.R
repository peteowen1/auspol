.fund_tf_cache <- new.env(parent = emptyenv())

#' Time-forward fundamentals prediction for one election
#'
#' The statewide projection blends the poll trend with a fundamentals model.
#' Harnesses used a LEAVE-ONE-OUT fundamentals prediction, which for NSW 2023
#' was fitted partly on the elections after it (and its ridge penalty chosen
#' on all of them): the fifth instance of the leak class fixed on 2026-09-28/29.
#' This fits [fit_fundamentals()] on the elections dated before the target only
#' ([elections_before()]) and predicts the target's two-party vote.
#' docs/plans/prereg-statewide-time-forward-2026-09-29.md.
#'
#' @param region,year The target, e.g. `"nsw"`, `2023`.
#' @return Numeric, or `NA` when fewer than 10 earlier elections exist.
#' @export
fundamentals_tf <- function(region, year) {
  key <- paste0(region, year)
  if (!is.null(.fund_tf_cache[[key]])) return(.fund_tf_cache[[key]])
  if (is.null(.fund_tf_cache$data)) .fund_tf_cache$data <- build_fundamentals_data()
  d <- .fund_tf_cache$data
  lab <- paste0(d$region, d$year)
  target_rows <- which(lab == key & d$party == "@TPP")
  if (length(target_rows) != 1L) {
    .fund_tf_cache[[key]] <- NA_real_
    return(NA_real_)
  }
  earlier <- elections_before(lab, key)
  tr <- d[which(earlier), ]
  out <- NA_real_
  if (sum(tr$party == "@TPP") >= 10L) {
    m <- fit_fundamentals(tr, "@TPP")
    out <- predict_fundamentals(m, d[target_rows, ])
  }
  .fund_tf_cache[[key]] <- out
  out
}

#' Time-forward fundamentals table in the shape harnesses expect
#'
#' @param keys Optional `region` + `year` labels to fill (default: every
#'   election with a two-party row).
#' @return data.table `year`, `region`, `fund`.
#' @export
fundamentals_tf_table <- function(keys = NULL) {
  d <- build_fundamentals_data()
  d <- d[d$party == "@TPP", ]
  if (!is.null(keys)) d <- d[paste0(d$region, d$year) %in% keys, ]
  data.table::data.table(year = d$year, region = d$region,
                         fund = mapply(fundamentals_tf, d$region, d$year))
}

#' Time-forward trend/fundamentals mix for one target
#'
#' Refits [fit_projection_mix()] on `output/projection-data.csv` rows of
#' elections dated before the target, with each earlier election's
#' fundamentals replaced by its own time-forward value. The shipped
#' `projection-mix.csv` was fitted on every election, later ones included.
#'
#' @param region,year The target.
#' @return A mix table as [fit_projection_mix()] returns.
#' @export
projection_mix_tf <- function(region, year) {
  key <- paste0("mix:", region, year)
  if (!is.null(.fund_tf_cache[[key]])) return(.fund_tf_cache[[key]])
  f <- out_path("projection-data.csv")
  if (!file.exists(f)) stop("projection_mix_tf needs output/projection-data.csv (scripts/fit_projection.R)")
  p <- data.table::fread(f, showProgress = FALSE)
  # TENTH instance of the data.table NSE trap: `region` and `year` are columns
  # of `p`, so `paste0(region, year)` inside `p[...]` read the columns, not the
  # arguments, and every target got the wrong training set. Mask built outside.
  target_lab <- paste0(region, year)
  keep <- elections_before(paste0(p$region, p$year), target_lab)
  p <- p[which(keep), ]
  el <- unique(p[, list(region, year)])
  el$fund_tf <- mapply(fundamentals_tf, el$region, el$year)
  p <- merge(p, el, by = c("region", "year"))
  p$fund_tpp <- p$fund_tf
  mix <- fit_projection_mix(p)
  if (!nrow(mix) || !1L %in% mix$horizon) {
    # AMENDMENT (plans/prereg-statewide-time-forward-2026-09-29.md): too few
    # earlier elections carry time-forward fundamentals to fit a mix (wa2001).
    # With no earlier evidence for mixing, use the poll trend alone (w = 1),
    # its spread and bias measured on the earlier elections' trend errors,
    # which need no fundamentals.
    tr <- p[is.finite(p$trend_tpp) & is.finite(p$actual_tpp), ]
    mix <- tr[, list(n = .N, w = 1, mae_mix = mean(abs(trend_tpp - actual_tpp)),
                     mae_mix_loo = mean(abs(trend_tpp - actual_tpp)),
                     mae_trend = mean(abs(trend_tpp - actual_tpp)), mae_fund = NA_real_,
                     bias = mean(trend_tpp - actual_tpp), sd_err = stats::sd(trend_tpp - actual_tpp),
                     sd_err_loo = stats::sd(trend_tpp - actual_tpp)), by = horizon]
    mix <- mix[mix$n >= 3L, ]
    if (!1L %in% mix$horizon)
      stop("projection_mix_tf: too few earlier elections even for a trend-only projection for ", region, year)
    cat(sprintf("FTF0 %s%d: too few earlier elections with fundamentals to fit a mix; trend only (w = 1) from %d earlier elections
",
                region, year, mix$n[mix$horizon == 1]))
  }
  .fund_tf_cache[[key]] <- mix
  mix
}
