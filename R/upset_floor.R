#' Upset insurance: a calibrated share of each seat's probability for minor contenders
#'
#' The seat simulation draws each class's vote from a smooth spread around its
#' prediction, so a jump from 7% to 40% never occurs and some real winners get
#' probability exactly 0: Wilkie (Denison 2010, predicted 7.2%), Oakeshott (Lyne
#' 2010), McGowan (Indi 2013), Butler (Barwon 2019, 5.5%). Seven such seat-
#' elections carried 13% of v58's total log loss, and one of them decided two
#' test verdicts on 2026-10-02.
#'
#' The remedy is a mixture: keep `1 - eps` of the simulation's probabilities and
#' give `eps` to the seat's independent and minor-party contenders predicted at
#' 2% or more, split in proportion to their predicted share. `eps` is fitted by
#' minimising log loss on EARLIER elections only ([upset_floor_fit()]); log loss
#' is a proper score, so the fit buys as much humility as the history justifies.
#' Offline on v58: 22-election log loss 0.3444 -> 0.3396, Victoria flat.
#' plans/prereg-upset-floor-2026-10-02.md.
#'
#' @name upset_floor
NULL

UPSET_MAJORS <- c("ALP", "LNP", "NAT")
UPSET_MIN_SHARE <- 2       # a contender predicted below 2% gets none of the floor
UPSET_EPS_GRID <- c(0, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2, 0.1)

#' @describeIn upset_floor Floor weights per (seat, party): minor contenders
#'   predicted at `UPSET_MIN_SHARE` or more, in proportion to predicted share.
#' @param shares data.table `seat`, `party`, `share` (predicted primary, %).
#' @export
upset_floor_weights <- function(shares) {
  s <- data.table::as.data.table(shares)
  s <- s[!(s$party %in% UPSET_MAJORS) & is.finite(s$share) & s$share >= UPSET_MIN_SHARE]
  if (!nrow(s)) return(data.table::data.table(seat = character(0), party = character(0), w = numeric(0)))
  s[, w := share / sum(share), by = seat]
  s[, .(seat, party, w)]
}

#' @describeIn upset_floor Mix win probabilities with the floor.
#' @param probs data.table `seat`, `party`, `prob`.
#' @param eps Mixing weight.
#' @return `probs` with `prob` mixed (a contender absent from `probs` is added).
#' @export
upset_floor_mix <- function(probs, shares, eps) {
  p <- data.table::copy(data.table::as.data.table(probs))
  if (!is.finite(eps) || eps <= 0) return(p)
  w <- upset_floor_weights(shares)
  seats_with_floor <- unique(w$seat)
  m <- merge(p, w, by = c("seat", "party"), all = TRUE)
  m[is.na(prob), prob := 0]
  m[is.na(w), w := 0]
  # seats with no minor contender keep their probabilities untouched
  m[seat %in% seats_with_floor, prob := (1 - eps) * prob + eps * w]
  m[, w := NULL]
  m[]
}

#' @describeIn upset_floor Fit `eps` on earlier seat-elections by log loss.
#' @param prob_actual Probability the simulation gave each seat's actual winner.
#' @param w_actual The actual winner's floor weight in that seat (0 if none).
#' @param has_floor Whether the seat had any minor contender (else unmixed).
#' @param grid Candidate values of `eps` to choose from.
#' @return The grid value minimising summed log loss (floored at 1e-6).
#' @export
upset_floor_fit <- function(prob_actual, w_actual, has_floor, grid = UPSET_EPS_GRID) {
  if (!length(prob_actual)) return(0)
  ll <- vapply(grid, function(e) {
    q <- ifelse(has_floor, (1 - e) * prob_actual + e * w_actual, prob_actual)
    sum(-log(pmax(q, 1e-6)))
  }, numeric(1))
  grid[which.min(ll)]
}
