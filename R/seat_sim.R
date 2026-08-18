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
#'   together across the state as they actually do.
#' @param seat_sd Per-seat idiosyncratic deviation, in points.
#' @param n_sims Number of simulations.
#' @param smooth Passed to the transfer step; see [distribute_preferences()].
#' @param seed Optional RNG seed.
#' @return List: `win_prob` (data.frame, one row per seat and party with a
#'   probability), `totals` (matrix of seats won per party per simulation),
#'   `fallback_rate` (share of transfers with no conditional cell).
#' @export
simulate_seat_contests <- function(shares, matrix, party_sd, seat_sd = 3.5,
                                   n_sims = 2000, smooth = 0.15, seed = NULL) {
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
  if (K > 20L) stop("More than 20 parties is not supported by the bitmask key")
  nseat <- nrow(shares)
  sd_vec <- vapply(parties, function(p) {
    v <- party_sd[[p]]; if (is.null(v) || !is.finite(v)) 0 else v
  }, numeric(1))

  # Flow lookup, keyed by from-index and survivor bitmask.
  pidx <- stats::setNames(seq_len(K), parties)
  cells <- new.env(parent = emptyenv())
  put <- function(k, v) assign(as.character(k), v, envir = cells)
  for (nm in names(matrix$conditional)) {
    bits <- strsplit(nm, "|", fixed = TRUE)[[1]]
    from <- pidx[[bits[1]]]
    if (is.null(from) || is.na(from)) next
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
  n_tx <- 0L; n_fb <- 0L

  for (s in seq_len(n_sims)) {
    shift <- stats::rnorm(K, 0, sd_vec)
    for (i in seq_len(nseat)) {
      v <- shares[i, ] + shift + stats::rnorm(K, 0, seat_sd)
      v[v < 0] <- 0
      alive <- which(v > 0)
      while (length(alive) > 2L) {
        from <- alive[which.min(v[alive])]
        pot <- v[from]
        alive <- alive[alive != from]
        mask <- sum(bitwShiftL(1L, alive - 1L))
        key <- as.character(from * 2^K + mask)
        row <- if (exists(key, envir = cells, inherits = FALSE)) {
          get(key, envir = cells, inherits = FALSE)
        } else {
          n_fb <- n_fb + 1L
          pool[[from]]
        }
        n_tx <- n_tx + 1L
        w <- row[alive]; tot <- sum(w)
        u <- 1 / length(alive)
        p <- if (tot <= 0) rep(u, length(alive)) else (1 - smooth) * (w / tot) + smooth * u
        v[alive] <- v[alive] + pot * p
        v[from] <- 0
      }
      w <- alive[which.max(v[alive])]
      wins[i, w] <- wins[i, w] + 1L
      totals[s, w] <- totals[s, w] + 1L
    }
  }

  wp <- expand.grid(seat = seat_names, party = parties,
                    stringsAsFactors = FALSE)
  wp$prob <- as.vector(wins) / n_sims
  list(win_prob = wp[wp$prob > 0, ],
       totals = totals,
       fallback_rate = if (n_tx) n_fb / n_tx else NA_real_)
}
