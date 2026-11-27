# Night two-candidate step, lane B of docs/plans/overnight-2026-11-27-night-fixes.md
# (docs/plans/prereg-night-lane-b-2026-11-27.md). Three switches, each OFF by default and byte-identical when off:
#   same_class  (B1) candidates of one class counted as their own candidates in the two-candidate step
#   flow_pool   (B2) the counted flow error learned across seats of the same final-pair type
#   tcp_by_type (B3) the counted flow by vote type, projected onto the seat's expected mix of vote types
# Nothing here touches the simulator: each step moves the a-share of the draws that hold a pair, then fixes the
# winners, `totals` and `win_prob` with the same rules as night_apply_tcp()'s move_draws.
# Data.table NSE: no argument or local shares a column name inside [...]; masks are computed outside the brackets.

# Counted candidate votes per seat and class: n_cand, tot, the senior (largest) candidate's votes and the second's.
# units: seat -> counted units (`booth` for ordinary booths, else `booth_type`), as night_booth_update() returns them.
.night_cand_votes <- function(live, units, seats) {
  if (!"candidate" %in% names(live)) return(NULL)
  L <- data.table::as.data.table(live)
  keep <- !is.na(L$votes) & L$votes > 0 & !is.na(L$candidate) & nzchar(trimws(L$candidate))
  L <- L[keep]
  if (!nrow(L)) return(NULL)
  cl <- classify_party(L$party); un <- ifelse(L$booth_type == "ordinary", L$booth, L$booth_type)
  # votes as double: an integer column (the federal booth tables) made jun2's 0 and v[2] different types per group
  L <- data.table::data.table(seat = L$district, unit = un, cls = cl, cand = L$candidate, v = as.numeric(L$votes))
  out <- list()
  for (s in intersect(names(units), seats)) {
    u <- units[[s]]
    m <- L$seat == s & L$unit %in% u
    if (!any(m)) next
    x <- L[m, list(v = sum(v)), by = c("cls", "cand")]
    x <- x[order(cls, -v)]
    out[[s]] <- x[, list(seat = s, n_cand = .N, tot = sum(v), sen = v[1], sen_cand = cand[1],
                         jun2 = if (.N >= 2L) v[2] else 0), by = "cls"]
  }
  if (!length(out)) return(NULL)
  data.table::rbindlist(out)
}

#' Same-class parameters for the night (time-forward)
#'
#' `g`, per class: the share of an excluded same-class candidate's votes that end with the other candidate of that
#' class when only the two classes of the final pair remain (exclusions whose votes went to exactly two classes, the
#' class itself and one other), from EARLIER elections' transfers files, shrunk (pseudo-count `.NIGHT_SC_K` = 10
#' exclusions) toward the class's prior `f + (1 - f) / 2`, `f` its one-step same-class rate over every earlier
#' same-class exclusion (as the night class split's `f`). A class with no final-pair exclusion takes its prior.
#' @param target_election Election label, e.g. `"vic2022"`.
#' @param transfers Optional transfers table (`election, seat, round, from, to, votes`); default every
#'   `external/elections/*transfers.csv`.
#' @param classes Classes fitted.
#' @return Named numeric `g`, attribute `n_events` (named by class).
#' @export
night_same_class_params <- function(target_election, transfers = NULL, classes = c("IND", "OTH", "OTH_RIGHT", "LNP", "GRN", "ONP")) {
  .yr <- function(e) as.integer(sub("^[a-z]+", "", e))
  .rg <- function(e) sub("[0-9]+$", "", e)
  if (is.null(transfers)) transfers <- class_split_transfers(classes = classes)
  tx <- data.table::as.data.table(transfers)
  tx <- tx[.yr(tx$election) < .yr(target_election) & tx$from %in% classes]
  ev <- tx[, list(tot = sum(votes), to_lnp = sum(votes[to == from]), n_to = data.table::uniqueN(to)),
           by = c("election", "seat", "round", "from")]
  ev2 <- ev[ev$to_lnp > 0 & ev$tot > 0 & ev$n_to == 2L]
  # Prior per class: its one-step same-class rate f (class_split's .cls_f_by(), every same-class exclusion) plus half
  # of the rest. Final-pair exclusions are rare for minor classes (2 for independents before 2022, against 78
  # Coalition ones), so each class's own rate is shrunk to that prior with a pseudo-count of NIGHT_SC_K exclusions
  # (docs/CONSTANTS.md): a class rate never borrows the Coalition's.
  f1 <- .cls_f_by(target_election, transfers, classes)
  if (all(!is.finite(f1)) && !nrow(ev2)) stop("NSC1! no same-class exclusion before ", target_election, call. = FALSE)
  f1[!is.finite(f1)] <- stats::median(f1[is.finite(f1)])
  k0 <- .NIGHT_SC_K
  g <- vapply(classes, function(k) {
    g0 <- f1[[k]] + (1 - f1[[k]]) / 2
    e <- ev2[ev2$from == k]; n <- nrow(e)
    if (!n) return(g0)
    raw <- sum(e$to_lnp) / sum(e$tot)
    (n * raw + k0 * g0) / (n + k0)
  }, 0)
  attr(g, "n_events") <- vapply(classes, function(k) sum(ev2$from == k), 0L)
  attr(g, "f1") <- f1
  g
}

# Pseudo-count (exclusions) shrinking a class's final-pair same-class rate toward its prior (night_same_class_params).
.NIGHT_SC_K <- 10

# Move the draws `rows` of seat column j (seat s) to a-shares `na` (0-1) between a and b: winner, runner-up and share,
# and for draws whose count winner changes, `totals` (only where the old party holds a seat in that draw, as
# night_apply_tcp()) and `win_prob` (kept at the seat's total). Returns list(sim, changed).
.night_move_pair <- function(sim, rows, j, s, a, b, na) {
  parties <- colnames(sim$totals); n <- nrow(sim$tcp_winner)
  na <- pmin(1, pmax(0, na))
  oldW <- sim$tcp_winner[rows, j]; newW <- ifelse(na > 0.5, a, b)
  ch <- which(newW != oldW)
  for (d in ch) {
    i_old <- match(oldW[d], parties); i_new <- match(newW[d], parties); r <- rows[d]
    if (is.na(i_old) || is.na(i_new)) stop("NSC2! party ", oldW[d], " or ", newW[d], " not in sim$totals", call. = FALSE)
    if (sim$totals[r, i_old] > 0) { sim$totals[r, i_old] <- sim$totals[r, i_old] - 1L; sim$totals[r, i_new] <- sim$totals[r, i_new] + 1L }
  }
  if (length(ch)) {
    wp <- sim$win_prob
    delta <- table(factor(newW[ch], parties)) - table(factor(oldW[ch], parties))
    tot_before <- sum(wp$prob[wp$seat == s])
    for (p in parties[delta != 0]) {
      row <- which(wp$seat == s & wp$party == p)
      if (length(row)) wp$prob[row] <- max(0, wp$prob[row] + delta[[p]] / n)
      else wp <- rbind(wp, data.frame(seat = s, party = p, prob = max(0, delta[[p]] / n), stringsAsFactors = FALSE))
    }
    rows_s <- which(wp$seat == s); tot_after <- sum(wp$prob[rows_s])
    if (tot_after > 0) wp$prob[rows_s] <- wp$prob[rows_s] * tot_before / tot_after
    sim$win_prob <- wp
  }
  sim$tcp_winner[rows, j] <- newW
  sim$tcp_runnerup[rows, j] <- ifelse(newW == a, b, a)
  sim$tcp_share[rows, j] <- ifelse(newW == a, na, 1 - na)
  list(sim = sim, changed = length(ch))
}

#' Same-class candidates as their own candidates in the two-candidate step (switch B1, `same_class`)
#'
#' The simulator counts a class as one candidate, except for ONE split per seat (the Coalition's, else the night
#' class split's second candidate). Every other same-class candidate (Mildura vic2022: the two other independents,
#' with the Liberal already split from the Nationals) is assumed to hand ALL its votes to its class's senior
#' candidate. On the night the counted candidate figures say how big those candidates are; this moves each draw whose
#' final pair holds the class by `j (1 - g)`: `j` the unsplit juniors' share of the seat (the class's updated share
#' times the counted junior fraction), `g` the share of such votes that end with the senior ([night_same_class_params()]).
#' Approximation: the juniors' exclusion order and the pair itself are left as the draw had them.
#' @param sim Output of [simulate_seat_contests()].
#' @param cv Counted candidate votes (`.night_cand_votes()`).
#' @param shares Seat x class matrix of updated first preferences (percent).
#' @param g From [night_same_class_params()].
#' @param cs0 The state's `coalition_split` (`r` named by seat), or `NULL`.
#' @param ncs [night_class_split()] output, or `NULL`.
#' @return `sim`, moved, with attribute `same_class` (one row per seat and class moved).
#' @export
night_same_class_shift <- function(sim, cv, shares, g, cs0 = NULL, ncs = NULL) {
  if (is.null(cv) || !nrow(cv) || is.null(g)) return(sim)
  seats <- colnames(sim$tcp_winner); parties <- colnames(sim$totals)
  cv <- cv[cv$n_cand >= 2L & cv$cls %in% colnames(shares) & cv$cls %in% names(g) & cv$seat %in% seats]
  rep <- list()
  for (k in seq_len(nrow(cv))) {
    s <- cv$seat[k]; cc <- cv$cls[k]; j <- match(s, seats)
    coal <- !is.null(cs0) && !is.null(cs0$r) && s %in% names(cs0$r) && is.finite(cs0$r[[s]])
    sim_split <- if (cc == "LNP") coal else (!coal && !is.null(ncs) && identical(unname(ncs$cls[s]), cc))
    unsplit <- (cv$tot[k] - cv$sen[k] - if (sim_split) cv$jun2[k] else 0) / cv$tot[k]
    if (!is.finite(unsplit) || unsplit <= 0) next
    jj <- shares[s, cc] / 100 * unsplit
    mv <- jj * (1 - g[[cc]])
    W <- sim$tcp_winner[, j]; R <- sim$tcp_runnerup[, j]
    hit <- which((W == cc | R == cc) & W != R)
    if (!length(hit) || mv <= 0) next
    other <- ifelse(W[hit] == cc, R[hit], W[hit])
    sh <- sim$tcp_share[hit, j]; pc <- ifelse(W[hit] == cc, sh, 1 - sh)
    n_ch <- 0L
    for (o in unique(other)) {
      m <- other == o
      res <- .night_move_pair(sim, hit[m], j, s, cc, o, pc[m] - mv)
      sim <- res$sim; n_ch <- n_ch + res$changed
    }
    rep[[length(rep) + 1]] <- data.table::data.table(seat = s, cls = cc, n_cand = cv$n_cand[k], sim_split = sim_split,
                                                     unsplit = unsplit, j = jj, g = g[[cc]], shift = mv, draws = length(hit), changed = n_ch)
  }
  attr(sim, "same_class") <- data.table::rbindlist(rep)
  sim
}

#' Counted flow errors pooled across seats of one final-pair type (switch B2, `flow_pool`)
#'
#' For each seat with a counted two-candidate count ([night_tcp_obs()]) and 2+ draws holding its pair, the residual
#' `d = counted flow - median draw flow` (flow: share of the votes for neither of the pair reaching `a`). Normal
#' hierarchy, every term estimated from the night's own counts (no fitted constant, so no leakage):
#' `d_s = mu_T + e_s + noise`, `e_s ~ N(0, tau^2)`, noise sd `flow_se`, `mu_T ~ N(0, sigma^2)` per pair type `T`
#' (`"a|b"`, sorted). `tau^2` is the within-type spread of `d` less the mean `flow_se^2` (method of moments), `sigma^2`
#' the mean squared type mean less its variance (0 when the counts show no common error: nothing moves). Every seat's
#' draws holding a counted pair type then shift by that type's posterior mean of `mu_T`, leaving the seat's OWN
#' count out (it is used afterwards by [night_apply_tcp()], not twice), times the seat's others' share (from its
#' count where it has one, else from `shares`).
#' @param sim Output of [simulate_seat_contests()].
#' @param obs [night_tcp_obs()] output.
#' @param shares Seat x class matrix of updated first preferences (percent).
#' @return `sim`, moved, with attribute `flow_pool` (one row per seat and type moved; attribute `hyper`: tau, sigma).
#' @export
night_flow_pool <- function(sim, obs, shares) {
  if (is.null(obs) || !nrow(obs)) return(sim)
  seats <- colnames(sim$tcp_winner)
  res_rows <- list()
  for (k in seq_len(nrow(obs))) {
    s <- obs$seat[k]; a <- obs$a[k]; b <- obs$b[k]; j <- match(s, seats)
    if (is.na(j) || !is.finite(obs$flow[k])) next
    W <- sim$tcp_winner[, j]; R <- sim$tcp_runnerup[, j]
    hit <- which((W == a & R == b) | (W == b & R == a))
    if (length(hit) < 2L) next
    rest <- (100 - obs$fp_a[k] - obs$fp_b[k]) / 100; if (!is.finite(rest) || rest <= 0.005) rest <- 0.005
    sh <- sim$tcp_share[hit, j]; pa <- ifelse(W[hit] == a, sh, 1 - sh)
    fm <- stats::median((pa - obs$fp_a[k] / 100) / rest)
    res_rows[[length(res_rows) + 1]] <- data.table::data.table(seat = s, type = paste(a, b, sep = "|"), d = obs$flow[k] - fm,
                                                               se = obs$flow_se[k])
  }
  if (!length(res_rows)) return(sim)
  Rs <- data.table::rbindlist(res_rows)
  Rs$se[!is.finite(Rs$se)] <- 0.25
  # tau^2: within-type spread less sampling (types with 2+ seats), from seats whose flow_se was MEASURED (3+ booths;
  # the 0.25 placeholder for fewer would swamp the subtraction and set tau to 0, passing one seat's residual whole to
  # its type); none -> total spread less sampling over the measured seats, else over all
  meas <- Rs$se < 0.25
  nt <- table(Rs$type[meas]); multi <- meas & Rs$type %in% names(nt)[nt >= 2L]
  if (any(multi)) {
    dm <- ave(Rs$d[multi], Rs$type[multi]); dfree <- sum(multi) - length(unique(Rs$type[multi]))
    tau2 <- max(0, sum((Rs$d[multi] - dm)^2) / dfree - mean(Rs$se[multi]^2))
  } else if (any(meas)) tau2 <- max(0, mean(Rs$d[meas]^2) - mean(Rs$se[meas]^2)) else tau2 <- max(0, mean(Rs$d^2) - mean(Rs$se^2))
  w_all <- 1 / (tau2 + Rs$se^2)
  ty <- unique(Rs$type)
  tm <- vapply(ty, function(t) { m <- Rs$type == t; sum(w_all[m] * Rs$d[m]) / sum(w_all[m]) }, 0)
  tv <- vapply(ty, function(t) 1 / sum(w_all[Rs$type == t]), 0)
  tn <- vapply(ty, function(t) sum(Rs$type == t), 0)
  sigma2 <- max(0, sum(tn * (tm^2 - tv)) / sum(tn))
  hyper <- c(tau = sqrt(tau2), sigma = sqrt(sigma2), n_seats = nrow(Rs), n_types = length(ty))
  rep <- list()
  if (sigma2 > 0) {
    for (j in seq_along(seats)) {
      s <- seats[j]
      W <- sim$tcp_winner[, j]; R <- sim$tcp_runnerup[, j]
      key <- ifelse(W < R, paste(W, R, sep = "|"), paste(R, W, sep = "|"))
      for (t in intersect(unique(key[W != R]), ty)) {
        m <- Rs$type == t & Rs$seat != s
        if (!any(m)) next
        mu <- sum(w_all[m] * Rs$d[m]) / (1 / sigma2 + sum(w_all[m]))
        ab <- strsplit(t, "|", fixed = TRUE)[[1]]; a <- ab[1]; b <- ab[2]
        ko <- which(obs$seat == s & obs$a == a & obs$b == b)
        rest <- if (length(ko)) (100 - obs$fp_a[ko[1]] - obs$fp_b[ko[1]]) / 100 else
          if (all(c(a, b) %in% colnames(shares)) && s %in% rownames(shares)) (100 - shares[s, a] - shares[s, b]) / 100 else NA_real_
        if (!is.finite(rest) || rest <= 0.005) next
        hit <- which(key == t & W != R)
        sh <- sim$tcp_share[hit, j]; pa <- ifelse(W[hit] == a, sh, 1 - sh)
        mvd <- .night_move_pair(sim, hit, j, s, a, b, pa + mu * rest)
        sim <- mvd$sim
        rep[[length(rep) + 1]] <- data.table::data.table(seat = s, type = t, mu = mu, rest = rest, shift = mu * rest,
                                                         draws = length(hit), changed = mvd$changed, own_count = length(ko) > 0)
      }
    }
  }
  out <- data.table::rbindlist(rep)
  attr(out, "hyper") <- hyper; attr(out, "resid") <- Rs
  attr(sim, "flow_pool") <- out
  sim
}
