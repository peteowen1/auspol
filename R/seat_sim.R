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
#' @param level_sd Optional `c(a, b)` making the per-seat deviation depend on the
#'   LEVEL of a party's share: `sd = a + b * sqrt(p * (1 - p))`, with `p` the
#'   party's projected share in that seat. `NULL`, the default, keeps the flat
#'   `seat_sd` and is byte-identical to the previous behaviour.
#'
#'   Why it exists: a flat 3.5 points is one number for every level, and
#'   measured over 9,015 seat-party observations across 17 election pairs the
#'   real spread runs 2.3 at 2% to 5.4 at 50%. Flat is therefore too WIDE at the
#'   bottom, giving no-hopers more chance than they have, and too NARROW at the
#'   top, making the leader more certain than they are. Too narrow at high
#'   shares is overconfidence about who wins, which is what federal calibration
#'   slopes of 0.18-0.38 look like.
#'
#'   The fitted seat-level form is `1.10 + 8.67 * sqrt(p(1-p))`. That is the
#'   TOTAL residual (`1.68 + 7.85 * sqrt(p(1-p))`) with the statewide component
#'   removed in variance, because `party_sd` is added separately here and
#'   feeding the total in would count it twice.
#'
#'   It is much flatter than binomial -- `sqrt(p(1-p))` alone would predict 9.8
#'   at 50% against 6.4 observed -- because a seat's vote is not a random sample.
#'
#'   Not adopted by default: see `docs/plans/prereg-level-dependent-variance.md`.
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
#' @param surge_h Per-draw probability, in `[0, 1]`, that an insurgent
#'   non-major candidate surges in a seat. Length 1 (the same hazard
#'   everywhere), one entry per seat, or a NAMED vector matched by seat name --
#'   in which case every seat must have an entry, for the same reason `shrink`
#'   is matched by name: an unnoticed reordering would give the wrong seat's
#'   hazard to the wrong seat and nothing in the output would show it.
#'
#'   Zero reproduces the previous behaviour exactly.
#'
#'   This is a FAT TAIL, not a wider bell. Symmetric widening of `seat_sd` was
#'   measured across 1.0-2.0 and barely matters, because no plausible Gaussian
#'   flips a seat a major leads by 30 points -- yet that is exactly where the
#'   over-confidence lived. Federal seats called at 99.9% won 95.7%, and eight
#'   of the nine misses above `pred_p` 0.9999 were a non-major taking a seat
#'   called safe for a major.
#' @param surge_mu,surge_sd Mean and standard deviation, in percentage points,
#'   of the `N(surge_mu, surge_sd)` gain drawn for the surging candidate.
#'   Everyone else in the seat scales down by a common factor -- not a flat
#'   subtraction, which would drive small parties negative and silently
#'   redistribute their vote -- so the seat still sums to 100.
#'
#'   The count then decides the seat as usual, so a surge that falls short
#'   LOSES. That is why the mechanism is generative rather than an override
#'   like `shrink`, and why it imposes no ceiling. `surge_sd` must be finite
#'   and non-negative.
#' @param surge_parties Character vector naming the share columns eligible to
#'   surge. `NULL` (default) makes every column other than `ALP`, `LNP` and
#'   `NAT` eligible. Any name not among the share columns is an error rather
#'   than a silent no-op.
#' @param surge_floor Minimum share, in percentage points, a candidate must
#'   already hold in the seat before it can surge there. Stops the mechanism
#'   handing a double-digit gain to a party polling near zero in that seat.
#' @param level_mult Optional NAMED numeric vector giving a per-party multiplier
#'   on `level_sd`'s slope `b`, so a party's width becomes
#'   `a + b * m * sqrt(p * (1 - p))`. Any party absent from the vector takes
#'   `m = 1`, so `NULL` (the default) and a vector of ones are both exactly the
#'   published model. Requires `level_sd`; passing it alone is an error rather
#'   than a silent no-op.
#'
#'   Why it exists: `level_sd` shipped ONE curve for every party, and the review
#'   that adopted it measured that the seats it fixed were not the seats it
#'   widened. On NSW the calibration slope went 0.565 to 0.720 across all seats
#'   but 0.959 to 1.272 EXCLUDING seats an independent won -- the majors were
#'   already almost perfectly calibrated and got widened past 1 anyway. The
#'   miscalibration lives in the non-major seats.
#'
#'   Matched by NAME, and a name that is not a share column is an error. An
#'   unnamed vector could reorder onto the wrong party, and a typo aimed at a
#'   party the seat file does not carry would look exactly like an arm that made
#'   no difference -- which is indistinguishable from an experiment that never
#'   ran. See `docs/plans/prereg-class-specific-variance.md`.
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
                                   level_sd = NULL,
                                   n_sims = 2000, smooth = 0.15, seed = NULL,
                                   statewide_draws = NULL,
                                   party_draws = NULL, shrink = 0,
                                   party_cor = NULL, fallback_smooth = 0,
                                   flow_sd = 0,
                                   level_mult = NULL,
                                   surge_h = 0, surge_mu = 15.6, surge_sd = 6.1,
                                   surge_parties = NULL, surge_floor = 2) {
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
  # SURGE_H MAY BE PER-SEAT, exactly as `shrink` may. `shrink` was made a vector
  # and surge_h was not, so wiring a 150-element salience hazard into it passed
  # a vector to a scalar parameter -- the same fix applied in one place and not
  # its sibling, inside one function.
  if (!is.numeric(surge_h) || anyNA(surge_h) || !all(is.finite(surge_h)) ||
      any(surge_h < 0) || any(surge_h > 1)) {
    stop("surge_h must be finite and in [0, 1]; got ",
         paste(utils::head(surge_h, 5), collapse = ", "))
  }
  if (length(surge_h) == 0L) stop("surge_h must have length >= 1")
  if (!is.finite(surge_mu) || !is.finite(surge_sd) || surge_sd < 0) {
    stop("surge_mu must be finite and surge_sd finite and non-negative")
  }
  if (!is.finite(surge_floor) || surge_floor < 0) {
    stop("surge_floor must be finite and non-negative; got ", surge_floor)
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

  # Resolve surge_h to one value per seat, by NAME where named -- the same rule
  # and the same reason as `shrink` above: an unnoticed reordering would give
  # the wrong seat's hazard to the wrong seat and nothing in the output would
  # show it.
  .fix_surge <- function(sh, seat_names) {
    if (length(sh) == 1L) return(rep(unname(sh), length(seat_names)))
    if (!is.null(names(sh))) {
      miss <- setdiff(seat_names, names(sh))
      if (length(miss))
        stop("surge_h is named but has no entry for ", length(miss), " seat(s): ",
             paste(utils::head(miss, 5), collapse = ", "))
      if (anyDuplicated(names(sh)))
        stop("surge_h has duplicate seat names; cannot match unambiguously")
      return(unname(sh[seat_names]))
    }
    if (length(sh) != length(seat_names))
      stop("surge_h must be length 1, length ", length(seat_names),
           " (one per seat), or a named vector; got ", length(sh))
    unname(sh)
  }

  # Which columns may surge. Named parties are matched BY NAME against the share
  # columns; NULL means "every party that is not a major", which is the shape
  # the federal measurement was made on. A name that is not a share column is an
  # error rather than a silent no-op -- a typo'd "IND " would otherwise turn the
  # whole mechanism off and the run would look like the surge simply did not
  # matter, which is the failure mode CLAUDE.md records for experiments that
  # never ran.
  surge_idx <- if (all(surge_h <= 0)) integer(0) else if (is.null(surge_parties)) {
    which(!parties %in% c("ALP", "LNP", "NAT"))
  } else {
    miss <- setdiff(surge_parties, parties)
    if (length(miss))
      stop("surge_parties not among the share columns: ",
           paste(miss, collapse = ", "))
    which(parties %in% surge_parties)
  }
  if (any(surge_h > 0) && !length(surge_idx))
    stop("surge_h > 0 but no eligible surge party among: ",
         paste(parties, collapse = ", "))

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

  # Resolve the surge hazard to one value per seat, by the same rule.
  surge_h <- .fix_surge(surge_h, seat_names)

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
  if (!is.null(level_sd)) {
    if (length(level_sd) != 2L || !all(is.finite(level_sd)) || any(level_sd < 0)) {
      stop("level_sd must be c(a, b), both finite and non-negative", call. = FALSE)
    }
    level_sd <- as.numeric(level_sd)
  }
  # PER-CLASS SLOPE MULTIPLIER. Resolved to one number per party HERE, once,
  # rather than inside the draw loop: the loop runs n_sims x nseat times and a
  # name lookup in there would be the whole cost of the feature.
  #
  # Matched BY NAME and defaulting to 1 for any party absent, which is what
  # makes the no-op exact -- an unnamed or partial vector must not silently
  # reorder onto the wrong party. Same rule and same reason as `shrink` and
  # `surge_h`; see docs/plans/prereg-class-specific-variance.md.
  level_mult_vec <- rep(1, K)
  if (!is.null(level_mult)) {
    if (is.null(level_sd)) {
      stop("level_mult has no effect without level_sd; pass both or neither",
           call. = FALSE)
    }
    if (is.null(names(level_mult)) || anyDuplicated(names(level_mult))) {
      stop("level_mult must be a named vector with unique names", call. = FALSE)
    }
    if (!all(is.finite(level_mult)) || any(level_mult < 0)) {
      stop("level_mult must be finite and non-negative", call. = FALSE)
    }
    # Silence here would be the failure: a multiplier aimed at a party the seat
    # file does not carry is a typo, and it would look exactly like an arm that
    # made no difference -- the "experiment that never ran" hazard in CLAUDE.md.
    unused <- setdiff(names(level_mult), parties)
    if (length(unused)) {
      stop("level_mult names no such party: ", paste(unused, collapse = ", "),
           ". Share columns are: ", paste(parties, collapse = ", "),
           call. = FALSE)
    }
    hit <- match(parties, names(level_mult))
    level_mult_vec[!is.na(hit)] <- as.numeric(level_mult)[hit[!is.na(hit)]]
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
  #
  # DENSE path: for realistic party counts this indexes a preallocated LIST by
  # the INTEGER key itself, avoiding the string-keyed environment profiling
  # found costing ~20% of simulate_seat_contests()'s runtime -- as.character()
  # building the key, then TWO lookups (exists() then get()) for one read.
  # Every class classify_party() emits today puts K at 8; CELLS_DENSE_CAP is
  # generous well past any real dataset.
  #
  # Guarded by SIZE, not by K directly, because K is capped at 20 above and
  # 20 * 2^20 slots would be roughly 1.2GB of list overhead for an address
  # space that stays almost entirely empty -- past the cap this falls back to
  # the original environment, which is correct for any K and was always the
  # only path before this change.
  pidx <- stats::setNames(seq_len(K), parties)
  CELLS_DENSE_CAP <- 2^18  # ~262k slots, a few MB
  n_slots <- (K + 1L) * 2^K
  dense_cells <- n_slots <= CELLS_DENSE_CAP
  if (dense_cells) {
    cell_list <- vector("list", n_slots)
    put <- function(k, v) cell_list[[k + 1L]] <<- v  # 1-based
  } else {
    cells <- new.env(parent = emptyenv())
    put <- function(k, v) assign(as.character(k), v, envir = cells)
  }
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
  # AVAILABILITY-CONDITIONED FALLBACK, preferred over the pooled row when
  # build_flow_matrix() supplies it. The pooled row is diluted by every round
  # where a destination was not on the ballot to receive anything, so
  # renormalising it onto a contest that HAS that destination asserts a rate
  # measured on a different contest. Measured: LNP excluded with ALP and IND
  # surviving sends 69.9% to the independent in the real counts (39 rounds,
  # 18 seat-elections); the pooled row renormalised says 22.2%. Backwards by
  # three times, on the transfer that decides Fowler, Mayo, Clark, Indi,
  # Bean, Calwell, Franklin, Fremantle, Watson and Kennedy.
  # `pairwise` conditions each rate on rounds where that destination actually
  # survived, so renormalising over the alive set is legitimate.
  # SUPERSET BACKOFF, tried before `pairwise`. Cells matched on supersets of
  # the ALIVE set rather than on an exact survivor match: a round with
  # {ALP, GRN, IND} surviving is good evidence about a contest with
  # {ALP, IND} alive, restricted to those destinations. Recovers the true
  # rate the exact key cannot reach -- LNP with {ALP, IND} alive is 71.2% to
  # the independent here against 69.9% in the raw counts, where `pairwise`
  # gives 46.2% and the pooled row 22.2%.
  ss_cache <- new.env(parent = emptyenv())
  ss_lookup <- function(from_i, alive_i) {
    if (is.null(matrix$superset) || !length(matrix$superset)) return(NULL)
    ck <- paste0(from_i, ".", paste(alive_i, collapse = "."))
    hit <- get0(ck, envir = ss_cache, inherits = FALSE, ifnotfound = NULL)
    if (!is.null(hit)) return(if (identical(hit, NA)) NULL else hit)
    nm <- paste0(parties[[from_i]], "|",
                 paste(sort(parties[alive_i]), collapse = "+"))
    r <- matrix$superset[[nm]]
    if (is.null(r)) { assign(ck, NA, envir = ss_cache); return(NULL) }
    row <- numeric(K)
    keep <- intersect(names(r), parties)
    row[pidx[keep]] <- pmax(0, r[keep])
    if (sum(row) <= 0) { assign(ck, NA, envir = ss_cache); return(NULL) }
    assign(ck, row, envir = ss_cache)
    row
  }
  pool_pw <- NULL
  if (!is.null(matrix$pairwise) && length(matrix$pairwise)) {
    pool_pw <- vector("list", K)
    for (p in parties) {
      r <- matrix$pairwise[[p]]
      row <- numeric(K)
      if (!is.null(r)) {
        keep <- intersect(names(r), parties)
        row[pidx[keep]] <- pmax(0, r[keep])
      }
      pool_pw[[pidx[[p]]]] <- if (sum(row) > 0) row else pool[[pidx[[p]]]]
    }
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
      # Names dropped HERE, after the by-name substitution above is done with
      # them and before anything downstream (`pp`, `sd_cell`, `v`, ...) uses
      # base_v purely positionally. Profiling found mostattributes<- costing
      # real time in pmin()/pmax() on a NAMED vector, because R re-copies the
      # names attribute through every arithmetic step that follows. Nothing
      # below indexes by party name -- all of it is positional, matched to
      # `parties`/`pidx` at the top of the function.
      base_v <- unname(base_v)
      # PER-CELL sd when level_sd is given: a party at 2% and one at 50% do not
      # deviate by the same number of points. `base_v` is this draw's projected
      # share, so the width tracks the level actually being simulated rather
      # than a fixed prior. NULL keeps seat_sd_vec exactly.
      sd_cell <- if (is.null(level_sd)) seat_sd_vec else {
        pp <- pmin(pmax(base_v, 0), 100) / 100
        level_sd[1L] + level_sd[2L] * level_mult_vec * sqrt(pp * (1 - pp))
      }
      v <- base_v + shift + stats::rnorm(K, 0, sd_cell)
      v[v < 0] <- 0
      # INSURGENCY SURGE. A fat tail, not a wider bell. Symmetric widening of
      # seat_sd was measured across 1.0-2.0 and "barely matters" -- no plausible
      # Gaussian flips a seat a major leads by 30 points, yet that is exactly
      # where the over-confidence lived (federal seats called at 99.9% won
      # 95.7%). Eight of the nine misses above pred_p 0.9999 were a non-major
      # taking a seat called safe for a major.
      #
      # So with probability surge_h the strongest eligible non-major gains
      # N(surge_mu, surge_sd), and everyone else scales down to keep the seat at
      # 100. The count then decides: a surge that falls short LOSES, which is
      # why this is generative rather than an override like `shrink`, and why it
      # imposes no ceiling.
      if (surge_h[i] > 0 && length(surge_idx)) {
        cand <- surge_idx[v[surge_idx] >= surge_floor]
        if (length(cand) && stats::runif(1) < surge_h[i]) {
          j <- cand[which.max(v[cand])]
          add <- stats::rnorm(1, surge_mu, surge_sd)
          if (add > 0) {
            others <- setdiff(seq_len(K), j)
            pool_v <- sum(v[others])
            # Scale the others down by the same factor rather than subtracting a
            # flat amount: a flat subtraction would drive small parties negative
            # and silently redistribute their vote.
            if (pool_v > add) {
              v[others] <- v[others] * (pool_v - add) / pool_v
              v[j] <- v[j] + add
            }
          }
        }
      }
      alive <- which(v > 0)
      while (length(alive) > 2L) {
        from <- alive[which.min(v[alive])]
        pot <- v[from]
        alive <- alive[alive != from]
        mask <- sum(bitwShiftL(1L, alive - 1L))
        key <- from * 2^K + mask
        row <- if (dense_cells) cell_list[[key + 1L]] else
          get0(as.character(key), envir = cells, inherits = FALSE, ifnotfound = NULL)
        got_cell <- !is.null(row)
        row <- if (got_cell) {
          row
        } else {
          n_fb <- n_fb + 1L
          ssr <- ss_lookup(from, alive)
          if (!is.null(ssr)) ssr
          else if (!is.null(pool_pw)) pool_pw[[from]] else pool[[from]]
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

#' Per-class slope multipliers for [simulate_seat_contests()]
#'
#' Builds the named vector `level_mult` expects, for exactly the parties a seat
#' file carries, from two numbers: one for independents and one for every other
#' non-major. Majors always take 1.
#'
#' Exists so the class definition lives in ONE place. Six callers need it --
#' `fit_seats_full.R` and the five candidate backtest harnesses -- and
#' `CLAUDE.md` records that a parameter wired into four harnesses and missed in
#' the fifth produced numbers that were read as findings for four days. A
#' hand-written class list in six files is six chances to disagree.
#'
#' @param parties Character vector of the share columns, i.e. `colnames(shares)`.
#' @param m_ind Slope multiplier for `IND`.
#' @param m_oth Slope multiplier for every non-major that is not `IND` -- `GRN`,
#'   `ONP`, `OTH`, `OTH_RIGHT` and anything else `classify_party()` emits.
#' @return A named numeric vector over `parties`, or `NULL` when both
#'   multipliers are 1, so the no-op reaches `simulate_seat_contests()` as
#'   `NULL` rather than as a vector of ones.
#' @export
level_mult_for <- function(parties, m_ind = 1, m_oth = 1) {
  if (!length(parties) || anyNA(parties)) {
    stop("parties must be a non-empty character vector", call. = FALSE)
  }
  if (!all(is.finite(c(m_ind, m_oth))) || any(c(m_ind, m_oth) < 0)) {
    stop("m_ind and m_oth must be finite and non-negative", call. = FALSE)
  }
  if (m_ind == 1 && m_oth == 1) return(NULL)
  # MAJORS ARE THE ONLY HARD-CODED LIST, and it matches the one
  # simulate_seat_contests() already uses for surge eligibility. Everything else
  # is whatever the seat file carries, so a new minor party gets m_oth without
  # anyone remembering to add it.
  out <- ifelse(parties == "IND", m_ind,
                ifelse(parties %in% c("ALP", "LNP", "NAT"), 1, m_oth))
  stats::setNames(as.numeric(out), parties)
}
