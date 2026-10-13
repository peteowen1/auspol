# Hare-Clark party-seat forecast (Tasmania, ACT) ------------------------------
#
# A SEPARATE scored path from the single-member model: it is not in
# all_election_pairs() or any of the six candidate-seat harnesses. The question
# it answers is "how many seats in each multi-member electorate does each party
# win", with probabilities. Which candidates win inside a party is out of scope.
#
# Pipeline, per target election (scripts/backtest_hare_clark.R drives it):
#   1. statewide level the day before: hc_statewide_draws() -- the existing poll
#      machinery when polls load for the region, otherwise a LOUD fallback to the
#      previous result with a time-forward spread (never the actual result);
#   2. electorate class shares = previous electorate share + statewide swing +
#      electorate noise, SD fitted time-forward and shrunk (hc_noise_sd());
#   3. minor units (each minor party ticket, each independent) share the "OTH"
#      class by their own previous result, or a time-forward new-entrant prior;
#   4. each draw is turned into seats by a party-level Hare-Clark count,
#      hc_party_count(), with party-to-party transfer rates from the PREVIOUS
#      election's ballots (hc_flows_from_ballots()).
# Data: scripts/build_hare_clark_data.R. Review: docs/reviews/hare-clark-forecast-2026-10-13.md.

#' Scoring class of a Hare-Clark unit
#'
#' The forecast scores four classes: Labor, Liberal, Greens and everyone else.
#' Independents, minor parties and grouped independents all score as `OTH`;
#' inside the count each one is still its own unit.
#'
#' @param cls Character vector of [classify_party()] classes.
#' @return Character vector in `ALP`, `LNP`, `GRN`, `OTH`.
#' @export
hc_score_class <- function(cls) {
  ifelse(cls %in% c("ALP", "LNP", "GRN"), cls, "OTH")
}

.hc_fc <- c("ALP", "LNP", "GRN", "RGT", "IND", "OTH")

#' Transfer class of a Hare-Clark unit
#'
#' Finer than the scoring class, because where a minor ticket's preferences go
#' decides close last seats: minor-right parties (One Nation, Shooters, the
#' Liberal Democrats, Family First, the DLP; [classify_party()]'s `ONP` and
#' `OTH_RIGHT`) lean to the Liberals, independents and other minors do not. With
#' a single `OTH` transfer class the party-level count reproduced 12 of 23 ACT
#' electorate results from the actual votes.
#'
#' MEASURED, and not the default: with the six classes the count run on the
#' actual votes reproduced 44 of 61 electorate results, against 49 of 61 with
#' the four scoring classes (`fine = FALSE`); it helped the ACT (time-forward
#' flows) and hurt Tasmania, whose independents borrow the ACT independent row.
#' Kept as an arm (`--flowclass=6` in `scripts/backtest_hare_clark.R`).
#'
#' @param cls Character vector of [classify_party()] classes.
#' @param fine `TRUE` for the six transfer classes, `FALSE` (default) for the
#'   four scoring classes.
#' @return Character vector in `ALP`, `LNP`, `GRN`, `RGT`, `IND`, `OTH`
#'   (only the first three and `OTH` when `fine = FALSE`).
#' @export
hc_flow_class <- function(cls, fine = FALSE) {
  if (!fine) return(hc_score_class(cls))
  ifelse(cls %in% c("ALP", "LNP", "GRN", "IND"), cls,
         ifelse(cls %in% c("ONP", "OTH_RIGHT", "RGT"), "RGT", "OTH"))
}

#' Hare-Clark elections covered by the party-seat forecast
#'
#' Polling days for Tasmania (House of Assembly) and the ACT (Legislative
#' Assembly). Tasmanian dates are as printed on the Wikipedia results pages the
#' data come from; ACT dates are the third Saturday in October convention
#' (2016 confirmed by Elections ACT). `prev` is the election each one swings from.
#'
#' @return `data.frame` with `region`, `year`, `date`, `prev`, `seats` (members
#'   per electorate, except ACT 2008/2012 where Molonglo returned 7).
#' @export
hare_clark_elections <- function() {
  data.frame(
    region = c(rep("tas", 8), rep("act", 5)),
    year = c(2002L, 2006L, 2010L, 2014L, 2018L, 2021L, 2024L, 2025L, 2008L, 2012L, 2016L, 2020L, 2024L),
    date = as.Date(c("2002-07-20", "2006-03-18", "2010-03-20", "2014-03-15", "2018-03-03", "2021-05-01",
                     "2024-03-23", "2025-07-19", "2008-10-18", "2012-10-20", "2016-10-15", "2020-10-17",
                     "2024-10-19")),
    prev = c(NA, 2002L, 2006L, 2010L, 2014L, 2018L, 2021L, 2024L, NA, 2008L, 2012L, 2016L, 2020L),
    seats = c(rep(5L, 6), 7L, 7L, rep(5L, 5)),
    stringsAsFactors = FALSE)
}

#' Party-level Hare-Clark count
#'
#' Allocates an electorate's seats among tickets ("units") from their first
#' preference votes. Each unit is treated as a bloc: within-ticket transfers are
#' assumed to stay in the ticket, so a unit wins one seat for each full quota it
#' holds, and only what leaves a ticket -- its votes when it is excluded or has
#' elected every candidate it ran -- moves between parties, at the rates in
#' `flows`.
#'
#' Rules, in order, repeated until the seats are filled: (1) every unit at or
#' above the quota wins `floor(votes / quota)` seats (capped by candidates run
#' and seats left) and keeps the remainder; a unit with no candidates left
#' passes its remainder on; (2) if the continuing units are no more than the
#' vacancies, each is elected once, largest first; (3) otherwise the unit with
#' the fewest votes is excluded and its votes transferred. Quota is
#' `floor(total / (seats + 1)) + 1`.
#'
#' Transfers: a share `flows[from, to]` of the transferred votes goes to class
#' `to`, split among that class's continuing units by their current votes;
#' `flows[from, "EXH"]` exhausts. A destination class with no continuing unit
#' gives its share to the other destinations in proportion, so only the stated
#' exhaustion is lost -- unless no destination with a positive rate is still
#' continuing, in which case the votes exhaust.
#'
#' @param votes Numeric first-preference votes, one per unit.
#' @param seats Members to elect.
#' @param unit_class Transfer class of each unit, from [hc_flow_class()]:
#'   `ALP`, `LNP`, `GRN`, `RGT` (minor right), `IND`, `OTH`.
#' @param flows Matrix of transfer rates, rows those six classes, columns the
#'   same plus `EXH`; each row sums to 1 (see [hc_flows_from_ballots()]).
#' @param ncand Candidates each unit ran (its maximum seats); `NULL` means
#'   no cap below `seats`.
#' @param leak Optional named numeric by class: the share of a ticket's
#'   remainder that leaves it each time it wins seats and still has candidates
#'   standing (surplus votes whose next preference is outside the ticket),
#'   moved at the `flows` rates. `NULL` (default) is no leakage, the pure bloc
#'   count. Estimated from ballots by [hc_leak_from_ballots()].
#' @return Integer vector of seats won, one per unit.
#' @export
hc_party_count <- function(votes, seats, unit_class, flows, ncand = NULL, leak = NULL) {
  n <- length(votes)
  if (length(unit_class) != n) stop("hc_party_count(): unit_class must match votes")
  if (is.null(ncand)) ncand <- rep(seats, n)
  if (any(!is.finite(votes)) || any(votes < 0)) stop("hc_party_count(): votes must be finite and >= 0")
  cl <- .hc_fc
  if (!all(unit_class %in% cl)) stop("hc_party_count(): unknown unit class")
  if (!all(cl %in% rownames(flows)) || !all(c(cl, "EXH") %in% colnames(flows)))
    stop("hc_party_count(): flows needs rows ", paste(cl, collapse = "/"), " and columns plus EXH")
  lk <- stats::setNames(rep(0, length(cl)), cl)
  if (!is.null(leak)) lk[names(leak)] <- leak
  if (any(!is.finite(lk)) || any(lk < 0 | lk > 1)) stop("hc_party_count(): leak must be in [0, 1]")
  v <- as.numeric(votes)
  q <- floor(sum(v) / (seats + 1)) + 1
  won <- integer(n)
  cont <- v > 0 & ncand > 0
  left <- seats

  transfer <- function(x, amt, remove = TRUE) {
    if (remove) cont[x] <<- FALSE
    if (amt <= 0) return(invisible())
    fr <- flows[unit_class[x], cl]
    recv <- cont; recv[x] <- FALSE
    avail <- vapply(cl, function(k) any(recv & unit_class == k), logical(1))
    fr[!avail] <- 0
    if (sum(fr) <= 0) return(invisible())
    # keep the stated exhaustion; give unreachable destinations' share to the reachable ones
    fr <- fr / sum(fr) * (1 - flows[unit_class[x], "EXH"])
    for (k in cl[avail]) {
      idx <- which(recv & unit_class == k)
      w <- v[idx]; w <- if (sum(w) > 0) w / sum(w) else rep(1 / length(idx), length(idx))
      v[idx] <<- v[idx] + amt * fr[[k]] * w
    }
    invisible()
  }

  guard <- 0L
  while (left > 0L && any(cont)) {
    guard <- guard + 1L
    if (guard > 10L * (n + seats)) stop("hc_party_count(): no progress")
    over <- which(cont & v >= q)
    if (length(over)) {
      for (x in over[order(-v[over])]) {
        k <- min(floor(v[x] / q), ncand[x] - won[x], left)
        if (k <= 0) next
        won[x] <- won[x] + k; v[x] <- v[x] - k * q; left <- left - k
        if (won[x] >= ncand[x]) { amt <- v[x]; v[x] <- 0; transfer(x, amt) }
        else if (lk[[unit_class[x]]] > 0) {
          # the elected candidates' surpluses leave the ticket at the leakage rate
          amt <- lk[[unit_class[x]]] * v[x]; v[x] <- v[x] - amt; transfer(x, amt, remove = FALSE)
        }
        if (left == 0L) break
      }
      next
    }
    ci <- which(cont)
    if (length(ci) <= left) {
      # every continuing unit is elected once, largest first; any seat still left goes to the largest
      # remaining vote among units with a candidate to spare
      for (x in ci[order(-v[ci])]) {
        if (left == 0L) break
        won[x] <- won[x] + 1L; left <- left - 1L; v[x] <- v[x] - q
      }
      while (left > 0L) {
        sp <- ci[won[ci] < ncand[ci]]
        if (!length(sp)) break
        x <- sp[which.max(v[sp])]
        won[x] <- won[x] + 1L; left <- left - 1L; v[x] <- v[x] - q
      }
      cont[ci] <- FALSE
      next
    }
    x <- ci[which.min(v[ci])]
    amt <- v[x]; v[x] <- 0
    transfer(x, amt)
  }
  won
}

#' Party transfer rates from ballot-level preference data
#'
#' For each first-preference transfer class, where the ballot goes when it
#' leaves its ticket: the class of the first preference for a DIFFERENT unit, or
#' `EXH` if there is none. `IND -> IND` means another independent. Each row is
#' shrunk toward the pooled distribution of all rows (own class removed for the
#' three majors, which run one ticket per electorate) with `prior_n`
#' pseudo-ballots, so a thin row cannot produce a hard zero.
#'
#' @param flow_rows `data.frame` with `c1` (first-preference class), `c2`
#'   (destination class or `EXH`) and `n` (ballots). Classes are mapped with
#'   [hc_flow_class()].
#' @param prior_n Pseudo-ballots of shrinkage per row.
#' @param fine Six transfer classes (`TRUE`) or the four scoring classes; see
#'   [hc_flow_class()]. With `FALSE` the `RGT` and `IND` rows carry no ballots
#'   and are the pooled row (they are never used, since no unit has those classes).
#' @return 6 x 7 matrix of rates (rows sum to 1); attribute `n` = ballots per row.
#' @export
hc_flows_from_ballots <- function(flow_rows, prior_n = 50, fine = FALSE) {
  cl <- .hc_fc; to <- c(cl, "EXH")
  c1 <- hc_flow_class(flow_rows$c1, fine)
  c2 <- ifelse(flow_rows$c2 == "EXH", "EXH", hc_flow_class(flow_rows$c2, fine))
  m <- matrix(0, length(cl), length(to), dimnames = list(cl, to))
  agg <- stats::aggregate(flow_rows$n, list(c1 = c1, c2 = c2), sum)
  for (i in seq_len(nrow(agg))) m[agg$c1[i], agg$c2[i]] <- m[agg$c1[i], agg$c2[i]] + agg$x[i]
  majors <- c("ALP", "LNP", "GRN")
  for (k in majors) m[k, k] <- 0          # one major ticket per electorate: no "other unit" of its class
  nrow_n <- rowSums(m)
  pool <- colSums(m)
  out <- m
  for (k in cl) {
    p <- pool; if (k %in% majors) p[k] <- 0
    p <- if (sum(p) > 0) p / sum(p) else hc_flows_prior(0.3)[k, ]
    out[k, ] <- (m[k, ] + prior_n * p) / (nrow_n[[k]] + prior_n)
  }
  attr(out, "n") <- nrow_n
  out
}

#' Ticket leakage rates from ballot-level preference data
#'
#' Per class, the share of ballots whose SECOND preference is not for the same
#' ticket (another party, or no second preference at all): what leaves a ticket
#' when its first-preference candidate's surplus is distributed. Each class is
#' shrunk toward the pooled rate with `prior_n` pseudo-ballots.
#'
#' @param leak_rows `data.frame` with `c1`, `n`, `n_leave2`
#'   (`output/hare-clark-act-leak.csv`).
#' @param prior_n Pseudo-ballots of shrinkage.
#' @param fine See [hc_flow_class()].
#' @return Named numeric rate per transfer class ([hc_flow_class()]).
#' @export
hc_leak_from_ballots <- function(leak_rows, prior_n = 50, fine = FALSE) {
  cl <- .hc_fc
  c1 <- hc_flow_class(leak_rows$c1, fine)
  pooled <- sum(leak_rows$n_leave2) / sum(leak_rows$n)
  vapply(cl, function(k) (sum(leak_rows$n_leave2[c1 == k]) + prior_n * pooled) / (sum(leak_rows$n[c1 == k]) + prior_n),
         numeric(1))
}

#' Uninformed transfer-rate prior
#'
#' Used only as a sensitivity arm: a fixed exhaustion rate and the rest split
#' equally among the other classes.
#'
#' @param exh Exhaustion rate.
#' @return 6 x 7 matrix in the shape [hc_party_count()] takes.
#' @export
hc_flows_prior <- function(exh = 0.3) {
  cl <- .hc_fc
  m <- matrix(0, length(cl), length(cl) + 1L, dimnames = list(cl, c(cl, "EXH")))
  for (k in cl) {
    dest <- if (k %in% c("ALP", "LNP", "GRN")) setdiff(cl, k) else cl
    m[k, dest] <- (1 - exh) / length(dest)
    m[k, "EXH"] <- exh
  }
  m
}

#' Class shares per electorate and statewide
#'
#' @param units `data.frame` of units (`region`, `year`, `electorate`, `unit`,
#'   `class`, `votes`), as written by `scripts/build_hare_clark_data.R`.
#' @return List: `elec` (region, year, electorate, cls, share in percent; all
#'   four classes present, zero where absent) and `state` (region, year, cls, share).
#' @export
hc_class_shares <- function(units) {
  u <- as.data.frame(units)
  u$cls <- hc_score_class(u$class)
  key <- unique(u[, c("region", "year", "electorate")])
  full <- merge(key, data.frame(cls = c("ALP", "LNP", "GRN", "OTH")), by = NULL)
  e <- stats::aggregate(u$votes, u[, c("region", "year", "electorate", "cls")], sum)
  names(e)[5] <- "votes"
  e <- merge(full, e, all.x = TRUE)
  e$votes[is.na(e$votes)] <- 0
  tot <- stats::ave(e$votes, e$region, e$year, e$electorate, FUN = sum)
  e$share <- 100 * e$votes / tot
  s <- stats::aggregate(e$votes, e[, c("region", "year", "cls")], sum)
  names(s)[4] <- "votes"
  s$share <- 100 * s$votes / stats::ave(s$votes, s$region, s$year, FUN = sum)
  list(elec = e, state = s)
}

# consecutive same-region pairs dated strictly before `before`; ACT 2012 -> 2016 is excluded because
# the 2016 redistribution replaced 3 electorates with 5, so there is no electorate to pair
.hc_pairs_before <- function(before) {
  el <- hare_clark_elections()
  el <- el[!is.na(el$prev) & el$date < as.Date(before), ]
  el
}

.hc_shrink_sd <- function(sumsq, n, prior_sd, n0) sqrt((n0 * prior_sd^2 + sumsq) / (n0 + n))

#' Electorate-level noise SD, fitted time-forward and shrunk
#'
#' For every same-region pair of consecutive elections dated strictly before
#' `before`, the electorate's change in a class's share minus the statewide
#' change (its deviation from uniform swing). Each class's SD is shrunk toward
#' the pooled SD by `n0` pseudo-observations, and the pooled SD toward
#' `prior_sd`, so a class seen in few electorates degrades to the pool rather
#' than off a cliff. Pairs whose electorates do not match (a redistribution that
#' renamed or created electorates) contribute only the electorates present in both.
#'
#' @param units Units table (see [hc_class_shares()]).
#' @param before Date; only elections strictly earlier are used.
#' @param prior_sd Prior SD in points, used when no earlier pair exists.
#' @param n0 Pseudo-observations of shrinkage.
#' @return Named numeric SD per class with attributes `n` (deviations per class)
#'   and `pooled`.
#' @export
hc_noise_sd <- function(units, before, prior_sd = 3, n0 = 5) {
  sh <- hc_class_shares(units)
  pr <- .hc_pairs_before(before)
  devs <- list()
  for (i in seq_len(nrow(pr))) {
    rg <- pr$region[i]; yb <- pr$year[i]; ya <- pr$prev[i]
    a <- sh$elec[sh$elec$region == rg & sh$elec$year == ya, ]
    b <- sh$elec[sh$elec$region == rg & sh$elec$year == yb, ]
    sa <- sh$state[sh$state$region == rg & sh$state$year == ya, ]
    sb <- sh$state[sh$state$region == rg & sh$state$year == yb, ]
    m <- merge(a[, c("electorate", "cls", "share")], b[, c("electorate", "cls", "share")],
               by = c("electorate", "cls"), suffixes = c("_a", "_b"))
    if (!nrow(m)) next
    sw <- sb$share[match(m$cls, sb$cls)] - sa$share[match(m$cls, sa$cls)]
    devs[[length(devs) + 1L]] <- data.frame(cls = m$cls, dev = m$share_b - m$share_a - sw)
  }
  cl <- c("ALP", "LNP", "GRN", "OTH")
  if (!length(devs)) {
    out <- stats::setNames(rep(prior_sd, 4), cl)
    attr(out, "n") <- stats::setNames(integer(4), cl); attr(out, "pooled") <- prior_sd
    return(out)
  }
  d <- do.call(rbind, devs)
  pooled <- .hc_shrink_sd(sum(d$dev^2), nrow(d), prior_sd, n0)
  out <- vapply(cl, function(k) {
    x <- d$dev[d$cls == k]
    .hc_shrink_sd(sum(x^2), length(x), pooled, n0)
  }, numeric(1))
  attr(out, "n") <- vapply(cl, function(k) sum(d$cls == k), integer(1))
  attr(out, "pooled") <- pooled
  out
}

#' Statewide change SD for the previous-result fallback, fitted time-forward
#'
#' RMS of each class's statewide change between consecutive elections dated
#' before `before` (both regions pooled), shrunk toward `prior_sd`.
#'
#' @inheritParams hc_noise_sd
#' @return Named numeric SD per class, attribute `n`.
#' @export
hc_state_sd <- function(units, before, prior_sd = 5, n0 = 3) {
  sh <- hc_class_shares(units)$state
  pr <- .hc_pairs_before(before)
  cl <- c("ALP", "LNP", "GRN", "OTH")
  ch <- list()
  for (i in seq_len(nrow(pr))) {
    a <- sh[sh$region == pr$region[i] & sh$year == pr$prev[i], ]
    b <- sh[sh$region == pr$region[i] & sh$year == pr$year[i], ]
    if (!nrow(a) || !nrow(b)) next
    ch[[length(ch) + 1L]] <- data.frame(cls = cl, d = b$share[match(cl, b$cls)] - a$share[match(cl, a$cls)])
  }
  d <- if (length(ch)) do.call(rbind, ch) else data.frame(cls = character(0), d = numeric(0))
  out <- vapply(cl, function(k) { x <- d$d[d$cls == k]; .hc_shrink_sd(sum(x^2), length(x), prior_sd, n0) },
                numeric(1))
  attr(out, "n") <- vapply(cl, function(k) sum(d$cls == k), integer(1))
  out
}

#' Minor-unit priors fitted time-forward
#'
#' Two constants for splitting the `OTH` class among its units: the mean first
#' preference share of a unit that did not stand at the previous election in
#' that region (`p_new`, points), and the SD of the log ratio of a returning
#' minor unit's share to its previous share in the same electorate (`sd_log`).
#' Both from pairs dated before `before`, each shrunk toward its prior.
#'
#' @inheritParams hc_noise_sd
#' @param prior_new,prior_sdlog Priors (points; log scale).
#' @return List `p_new`, `sd_log`, `n_new`, `n_ret`.
#' @export
hc_unit_priors <- function(units, before, prior_new = 1.5, prior_sdlog = 0.5, n0 = 5) {
  u <- as.data.frame(units)
  u$cls <- hc_score_class(u$class)
  u$share <- 100 * u$votes / stats::ave(u$votes, u$region, u$year, u$electorate, FUN = sum)
  pr <- .hc_pairs_before(before)
  newv <- numeric(0); lr <- numeric(0)
  for (i in seq_len(nrow(pr))) {
    a <- u[u$region == pr$region[i] & u$year == pr$prev[i] & u$cls == "OTH", ]
    b <- u[u$region == pr$region[i] & u$year == pr$year[i] & u$cls == "OTH", ]
    newv <- c(newv, b$share[!(b$unit %in% a$unit)])
    m <- merge(a[, c("electorate", "unit", "share")], b[, c("electorate", "unit", "share")],
               by = c("electorate", "unit"))
    m <- m[m$share.x > 0 & m$share.y > 0, ]
    lr <- c(lr, log(m$share.y / m$share.x))
  }
  list(p_new = (n0 * prior_new + sum(newv)) / (n0 + length(newv)),
       sd_log = .hc_shrink_sd(sum(lr^2), length(lr), prior_sdlog, n0),
       n_new = length(newv), n_ret = length(lr))
}

#' Notional previous-election class shares for redrawn electorates
#'
#' For an election whose electorates did not exist last time (ACT 2016), shares
#' each previous-election polling place out across the target electorates in
#' proportion to the ballots it took for each of them in the target year, and
#' returns the previous election's class shares so built. Returned as a deviation
#' from the previous territory-wide booth share added to the previous
#' territory-wide share of ALL votes, so declaration votes still set the level.
#'
#' @param booths `data.frame` with `year`, `electorate`, `pollingplace`, `unit`,
#'   `votes` (`output/hare-clark-act-booths.csv`).
#' @param units Units table, for the unit classes and the territory level.
#' @param prev_year,target_year The two elections.
#' @return `data.frame` electorate, cls, share (points), plus attribute
#'   `coverage` (share of previous booth votes mapped).
#' @export
hc_notional_from_booths <- function(booths, units, prev_year, target_year) {
  b <- as.data.frame(booths); u <- as.data.frame(units)
  ua <- u[u$region == "act" & u$year == prev_year, ]
  # Every ACT polling place takes ballots for every electorate (absent votes are filed under the voter's
  # home electorate), so a place is shared out across target electorates in proportion to the ballots it
  # took for each in the target year, rather than assigned whole.
  tb <- b[b$year == target_year, ]
  tw <- stats::aggregate(tb$votes, tb[, c("pollingplace", "electorate")], sum)
  tw$w <- tw$x / stats::ave(tw$x, tw$pollingplace, FUN = sum)
  p <- b[b$year == prev_year, ]
  p$cls <- hc_score_class(ua$class[match(paste(p$electorate, p$unit), paste(ua$electorate, ua$unit))])
  if (anyNA(p$cls)) stop("hc_notional_from_booths(): booth unit not in units table")
  pc <- stats::aggregate(p$votes, p[, c("pollingplace", "cls")], sum)
  coverage <- sum(pc$x[pc$pollingplace %in% tw$pollingplace]) / sum(pc$x)
  cl <- c("ALP", "LNP", "GRN", "OTH")
  terr_booth <- vapply(cl, function(k) sum(pc$x[pc$cls == k]), numeric(1)) / sum(pc$x) * 100
  st <- hc_class_shares(u[u$region == "act" & u$year == prev_year, ])$state
  terr_all <- st$share[match(cl, st$cls)]
  m <- merge(pc, tw[, c("pollingplace", "electorate", "w")], by = "pollingplace")
  out <- do.call(rbind, lapply(sort(unique(m$electorate)), function(e) {
    x <- m[m$electorate == e, ]
    sh <- vapply(cl, function(k) sum(x$x[x$cls == k] * x$w[x$cls == k]), numeric(1)) / sum(x$x * x$w) * 100
    data.frame(electorate = e, cls = cl, share = pmax(0, terr_all + sh - terr_booth))
  }))
  attr(out, "coverage") <- coverage
  out
}

#' Statewide class-share draws for a Hare-Clark election
#'
#' Calls the existing poll machinery ([statewide_draws_as_at()], cut off the
#' day before polling day) when polls load for the region. When they do not --
#' no poll file, no cycle, no prior results, or no fittable trend -- it falls
#' back to the PREVIOUS election's statewide shares with a time-forward spread
#' ([hc_state_sd()]), and says so on the console with check code `HCS1`. The
#' fallback never sees the target election's result.
#'
#' @param region `"tas"` or `"act"`.
#' @param year Target year.
#' @param election_date Polling day.
#' @param prev_state Named numeric, previous statewide class shares (points).
#' @param state_sd Named numeric SD per class for the fallback.
#' @param n_sims Draws.
#' @param seed Optional seed.
#' @return List `draws` (n_sims x 4, rows sum to 100), `source` (`"polls"` or
#'   `"fallback: previous result"`), `n_polls`, `reason`.
#' @export
hc_statewide_draws <- function(region, year, election_date, prev_state, state_sd, n_sims = 5000L, seed = NULL) {
  cl <- c("ALP", "LNP", "GRN", "OTH")
  ed <- as.Date(election_date)
  reason <- NULL
  fc <- tryCatch({
    load_polls(region)
    statewide_draws_as_at(region, year, as_at = ed - 1, election_date = ed, parties = cl,
                          n_sims = n_sims, seed = seed)
  }, error = function(e) { reason <<- conditionMessage(e); NULL })
  if (!is.null(fc)) {
    d <- fc$draws[, cl, drop = FALSE]
    cat(sprintf("HCS1  %s%d statewide FROM POLLS: %d polls to %s (unanchored to a projection: none exists for %s)\n",
                region, year, fc$n_polls, as.character(ed - 1), region))
    return(list(draws = d, source = "polls", n_polls = fc$n_polls, reason = NA_character_))
  }
  if (is.null(reason)) reason <- "trend could not be fitted at the cutoff"
  cat(sprintf(paste0("HCS1  %s%d statewide FALLBACK -- NOT POLLS: previous election's result (%s) with ",
                     "time-forward SD (%s). Reason polls were not used: %s\n"),
              region, year, paste(sprintf("%s %.1f", cl, prev_state[cl]), collapse = ", "),
              paste(sprintf("%s %.1f", cl, state_sd[cl]), collapse = ", "), substr(reason, 1, 160)))
  if (!is.null(seed)) set.seed(seed)
  d <- sapply(cl, function(k) prev_state[[k]] + stats::rnorm(n_sims, 0, state_sd[[k]]))
  d <- pmax(d, 0.05)
  d <- d / rowSums(d) * 100
  list(draws = d, source = "fallback: previous result", n_polls = 0L, reason = reason)
}

#' Simulate party seats in every electorate of one Hare-Clark election
#'
#' @param target `data.frame` of the target election's units as NOMINATED
#'   (known before polling day): `electorate`, `unit`, `cls` (score class),
#'   `fcls` (transfer class, [hc_flow_class()]), `ncand`, `seats`. Votes are
#'   not read.
#' @param base `data.frame` electorate, cls, share: the previous (or notional)
#'   electorate class shares in points.
#' @param unit_prev `data.frame` electorate, unit, share: previous minor-unit
#'   shares in points (same electorate). Units standing elsewhere last time get
#'   their mean there; others get `unit_pri$p_new`.
#' @param state_draws n_sims x 4 matrix of statewide class shares.
#' @param prev_state Named numeric, previous statewide class shares.
#' @param noise_sd Named numeric electorate SD per class.
#' @param unit_pri List from [hc_unit_priors()].
#' @param flows Transfer matrix for [hc_party_count()].
#' @param leak Ticket leakage rates for [hc_party_count()], or `NULL`.
#' @param seed Optional seed.
#' @return `data.frame` electorate, cls, seats, prob: the forecast distribution
#'   of each class's seat count, plus attribute `draws` (per-draw seats by
#'   electorate and class, long form) for statewide totals.
#' @export
hc_simulate <- function(target, base, unit_prev, state_draws, prev_state, noise_sd, unit_pri, flows,
                        leak = NULL, seed = NULL) {
  cl <- c("ALP", "LNP", "GRN", "OTH")
  if (!is.null(seed)) set.seed(seed)
  n_sims <- nrow(state_draws)
  swing <- sweep(state_draws[, cl, drop = FALSE], 2, prev_state[cl])
  elecs <- unique(target$electorate)
  res <- list(); dr <- list()
  for (e in elecs) {
    tu <- target[target$electorate == e, ]
    seats <- tu$seats[1]
    present <- cl %in% tu$cls
    b <- base[base$electorate == e, ]
    bshare <- stats::setNames(b$share[match(cl, b$cls)], cl)
    bshare[is.na(bshare)] <- 0
    # minor units: their own previous share here, else their mean share elsewhere last time, else the
    # new-entrant prior; OTH's base is the sum over the units actually standing (nominations are known)
    oth <- which(tu$cls == "OTH")
    w <- vapply(tu$unit[oth], function(un) {
      here <- unit_prev$share[unit_prev$electorate == e & unit_prev$unit == un]
      if (length(here) == 1L && is.finite(here)) return(here)
      if (!grepl("^(IND|UNG|GRP): ", un)) {
        els <- unit_prev$share[unit_prev$unit == un]
        if (length(els)) return(mean(els))
      }
      unit_pri$p_new
    }, numeric(1))
    if (length(oth)) bshare[["OTH"]] <- sum(w)
    noise <- sapply(cl, function(k) stats::rnorm(n_sims, 0, noise_sd[[k]]))
    sh <- sweep(swing + noise, 2, bshare, `+`)
    sh <- pmax(sh, 0.05)
    sh[, !present] <- 0
    sh <- sh / rowSums(sh) * 100
    # unit votes per draw
    uv <- matrix(0, n_sims, nrow(tu))
    for (k in setdiff(cl, "OTH")) {
      j <- which(tu$cls == k)
      if (length(j) > 1L) stop("hc_simulate(): more than one ", k, " ticket in ", e)
      if (length(j)) uv[, j] <- sh[, k]
    }
    if (length(oth)) {
      lw <- matrix(log(pmax(w, 0.01)), n_sims, length(oth), byrow = TRUE) +
        matrix(stats::rnorm(n_sims * length(oth), 0, unit_pri$sd_log), n_sims)
      ww <- exp(lw); ww <- ww / rowSums(ww)
      uv[, oth] <- ww * sh[, "OTH"]
    }
    seat_mat <- matrix(0L, n_sims, 4, dimnames = list(NULL, cl))
    for (s in seq_len(n_sims)) {
      won <- hc_party_count(uv[s, ], seats, tu$fcls, flows, ncand = tu$ncand, leak = leak)
      seat_mat[s, ] <- vapply(cl, function(k) sum(won[tu$cls == k]), numeric(1))
    }
    for (k in cl) {
      tab <- tabulate(seat_mat[, k] + 1L, nbins = seats + 1L) / n_sims
      res[[length(res) + 1L]] <- data.frame(electorate = e, cls = k, seats = 0:seats, prob = tab)
    }
    dr[[e]] <- seat_mat
  }
  out <- do.call(rbind, res)
  attr(out, "draws") <- dr
  out
}

#' Log loss of a seat-count forecast
#'
#' `-log(max(p, eps))` of the probability the forecast gave each class's actual
#' seat count in each electorate. `eps = 1e-6`, the repo-wide floor.
#'
#' @param probs `data.frame` electorate, cls, seats, prob (from [hc_simulate()]).
#' @param actual `data.frame` electorate, cls, seats_won.
#' @param eps Probability floor.
#' @return `actual` with `p_actual`, `logloss`, `mode` (most likely count).
#' @export
hc_log_loss <- function(probs, actual, eps = 1e-6) {
  a <- as.data.frame(actual)
  key_p <- paste(probs$electorate, probs$cls, probs$seats)
  a$p_actual <- probs$prob[match(paste(a$electorate, a$cls, a$seats_won), key_p)]
  a$p_actual[is.na(a$p_actual)] <- 0
  a$logloss <- -log(pmax(a$p_actual, eps))
  a$mode <- vapply(seq_len(nrow(a)), function(i) {
    p <- probs[probs$electorate == a$electorate[i] & probs$cls == a$cls[i], ]
    p$seats[which.max(p$prob)]
  }, numeric(1))
  a
}

#' Naive baseline: seats as last time, with a fitted hit rate
#'
#' Point prediction = the class's seats in this electorate at the previous
#' election (scaled by largest remainder when the electorate's size changed, or
#' taken from the territory-wide seat share when the electorate is new). Given
#' probability `hit` on that count and `(1 - hit)` split over the counts one
#' either side, so it can be scored by log loss beside the model.
#'
#' @param prev_seats Named numeric, previous seats per class (or territory
#'   fractions when `new_seats` differs).
#' @param seats Seats in the target electorate.
#' @param hit Probability on the point prediction.
#' @param prev_total Seats the previous counts were out of.
#' @return `data.frame` cls, seats, prob.
#' @export
hc_naive <- function(prev_seats, seats, hit = 0.6, prev_total = sum(prev_seats)) {
  cl <- c("ALP", "LNP", "GRN", "OTH")
  ps <- stats::setNames(prev_seats[cl], cl); ps[is.na(ps)] <- 0
  q <- ps * seats / prev_total
  pt <- floor(q)
  rem <- seats - sum(pt)
  if (rem > 0) pt[order(-(q - pt))[seq_len(rem)]] <- pt[order(-(q - pt))[seq_len(rem)]] + 1
  do.call(rbind, lapply(cl, function(k) {
    p <- numeric(seats + 1L)
    p[pt[[k]] + 1L] <- hit
    nb <- c(pt[[k]] - 1L, pt[[k]] + 1L); nb <- nb[nb >= 0 & nb <= seats]
    if (length(nb)) p[nb + 1L] <- p[nb + 1L] + (1 - hit) / length(nb) else p[pt[[k]] + 1L] <- 1
    data.frame(cls = k, seats = 0:seats, prob = p)
  }))
}
