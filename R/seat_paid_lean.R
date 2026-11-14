# Arm SPL: paid (stakeholder) SEAT polls lose a shrunk lean toward their sponsor's side, learned time-forward from
# seat results net of independent seat polls of the same election (docs/plans/prereg-seat-paid-lean-2026-11-14.md;
# the walk: docs/reviews/seat-poll-paid-lean-walk-2026-11-14.md). The statewide twin is R/paid_poll.R (arm PPC),
# whose side map (paid_poll_side(), .ppc_side_parties()) this shares. Data.table NSE: no local shares a column name.

#' Whether paid seat polls lose their lean toward the sponsor (`AUSPOL_SEAT_POLL_PAID_LEAN`, arm SPL)
#' @keywords internal
.seat_paid_lean_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_PAID_LEAN", "1")   # shipped 14 Nov 2026

SEAT_PAID_LEAN_BASE_K <- 3   # an election's independent-poll mean is shrunk to 0 by n/(n + 3), as AUSPOL_CONSERVE_SHRINK_K
SEAT_PAID_LEAN_SIDES <- c("ALP", "ALP+GRN", "GRN", "LNP", "IND")

.spl_tcp_party <- function(x) {
  x <- toupper(trimws(x))
  ifelse(x %in% c("LIB", "NAT", "LNP", "L/NP", "LP", "NP", "CLP", "COALITION"), "LNP", ifelse(x == "IND" | grepl("\\(IND\\)$", x), "IND", x))
}

#' Side gaps of one election's direct seat polls against its results
#'
#' @param raw [seat_poll_shares()] at `.raw = TRUE` (one row per poll and class, with `group` and `sponsor`).
#' @param act Results for the same election: `seat`, `party`, `share` (percent of the seat's formal vote).
#' @param tcp `NULL` or two-candidate results: `seat`, `party`, `tshare`.
#' @param tcp_rows `NULL` or one row per poll with a two-candidate figure: `poll_id`, `pa`, `pb`, `tcp_a`.
#' @param sides `NULL` (from each paid poll's sponsor) or a named vector, poll_id -> side.
#' @return data.table, one row per measurable PAID poll: `poll_id`, `seat`, `side`, `cluster` (sponsor), `how`
#'   (primary or tcp), `gap` (side's poll share minus its result), `base` (shrunk independent-poll mean, same
#'   election and side), `net` (= gap - base).
#' @keywords internal
seat_paid_lean_measure <- function(raw, act, tcp = NULL, tcp_rows = NULL, sides = NULL) {
  out0 <- data.table::data.table(poll_id = character(0), seat = character(0), side = character(0), cluster = character(0),
                                 how = character(0), gap = numeric(0), base = numeric(0), net = numeric(0))
  if (!nrow(raw)) return(out0)
  r <- raw[raw$group %in% c("direct_stake", "direct_indep") & is.finite(raw$fp)]
  if (!nrow(r)) return(out0)
  info <- unique(r[, c("poll_id", "seat", "group", "sponsor"), with = FALSE], by = "poll_id")
  info$side <- if (is.null(sides)) ifelse(info$group == "direct_stake", paid_poll_side(info$sponsor), NA_character_) else unname(sides[info$poll_id])
  prim <- function(pid, sd_) {   # primary side gap, NA unless the poll names ALP, LNP and GRN (and IND for the IND side)
    b <- r[r$poll_id == pid, list(fp = sum(fp)), by = "class"]
    if (!all(c("ALP", "LNP", "GRN") %in% b$class) || (sd_ == "IND" && !"IND" %in% b$class)) return(NA_real_)
    sp <- .ppc_side_parties(sd_, b$class)
    if (!length(sp)) return(NA_real_)
    st <- info$seat[info$poll_id == pid]
    a <- act[act$seat == st]
    if (!nrow(a)) return(NA_real_)
    100 * sum(b$fp[b$class %in% sp]) / sum(b$fp) - sum(a$share[a$party %in% sp])
  }
  tcpg <- function(pid, sd_) {
    if (is.null(tcp) || is.null(tcp_rows)) return(NA_real_)
    t <- tcp_rows[tcp_rows$poll_id == pid]
    if (nrow(t) != 1L || !is.finite(t$tcp_a)) return(NA_real_)
    a <- tcp[tcp$seat == info$seat[info$poll_id == pid]]
    if (nrow(a) != 2L || !setequal(c(t$pa, t$pb), a$party)) return(NA_real_)
    sp <- .ppc_side_parties(sd_, c(t$pa, t$pb))
    if (length(sp) != 1L) return(NA_real_)
    (if (sp == t$pa) t$tcp_a else 100 - t$tcp_a) - a$tshare[a$party == sp]
  }
  # independent baseline per side: mean primary gap over this election's independent polls, shrunk to 0
  ind <- info$poll_id[info$group == "direct_indep"]
  ind_ss <- 0; ind_df <- 0; ind_n <- 0L   # independent polls' residual noise around this election's side means (amendment 1)
  base <- vapply(SEAT_PAID_LEAN_SIDES, function(sd_) {
    g <- vapply(ind, prim, 1, sd_ = sd_); g <- g[is.finite(g)]
    if (length(g) >= 2L) { ind_ss <<- ind_ss + sum((g - mean(g))^2); ind_df <<- ind_df + length(g) - 1 }
    ind_n <<- max(ind_n, length(g))
    if (!length(g)) 0 else mean(g) * length(g) / (length(g) + SEAT_PAID_LEAN_BASE_K)
  }, 1)
  # one degree of freedom per independent poll beyond one per election, whatever the number of sides measured
  ind_s2 <- if (ind_df > 0) ind_ss / ind_df else NA_real_
  out0 <- .spl_noise(out0, ind_s2, max(0L, ind_n - 1L))
  paid <- info[info$group == "direct_stake" & !is.na(info$side) & info$side %in% SEAT_PAID_LEAN_SIDES]
  if (!nrow(paid)) return(out0)
  rows <- lapply(seq_len(nrow(paid)), function(j) {
    pid <- paid$poll_id[j]; sd_ <- paid$side[j]
    g <- prim(pid, sd_); how <- "primary"
    if (!is.finite(g)) { g <- tcpg(pid, sd_); how <- "tcp" }
    if (!is.finite(g)) return(NULL)
    data.table::data.table(poll_id = pid, seat = paid$seat[j], side = sd_, cluster = paid$sponsor[j], how = how,
                           gap = g, base = base[[sd_]], net = g - base[[sd_]])
  })
  out <- data.table::rbindlist(rows)
  if (!nrow(out)) out0 else .spl_noise(out, ind_s2, max(0L, ind_n - 1L))
}

.spl_noise <- function(x, s2, df) { attr(x, "ind_s2") <- s2; attr(x, "ind_df") <- df; x }

#' Fit the per-side lean of paid seat polls (each side shrunk to zero on its own, SE clustered on sponsor and election)
#'
#' @param dev Rows of [seat_paid_lean_measure()] over the training elections, with `cluster` already holding
#'   election and sponsor.
#' @param s2_ind,df_ind Independent seat polls' residual variance (points^2) and its degrees of freedom: the prior
#'   the paid-poll residual variance is pooled with (prereg amendment 1). `df_ind = 0` uses the paid polls alone.
#' @return List: `lean` (per side: `n`, `k` clusters, `m`, `se`, `w` = tau0^2/(tau0^2+se^2), `shrunk` = w m), and for the
#'   log only `mu`, `se_mu`, `w0`, `mu_s` (pooled across sides), `tau2`; `s2` (residual variance), `n`.
#' @keywords internal
seat_paid_lean_fit <- function(dev, s2_ind = NA_real_, df_ind = 0) {
  empty <- list(lean = data.table::data.table(side = character(0), n = integer(0), k = integer(0), m = numeric(0),
                                              se = numeric(0), w = numeric(0), shrunk = numeric(0)),
                mu = 0, se_mu = NA_real_, w0 = 0, mu_s = 0, tau2 = 0, s2 = NA_real_, n = 0L)
  if (!nrow(dev)) return(empty)
  d <- dev[is.finite(dev$net) & dev$side %in% SEAT_PAID_LEAN_SIDES]
  empty$n <- nrow(d)
  if (nrow(d) < 2L) return(empty)
  lean <- d[, list(n = .N, k = data.table::uniqueN(cluster), m = mean(net)), by = "side"]
  df <- nrow(d) - nrow(lean)
  ss <- sum((d$net - lean$m[match(d$side, lean$side)])^2)
  if (!is.finite(s2_ind) || df_ind <= 0) { s2_ind <- 0; df_ind <- 0 }
  if (df + df_ind < 1) return(empty)
  s2 <- (ss + df_ind * s2_ind) / (df + df_ind)
  if (!is.finite(s2) || s2 <= 0) return(empty)
  lean[, se := sqrt(s2 / lean$k)]
  wt <- 1 / lean$se^2
  mu <- sum(wt * lean$m) / sum(wt); se_mu <- 1 / sqrt(sum(wt))
  kk <- nrow(lean)
  tau2 <- if (kk > 1L) max(0, (sum(wt * (lean$m - mu)^2) - (kk - 1)) / (sum(wt) - sum(wt^2) / sum(wt))) else 0
  w0 <- mu^2 / (mu^2 + se_mu^2)
  mu_s <- w0 * mu
  # amendment 3 (Pete, 14 Nov): sides are NOT pooled toward each other but each shrunk toward ZERO, by an
  # empirical-Bayes weight: tau0^2 = how far real side leans spread around zero (mean of m^2 - se^2, floored at 0),
  # w = tau0^2 / (tau0^2 + se^2). Pure noise gives tau0^2 ~ 0 and no lean; Climate 200's record (none) is never
  # overruled by Advance's (+4.7). mu, tau2 and mu_s stay in the fit for the log only.
  tau0 <- max(0, mean(lean$m^2 - lean$se^2))
  lean[, w := tau0 / (tau0 + lean$se^2)]
  lean[, shrunk := lean$w * lean$m]
  list(lean = lean, mu = mu, se_mu = se_mu, w0 = w0, mu_s = mu_s, tau2 = tau2, tau0 = tau0, s2 = s2, n = nrow(d))
}

#' One election's inputs for arm SPL: its seat polls (`.raw`), results from `output/candidacies.csv`, and federal
#' two-candidate counts from `external/elections/aec-fed-tcp.csv` with the polls' two-candidate figures
#' @keywords internal
.seat_paid_lean_inputs <- function(el) {
  utils::capture.output(raw <- seat_poll_shares(el, .raw = TRUE))
  if (!nrow(raw) || !"sponsor" %in% names(raw)) return(NULL)
  cand <- data.table::fread(out_path("candidacies.csv"), select = c("election", "seat", "party", "votes"), showProgress = FALSE)
  cand <- cand[cand$election == el]
  if (!nrow(cand)) return(NULL)
  cand$votes <- suppressWarnings(as.numeric(cand$votes))
  act <- cand[, list(v = sum(votes, na.rm = TRUE)), by = c("seat", "party")]
  act[, share := 100 * v / sum(v), by = "seat"]
  tcp <- NULL; tcp_rows <- NULL
  tf <- file.path(pkg_root(), "external", "elections", "aec-fed-tcp.csv")
  if (startsWith(el, "fed") && file.exists(tf)) {
    tcp <- data.table::fread(tf, showProgress = FALSE)
    tcp <- tcp[tcp$election == el]
    tcp[, tshare := 100 * votes / sum(votes), by = "seat"]
    utils::capture.output(s <- .read_seat_polls_file(file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")))
    s <- s[s$election == el & !is.na(s$tcp_a) & nzchar(as.character(s$tcp_a))]
    if (nrow(s)) {
      tcp_rows <- unique(data.table::data.table(poll_id = paste(s$seat_name, s$pollster, s$date_raw),
                                                pa = .spl_tcp_party(s$tcp_party_a), pb = .spl_tcp_party(s$tcp_party_b),
                                                tcp_a = suppressWarnings(as.numeric(s$tcp_a))), by = "poll_id")
    }
  }
  list(raw = raw, act = act, tcp = tcp, tcp_rows = tcp_rows)
}

#' One election's measured paid polls plus its independent-poll noise; `inp` and `sides` let the placebo
#' (scripts/screen_seat_paid_lean.R) relabel polls
#' @keywords internal
.seat_paid_lean_election <- function(el, inp = .seat_paid_lean_inputs(el), sides = NULL) {
  if (is.null(inp)) return(NULL)
  m <- seat_paid_lean_measure(inp$raw, inp$act, inp$tcp, inp$tcp_rows, sides)
  # an election with no direct polls returns before measuring any noise: no attributes, no noise
  s2 <- attr(m, "ind_s2"); dfi <- attr(m, "ind_df")
  if (is.null(s2) || is.null(dfi)) { s2 <- NA_real_; dfi <- 0 }
  if (nrow(m)) { m$election <- el; m$cluster <- paste(el, m$cluster) }
  list(dev = m, ind_ss = if (is.finite(s2)) s2 * dfi else 0, ind_df = if (is.finite(s2)) dfi else 0)
}

#' The paid-seat-poll lean for one target election, from every election with polling day before it
#' @keywords internal
seat_paid_lean <- function(target_election) {
  .seat_poll_memoised(.seat_poll_memo_key(target_election, "spl", FALSE, FALSE, FALSE,
                                          extra = c(file.path(pkg_root(), "external", "elections", "aec-fed-tcp.csv"),
                                                    file.path(pkg_root(), "external", "reference", "polls", "sponsor_side.csv"))),
                      function() {
    ed <- election_dates()
    t0 <- as.Date(unname(ed[target_election]))
    utils::capture.output(s <- .read_seat_polls_file(file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")))
    els <- intersect(unique(s$election), names(ed))
    els <- els[as.Date(unname(ed[els])) < t0]
    per <- Filter(Negate(is.null), lapply(els, .seat_paid_lean_election))
    dev <- data.table::rbindlist(lapply(per, `[[`, "dev"), fill = TRUE)
    ind_df <- sum(vapply(per, `[[`, 1, "ind_df"))
    fit <- seat_paid_lean_fit(dev, if (ind_df > 0) sum(vapply(per, `[[`, 1, "ind_ss")) / ind_df else NA_real_, ind_df)
    cat(sprintf("SPQ1 %s paid seat-poll lean from %d earlier election(s), %d measured paid polls (noise sd %s, %d independent df): pooled %+.2f (SE %s), shrunk %+.2f; per side %s\n",
                target_election, length(els), fit$n, if (is.finite(fit$s2)) sprintf("%.2f", sqrt(fit$s2)) else "NA", as.integer(ind_df),
                fit$mu, if (is.finite(fit$se_mu)) sprintf("%.2f", fit$se_mu) else "NA", fit$mu_s,
                if (nrow(fit$lean)) paste(sprintf("%s %+.2f (n %d, %d clusters)", fit$lean$side, fit$lean$shrunk, fit$lean$n, fit$lean$k), collapse = ", ") else "none"))
    fit
  })
}

#' The lean per side: its own shrunk row; a side with no row, UNKNOWN and NA get none
#' @keywords internal
.spl_leans <- function(fit, sides) {
  sides <- intersect(unique(sides[!is.na(sides)]), SEAT_PAID_LEAN_SIDES)
  own <- setNames(fit$lean$shrunk, fit$lean$side)
  # a side with no record of its own gets none (amendment 3: no borrowing across sides)
  setNames(vapply(sides, function(x) if (x %in% names(own) && is.finite(own[[x]])) own[[x]] else 0, 1), sides)
}

#' Take the lean off each paid seat poll's figures (one row per poll and class, as in .seat_poll_shares_impl())
#'
#' @param per_poll Rows with `poll_id`, `class`, `fp`, `group`, `sponsor`.
#' @param fit From [seat_paid_lean_fit()].
#' @param sides `NULL` (from the sponsor) or a named vector, poll_id -> side.
#' @return `per_poll` with the side's figures lowered and the others raised (each poll's total unchanged), and
#'   attribute `moved` (polls shifted).
#' @keywords internal
seat_paid_lean_apply <- function(per_poll, fit, sides = NULL) {
  out <- data.table::copy(per_poll)
  ids <- unique(out$poll_id[out$group == "direct_stake"])
  attr(out, "moved") <- character(0)
  if (!length(ids)) return(out)
  sp_of <- if (is.null(sides)) setNames(paid_poll_side(out$sponsor[match(ids, out$poll_id)]), ids) else sides[ids]
  ln <- .spl_leans(fit, sp_of)
  moved <- character(0)
  for (pid in ids) {
    sd_ <- unname(sp_of[pid])
    if (is.na(sd_) || !sd_ %in% names(ln) || ln[[sd_]] == 0) next
    ix <- which(out$poll_id == pid & is.finite(out$fp))
    cl <- out$class[ix]
    if (sd_ == "IND" && !"IND" %in% cl) next
    sp <- .ppc_side_parties(sd_, unique(cl))
    on <- cl %in% sp
    if (!any(on) || sum(out$fp[ix][on]) <= 0) next   # a side listed at 0% has nothing to take the lean off (0/0)
    # the lean is in points of a full poll (ALP, LNP and GRN named, scaled to 100): a full poll with undecideds takes
    # it in its own units; a partial one (Hawthorn 2026 reaches here as LNP 41 alone) takes it whole on the side's
    # figures, and with nothing else named it just comes off (each class is averaged on its own in the blend)
    full <- all(c("ALP", "LNP", "GRN") %in% cl)
    l <- ln[[sd_]] * (if (full) sum(out$fp[ix]) / 100 else 1)
    f <- out$fp[ix]
    # never more than the figures it comes off (a partial poll naming only a small side figure): no negative share
    l <- if (l > 0) min(l, sum(f[on])) else if (any(!on)) max(l, -sum(f[!on])) else 0
    f[on] <- f[on] - l * f[on] / sum(f[on])
    if (any(!on)) f[!on] <- f[!on] + l * f[!on] / sum(f[!on])
    data.table::set(out, i = ix, j = "fp", value = f)
    moved <- c(moved, pid)
  }
  attr(out, "moved") <- moved
  out
}
