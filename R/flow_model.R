# Preference flows, estimated ----------------------------------------------
#
# Where a party's preferences go is the single largest lever on a two-party
# figure when a minor party is polling well: at 20% of the vote, one point of
# assumed flow moves the two-party number by 0.2. It deserves a model, not a
# constant.
#
# Neither reference implementation does this. AE Forecasts hand-authors the
# value and borrows across regions when a state has no recent data -- its file
# literally carries `2026,vic,ONP FP,25.5,#Use federal pref flow estimate`, so
# an assumption made once sits frozen while the world moves, and the same
# borrowed number appears for three different future elections as though it
# were three estimates. theswingison uses a twelve-rule hierarchy keyed on who
# has been eliminated, with a confidence tier per rule: better than one fixed
# rate, but still hand-authored rules that no new election can update.
#
# So: estimate the flow from the elections that have actually happened, and let
# it move when the record moves.
#
# WHICH estimator was decided by a strict temporal backtest -- every election
# predicted using only elections held strictly EARLIER -- across 102 elections
# from 2004. Seven candidates, mean absolute error:
#
#   mean of last 5      4.769   <- adopted
#   last in region      4.911
#   mean of last 3      5.087
#   half trend          5.258
#   linear trend        5.348
#   carry last forward  5.726
#   last plus drift     5.915
#
# The linear trend came FIFTH. It was the obvious idea and the one this file
# was first written around: the trends are real and strong (Greens +1.10
# points a year over 53 elections, One Nation -0.605 over 21, both p < 0.001)
# and leave-one-out endorsed them. Leave-one-out was wrong, because it lets
# later elections inform an earlier prediction; under honest temporal
# validation a straight line extrapolated off the end of the record misses
# every turning point. Averaging the five most recent estimates keeps the drift
# without betting on its continuing.
#
# The winner is chosen on the POOLED backtest, not per party. Per party the
# ranking shuffles -- One Nation prefers the mean of 3, the Greens prefer last
# in region -- but those are 16 and 38 elections, and picking a different
# estimator for each party from the same backtest that measures them is how you
# fit noise and call it insight.
#
# A state-versus-federal term was tested and rejected: +1.10 points, se 1.90,
# p = 0.57, and worse out of sample. It is a plausible idea -- One Nation's
# state and council voters need not behave like its federal ones -- but six
# federal elections cannot separate it from the year trend, and shipping it
# would be shipping a hunch with a coefficient attached.

#' Elections whose result is actually known
#'
#' "Observed" must mean the election has happened, keyed off its end date. The
#' obvious `year <= this year` is identical today and silently stops being so:
#' the anchor's file carries forward projections for future elections, and a
#' year-based rule absorbs each one as the calendar rolls past it, feeding
#' assumptions back in as though they were evidence.
#'
#' @param dt data.table with `year` and `region`.
#' @param cycles From [load_election_cycles()]; loaded if missing.
#' @param as_of Date to judge against.
#' @return Logical vector.
#' @export
is_observed_election <- function(dt, cycles = NULL, as_of = Sys.Date()) {
  if (is.null(cycles)) cycles <- load_election_cycles()
  vapply(seq_len(nrow(dt)), function(i) {
    any(cycles$region == dt$region[i] & cycles$year == dt$year[i] &
        cycles$end <= as_of)
  }, logical(1))
}

#' Estimate a party's preference flow for an election that has not happened
#'
#' Averages the party's `min_n` most recent observed estimates, pooled across
#' regions. Chosen by strict temporal backtest over 102 elections, where it
#' beat a fitted trend, carry-forward and four other candidates -- see the
#' commentary at the top of this file. Pooling regions is deliberate:
#' preference behaviour moves on a national timescale and no single state has
#' enough elections to estimate it alone.
#'
#' @param flows From [load_preference_flows()].
#' @param target_party Party code. Deliberately not named `party`: that is also
#'   a column of `flows`, and data.table would bind the column instead.
#' @param year Election year to predict. Used only to report which record the
#'   estimate came from; the estimator itself does not extrapolate to it.
#' @param cycles From [load_election_cycles()]; loaded if missing.
#' @param as_of Date defining which elections count as observed.
#' @param min_n How many recent estimates to average.
#' @return List with `flow`, `se` (standard error of that mean), `n`,
#'   `n_avail`, `model`, `spread` and `years`; or `NULL` if nothing to use.
#' @export
estimate_flow <- function(flows, target_party, year, cycles = NULL,
                          as_of = Sys.Date(), min_n = 5L) {
  if (is.null(cycles)) cycles <- load_election_cycles()
  # The argument is `target_party`, NOT `party`, and the mask is built from a
  # plain vector before it goes anywhere near `[`. Written the obvious way,
  # `flows[flows$party == party, ]` has data.table bind the bare `party` to the
  # COLUMN, making it a self-comparison that is TRUE for every row: the filter
  # silently does nothing and every party is handed the pooled mean of all 202
  # estimates. That is exactly what happened here on the first run -- Greens,
  # One Nation, Others and UAP all came back 52.16 with n = 202 -- and it is
  # the third time this bug has landed in this codebase, which is why
  # flows_for() carries the same warning.
  pcol <- as.character(flows$party)
  d <- flows[which(pcol == target_party), ]
  if (!nrow(d)) return(NULL)
  d <- d[which(is_observed_election(d, cycles, as_of)), ]
  if (nrow(d) < 3L) return(NULL)

  # The five most recent estimates for this party, any region. Pooling regions
  # is deliberate: preference behaviour moves on a national timescale and no
  # single state has enough elections to estimate it alone. `k` is not tuned
  # per party -- 3 and 5 were both raced and 5 won pooled.
  d <- d[order(d$year, decreasing = TRUE), ]
  recent <- utils::head(d$flow_alp, min_n)
  if (!length(recent)) return(NULL)

  # Spread of the values being averaged, as the honest uncertainty in the
  # estimate. Not a regression standard error: there is no fitted line here,
  # and quoting one would imply a precision the method does not claim.
  se <- if (length(recent) > 1L) {
    stats::sd(recent) / sqrt(length(recent))
  } else NA_real_

  list(flow = mean(recent), se = se, n = length(recent), n_avail = nrow(d),
       model = sprintf("mean of last %d", length(recent)),
       spread = if (length(recent) > 1L) stats::sd(recent) else NA_real_,
       # Region as well as year: five bare years read as "2026, 2025, 2025,
       # 2024, 2023", where the repeats look like a mistake rather than two
       # different elections held the same year.
       years = paste(sprintf("%s %d", toupper(utils::head(d$region, min_n)),
                             utils::head(d$year, min_n)), collapse = ","))
}

#' Replace assumed flows with estimates, for an election yet to happen
#'
#' Any row whose own election has already been held is left exactly as it is —
#' that is a recorded result and the best evidence available. Only rows
#' standing in for an election that has not happened are replaced, since those
#' are assumptions whatever file they live in.
#'
#' Flows are held to `[0, 100]`, and a party with too little history keeps
#' whatever the source supplied rather than being dropped.
#'
#' @param used Flow table for the cycle, from [flows_for()].
#' @param flows The full table from [load_preference_flows()].
#' @param year,cycles,as_of As [estimate_flow()].
#' @param quiet Suppress the per-party report.
#' @return `used` with `flow_alp` replaced where estimable, plus columns
#'   `flow_source`, `flow_se` and `flow_n`.
#' @export
estimate_flows_for <- function(used, flows, year, cycles = NULL,
                               as_of = Sys.Date(), quiet = FALSE) {
  if (is.null(cycles)) cycles <- load_election_cycles()
  used <- data.table::copy(data.table::as.data.table(used))
  used[, c("flow_source", "flow_se", "flow_n") :=
         list("as supplied", NA_real_, NA_integer_)]

  # If the target election has already been held, everything here is a record
  # of what actually happened and none of it is ours to replace -- including
  # rows the source carried forward, which were the analyst's call at the time
  # and are still the only account we have. Estimation is for elections whose
  # result is not yet known.
  target_held <- any(cycles$region == used$region[1] & cycles$year == year &
                     cycles$end <= as_of)
  if (target_held) {
    used$flow_source <- "as supplied (election already held)"
    return(used[])
  }

  # For an election not yet held, EVERY flow is an assumption -- there is no
  # such thing as an observed preference flow for a vote that has not been
  # counted. A value the source authored for 2026 is a forecast; one carried
  # forward from 2018 is a forecast too. Both get estimated. (The first draft
  # of this exempted rows authored for the target year, which would have left
  # the One Nation 25.5 that started all of this exactly where it was.)
  for (i in seq_len(nrow(used))) {
    est <- estimate_flow(flows, used$party[i], year, cycles, as_of)
    if (is.null(est)) next
    old <- used$flow_alp[i]
    used$flow_alp[i] <- max(0, min(100, est$flow))
    used$flow_source[i] <- sprintf("fitted (%s, n=%d)", est$model, est$n)
    used$flow_se[i] <- est$se
    used$flow_n[i] <- est$n
    if (!quiet) {
      message(sprintf("  %s flow %s %.2f -> %.2f (%s, n=%d, se %.2f)",
                      used$party[i], "→", old, used$flow_alp[i],
                      est$model, est$n, est$se))
    }
  }
  used[]
}
