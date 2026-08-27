#' Which candidates salience permits to emerge
#'
#' The seat model cannot distinguish a new candidate who will poll 2% from one
#' who will win, because neither has a prior vote in the seat. Dai Le had 0.0%
#' and won Fowler on 29.5%. Applying an emergent's treatment to all ~300 such
#' candidates is what made conditional slopes hurt every emergence election they
#' touched.
#'
#' Salience separates them, and it does so in ONE direction only. Measured across
#' five elections after correcting the population definition: **709 governed
#' candidates were silent and none of them won**. Firing is therefore permission,
#' never a prediction — Ian Cook topped Victoria on 18.0% and lost, David Speirs
#' topped South Australia on 14.1%.
#'
#' @section The registration test:
#' A field where almost nobody registers carries no information, and treating
#' silence as evidence there would be wrong. South Australia had 7 of 111
#' candidates fire; federal elections have a third. Below `min_fire` the screen
#' returns all-permit, which reproduces the unscreened model exactly.
#'
#' @param jump Numeric campaign-salience values, one per candidate.
#' @param governed Logical: is this candidate one the screen speaks about? A
#'   sitting member is not, nor is a candidate of a class whose statewide vote
#'   surged — see [candidate_returns()] and [surging_parties()].
#' @param min_fire Minimum share of the field that must register for the screen
#'   to apply at all.
#' @return Logical vector, `TRUE` where the candidate may emerge. Ungoverned
#'   candidates are always `TRUE`: the screen makes no claim about them.
#' @export
salience_screen <- function(jump, governed, min_fire = 0.10) {
  if (length(jump) != length(governed)) {
    stop("jump and governed must be the same length: ", length(jump), " vs ",
         length(governed), call. = FALSE)
  }
  if (!length(jump)) return(logical(0))
  jump[!is.finite(jump)] <- 0
  fired <- jump > 0
  # DECIDED FROM THE FIELD, with no outcome data.
  if (mean(fired) < min_fire) return(rep(TRUE, length(jump)))
  # Silence is only evidence about candidates the screen governs.
  !governed | fired
}

#' Share of a field that registers any campaign salience
#'
#' The quantity the registration test reads. Reported separately so a run can
#' print it before any result is looked at.
#'
#' @param jump Numeric campaign-salience values.
#' @return Proportion in `[0, 1]`.
#' @export
salience_registration <- function(jump) {
  if (!length(jump)) return(0)
  jump[!is.finite(jump)] <- 0
  mean(jump > 0)
}
