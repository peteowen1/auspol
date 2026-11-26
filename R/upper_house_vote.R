# Upper-house (Legislative Council) VOTE model: each group's first-preference share by region.
# Pre-registration: docs/plans/upper-house-vote-model-2026-11-26.md. Used by scripts/build_upper_house_forecast.R
# under AUSPOL_UPPER_HOUSE_VOTE_MODEL=1; backtest in scripts/backtest_upper_house_vote.R.
#
# Majors (ALP, LNP, GRN): upper share = lower share x ratio, ratio fitted per party and region on past Victorian
# elections, region effects partially pooled toward the statewide ratio, statewide drift (common + party part)
# and region drift drawn per simulation. One Nation: a ratio pooled across federal Senate-vs-House, Victorian and
# poll evidence (random effects, clustered on the election). Minor groups: polled levels where named, a shrunk
# regional pattern from 2022, the rest scaled to fill the pool the majors leave.

utils::globalVariables(c("reg", "region", "election", "upper", "lower", "cls", "district", "party", "U", "L",
  "SU", "SL", "u", "l", "su", "sl", "us", "ls", "y", "m", "lstate", "d", "xr", "da", "dbar", "yd", "xd", "er",
  "lst", "kind", "se", "n", "log_ratio", "unit", "source", "weight", "key", "votes", "R", "v", "share", "state",
  "pat", "pat_n", "pat_o", "yr", "ratio", "change", "com", "case", "poll", "house", "pct", "group_name", "group", "level", "polled", "med", "xg", "groups", "seats", "ticket", "b_ols", "c_ols", "se_b", "se_c", "w_b", "w_c", "b", "a", "res"))

#' Map an older Legislative Council region name to its 2022 successor
#'
#' 2014-2018 "Eastern Metropolitan" became "North-Eastern Metropolitan" in the 2021 redistribution.
#' @param x character vector of region names.
#' @return character vector.
#' @export
uh_map_region <- function(x) {
  x <- as.character(x)
  x[x == "Eastern Metropolitan"] <- "North-Eastern Metropolitan"
  x
}

#' Region-level upper and lower shares and log ratios
#'
#' @param inp data.frame with columns election, region, district, cls, upper, lower (votes per district and
#'   party class; `external/reference/vec/upper-house-ratio-inputs.csv`).
#' @param parties party classes to keep.
#' @return data.table: election, reg, party, us, ls (percent), y = log(us/ls), m (statewide log ratio), lstate
#'   (statewide lower share), d = y - m, xr = log(ls / lstate).
#' @export
uh_region_table <- function(inp, parties = c("ALP", "LNP", "GRN")) {
  d <- data.table::copy(data.table::as.data.table(inp))
  stopifnot(all(c("election", "region", "district", "cls", "upper", "lower") %in% names(d)))
  d[, reg := uh_map_region(region)]
  nreg <- d[, .(n = data.table::uniqueN(reg)), by = election]
  if (any(nreg$n != 8L)) stop("uh_region_table: expected 8 regions per election, got ", paste(nreg$election, nreg$n, collapse = ", "))
  tot <- d[, .(U = sum(upper), L = sum(lower)), by = .(election, reg)]
  st  <- d[, .(SU = sum(upper), SL = sum(lower)), by = election]
  rp  <- d[cls %in% parties, .(u = sum(upper), l = sum(lower)), by = .(election, reg, party = cls)]
  sp  <- d[cls %in% parties, .(su = sum(upper), sl = sum(lower)), by = .(election, party = cls)]
  out <- merge(merge(rp, tot, by = c("election", "reg")), merge(sp, st, by = "election"), by = c("election", "party"))
  out[, `:=`(us = 100 * u / U, ls = 100 * l / L)]
  out[, `:=`(y = log(us / ls), m = log((su / SU) / (sl / SL)), lstate = 100 * sl / SL)]
  out[, `:=`(d = y - m, xr = log(ls / lstate))]
  if (any(!is.finite(out$y))) stop("uh_region_table: a party has zero votes in a region on one side")
  out[, .(election, reg, party, us, ls, y, m, lstate, d, xr)][order(election, party, reg)]
}

#' Within-election cross-district level slope of the log ratio, per party
#'
#' log(upper/lower) in a district, minus the election's statewide log ratio, regressed on log(district lower share /
#' statewide lower share), with an election-by-region intercept, so the slope is identified WITHIN regions.
#' @param inp district input table (see [uh_region_table()]).
#' @param elections elections to use.
#' @param parties party classes.
#' @return named numeric vector of slopes.
#' @export
uh_level_slope <- function(inp, elections, parties = c("ALP", "LNP", "GRN")) {
  d <- data.table::as.data.table(inp); els <- elections
  d <- d[election %in% els]
  d[, reg := uh_map_region(region)]
  tot <- d[, .(U = sum(upper), L = sum(lower)), by = .(election, district)]
  st <- d[, .(SU = sum(upper), SL = sum(lower)), by = election]
  b <- setNames(numeric(length(parties)), parties)
  for (k in parties) {
    pk <- k
    x <- merge(merge(d[cls == pk], tot, by = c("election", "district")), st, by = "election")
    x <- x[upper > 0 & lower > 0]
    sx <- x[, .(m = log((sum(upper) / SU[1]) / (sum(lower) / SL[1])), lst = sum(lower) / SL[1]), by = election]
    x <- merge(x, sx, by = "election")
    x[, `:=`(yd = log((upper / U) / (lower / L)) - m, xd = log((lower / L) / lst), er = paste(election, reg))]
    b[[k]] <- unname(stats::coef(stats::lm(yd ~ xd + factor(er), data = x))[["xd"]])
  }
  b
}

#' Fit the majors' ratio model
#'
#' @param rt region table from [uh_region_table()].
#' @param elections elections to fit on (any order; the level is the mean of the LAST TWO by year).
#' @param slope optional named slope vector from [uh_level_slope()] (arm B); NULL for arm A.
#' @param shrink FALSE gives raw region effects (no pooling), for the backtest only.
#' @param regional FALSE gives a uniform statewide ratio (no region effects); the region residual variance is then
#'   the whole spread of region log ratios about the statewide one, pooled over elections. This is what the
#'   pre-registered decision rule chose (the backtest found past region effects did not beat a uniform ratio).
#' @return list: per-party list (mu, eff = named region effects, w, s2, tau2, postvar, b), drift_common_sd,
#'   drift_party_sd, elections.
#' @export
uh_fit_majors <- function(rt, elections, slope = NULL, shrink = TRUE, regional = TRUE) {
  els <- elections; yrs <- as.integer(sub("^[a-z]+", "", els)); els <- els[order(yrs)]
  x <- data.table::as.data.table(rt)[election %in% els]
  E <- length(els); parties <- sort(unique(x$party))
  if (!nrow(x) || E < 1L) stop("uh_fit_majors: no rows for the elections given")
  fit <- list()
  for (k in parties) {
    pk <- k
    xk <- x[party == pk]
    b <- if (is.null(slope)) 0 else unname(slope[[k]])
    xk[, da := d - b * xr]
    mm <- xk[, .(m = m[1]), by = election][match(els, election)]$m
    mu <- mean(utils::tail(mm, 2))
    db <- xk[, .(dbar = mean(da), n = .N), by = reg]
    if (E >= 2L) {
      res <- merge(xk, db, by = "reg")
      s2 <- sum((res$da - res$dbar)^2) / (nrow(db) * (E - 1))
      tau2 <- max(0, stats::var(db$dbar) - s2 / E)
      w <- if (shrink) tau2 / (tau2 + s2 / E) else 1
    } else { s2 <- NA_real_; tau2 <- NA_real_; w <- 1 }
    eff <- setNames(w * db$dbar, db$reg)
    postvar <- if (E >= 2L) w * s2 / E else NA_real_
    if (!regional) {   # uniform ratio: the whole region spread is noise for a new election
      w <- 0; eff[] <- 0; s2 <- mean(xk$da^2); postvar <- 0
    }
    fit[[k]] <- list(mu = mu, eff = eff, w = w, s2 = s2, tau2 = tau2, postvar = postvar, b = b, m = setNames(mm, els))
  }
  # statewide drift: m[k, e] = mbar_k + c_e + r_ke. Predictive variance for the next election about a mean of the
  # last two elections: v x (1 + 1/2).
  if (E >= 2L) {
    M <- t(vapply(parties, function(k) fit[[k]]$m, numeric(E)))
    dev <- M - rowMeans(M); ce <- colMeans(dev); r <- sweep(dev, 2, ce)
    vc <- if (E >= 2L) stats::var(ce) else NA_real_
    vp <- if (length(parties) >= 2L) sum(r^2) / ((length(parties) - 1) * (E - 1)) else 0
    k2 <- 1 + 1 / min(2, E)
    dc <- sqrt(k2 * vc); dp <- sqrt(k2 * vp)
  } else { dc <- NA_real_; dp <- NA_real_ }
  list(party = fit, drift_common_sd = dc, drift_party_sd = dp, elections = els)
}

#' Point log ratio per region for the majors
#'
#' @param fit from [uh_fit_majors()].
#' @param lower_reg named list or data.frame-like: for each party, a named vector of lower-house region shares
#'   (percent), names = regions. Used only by the slope (arm B).
#' @param lower_state named vector: statewide lower share per party (percent).
#' @param regs regions to predict.
#' @return matrix regions x parties of log ratios.
#' @export
uh_major_logratio <- function(fit, regs, lower_reg = NULL, lower_state = NULL) {
  ps <- names(fit$party)
  out <- matrix(NA_real_, length(regs), length(ps), dimnames = list(regs, ps))
  for (k in ps) {
    f <- fit$party[[k]]
    e <- f$eff[regs]; e[is.na(e)] <- 0
    lv <- if (f$b != 0) {
      if (is.null(lower_reg) || is.null(lower_state)) stop("uh_major_logratio: slope fit needs lower_reg and lower_state")
      f$b * log(lower_reg[[k]][regs] / lower_state[[k]])
    } else 0
    out[, k] <- f$mu + e + lv
  }
  out
}

#' Simulated ratio draws for the majors
#'
#' exp(point + common drift + party drift + region residual). The drift draws are shared by every region in a
#' simulation; the region residual has variance s2 + postvar.
#' @param fit from [uh_fit_majors()] fitted on at least two elections.
#' @param point matrix regions x parties from [uh_major_logratio()].
#' @param N number of simulations.
#' @return list by party of N x regions ratio matrices.
#' @export
uh_draw_major_ratios <- function(fit, point, N) {
  if (!is.finite(fit$drift_common_sd)) stop("uh_draw_major_ratios: the fit needs at least two elections for its drift")
  ps <- colnames(point); R <- nrow(point)
  com <- stats::rnorm(N, 0, fit$drift_common_sd)
  out <- list()
  for (k in ps) {
    f <- fit$party[[k]]
    pd <- stats::rnorm(N, 0, fit$drift_party_sd)
    rs <- matrix(stats::rnorm(N * R, 0, sqrt(f$s2 + f$postvar)), N, R)
    lr <- matrix(point[, k], N, R, byrow = TRUE) + com + pd + rs
    out[[k]] <- exp(lr); colnames(out[[k]]) <- rownames(point)
  }
  out
}

#' Regime-change variance from ticket-abolition natural experiments
#'
#' Each case has a before (tickets) and after (no tickets) election; the change in log ratio per party is split
#' into a common part (mean over parties within a case) and a party part. No mean shift is returned for use: the
#' cases disagree in sign (prereg addition 6); the mean is reported only.
#' @param nt data.frame: case, election, cls, ratio (`upper-house-noticket-experiments.csv`), two elections per case.
#' @return list(common_sd, party_sd, changes = data.table, mean_shift = named by party).
#' @export
uh_noticket_variance <- function(nt) {
  x <- data.table::as.data.table(nt)
  x[, yr := as.integer(sub("^[a-z]+", "", election))]
  ch <- x[, { o <- order(yr); if (.N != 2L) stop("uh_noticket_variance: each case needs exactly two elections per party")
    .(change = log(ratio[o][2] / ratio[o][1])) }, by = .(case, cls)]
  ch[, com := mean(change), by = case]
  nc <- data.table::uniqueN(ch$case); np <- data.table::uniqueN(ch$cls)
  list(common_sd = sqrt(sum(unique(ch[, .(case, com)])$com^2) / nc),
       party_sd = sqrt(sum((ch$change - ch$com)^2) / (nc * (np - 1))),
       changes = ch, mean_shift = ch[, .(shift = mean(change)), by = cls])
}

#' Add the regime-change variance to a majors fit's statewide drift
#'
#' @param fit from [uh_fit_majors()].
#' @param nv from [uh_noticket_variance()].
#' @return the fit with drift_common_sd and drift_party_sd widened (variances added).
#' @export
uh_add_regime_variance <- function(fit, nv) {
  fit$drift_common_sd <- sqrt(fit$drift_common_sd^2 + nv$common_sd^2)
  fit$drift_party_sd <- sqrt(fit$drift_party_sd^2 + nv$party_sd^2)
  fit$regime <- nv
  fit
}

#' DerSimonian-Laird random-effects pooling
#'
#' @param y estimates.
#' @param se their standard errors.
#' @return list(mu, se, tau2, w) with w the normalised weights.
#' @export
uh_dl_pool <- function(y, se) {
  ok <- is.finite(y) & is.finite(se) & se > 0
  if (sum(ok) < 1L) stop("uh_dl_pool: no usable estimates")
  y <- y[ok]; v <- se[ok]^2; wf <- 1 / v
  mf <- sum(wf * y) / sum(wf); Q <- sum(wf * (y - mf)^2); k <- length(y)
  tau2 <- if (k > 1L) max(0, (Q - (k - 1)) / (sum(wf) - sum(wf^2) / sum(wf))) else 0
  wr <- 1 / (v + tau2); mu <- sum(wr * y) / sum(wr)
  w <- rep(NA_real_, length(ok)); w[ok] <- wr / sum(wr)
  list(mu = mu, se = sqrt(1 / sum(wr)), tau2 = tau2, w = w)
}

#' House-effect-free relative ratio from one poll
#'
#' (party upper / party lower) / geometric mean over the majors of (upper / lower), times the historical majors'
#' geometric mean ratio. The poll's level (undecideds, how it treats minors) cancels.
#' @param pu,pl party's upper and lower percent in the poll.
#' @param mu,ml majors' upper and lower percent in the same poll (same order).
#' @param hist_geo historical geometric mean of the majors' ratios (a ratio, not a log).
#' @return log ratio.
#' @export
uh_poll_relative <- function(pu, pl, mu, ml, hist_geo) {
  log(pu / pl) - mean(log(mu / ml)) + log(hist_geo)
}

#' Pool One Nation's upper/lower log ratio across sources
#'
#' Federal state rows are pooled within each election first (random effects), so an election with seven states
#' counts once; then all units are pooled with [uh_dl_pool()].
#' @param src data.frame: source ("fed2022 VIC"), kind, n, log_ratio, se (`upper-house-onp-sources.csv`), and any
#'   extra unit rows (kind not "federal Senate vs House", already one unit each).
#' @param min_n federal state rows with fewer paired divisions are dropped.
#' @return list(units = data.table with weights, mu, se, tau2, pred_sd, dropped).
#' @export
uh_onp_pool <- function(src, min_n = 5L) {
  s <- data.table::as.data.table(src)
  fedk <- "federal Senate vs House"
  fe <- s[kind == fedk]
  drop <- fe[!(n >= min_n & is.finite(se))]
  fe <- fe[n >= min_n & is.finite(se)]
  fe[, unit := sub(" .*$", "", source)]
  fu <- fe[, { p <- uh_dl_pool(log_ratio, se); .(log_ratio = p$mu, se = p$se, n = sum(n), states = .N) }, by = unit]
  fu[, kind := fedk]
  ot <- s[kind != fedk, .(unit = source, log_ratio, se, n, states = 1L, kind)]
  u <- rbind(fu, ot, fill = TRUE)
  p <- uh_dl_pool(u$log_ratio, u$se)
  u[, weight := p$w]
  list(units = u, mu = p$mu, se = p$se, tau2 = p$tau2, pred_sd = sqrt(p$se^2 + p$tau2), dropped = drop)
}

#' Shrunk regional pattern for minor groups
#'
#' pattern = log(region share / statewide share). Its between-election instability s2 comes from groups that ran in
#' both of two elections (var of the change / 2); tau2 = var(pattern) - s2; the pattern is shrunk by tau2/(tau2+s2).
#' @param p_new named-by-row data.frame: key, reg, pat (the newer election's pattern).
#' @param p_old the same for the older election.
#' @return list(w, s2, tau2, n_pairs).
#' @export
uh_minor_shrink <- function(p_new, p_old) {
  a <- merge(data.table::as.data.table(p_new), data.table::as.data.table(p_old), by = c("key", "reg"), suffixes = c("_n", "_o"))
  a <- a[is.finite(pat_n) & is.finite(pat_o)]
  if (nrow(a) < 8L) stop("uh_minor_shrink: fewer than 8 group-region pairs ran in both elections")
  s2 <- stats::var(a$pat_n - a$pat_o) / 2
  tau2 <- max(0, stats::var(a$pat_n) - s2)
  list(w = tau2 / (tau2 + s2), s2 = s2, tau2 = tau2, n_pairs = nrow(a))
}

#' Regional pattern of each group from region totals
#'
#' @param tots data.frame: reg, key, votes (every group, majors included, so region totals are formal votes).
#' @param keys keys to return (NA keys are counted in totals but not returned).
#' @return data.table key, reg, share (percent), state (statewide percent), pat.
#' @export
uh_minor_pattern <- function(tots, keys = NULL) {
  t <- data.table::copy(data.table::as.data.table(tots))
  t[, R := sum(votes), by = reg]; S <- sum(t$votes)
  g <- t[!is.na(key), .(v = sum(votes), R = R[1]), by = .(key, reg)]
  g[, `:=`(share = 100 * v / R, state = 100 * sum(v) / S), by = key]
  g[, pat := log(share / state)]
  if (!is.null(keys)) { kk <- keys; g <- g[key %in% kk] }
  g[, .(key, reg, share, state, pat)]
}

#' Region levels of a group from a statewide level and a shrunk pattern
#'
#' share_r = level x exp(w x pat_r), rescaled so the vote-weighted mean over regions equals the level.
#' @param level statewide percent.
#' @param pat named regional pattern.
#' @param w shrink weight.
#' @param vw named region vote weights.
#' @return named percent by region.
#' @export
uh_level_by_region <- function(level, pat, w, vw) {
  rr <- names(vw); p <- pat[rr]; p[is.na(p)] <- 0
  s <- exp(w * p); s * level / sum(s * vw / sum(vw))
}

#' Name patterns that identify the same minor group across elections
#'
#' Used for the regional pattern and its shrinkage. Matched in order; the LAST match wins (as the build script's
#' own matcher does).
#' @return character vector of regular expressions.
#' @export
uh_minor_keys <- function() {
  c("Cannabis", "Labour DLP|Democratic Labour", "Victorian Socialists", "Sustainable Australia", "Animal Justice", "Shooters",
    "Libertarian|Liberal Democrats", "Family First", "Justice Party", "Reason", "Health Australia", "Transport Matters")
}

#' Key of a group name under [uh_minor_keys()]
#' @param nm group names.
#' @param keys patterns.
#' @return character, NA where nothing matches.
#' @export
uh_key_of <- function(nm, keys = uh_minor_keys()) {
  vapply(nm, function(s) { k <- NA_character_; for (p in keys) if (grepl(p, s, ignore.case = TRUE)) k <- p; k }, "", USE.NAMES = FALSE)
}

#' One Nation poll units, house-effect-free, from same-poll upper and lower figures
#'
#' Sampling variance of log(upper/lower) is taken as if the two answers were independent (an upper bound: they come
#' from the same respondents). The discrepancy variance is what the majors' relative ratios in the same polls show
#' beyond sampling, against Victoria's 2018-22 relative ratios.
#' @param pl data.frame: poll, n, house ("upper"/"lower"), party, pct (`external/reference/polls/demosau-upper-lower-2025-2026.csv`).
#' @param rt region table from [uh_region_table()] (statewide m per party and election).
#' @param hist_elections elections whose ratios are the history.
#' @return list(units = data.table source, kind, n, lower, upper, log_ratio, se; disc = per poll x major; disc_var; hist_geo).
#' @export
uh_onp_poll_units <- function(pl, rt, hist_elections = c("vic2018", "vic2022")) {
  p <- data.table::as.data.table(pl); he <- hist_elections; mj <- c("LNP", "ALP", "GRN")
  mh <- unique(data.table::as.data.table(rt)[election %in% he, .(election, party, m)])[, .(m = mean(m)), by = party]
  if (!all(mj %in% mh$party)) stop("uh_onp_poll_units: history lacks a major")
  hist_geo <- exp(mean(mh$m)); relh <- setNames(mh$m - mean(mh$m), mh$party)
  sv <- function(q, nn) (1 - q / 100) / (nn * q / 100)
  get <- function(pp, hh, pa) { z <- p[poll == pp & house == hh & party == pa]$pct; if (length(z) == 1L) z else NA_real_ }
  polls <- unique(p$poll)
  disc <- data.table::rbindlist(lapply(polls, function(pp) {
    nn <- p[poll == pp]$n[1]; u <- vapply(mj, function(k) get(pp, "upper", k), 0); l <- vapply(mj, function(k) get(pp, "lower", k), 0)
    if (anyNA(c(u, l))) return(NULL)
    lr <- log(u / l); data.table::data.table(poll = pp, party = mj, disc = (lr - mean(lr)) - relh[mj], samp = sv(u, nn) + sv(l, nn))
  }))
  np <- data.table::uniqueN(disc$poll)
  disc_var <- max(0, sum(disc$disc^2) / (np * (length(mj) - 1)) - mean(disc$samp))
  units <- data.table::rbindlist(lapply(polls, function(pp) {
    nn <- p[poll == pp]$n[1]; ou <- get(pp, "upper", "ONP"); ol <- get(pp, "lower", "ONP")
    u <- vapply(mj, function(k) get(pp, "upper", k), 0); l <- vapply(mj, function(k) get(pp, "lower", k), 0)
    if (anyNA(c(ou, ol, u, l))) return(NULL)
    data.table::data.table(source = paste("DemosAU", pp), kind = "DemosAU same-poll relative ratio", n = nn, lower = ol, upper = ou,
                           log_ratio = uh_poll_relative(ou, ol, u, l, hist_geo), se = sqrt(sv(ou, nn) + sv(ol, nn) + disc_var))
  }))
  list(units = units, disc = disc, disc_var = disc_var, hist_geo = hist_geo)
}

#' Expected first-preference level of each 2026 minor group by region
#'
#' Matched groups: 2022 statewide share x exp(w x 2022 regional pattern), rescaled to the statewide level; a polled
#' level replaces the 2022 statewide share where the group is named in a poll. Unmatched groups: the region's
#' median 2022 minor share (x 0.3 for ungrouped or unnamed columns, as the build script does).
#' @param mi data.frame: region, group (2026 minor groups).
#' @param tot22 data.frame: region, group_name, votes (every 2022 group, majors included).
#' @param w pattern shrink weight from [uh_minor_shrink()].
#' @param vw named region vote weights.
#' @param polled named numeric: key -> statewide percent.
#' @param major_pat regex of the 2022 major and One Nation group names (excluded from the median).
#' @return data.table region, group, key, level (percent of region vote), polled (logical).
#' @export
uh_minor_region_levels <- function(mi, tot22, w, vw, polled = numeric(0),
                                   major_pat = "LABOR|LIBERAL|NATIONALS|GREENS|ONE NATION") {
  g <- data.table::copy(data.table::as.data.table(mi)); t <- data.table::copy(data.table::as.data.table(tot22))
  t[, `:=`(reg = region, key = uh_key_of(group_name))]
  pat <- uh_minor_pattern(t[, .(reg, key, votes)])
  t[, R := sum(votes), by = reg]
  med <- t[!grepl(major_pat, toupper(group_name)), .(med = stats::median(100 * votes / R)), by = reg]
  g[, key := uh_key_of(group)]
  g[, `:=`(level = NA_real_, polled = FALSE)]
  for (k in unique(stats::na.omit(g$key))) {
    kk <- k; pk <- pat[key == kk]
    if (!nrow(pk) && !(k %in% names(polled))) next
    lev <- if (k %in% names(polled)) polled[[k]] else pk$state[1]
    pr <- if (nrow(pk)) setNames(pk$pat, pk$reg) else setNames(numeric(0), character(0))
    byr <- uh_level_by_region(lev, pr, w, vw)
    ix <- which(g$key == kk)
    g$level[ix] <- byr[g$region[ix]]; g$polled[ix] <- k %in% names(polled)
  }
  miss <- which(is.na(g$level))
  g$level[miss] <- med$med[match(g$region[miss], med$reg)] * ifelse(grepl("Ungrouped|no name|Unnamed", g$group[miss]), 0.3, 1)
  if (anyNA(g$level)) stop("uh_minor_region_levels: a region has no 2022 minor median")
  g[, .(region, group, key, level, polled)]
}

#' Simulated minor-group votes in one region
#'
#' The pool (what the majors and One Nation leave) is shared across ALL the region's minor groups in proportion to
#' their expected levels, with Dirichlet noise; a polled group's weight is also multiplied by its per-simulation
#' sampling factor (shared across regions, passed in). Proportional, not "polled groups fixed and the rest stretched":
#' holding polled groups fixed left the un-polled ones absorbing every swing in the pool (results addition 7).
#' @param lv data.frame for ONE region from [uh_minor_region_levels()], in the column order wanted.
#' @param pool length-N vector: percent left after the majors and One Nation.
#' @param zf N x (polled groups) matrix of multiplicative sampling factors, columns named by key.
#' @param conc Dirichlet concentration (the build script's CONC).
#' @return N x groups matrix of percent; rows sum to `pool`.
#' @export
uh_minor_votes <- function(lv, pool, zf, conc = 30) {
  N <- length(pool); G <- nrow(lv)
  if (any(!is.finite(lv$level)) || any(lv$level <= 0)) stop("uh_minor_votes: every minor group needs a positive level")
  W <- matrix(lv$level, N, G, byrow = TRUE)
  for (j in which(lv$polled)) W[, j] <- W[, j] * zf[, lv$key[j]]
  W <- W / rowSums(W)
  gam <- matrix(stats::rgamma(N * G, shape = conc * W), N)
  gam / rowSums(gam) * pool
}

#' Election-level table for the ballot-crowding model
#'
#' @param cr data.frame: election, unit, groups, seats, cls, ratio (the election's statewide upper/lower ratio,
#'   repeated per unit), ticket (`external/reference/vec/upper-house-crowding-inputs.csv`).
#' @param scale "per_seat" (x = log(groups / seats), the pre-registered choice) or "raw" (x = log(groups)).
#' @return data.table election, cls, x (mean over units), ticket, y = log ratio.
#' @export
uh_crowding_table <- function(cr, scale = c("per_seat", "raw")) {
  scale <- match.arg(scale)
  x <- data.table::copy(data.table::as.data.table(cr))
  if (any(!is.finite(x$groups)) || any(x$groups < 1)) stop("uh_crowding_table: every unit needs a group count")
  x[, xg := if (scale == "per_seat") log(groups / seats) else log(groups)]
  x[!is.na(ratio), .(x = mean(xg), ticket = ticket[1], y = log(ratio[1])), by = .(election, cls)]
}

#' Fit the ballot-crowding model: log ratio = a + b x + c ticket, per major party, b and c partially pooled
#'
#' Each party's OLS slope b_k and ticket term c_k are shrunk toward their precision-weighted mean across parties
#' ([uh_dl_pool()]: w = tau2 / (tau2 + se^2)); the intercept is refitted given the shrunk terms. Residuals are split
#' into a common part (mean across parties within an election) and a party part.
#' @param et table from [uh_crowding_table()].
#' @param elections elections to fit on.
#' @return list(coef = data.table cls, a, b, c, b_ols, c_ols, se_b, se_c, w_b, w_c; V = per-party OLS vcov;
#'   common_sd, party_sd, n, elections).
#' @export
uh_crowding_fit <- function(et, elections) {
  els <- elections; x <- data.table::as.data.table(et)[election %in% els]
  ps <- sort(unique(x$cls)); E <- data.table::uniqueN(x$election)
  if (E < 4L) stop("uh_crowding_fit: needs at least 4 elections for 3 parameters, got ", E)
  if (data.table::uniqueN(x$ticket) < 2L) stop("uh_crowding_fit: the ticket indicator does not vary in these elections")
  ols <- lapply(ps, function(k) { pk <- k; stats::lm(y ~ x + ticket, data = x[cls == pk]) }); names(ols) <- ps
  cf <- data.table::rbindlist(lapply(ps, function(k) { s <- summary(ols[[k]])$coefficients
    data.table::data.table(cls = k, b_ols = s["x", 1], se_b = s["x", 2], c_ols = s["ticket", 1], se_c = s["ticket", 2]) }))
  pb <- uh_dl_pool(cf$b_ols, cf$se_b); pc <- uh_dl_pool(cf$c_ols, cf$se_c)
  cf[, `:=`(w_b = pb$tau2 / (pb$tau2 + se_b^2), w_c = pc$tau2 / (pc$tau2 + se_c^2))]
  cf[, `:=`(b = pb$mu + w_b * (b_ols - pb$mu), c = pc$mu + w_c * (c_ols - pc$mu))]
  cf[, a := vapply(cls, function(k) { pk <- k; z <- x[cls == pk]; mean(z$y - b[cls == pk] * z$x - c[cls == pk] * z$ticket) }, 0)]
  r <- merge(x, cf[, .(cls, a, b, c)], by = "cls")[, res := y - a - b * x - c * ticket]
  R <- as.matrix(data.table::dcast(r, election ~ cls, value.var = "res")[, -1])
  com <- rowMeans(R); df <- max(1, E - 3)
  list(coef = cf, V = lapply(ols, stats::vcov), common_sd = sqrt(sum(com^2) / df),
       party_sd = sqrt(sum((R - com)^2) / (df * (length(ps) - 1))), n = E, elections = sort(unique(x$election)))
}

#' Point log ratio per region from the crowding model, and its coefficient variance
#'
#' @param cf fit from [uh_crowding_fit()].
#' @param xr named numeric: each region's x (log groups per seat, or log groups, matching the fit).
#' @param ticket 0 or 1 for the election predicted.
#' @return list(point = regions x parties matrix, coef_var = named per party, at the mean x).
#' @export
uh_crowding_predict <- function(cf, xr, ticket = 0) {
  ps <- cf$coef$cls
  pt <- sapply(ps, function(k) { z <- cf$coef[cls == k]; z$a + z$b * xr + z$c * ticket })
  if (is.null(dim(pt))) pt <- matrix(pt, nrow = length(xr), dimnames = list(names(xr), ps))
  rownames(pt) <- names(xr)
  x0 <- c(1, mean(xr), ticket)
  cv <- vapply(ps, function(k) drop(t(x0) %*% cf$V[[k]] %*% x0), 0)
  list(point = pt, coef_var = cv)
}

#' Simulated ratio draws from the crowding model
#'
#' exp(point + common residual + party residual + coefficient error + region residual). The first three are drawn
#' once per simulation and shared by every region.
#' @param cf fit from [uh_crowding_fit()].
#' @param pr from [uh_crowding_predict()].
#' @param s2 named per party: region residual variance (from [uh_fit_majors()] with regional = FALSE).
#' @param N simulations.
#' @return list by party of N x regions matrices.
#' @export
uh_crowding_draws <- function(cf, pr, s2, N) {
  P <- pr$point; R <- nrow(P); com <- stats::rnorm(N, 0, cf$common_sd); out <- list()
  for (k in colnames(P)) {
    sh <- com + stats::rnorm(N, 0, cf$party_sd) + stats::rnorm(N, 0, sqrt(pr$coef_var[[k]]))
    lr <- matrix(P[, k], N, R, byrow = TRUE) + sh + matrix(stats::rnorm(N * R, 0, sqrt(s2[[k]])), N, R)
    out[[k]] <- exp(lr); colnames(out[[k]]) <- rownames(P)
  }
  out
}
