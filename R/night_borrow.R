# ELECTION-NIGHT SWING TO UNCOUNTED SEATS (AUSPOL_NIGHT_BORROW; Pete 26 Nov 2026: "if a seat comes in way over
# performing expectation for labor say other seats and similar seats reflect that").
#
# Without this, night_booth_update() moves only seats whose own booths are in, and night_shrink_draws() narrows the
# statewide draws around the AFTERNOON centre: a seat with nothing counted keeps its afternoon forecast however clearly
# the counted seats show a swing. This shifts every seat's PRIOR by the swing the OTHER counted seats show, before its
# own booth update, so its own count still takes over as it comes in.
#
# Each counted seat's swing is its posterior minus its prior (per class, points), from a first booth update. A seat's
# borrowed swing, leave-own-out:
#   statewide  = sum(w_i d_i) / sum(w_i) * n / (n + k)          n = sum(w_i), w_i = counted_i / (counted_i + c0)
#   cluster    = mean residual (d_i - statewide) in the seat's region / type cluster, times m rho / (m rho + 1 - rho)
#                (m = sum(w_i) in the cluster; rho the afternoon forecast's cluster share of seat variance), i.e. the
#                Gaussian conditional-mean weight for a shared cluster term
# Only cells with a positive prior move (a class not standing stays at 0); rows are renormalised to 100.

#' Night swing borrowed from counted seats, per seat and class (points)
#'
#' @param shares Seat x class prior first preferences (percent), the afternoon forecast.
#' @param post Seat x class posterior from a first [night_booth_update()] on `shares` (same shape).
#' @param counted Named per-seat share of the vote counted (0-1).
#' @param cluster `NULL`, an integer vector of cluster ids per seat, or a matrix with columns `region` / `type`
#'   (the `seat_cluster` of [seat_cluster_setup()]).
#' @param rho `NULL`, a named per-class vector, or a list `region` / `type` of them (the `cluster_rho`).
#' @param k Statewide shrinkage: `n / (n + k)` with `n` the effective number of counted seats.
#' @param c0 Counted share at which a seat counts as half a seat of evidence.
#' @return Seat x class matrix of borrowed swing (points), attribute `detail` (n_eff, statewide swing per class).
#' @export
night_borrow_swing <- function(shares, post, counted, cluster = NULL, rho = NULL, k = 2, c0 = 0.05) {
  stopifnot(is.matrix(shares), identical(dim(shares), dim(post)), is.finite(k), k >= 0, is.finite(c0), c0 > 0)
  seats <- rownames(shares); cls <- colnames(shares)
  cs <- unname(counted[seats]); cs[is.na(cs)] <- 0
  w <- cs / (cs + c0)
  d <- post - shares; d[!is.finite(d)] <- 0
  out <- matrix(0, nrow(shares), ncol(shares), dimnames = dimnames(shares))
  if (sum(w > 0) < 2L) { attr(out, "detail") <- list(n_eff = sum(w), statewide = setNames(rep(0, length(cls)), cls)); return(out) }
  W <- sum(w); WD <- colSums(w * d)
  # leave-own-out statewide swing per seat
  n_loo <- W - w
  sw <- (matrix(WD, nrow(d), ncol(d), byrow = TRUE) - w * d) / pmax(n_loo, 1e-12)
  sw <- sw * (n_loo / (n_loo + k))
  sw[n_loo <= 0, ] <- 0
  out <- sw
  if (!is.null(cluster)) {
    cm <- if (is.matrix(cluster)) cluster else cbind(cluster = as.integer(cluster))
    rl <- if (is.list(rho)) rho else list(rho)
    if (length(rl) == 1L && ncol(cm) >= 1L && is.null(names(rl))) names(rl) <- colnames(cm)[1]
    sw_all <- matrix(WD / W, nrow(d), ncol(d), byrow = TRUE)
    resid <- d - sw_all
    for (j in seq_len(ncol(cm))) {
      id <- cm[, j]; r <- rl[[colnames(cm)[j]]]
      if (is.null(r)) next
      rv <- setNames(rep(0, length(cls)), cls); rv[intersect(names(r), cls)] <- r[intersect(names(r), cls)]
      rv <- pmin(pmax(rv, 0), 0.95)
      for (g in unique(id[!is.na(id)])) {
        ing <- which(id == g)
        wg <- w[ing]; if (sum(wg > 0) == 0) next
        RG <- colSums(wg * resid[ing, , drop = FALSE]); MG <- sum(wg)
        for (s in ing) {
          m <- MG - w[s]; if (m <= 0) next
          mr <- (RG - w[s] * resid[s, ]) / m
          out[s, ] <- out[s, ] + mr * (m * rv / (m * rv + 1 - rv))
        }
      }
    }
  }
  out[shares <= 0] <- 0
  attr(out, "detail") <- list(n_eff = W, statewide = WD / W * (W / (W + k)))
  out
}

#' Apply a borrowed swing to the prior: shift positive cells, floor at 0.01, renormalise rows to 100
#' @param shares Seat x class prior (percent).
#' @param borrow Matrix from [night_borrow_swing()].
#' @export
night_apply_borrow <- function(shares, borrow) {
  s2 <- shares + borrow
  pos <- shares > 0
  s2[pos] <- pmax(s2[pos], 0.01); s2[!pos] <- 0
  s2 / rowSums(s2) * 100
}

#' AUSPOL_NIGHT_BORROW: "0"/unset off; "1" on at the defaults; or "k,c0"
#' @param v The setting (default: the AUSPOL_NIGHT_BORROW environment variable).
#' @return `NULL` when off, else `list(k, c0)`.
#' @export
night_borrow_args <- function(v = Sys.getenv("AUSPOL_NIGHT_BORROW", "0")) {
  if (!nzchar(v) || identical(v, "0")) return(NULL)
  if (identical(v, "1")) return(list(k = 2, c0 = 0.05))
  p <- suppressWarnings(as.numeric(strsplit(v, ",", fixed = TRUE)[[1]]))
  if (length(p) != 2L || any(!is.finite(p)) || p[1] < 0 || p[2] <= 0)
    stop("AUSPOL_NIGHT_BORROW must be 0, 1 or \"k,c0\" (k >= 0, c0 > 0), not \"", v, "\"", call. = FALSE)
  list(k = p[1], c0 = p[2])
}
