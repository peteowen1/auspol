# Candidate-level seat simulation --------------------------------------------
#
# [simulate_seats()] applies a statewide two-party swing to each seat's margin.
# That cannot represent a seat won by anyone other than Labor or the Coalition,
# because a two-party margin is the only thing it knows about a seat.
#
# This works from each seat's FIRST PREFERENCES instead and runs the count:
# exclude the lowest, distribute at rates from [build_flow_matrix()], repeat.
# A Green, an independent or One Nation can therefore win, and the model is
# able to be wrong about it rather than silent.
#
# Performance note. 87 seats x 20,000 simulations x roughly four exclusions is
# about seven million transfers, and doing that with named-vector lookups is
# far too slow. Parties are held as integer indices and the survivor set as a
# bitmask, so a cell lookup is one integer key into a preallocated list. This
# matters because a simulation that takes an hour stops being re-run, and a
# model nobody re-runs stops being checked.

#' Simulate every seat from first preferences
#'
#' @param shares Matrix or data.frame, one row per seat, one column per party,
#'   holding each seat's CENTRAL projected first-preference share. Row names
#'   (or a `seat` column) name the seats.
#' @param matrix From [build_flow_matrix()].
#' @param party_sd Named numeric: statewide uncertainty per party, in points.
#'   Applied once per simulation and shared by every seat, so parties move
#'   together across the state as they actually do. Ignored when
#'   `statewide_draws` is supplied.
#' @param statewide_draws Optional `n_sims` x parties matrix of statewide
#'   shares, one row per simulation. Supply this when the statewide
#'   distribution is already known and calibrated — drawing each party
#'   independently here and renormalising destroys the Labor-versus-Coalition
#'   covariance, which measured at **60% of the projection's own two-party
#'   spread** and made the seat range roughly 40% too tight.
#' @param party_draws Optional named list of `n_sims` x `nseat` matrices,
#'   one per party, replacing that party's BASE seat share on each draw.
#'   For a party whose seat shares are allocated rather than measured, the
#'   uncertainty is in WHICH seat gets which share, not in the shares
#'   themselves -- so each row should carry the same multiset of values in
#'   a different order. Adding independent noise to each share instead is
#'   a one-way ratchet for a party that is behind in most seats: upside
#'   crosses the winning threshold, downside costs nothing where it was
#'   already losing. Measured at 71 seats up against 1 down; see
#'   docs/reviews/onp-seat-uncertainty-2026-08-19.md.
#' @param seat_sd Per-seat idiosyncratic deviation, in points. A single number
#'   applies to every party; a named vector gives each party its own, which
#'   matters when one party's seat share is ALLOCATED rather than measured. One
#'   Nation polled 0.22% in Victoria in 2022, so its seat shares are constructed
#'   by ordering on Greens share and quantile-mapping onto South Australia --
#'   an estimate with a measured RMSE of 5.0 points against SA's actual result,
#'   against 3.5 for a party projected from its own prior seat vote. Giving both
#'   the same figure claims the constructed number is as reliable as the
#'   measured one. See docs/plans/prereg-onp-seat-uncertainty.md.
#' @param n_sims Number of simulations.
#' @param shrink Probability that a simulated seat is decided by a coin toss
#'   between its final two rather than by the count. Zero reproduces the
#'   previous behaviour exactly. May be a single number applied to every seat,
#'   or ONE VALUE PER SEAT -- either in seat order, or named by seat, in which
#'   case it is matched by name and a missing seat is an error rather than a
#'   silent recycle.
#'
#'   PREFER THE PER-SEAT FORM. A scalar caps every seat at `1 - shrink/2`:
#'   at 0.10 the highest probability the model can emit is 0.9598, and on the
#'   federal corpus no seat sits above 0.99 where the unshrunk model had 529.
#'   The risk that cap absorbs is not spread evenly. Eight of the nine federal
#'   misses above `pred_p` 0.9999 were a non-major taking a seat called safe for
#'   a major, and the measured non-major win rate runs from 0.0% where the best
#'   non-major polled under 5% last time to 77.8% where it polled over 30%. So a
#'   flat rate charges 672 low-risk seats for a risk carried by a few dozen.
#'   See `scripts/fit_insurgency_risk.R`.
#'
#'   THIS IS A CALIBRATION FIX, NOT A MODELLING FLOURISH. Scored on 1,187 seats
#'   across 10 elections, this model's calibration slope was below 1 in nine of
#'   them: a seat it called at 95% won about 70% of the time. A shrink of 0.10,
#'   fitted leave-one-election-out and identical in all ten folds, cuts the
#'   held-out log score by more than a post-hoc temperature on the output does
#'   (+3.36 SE), and unlike a temperature it applies PER DRAW -- so the
#'   seat-count histogram and the per-seat probabilities stay consistent with
#'   each other, which was the condition blocking the temperature from shipping.
#'
#'   It works mainly by putting a floor under catastrophic misses. A seat given
#'   a near-zero probability that is then won costs log(0.05) rather than
#'   log(0.016), and the log score is dominated by exactly those seats.
#'   See docs/reviews/calibration-2026-08-21.md.
#' @param party_cor Optional correlation matrix between parties' statewide
#'   deviations, with parties as dimnames and a unit diagonal. NULL draws them
#'   independently, which is what this did before and is not defensible: a
#'   simulation where one party runs hot has to take those votes from someone.
#'   Estimated across ten election pairs by
#'   `scripts/estimate_statewide_cov.R`. Scale still comes from `party_sd`.
#' @param smooth Passed to the transfer step; see [distribute_preferences()].
#' @param fallback_smooth Extra blend toward uniform applied ONLY when an
#'   exclusion has no conditional cell and falls back to the pooled rate. The
#'   effective smoothing becomes `max(smooth, fallback_smooth)`.
#'
#'   A pooled rate is not a measurement of the contest in front of it, and
#'   renormalising it across the survivors treats it as one. Measured on South
#'   Australia 2026: the matrix built from federal 2025 has **no cell at all**
#'   for `ALP|LNP+ONP`, `LNP|ALP+ONP` or `GRN|LNP+ONP` -- the exact contests a
#'   One Nation surge produces -- and the pooled Labor rate sends 59.9% to
#'   independents. In a seat with no independent that mass is redistributed
#'   over whoever remains, leaving One Nation on 2.9% of Labor preferences
#'   where the election itself gave 22.1%, and 4.5% of Coalition preferences
#'   where it gave 54.0%.
#'
#'   Zero reproduces the previous behaviour exactly.
#'   See `docs/reviews/flow-matrix-is-the-defect-2026-08-25.md`.
#' @param flow_sd Per-draw standard deviation, in percentage points, applied to
#'   each transfer proportion before it is used.
#'
#'   Flows are a FORECAST quantity that this model has always treated as known:
#'   one fixed matrix applied identically in every draw, so a wrong rate yields
#'   the same wrong answer `n_sims` times and the simulation has no way to be
#'   uncertain about it. That is a direct contributor to over-confidence -- a
#'   seat can be called at 0.95 on a preference assumption carrying no error
#'   bars. The one-step-ahead error of "mean of the last five" was measured at
#'   **sd 3.65 points** over 19 observations.
#'
#'   Zero reproduces the previous behaviour exactly.
#' @param seed Optional RNG seed.
#' @return List: `win_prob` (data.frame, one row per seat and party with a
#'   probability), `totals` (matrix of seats won per party per simulation),
#'   `tcp_winner`, `tcp_runnerup` (n_sims x nseat character matrices naming
#'   the final two survivors in each draw, `NA` for a seat uncontested down to
#'   one party), `tcp_share` (n_sims x nseat, `tcp_winner`'s share of their
#'   two-candidate-preferred total), `fallback_rate` (share of transfers with
#'   no conditional cell).
#'
#'   `tcp_winner` is the COUNT winner, taken before the `shrink` coin toss
#'   below can overrule which party is credited in `wins`/`totals` for that
#'   same draw -- so when `shrink > 0` the two can legitimately disagree.
#'   That is intentional (TCP describes the simulated vote split; `shrink` is
#'   a calibration overlay on the recorded winner, not a property of the
#'   count) but matters to anyone joining TCP data against `wins`.
#' @export
simulate_seat_contests <- function(shares, matrix, party_sd, seat_sd = 3.5,
                                   n_sims = 2000, smooth = 0.15, seed = NULL,
                                   statewide_draws = NULL,
                                   party_draws = NULL, shrink = 0,
                                   party_cor = NULL, fallback_smooth = 0,
                                   flow_sd = 0) {
  # SHRINK MAY BE PER-SEAT. A scalar applies the same rate everywhere and caps
  # EVERY seat at 1 - shrink/2 -- 0.9598 at shrink = 0.10, with no seat above
  # 0.99. That absorbs one specific risk (a non-major taking a seat called safe
  # for a major, which is 8 of the 9 federal misses above pred_p 0.9999) by
  # charging it to all 886 seats, including the 672 whose measured risk is under
  # 1.5%. A vector lets each seat carry its own ceiling. Length is checked
  # against the seat count AFTER seat_names is resolved, below.
  if (!is.numeric(shrink) || anyNA(shrink) || !all(is.finite(shrink)) ||
      any(shrink < 0) || any(shrink >= 1)) {
    stop("shrink must be finite and in [0, 1); got ",
         paste(utils::head(shrink, 5), collapse = ", "))
  }
  if (length(shrink) == 0L) stop("shrink must have length >= 1")
  if (!is.finite(fallback_smooth) || fallback_smooth < 0 || fallback_smooth > 1) {
    stop("fallback_smooth must be in [0, 1]; got ", fallback_smooth)
  }
  if (!is.finite(flow_sd) || flow_sd < 0) {
    stop("flow_sd must be finite and non-negative; got ", flow_sd)
  }
  if (!is.null(seed)) set.seed(seed)
  if (is.data.frame(shares) && "seat" %in% names(shares)) {
    seat_names <- as.character(shares$seat)
    shares <- as.matrix(shares[, setdiff(names(shares), "seat"), drop = FALSE])
  } else {
    seat_names <- rownames(shares)
    shares <- as.matrix(shares)
    if (is.null(seat_names)) seat_names <- paste0("seat", seq_len(nrow(shares)))
  }
  parties <- colnames(shares)
  if (is.null(parties)) stop("shares must have party names as column names")
  K <- length(parties)

  # Resolve shrink to one value per seat. A NAMED vector is matched BY NAME,
  # never by position -- the same rule seat_sd follows two blocks below, and for
  # the same reason: an unnoticed reordering would give the wrong seat's ceiling
  # to the wrong seat and nothing in the output would show it. An unnamed vector
  # must already be in seat order and is length-checked.
  if (length(shrink) == 1L) {
    shrink <- rep(unname(shrink), length(seat_names))
  } else if (!is.null(names(shrink))) {
    miss <- setdiff(seat_names, names(shrink))
    if (length(miss))
      stop("shrink is named but has no entry for ", length(miss), " seat(s): ",
           paste(utils::head(miss, 5), collapse = ", "))
    if (anyDuplicated(names(shrink)))
      stop("shrink has duplicate seat names; cannot match unambiguously")
    shrink <- unname(shrink[seat_names])
  } else if (length(shrink) != length(seat_names)) {
    stop("shrink must be length 1, length ", length(seat_names),
         " (one per seat), or a named vector; got ", length(shrink))
  }

  # seat_sd may be one number for every party, or one per party. A named
  # vector is matched BY NAME to the share columns, never by position: the
  # two orderings have no reason to agree, and silently pairing One Nation's
  # sd with Labor's column would be undetectable in the output.
  # length == 1 AND unnamed. A named length-1 vector -- `c(ONP = 5.5)`, the
  # natural way to write "give One Nation its own and leave the rest alone" --
  # went through this branch and was broadcast to EVERY party, name discarded,
  # silently. That is the same undetectable mispairing the comment above warns
  # about, arriving through the length check instead of the ordering. There is
  # no per-party default to fall back on, so a named vector that does not cover
  # every party is refused below rather than half-applied.
  if (length(seat_sd) == 1L && is.null(names(seat_sd))) {
    seat_sd_vec <- rep(as.numeric(seat_sd), K)
  } else {
    if (is.null(names(seat_sd))) {
      stop("seat_sd has ", length(seat_sd), " values but no names; it must ",
           "be a single number or a NAMED vector of per-party sds",
           call. = FALSE)
    }
    miss <- setdiff(parties, names(seat_sd))
    if (length(miss)) {
      stop("seat_sd is missing an entry for: ", paste(miss, collapse = ", "),
           call. = FALSE)
    }
    seat_sd_vec <- as.numeric(seat_sd[parties])
  }
  if (anyNA(seat_sd_vec) || any(seat_sd_vec < 0)) {
    stop("seat_sd must be finite and non-negative", call. = FALSE)
  }
  if (K > 20L) stop("More than 20 parties is not supported by the bitmask key")
  nseat <- nrow(shares)
  sd_vec <- vapply(parties, function(p) {
    v <- party_sd[[p]]; if (is.null(v) || !is.finite(v)) 0 else v
  }, numeric(1))

  # Correlation between parties' statewide deviations. NULL keeps the previous
  # behaviour -- independent draws -- exactly.
  #
  # WHY IT IS NOT DEFENSIBLE TO LEAVE THEM INDEPENDENT. A simulation where One
  # Nation runs five points above forecast is, under independence, equally
  # likely to pair with a strong Coalition as a weak one. Votes come from
  # somewhere: measured across ten election pairs, the correlation between the
  # statewide change in One Nation's vote and the Coalition's is -0.83, against
  # -0.12 for Labor.
  #
  # It biases in a knowable direction. One Nation's winnable seats are the ones
  # it takes from the Coalition, so under independence its good simulations are
  # not systematically the Coalition's bad ones and it crosses the line less
  # often than it should.
  chol_t <- NULL
  if (!is.null(party_cor)) {
    party_cor <- as.matrix(party_cor)
    miss <- setdiff(parties, colnames(party_cor))
    if (length(miss)) {
      stop("party_cor is missing party/parties: ", paste(miss, collapse = ", "),
           call. = FALSE)
    }
    party_cor <- party_cor[parties, parties, drop = FALSE]
    if (any(abs(diag(party_cor) - 1) > 1e-8)) {
      stop("party_cor must be a CORRELATION matrix (unit diagonal); the ",
           "per-party scale comes from party_sd.", call. = FALSE)
    }
    # A correlation matrix estimated from few observations need not be positive
    # definite, and chol() would fail with a message about the leading minor
    # rather than about the statistics. Say which.
    ev <- min(eigen(party_cor, symmetric = TRUE, only.values = TRUE)$values)
    if (ev <= 1e-8) {
      stop("party_cor is not positive definite (smallest eigenvalue ",
           signif(ev, 3), "), so it does not describe any joint distribution. ",
           "With ", ncol(party_cor), " parties it needs more election pairs ",
           "than that, or more shrinkage toward the diagonal.", call. = FALSE)
    }
    chol_t <- t(chol(party_cor))
  }

  # Flow lookup, keyed by from-index and survivor bitmask.
  pidx <- stats::setNames(seq_len(K), parties)
  cells <- new.env(parent = emptyenv())
  put <- function(k, v) assign(as.character(k), v, envir = cells)
  # A MULTIPLICITY MATRIX IS NOT READABLE HERE, and must not be accepted
  # quietly. Its survivor labels carry a candidate count -- "LNP2" rather than
  # "LNP" -- and the membership test below would reject every one of them, so
  # every conditional cell would be skipped and the simulation would fall back
  # to the pooled rate for 100% of exclusions while reporting nothing.
  #
  # That is the CLAUDE.md hazard exactly: an experiment that never ran looks
  # identical to one with no effect. Wiring these keys through is the work
  # docs/plans/prereg-survivor-multiplicity.md describes, and it was refused on
  # coverage before it was done -- so until it is done, this stops.
  if (isTRUE(matrix$multiplicity)) {
    stop("This flow matrix is keyed on survivor MULTIPLICITY, which this ",
         "function cannot read: every cell would be skipped and every ",
         "exclusion would silently use the pooled rate. Rebuild with ",
         "multiplicity = FALSE, or teach this function the keys first.")
  }
  for (nm in names(matrix$conditional)) {
    bits <- strsplit(nm, "|", fixed = TRUE)[[1]]
    # SINGLE bracket. `pidx` is an atomic vector, so `pidx[["missing"]]`
    # THROWS rather than returning NULL -- the is.null() guard that was here
    # could never fire, and any historical exclusion of a party not contesting
    # the current seats killed the whole run with "subscript out of bounds".
    # The survivor side two lines down was always safe because it uses %in%.
    from <- unname(pidx[bits[1]])
    if (is.na(from)) next
    surv <- strsplit(bits[2], "+", fixed = TRUE)[[1]]
    if (!all(surv %in% parties)) next
    mask <- sum(bitwShiftL(1L, pidx[surv] - 1L))
    row <- numeric(K)
    r <- matrix$conditional[[nm]]
    keep <- intersect(names(r), parties)
    row[pidx[keep]] <- pmax(0, r[keep])
    put(from * 2^K + mask, row)
  }
  pool <- vector("list", K)
  for (p in parties) {
    r <- matrix$pooled[[p]]
    row <- numeric(K)
    if (!is.null(r)) {
      keep <- intersect(names(r), parties)
      row[pidx[keep]] <- pmax(0, r[keep])
    }
    pool[[pidx[[p]]]] <- row
  }

  totals <- base::matrix(0L, nrow = n_sims, ncol = K,
                         dimnames = list(NULL, parties))
  wins <- base::matrix(0L, nrow = nseat, ncol = K,
                       dimnames = list(seat_names, parties))
  # Seat TCP, retained rather than thrown away. `alive` holds exactly the
  # final two survivors right where this is written (or one, for a seat
  # uncontested down to a single party, which leaves all three NA here since
  # there is no split to report). AE Forecasts publishes a seat TCP MAE of
  # 3.69pp over 722 seats -- the one metric this model could not be scored on.
  tcp_winner <- base::matrix(NA_character_, nrow = n_sims, ncol = nseat,
                             dimnames = list(NULL, seat_names))
  tcp_runnerup <- base::matrix(NA_character_, nrow = n_sims, ncol = nseat,
                               dimnames = list(NULL, seat_names))
  tcp_share <- base::matrix(NA_real_, nrow = n_sims, ncol = nseat,
                            dimnames = list(NULL, seat_names))
  n_tx <- 0L; n_fb <- 0L

  if (!is.null(party_draws)) {
    if (is.null(names(party_draws))) {
      stop("party_draws must be a NAMED list, one entry per party it overrides",
           call. = FALSE)
    }
    unknown <- setdiff(names(party_draws), parties)
    if (length(unknown)) {
      stop("party_draws names a party not in shares: ",
           paste(unknown, collapse = ", "), call. = FALSE)
    }
    for (nm in names(party_draws)) {
      d <- party_draws[[nm]]
      if (!is.matrix(d) || nrow(d) != n_sims || ncol(d) != nseat) {
        stop("party_draws[['", nm, "']] must be an n_sims x nseat matrix (",
             n_sims, " x ", nseat, "), got ",
             paste(dim(as.matrix(d)), collapse = " x "), call. = FALSE)
      }
      if (anyNA(d)) {
        stop("party_draws[['", nm, "']] contains NA", call. = FALSE)
      }
    }
  }

  if (!is.null(statewide_draws)) {
    statewide_draws <- as.matrix(statewide_draws)
    if (nrow(statewide_draws) != n_sims) {
      stop("statewide_draws must have n_sims rows, got ", nrow(statewide_draws))
    }
    miss <- setdiff(parties, colnames(statewide_draws))
    if (length(miss)) {
      stop("statewide_draws is missing column(s): ", paste(miss, collapse = ", "))
    }
    statewide_draws <- statewide_draws[, parties, drop = FALSE]
    centre <- colMeans(statewide_draws)
  }

  for (s in seq_len(n_sims)) {
    shift <- if (is.null(statewide_draws)) {
      if (is.null(chol_t)) stats::rnorm(K, 0, sd_vec)
      else as.vector(chol_t %*% stats::rnorm(K)) * sd_vec
    } else {
      # Deviation of this simulation's statewide result from the central one.
      # Seat shares are already centred, so only the departure is applied.
      statewide_draws[s, ] - centre
    }
    for (i in seq_len(nseat)) {
      # Named `base_v` for readability, not for safety. An earlier version of
      # this comment claimed a local called `base` would endanger this file's
      # base::matrix() calls -- that is wrong. `pkg::name` resolves the literal
      # symbol without an environment lookup, so a local `base` cannot shadow
      # it. Kept the name, corrected the reason: a wrong rationale in a comment
      # is worse than none, because the next editor believes it.
      base_v <- shares[i, ]
      # A per-draw base share for parties whose allocation is uncertain. `shift`
      # still applies on top: the statewide level comes from the draw, this only
      # changes how that level is spread across seats.
      if (!is.null(party_draws)) {
        for (nm in names(party_draws)) base_v[[nm]] <- party_draws[[nm]][s, i]
      }
      v <- base_v + shift + stats::rnorm(K, 0, seat_sd_vec)
      v[v < 0] <- 0
      alive <- which(v > 0)
      while (length(alive) > 2L) {
        from <- alive[which.min(v[alive])]
        pot <- v[from]
        alive <- alive[alive != from]
        mask <- sum(bitwShiftL(1L, alive - 1L))
        key <- as.character(from * 2^K + mask)
        got_cell <- exists(key, envir = cells, inherits = FALSE)
        row <- if (got_cell) {
          get(key, envir = cells, inherits = FALSE)
        } else {
          n_fb <- n_fb + 1L
          pool[[from]]
        }
        n_tx <- n_tx + 1L
        w <- row[alive]; tot <- sum(w)
        u <- 1 / length(alive)
        # FALLBACK SMOOTHING. A pooled rate is not a measurement of THIS
        # contest, and renormalising it over the survivors treats it as one.
        # Measured on the SA 2026 case: the pooled ALP rate sends 59.9% to
        # independents, so in a seat with no independent that mass is
        # redistributed across whoever remains as though it described them --
        # and One Nation ends up on 2.9% of Labor preferences where the actual
        # election gave 22.1%.
        #
        # `smooth` already blends toward uniform, but at one fixed weight
        # whether the cell was measured or invented. This applies a HEAVIER
        # blend when there was no conditional cell at all. Default 0 keeps the
        # previous behaviour exactly.
        sm <- if (!got_cell) max(smooth, fallback_smooth) else smooth
        p <- if (tot <= 0) rep(u, length(alive)) else (1 - sm) * (w / tot) + sm * u
        # FLOW UNCERTAINTY, per draw. Flows are a FORECAST quantity and the
        # model has always treated them as known: one fixed matrix applied
        # identically in all n_sims draws, so a wrong rate produces the same
        # wrong answer every time and the simulation cannot be uncertain about
        # it. The one-step-ahead error of "mean of the last five" was measured
        # at sd 3.65 points. Default 0 keeps the previous behaviour exactly.
        if (flow_sd > 0 && length(alive) > 1L) {
          p <- pmax(0, p + stats::rnorm(length(p), 0, flow_sd / 100))
          ps <- sum(p)
          p <- if (ps > 0) p / ps else rep(u, length(alive))
        }
        v[alive] <- v[alive] + pot * p
        v[from] <- 0
      }
      w <- alive[which.max(v[alive])]
      # Computed from the COUNT, before the shrink coin toss below can
      # overrule which index `w` holds -- shrink is a calibration overlay on
      # the recorded winner, not a property of the simulated vote split.
      if (length(alive) == 2L) {
        tcp_winner[s, i] <- parties[w]
        tcp_runnerup[s, i] <- parties[alive[alive != w]]
        tcp_share[s, i] <- v[w] / sum(v[alive])
      }
      # The per-draw calibration shrink. `alive` holds exactly the final two at
      # this point, so tossing between them gives a marginal of
      # (1 - shrink) * p + shrink * 0.5 -- and because it happens HERE, inside
      # the draw, `totals` and `wins` move together. A temperature applied to
      # `wins` afterwards would recalibrate the per-seat probabilities and leave
      # the seat-count histogram describing a different model.
      if (shrink[i] > 0 && length(alive) > 1L && stats::runif(1) < shrink[i]) {
        w <- alive[sample.int(length(alive), 1L)]
      }
      wins[i, w] <- wins[i, w] + 1L
      totals[s, w] <- totals[s, w] + 1L
    }
  }

  wp <- expand.grid(seat = seat_names, party = parties,
                    stringsAsFactors = FALSE)
  wp$prob <- as.vector(wins) / n_sims
  list(win_prob = wp[wp$prob > 0, ],
       totals = totals,
       tcp_winner = tcp_winner,
       tcp_runnerup = tcp_runnerup,
       tcp_share = tcp_share,
       fallback_rate = if (n_tx) n_fb / n_tx else NA_real_)
}
