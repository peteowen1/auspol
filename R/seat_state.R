# SEAT-LEVEL QUICK SCREEN (scripts/seat_quick.R; Pete, 25 Nov 2026: "testing a tweak
# that touches 39 seats should not need a 45-minute run of all 35 elections").
#
# Each harness's final simulate_seat_contests() call goes through seat_state_sim().
# With AUSPOL_SEAT_STATE_DUMP unset it is exactly that call (do.call on the same
# evaluated arguments; no RNG, no extra work). Set to <path>.rds, it also saves the
# EXACT argument list the simulator received, every AUSPOL_* variable in force, and the
# run's own win probabilities, to <path>-<pair>.rds. So the cached state is the
# simulation's input by construction, not a second hand-kept list of the same
# expressions (the AUSPOL_NIGHT_DUMP lists had already drifted: the NSW one lacks
# `exhaust` and `engine`).
#
# A seat's simulated winner depends only on its own row and its own draws
# (docs/plans/plan-correlated-seat-draws.md section 0), so a tweak that moves a few
# rows can be re-simulated on those rows alone. The simulator draws one stream,
# simulations outer and seats inner, so a SUBSET run is a fresh Monte Carlo estimate
# for those seats, not the same draws the full run used: it matches the full run to
# Monte Carlo error, and baseline and arm subsets share a seed (common random numbers).

#' Run the final seat simulation, saving its exact inputs when asked
#'
#' `simulate_seat_contests(...)` with the same arguments. With
#' `AUSPOL_SEAT_STATE_DUMP` set to a path ending `.rds`, the argument list
#' (matched to the simulator's formals, so every entry is named), the
#' `AUSPOL_*` environment and the result's `win_prob` are saved to that path
#' with `-<pair>` inserted before `.rds`. Saved AFTER the simulation, so the
#' dump cannot touch the random stream.
#' @param pair Election label, e.g. `"vic2022"`.
#' @param ... Arguments for [simulate_seat_contests()].
#' @return The [simulate_seat_contests()] result.
#' @keywords internal
seat_state_sim <- function(pair, ...) {
  args <- list(...)
  path <- Sys.getenv("AUSPOL_SEAT_STATE_DUMP", "")
  if (nzchar(path) && !grepl("[.]rds$", path)) stop("SQ9! AUSPOL_SEAT_STATE_DUMP must end in .rds (the pair label is inserted before it), not ", path)
  sim <- do.call(simulate_seat_contests, args)
  if (nzchar(path)) {
    out <- sub("[.]rds$", sprintf("-%s.rds", pair), path)
    env <- Sys.getenv(); env <- env[grepl("^AUSPOL_", names(env))]
    na <- seat_state_named_args(args)
    saveRDS(list(version = 1L, pair = pair, args = na,
                 env = stats::setNames(as.character(env), names(env)), win_prob = sim$win_prob), out)
    cat(sprintf("SQ8  seat state for %s saved to %s (%d seats, %s sims)\n", pair, out, nrow(as.matrix(na$shares)),
                if (is.null(na$n_sims)) "default" else format(na$n_sims)))
  }
  sim
}

#' Name every argument by matching it to simulate_seat_contests()'s formals
#'
#' Unnamed arguments are matched by position to the formals not already named,
#' exactly as R matches a call (no partial names: every named argument must be
#' a formal in full).
#' @param args List of arguments, some possibly unnamed.
#' @return The same list, every element named.
#' @keywords internal
seat_state_named_args <- function(args) {
  f <- names(formals(simulate_seat_contests))
  nm <- names(args); if (is.null(nm)) nm <- rep("", length(args))
  bad <- nm[nzchar(nm) & !nm %in% f]
  if (length(bad)) stop("seat_state: not an argument of simulate_seat_contests(): ", paste(bad, collapse = ", "))
  if (anyDuplicated(nm[nzchar(nm)])) stop("seat_state: argument named twice")
  free <- setdiff(f, nm[nzchar(nm)])
  un <- which(!nzchar(nm))
  if (length(un) > length(free)) stop("seat_state: more positional arguments than free formals")
  nm[un] <- free[seq_along(un)]
  names(args) <- nm
  args
}

# Arguments that are never indexed by seat (flow table, statewide draws, per-class
# quantities). Everything else is subset by seat when its shape says it is per seat.
.SEAT_STATE_NOT_PER_SEAT <- c("matrix", "statewide_draws", "party_draws", "party_cor", "error_q",
                              "breakout_q", "level_sd", "party_sd", "seat_sd", "flow_sd", "fallback_flow_sd",
                              "n_sims", "seed", "smooth", "fallback_smooth", "shrink_k", "exhaust", "engine",
                              "keep_fp", "surge_parties", "surge_floor", "surge_from_zero", "zero_absent",
                              "surge_level", "level_mult")

#' Restrict a saved argument list to some seats
#'
#' `shares` rows are kept in the order of `seats`. Every other argument not in the
#' known per-class/global list is subset when it is per seat: a matrix or data
#' frame with one row per seat, or a vector/list with one element per seat (by
#' name when it is named by seat). An argument of any other shape that is not
#' length 0 or 1 stops the run: a shape this function does not understand is
#' never passed through unsubset.
#' @param args Named argument list ([seat_state_named_args()]).
#' @param seats Seat names (rownames of `args$shares`).
#' @return The subset argument list.
#' @keywords internal
seat_state_subset <- function(args, seats) {
  sh <- as.matrix(args$shares); all_seats <- rownames(sh)
  if (is.null(all_seats) || anyDuplicated(all_seats)) stop("seat_state_subset: shares need unique seat rownames")
  idx <- match(seats, all_seats)
  if (anyNA(idx)) stop("seat_state_subset: seat(s) not in the state: ", paste(seats[is.na(idx)], collapse = ", "))
  n <- length(all_seats)
  if (length(args$level_mult) && (is.matrix(args$level_mult) && nrow(args$level_mult) == n || (!is.matrix(args$level_mult) && length(args$level_mult) == n)))
    stop("seat_state_subset: level_mult is per seat here; this function treats it as per class")
  one <- function(x, what) {
    if (is.null(x) || is.function(x)) return(x)
    if (is.matrix(x) || is.data.frame(x)) {
      if (nrow(x) != n) stop(sprintf("seat_state_subset: %s has %d rows for %d seats", what, nrow(x), n))
      if (!is.null(rownames(x)) && !is.data.frame(x) && !identical(rownames(x), all_seats))
        stop("seat_state_subset: ", what, " rows are not in the seat order of shares")
      return(x[idx, , drop = FALSE])
    }
    if (length(x) <= 1L) return(x)
    if (length(x) == n) {
      if (!is.null(names(x)) && all(nzchar(names(x)))) {
        if (!setequal(names(x), all_seats)) stop("seat_state_subset: ", what, " is named but not by these seats")
        return(x[seats])
      }
      return(x[idx])
    }
    if (is.list(x)) {   # a container (e.g. a coalition split): subset each element by the same rules
      at <- attributes(x)
      y <- lapply(seq_along(x), function(k) one(x[[k]], sprintf("%s[[%d]]", what, k)))
      attributes(y) <- at
      return(y)
    }
    if (!is.null(names(x)) && all(names(x) %in% all_seats)) return(x[intersect(names(x), seats)])
    stop(sprintf("seat_state_subset: cannot tell whether %s (length %d, %d seats) is per seat", what, length(x), n))
  }
  out <- args
  out$shares <- sh[idx, , drop = FALSE]
  for (a in setdiff(names(args), c("shares", .SEAT_STATE_NOT_PER_SEAT))) {
    if (is.null(args[[a]])) next
    out[a] <- list(one(args[[a]], a))
  }
  out
}

#' Re-run a saved seat simulation, optionally on some seats and with new shares
#'
#' The `AUSPOL_*` environment saved with the state is put in force for the call
#' (every other `AUSPOL_*` variable is unset) and restored afterwards, because the
#' simulator reads some switches itself (`zero_absent_on()`, `surge_level_on()`,
#' `AUSPOL_SIM_ENGINE`).
#' @param st A state from [seat_state_sim()] (`readRDS`).
#' @param shares Replacement shares matrix (same rows and columns), or `NULL`.
#' @param seats Seats to simulate (`NULL`: all, in the saved order).
#' @param n_sims Simulations (`NULL`: as saved). At most the saved count when the
#'   state carries statewide draws (their first `n_sims` rows are used).
#' @return The `win_prob` data frame (`seat`, `party`, `prob`).
#' @keywords internal
seat_state_resim <- function(st, shares = NULL, seats = NULL, n_sims = NULL) {
  a <- st$args
  if (!is.null(shares)) {
    old <- as.matrix(a$shares)
    if (!identical(dim(shares), dim(old)) || !identical(dimnames(shares), dimnames(old)))
      stop("seat_state_resim: replacement shares differ in shape or names from the saved ones")
    a$shares <- shares
  }
  if (!is.null(n_sims)) {
    n0 <- if (is.null(a$n_sims)) 2000L else as.integer(a$n_sims)
    if (!is.null(a$statewide_draws)) {
      if (n_sims > nrow(a$statewide_draws)) stop(sprintf("seat_state_resim: %d sims asked, the state carries %d statewide draws", n_sims, nrow(a$statewide_draws)))
      a$statewide_draws <- a$statewide_draws[seq_len(n_sims), , drop = FALSE]
    } else if (n_sims != n0 && !is.null(a$party_draws)) stop("seat_state_resim: party_draws cannot be resized")
    a$n_sims <- as.integer(n_sims)
  }
  if (!is.null(seats)) a <- seat_state_subset(a, seats)
  seat_state_with_env(st, {
    utils::capture.output(sim <- do.call(simulate_seat_contests, a))
    sim$win_prob
  })
}

#' Evaluate `code` with a saved state's `AUSPOL_*` environment in force
#'
#' Every `AUSPOL_*` variable is unset, the state's are set (except the dump path
#' itself), `code` runs, and the caller's `AUSPOL_*` variables are put back
#' whatever happens.
#' @param st A saved state.
#' @param code Expression.
#' @param extra Named character vector set on top (e.g. an arm's switch).
#' @return The value of `code`.
#' @keywords internal
seat_state_with_env <- function(st, code, extra = character(0)) {
  cur <- Sys.getenv(); cur <- cur[grepl("^AUSPOL_", names(cur))]
  clear <- function() { now <- names(Sys.getenv()); drop <- now[grepl("^AUSPOL_", now)]; if (length(drop)) Sys.unsetenv(drop) }
  on.exit({ clear(); if (length(cur)) do.call(Sys.setenv, as.list(cur)) }, add = TRUE)
  clear()
  env <- c(st$env[names(st$env) != "AUSPOL_SEAT_STATE_DUMP"], extra)
  env <- env[!duplicated(names(env), fromLast = TRUE)]
  if (length(env)) do.call(Sys.setenv, as.list(env))
  force(code)
}

#' Probability each seat's actual winner was given, from a win_prob table
#' @param wp data.frame `seat`, `party`, `prob`.
#' @param actual Named character vector: winner by seat.
#' @return Numeric, one per `names(actual)`; 0 where the winner was never drawn.
#' @keywords internal
seat_state_winner_p <- function(wp, actual) {
  k <- paste(wp$seat, wp$party, sep = "\r")
  p <- wp$prob[match(paste(names(actual), actual, sep = "\r"), k)]
  p[is.na(p)] <- 0
  stats::setNames(p, names(actual))
}

#' Seat-winner log-loss change on touched seats, comparable with quick_arm.R's Q3
#'
#' `seats` holds the touched seats only (`pair`, `seat`, `p_base`, `p_arm`);
#' `n_seats` gives every election's full seat count, so the change can also be
#' stated as quick_arm's Q3 states it: the mean over EVERY seat of the elections
#' scored, untouched seats contributing exactly 0 (their probabilities cannot move
#' when only touched rows are re-simulated). SE clustered on election either way.
#' @param seats data.frame `pair`, `seat`, `p_base`, `p_arm`.
#' @param n_seats Named integer: seats per election (names = pairs scored).
#' @param eps Floor before the log (quick_arm: 0.5 / n_sims).
#' @return list `touched` (quick_clustered over touched seats), `all` (over every
#'   seat), `per_pair` data.frame, `seats` with `dd`.
#' @keywords internal
seat_state_ll <- function(seats, n_seats, eps) {
  if (!all(seats$pair %in% names(n_seats))) stop("seat_state_ll: a touched seat's election has no seat count")
  ll <- function(p) -log(pmax(eps, p))
  seats$ll_base <- ll(seats$p_base); seats$ll_arm <- ll(seats$p_arm); seats$dd <- seats$ll_arm - seats$ll_base
  pad <- unlist(lapply(names(n_seats), function(e) rep(0, n_seats[[e]] - sum(seats$pair == e))))
  padc <- unlist(lapply(names(n_seats), function(e) rep(e, n_seats[[e]] - sum(seats$pair == e))))
  if (any(n_seats[unique(seats$pair)] < table(seats$pair)[unique(seats$pair)])) stop("seat_state_ll: more touched seats than seats")
  per <- do.call(rbind, lapply(names(n_seats), function(e) {
    g <- seats[seats$pair == e, , drop = FALSE]
    data.frame(pair = e, seats = n_seats[[e]], touched = nrow(g), ll_change_touched = if (nrow(g)) mean(g$dd) else 0,
               ll_change_all = sum(g$dd) / n_seats[[e]], stringsAsFactors = FALSE)
  }))
  list(touched = if (nrow(seats)) quick_clustered(seats$dd, seats$pair) else NULL,
       all = quick_clustered(c(seats$dd, pad), c(seats$pair, padc)), per_pair = per, seats = seats)
}

#' Stop when a tweak moved a seat it does not claim, or a cell by NA
#'
#' A seat-level tweak declares the seats it means to change (`targets`). Any
#' other row that moved is a bug in the tweak (an index off by one, a seat
#' matched by the wrong name), and screening it would score seats the idea
#' never touched.
#' @param base,arm Shares matrices, same shape.
#' @param targets Seat names the tweak may move.
#' @return Character vector of the seats that moved (all within `targets`).
#' @keywords internal
seat_tweak_check <- function(base, arm, targets) {
  if (!identical(dim(base), dim(arm)) || !identical(dimnames(base), dimnames(arm)))
    stop("SQ7! the tweak changed the shape or names of the shares matrix")
  if (anyNA(arm) && !identical(is.na(arm), is.na(base))) stop("SQ7! the tweak introduced NA shares")
  d <- abs(arm - base); d[is.na(d)] <- 0
  moved <- rownames(base)[rowSums(d) > 0]
  stray <- setdiff(moved, targets)
  if (length(stray)) stop("SQ7! the tweak moved seat(s) it does not target: ", paste(stray, collapse = ", "))
  tot <- abs(rowSums(arm, na.rm = TRUE) - rowSums(base, na.rm = TRUE))
  if (any(tot > 1e-8)) stop("SQ7! the tweak changed a row total: ", paste(rownames(base)[tot > 1e-8], collapse = ", "))
  moved
}

#' Former-leader seat tweak on cached shares: flat (as `AUSPOL_LEADER_FORMER=1`) or scaled by safety
#'
#' `"flat"` moves each former leader's party in that seat by its role's bonus
#' ([former_leader_bonus()]) with [.shift_cell()], the same arithmetic and order
#' [leader_seat_apply()] uses. `"scaled"` cuts `slope * safety`, where `safety`
#' is a non-negative number per seat (how safe the seat is for that party) and
#' `slope` comes from [former_leader_scaled_slope()], fitted on earlier elections
#' with the same safety measure (plans/prereg-leader-former-scaled-2026-11-25.md).
#' @param shares Shares matrix (seats x classes) as the simulator receives it.
#' @param pair Election label.
#' @param mode `"flat"` or `"scaled"`.
#' @param safety For `"scaled"`: `function(pair, fs)` returning one non-negative
#'   number (or `NA`) per row of `fs` (`seat`, `party`).
#' @param passthrough `NULL`, or data.frame `pair`, `seat`, `party`, `r`: each listed
#'   seat's cut is multiplied by `r`, the fraction of the cut the real harness
#'   carries through to the final shares (see `scripts/seat_quick.R --passthrough`).
#' @return `shares`, moved, with attributes `targets` (seats it may move) and `log`
#'   (data.table seat, party, delta, and `safety`/`slope` when scaled).
#' @keywords internal
seat_tweak_former_leader <- function(shares, pair, mode = c("flat", "scaled"), safety = NULL, passthrough = NULL) {
  mode <- match.arg(mode)
  ls <- leader_seats()
  fs <- former_leader_seats(pair, ls)
  attr(shares, "targets") <- character(0)
  attr(shares, "log") <- data.table::data.table(seat = character(0), party = character(0), delta = numeric(0))
  if (!nrow(fs)) return(shares)
  if (mode == "flat") {
    fb <- former_leader_bonus(pair)
    fs <- merge(fs, fb[, list(role, bonus)], by = "role", sort = FALSE)
    fs$delta <- fs$bonus
  } else {
    if (!is.function(safety)) stop("seat_tweak_former_leader: mode \"scaled\" needs a safety function")
    sl <- former_leader_scaled_slope(pair, safety, ls)
    fs$safety <- safety(pair, fs)
    fs$slope <- sl$slope
    fs$delta <- sl$slope * fs$safety
  }
  # PASS-THROUGH: the share of a pre-blend cut the real harness carries to the final shares (the seat-poll
  # blend dilutes it in polled seats); a seat not listed passes 1.
  fs$pt <- 1
  if (!is.null(passthrough)) {
    k <- match(paste(pair, normalise_seat(fs$seat), fs$party), paste(passthrough$pair, normalise_seat(passthrough$seat), passthrough$party))
    fs$pt[!is.na(k)] <- passthrough$r[k[!is.na(k)]]
    fs$delta <- fs$delta * fs$pt
  }
  i <- match(normalise_seat(fs$seat), normalise_seat(rownames(shares)))
  j <- match(fs$party, colnames(shares))
  hit <- which(!is.na(i) & !is.na(j) & is.finite(fs$delta) & fs$delta != 0)
  for (h in hit) shares[i[h], ] <- .shift_cell(shares[i[h], ], j[h], fs$delta[h])
  attr(shares, "targets") <- rownames(shares)[unique(i[hit])]
  lg <- data.table::data.table(seat = rownames(shares)[i[hit]], party = fs$party[hit], delta = fs$delta[hit], passthrough = fs$pt[hit])
  if (mode == "scaled") { lg$safety <- fs$safety[hit]; lg$slope <- fs$slope[hit] }
  attr(shares, "log") <- lg
  shares
}

#' Safety measure: the party's primary margin over the best other party, as-at tree predictions
#'
#' `max(0, own - best other)` in points of `xgb_pred_seat` ([current_seat_predictions()]),
#' `NA` where the seat or party has no prediction.
#' @param pair Election label.
#' @param fs data.table with `seat`, `party`.
#' @return Numeric, one per row of `fs`.
#' @keywords internal
former_safety_margin <- function(pair, fs) {
  f <- current_seat_predictions()
  if (is.null(f)) stop("former_safety_margin needs the as-at predictions")
  .p <- pair
  f <- f[f$election == .p & is.finite(f$xgb_pred_seat)]
  s <- f[, list(pred = sum(xgb_pred_seat)), by = list(seat, party)]
  ns <- normalise_seat(s$seat)
  vapply(seq_len(nrow(fs)), function(r) {
    in_seat <- ns == normalise_seat(fs$seat[r])
    own <- s$pred[in_seat & s$party == fs$party[r]]
    oth <- s$pred[in_seat & s$party != fs$party[r]]
    if (length(own) != 1L || !length(oth)) return(NA_real_)
    max(0, own - max(oth))
  }, 0)
}

#' Safety measure from the model's own win probabilities: `max(0, 2 p - 1)`
#'
#' `p` is the probability the baseline forecast gave that party to win the seat,
#' looked up in `wp`; 0 at a coin flip or worse, 1 at certainty.
#' @param wp data.frame `pair`, `seat`, `party`, `prob` covering the elections asked about.
#' @return `function(pair, fs)` for [seat_tweak_former_leader()].
#' @keywords internal
former_safety_winprob <- function(wp) {
  key <- paste(wp$pair, normalise_seat(wp$seat), wp$party, sep = "\r")
  function(pair, fs) {
    seats_here <- unique(wp$seat[wp$pair == pair])
    if (!length(seats_here)) return(rep(NA_real_, nrow(fs)))
    p <- wp$prob[match(paste(pair, normalise_seat(fs$seat), fs$party, sep = "\r"), key)]
    known <- normalise_seat(fs$seat) %in% normalise_seat(seats_here)
    p[is.na(p) & known] <- 0   # the party was never drawn winning: as unsafe as it gets
    pmax(0, 2 * p - 1)
  }
}

#' Time-forward slope of the former-leader miss on a safety measure, shrunk
#'
#' At the former-leader seats of every election before `target_election`:
#' `r_seat` as in [former_leader_bonus()] (actual minus as-at `xgb_pred_seat`,
#' less the class's median miss that election), regressed through the origin on
#' that seat's safety. The slope is shrunk toward 0 by `b^2 / (b^2 + se^2)`, the
#' rule [.role_pooled_bonus()] uses for its pooled mean. Under 3 seats with
#' positive safety, the slope is 0.
#' @param target_election Label such as `"vic2026"`.
#' @param safety As in [seat_tweak_former_leader()].
#' @param ls [leader_seats()] output.
#' @return list `slope` (shrunk), `raw`, `se`, `n`.
#' @keywords internal
former_leader_scaled_slope <- function(target_election, safety, ls = leader_seats()) {
  f <- current_seat_predictions()
  if (is.null(f)) stop("former_leader_scaled_slope needs the as-at predictions")
  f <- f[is.finite(f$xgb_pred_seat) & is.finite(f$actual_share)]
  s <- f[, list(pred = sum(xgb_pred_seat), actual = sum(actual_share)), by = list(pair = election, seat, party)]
  s$r <- s$actual - s$pred
  s[, r_seat := r - stats::median(r), by = list(pair, party)]
  prs <- unique(s$pair[elections_before(s$pair, target_election)])
  rows <- data.table::rbindlist(lapply(prs, function(e) {
    x <- former_leader_seats(e, ls)
    if (!nrow(x)) return(NULL)
    x$pair <- e
    x$x <- safety(e, x)
    x
  }), fill = TRUE)
  none <- list(slope = 0, raw = NA_real_, se = NA_real_, n = 0L)
  if (!nrow(rows)) return(none)
  rows$k <- paste(rows$pair, normalise_seat(rows$seat), rows$party)
  s$k <- paste(s$pair, normalise_seat(s$seat), s$party)
  m <- merge(s[, list(k, r_seat)], rows[, list(k, x)], by = "k")
  m <- m[is.finite(m$x)]
  if (sum(m$x > 0) < 3) return(utils::modifyList(none, list(n = nrow(m))))
  b <- sum(m$x * m$r_seat) / sum(m$x^2)
  se <- sqrt(sum((m$r_seat - b * m$x)^2) / (nrow(m) - 1) / sum(m$x^2))
  list(slope = b * b^2 / (b^2 + se^2), raw = b, se = se, n = nrow(m))
}
