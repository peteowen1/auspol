# Statewide forecast for a cycle too thin for the poll trend ----------------
#
# WHY. trend_as_at() returns nothing below 8 polls in a cycle (min_polls) and
# forecast_statewide_for() refuses without the anchor's fundamentals, so a thin
# cycle had NO forecast and its pair was skipped: wa2021 (4 polls) and every
# Northern Territory pair (2, 4 and 2 polls; the anchor has no NT rows at all).
# That is a cliff -- 8 polls give a full trend, 7 give nothing -- and the
# repo's rule is shrinkage instead (CLAUDE.md, "Fit constants with SHRINKAGE").
#
# WHAT. The level starts from the previous election's result, with the spread
# statewide shares have actually moved between consecutive elections (tau),
# and each poll moves it by its precision:
#
#   level = (b / tau^2 + sum y_i / s_i^2) / (1 / tau^2 + sum 1 / s_i^2)
#
# so one poll of noise s carries weight tau^2 / (tau^2 + s^2), no poll leaves
# the previous result, and many polls leave mostly the polls.
#   * b      previous result for the class (the caller's st_a).
#   * tau    root-mean-square change in that class's statewide share between
#            consecutive elections, pooled over every jurisdiction in the
#            candidacy corpus, using only pairs whose later election is
#            BEFORE the one being forecast (time-forward), and each class's
#            value shrunk toward the all-class mean by how precisely it is
#            measured (w = tau_b^2 / (tau_b^2 + se^2)).
#   * s_i    the trend model's own default poll noise, 1.7 points
#            (default_sigmas("points")), plus its random walk of 0.10 points a
#            day for the days between the poll and polling day -- an old poll
#            is worth less than a recent one. No house effects: one or two
#            polls cannot estimate them.
# A class no poll reports (independents; usually OTH) is not updated: the
# share the polled classes leave is split among the unpolled ones by their
# previous shares.
#
# This is NOT the published construction for a fitted cycle (no trend, no
# fundamentals, no house effects) and says so in every line it prints.

#' Statewide forecast for a thin poll cycle: previous result updated by polls
#'
#' See the file header (R/thin_cycle.R). Used by
#' [forecast_statewide_or_oracle()] under `AUSPOL_THIN_CYCLE = "1"` when the
#' published trend path cannot run.
#'
#' @param region,year The target, e.g. `"nt"`, `2020`.
#' @param election_date Polling day.
#' @param parties Classes to return.
#' @param st_a Named numeric, previous election's statewide percentages.
#' @param polls Optional poll table (default [load_polls()] for the region).
#' @param corpus Optional candidacy table (default `output/candidacies.csv`).
#' @param code Log prefix.
#' @return Named numeric percentages over `parties`, summing to 100, with
#'   attributes `tau`, `n_polls`, `w_polls`.
#' @export
thin_cycle_statewide <- function(region, year, election_date, parties, st_a,
                                 polls = NULL, corpus = NULL, code = "TC") {
  ed <- as.Date(election_date)
  if (!is.finite(ed)) stop("thin_cycle_statewide(): unparseable election_date")
  target <- paste0(region, year)
  dates <- election_dates()
  reg_of <- sub("[0-9]{4}$", "", names(dates))
  prev_d <- dates[reg_of == region & dates < ed]
  if (!length(prev_d)) stop("thin_cycle_statewide(): no earlier ", region, " election in election_dates()")
  prev_date <- max(prev_d)

  # ---- tau: time-forward spread of statewide swings, pooled and shrunk ----
  C <- corpus
  if (is.null(C)) {
    f <- out_path("candidacies.csv")
    if (!file.exists(f)) stop("thin_cycle_statewide() needs output/candidacies.csv")
    C <- data.table::fread(f, showProgress = FALSE, select = c("election", "party", "votes"))
  }
  C <- data.table::as.data.table(C)
  sw <- C[is.finite(C$votes), list(v = sum(votes)), by = c("election", "party")]
  sw <- sw[sw$election %in% names(dates)]
  sw[, share := 100 * v / sum(v), by = "election"]
  sw <- sw[sw$election %in% sw[, list(t = sum(v)), by = "election"][t > 0]$election]
  els <- unique(sw$election)
  ed_e <- dates[els]; rg_e <- sub("[0-9]{4}$", "", els)
  pr <- data.table::rbindlist(lapply(seq_along(els), function(i) {
    if (!(ed_e[i] < ed)) return(NULL)                          # later election strictly before the target
    cand <- els[rg_e == rg_e[i] & ed_e < ed_e[i]]
    if (!length(cand)) return(NULL)
    data.table::data.table(to = els[i], from = cand[which.max(dates[cand])])
  }))
  if (!nrow(pr)) stop("thin_cycle_statewide(): no earlier election pairs to measure swings from")
  d <- data.table::rbindlist(lapply(seq_len(nrow(pr)), function(i) {
    a <- sw[sw$election == pr$from[i]]; b <- sw[sw$election == pr$to[i]]
    cl <- union(a$party, b$party)
    sa <- stats::setNames(a$share, a$party)[cl]; sb <- stats::setNames(b$share, b$party)[cl]
    sa[is.na(sa)] <- 0; sb[is.na(sb)] <- 0
    data.table::data.table(pair = pr$to[i], party = cl, d = unname(sb - sa))
  }))
  vt <- d[, list(n = .N, v = mean(d^2)), by = "party"]
  ok <- vt$n >= 2L
  se2 <- ifelse(ok, 2 * vt$v^2 / vt$n, NA_real_)
  mu <- mean(vt$v[ok])
  tau_b2 <- max(0, stats::var(vt$v[ok]) - mean(se2[ok]))
  w <- ifelse(ok, tau_b2 / (tau_b2 + se2), 0)
  vt[, v_shrunk := mu + w * (v - mu)]
  tau <- stats::setNames(sqrt(vt$v_shrunk), vt$party)
  tau_of <- function(p) if (p %in% names(tau)) tau[[p]] else sqrt(mu)
  cat(sprintf("%s  %s: tau from %d earlier election pairs (all jurisdictions, time-forward): %s | all-class %.2f\n",
              code, target, nrow(pr), paste(sprintf("%s %.2f", vt$party, sqrt(vt$v_shrunk)), collapse = " "), sqrt(mu)))

  # ---- polls in the cycle ----
  P <- polls
  if (is.null(P)) P <- suppressMessages(load_polls(region))
  pcols <- attr(P, "parties")
  if (is.null(pcols)) pcols <- setdiff(names(P), c("date", "firm", "tpp_published", "gl_approve", "gl_disapprove"))
  P <- P[P$date > prev_date & P$date < ed]
  sig <- default_sigmas("points")
  s2 <- sig[["sigma_obs"]]^2 + sig[["sigma_rw"]]^2 * as.numeric(ed - P$date)
  col_cls <- vapply(pcols, function(cn) if (cn == "OTH") "OTH" else classify_party(cn, cn), "")

  b <- stats::setNames(vapply(parties, function(p) { v <- st_a[p]; if (length(v) == 1L && is.finite(v)) unname(v) else 0 }, 0), parties)
  b <- 100 * b / sum(b)
  upd <- intersect(setdiff(parties, "OTH"), unique(col_cls))
  out <- b; wpoll <- stats::setNames(rep(0, length(parties)), parties); npoll <- wpoll
  for (p in upd) {
    cols <- pcols[col_cls == p]
    y <- rowSums(as.matrix(P[, cols, with = FALSE]), na.rm = TRUE)
    has <- rowSums(!is.na(as.matrix(P[, cols, with = FALSE]))) > 0
    if (!any(has)) next
    t2 <- tau_of(p)^2
    prec <- 1 / t2 + sum(1 / s2[has])
    out[[p]] <- (b[[p]] / t2 + sum(y[has] / s2[has])) / prec
    wpoll[[p]] <- 1 - (1 / t2) / prec
    npoll[[p]] <- sum(has)
  }
  done <- names(npoll)[npoll > 0]
  rest <- setdiff(parties, done)
  left <- max(0, 100 - sum(out[done]))
  out[rest] <- if (sum(b[rest]) > 0) left * b[rest] / sum(b[rest]) else left / length(rest)
  out <- 100 * out / sum(out)
  cat(sprintf("%s  %s: %d poll(s) between %s and polling day (s = %.1f-pt poll noise + %.2f pts/day drift)\n",
              code, target, nrow(P), as.character(prev_date), sig[["sigma_obs"]], sig[["sigma_rw"]]))
  cat(sprintf("%s  %s THIN-CYCLE level (previous result -> forecast, weight on polls): %s\n", code, target,
              paste(sprintf("%s %.1f->%.1f (n %d, w %.2f)", parties, b, out, as.integer(npoll), wpoll), collapse = " | ")))
  attr(out, "tau") <- tau[intersect(names(tau), parties)]
  attr(out, "n_polls") <- nrow(P)
  attr(out, "w_polls") <- wpoll
  out
}
