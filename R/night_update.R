# ELECTION-NIGHT UPDATE (AUSPOL_NIGHT_REPLAY_FRAC; issue #153, map #148).
#
# The afternoon forecast is the prior. As booths report, each seat's projected final
# first preferences (R/booth_projection.R: booth swings against the previous election,
# applied to the uncounted booths) are combined with the prior cell by cell, precision-
# weighted. The posterior means replace the seat's primaries and the posterior sds replace
# its per-cell spread, so the SAME preference-flow count, simulator and chamber
# aggregation as the published forecast turn them into win probabilities. The statewide
# draws (the cross-seat correlated part) shrink by the share of the night's uncertainty
# already resolved, because the count reveals the statewide swing as well as each seat's.
#
# Off unless AUSPOL_NIGHT_REPLAY_FRAC is set; with it unset nothing here is called.

#' Fraction of the night's vote counted, for a replay (AUSPOL_NIGHT_REPLAY_FRAC)
#' @return `NA` when unset, else a number in \[0, 1\].
#' @export
night_replay_frac <- function() {
  v <- Sys.getenv("AUSPOL_NIGHT_REPLAY_FRAC", "")
  if (!nzchar(v)) return(NA_real_)
  x <- suppressWarnings(as.numeric(v))
  if (!is.finite(x) || x < 0 || x > 1)
    stop("AUSPOL_NIGHT_REPLAY_FRAC must be a number from 0 to 1, not \"", v, "\"", call. = FALSE)
  x
}

#' Per-cell prior sd the simulator would use: level-shaped, overridden where given
#'
#' Mirrors `simulate_seat_contests()`: `a + b * level_mult * sqrt(p(1-p))` (p the share as a
#' fraction), replaced wherever `sd_override` is not `NA`.
#' @param shares Seat x class matrix of first-preference shares (percent).
#' @param level_sd `c(a, b)`.
#' @param level_mult Named per-class multiplier (or `NULL` for 1).
#' @param sd_override Matrix shaped like `shares`, or `NULL`.
#' @export
night_prior_sd <- function(shares, level_sd, level_mult = NULL, sd_override = NULL) {
  if (is.null(level_sd)) stop("night update needs level_sd: there is no per-cell prior spread without it", call. = FALSE)
  cls <- colnames(shares); lm <- rep(1, length(cls))
  if (!is.null(level_mult)) { hit <- match(names(level_mult), cls); lm[hit[!is.na(hit)]] <- as.numeric(level_mult)[!is.na(hit)] }
  p <- pmin(pmax(unname(as.matrix(shares)), 0), 100) / 100
  sd <- level_sd[1L] + level_sd[2L] * matrix(lm, nrow(p), length(cls), byrow = TRUE) * sqrt(p * (1 - p))
  if (!is.null(sd_override)) { so <- as.matrix(sd_override); ok <- !is.na(so); sd[ok] <- so[ok] }
  dimnames(sd) <- dimnames(shares)
  sd
}

# Simulated report order on the night (no order is recorded in the final booth files):
# small ordinary booths first, early-vote centres after the ordinary booths, postals last.
# The same order as dress rehearsals 1 and 2 (docs/plans/election-night-booth-model.md).
.night_order <- function(Lc, seed) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()))
  set.seed(seed)
  ord <- Lc[Lc$booth_type == "ordinary", list(size = sum(v)), by = c("district", "unit")]
  ord[, key := log(size + 1) + stats::rnorm(.N, 0, 0.5)]
  ord <- ord[order(district, key)]
  ord[, pos := seq_len(.N) / .N, by = "district"]
  rbind(ord[, c("district", "unit", "pos")],
        unique(Lc[Lc$booth_type == "early", list(district, unit, pos = 1.5)]),
        unique(Lc[Lc$booth_type == "postal", list(district, unit, pos = 2.0)]))
}

#' Update a seat-by-class share matrix with the booths counted by a fraction of the night
#'
#' @param shares Afternoon prior: seat x class first-preference shares (percent).
#' @param prior_sd Matching per-cell prior sd ([night_prior_sd()]).
#' @param frac Fraction of each seat's night vote (ordinary + early + postal) counted.
#' @param live,ref Booth tables for the election being replayed and the one before it
#'   (`district, booth, booth_type, party, votes`), e.g. `output/booths-vic2022.csv`.
#' @param seed Seed for the simulated report order (restored afterwards).
#' @return List: `shares` (posterior means, rows renormalised to 100), `sd` (posterior sds),
#'   `counted` (named per-seat share of the final night vote counted), `resolved` (mean over
#'   updated cells of 1 - posterior sd / prior sd), `n_updated` (seats with booths).
#' @export
night_booth_update <- function(shares, prior_sd, frac, live, ref, seed = 2022L) {
  stopifnot(identical(dim(shares), dim(prior_sd)), is.finite(frac), frac >= 0, frac <= 1)
  prep <- function(X) {
    X <- data.table::as.data.table(X)
    X[is.na(votes), votes := 0]
    X[, cls := classify_party(party)]
    X[, unit := ifelse(booth_type == "ordinary", booth, booth_type)]
    X[, list(v = sum(votes)), by = c("district", "unit", "booth_type", "cls")]
  }
  Lc <- prep(live); Rc <- prep(ref)
  M <- match_booth_units(Lc, Rc)
  Rk <- merge(Rc, M, by.x = c("district", "unit"), by.y = c("ref_district", "ref_unit"), suffixes = c(".ref", ".live"))
  Rk <- Rk[, list(district = district.live, unit = unit.live, booth_type = booth_type.live, cls, v)]
  seq_units <- .night_order(Lc, seed)
  night_total <- Lc[Lc$booth_type %in% c("ordinary", "early", "postal"), list(nt = sum(v)), by = "district"]

  post <- as.matrix(shares); psd <- as.matrix(prior_sd)
  seats <- rownames(post); cls_all <- colnames(post)
  counted <- setNames(rep(0, length(seats)), seats)
  res <- numeric(0); n_up <- 0L
  for (s in intersect(seats, unique(Lc$district))) {
    ld <- Lc[Lc$district == s]; rd <- Rk[Rk$district == s]
    su <- seq_units[seq_units$district == s][order(pos)]
    su <- merge(su, ld[, list(uv = sum(v)), by = "unit"], by = "unit")[order(pos)]
    nt <- night_total$nt[night_total$district == s]
    su[, cum := cumsum(uv) / nt]
    units <- if (frac >= 1) su$unit else su$unit[su$cum <= frac + 1e-9]
    if (!length(units)) next
    p <- project_seat_from_booths(ld, rd, units)
    if (is.null(p) || !nrow(p)) next
    cs <- p$counted_share[1]
    counted[s] <- cs
    proj <- 100 * p$projected / sum(p$projected)
    names(proj) <- p$cls
    sdj <- booth_projection_sd(cs)
    j <- match(names(proj), cls_all); ok <- !is.na(j)
    if (!any(ok)) next
    # A class standing now that the projection does not see (no booth votes) keeps its prior;
    # a class the projection sees that the forecast does not model is left out (rows renormalise).
    cm <- combine_prior_projection(post[s, j[ok]], proj[ok], psd[s, j[ok]], sdj)
    res <- c(res, 1 - cm$sd / psd[s, j[ok]])
    post[s, j[ok]] <- cm$mean; psd[s, j[ok]] <- cm$sd
    post[s, ] <- 100 * post[s, ] / sum(post[s, ])
    n_up <- n_up + 1L
  }
  list(shares = post, sd = psd, counted = counted,
       resolved = if (length(res)) mean(res) else 0, n_updated = n_up)
}

#' Shrink statewide draws around their own centre
#' @param draws `n_sims` x parties matrix (or `NULL`, returned as is).
#' @param keep Share of the spread kept, in \[0, 1\].
#' @export
night_shrink_draws <- function(draws, keep) {
  if (is.null(draws)) return(NULL)
  stopifnot(is.finite(keep), keep >= 0, keep <= 1)
  ctr <- colMeans(draws)
  out <- sweep(sweep(draws, 2L, ctr) * keep, 2L, ctr, `+`)
  dimnames(out) <- dimnames(draws)
  out
}
