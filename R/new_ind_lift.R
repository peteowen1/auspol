# AUSPOL_NEW_IND_LIFT: an ADDITIVE lift for first-time sole independents who carry a pre-election
# signal (Climate 200, Voices, elected councillor or mayor), fitted time-forward on what the model
# PUBLISHED for earlier elections, not on base_pred.
#
# Why (docs/plans/prereg-new-ind-lift-2026-11-09.md): published share under-calls these cells by
# +3 to +7 points at every level of our call (75 cells, 20 elections), while the factor fitted on
# base_pred (prereg-new-ind-shrink-signal-2026-11-09.md, Amendment 1) double counted the trees' own
# signal correction and over-called Lane Cove, Vaucluse, Grey and Hammond. The residual is flat
# across the band, so the shift is a number of points, not a multiplier.
#
# Applied as the LAST share step, after the final nomination zero and level_conserve "final", in
# every harness and in fit_seats_full.R, so it moves exactly the number the fit is measured on.

#' The validated `AUSPOL_NEW_IND_LIFT` switch
#'
#' `"0"` (default) off; `"1"` adds the fitted lift to first-time sole independents with a
#' pre-election signal ([new_ind_lift_fit()]). Anything else is an error.
#'
#' @return `"0"` or `"1"`.
#' @export
new_ind_lift_mode <- function() {
  m <- Sys.getenv("AUSPOL_NEW_IND_LIFT", "0")
  if (!nzchar(m)) m <- "0"
  if (!m %in% c("0", "1"))
    stop("AUSPOL_NEW_IND_LIFT must be \"0\" or \"1\"; got \"", m, "\"", call. = FALSE)
  m
}

.nl_read_published <- function() {
  f <- out_path("published-predictions.csv")
  if (!file.exists(f))
    stop("new_ind_lift_fit() needs ", f, " (scripts/build_published_predictions.R)", call. = FALSE)
  # ours_prelift (scripts/build_published_predictions.R) is the share before this lift; a file from a run with the
  # lift on that lacked it would teach the fit its own correction, so it is used whenever present.
  hdr <- names(data.table::fread(f, nrows = 0L, showProgress = FALSE))
  if ("ours_prelift" %in% hdr) {
    P <- data.table::fread(f, select = c("pair", "seat", "party", "ours_prelift"), showProgress = FALSE)
    data.table::setnames(P, "ours_prelift", "ours")
    P
  } else data.table::fread(f, select = c("pair", "seat", "party", "ours"), showProgress = FALSE)
}

# Mean of u with a cluster-robust SE, clustered by election. c(m, se, G). One election: the
# cell-level SE with G = 1, which the caller scales by a design effect.
.nl_mean <- function(u, el) {
  n <- length(u)
  m <- mean(u)
  G <- length(unique(el))
  if (G >= 2L) {
    U <- tapply(u - m, el, sum)
    se <- sqrt(G / (G - 1) * sum(U^2)) / n
  } else {
    se <- if (n >= 2L) stats::sd(u) / sqrt(n) else NA_real_
  }
  c(m = m, se = se, G = G)
}

#' Fit the signal first-timer lift, time-forward, partially pooled by jurisdiction
#'
#' Training cells: every [new_ind_cells()] cell of a scored election dated strictly before
#' `target` that carries a pre-election signal (`c200`, `voices`, `council_elected` or
#' `council_mayor` above 0, from the stage-1 feature table). The residual is
#' `actual - ours`, `ours` the PUBLISHED share for that election
#' (`output/published-predictions.csv`, as-at models, so each one was a genuine forecast).
#' Per jurisdiction the mean residual is shrunk toward the all-jurisdiction mean,
#' `w = tau^2 / (tau^2 + se_j^2)`, `tau^2` DerSimonian-Laird, `se_j` clustered by election.
#' Unbounded in both directions.
#'
#' @param target Election label; nothing dated on or after it is read.
#' @param corpus,byelection,features,published Optional pre-read tables (`published`:
#'   `pair, seat, party, ours`).
#' @param tau2 `NULL` estimates it; a number forces it.
#' @param prior_max Passed to [new_ind_cells()].
#' @param code,quiet Logging.
#' @return A list: `shift` (points, for the target's jurisdiction), `table`, `pooled`, `tau2`,
#'   `train`.
#' @export
new_ind_lift_fit <- function(target, corpus = NULL, byelection = NULL, features = NULL,
                             published = NULL, tau2 = NULL, prior_max = 10, code = "NL1",
                             quiet = FALSE) {
  C <- .ni_read_corpus(corpus)
  if (is.null(features)) features <- .ni_read_features()
  if (is.null(published)) published <- .nl_read_published()
  FT <- data.table::as.data.table(features)
  FT <- FT[FT$party == "IND", ]
  FT <- FT[.ni_signal(FT), ]
  PB <- data.table::as.data.table(published)
  PB <- PB[PB$party == "IND", c("pair", "seat", "ours")]
  FT <- merge(FT, PB, by = c("pair", "seat"), all.x = TRUE)
  FT[, skey := normalise_seat(seat)]
  trg_region <- sub("[0-9]{4}$", "", target)
  pairs <- unique(FT$pair)
  pairs <- pairs[elections_before(pairs, target)]
  rows <- lapply(pairs, function(E) {
    cl <- new_ind_cells(E, corpus = C, byelection = byelection, prior_max = prior_max, quiet = TRUE)
    if (!nrow(cl)) return(NULL)
    ft <- FT[FT$pair == E, ]
    m <- ft[match(cl$skey, ft$skey), ]
    keep <- !is.na(m$pair)
    if (any(keep & !is.finite(m$ours)))
      stop(sprintf("%s! %s: %d signal first-timer cell(s) have no published share -- published-predictions.csv is not from the same corpus",
                   code, E, sum(keep & !is.finite(m$ours))), call. = FALSE)
    if (!any(keep)) return(NULL)
    data.table::data.table(election = E, region = sub("[0-9]{4}$", "", E), seat = cl$seat[keep],
                           a = m$actual_share[keep], p = m$ours[keep])
  })
  Tr <- data.table::rbindlist(rows)
  if (!nrow(Tr)) {
    if (!quiet) cat(sprintf("%s! %s: no earlier signal first-timer cells; lift 0\n", code, target))
    return(list(shift = 0, table = data.frame(), pooled = NA_real_, tau2 = NA_real_, train = Tr))
  }
  Tr[, u := a - p]
  pool <- .nl_mean(Tr$u, Tr$election)
  deff <- if (is.finite(pool[["se"]]) && pool[["G"]] >= 2) {
    nv <- .nl_mean(Tr$u, seq_len(nrow(Tr)))
    if (is.finite(nv[["se"]]) && nv[["se"]] > 0) pool[["se"]] / nv[["se"]] else 1
  } else 1
  regs <- sort(unique(Tr$region))
  tb <- do.call(rbind, lapply(regs, function(r) {
    d <- Tr[Tr$region == r, ]
    z <- .nl_mean(d$u, d$election)
    se <- if (z[["G"]] < 2) z[["se"]] * deff else z[["se"]]
    data.frame(region = r, n = nrow(d), n_el = z[["G"]], d = z[["m"]], se = se, stringsAsFactors = FALSE)
  }))
  ok <- is.finite(tb$d) & is.finite(tb$se) & tb$se > 0
  tau2_hat <- 0
  if (sum(ok) >= 2L) {
    wi <- 1 / tb$se[ok]^2
    mu_w <- sum(wi * tb$d[ok]) / sum(wi)
    Q <- sum(wi * (tb$d[ok] - mu_w)^2)
    tau2_hat <- max(0, (Q - (sum(ok) - 1)) / (sum(wi) - sum(wi^2) / sum(wi)))
  }
  t2 <- if (is.null(tau2)) tau2_hat else tau2
  tb$w <- ifelse(ok, t2 / (t2 + tb$se^2), 0)
  tb$w[!is.finite(tb$w)] <- 0
  tb$shift <- pool[["m"]] + tb$w * (tb$d - pool[["m"]])
  sh <- if (trg_region %in% tb$region) tb$shift[tb$region == trg_region] else pool[["m"]]
  if (!quiet) {
    cat(sprintf("%s  lift fit for %s: %d signal cell(s) in %d election(s), pooled %+.2f points (se %.2f, design effect %.2f), tau2 %.3f%s\n",
                code, target, nrow(Tr), length(unique(Tr$election)), pool[["m"]], pool[["se"]], deff, t2,
                if (is.null(tau2)) "" else " (FORCED)"))
    for (i in seq_len(nrow(tb)))
      cat(sprintf("%s    %-4s n %3d (%d election%s) | mean %+.2f | se %.2f | w %.3f | shift %+.2f%s\n",
                  code, tb$region[i], tb$n[i], as.integer(tb$n_el[i]), if (tb$n_el[i] == 1) "" else "s",
                  tb$d[i], tb$se[i], tb$w[i], tb$shift[i], if (tb$region[i] == trg_region) "  <- target" else ""))
    if (!trg_region %in% tb$region)
      cat(sprintf("%s    %s has no earlier cells: pooled shift %+.2f used\n", code, trg_region, sh))
  }
  list(shift = sh, table = tb, pooled = pool[["m"]], tau2 = t2, train = Tr)
}

#' Apply the signal first-timer lift to a share matrix
#'
#' Each [new_ind_cells()] cell present in `shares` (class `IND`, share above zero) that carries a
#' pre-election signal gets the fitted shift added, bounded to `[0, row total]`; the seat's other
#' classes are scaled by `(rowsum - new) / (rowsum - old)` so the row total is unchanged. Switch
#' `"0"` returns `shares` itself with no file read, so a run with it off is byte-identical.
#'
#' Called as the last share step (after the final nomination zero and `level_conserve_apply(stage =
#' "final")`) in `backtest_candidate_{fed,vic,nsw,qld,sa,wa,nt}.R` and `scripts/fit_seats_full.R`.
#'
#' @param shares Seats x classes matrix, rownames seats.
#' @param target Election label.
#' @param code Log prefix.
#' @param ... Passed to [new_ind_cells()] / [new_ind_lift_fit()].
#' @return `shares`, with attribute `"new_ind_lift"` (`seat, old, new, shift`) when on.
#' @export
new_ind_lift_apply <- function(shares, target, code = "NL1", ...) {
  if (identical(new_ind_lift_mode(), "0")) return(shares)
  if (!"IND" %in% colnames(shares)) return(shares)
  a <- list(...)
  cells <- do.call(new_ind_cells, c(list(target, code = code),
                                    a[intersect(names(a), c("corpus", "byelection", "prior_max"))]))
  fa <- a[intersect(names(a), c("corpus", "byelection", "features", "published", "tau2", "prior_max"))]
  keys <- data.table::data.table(pair = target, seat = cells$seat, party = "IND")
  sig <- if (nrow(cells)) .ni_signal(council_features(endorsement_features(keys))) else logical(0)
  sh <- do.call(new_ind_lift_fit, c(list(target, code = code), fa))$shift
  rm_ <- match(cells$skey, normalise_seat(rownames(shares)))
  ci <- match("IND", colnames(shares))
  out <- shares
  log <- data.frame(seat = character(0), old = numeric(0), new = numeric(0), shift = numeric(0))
  for (j in which(!is.na(rm_) & sig)) {
    i <- rm_[j]; old <- shares[i, ci]
    if (!(old > 0)) next
    tot <- sum(shares[i, ])
    if (tot - old <= 0) next
    new <- min(tot, max(0, old + sh))
    out[i, ] <- shares[i, ] * (tot - new) / (tot - old)
    out[i, ci] <- new
    log <- rbind(log, data.frame(seat = rownames(shares)[i], old = old, new = new, shift = sh))
  }
  cat(sprintf("%s  AUSPOL_NEW_IND_LIFT=1 for %s: shift %+.2f points applied to %d of %d signal cell(s) (%d first-timer cell(s))\n",
              code, target, sh, nrow(log), sum(sig), nrow(cells)))
  for (j in seq_len(nrow(log)))
    cat(sprintf("%s    %-22s IND %6.2f -> %6.2f\n", code, log$seat[j], log$old[j], log$new[j]))
  attr(out, "new_ind_lift") <- log
  out
}
