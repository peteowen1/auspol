#' Per-state Labor adjustment from the preceding state election
#'
#' Federal seats in one state can swing very differently from the nation, and
#' nothing in the model knows it: `level_pred` carries a single NATIONAL figure
#' and the harness distributes it uniformly. fed2022 missed Hasluck by 11.4
#' points and Tangney by 12.9 on the Labor primary because Western Australia
#' swung +7.0 to Labor while the country swung -0.8 -- a +7.8 deviation, the
#' largest in the corpus.
#'
#' OUR FEDERAL POLLS HAVE NO STATE BREAKDOWN (`poll-data-fed.csv` is 16 columns,
#' national only), so the obvious input is unavailable. This is the substitute:
#' the most recent STATE election before federal polling day, which we hold for
#' New South Wales, Victoria, Queensland, South Australia and Western Australia.
#'
#' MEASURED, `scripts/build_state_swing_prior.R`. Over 18 pair-state
#' observations the raw correlation is +0.440 (t = 1.96), which is borderline --
#' but it pools a live signal with a stale one:
#'
#' | gap to federal polling day | n | correlation |
#' |---|---|---|
#' | under 24 months | 10 | **+0.769** |
#' | over 24 months  |  8 | -0.243 |
#'
#' On the recent subset the slope is +0.231 (se 0.068, t = 3.40, R2 0.591): a
#' state swinging +10 at its own election predicts a +2.3 point federal
#' deviation there. For WA 2022 that is +5.2 predicted against +7.8 actual, or
#' 43% of the Hasluck/Tangney miss. A state election four years old predicts
#' nothing, which is why the window exists and why it is a window rather than a
#' fitted decay -- 18 observations cannot support a decay parameter.
#'
#' ZERO-SUM BY CONSTRUCTION. The harness already anchors to the correct national
#' total, so this must only REDISTRIBUTE between states, never move the national
#' figure. Adjustments are centred on the seat-weighted mean before being
#' applied, and what Labor gains in one state the Coalition gives back in the
#' same seat.
#'
#' LEAVE-ONE-PAIR-OUT. The slope is refitted for every target election with that
#' election's own observations excluded, so a pair is never scored by a
#' coefficient that saw it.
#'
#' @param pair Federal pair label, e.g. `"fed2022"`.
#' @param seat_state Named character vector: seat name -> state abbreviation.
#' @param max_gap_months Only use a state election closer than this. Default 24.
#' @return Named numeric vector, one entry per seat, of POINTS to add to Labor's
#'   primary (and subtract from the Coalition's). Zero where no state election
#'   qualifies. `NULL` if the prior file is missing.
#' @export
state_swing_adjustment <- function(pair, seat_state, max_gap_months = 24) {
  f <- Sys.getenv("AUSPOL_STATE_SWING_SRC", "output/state-swing-prior.csv")
  if (!file.exists(f)) {
    cat(sprintf("SS9! %s missing -- run scripts/build_state_swing_prior.R; AUSPOL_STATE_SWING ignored\n", f))
    return(NULL)
  }
  P <- data.table::fread(f, showProgress = FALSE)
  need <- c("pair", "state", "state_swing", "months_gap")
  if (!all(need %in% names(P))) {
    cat(sprintf("SS9! %s lacks %s -- ignored\n", f, paste(setdiff(need, names(P)), collapse = ", ")))
    return(NULL)
  }
  # NSE guard: `pair` is a column here, so the argument is copied to a
  # differently-named local before use. Tenth instance of that trap was today.
  want <- pair
  if (!"fed_dev" %in% names(P)) {
    cat("SS9! state-swing-prior.csv has no fed_dev column -- cannot fit; run the builder\n")
    return(NULL)
  }
  train <- P[P$pair != want & is.finite(P$state_swing) & is.finite(P$fed_dev) &
             is.finite(P$months_gap) & P$months_gap < max_gap_months]
  if (nrow(train) < 6) {
    cat(sprintf("SS9! only %d training observations for %s -- no adjustment applied\n",
                nrow(train), want))
    return(stats::setNames(rep(0, length(seat_state)), names(seat_state)))
  }
  fit <- stats::lm(fed_dev ~ state_swing, data = train)
  tgt <- P[P$pair == want & is.finite(P$state_swing) & is.finite(P$months_gap) &
           P$months_gap < max_gap_months]
  adj_by_state <- stats::setNames(rep(0, 0), character(0))
  if (nrow(tgt)) {
    pr <- stats::predict(fit, newdata = data.frame(state_swing = tgt$state_swing))
    adj_by_state <- stats::setNames(as.numeric(pr), tgt$state)
  }
  out <- stats::setNames(rep(0, length(seat_state)), names(seat_state))
  hit <- seat_state %in% names(adj_by_state)
  out[hit] <- adj_by_state[seat_state[hit]]
  # CENTRE IT. The national total is already anchored, so only the DIFFERENCES
  # between states are ours to set. Without this the whole country would shift
  # by the mean adjustment and the national anchor would be silently broken.
  out <- out - mean(out)
  cat(sprintf("SS9  %s: state swing prior, slope %+.3f from %d obs (target excluded) | %d of %d seats adjusted\n",
              want, stats::coef(fit)[2], nrow(train), sum(hit), length(out)))
  if (nrow(tgt)) {
    o <- order(-abs(adj_by_state))
    cat(sprintf("SS9  by state: %s\n",
                paste(sprintf("%s %+.2f", names(adj_by_state)[o],
                              adj_by_state[o] - mean(out[hit])), collapse = " ")))
  }
  out
}
