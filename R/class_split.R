# Two candidates of one minor class counted separately (AUSPOL_CLASS_SPLIT).
# docs/plans/prereg-class-split-2026-11-06.md; walkthrough
# docs/reviews/two-candidates-one-class-2026-11-06.md.

.cls_cache <- new.env(parent = emptyenv())

#' The per-candidate predictions file the class split reads
#'
#' `AUSPOL_CLASS_SPLIT_SRC`, default `"minor-candidate-oof-resid-v2.csv"`;
#' `"minor-candidate-oof-resid-v2-sal.csv"` is the model with campaign search
#' interest and backing (`AUSPOL_MC_EXTRA=sal`, prereg amendment 1).
#'
#' @return A file name under `output/`.
#' @export
class_split_src <- function() Sys.getenv("AUSPOL_CLASS_SPLIT_SRC", "minor-candidate-oof-resid-v2.csv")

#' Every same-class exclusion the class split's `f` is fitted from
#'
#' @param dir The elections directory.
#' @param classes Minor classes to keep.
#' @return A data.table `election, seat, round, from, to, votes`, rows whose
#'   `from` is one of `classes`.
#' @export
class_split_transfers <- function(dir = file.path("external", "elections"),
                                  classes = c("IND", "OTH", "OTH_RIGHT")) {
  cols <- c("election", "seat", "round", "from", "to", "votes")
  fs <- list.files(dir, "transfers[.]csv$", full.names = TRUE)
  x <- data.table::rbindlist(lapply(fs, function(f) {
    y <- data.table::fread(f)
    y[y$from %in% classes, cols, with = FALSE]
  }), fill = TRUE)
  data.table::setattr(x, "src", sprintf("%d transfers files", length(fs)))
  x
}

#' Fit the class split for one election
#'
#' For every seat of `target_election` where a minor class has two or more
#' candidates in the per-candidate predictions, the junior fraction
#' r, the second-largest prediction divided by the sum of the class's predictions. Its
#' spread is the root mean squared error of that fraction against the actual
#' one over EARLIER elections' seats, and `f` (the share of an excluded
#' same-class candidate's votes that reach the other) comes from earlier
#' elections' same-class transfers, shrunk by jurisdiction as [coalition_f()].
#' One class per seat: the one whose junior has the largest prediction.
#'
#' @param target_election Election label, e.g. `"sa2022"`.
#' @param oof Per-candidate predictions (`election, seat, cls, share,
#'   pred_xgb`); default the file [class_split_src()] names.
#' @param transfers Same-class exclusions; default [class_split_transfers()].
#' @param classes Minor classes that can be split.
#' @return A list: `seats` (data.frame `seat, cls, r, sd, f, n_cand`), `sd`,
#'   `f` (named by class), `n_hist`, `n_target`, `missing` (TRUE when the
#'   election has no per-candidate predictions).
#' @export
class_split_fit <- function(target_election, oof = NULL, transfers = NULL,
                            classes = c("IND", "OTH", "OTH_RIGHT")) {
  tgt_el <- as.character(target_election)
  .yr <- function(e) as.integer(sub("^[a-z]+", "", e))
  .rg <- function(e) sub("[0-9]+$", "", e)
  tgt_year <- .yr(tgt_el)
  if (is.null(oof)) oof <- data.table::fread(out_path(class_split_src()))
  o <- data.table::as.data.table(oof)
  o <- o[o$cls %in% classes & is.finite(o$pred_xgb)]
  o[, "p" := pmax(get("pred_xgb"), 0.01)]
  data.table::setorderv(o, c("election", "seat", "cls", "p"), c(1L, 1L, 1L, -1L))
  agg <- o[, list(n_cand = .N, sum_p = sum(get("p")), p2 = get("p")[2],
                  j_share = get("share")[2], all_share = sum(get("share"))),
           by = c("election", "seat", "cls")]
  agg <- agg[agg$n_cand >= 2L]
  agg[, "r" := pmin(get("p2") / get("sum_p"), 0.5)]
  agg[, "year" := .yr(get("election"))]
  empty <- list(seats = data.frame(seat = character(0), cls = character(0), r = numeric(0),
                                   sd = numeric(0), f = numeric(0), n_cand = integer(0)),
                sd = NA_real_, f = NA_real_, n_hist = 0L, n_target = 0L,
                missing = !tgt_el %in% o$election)

  hist <- agg[agg$year < tgt_year & is.finite(agg$j_share) & is.finite(agg$all_share) & agg$all_share > 0]
  empty$n_hist <- nrow(hist)
  if (nrow(hist) < 5L) return(empty)
  sdv <- sqrt(mean((hist$j_share / hist$all_share - hist$r)^2))

  f_by <- .cls_f_by(tgt_el, transfers, classes)
  ev_n <- attr(f_by, "n_events")
  # sd and f never depend on the target's own candidates: an election with none (the night split's live vic2026,
  # whose per-candidate predictions are not in the file) still gets them, with no seats
  tgt <- agg[agg$election == tgt_el]
  if (!nrow(tgt)) { empty$sd <- sdv; empty$f <- f_by; return(empty) }
  data.table::setorderv(tgt, c("seat", "p2"), c(1L, -1L))
  tgt <- tgt[!duplicated(tgt$seat)]
  list(seats = data.frame(seat = tgt$seat, cls = tgt$cls, r = tgt$r, sd = rep(sdv, nrow(tgt)),
                          f = unname(f_by[tgt$cls]), n_cand = tgt$n_cand, stringsAsFactors = FALSE),
       sd = sdv, f = f_by, n_hist = nrow(hist), n_target = nrow(tgt), n_events = ev_n,
       missing = FALSE)
}

#' The validated `AUSPOL_CLASS_SPLIT_MODE` switch
#'
#' How the class split sizes the junior candidate: `"pred"` (the 6 Nov
#' design: junior fraction from per-candidate predictions), `"pts_cred"` (the
#' junior's expected vote in points from their credential, divided by the run's
#' own forecast of the class) or `"pts_carry"` (as `pts_cred`, but a candidate
#' with an earlier non-major vote is expected to poll a carried share of it;
#' the default, shipped 2026-11-18).
#' docs/plans/prereg-ind-split-points-2026-11-18.md.
#' @return One of the three modes.
#' @export
class_split_mode <- function() {
  m <- Sys.getenv("AUSPOL_CLASS_SPLIT_MODE", "pts_carry")
  if (!nzchar(m)) m <- "pts_carry"
  if (!m %in% c("pred", "pts_cred", "pts_carry"))
    stop("AUSPOL_CLASS_SPLIT_MODE must be \"pred\", \"pts_cred\" or \"pts_carry\"; got \"", m, "\"", call. = FALSE)
  m
}

#' Which seats the points-mode class split may touch
#'
#' Reads `AUSPOL_CLASS_SPLIT_GATE`: `"none"` (every seat with 2+
#' independents) or `"cred2"` (default, shipped 2026-11-18: only seats where two or more of them have a
#' record: MP, councillor, or an earlier 5%+ non-major vote).
#' docs/plans/prereg-ind-split-points-2026-11-18.md, Amendment 2.
#' @return `"none"` or `"cred2"`.
#' @export
class_split_gate <- function() {
  g <- Sys.getenv("AUSPOL_CLASS_SPLIT_GATE", "cred2")
  if (!nzchar(g)) g <- "cred2"
  if (!g %in% c("none", "cred2"))
    stop("AUSPOL_CLASS_SPLIT_GATE must be \"none\" or \"cred2\"; got \"", g, "\"", call. = FALSE)
  g
}

# `f`, the share of an excluded same-class candidate's votes that reach the other, per class, from EARLIER elections'
# same-class exclusions, shrunk by jurisdiction as coalition_f(). A class with none takes the all-class rate.
# Attribute n_events: how many exclusions it was fitted on.
.cls_f_by <- function(tgt_el, transfers, classes) {
  .yr <- function(e) as.integer(sub("^[a-z]+", "", e))
  .rg <- function(e) sub("[0-9]+$", "", e)
  if (is.null(transfers)) transfers <- class_split_transfers(classes = classes)
  tx <- data.table::as.data.table(transfers)
  tx <- tx[.yr(tx$election) < .yr(tgt_el) & tx$from %in% classes]
  ev <- tx[, list(tot = sum(get("votes")), to_lnp = sum(get("votes")[get("to") == get("from")])),
           by = c("election", "seat", "round", "from")]
  ev <- ev[ev$to_lnp > 0 & ev$tot > 0]
  mode <- Sys.getenv("AUSPOL_COALITION_SPLIT_F", "state")
  f_all <- if (nrow(ev)) coalition_f(ev, .rg(tgt_el), mode) else NA_real_
  f_by <- vapply(classes, function(k) {
    e <- ev[ev$from == k]
    if (nrow(e)) as.numeric(coalition_f(e, .rg(tgt_el), mode)) else as.numeric(f_all)
  }, 0)
  attr(f_by, "n_events") <- nrow(ev)
  f_by
}

# Partial pooling of cell means toward the pooled mean, w = tau^2 / (tau^2 + se^2) (CLAUDE.md: shrinkage, never a
# min_n cliff). `x` values, `g` cell labels; returns the shrunk mean per cell, named.
.cls_shrunk_means <- function(x, g) {
  mu <- mean(x)
  cell <- data.table::data.table(x = x, g = g)[, list(m = mean(x), v = stats::var(x), n = .N), by = "g"]
  v_in <- sum((cell$n - 1) * ifelse(is.finite(cell$v), cell$v, 0)) / max(1, sum(cell$n - 1))
  cell[, "se2" := v_in / get("n")]
  tau2 <- max(0, sum(cell$n * (cell$m - mu)^2) / sum(cell$n) - mean(cell$se2))
  cell[, "w" := if (tau2 > 0) tau2 / (tau2 + get("se2")) else 0]
  stats::setNames(mu + cell$w * (cell$m - mu), cell$g)
}

#' Fit the points-based class split for one election
#'
#' Independents only. For every seat of `target_election` with two or more
#' independents, each candidate's expected vote in points: the shrunk mean vote
#' of NON-LEADING independents with the same credential (`MP`, `councillor`,
#' `prior5`, `none`) at EARLIER elections; under `"pts_carry"` a candidate with
#' an earlier non-major vote instead expects `carry x` that vote, `carry` the
#' ratio of vote to earlier vote over earlier elections' candidates, fitted
#' separately for the same seat and another seat. The junior is the
#' second-highest expectation; the simulator divides its points by the run's own
#' forecast of the class ([simulate_seat_contests()]). `sd` is the root mean
#' squared error of that fraction, computed the same way on earlier elections'
#' seats against our published-path forecast of the class. `f` as
#' [class_split_fit()].
#'
#' @param target_election Election label.
#' @param mode `"pts_cred"` or `"pts_carry"`.
#' @param cand Candidate inputs; default `output/ind-split-candidates.csv`
#'   (scripts/build_ind_split_inputs.R).
#' @param transfers Same-class exclusions; default [class_split_transfers()].
#' @return As [class_split_fit()], with `seats$pts` (the junior's expected
#'   points) and `seats$r` NA, plus `pts` (the credential means) and `carry`.
#' @export
class_split_fit_pts <- function(target_election, mode = class_split_mode(), cand = NULL, transfers = NULL) {
  if (!mode %in% c("pts_cred", "pts_carry")) stop("class_split_fit_pts: mode must be pts_cred or pts_carry")
  tgt_el <- as.character(target_election)
  tgt_year <- as.integer(sub("^[a-z]+", "", tgt_el))
  if (is.null(cand)) cand <- data.table::fread(out_path("ind-split-candidates.csv"), encoding = "UTF-8")
  d <- data.table::as.data.table(cand)
  empty <- list(seats = data.frame(seat = character(0), cls = character(0), r = numeric(0), pts = numeric(0),
                                   sd = numeric(0), f = numeric(0), n_cand = integer(0), n_cred = integer(0)),
                sd = NA_real_, f = NA_real_, n_hist = 0L, n_target = 0L, missing = !tgt_el %in% d$election)
  hist <- d[d$year < tgt_year & is.finite(d$share)]
  if (!nrow(hist)) return(empty)
  data.table::setorderv(hist, c("election", "seat", "share"), c(1L, 1L, -1L))
  hist[, "rank" := seq_len(.N), by = c("election", "seat")]
  # The junior's points grow with the class (checked 18 Nov: +0.091 points per point of our class forecast, t = 9 on
  # 492 seats), so: points = credential intercept + b x class forecast. b from the second-placed independents of
  # earlier elections against our published-path class forecast; the intercepts are the shrunk credential means of
  # what is left.
  jr <- hist[hist$rank == 2L & is.finite(hist$our_cls)]
  if (nrow(jr) < 10L) return(empty)
  b_cls <- max(0, unname(stats::coef(stats::lm(share ~ cred + our_cls, data = jr))["our_cls"]))
  if (!is.finite(b_cls)) b_cls <- 0
  pts_c <- .cls_shrunk_means(jr$share - b_cls * jr$our_cls, jr$cred)
  carry <- c(same = NA_real_, other = NA_real_)
  if (mode == "pts_carry") {
    hc <- hist[is.finite(hist$prior_nonmajor) & hist$prior_nonmajor > 0]
    for (k in c("same", "other")) {
      h <- hc[(hc$prior_same_seat %in% TRUE) == (k == "same")]
      carry[k] <- if (nrow(h)) sum(h$share) / sum(h$prior_nonmajor) else NA_real_
    }
    pooled <- if (nrow(hc)) sum(hc$share) / sum(hc$prior_nonmajor) else NA_real_
    carry[!is.finite(carry)] <- pooled
  }
  c_mid <- stats::median(jr$our_cls)   # the class size used only to ORDER candidates where no forecast is in the file
  # each candidate's expected points as intercept + slope x class: credential (slope b_cls), or carried vote (slope 0)
  expect <- function(x) {
    a <- unname(pts_c[x$cred]); a[!is.finite(a)] <- mean(jr$share - b_cls * jr$our_cls)
    s <- rep(b_cls, nrow(x))
    if (mode == "pts_carry" && all(is.finite(carry))) {
      has <- is.finite(x$prior_nonmajor) & x$prior_nonmajor > 0
      a[has] <- ifelse(x$prior_same_seat[has] %in% TRUE, carry["same"], carry["other"]) * x$prior_nonmajor[has]
      s[has] <- 0
    }
    list(a = a, s = s)
  }
  junior <- function(x) {
    x <- data.table::copy(x)
    ex <- expect(x)
    x[, c("ea", "es") := list(ex$a, ex$s)]
    x[, "eo" := get("ea") + get("es") * ifelse(is.finite(get("our_cls")), get("our_cls"), c_mid)]
    x[, {
      o <- order(-get("eo"), get("name"))[2]
      list(pts = get("ea")[o], pts_b = get("es")[o], jnone = get("cred")[o] == "none", n_cand = .N,
           n_cred = sum(get("cred") != "none"),
           r_act = if (all(is.finite(get("share")))) sort(get("share"), decreasing = TRUE)[2] / sum(get("share")) else NA_real_,
           our_cls = get("our_cls")[1])
    }, by = c("election", "seat")]
  }
  hj <- junior(hist)
  hj <- hj[is.finite(hj$our_cls) & hj$our_cls > 0 & is.finite(hj$r_act)]
  if (nrow(hj) < 5L) return(empty)
  hj[, "r" := pmin(pmax((get("pts") + get("pts_b") * get("our_cls")) / get("our_cls"), 0.01), 0.5)]
  sdv <- sqrt(mean((hj$r_act - hj$r)^2))
  # AMENDMENT 1 (18 Nov, after arm C's refusal; AUSPOL_CLASS_SPLIT_SD = "by_junior"): the spread by the junior's
  # credential (none / any), each the RMSE over earlier seats weighted by our class forecast, so the big-class seats a
  # split can decide dominate; a group with under 5 seats takes the pooled value.
  sd_mode <- Sys.getenv("AUSPOL_CLASS_SPLIT_SD", "pooled")
  if (!sd_mode %in% c("pooled", "by_junior")) stop("AUSPOL_CLASS_SPLIT_SD must be \"pooled\" or \"by_junior\"; got \"", sd_mode, "\"")
  sd_j <- c(none = sdv, cred = sdv)
  if (sd_mode == "by_junior") {
    for (g in c("none", "cred")) {
      h <- hj[hj$jnone == (g == "none")]
      if (nrow(h) >= 5L) sd_j[g] <- sqrt(sum(h$our_cls * (h$r_act - h$r)^2) / sum(h$our_cls))
    }
  }
  f_ind <- unname(.cls_f_by(tgt_el, transfers, "IND")["IND"])
  out <- c(empty[c("seats")], list(sd = sdv, f = stats::setNames(f_ind, "IND"), n_hist = nrow(hj), n_target = 0L,
                                   missing = !tgt_el %in% d$election, pts = pts_c, carry = carry, b = b_cls))
  tg <- d[d$election == tgt_el]
  if (!nrow(tg)) return(out)
  tj <- junior(tg)
  out$seats <- data.frame(seat = tj$seat, cls = "IND", r = NA_real_, pts = tj$pts, pts_b = tj$pts_b,
                          sd = unname(ifelse(tj$jnone, sd_j["none"], sd_j["cred"])), f = f_ind,
                          n_cand = tj$n_cand, n_cred = tj$n_cred, stringsAsFactors = FALSE)
  out$sd_junior <- sd_j
  out$n_target <- nrow(tj)
  out
}

#' The class-split elements of the `coalition_split` argument
#'
#' Reads `AUSPOL_CLASS_SPLIT` (default `"1"`, shipped 2026-11-18): anything but `"1"` returns
#' `NULL`. Prints the plumbing line `CLS1` per election.
#'
#' @param target_election Election label.
#' @param seat_names The simulation's seats, in its order.
#' @return `NULL`, or a list `cls`, `cls_r`, `cls_sd`, `cls_f`, each named by
#'   seat (`NA` where no split).
#' @export
class_split_args <- function(target_election, seat_names) {
  if (!identical(Sys.getenv("AUSPOL_CLASS_SPLIT", "1"), "1")) return(NULL)
  mode <- class_split_mode()
  src <- out_path(class_split_src())
  psrc <- out_path("ind-split-candidates.csv")
  tf <- list.files(file.path("external", "elections"), "transfers[.]csv$", full.names = TRUE)
  key <- paste(target_election, mode, Sys.getenv("AUSPOL_CLASS_SPLIT_SD", "pooled"), src, Sys.getenv("AUSPOL_COALITION_SPLIT_F", "state"),
               if (file.exists(src)) file.mtime(src) else "nofile",
               if (mode != "pred" && file.exists(psrc)) file.mtime(psrc) else "nopts",
               if (length(tf)) max(file.mtime(tf)) else "notx")
  frz <- out_path(sprintf("ind-split-fit-%s.csv", target_election))
  key <- paste(key, if (mode != "pred" && file.exists(frz)) file.mtime(frz) else "nofrozen")
  fit <- .cls_cache[[key]]
  if (is.null(fit)) {
    if (mode == "pred") {
      if (!file.exists(src)) stop("AUSPOL_CLASS_SPLIT=1 needs ", src, " (scripts/fit_minor_candidates.R)")
      fit <- class_split_fit(target_election)
    } else if (file.exists(frz)) {
      # FROZEN FIT for a live election (scripts/build_ind_split_inputs.R): the same class_split_fit_pts() result,
      # written where the transfers corpus exists, so the daily forecast (which has no transfers files) runs it.
      fz <- data.table::fread(frz)
      want_mode <- mode   # never a bare `mode` inside [ ]: fz has a column of that name (CLAUDE.md NSE trap)
      fz <- fz[which(fz[["mode"]] == want_mode)]
      if (!nrow(fz)) stop("CLS2! ", frz, " has no rows for mode ", mode, ": rerun scripts/build_ind_split_inputs.R")
      want_sd <- Sys.getenv("AUSPOL_CLASS_SPLIT_SD", "pooled")
      if (!"sd_mode" %in% names(fz) || !identical(unique(fz[["sd_mode"]]), want_sd))
        stop("CLS2! ", frz, " was built for spread ", paste(unique(fz[["sd_mode"]]), collapse = "/"), ", this run asks for ", want_sd,
             ": rerun scripts/build_ind_split_inputs.R with the same AUSPOL_CLASS_SPLIT_SD")
      if (class_split_gate() != "none" && !"n_cred" %in% names(fz))
        stop("CLS2! ", frz, " has no n_cred column, which AUSPOL_CLASS_SPLIT_GATE=", class_split_gate(),
             " needs: rerun scripts/build_ind_split_inputs.R")
      keep <- intersect(c("seat", "cls", "r", "pts", "pts_b", "sd", "f", "n_cand", "n_cred"), names(fz))
      fit <- list(seats = as.data.frame(fz[, keep, with = FALSE]),
                  sd = fz$sd[1], f = stats::setNames(fz$f[1], "IND"), n_hist = fz$n_hist[1], n_target = nrow(fz),
                  missing = FALSE, b = fz$b[1], carry = c(same = fz$carry_same[1], other = fz$carry_other[1]),
                  pts = stats::setNames(c(fz$i_none[1], fz$i_MP[1], fz$i_prior5[1], fz$i_councillor[1]),
                                        c("none", "MP", "prior5", "councillor")))
      cat(sprintf("CLS2 class split %s: frozen fit %s (%d seats, mode %s)\n", target_election, basename(frz), nrow(fz), mode))
    } else {
      if (!file.exists(psrc)) stop("AUSPOL_CLASS_SPLIT_MODE=", mode, " needs ", psrc, " (scripts/build_ind_split_inputs.R)")
      fit <- class_split_fit_pts(target_election, mode)
    }
    assign(key, fit, envir = .cls_cache)
  }
  na <- stats::setNames(rep(NA_real_, length(seat_names)), seat_names)
  cls <- stats::setNames(rep(NA_character_, length(seat_names)), seat_names)
  r <- na; sdv <- na; f <- na; pts <- na; pts_b <- na
  s <- fit$seats[fit$seats$seat %in% seat_names & is.finite(fit$seats$f), ]
  # AMENDMENT 2 (18 Nov; AUSPOL_CLASS_SPLIT_GATE = "cred2", points modes only): split only where two or more of the
  # seat's independents have a record (MP, councillor, earlier 5%+ non-major vote). A seat whose other independents
  # have no record keeps one class: that is where every ungated split lost (Kooyong 2022, Indi 2025).
  gate <- class_split_gate()
  if (gate == "cred2") {
    if (mode == "pred") stop("AUSPOL_CLASS_SPLIT_GATE=cred2 needs a points mode (AUSPOL_CLASS_SPLIT_MODE=pts_cred or pts_carry)")
    if (!"n_cred" %in% names(s)) stop("CLS3! the class-split fit has no n_cred column: the gate cannot be applied")
    n0 <- nrow(s)
    s <- s[!is.na(s$n_cred) & s$n_cred >= 2L, ]
    cat(sprintf("CLS3 class split %s gate cred2: %d of %d seats kept (2+ independents with a record)%s\n", target_election,
                nrow(s), n0, if (nrow(s)) paste0(": ", paste(utils::head(s$seat, 8), collapse = ", ")) else ""))
  }
  cls[s$seat] <- s$cls; r[s$seat] <- s$r; sdv[s$seat] <- s$sd; f[s$seat] <- s$f
  if (mode != "pred") {
    pts[s$seat] <- s$pts; pts_b[s$seat] <- s$pts_b
    cat(sprintf("CLS2 class split %s mode %s: junior points = intercept by credential %s + %.3f x class forecast%s; mean junior intercept %.2f\n",
                target_election, mode, paste(names(fit$pts), sprintf("%.2f", fit$pts), sep = "=", collapse = " "), fit$b,
                if (mode == "pts_carry") sprintf("; carry same-seat %.3f, other seat %.3f", fit$carry["same"], fit$carry["other"]) else "",
                if (nrow(s)) mean(s$pts) else NA_real_))
  }
  miss <- setdiff(fit$seats$seat, seat_names)
  tab <- table(s$cls)
  cat(sprintf(paste0("CLS1 class split %s: %d seat(s) [%s] of %d with 2+ candidates of one minor class%s%s;",
                     " sd=%.3f on %d earlier seat-classes; f %s; mean r=%.3f\n"),
              target_election, nrow(s), paste(names(tab), tab, sep = "=", collapse = " "), fit$n_target,
              if (isTRUE(fit$missing)) " (NO per-candidate predictions for this election: no class split)" else "",
              if (length(miss)) paste0(" (not in the simulation: ", paste(utils::head(miss, 5), collapse = ", "), ")") else "",
              fit$sd, fit$n_hist,
              if (all(is.na(fit$f))) "none" else paste(names(fit$f), sprintf("%.3f", fit$f), sep = "=", collapse = " "),
              if (nrow(s) && any(is.finite(s$r))) mean(s$r, na.rm = TRUE) else NA_real_))
  if (!nrow(s)) return(NULL)
  if (mode == "pred") return(list(cls = cls, cls_r = r, cls_sd = sdv, cls_f = f))
  list(cls = cls, cls_r = r, cls_sd = sdv, cls_f = f, cls_pts = pts, cls_pts_b = pts_b)
}
