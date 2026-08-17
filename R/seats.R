# Seats -------------------------------------------------------------------
#
# A statewide two-party projection becomes a seat count by applying the swing
# to each seat's margin and simulating. Two things make that more than
# arithmetic: seats do not all swing together (the spread of seat-level
# deviations from the statewide swing is measurable and material), and a
# growing share of seats are not ALP-versus-Coalition contests at all, where a
# two-party margin does not decide the winner.
#
# This is the anchor's stage 4 reduced to its load-bearing core. Not
# implemented: regional swing structure, per-seat elasticity, candidate
# effects (retirement, sophomore surge), and modelling independent and minor
# contests properly. Non-classic seats are IDENTIFIED and held aside rather
# than silently decided by a two-party number that does not apply to them.

#' Read the anchor's authored seat configuration for one election
#'
#' Format is a flat text file: `#SeatName` then `key=value` lines.
#'
#' @param year,region Election identifiers, e.g. 2026 and "vic".
#' @return data.table: `seat`, `incumbent`, `challenger`, `seat_region`
#'   (`NA` if the block omits `sRegion`), `margin` (**ALP's** two-party margin
#'   over 50 in every seat, negative where the Coalition leads — NOT the
#'   incumbent's; see [seat_alp_tpp()] for why that distinction matters and
#'   how reading it the other way was caught), `prev_swing`, `classic` (TRUE
#'   when the contest is ALP versus Coalition).
#' @export
load_seats <- function(year, region) {
  path <- anchor_data_path(file.path("..", "..", "analysis", "seats",
                                     sprintf("%d%s.txt", year, region)))
  lines <- readLines(path, warn = FALSE)
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  starts <- which(startsWith(lines, "#"))
  if (!length(starts)) stop("No seats found in ", path)
  ends <- c(utils::tail(starts, -1) - 1L, length(lines))

  get <- function(block, key) {
    hit <- block[startsWith(block, paste0(key, "="))]
    if (!length(hit)) return(NA_character_)
    sub(paste0("^", key, "="), "", hit[1])
  }
  out <- data.table::rbindlist(lapply(seq_along(starts), function(i) {
    block <- lines[starts[i]:ends[i]]
    data.table::data.table(
      seat = sub("^#", "", block[1]),
      incumbent = get(block, "sIncumbent"),
      challenger = get(block, "sChallenger"),
      seat_region = get(block, "sRegion"),
      margin = suppressWarnings(as.numeric(get(block, "fTppMargin"))),
      prev_swing = suppressWarnings(as.numeric(get(block, "fPreviousTppSwing")))
    )
  }))
  majors <- c("ALP", "LNP", "LIB", "NAT")
  out[, classic := incumbent %in% majors & challenger %in% majors]
  out[!is.na(margin)]
}

#' ALP two-party share implied by a seat's margin
#'
#' `fTppMargin` is Labor's margin over 50 in EVERY seat, not the incumbent's —
#' which is why the column carries negative values for Coalition seats. The
#' obvious reading, flipping the sign for non-Labor incumbents, gives Labor 82
#' of 83 classic seats at zero swing against an actual 2022 result of 56 of
#' 88, which is how this was caught.
#'
#' @param seats From [load_seats()].
#' @return Numeric vector: ALP two-party percent in each seat.
#' @export
seat_alp_tpp <- function(seats) {
  50 + seats$margin
}

#' Spread of seat-level swings around the statewide swing
#'
#' Seats do not move as one, and they do not move independently either: they
#' move in regional blocks. This splits the deviation from the statewide swing
#' into a component shared within a region and a component specific to the
#' seat. Measured on Victoria, the regional share is 37% of the variance at
#' the 2022 election and 29% at 2018.
#'
#' The split matters for the seat COUNT rather than for any single seat. Total
#' per-seat variance is the same either way, but correlated deviations flip
#' neighbouring seats together, which widens the distribution of seat totals.
#' Treating them as independent understates how uncertain the result is.
#'
#' Region effects are barely persistent between elections (correlation 0.27
#' across Victoria's 13 regions), so they belong in a simulation as a random
#' block effect drawn fresh each time, not as a predictable offset.
#'
#' @param seats From [load_seats()].
#' @param statewide_swing The statewide two-party swing at that election.
#' @return List: `sd` (total), `sd_between`, `sd_within`, `mean_dev`, `n`,
#'   `region_means`.
#' @export
seat_swing_spread <- function(seats, statewide_swing) {
  d <- data.table::data.table(region = seats$seat_region,
                              dev = seats$prev_swing - statewide_swing)
  d <- d[which(is.finite(d$dev)), ]
  n <- nrow(d)
  grand <- mean(d$dev)
  by_region <- split(d$dev, d$region)
  rm <- data.table::data.table(
    region = names(by_region),
    n = vapply(by_region, length, 1L),
    m = vapply(by_region, mean, numeric(1)))
  var_between <- sum(rm$n * (rm$m - grand)^2) / n
  var_within <- sum(vapply(by_region,
                           function(v) sum((v - mean(v))^2), numeric(1))) / n
  list(sd = stats::sd(d$dev), sd_between = sqrt(var_between),
       sd_within = sqrt(var_within), mean_dev = grand, n = n,
       region_means = rm[order(-rm$n), ])
}

#' Simulate a seat count from a projected two-party vote
#'
#' Three sources of variation, in descending order of how much they move the
#' seat total: the statewide result itself, drawn from the projection's own
#' uncertainty and shifting every seat together; a regional effect shared by
#' the seats in each region; and a residual specific to each seat, which
#' decides the close ones.
#'
#' Leaving out the regional layer does not change any single seat's
#' probability much, but it makes the SEAT COUNT look more certain than it is,
#' because independent deviations average out across 83 seats while correlated
#' ones do not.
#'
#' Non-classic seats are not simulated — the model holds no two-candidate
#' margin for a contest that is not Labor against a major — so they are assumed
#' held by their incumbent. `alp_total` adds the ones Labor already holds to
#' the simulated count, and **that is the figure to publish**. `seats_won`
#' counts classic seats only and is kept for diagnostics.
#'
#' @param seats From [load_seats()].
#' @param tpp_mean,tpp_sd Projected ALP two-party share and its sd.
#' @param prev_tpp The previous election's statewide ALP two-party share, from
#'   which the swing is measured.
#' @param seat_sd Spread of seat-specific deviations — the WITHIN-region
#'   figure from [seat_swing_spread()] when `region_sd` is also supplied.
#' @param region_sd Spread of regional effects. Zero reproduces the earlier
#'   independent-seats behaviour.
#' @param n_sims Number of simulations.
#' @param seed Optional RNG seed.
#' @return List: `seats_won` (ALP classic-seat wins per simulation),
#'   `alp_total` (`seats_won` plus non-classic seats Labor holds — the
#'   publishable total), `alp_nonclassic` (that constant), `by_seat` (win
#'   probability per seat), `n_classic`, `n_nonclassic`.
#' @export
simulate_seats <- function(seats, tpp_mean, tpp_sd, prev_tpp, seat_sd,
                           region_sd = 0, n_sims = 20000, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  cl <- seats[which(seats$classic), ]
  if (!nrow(cl)) stop("No classic two-party contests to simulate")
  base <- seat_alp_tpp(cl)
  n <- nrow(cl)

  statewide <- stats::rnorm(n_sims, tpp_mean, tpp_sd) - prev_tpp
  # n_sims x n matrix of seat results
  noise <- matrix(stats::rnorm(n_sims * n, 0, seat_sd), nrow = n_sims)
  result <- matrix(base, nrow = n_sims, ncol = n, byrow = TRUE) +
    statewide + noise
  if (region_sd > 0) {
    # A seat whose block omits sRegion arrives as NA. factor() DROPS NA rather
    # than giving it a level, so reg carries an NA, max(reg) is NA, and
    # rnorm(n_sims * NA) dies with "invalid arguments" — nothing pointing at a
    # missing region field. Every shipped seat file currently labels every
    # seat, so this is dormant, but the key is otherwise optional and one
    # omission in a future redistribution would take down the whole forecast.
    if (anyNA(cl$seat_region)) {
      stop("Seats missing sRegion, needed when region_sd > 0: ",
           paste(cl$seat[is.na(cl$seat_region)], collapse = ", "))
    }
    reg <- as.integer(factor(cl$seat_region))
    n_reg <- max(reg)
    # One draw per region per simulation, expanded to that region's seats, so
    # neighbouring seats move together.
    reg_eff <- matrix(stats::rnorm(n_sims * n_reg, 0, region_sd), nrow = n_sims)
    result <- result + reg_eff[, reg, drop = FALSE]
  }
  won <- result > 50
  classic_won <- rowSums(won)

  # Added here rather than left to callers. scripts/fit_seats.R computed this
  # and scripts/build_page.R did not, so the published page would have
  # under-counted Labor by one for every non-classic seat it held. The two
  # agreed only because no non-classic seat is Labor-held in 2026 and the
  # constant happened to be zero — a divergence that could not show up until
  # the arithmetic mattered.
  alp_nonclassic <- sum(seats$incumbent == "ALP" & !seats$classic)

  list(seats_won = classic_won,
       alp_nonclassic = alp_nonclassic,
       alp_total = classic_won + alp_nonclassic,
       by_seat = data.table::data.table(
         seat = cl$seat, seat_region = cl$seat_region,
         incumbent = cl$incumbent, margin = cl$margin,
         alp_tpp_now = base, alp_win_prob = colMeans(won))[order(-alp_win_prob)],
       n_classic = n,
       n_nonclassic = sum(!seats$classic))
}
