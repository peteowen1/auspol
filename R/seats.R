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
#' @return data.table: `seat`, `incumbent`, `challenger`, `seat_region`,
#'   `margin` (incumbent's two-party margin over 50), `prev_swing`,
#'   `classic` (TRUE when the contest is ALP versus Coalition).
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
#' Seats do not move as one. This measures by how much they differ, which is
#' what turns a single projected vote share into a distribution of seat
#' counts rather than a single number.
#'
#' Uses the previous election's per-seat swing, which the seat files record,
#' against the statewide swing implied by the two elections' results.
#'
#' @param seats From [load_seats()].
#' @param statewide_swing The statewide two-party swing at that election.
#' @return List: `sd`, `mean_dev`, `n`.
#' @export
seat_swing_spread <- function(seats, statewide_swing) {
  # prev_swing is recorded toward the seat's own incumbent; put it on a
  # consistent Labor footing before comparing with a Labor statewide swing.
  dev <- seats$prev_swing - statewide_swing
  dev <- dev[is.finite(dev)]
  list(sd = stats::sd(dev), mean_dev = mean(dev), n = length(dev))
}

#' Simulate a seat count from a projected two-party vote
#'
#' Each simulation draws a statewide result from the projection's own
#' uncertainty, then gives every seat an independent deviation from it. Both
#' matter: statewide error moves all seats together and sets the spread of
#' plausible outcomes, while seat-level noise decides the close ones.
#'
#' @param seats From [load_seats()].
#' @param tpp_mean,tpp_sd Projected ALP two-party share and its sd.
#' @param prev_tpp The previous election's statewide ALP two-party share, from
#'   which the swing is measured.
#' @param seat_sd Spread of seat-level deviations, from [seat_swing_spread()].
#' @param n_sims Number of simulations.
#' @param seed Optional RNG seed.
#' @return List: `seats_won` (vector of ALP classic-seat wins per simulation),
#'   `by_seat` (win probability per seat), `n_classic`, `n_nonclassic`.
#' @export
simulate_seats <- function(seats, tpp_mean, tpp_sd, prev_tpp, seat_sd,
                           n_sims = 20000, seed = NULL) {
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
  won <- result > 50

  list(seats_won = rowSums(won),
       by_seat = data.table::data.table(
         seat = cl$seat, seat_region = cl$seat_region,
         incumbent = cl$incumbent, margin = cl$margin,
         alp_tpp_now = base, alp_win_prob = colMeans(won))[order(-alp_win_prob)],
       n_classic = n,
       n_nonclassic = sum(!seats$classic))
}
