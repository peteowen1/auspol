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
# `early = "interleaved"` (issue #160) puts each district's early-vote unit at a random point among its
# ordinary booths (uniform 0.3-1.0 of the way through), as early centres report during the evening rather
# than after every booth; with "last" (the default, byte-identical) the 2022 early lump, about half the
# night vote, is never counted below 100%, so no vote-type gap can ever be measured.
.night_order <- function(Lc, seed, early = c("last", "interleaved")) {
  early <- match.arg(early)
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()))
  set.seed(seed)
  ord <- Lc[Lc$booth_type == "ordinary", list(size = sum(v)), by = c("district", "unit")]
  ord[, key := log(size + 1) + stats::rnorm(.N, 0, 0.5)]
  ord <- ord[order(district, key)]
  ord[, pos := seq_len(.N) / .N, by = "district"]
  ear <- unique(Lc[Lc$booth_type == "early", list(district, unit)])
  ear[, pos := if (early == "last") 1.5 else stats::runif(.N, 0.3, 1.0)]
  rbind(ord[, c("district", "unit", "pos")], ear[, c("district", "unit", "pos")],
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
#' @param gap_k Pooled vote-type gap (issue #160): `NULL` (default) is off and byte-identical to
#'   before. A number `k >= 0` turns it on: for each non-ordinary booth type (early, postal, ...)
#'   and class, the gap between that type's counted swing and the same seat's ordinary swing is
#'   pooled over the seats where the type is counted (weighted by its counted votes) and shrunk by
#'   `n / (n + k)`, `n` those seats; a seat whose own votes of that type are not yet in projects them
#'   at its all-types swing plus the shrunk gap.
#' @param new_sd_mult Multiplier on the projection's sd for a class with no previous-election votes in the
#'   seat (a new candidate); 1 (default) treats it like every other class.
#' @param early Report position of each district's early-vote unit: `"last"` (default) after every
#'   ordinary booth, or `"interleaved"` among them (see `.night_order()`).
#' @param reported Live-feed mode (election-night runner): `NULL` (default) simulates the report order and counts
#'   `frac` of the night. A table `district, unit` of the units that HAVE reported (unit = booth name for an
#'   ordinary booth, else the booth type) counts exactly those; `frac` is then ignored. `live` must still list every
#'   unit of the seat (uncounted ones with any votes, ignored) so the uncounted ones can be projected.
#' @param total Denominator of a seat's counted share: `"table"` (default) is the votes in `live` (right for a replay,
#'   where `live` is the final result); `"projected"` is counted / (counted + the projected size of the uncounted units),
#'   which is all a live feed can know; `"expected"` is `expected[seat]` (enrolment x turnout), with the uncounted units
#'   rescaled to the remainder (see [project_seat_from_booths()]).
#' @param expected For `total = "expected"`: named numeric, expected final votes per seat (a seat missing or NA falls
#'   back to `"projected"`).
#' @return List: `shares` (posterior means, rows renormalised to 100), `sd` (posterior sds),
#'   `counted` (named per-seat share of the final night vote counted), `resolved` (mean over
#'   updated cells of 1 - posterior sd / prior sd), `n_updated` (seats with booths), `units`
#'   (counted units per seat), `type_gap` (the pooled gaps used, or `NULL`).
#' @export
night_booth_update <- function(shares, prior_sd, frac, live, ref, seed = 2022L, gap_k = NULL, early = "last", new_sd_mult = 1,
                               reported = NULL, total = c("table", "projected", "expected"), expected = NULL) {
  total <- match.arg(total)
  stopifnot(is.numeric(new_sd_mult), length(new_sd_mult) == 1L, new_sd_mult >= 1)
  stopifnot(identical(dim(shares), dim(prior_sd)), is.finite(frac), frac >= 0, frac <= 1)
  if (!is.null(reported)) stopifnot(all(c("district", "unit") %in% names(reported)))
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
  seq_units <- if (is.null(reported)) .night_order(Lc, seed, early)
  night_total <- Lc[Lc$booth_type %in% c("ordinary", "early", "postal"), list(nt = sum(v)), by = "district"]

  post <- as.matrix(shares); psd <- as.matrix(prior_sd)
  seats <- rownames(post); cls_all <- colnames(post)
  counted <- setNames(rep(0, length(seats)), seats)
  res <- numeric(0); n_up <- 0L; units_by_seat <- list(); fallback_projected <- character(0); proj_total <- numeric(0)
  todo <- intersect(seats, unique(Lc$district))
  cd <- if (!is.null(reported)) reported$district; cu <- if (!is.null(reported)) reported$unit
  for (s in todo) {
    ld <- Lc[Lc$district == s]
    if (!is.null(reported)) {           # a LIVE feed says which units have reported; no report order to simulate
      u <- intersect(cu[cd == s], ld$unit)
      if (length(u)) units_by_seat[[s]] <- u
      next
    }
    su <- seq_units[seq_units$district == s][order(pos)]
    su <- merge(su, ld[, list(uv = sum(v)), by = "unit"], by = "unit")[order(pos)]
    nt <- night_total$nt[night_total$district == s]
    su[, cum := cumsum(uv) / nt]
    units <- if (frac >= 1) su$unit else su$unit[su$cum <= frac + 1e-9]
    if (length(units)) units_by_seat[[s]] <- units
  }
  type_gap <- if (is.null(gap_k)) NULL else .night_type_gap(Lc, Rk, units_by_seat, gap_k)
  for (s in names(units_by_seat)) {
    ld <- Lc[Lc$district == s]; rd <- Rk[Rk$district == s]
    units <- units_by_seat[[s]]
    if (total == "expected" && !(!is.null(expected) && is.finite(unname(expected[s])) && unname(expected[s]) > 0)) fallback_projected <- c(fallback_projected, s)
    p <- project_seat_from_booths(ld, rd, units, type_gap = type_gap, total = total, expected_total = if (is.null(expected)) NA_real_ else unname(expected[s]))
    if (is.null(p) || !nrow(p)) next
    cs <- p$counted_share[1]
    proj_total[s] <- sum(p$projected)
    counted[s] <- cs
    proj <- 100 * p$projected / sum(p$projected)
    names(proj) <- p$cls
    sdj <- rep(booth_projection_sd(cs), length(proj))
    # NEW CANDIDATES (#160): a class with no votes at the previous election in this seat has no booth
    # swing to measure -- the projection carries its counted share forward -- so its projection is held
    # more loosely (new_sd_mult; 1 = as every other class).
    if (new_sd_mult != 1) sdj[!names(proj) %in% unique(rd$cls)] <- sdj[!names(proj) %in% unique(rd$cls)] * new_sd_mult
    j <- match(names(proj), cls_all); ok <- !is.na(j)
    if (!any(ok)) next
    # A class standing now that the projection does not see (no booth votes) keeps its prior;
    # a class the projection sees that the forecast does not model is left out (rows renormalise).
    cm <- combine_prior_projection(post[s, j[ok]], proj[ok], psd[s, j[ok]], sdj[ok])
    res <- c(res, 1 - cm$sd / psd[s, j[ok]])
    post[s, j[ok]] <- cm$mean; psd[s, j[ok]] <- cm$sd
    post[s, ] <- 100 * post[s, ] / sum(post[s, ])
    n_up <- n_up + 1L
  }
  list(shares = post, sd = psd, counted = counted,
       resolved = if (length(res)) mean(res) else 0, n_updated = n_up, units = units_by_seat, type_gap = type_gap,
       fallback_projected = fallback_projected, proj_total = proj_total)
}

# Pooled swing gap of each non-ordinary booth type against ordinary booths, per class, over the
# seats where both are counted, shrunk by n / (n + k). Swings are share-point changes on matched
# units, the same arithmetic as project_seat_from_booths().
.night_type_gap <- function(Lc, Rk, units_by_seat, k) {
  stopifnot(is.numeric(k), length(k) == 1L, k >= 0)
  rows <- list()
  for (s in names(units_by_seat)) {
    u <- units_by_seat[[s]]
    ld <- Lc[Lc$district == s & Lc$unit %in% u]; rd <- Rk[Rk$district == s & Rk$unit %in% u]
    if (!nrow(rd)) next
    lt <- ld[, list(lt = sum(v)), by = "unit"]; rt <- rd[, list(rt = sum(v)), by = "unit"]
    mc <- merge(ld, rd[, list(unit, cls, rv = v)], by = c("unit", "cls"))
    mc <- merge(merge(mc, lt, by = "unit"), rt, by = "unit")
    # SWT, not `sw`: a table named like its own column binds to the COLUMN inside `[` (CLAUDE.md's
    # data.table trap; it failed exactly that way on its first run, 2026-10-28).
    SWT <- mc[, list(sw = sum(v) / sum(lt) - sum(rv) / sum(rt), w = sum(v)), by = c("booth_type", "cls")]
    o <- SWT[SWT$booth_type == "ordinary", list(cls, sw_o = sw)]
    g <- merge(SWT[SWT$booth_type != "ordinary"], o, by = "cls")
    if (nrow(g)) rows[[s]] <- g[, list(seat = s, booth_type, cls, gap = sw - sw_o, w)]
  }
  G <- data.table::rbindlist(rows)
  if (!nrow(G)) return(NULL)
  G[, list(gap = (data.table::uniqueN(seat) / (data.table::uniqueN(seat) + k)) * sum(gap * w) / sum(w),
           n_seats = data.table::uniqueN(seat)), by = c("booth_type", "cls")]
}

#' The VEC's two-candidate count, turned into a projected final 2CP per seat
#'
#' The counted booths are not a random sample of the seat (small booths report first), so their
#' raw 2CP share is biased; tried first on 2026-10-28 and it made the replay WORSE (vic2022 log loss
#' 0.1112 -> 0.1661 at half counted). What the counted booths do measure well is the PREFERENCE FLOW:
#' of the votes for neither of the pair, the share that went to `a`. That flow is applied to the seat's
#' updated first preferences: `share_a = (fp_a + flow * (100 - fp_a - fp_b)) / 100`.
#'
#' @param tcp Booth 2CP rows (`district, booth, vote_type, party_raw, votes`), e.g.
#'   `output/booths/vic2022-booth-tcp.csv`. A unit is the booth for ordinary votes, else the vote type.
#' @param fp Booth first-preference rows for the same election (`district, booth, booth_type, party,
#'   votes`), e.g. `output/booths-vic2022.csv`.
#' @param units Named list: the counted units per seat ([night_booth_update()]'s `units`).
#' @param post Seat x class matrix of updated first preferences (percent).
#' @return data.table `seat, a, b, flow` (share of the others' votes reaching `a`, 0-1), `share_a`
#'   (projected final 2CP share of `a`, 0-1), `raw_share_a` (the RAW counted 2CP share of `a` over `a` + `b` in the counted units, no projection), `votes` (2CP votes counted). Seats with no counted
#'   2CP, not exactly two classes, a class missing from `post`, or no other votes, are absent.
#' @export
night_tcp_obs <- function(tcp, fp, units, post) {
  # vote-type labels differ between the two files ("marked as voted" / "marked_as_voted"): one spelling
  .vt <- function(x) gsub("[^a-z]+", "_", tolower(x))
  TT <- data.table::as.data.table(tcp)
  TT[is.na(votes), votes := 0]
  TT[, cls := classify_party(party_raw)]
  TT[, unit := ifelse(vote_type == "ordinary", booth, .vt(vote_type))]
  FF <- data.table::as.data.table(fp)
  FF[is.na(votes), votes := 0]
  FF[, cls := classify_party(party)]
  FF[, unit := ifelse(booth_type == "ordinary", booth, .vt(booth_type))]
  out <- list()
  for (s in intersect(names(units), rownames(post))) {
    u <- units[[s]]
    if (!length(u)) next
    u <- ifelse(u %in% FF$booth[FF$district == s & FF$booth_type == "ordinary"], u, .vt(u))
    x <- TT[TT$district == s & TT$unit %in% u, list(v = sum(votes)), by = "cls"]
    if (nrow(x) != 2L || sum(x$v) <= 0) next
    x <- x[order(cls)]
    a <- x$cls[1]; b <- x$cls[2]
    if (!all(c(a, b) %in% colnames(post))) next
    # first preferences in the SAME counted units the 2CP covers
    tu <- unique(TT$unit[TT$district == s & TT$unit %in% u])
    f <- FF[FF$district == s & FF$unit %in% tu, list(v = sum(votes)), by = "cls"]
    tot <- sum(f$v); fa <- sum(f$v[f$cls == a]); fb <- sum(f$v[f$cls == b])
    rest <- tot - fa - fb
    if (rest <= 0) next
    flow <- min(1, max(0, (x$v[1] - fa) / rest))
    # Its standard error from the spread of the flow between counted booths, weighted by their
    # other-party votes: flows differ booth to booth far more than sampling alone implies, and that
    # heterogeneity is what an early count does not pin down. Unbiased weighted form (divides by
    # 1 - sum(w^2)); under 3 booths the spread cannot be measured, so the flow is held loosely (0.25).
    # Review of #161: the biased form gave 0.01 for two equal booths and the flow ~99% weight.
    pb_t <- TT[TT$district == s & TT$unit %in% tu & TT$cls == a, list(ta = sum(votes)), by = "unit"]
    pb_f <- FF[FF$district == s & FF$unit %in% tu, list(fa = sum(votes[cls == a]), fb = sum(votes[cls == b]), tot = sum(votes)), by = "unit"]
    pbk <- merge(pb_t, pb_f, by = "unit"); pbk[, rst := tot - fa - fb]; pbk <- pbk[pbk$rst > 0]
    se <- if (nrow(pbk) >= 3L) {
      fj <- pmin(1, pmax(0, (pbk$ta - pbk$fa) / pbk$rst)); w <- pbk$rst / sum(pbk$rst)
      sqrt(sum(w * (fj - sum(w * fj))^2) * sum(w^2) / max(1 - sum(w^2), 1e-6))
    } else 0.25
    pa <- post[s, a]; pb <- post[s, b]
    out[[s]] <- data.table::data.table(seat = s, a = a, b = b, flow = flow, flow_se = max(se, 0.02),
                                       fp_a = pa, fp_b = pb,
                                       share_a = (pa + flow * (100 - pa - pb)) / 100, raw_share_a = x$v[1] / sum(x$v), votes = sum(x$v))
  }
  data.table::rbindlist(out)
}

#' Condition simulated draws on the VEC's two-candidate count
#'
#' For each seat with an observed pair: the draws whose final two are that pair are found;
#' if the pair occurs in fewer than `pair_min` of draws the count is ignored and the seat is
#' flagged (the VEC's pair is probably not the real contest). Otherwise only the PREFERENCE FLOW
#' is updated: each draw's implied flow to `a` (its 2CP share minus `a`'s updated first preference,
#' over the others' share) is combined, precision-weighted, with the flow counted in the booths
#' (`flow`, `flow_se` from [night_tcp_obs()]), and every draw shifts by the change in mean flow
#' times the others' share. The first preferences are not used a second time. Winners, `totals`
#' and `win_prob` are updated for the draws whose winner changes.
#' Replay, vic2022, 1,000 sims: seat log loss 0.1556 -> 0.1146 at 10% counted, 0.1112 -> 0.0970 at 50%
#' (first-preference update alone -> plus this); an earlier version that combined 2CP SHARES made it
#' worse (0.1661), by counting the first preferences twice.
#'
#' Approximation: the draw's credited winner is taken to be its count winner (`tcp_winner`); the
#' per-draw calibration shrink toss (1% at the published setting) is not redone for a changed draw.
#' @param sim Output of [simulate_seat_contests()].
#' @param obs [night_tcp_obs()] output.
#' @param pair_min Smallest share of draws with the VEC's pair for its count to be used.
#' @return `sim`, updated, with attribute `night_tcp`: one row per observed seat (pair share
#'   of draws, prior and posterior mean of a's share, draws changed, `flag`).
#' @export
night_apply_tcp <- function(sim, obs, pair_min = 0.2) {
  if (is.null(obs) || !nrow(obs)) return(sim)
  seats <- colnames(sim$tcp_winner)
  if (is.null(seats)) stop("NX5! sim$tcp_winner has no seat names: cannot match the VEC's 2CP to seats", call. = FALSE)
  n <- nrow(sim$tcp_winner); parties <- colnames(sim$totals)
  wp <- sim$win_prob; rep <- list()
  for (k in seq_len(nrow(obs))) {
    s <- obs$seat[k]; a <- obs$a[k]; b <- obs$b[k]
    raw_k <- if ("raw_share_a" %in% names(obs)) obs$raw_share_a[k] else NA_real_   # raw counted 2CP share of a, not the flow projection
    j <- match(s, seats); if (is.na(j)) next
    W <- sim$tcp_winner[, j]; R <- sim$tcp_runnerup[, j]
    hit <- which((W == a & R == b) | (W == b & R == a))
    frac_pair <- length(hit) / n
    if (frac_pair < pair_min || length(hit) < 2L) {
      rep[[k]] <- data.table::data.table(seat = s, a = a, b = b, pair_share = frac_pair, prior_a = NA_real_,
                                         post_a = NA_real_, obs_a = obs$share_a[k], raw_a = raw_k, changed = 0L, flag = TRUE)
      next
    }
    sh <- sim$tcp_share[hit, j]
    pa <- ifelse(W[hit] == a, sh, 1 - sh)                      # a's share of the pair, 0-1
    pm <- mean(pa)
    # FLOW ONLY. The draws already carry the updated first preferences, so the count's evidence on
    # those must not be used twice: the 2CP updates the preference FLOW, and every draw shifts by
    # the change in flow times the other parties' share. (Combining 2CP shares directly double-
    # counted the first preferences and over-sharpened close seats: Mornington 0.69 -> 0.04.)
    rest <- (100 - obs$fp_a[k] - obs$fp_b[k]) / 100
    if (!is.finite(rest) || rest <= 0.005) rest <- 0.005
    fi <- (pa - obs$fp_a[k] / 100) / rest                     # each draw's implied flow to a
    fm <- mean(fi); fsd <- max(stats::sd(fi), 0.01)
    cm <- combine_prior_projection(fm, obs$flow[k], fsd, obs$flow_se[k])
    na <- pmin(1, pmax(0, pa + (cm$mean - fm) * rest))
    cm <- list(mean = mean(na))
    newW <- ifelse(na > 0.5, a, b); oldW <- W[hit]
    ch <- which(newW != oldW)
    for (d in ch) {
      i_old <- match(oldW[d], parties); i_new <- match(newW[d], parties); r <- hit[d]
      # Move a seat from old to new in this draw ONLY if old holds one: after the shrink toss the
      # credited winner can differ from the count winner, and an unmatched increment would double count.
      if (sim$totals[r, i_old] > 0) {
        sim$totals[r, i_old] <- sim$totals[r, i_old] - 1L
        sim$totals[r, i_new] <- sim$totals[r, i_new] + 1L
      }
    }
    if (length(ch)) {
      delta <- table(factor(newW[ch], parties)) - table(factor(oldW[ch], parties))
      for (p in parties[delta != 0]) {
        row <- which(wp$seat == s & wp$party == p)
        if (length(row)) wp$prob[row] <- max(0, wp$prob[row] + delta[[p]] / n)
        else wp <- rbind(wp, data.frame(seat = s, party = p, prob = max(0, delta[[p]] / n), stringsAsFactors = FALSE))
      }
    }
    sim$tcp_winner[hit, j] <- newW
    sim$tcp_runnerup[hit, j] <- ifelse(newW == a, b, a)
    sim$tcp_share[hit, j] <- ifelse(newW == a, na, 1 - na)
    rep[[k]] <- data.table::data.table(seat = s, a = a, b = b, pair_share = frac_pair, prior_a = pm,
                                       post_a = cm$mean, obs_a = obs$share_a[k], raw_a = raw_k, changed = length(ch), flag = FALSE)
  }
  sim$win_prob <- wp[wp$prob > 0, ]
  attr(sim, "night_tcp") <- data.table::rbindlist(rep)
  sim
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
