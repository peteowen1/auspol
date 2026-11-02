# Company lean against RESULTS, learned from earlier elections (arm REC of
# docs/plans/prereg-poll-lean-2026-11-02.md; Pete, 1 Nov: "we 100% should be treating
# different polls differently based on the poll type and company and how old it is").
#
# The published trend already fits a house effect per firm per party, but WITHIN the
# cycle, centred by a soft sum-to-zero: a company is measured against the other
# companies polling now. This file measures it against what actually happened at
# earlier elections, on the logit scale the trend fits on, and shrinks each estimate
# to zero by how well it is measured (CLAUDE.md shrinkage rule; no n floor).
#
# Not wired into trend_as_at(): the screen (scripts/screen_poll_lean_rec.R) applies it to
# the polls before fitting. It reaches the published forecast only if it passes.

POLL_LEAN_PARTIES <- c("ALP", "LNP", "GRN", "ONP", "OTH")   # prereg arm REC, per party class

#' Every past poll's logit deviation from the result, beyond the miss all firms shared
#'
#' For each completed election and each poll in its cycle, per party in
#' `POLL_LEAN_PARTIES`: `e = logit(poll) - logit(result)`, minus the recency-weighted
#' mean `e` over every poll of that election and party, so a miss every company made
#' (2019's Labor overstatement) is not one company's lean. Recency weight
#' `0.5^(days before polling day / POLL_RECORD_HALFLIFE)`, as [poll_error_table()].
#' @param regions Poll files to read.
#' @return data.table `region`, `year`, `election` (polling day), `firm`, `party`,
#'   `d` (logit deviation beyond the shared miss), `rec` (recency weight).
#' @export
poll_lean_errors <- function(regions = c("fed", "vic", "nsw", "qld", "wa", "sa")) {
  key <- paste("lean", paste(sort(regions), collapse = ","))
  if (!is.null(.poll_record_cache[[key]])) return(.poll_record_cache[[key]])
  cycles <- load_election_cycles()
  ev <- load_eventual_results()
  out <- list()
  for (rg in regions) {
    if (!file.exists(anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE))) next
    pl <- suppressMessages(load_polls(rg))
    cy <- cycles[cycles$region == rg]
    for (k in seq_len(nrow(cy))) {
      el_end <- cy$end[k]; el_year <- cy$year[k]
      inn <- which(pl$date > cy$start[k] & pl$date <= el_end)
      if (!length(inn)) next
      for (p in intersect(POLL_LEAN_PARTIES, names(pl))) {
        hit <- which(ev$region == rg & ev$year == el_year & ev$party == p)
        if (!length(hit)) next
        act <- ev$actual[hit[1]]
        if (!is.finite(act) || act <= 0) next
        y <- pl[[p]][inn]
        ok <- is.finite(y) & y > 0
        if (sum(ok) < 2L) next
        e <- to_link(y[ok], "logit")$z - to_link(act, "logit")$z
        rec <- 0.5^(as.numeric(el_end - pl$date[inn][ok]) / POLL_RECORD_HALFLIFE)
        out[[length(out) + 1L]] <- data.table::data.table(
          region = rg, year = el_year, election = el_end, firm = pl$firm[inn][ok],
          party = p, d = e - sum(rec * e) / sum(rec), rec = rec)
      }
    }
  }
  tab <- data.table::rbindlist(out)
  .poll_record_cache[[key]] <- tab
  tab
}

#' Each company's lean per party from elections held before `as_of`, shrunk to zero
#'
#' One observation per (firm, election, party): the recency-weighted mean of `d`
#' ([poll_lean_errors()]). A firm's lean is the mean over its elections; its standard
#' error is `sqrt(s2 / k)`, with `s2` the pooled variance of firm-election means around
#' their firm's mean (pooled because most firms have one or two elections) and `k` the
#' firm's number of elections. Then DerSimonian-Laird `tau^2` across firms and
#' `shrunk = w * est`, `w = tau^2 / (tau^2 + se^2)`, toward ZERO (no lean), never toward
#' the pooled mean: the shared miss is already removed, so the pooled lean is zero by
#' construction.
#' @param as_of Date; only elections with polling day strictly before it are used.
#' @param errors From [poll_lean_errors()].
#' @return data.table `firm`, `party`, `k`, `est`, `se`, `tau2`, `w`, `lean` (logit;
#'   subtract it from a poll's logit share). Attribute `n_elections`.
#' @export
poll_lean_table <- function(as_of, errors = poll_lean_errors()) {
  as_of_d <- as.Date(as_of)
  used <- errors[errors$election < as_of_d]
  empty <- data.table::data.table(firm = character(0), party = character(0), k = integer(0), est = numeric(0),
                                  se = numeric(0), tau2 = numeric(0), w = numeric(0), lean = numeric(0))
  if (!nrow(used)) return(structure(empty, n_elections = 0L))
  # An election on or after as_of would be the result being forecast leaking in.
  stopifnot(all(used$election < as_of_d))
  fe <- used[, list(m = sum(rec * d) / sum(rec)), by = c("firm", "region", "year", "party")]
  out <- data.table::rbindlist(lapply(unique(fe$party), function(pp) {
    x <- fe[fe$party == pp]
    by_f <- x[, list(k = .N, est = mean(m)), by = "firm"]
    dev <- x$m - by_f$est[match(x$firm, by_f$firm)]
    df <- nrow(x) - nrow(by_f)
    s2 <- if (df >= 1L) sum(dev^2) / df else stats::var(x$m)
    if (!is.finite(s2) || s2 <= 0) s2 <- stats::var(x$m)
    if (!is.finite(s2) || s2 <= 0) return(NULL)
    se <- sqrt(s2 / by_f$k)
    tau2 <- 0
    if (nrow(by_f) >= 2L) {
      v <- 1 / se^2
      mf <- sum(v * by_f$est) / sum(v)
      Q <- sum(v * (by_f$est - mf)^2)
      den <- sum(v) - sum(v^2) / sum(v)
      if (den > 0) tau2 <- max(0, (Q - (nrow(by_f) - 1L)) / den)
    }
    w <- tau2 / (tau2 + se^2)
    data.table::data.table(firm = by_f$firm, party = pp, k = by_f$k, est = by_f$est, se = se,
                           tau2 = tau2, w = w, lean = w * by_f$est)
  }))
  if (!nrow(out)) out <- empty
  structure(out, n_elections = length(unique(paste(used$region, used$year))))
}

#' Take each company's lean out of its polls
#'
#' `poll' = from_link(logit(poll) - lean[firm, party])` for every poll and party the
#' table names; everything else is untouched. Keeps the poll table's attributes.
#' @param polls From [load_polls()].
#' @param lean From [poll_lean_table()].
#' @return The adjusted poll table, attribute `lean_applied` (polls x parties moved).
#' @export
apply_poll_lean <- function(polls, lean) {
  out <- data.table::copy(polls)
  n_moved <- 0L
  # `lean` is also a COLUMN of the table: inside `[` the bare name binds to the column, so
  # `lean[lean$party == pp]` read `<numeric column>$party` (CLAUDE.md data.table NSE, the twelfth
  # time; caught 2 Nov by its first test). Plain vectors, masks outside the brackets.
  lt_party <- lean$party; lt_firm <- lean$firm; lt_val <- lean$lean
  for (pp in intersect(unique(lt_party), names(out))) {
    is_p <- lt_party == pp
    sh <- lt_val[is_p][match(out$firm, lt_firm[is_p])]
    y <- out[[pp]]
    hit <- which(is.finite(sh) & sh != 0 & is.finite(y) & y > 0)
    if (!length(hit)) next
    y[hit] <- from_link(to_link(y[hit], "logit")$z - sh[hit], "logit")
    data.table::set(out, j = pp, value = y)
    n_moved <- n_moved + length(hit)
  }
  for (a in setdiff(names(attributes(polls)), names(attributes(out)))) data.table::setattr(out, a, attr(polls, a))
  data.table::setattr(out, "lean_applied", n_moved)
  out
}
