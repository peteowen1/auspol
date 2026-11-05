# Federal polls' state breakdowns inside the state poll trend -------------------
#
# docs/plans/prereg-fed-breakdowns-in-trend-2026-10-26.md ("How a breakdown enters trend_as_at()", steps 1-9).
#
# A breakdown measures FEDERAL vote intention in a state, so it enters the state trend as an extra observation
# with its own house effect, one per federal pollster per federal term (`fed:<firm>:<term>`). Those effects carry
# the federal-to-state offset, get a wide prior (sd 10 points at the party's reference share) and ZERO weight in
# the house-effect sum-to-zero, so the LEVEL stays defined by the state polls and a breakdown contributes only
# the shape of movement within its term. Its observation variance is sigma_obs^2 / r (times a sample-size factor
# under AUSPOL_TREND_FED_N = "1"), and it observes the MEAN of the latent share over its fieldwork days.
#
# Off by default: AUSPOL_TREND_FED_R = "0" makes trend_fed_for() return NULL, and trend_as_at(fed = NULL) runs
# exactly the code it ran before this file existed.

#' Reference state-poll sample for the breakdowns' sample-size factor (prereg step 5)
#'
#' The median observed state-poll sample (`docs/reviews/statewide-poll-samples-2026-10-09.md`).
#' @keywords internal
TREND_FED_N_REF <- 1516

#' Non-sampling share of state-poll noise for the sample-size factor (prereg step 5)
#'
#' 1 minus the sampling variance at `TREND_FED_N_REF` (1.50 points squared at a 35% party) over the 1.7-point
#' state-poll noise squared (2.89).
#' @keywords internal
TREND_FED_LAMBDA <- 0.48

#' Settings of the federal-breakdowns trend arm, from the environment
#'
#' `AUSPOL_TREND_FED_R` (default `"0"` = off): precision of a breakdown relative to a state poll.
#' `AUSPOL_TREND_FED_SRC`: `"shipped"` (`output/fed-state-breakdowns.csv`, Wikipedia, ALP/LNP/GRN, no sample
#' sizes) or `"full"` (`output/fed-state-breakdowns-full.csv`, the four-source union with ONP and state n).
#' `AUSPOL_TREND_FED_N`: `"1"` scales each breakdown's variance by its sample size.
#' `AUSPOL_TREND_FED_PRIOR_SD` (default `"10"`): prior sd of the federal house effects, in points; the
#' prereg's diagnostics B-eq (0.5) and B2-wide20 (20) move it, nothing published does.
#' @return list `r`, `src`, `use_n`, `prior_sd`.
#' @export
trend_fed_config <- function() {
  r <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_TREND_FED_R", "0")))
  if (length(r) != 1L || !is.finite(r) || r < 0) stop("AUSPOL_TREND_FED_R must be a number >= 0, not ", Sys.getenv("AUSPOL_TREND_FED_R"))
  src <- Sys.getenv("AUSPOL_TREND_FED_SRC", "shipped")
  if (!src %in% c("shipped", "full")) stop("AUSPOL_TREND_FED_SRC must be \"shipped\" or \"full\", not ", src)
  nn <- Sys.getenv("AUSPOL_TREND_FED_N", "0")
  if (!nn %in% c("0", "1")) stop("AUSPOL_TREND_FED_N must be \"0\" or \"1\", not ", nn)
  if (nn == "1" && src != "full") stop("AUSPOL_TREND_FED_N=1 needs AUSPOL_TREND_FED_SRC=full (the shipped file has no sample sizes)")
  psd <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_TREND_FED_PRIOR_SD", "10")))
  if (length(psd) != 1L || !is.finite(psd) || psd <= 0) stop("AUSPOL_TREND_FED_PRIOR_SD must be a positive number of points")
  list(r = r, src = src, use_n = identical(nn, "1"), prior_sd = psd)
}

.tf_memo <- new.env(parent = emptyenv())

# The breakdown table for a source, read once per process (keyed on file stamp).
#' @noRd
.trend_fed_table <- function(src) {
  f <- out_path(if (identical(src, "full")) "fed-state-breakdowns-full.csv" else "fed-state-breakdowns.csv")
  if (!file.exists(f)) stop("AUSPOL_TREND_FED_SRC=", src, " needs ", f, " -- run scripts/build_fed_state_breakdowns.R")
  key <- paste(src, file.info(f)$mtime, file.info(f)$size)
  if (!is.null(.tf_memo[[key]])) return(.tf_memo[[key]])
  d <- data.table::fread(f, showProgress = FALSE)
  if (identical(src, "shipped")) {
    # The shipped file carries the fieldwork MIDPOINT (`date`) and END, not the start. mid = start + (end - start)
    # %/% 2, so start = 2 * mid - end recovers it exactly when the span is even and one day early when odd (the
    # inverse is two-valued); immaterial for the 1/L spreading. No One Nation figure and no sample size.
    mid <- as.Date(d$date); en <- as.Date(d$end)
    out <- data.table::data.table(st = d$st, start = as.Date(2L * as.integer(mid) - as.integer(en), origin = "1970-01-01"),
                                  end = en, firm = d$firm, ALP = as.numeric(d$ALP), LNP = as.numeric(d$LNP),
                                  GRN = as.numeric(d$GRN), ONP = NA_real_, n = NA_real_, n_nat = NA_real_)
  } else {
    need <- c("st", "start", "end", "firm", "ALP", "LNP", "GRN", "ONP", "n", "n_nat")
    if (!all(need %in% names(d))) stop(f, " lacks columns: ", paste(setdiff(need, names(d)), collapse = ", "))
    out <- data.table::data.table(st = d$st, start = as.Date(d$start), end = as.Date(d$end), firm = d$firm,
                                  ALP = as.numeric(d$ALP), LNP = as.numeric(d$LNP), GRN = as.numeric(d$GRN),
                                  ONP = as.numeric(d$ONP), n = as.numeric(d$n), n_nat = as.numeric(d$n_nat))
  }
  out <- out[is.finite(out$end)]
  out$start[!is.finite(out$start) | out$start > out$end] <- out$end[!is.finite(out$start) | out$start > out$end]
  alias_f <- file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "firm_alias.csv")
  alias <- if (file.exists(alias_f)) data.table::fread(alias_f, showProgress = FALSE) else data.table::data.table(pattern = character(), canonical = character())
  out$canon <- .ps_canon(out$firm, alias)
  assign(key, out, envir = .tf_memo)
  out
}

# Federal term of each date: the label of the latest federal polling day before it.
#' @noRd
.trend_fed_term <- function(d) {
  ed <- election_dates(); fe <- ed[startsWith(names(ed), "fed")]
  fd <- as.Date(unname(fe)); nm <- names(fe); o <- order(fd); fd <- fd[o]; nm <- nm[o]
  i <- findInterval(as.integer(d) - 1L, as.integer(fd))   # polling day itself belongs to the old term
  ifelse(i > 0L, nm[pmax(i, 1L)], "pre")
}

#' Federal breakdowns admitted to one state cycle's trend as at a date
#'
#' Admission (prereg step 1): this state, fieldwork STARTED after the previous state election (`cycle_start`),
#' fieldwork ENDED before `as_at`. Returns `NULL` when the arm is off, for a federal target, or with nothing
#' admitted. The variance multiplier `vmult` is `1 / r`, times `lambda + (1 - lambda) * n_ref / n_i` under
#' `AUSPOL_TREND_FED_N = "1"`, with a missing `n_i` imputed from data that ended before `as_at` (step 5).
#'
#' @param region Poll region (`"vic"`, ...). `"fed"` always returns `NULL`.
#' @param as_at Cutoff date (breakdowns must have ENDED before it).
#' @param cycle_start The previous state election's polling day.
#' @param cfg [trend_fed_config()].
#' @return data.table (`start`, `end`, `firm`, `canon`, `term`, `ALP`, `LNP`, `GRN`, `ONP`, `n`, `n_used`,
#'   `n_how`, `vmult`) with attribute `prior_sd`, or `NULL`.
#' @export
trend_fed_for <- function(region, as_at, cycle_start, cfg = trend_fed_config()) {
  if (cfg$r <= 0 || identical(region, "fed")) return(NULL)
  as_at <- as.Date(as_at); cycle_start <- as.Date(cycle_start)
  tab <- .trend_fed_table(cfg$src)
  reg <- region
  before <- tab[tab$end < as_at]                       # everything known as at the cutoff (for imputation)
  f <- before[before$st == reg & before$start > cycle_start]
  if (!nrow(f)) return(NULL)
  stopifnot(all(f$end < as_at), all(f$start > cycle_start))
  f$term <- .trend_fed_term(f$end)
  f$n_used <- f$n; f$n_how <- ifelse(is.finite(f$n), "own", NA_character_)
  if (cfg$use_n) {
    sb <- before[before$st == reg & is.finite(before$n)]
    miss <- which(!is.finite(f$n_used))
    for (i in miss) {
      fi <- f$canon[i]
      m1 <- sb$n[sb$canon == fi]
      if (length(m1)) { f$n_used[i] <- stats::median(m1); f$n_how[i] <- "firm-state median"; next }
      nat <- if (is.finite(f$n_nat[i])) f$n_nat[i] else stats::median(before$n_nat[before$canon == fi & is.finite(before$n_nat)])
      rat <- sb$n / sb$n_nat; rat <- rat[is.finite(rat) & rat > 0]
      if (length(nat) && is.finite(nat) && length(rat)) { f$n_used[i] <- nat * stats::median(rat); f$n_how[i] <- "national x state ratio"; next }
      if (nrow(sb)) { f$n_used[i] <- stats::median(sb$n); f$n_how[i] <- "state median"; next }
      f$n_used[i] <- TREND_FED_N_REF; f$n_how[i] <- "n_ref"
    }
    fac <- TREND_FED_LAMBDA + (1 - TREND_FED_LAMBDA) * TREND_FED_N_REF / f$n_used
    stopifnot(all(is.finite(fac)), all(fac > 0))
  } else fac <- rep(1, nrow(f))
  f$vmult <- fac / cfg$r
  data.table::setattr(f, "prior_sd", cfg$prior_sd)
  data.table::setattr(f, "as_at", as_at)
  data.table::setattr(f, "cycle_start", cycle_start)
  f
}

# Which breakdown classes enter which party fits (prereg step 2), and the latent-walk end date. Asserts admission
# again on what trend_as_at() was actually handed, so a caller cannot slip a late row past it.
#' @noRd
.trend_fed_gate <- function(fed, cp2, ps, as_at, verbose = TRUE) {
  as_at <- as.Date(as_at)
  late <- which(!(as.Date(fed$end) < as_at))
  if (length(late)) {
    stop(sprintf("TF0! %d federal breakdown(s) handed to trend_as_at() did not end before the as-at date %s (latest end %s). A forecast cannot see a poll still in the field.",
                 length(late), format(as_at), format(max(as.Date(fed$end)))), call. = FALSE)
  }
  cs <- as.Date(attr(cp2, "cycle_start"))
  early <- which(!(as.Date(fed$start) > cs))
  if (length(early)) stop(sprintf("TF0! %d federal breakdown(s) started on or before the cycle start %s", length(early), format(cs)), call. = FALSE)
  cls <- intersect(c("ALP", "LNP", "GRN", "ONP"), ps)
  dropped <- character(0)
  if ("LNP" %in% cls && any(c("NAT", "LIB") %in% ps)) {
    cls <- setdiff(cls, "LNP"); dropped <- "LNP (state polls fit Liberal and National separately)"
  }
  obs <- list()
  for (p in cls) {
    v <- fed[[p]]; ok <- is.finite(v)
    if (!any(ok)) next
    o <- data.table::data.table(start = as.Date(fed$start[ok]), end = as.Date(fed$end[ok]), firm = fed$canon[ok],
                                term = fed$term[ok], y = v[ok], vmult = fed$vmult[ok])
    data.table::setattr(o, "prior_sd", attr(fed, "prior_sd"))
    obs[[p]] <- o
  }
  if (!length(obs)) return(NULL)
  # Where each party's walk ends. Without breakdowns a party's series ends at its own last state poll, and the
  # published level reads the parties that reach the LATEST of those days (D); a fitted party whose last poll is
  # earlier is folded into the others downstream (statewide_draws_as_at(): nsw2023 One Nation, day before). The
  # arm must not change that, or it would move levels through the folding rather than through the breakdowns. So
  # the parties that reach D are all moved, together, to E = the later of D and the newest admitted breakdown;
  # a party that ends before D keeps its end, and its breakdowns that ended after it are left out (printed).
  own_end <- vapply(ps, function(p) {
    d <- if (p %in% names(cp2)) cp2$date[!is.na(cp2[[p]])] else cp2$date[0]
    if (length(d)) as.integer(max(d)) else NA_integer_ }, 1L)
  D <- max(own_end, na.rm = TRUE)
  own_end[is.na(own_end)] <- D
  E <- max(D, max(vapply(obs, function(o) as.integer(max(o$end)), 1L)))
  t_end <- lapply(ps, function(p) if (own_end[[p]] == D && E > D) as.Date(E, origin = "1970-01-01") else NULL)
  names(t_end) <- ps
  cut_n <- 0L
  for (p in names(obs)) if (own_end[[p]] < D) {
    keep <- as.integer(obs[[p]]$end) <= own_end[[p]]
    cut_n <- cut_n + sum(!keep)
    o <- obs[[p]][keep]; data.table::setattr(o, "prior_sd", attr(fed, "prior_sd"))
    obs[[p]] <- if (nrow(o)) o else NULL
  }
  obs <- obs[!vapply(obs, is.null, TRUE)]
  if (!length(obs)) return(NULL)
  if (verbose) cat(sprintf("TF1  federal breakdowns in the trend: %s; latent walk %s%s%s\n",
                           paste(sprintf("%s %d", names(obs), vapply(obs, nrow, 1L)), collapse = ", "),
                           if (E > D) sprintf("extended %s -> %s", format(as.Date(D, origin = "1970-01-01")), format(as.Date(E, origin = "1970-01-01"))) else "unchanged",
                           if (cut_n) sprintf("; %d breakdowns after a short party's last poll left out", cut_n) else "",
                           if (length(dropped)) paste0("; left out: ", dropped) else ""))
  list(obs = obs, t_end = t_end, dropped = dropped)
}

# Append a party's admitted breakdowns to a prepared cycle (prereg steps 3, 4, 6). Also extends the latent walk to
# t_end so every party's series ends on the same day.
#' @noRd
prep_add_fed <- function(prep, fo, t_end, min_firm_polls = 3) {
  if (!is.null(t_end)) {
    T_new <- as.integer(as.Date(t_end) - prep$start) + 1L
    if (T_new > prep$T_) { prep$T_ <- T_new; prep$days <- seq.int(0L, T_new - 1L) }
  }
  if (is.null(fo) || !nrow(fo)) return(prep)
  ts <- as.integer(fo$start - prep$start) + 1L
  te <- as.integer(fo$end - prep$start) + 1L
  if (any(ts < 1L) || any(te < ts) || any(te > prep$T_)) stop("prep_add_fed(): a breakdown's fieldwork falls outside the latent walk")
  lab <- paste0("fed:", fo$firm, ":", fo$term)
  cnt <- table(lab)
  small <- names(cnt)[cnt < min_firm_polls]
  lab[lab %in% small] <- paste0("fed:(other firms):", fo$term[lab %in% small])
  ffirms <- sort(unique(lab))
  tr <- to_link(fo$y, prep$scale)
  psd <- attr(fo, "prior_sd"); if (is.null(psd)) psd <- 10
  prep$fed <- list(y = tr$z, ts = ts, te = te, tm = (ts + te) %/% 2L, jf = match(lab, ffirms), firms = ffirms,
                   J = length(ffirms), vmult = fo$vmult, n = nrow(fo), y_pct = fo$y,
                   sigma_house = sd_to_link(psd, prep$p_ref, prep$scale), prior_sd = psd)
  prep$J_state <- prep$J
  prep$J <- prep$J + length(ffirms)
  prep$log_jac <- prep$log_jac + log_jacobian(fo$y, prep$scale)
  prep
}

# Prior system with federal house effects: as trend_prior_system(), plus Jf effects with their own prior and NO
# weight in the sum-to-zero (which runs over the state firms alone, exactly as without breakdowns).
#' @noRd
.trend_prior_system_fed <- function(prep, sigma_rw, sigma_house, anchor, szc_sd) {
  T_ <- prep$T_; Js <- prep$J_state; Jf <- prep$fed$J
  n_par <- T_ + Js + Jf
  ijx <- list()
  add <- function(i, j, x) ijx[[length(ijx) + 1L]] <<- data.frame(i = i, j = j, x = x)
  w_rw <- 1 / sigma_rw^2
  tt <- seq_len(T_ - 1L)
  add(tt, tt, rep(w_rw, T_ - 1L)); add(tt + 1L, tt + 1L, rep(w_rw, T_ - 1L))
  add(tt, tt + 1L, rep(-w_rw, T_ - 1L)); add(tt + 1L, tt, rep(-w_rw, T_ - 1L))
  add(1L, 1L, 1 / anchor$sd^2)
  b0 <- numeric(n_par); b0[1L] <- anchor$val / anchor$sd^2
  hj <- T_ + seq_len(Js)
  add(hj, hj, rep(1 / sigma_house^2, Js))
  hf <- T_ + Js + seq_len(Jf)
  add(hf, hf, rep(1 / prep$fed$sigma_house^2, Jf))
  wj <- prep$obs[, .N, by = j][order(j), N] / nrow(prep$obs)
  if (identical(Sys.getenv("AUSPOL_TREND_SZC", "polls"), "firms")) wj <- rep(1 / Js, Js)
  w_szc <- 1 / szc_sd^2
  add(rep(hj, each = Js), rep(hj, times = Js), as.vector(outer(wj, wj)) * w_szc)
  ijx <- do.call(rbind, ijx)
  P <- Matrix::sparseMatrix(i = ijx$i, j = ijx$j, x = ijx$x, dims = c(n_par, n_par))
  list(P = Matrix::forceSymmetric(P), b0 = b0, szc_w = c(wj, rep(0, Jf)))
}

# Observation matrix with breakdown rows spread 1/L over their L fieldwork days.
#' @noRd
.trend_obs_matrix_fed <- function(prep) {
  n <- nrow(prep$obs); f <- prep$fed; T_ <- prep$T_; Js <- prep$J_state
  L <- f$te - f$ts + 1L
  ii <- rep(n + seq_len(f$n), L)
  jj <- unlist(Map(seq.int, f$ts, f$te), use.names = FALSE)
  Matrix::sparseMatrix(
    i = c(seq_len(n), seq_len(n), ii, n + seq_len(f$n)),
    j = c(prep$obs$t, T_ + prep$obs$j, jj, T_ + Js + f$jf),
    x = c(rep(1, 2L * n), rep(1 / L, L), rep(1, f$n)),
    dims = c(n + f$n, T_ + prep$J)
  )
}

# House-effect table for a fit with breakdowns: state firms as fit_trend() reports them, plus one row per federal
# (firm, term) effect with its posterior sd.
#' @noRd
.trend_fed_house <- function(prep, sol, mu, scale) {
  T_ <- prep$T_; Js <- prep$J_state; f <- prep$fed
  hj <- T_ + seq_len(Js)
  obs_t_by_firm <- split(prep$obs$t, prep$obs$j)[as.character(seq_len(Js))]
  st <- data.table::data.table(firm = prep$firms[seq_len(Js)], effect = sol$theta[hj],
                               sd = if (is.null(sol$sds)) NA_real_ else sol$sds[hj],
                               n_polls = prep$obs[, .N, by = j][order(j), N], kind = "state")
  st[, effect_pts := vapply(seq_len(.N), function(k) {
    mu_k <- mu[obs_t_by_firm[[k]]]; mean(from_link(mu_k + effect[k], scale) - from_link(mu_k, scale))
  }, numeric(1))]
  hf <- T_ + Js + seq_len(f$J)
  tm_by <- split(f$tm, f$jf)[as.character(seq_len(f$J))]
  fe <- data.table::data.table(firm = f$firms, effect = sol$theta[hf], sd = sol$fed_sd,
                               n_polls = tabulate(f$jf, nbins = f$J), kind = "fed")
  fe[, effect_pts := vapply(seq_len(.N), function(k) {
    mu_k <- mu[tm_by[[k]]]; mean(from_link(mu_k + effect[k], scale) - from_link(mu_k, scale))
  }, numeric(1))]
  # posterior sd in points at the firm's own level (delta method), for the printed offsets
  fe[, sd_pts := vapply(seq_len(.N), function(k) {
    p <- from_link(mean(mu[tm_by[[k]]]) + effect[k], scale); sd_from_link(sd[k], p, scale)
  }, numeric(1))]
  st[, sd_pts := NA_real_]
  rbind(st, fe)
}

#' Federal breakdowns for a cycle, as the published callers pass them to trend_as_at()
#'
#' [trend_fed_for()] with the cycle start looked up from the election calendar. `NULL` when the arm is off, so
#' `trend_as_at(..., fed = trend_fed_for_cycle(...))` is byte-identical to the call without it. Used by
#' `scripts/fit_seats_full.R`, `scripts/build_trend_page_data.R` and `scripts/build_page.R` (prereg step 9), and
#' by [statewide_draws_as_at()] through the same [trend_fed_for()].
#' @param region,year The cycle.
#' @param as_at Cutoff date.
#' @param cycles [load_election_cycles()]; loaded when NULL.
#' @return As [trend_fed_for()].
#' @export
trend_fed_for_cycle <- function(region, year, as_at, cycles = NULL) {
  cfg <- trend_fed_config()
  if (cfg$r <= 0 || identical(region, "fed")) return(NULL)
  if (is.null(cycles)) cycles <- load_election_cycles()
  reg <- region; yr <- year
  cs <- cycles$start[cycles$region == reg & cycles$year == yr]
  if (length(cs) != 1L) stop("trend_fed_for_cycle(): no unique cycle for ", region, year)
  trend_fed_for(region, as_at, min(as.Date(cs)), cfg)
}
