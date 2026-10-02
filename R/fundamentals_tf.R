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
  # The env var is in the key: elections_before() reads it, so a cached value
  # from a leave-one-out call must not answer a time-forward one.
  key <- paste0(region, year)
  ck <- paste0(key, ":", Sys.getenv("AUSPOL_TIME_FORWARD_FITS", "1"))
  if (!is.null(.fund_tf_cache[[ck]])) return(.fund_tf_cache[[ck]])
  if (is.null(.fund_tf_cache$data)) .fund_tf_cache$data <- build_fundamentals_data()
  d <- .fund_tf_cache$data
  # DISK CACHE across processes. Each harness is its own R process, so the
  # in-memory cache above starts cold in every one, and each refits this ridge
  # (leave-one-out) model for every earlier election: 32% of a harness pair's
  # time (profiled 2026-10-02, sa2026). Keyed on the data AND the fitting code,
  # so a change to either starts a fresh cache directory. Stored at %.17g (exact
  # round trip); written to a temp file then renamed, so parallel harnesses
  # cannot read a half-written value.
  cdir <- .fund_tf_disk_dir(d)
  cf <- if (!is.na(cdir)) file.path(cdir, paste0(gsub("[^A-Za-z0-9]", "_", ck), ".txt")) else NA_character_
  if (!is.na(cf) && file.exists(cf)) {
    v <- suppressWarnings(as.numeric(readLines(cf, warn = FALSE)[1]))
    if (length(v) == 1L) { .fund_tf_cache[[ck]] <- v; return(v) }
  }
  on.exit(if (!is.na(cf) && !is.null(.fund_tf_cache[[ck]])) {
    tmp <- paste0(cf, ".", Sys.getpid(), ".tmp")
    writeLines(sprintf("%.17g", .fund_tf_cache[[ck]]), tmp)
    if (!file.rename(tmp, cf)) unlink(tmp)
  }, add = TRUE)
  lab <- paste0(d$region, d$year)
  target_rows <- which(lab == key & d$party == "@TPP")
  if (length(target_rows) != 1L) {
    .fund_tf_cache[[ck]] <- NA_real_
    return(NA_real_)
  }
  earlier <- elections_before(lab, key)
  tr <- d[which(earlier), ]
  out <- NA_real_
  if (sum(tr$party == "@TPP") >= 10L) {
    m <- fit_fundamentals(tr, "@TPP")
    out <- predict_fundamentals(m, d[target_rows, ])
  }
  .fund_tf_cache[[ck]] <- out
  out
}

# The cache directory for one version of the inputs and the fitting code
# (AUSPOL_FUND_CACHE = "0" turns the disk cache off). Computed once per process.
.fund_tf_disk_dir <- function(d) {
  if (identical(Sys.getenv("AUSPOL_FUND_CACHE", "1"), "0")) return(NA_character_)
  if (!is.null(.fund_tf_cache$disk_dir)) return(.fund_tf_cache$disk_dir)
  h <- digest::digest(list(as.data.frame(d), deparse(fit_fundamentals), deparse(predict_fundamentals),
                           deparse(ridge_loo), FUNDAMENTALS_FEATURES, deparse(elections_before),
                           tryCatch(election_dates(), error = function(e) NULL)))
  dir <- out_path(file.path("cache", "fundamentals-tf", substr(h, 1, 16)))
  ok <- tryCatch({ dir.create(dir, recursive = TRUE, showWarnings = FALSE); dir.exists(dir) }, error = function(e) FALSE)
  .fund_tf_cache$disk_dir <- if (isTRUE(ok)) dir else NA_character_
  .fund_tf_cache$disk_dir
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
  key <- paste0("mix:", region, year, ":", Sys.getenv("AUSPOL_TIME_FORWARD_FITS", "1"))
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
