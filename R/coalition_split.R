# A Liberal and a National in the same seat, counted as two candidates
# (AUSPOL_COALITION_SPLIT). docs/plans/prereg-lib-nat-two-candidates-2026-10-16.md.
#
# classify_party() files both as `LNP`, so the simulator saw one Coalition
# candidate holding the combined vote and every Coalition vote reached the final
# count. In reality the weaker of the two is excluded and 71% of its votes go to
# the other (207 exclusions, 21 elections); Albany 2013 was lost that way on a
# combined 49.5 against Labor's 39.3. The combined vote is unchanged here; this
# file fits how it divides and how much survives an exclusion, using only
# elections held in an earlier year than the one being predicted.

.cs_cache <- new.env(parent = emptyenv())

#' Which Coalition party a raw party label names
#'
#' @param party_raw Character vector of party labels as the commission printed them.
#' @return `"NAT"`, `"LIB"`, or `NA` for anything else (including the merged
#'   Queensland LNP and the Country Liberals, which field one candidate).
#' @export
coalition_side <- function(party_raw) {
  x <- toupper(trimws(as.character(party_raw)))
  nat <- (grepl("NATIONAL", x) & !grepl("LIBERAL", x)) | x %in% c("NAT", "NP", "NATS")
  lib <- !nat & (grepl("LIBERAL", x) | x %in% c("LIB", "LP")) &
    !grepl("LIBERAL NATIONAL|COUNTRY LIBERAL|DEMOCRAT|LIBERTARIAN", x) & x != "LNP"
  out <- rep(NA_character_, length(x))
  out[nat] <- "NAT"; out[lib] <- "LIB"
  out
}

#' Fit the Coalition split for one election, time-forward
#'
#' Prereg amendment 1: the Nationals' fraction of the Coalition vote in a seat,
#' `fn = NAT / (LIB + NAT)`, predicted by a ridge regression on `logit(fn)`
#' over split seat-elections from EARLIER years, on facts known before the
#' election: the Nationals' fraction of the Coalition vote across the same state
#' at the previous election, each candidate's own previous primary share, which
#' of them (if either) won the seat last time, and the seat's previous split.
#' The junior fraction is `min(fn, 1 - fn)`; its spread is the sd of the
#' out-of-fold residuals.
#'
#' @param target_election Election label, e.g. `"wa2013"`.
#' @param cand The candidacy corpus (`output/candidacies.csv`); read if `NULL`.
#' @param transfers Transfer rows (`election, seat, round, from, to, votes`)
#'   from `external/elections/*-transfers.csv`; read if `NULL`.
#' @return A list: `seats` (data.frame: `seat`, `r` junior fraction centre,
#'   `sd`, `has_prev`, `fn_hat`), `f`, `mu` (mean junior fraction of the
#'   training rows), `s` (sd of the out-of-fold residuals), `lambda`, `n_hist`
#'   (earlier split seat-elections), `n_events` (earlier Coalition-to-Coalition
#'   exclusions), `n_target`. `seats` is empty, and `f` `NA`, when no earlier
#'   election supplies the data -- the split is then not applied.
#' @export
coalition_split_fit <- function(target_election, cand = NULL, transfers = NULL) {
  if (is.null(cand)) cand <- data.table::fread(out_path("candidacies.csv"))
  cand <- data.table::as.data.table(cand)
  tgt_el <- as.character(target_election)
  tgt_year <- as.integer(sub("^[a-z]+", "", tgt_el))
  .yr <- function(e) as.integer(sub("^[a-z]+", "", e))
  .rg <- function(e) sub("[0-9]+$", "", e)
  .nm <- function(x) toupper(trimws(gsub("[[:space:]]+", " ", as.character(x))))

  # Each region's elections in order, to find "the previous election".
  els <- unique(as.character(cand$election))
  el_tab <- data.frame(election = els, region = .rg(els), year = .yr(els), stringsAsFactors = FALSE)
  el_tab <- el_tab[order(el_tab$region, el_tab$year), ]
  el_tab$prev <- stats::ave(el_tab$election, el_tab$region,
                            FUN = function(x) c(NA_character_, utils::head(x, -1)))
  prev_of <- stats::setNames(el_tab$prev, el_tab$election)

  nr <- nrow(cand)
  .col <- function(nm, default) if (nm %in% names(cand)) cand[[nm]] else rep(default, nr)
  co <- data.table::data.table(election = as.character(cand$election), seat = as.character(cand$seat),
                               party = as.character(cand$party), side = coalition_side(cand$party_raw),
                               name = .nm(.col("name", NA_character_)), pcv = as.numeric(cand$pcv),
                               votes = as.numeric(.col("votes", NA_real_)),
                               state = as.character(.col("state", NA_character_)),
                               elected = as.logical(.col("elected", NA)))
  co[, "region" := .rg(get("election"))]
  # A state election's state is its jurisdiction; a federal seat carries its own.
  st <- co$state
  use_region <- co$region != "fed" | is.na(st) | !nzchar(st)
  st[use_region] <- co$region[use_region]
  co[, "state" := toupper(st)]
  winners <- co[co$elected %in% TRUE, c("election", "seat", "name"), with = FALSE]
  cs <- co[co$party == "LNP" & !is.na(co$side)]

  # Nationals' fraction of the Coalition vote across each state at each election.
  cs[, "w" := ifelse(is.na(get("votes")), get("pcv"), get("votes"))]
  sv <- cs[, list(nat = sum(get("w")[get("side") == "NAT"], na.rm = TRUE),
                  all = sum(get("w"), na.rm = TRUE)), by = c("election", "state")]
  sv <- sv[sv$all > 0]
  state_fn <- stats::setNames(sv$nat / sv$all, paste(sv$election, sv$state))
  # Each candidate's own primary share, by (election, name).
  own <- stats::setNames(co$pcv, paste(co$election, co$name))
  own <- own[!duplicated(names(own))]

  # One row per split seat-election (by nominations).
  by_seat <- cs[, list(n_lib = sum(get("side") == "LIB"), n_nat = sum(get("side") == "NAT"),
                       lib = sum(get("pcv")[get("side") == "LIB"], na.rm = TRUE),
                       nat = sum(get("pcv")[get("side") == "NAT"], na.rm = TRUE),
                       st = get("state")[1],
                       lib_name = get("name")[get("side") == "LIB"][1],
                       nat_name = get("name")[get("side") == "NAT"][1]),
                by = c("election", "region", "seat")]
  by_seat <- by_seat[by_seat$n_lib > 0 & by_seat$n_nat > 0]
  by_seat[, "year" := .yr(get("election"))]
  by_seat <- by_seat[by_seat$year <= tgt_year]
  by_seat[, "prev_el" := unname(prev_of[get("election")])]
  tot_c <- by_seat$lib + by_seat$nat
  by_seat[, "fn" := ifelse(tot_c > 0, by_seat$nat / tot_c, NA_real_)]

  # Features: every one is read from the PREVIOUS election.
  by_seat[, "x_state_fn" := unname(state_fn[paste(by_seat$prev_el, by_seat$st)])]
  on <- unname(own[paste(by_seat$prev_el, by_seat$nat_name)])
  ol <- unname(own[paste(by_seat$prev_el, by_seat$lib_name)])
  by_seat[, "x_nat_own" := ifelse(is.na(on), 0, on)]
  by_seat[, "x_nat_stood" := as.numeric(!is.na(on))]
  by_seat[, "x_lib_own" := ifelse(is.na(ol), 0, ol)]
  by_seat[, "x_lib_stood" := as.numeric(!is.na(ol))]
  wk <- stats::setNames(winners$name, paste(winners$election, winners$seat))
  wk <- wk[!duplicated(names(wk))]
  wprev <- unname(wk[paste(by_seat$prev_el, by_seat$seat)])
  by_seat[, "x_nat_sitting" := as.numeric(!is.na(wprev) & wprev == by_seat$nat_name)]
  by_seat[, "x_lib_sitting" := as.numeric(!is.na(wprev) & wprev == by_seat$lib_name)]
  fprev <- stats::setNames(by_seat$fn, paste(by_seat$election, by_seat$seat))
  fp <- unname(fprev[paste(by_seat$prev_el, by_seat$seat)])
  by_seat[, "x_prev_split" := as.numeric(!is.na(fp))]
  by_seat[, "x_prev_fn" := ifelse(is.na(fp), 0, fp)]

  # Target split seats come from NOMINATIONS only; their votes are never read.
  tgt <- by_seat[by_seat$election == tgt_el]
  hist <- by_seat[by_seat$year < tgt_year & !is.na(by_seat$fn)]

  empty <- list(seats = data.frame(seat = character(0), r = numeric(0), sd = numeric(0),
                                   has_prev = logical(0), fn_hat = numeric(0)),
                f = NA_real_, mu = NA_real_, s = NA_real_, lambda = NA_real_,
                n_hist = nrow(hist), n_events = 0L, n_target = nrow(tgt))

  # Coalition-to-Coalition rate from earlier elections' exclusions.
  if (is.null(transfers)) {
    fs <- list.files(file.path("external", "elections"), "transfers[.]csv$", full.names = TRUE)
    transfers <- data.table::rbindlist(lapply(fs, function(f) {
      x <- data.table::fread(f)
      x[, c("election", "seat", "round", "from", "to", "votes"), with = FALSE]
    }), fill = TRUE)
  }
  tx <- data.table::as.data.table(transfers)
  tx <- tx[.yr(tx$election) < tgt_year & tx$from == "LNP"]
  ev <- tx[, list(tot = sum(get("votes")), to_lnp = sum(get("votes")[get("to") == "LNP"])),
           by = c("election", "seat", "round")]
  ev <- ev[ev$to_lnp > 0]
  empty$n_events <- nrow(ev)
  # Fewer than 5 earlier rows cannot be cross-validated (COMPUTATIONAL).
  if (nrow(hist) < 5L || nrow(ev) == 0L) return(empty)
  f <- coalition_f(ev, .rg(tgt_el), Sys.getenv("AUSPOL_COALITION_SPLIT_F", "state"))

  xcols <- c("x_state_fn", "x_nat_own", "x_nat_stood", "x_lib_own", "x_lib_stood",
             "x_nat_sitting", "x_lib_sitting", "x_prev_split", "x_prev_fn")
  # A state with no Coalition votes at the previous election (or no previous
  # election) has no reading: the training mean, not zero (zero would claim the
  # Nationals took nothing there).
  fill <- mean(hist$x_state_fn, na.rm = TRUE)
  if (!is.finite(fill)) fill <- mean(hist$fn)
  .X <- function(d) {
    m <- as.matrix(d[, xcols, with = FALSE])
    m[is.na(m[, "x_state_fn"]), "x_state_fn"] <- fill
    m
  }
  X <- .X(hist)
  y <- stats::qlogis(pmin(pmax(hist$fn, 0.005), 0.995))
  nf <- min(10L, nrow(hist))
  # Folds fixed by row order, not drawn, so the fit draws no random number.
  foldid <- rep_len(seq_len(nf), nrow(hist))
  keep <- apply(X, 2, function(v) stats::var(v) > 0)
  if (sum(keep) < 2L) {
    # glmnet needs two columns; with fewer, the training mean.
    m0 <- stats::plogis(mean(y))
    pred_fn <- function(Z) rep(m0, nrow(Z))
    oof <- vapply(seq_len(nf), function(k) stats::plogis(mean(y[foldid != k])), 0)[foldid]
    lam <- NA_real_
  } else {
    cv <- glmnet::cv.glmnet(X[, keep, drop = FALSE], y, alpha = 0, foldid = foldid,
                            keep = TRUE, grouped = FALSE)
    lam <- cv$lambda.min
    pred_fn <- function(Z) stats::plogis(as.numeric(stats::predict(cv, Z[, keep, drop = FALSE], s = "lambda.min")))
    oof <- stats::plogis(cv$fit.preval[, match(lam, cv$lambda)])
  }
  s <- stats::sd(hist$fn - oof)
  fn_hat <- if (nrow(tgt)) pred_fn(.X(tgt)) else numeric(0)
  r <- pmin(fn_hat, 1 - fn_hat)
  list(seats = data.frame(seat = tgt$seat, r = r, sd = rep(s, length(r)),
                          has_prev = tgt$x_prev_split == 1, fn_hat = fn_hat,
                          stringsAsFactors = FALSE),
       f = f, mu = mean(pmin(hist$fn, 1 - hist$fn)), s = s, lambda = lam,
       n_hist = nrow(hist), n_events = nrow(ev), n_target = nrow(tgt))
}

#' The Coalition-to-Coalition rate for one jurisdiction
#'
#' Prereg amendment 2. `"pooled"`: every earlier exclusion's votes pooled.
#' `"state"`: the jurisdiction's own rate shrunk toward the pooled one by
#' `w = tau^2 / (tau^2 + s^2 / n_J)` (`s^2` the variance of the per-exclusion
#' fraction over all exclusions, `tau^2` between jurisdictions by
#' DerSimonian-Laird, floored at 0).
#'
#' @param ev Exclusions: `election`, `tot`, `to_lnp` (earlier years only).
#' @param jur The target's jurisdiction (`"vic"`, `"fed"`, ...).
#' @param mode `"pooled"` or `"state"`.
#' @return The rate, with attributes `raw`, `n` and `w` under `"state"`.
#' @export
coalition_f <- function(ev, jur, mode = c("pooled", "state")) {
  mode <- match.arg(mode)
  fp <- sum(ev$to_lnp) / sum(ev$tot)
  if (mode == "pooled") return(fp)
  j <- sub("[0-9]+$", "", ev$election)
  fe <- ev$to_lnp / ev$tot
  s2 <- if (length(fe) > 1L) stats::var(fe) else 0
  g <- split(seq_along(j), j)
  n <- vapply(g, length, 0L)
  raw <- vapply(g, function(i) sum(ev$to_lnp[i]) / sum(ev$tot[i]), 0)
  tau2 <- 0
  if (length(g) > 1L && s2 > 0) {
    wi <- n / s2
    mu <- sum(wi * raw) / sum(wi)
    Q <- sum(wi * (raw - mu)^2)
    tau2 <- max(0, (Q - (length(g) - 1)) / (sum(wi) - sum(wi^2) / sum(wi)))
  }
  if (!jur %in% names(raw)) return(structure(fp, raw = NA_real_, n = 0L, w = 0))
  w <- if (tau2 > 0) tau2 / (tau2 + s2 / n[[jur]]) else 0
  structure(fp + w * (raw[[jur]] - fp), raw = raw[[jur]], n = n[[jur]], w = w)
}

#' The `coalition_split` argument for one election's simulation
#'
#' Reads `AUSPOL_COALITION_SPLIT` (default `"1"`, shipped 2026-10-17):
#' anything but `"1"` returns `NULL`, the one-candidate count. Prints, per election, the number of split seats, `f`
#' and the mean centre `r` applied (the prereg's plumbing line, code `LN1`).
#'
#' @param target_election Election label.
#' @param seat_names The simulation's seats, in its order.
#' @param ... Passed to [coalition_split_fit()].
#' @return `NULL`, or a list `r`, `sd` (named by seat, `NA` for no split) and `f`.
#' @export
coalition_split_args <- function(target_election, seat_names, ...) {
  if (!identical(Sys.getenv("AUSPOL_COALITION_SPLIT", "1"), "1")) return(NULL)
  # Cached per election for a call with no inputs supplied: the Victorian
  # harness simulates in a loop, and the fit reads two corpora each time.
  # Keyed on the files' modification times too, so a rebuilt corpus refits.
  dots <- list(...)
  key <- paste(target_election, Sys.getenv("AUSPOL_COALITION_SPLIT_F", "state"),
               file.mtime(out_path("candidacies.csv")),
               max(file.mtime(list.files(file.path("external", "elections"), "transfers[.]csv$",
                                         full.names = TRUE))))
  fit <- if (!length(dots) && !is.null(.cs_cache[[key]])) .cs_cache[[key]] else {
    x <- coalition_split_fit(target_election, ...)
    if (!length(dots)) assign(key, x, envir = .cs_cache)
    x
  }
  r <- stats::setNames(rep(NA_real_, length(seat_names)), seat_names)
  sdv <- r
  hit <- fit$seats$seat[fit$seats$seat %in% seat_names]
  r[hit] <- fit$seats$r[match(hit, fit$seats$seat)]
  sdv[hit] <- fit$seats$sd[match(hit, fit$seats$seat)]
  miss <- setdiff(fit$seats$seat, seat_names)
  cat(sprintf(paste0("LN1 coalition split %s: %d split seat(s) applied of %d nominated",
                     "%s; f=%.3f (%s; %d earlier exclusions); mean r=%.3f; ridge on %d earlier split seats,",
                     " lambda=%.3g, out-of-fold sd=%.3f (training mean junior %.3f)\n"),
              target_election, length(hit), fit$n_target,
              if (length(miss)) paste0(" (not in the simulation: ", paste(miss, collapse = ", "), ")") else "",
              fit$f, if (is.null(attr(fit$f, "w"))) "pooled" else sprintf("state: raw %.3f on %d, weight %.2f", attr(fit$f, "raw"), attr(fit$f, "n"), attr(fit$f, "w")),
              fit$n_events, if (length(hit)) mean(r[hit]) else NA_real_,
              fit$n_hist, fit$lambda, fit$s, fit$mu))
  if (!length(hit) || !is.finite(fit$f)) return(NULL)
  list(r = r, sd = sdv, f = fit$f)
}
