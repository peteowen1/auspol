# Choosing a prior by held-out error -------------------------------------
#
# Most hyperparameters here are already chosen this way (both sigmas, the
# per-cycle volatilities, the mix weight, the ridge penalty). The trend priors
# were the exception, set by hand. This is the shared machinery for moving one
# of them from "asserted" to "estimated", so each new constant costs a grid and
# a pre-registration rather than another sixty lines of copied script.
#
# The rule is deliberately conservative in one direction: the incumbent value
# wins ties and near-ties. Swapping a published constant every time a rerun
# nudges one grid point ahead of another is fitting the backtest rather than
# using it, and these are ~200 election-horizon pairs, which is not a lot.

#' Choose one prior by leave-one-election-out error
#'
#' Refits the entire projection backtest once per grid value, so this is slow
#' by construction: about a minute per value.
#'
#' The fundamentals are fitted ONCE and shared across arms. They use no polling
#' data and cannot depend on a poll-model prior, so refitting them per arm
#' would only let something stochastic vary between arms and be misattributed
#' to the prior under test — the confound that made six unrelated experiment
#' arms agree to within 0.2% in a sister project.
#'
#' @param param Name of the [fit_trend()] argument to vary.
#' @param grid Values to try. Pre-register this, do not tune it.
#' @param incumbent The shipped value; wins ties and near-ties.
#' @param material MAE a challenger must beat the incumbent by to displace it.
#' @param horizons Passed to [build_projection_data()].
#' @return List with `table` (grid and MAE), `chosen`, `gain`, `verdict`.
#' @export
tune_prior <- function(param, grid, incumbent, material = 0.02,
                       horizons = c(30, 90, 180, 365, 730)) {
  stopifnot(is.character(param), length(param) == 1L,
            is.numeric(grid), length(grid) >= 2L,
            is.numeric(incumbent), length(incumbent) == 1L,
            is.numeric(material), material >= 0)

  # `param` MUST name a fit_trend() argument. args[[param]] is handed to
  # build_projection_data(), so a name that happens to belong to IT instead --
  # min_polls, verbose, horizons -- would quietly tune a different quantity,
  # run to completion, and report a plausible verdict about the wrong
  # experiment. A typo does the same thing more obviously but just as quietly.
  if (!param %in% names(formals(fit_trend))) {
    stop("'", param, "' is not an argument of fit_trend(). tune_prior() varies ",
         "a MODEL prior; a name belonging to build_projection_data() would ",
         "silently tune something else. Available: ",
         paste(setdiff(names(formals(fit_trend)), c("polls", "party", "...")),
               collapse = ", "), call. = FALSE)
  }
  # Exact == on doubles: 0.3 %in% c(0.3, ...) is safe for identical literals
  # but not for a computed incumbent, and the failure is an assertion with no
  # hint of why. Match on tolerance and report the values when it fails.
  hit <- which(abs(grid - incumbent) < 1e-9)
  if (!length(hit)) {
    stop("incumbent ", format(incumbent), " is not in the grid (",
         paste(format(grid), collapse = ", "),
         "). It must be, so the comparison has a baseline.", call. = FALSE)
  }
  incumbent <- grid[hit[1]]   # use the grid's own value from here on

  m_tpp <- fit_fundamentals(build_fundamentals_data(), "@TPP")
  fund_loo <- data.table::data.table(
    year = m_tpp$data$year, region = m_tpp$data$region,
    fund_tpp = m_tpp$data$actual - m_tpp$loo_errors)

  rows <- lapply(grid, function(v) {
    t0 <- Sys.time()
    args <- list(horizons = horizons, verbose = FALSE)
    args[[param]] <- v
    dat <- do.call(build_projection_data, args)
    dat <- merge(dat, fund_loo, by = c("year", "region"), all.x = TRUE)

    # projection_loo() returns one ROW PER held-out prediction, not a summary.
    # Reading a `$mae` off it gives NULL silently, data.table drops the column,
    # and rbindlist(fill = TRUE) accepts the result — a whole grid can run to
    # completion and produce a table with no results in it. Assert the shape.
    loo <- projection_loo(dat, debias = FALSE)
    stopifnot(is.data.frame(loo), nrow(loo) > 50, "err" %in% names(loo))
    mae <- mean(abs(loo$err))
    stopifnot(is.finite(mae))
    message(sprintf("  %s = %-6s held-out MAE %.4f  (n = %d, %.0f s)",
                    param, format(v), mae, nrow(loo),
                    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
    data.table::data.table(value = v, mae = mae, n = nrow(loo))
  })
  tab <- data.table::rbindlist(rows)

  # An arm that dropped out would leave a shorter table and a ranking over
  # fewer values than were registered.
  stopifnot(nrow(tab) == length(grid), all(is.finite(tab$mae)))
  data.table::setorder(tab, mae)

  inc_mae <- tab$mae[which(abs(tab$value - incumbent) < 1e-9)][1]
  stopifnot(length(inc_mae) == 1L, is.finite(inc_mae))
  gain <- inc_mae - tab$mae[1]
  qual <- tab[inc_mae - tab$mae > material]

  if (!nrow(qual)) {
    chosen <- incumbent
    verdict <- sprintf("KEEP %s (best gain %.4f does not clear the %.2f bar)",
                       format(incumbent), gain, material)
  } else {
    # Smallest qualifying value: a tighter prior concedes less to the thing it
    # governs, so it is the conservative choice among equals.
    chosen <- min(qual$value)
    verdict <- sprintf("ADOPT %s (beats incumbent by %.4f; smallest of %d qualifying)",
                       format(chosen),
                       inc_mae - tab$mae[which(abs(tab$value - chosen) < 1e-9)][1],
                       nrow(qual))
  }
  list(table = tab, chosen = chosen, incumbent = incumbent,
       gain = gain, verdict = verdict, param = param)
}

#' Report a tuning result as a numbered check
#'
#' Prints the grid, the verdict, and whether the shipped default agrees with
#' what this run chose — so a divergence is visible in the run summary rather
#' than discovered months later.
#'
#' @param res From [tune_prior()].
#' @param code Check code to print under.
#' @export
report_tuning <- function(res, code = "G4") {
  cat(sprintf("\n=== %s by held-out error ===\n", res$param))
  print(res$table[, .(value, mae = round(mae, 4), n)])
  cat(sprintf("\n%s  %s: %s\n", code, res$param, res$verdict))
  current <- formals(fit_trend)[[res$param]]
  # tune_prior() already refuses a param that is not a fit_trend formal, so
  # this cannot be NULL by that route -- but a formal whose default is an
  # unevaluated call (scale = c("logit","points")) would make as.numeric()
  # hard-error, and a NULL would print "shipped default NULL ... DISAGREE",
  # which reads like a finding rather than a broken comparison.
  current_num <- suppressWarnings(tryCatch(as.numeric(current),
                                           error = function(e) NA_real_))
  if (length(current_num) != 1L || !is.finite(current_num)) {
    stop("fit_trend()'s default for '", res$param, "' is not a single number, ",
         "so it cannot be compared with the tuned value.", call. = FALSE)
  }
  agree <- isTRUE(all.equal(current_num, as.numeric(res$chosen)))
  cat(sprintf("%s  shipped default %s; this run chose %s  %s\n",
              code, format(current), format(res$chosen),
              if (agree) "AGREE" else
                "DISAGREE -- update fit_trend() or record why not"))
  invisible(agree)
}
