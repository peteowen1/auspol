# AUSPOL_GRN_TREE_SHRINK: pull the trees' Greens share back toward base_pred as
# the Greens base grows. Pete, 2026-10-24 (Melbourne, Griffith, South Brisbane).
# docs/reviews/greens-overcall-investigation-2026-10-24.md: at a Greens base of
# 30+ the trees add about +3.2 points and only about a third of that is borne
# out. docs/plans/prereg-grn-tree-shrink-2026-10-24.md.
#
# Form, Greens cells only: x' = base + w (xgb - base), w = 1 / (1 + lambda * base),
# so lambda = 0 is exactly today. lambda is fitted time-forward by least squares
# on the as-at tree rows (output/forecasts.csv) of elections strictly before the
# target, then shrunk toward 0 by G / (G + k), G the number of those elections
# with a Greens row (AUSPOL_GRN_TREE_SHRINK_K, default 3). AFTER the trees, so
# it is a post-xgb switch: the as-at trees never train on it.

#' The validated `AUSPOL_GRN_TREE_SHRINK` switch
#'
#' `"0"` off (shipped), `"1"` lambda fitted time-forward. A positive number is a
#' FIXED `k` in `w = 1 / (1 + base / k)` (screening only; not time-forward).
#' Anything else is an error.
#'
#' @return The validated string.
#' @export
grn_tree_shrink_mode <- function() {
  m <- Sys.getenv("AUSPOL_GRN_TREE_SHRINK", "0")
  if (!nzchar(m)) m <- "0"
  num <- suppressWarnings(as.numeric(m))
  if (!(m %in% c("0", "1") || (is.finite(num) && num > 1)))
    stop("AUSPOL_GRN_TREE_SHRINK must be \"0\", \"1\" or a fixed k > 1; got \"", m, "\"", call. = FALSE)
  m
}

#' Fit the Greens tree-shrink strength, time-forward
#'
#' @param target Election label; only elections strictly before it are read.
#' @param forecasts Optional pre-read `output/forecasts.csv` (`election, party,
#'   base_pred, xgb_pred, actual_share`).
#' @return list(lambda (shrunk), lambda_raw, G elections, n rows, k).
#' @export
grn_tree_shrink_fit <- function(target, forecasts = NULL) {
  k <- as.numeric(Sys.getenv("AUSPOL_GRN_TREE_SHRINK_K", "3"))
  if (!is.finite(k) || k < 0) stop("AUSPOL_GRN_TREE_SHRINK_K must be a non-negative number", call. = FALSE)
  if (is.null(forecasts)) {
    f <- out_path("forecasts.csv")
    if (!file.exists(f)) stop("grn_tree_shrink_fit() needs ", f, call. = FALSE)
    forecasts <- data.table::fread(f, select = c("election", "party", "base_pred", "xgb_pred", "actual_share"),
                                   showProgress = FALSE)
  }
  FT <- data.table::as.data.table(forecasts)
  els <- unique(FT$election)
  keep_el <- els[elections_before(els, target)]
  is_grn <- FT$party == "GRN" & FT$election %in% keep_el &
    is.finite(FT$base_pred) & is.finite(FT$xgb_pred) & is.finite(FT$actual_share)
  d <- FT[is_grn, ]
  G <- length(unique(d$election))
  if (!nrow(d)) return(list(lambda = 0, lambda_raw = NA_real_, G = 0L, n = 0L, k = k))
  b <- d$base_pred; x <- d$xgb_pred; a <- d$actual_share
  sse <- function(l) sum((b + (x - b) / (1 + l * pmax(b, 0)) - a)^2)
  # lambda >= 0 only: the switch pulls the tree back toward base, never pushes it further
  lam <- stats::optimize(sse, c(0, 1))$minimum
  if (sse(0) <= sse(lam)) lam <- 0
  list(lambda = lam * G / (G + k), lambda_raw = lam, G = G, n = nrow(d), k = k)
}

#' Apply the Greens tree shrink to one share matrix
#'
#' @param out Seats x classes matrix AFTER the tree override, before renormalising.
#' @param base The same matrix before the override (the base the trees corrected).
#' @param target Election label.
#' @param code Log prefix.
#' @return `out` with the GRN column pulled toward `base`; unchanged when off or
#'   when there is no GRN column.
#' @export
grn_tree_shrink_apply <- function(out, base, target, code = "GT1") {
  m <- grn_tree_shrink_mode()
  if (m == "0" || !"GRN" %in% colnames(out)) return(out)
  b <- base[, "GRN"]; x <- out[, "GRN"]
  if (m == "1") {
    fit <- grn_tree_shrink_fit(target)
    w <- 1 / (1 + fit$lambda * pmax(b, 0))
    cat(sprintf("%s  Greens tree shrink for %s: lambda %.4f (raw %.4f, %d earlier elections, %d rows, k %g)\n",
                code, target, fit$lambda, fit$lambda_raw, fit$G, fit$n, fit$k))
  } else {
    w <- 1 / (1 + pmax(b, 0) / as.numeric(m))
    cat(sprintf("%s  Greens tree shrink for %s: FIXED k %s (screen only, not time-forward)\n", code, target, m))
  }
  new <- b + w * (x - b)
  moved <- which(abs(new - x) > 1e-9)
  if (length(moved)) {
    o <- utils::head(moved[order(-abs(new[moved] - x[moved]))], 5L)
    for (j in o) cat(sprintf("%s    %-22s GRN base %5.1f tree %5.1f -> %5.1f\n",
                             code, rownames(out)[j], b[j], x[j], new[j]))
  }
  out[, "GRN"] <- pmax(0, new)
  out
}
