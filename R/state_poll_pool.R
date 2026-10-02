#' Shift a federal election's seats by how their STATE's seat polls run
#'
#' One seat poll is noisy (the blend trusts it 0.32), but every seat poll in a
#' state missing our prediction the same way is a state movement, and it
#' reaches unpolled seats too. Measured 2026-10-02 over 34 state-years
#' (fed2019-fed2025, >=2 polled seats): relative to each election's own
#' average, the polled seats' mean gap predicts the state's mean actual error
#' with correlation 0.675, slope 1.16 (0.91-1.35 leaving each election out).
#' Tasmania 2025: polls said Labor +4.5 relative, actual +7.2 (Braddon, Lyons).
#' plans/prereg-state-poll-pool-2026-10-02.md.
#'
#' Applied BEFORE the seat-poll blend, so the blend pulls a polled seat only
#' the remaining way to its own polls. Federal only: a state election has one
#' state, so the relative signal is zero by construction.
#'
#' Slope `b` per class, time-forward: earlier federal elections' state-years,
#' predictions from [current_seat_predictions()] (as the blend's weight),
#' least squares through the origin, SE over state-years, shrunk
#' `b * b^2 / (b^2 + se^2)` and clamped to [0, 1].
#'
#' @param shares Seat-by-class matrix of primaries (rows sum to 100).
#' @param target_election Label such as `"fed2025"`.
#' @param classes Classes shifted.
#' @return `shares`, shifted and renormalised.
#' @export
state_poll_pool_apply <- function(shares, target_election, classes = c("ALP", "LNP")) {
  if (!identical(Sys.getenv("AUSPOL_STATE_POLL_POOL", "0"), "1")) return(shares)
  if (!grepl("^fed", target_election)) return(shares)
  st_map <- .spp_states(target_election)
  if (is.null(st_map)) { cat("SPP! no seat-state map; state poll pool SKIPPED\n"); return(shares) }
  our <- data.table::data.table(seat = rep(rownames(shares), ncol(shares)),
                                class = rep(colnames(shares), each = nrow(shares)),
                                pred = as.vector(shares))
  sig <- .spp_signal(target_election, our, st_map)
  if (is.null(sig) || !nrow(sig)) { cat(sprintf("SPP  %s: no state with 2+ polled seats; no shift\n", target_election)); return(shares) }
  seat_state <- st_map$state[match(normalise_seat(rownames(shares)), st_map$k)]
  tot <- rowSums(shares); applied <- character(0)
  for (cl in intersect(classes, colnames(shares))) {
    b <- state_poll_pool_slope(target_election, cl)
    sc <- sig[sig$class == cl]
    if (!nrow(sc) || b$b <= 0) { applied <- c(applied, sprintf("%s b=0 (raw %s, %d state-years)", cl, format(round(b$raw, 3)), b$n)); next }
    x <- sc$pd[match(seat_state, sc$state)]; x[!is.finite(x)] <- 0
    has <- shares[, cl] > 0
    shares[has, cl] <- pmax(0, shares[has, cl] + b$b * x[has])
    applied <- c(applied, sprintf("%s b=%.3f (raw %.3f, se %.3f, %d state-years in %d elections) | %s", cl, b$b, b$raw, b$se, b$n, b$k,
                                  paste(sprintf("%s %+.2f", sc$state, sc$pd), collapse = " ")))
  }
  rs <- rowSums(shares); k <- rs > 0
  shares[k, ] <- shares[k, ] * (tot[k] / rs[k])
  cat(sprintf("SPP  %s state poll pool: %s\n", target_election, paste(applied, collapse = " || ")))
  shares
}

# seat -> state for one federal election (output/state-deviation-features.csv)
.spp_states <- function(el) {
  f <- out_path("state-deviation-features.csv")
  if (!file.exists(f)) return(NULL)
  d <- data.table::fread(f, showProgress = FALSE)
  .el <- el
  d <- unique(d[d$pair == .el & nzchar(d$state), c("seat", "state")])
  if (!nrow(d)) return(NULL)
  d$k <- normalise_seat(d$seat)
  d
}

# per (state, class): mean(poll - pred) over polled seats (>= 2), minus the
# election-wide mean of that, weighted by each state's seat count
.spp_signal <- function(el, our, st_map, actual = NULL) {
  sp <- .seat_poll_cells(el, data.table::data.table(seat = our$seat, class = our$class, share = our$pred))
  if (!nrow(sp)) return(NULL)
  sp$k <- normalise_seat(sp$seat)
  our$k <- normalise_seat(our$seat)
  m <- merge(sp[, c("k", "class", "poll")], our[, c("k", "class", "pred")], by = c("k", "class"))
  m <- m[is.finite(m$pred) & m$pred > 0]
  m$state <- st_map$state[match(m$k, st_map$k)]
  m <- m[!is.na(m$state)]
  if (!nrow(m)) return(NULL)
  s <- m[, list(pe = mean(poll - pred), n_polled = .N), by = c("state", "class")]
  s <- s[s$n_polled >= 2]
  if (!nrow(s)) return(NULL)
  ns <- st_map[, list(n_seats = .N), by = "state"]
  s <- merge(s, ns, by = "state")
  s[, pd := pe - stats::weighted.mean(pe, n_seats), by = "class"]
  if (!is.null(actual)) {
    a <- merge(our, actual, by = c("k", "class"))
    a$state <- st_map$state[match(a$k, st_map$k)]
    a <- a[!is.na(a$state) & is.finite(a$actual)]
    ae <- a[, list(ae = mean(actual - pred), n_all = .N), by = c("state", "class")]
    ae[, ad := ae - stats::weighted.mean(ae, n_all), by = "class"]
    s <- merge(s, ae[, c("state", "class", "ad")], by = c("state", "class"))
  }
  s
}

#' @describeIn state_poll_pool_apply The time-forward, shrunk slope for one class.
#' @param cl Class.
#' @export
state_poll_pool_slope <- function(target_election, cl) {
  f <- current_seat_predictions()
  none <- list(b = 0, raw = NA_real_, se = NA_real_, n = 0L, k = 0L)
  if (is.null(f)) return(none)
  els <- unique(f$election[grepl("^fed", f$election)])
  els <- els[elections_before(els, target_election)]
  rows <- data.table::rbindlist(lapply(els, function(e) {
    st_map <- .spp_states(e)
    if (is.null(st_map)) return(NULL)
    fe <- f[f$election == e]
    our <- data.table::data.table(seat = fe$seat, class = fe$party, pred = fe$xgb_pred_seat)
    act <- data.table::data.table(k = normalise_seat(fe$seat), class = fe$party, actual = fe$actual_share)
    s <- .spp_signal(e, our, st_map, actual = act)
    if (is.null(s)) return(NULL)
    s$el <- e
    s
  }), fill = TRUE)
  .cl <- cl
  if (!nrow(rows)) return(none)
  rows <- rows[rows$class == .cl & is.finite(rows$pd) & is.finite(rows$ad)]
  if (nrow(rows) < 3 || sum(rows$pd^2) == 0) return(utils::modifyList(none, list(n = nrow(rows))))
  b <- sum(rows$pd * rows$ad) / sum(rows$pd^2)
  e <- rows$ad - b * rows$pd
  # SE over state-years (each row its own cluster): with only one or two
  # earlier polled elections, clustering on election is degenerate (one
  # cluster gives se 0 at the least-squares optimum, i.e. no shrinkage)
  n <- nrow(rows)
  se2 <- sum((rows$pd * e)^2) / sum(rows$pd^2)^2 * n / max(1, n - 1)
  list(b = min(1, max(0, b * b^2 / (b^2 + se2))), raw = b, se = sqrt(se2), n = n, k = length(unique(rows$el)))
}
