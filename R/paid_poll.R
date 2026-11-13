# Arm PPC: party- and advocacy-paid statewide polls get a shrunk lean toward the sponsor's side and extra noise
# (docs/plans/prereg-paid-poll-correction-2026-11-13.md; Pete, 13 Nov 2026: "Shrinkage or better method. Don't just
# add as is"). Learned from POLLS ONLY: each paid poll against the independent polls of its region fielded within
# 21 days, all dated on or before the cutoff, so nothing after the forecast date and no election result reaches it.
#
# Which polls are paid: poll_sponsor_class() == "party" (a party or advocacy client on the matched Wikipedia row).
# Their side: the first row of external/reference/polls/sponsor_side.csv whose pattern hits the client text.

PAID_POLL_WINDOW <- 21L       # days either side of a poll's midpoint for its independent reference polls
PAID_POLL_MIN_REF <- 2L       # independent polls needed for a reference
PAID_POLL_BASE_FROM <- as.Date("2025-01-01")   # baseline v0 from independent polls of the era sponsors are recorded

#' Sponsor side of each paid poll
#'
#' @param sponsor Client text per poll (`attr(poll_sponsor_class(), "sponsor")`).
#' @param path The side table.
#' @return Character: `"LNP"`, `"ALP"`, `"GRN"`, `"ALP+GRN"`, `"IND"`, or `"UNKNOWN"` for a client no row
#'   matches; `NA` where `sponsor` is empty.
#' @keywords internal
paid_poll_side <- function(sponsor, path = file.path(pkg_root(), "external", "reference", "polls", "sponsor_side.csv")) {
  tab <- data.table::fread(path, showProgress = FALSE)
  stopifnot(all(c("pattern", "side") %in% names(tab)), nrow(tab) > 0,
            all(tab$side %in% c("LNP", "ALP", "GRN", "ALP+GRN", "IND", "UNKNOWN")))
  s <- tolower(ifelse(is.na(sponsor), "", sponsor))
  out <- rep(NA_character_, length(s))
  for (i in seq_len(nrow(tab))) {
    hit <- is.na(out) & nzchar(s) & grepl(tab$pattern[i], s, perl = TRUE)
    out[hit] <- tab$side[i]
  }
  out[is.na(out) & nzchar(s)] <- "UNKNOWN"
  out
}

# The parties a side's lean is measured on, among the columns present.
#' @noRd
.ppc_side_parties <- function(side, cols) {
  p <- switch(side, "ALP+GRN" = c("ALP", "GRN"), "IND" = if ("IND" %in% cols) "IND" else "OTH", side)
  if (side %in% c("UNKNOWN", NA)) return(character(0))
  intersect(p, cols)
}

#' Deviations of every poll from its independent neighbours, as of a cutoff
#'
#' @param polls From [load_polls()].
#' @param cls,sponsor From [poll_sponsor_class()] for `polls` (class and client text).
#' @param as_at Cutoff: only polls dated on or before it, as subject or reference.
#' @param parties Party columns to measure.
#' @return data.table, one row per poll and party with a reference: `i` (row of `polls`), `date`, `firm`, `paid`,
#'   `side`, `party`, `value`, `ref`, `d` (= value - ref), `n_ref`.
#' @keywords internal
paid_poll_deviations <- function(polls, cls, sponsor, as_at, parties = c("ALP", "LNP", "GRN", "ONP", "OTH")) {
  stopifnot(length(cls) == nrow(polls), length(sponsor) == nrow(polls))
  cols <- intersect(parties, names(polls))
  pd <- polls$date
  paid <- cls == "party"
  # subjects: every paid poll, and independent polls of the era sponsors are recorded (the baseline's era); any
  # independent poll can still be a reference
  keep <- which(is.finite(pd) & pd <= as_at)
  subj <- keep[paid[keep] | pd[keep] >= PAID_POLL_BASE_FROM]
  side <- ifelse(paid, paid_poll_side(sponsor), NA_character_)
  side[paid & is.na(side)] <- "UNKNOWN"
  indep <- keep[cls[keep] %in% c("media", "unknown")]   # any other class (a placebo's "excluded") is neither
  out <- vector("list", length(subj))
  for (k in seq_along(subj)) {
    i <- subj[k]
    near <- indep[indep != i & abs(as.integer(pd[indep] - pd[i])) <= PAID_POLL_WINDOW]
    if (length(near) < PAID_POLL_MIN_REF) next
    rows <- lapply(cols, function(p) {
      x <- polls[[p]][i]; r <- polls[[p]][near]; r <- r[is.finite(r)]
      if (!is.finite(x) || length(r) < PAID_POLL_MIN_REF) return(NULL)
      data.table::data.table(i = i, party = p, value = x, ref = mean(r), n_ref = length(r))
    })
    out[[k]] <- data.table::rbindlist(rows)
  }
  dv <- data.table::rbindlist(out)
  if (!nrow(dv)) return(dv)
  dv[, `:=`(date = pd[dv$i], firm = polls$firm[dv$i], paid = paid[dv$i], side = side[dv$i], d = dv$value - dv$ref)]
  # `i` is a row of THIS region's table; `uid` stays unique when regions are pooled (review, 13 Nov)
  dv[, uid := paste(if (is.null(attr(polls, "region"))) "?" else attr(polls, "region"), dv$i, sep = ":")]
  dv[]
}

#' Fit the paid-poll lean and noise from deviations
#'
#' @param dv From [paid_poll_deviations()], pooled over regions.
#' @return List: `lean` (data.table per side: `n`, `m` raw mean side gap, `se`, `w`, `shrunk`), `mu`, `se_mu`, `w0`, `mu_s` (pooled shrunk lean, for a side with no row),
#'   `tau2`, `v0` (mean squared independent deviation per cell, points^2), `x2` (extra variance, shrunk), `factor`
#'   (noise sd multiplier for paid polls), `n_paid`.
#' @keywords internal
paid_poll_fit <- function(dv) {
  if (!nrow(dv)) dv <- data.table::data.table(uid = character(0), party = character(0), value = numeric(0),
                                              date = as.Date(character(0)), paid = logical(0), side = character(0),
                                              d = numeric(0))   # no deviations at all: the empty fit below
  base <- dv[!dv$paid & dv$date >= PAID_POLL_BASE_FROM]
  v0 <- if (nrow(base)) mean(base$d^2) else NA_real_
  pp <- dv[dv$paid]
  n_paid <- data.table::uniqueN(pp$uid)
  empty <- list(lean = data.table::data.table(side = character(0), n = integer(0), m = numeric(0), se = numeric(0),
                                              w = numeric(0), shrunk = numeric(0)),
                mu = 0, se_mu = NA_real_, w0 = 0, mu_s = 0, tau2 = 0, v0 = v0, x2 = 0, factor = 1, n_paid = n_paid)
  if (!n_paid || !is.finite(v0)) return(empty)
  # side gap per paid poll, and the same side gap for every independent poll (its baseline variance)
  side_gap <- function(tab, sd_) {
    sp <- .ppc_side_parties(sd_, unique(tab$party))
    if (!length(sp)) return(NULL)
    g <- tab[tab$party %in% sp, list(gap = sum(d), np = .N), by = "uid"]
    g[g$np == length(sp)]
  }
  sides <- setdiff(unique(pp$side), "UNKNOWN")
  lean <- data.table::rbindlist(lapply(sides, function(sd_) {
    g <- side_gap(pp[pp$side == sd_], sd_); b <- side_gap(base, sd_)
    if (is.null(g) || !nrow(g) || is.null(b) || nrow(b) < 10L) return(NULL)
    data.table::data.table(side = sd_, n = nrow(g), m = mean(g$gap), se = sqrt(mean(b$gap^2) / nrow(g)))
  }))
  fit <- empty
  if (nrow(lean)) {
    wt <- 1 / lean$se^2
    mu <- sum(wt * lean$m) / sum(wt); se_mu <- 1 / sqrt(sum(wt))
    k <- nrow(lean)
    tau2 <- if (k > 1L) max(0, (sum(wt * (lean$m - mu)^2) - (k - 1)) / (sum(wt) - sum(wt^2) / sum(wt))) else 0
    w0 <- mu^2 / (mu^2 + se_mu^2)
    mu_s <- w0 * mu
    lean[, w := tau2 / (tau2 + lean$se^2)]
    lean[, shrunk := mu_s + lean$w * (lean$m - mu_s)]
    fit$lean <- lean; fit$mu <- mu; fit$se_mu <- se_mu; fit$w0 <- w0; fit$mu_s <- mu_s; fit$tau2 <- tau2
  }
  # extra noise: paid polls' squared gaps after the lean, beyond the independent baseline
  ln <- .ppc_leans(fit, unique(pp$side))
  r <- pp$d
  for (sd_ in names(ln)) {
    ix <- which(pp$side == sd_)
    if (!length(ix) || ln[[sd_]] == 0) next
    sp <- .ppc_side_parties(sd_, unique(pp$party))
    on <- pp$party[ix] %in% sp
    # the lean comes off the side's parties (split by share) and goes to the rest (split by share)
    sh <- pp$value[ix]
    tot_on <- ave(ifelse(on, sh, 0), pp$uid[ix], FUN = sum); tot_off <- ave(ifelse(on, 0, sh), pp$uid[ix], FUN = sum)
    adj <- ifelse(on, -ln[[sd_]] * sh / pmax(tot_on, 1e-9), ln[[sd_]] * sh / pmax(tot_off, 1e-9))
    r[ix] <- r[ix] + adj
  }
  x2 <- max(0, mean(r^2) - v0) * n_paid / (n_paid + 3)
  fit$x2 <- x2
  fit$factor <- sqrt(1 + x2 / v0)
  fit
}

#' The lean taken off each side: its own shrunk lean, or the pooled shrunk lean `mu_s` for a known side the fit has
#' no row for (no independent polls in reach, or a new sponsor side), as partial pooling gives a cell with no data.
#' UNKNOWN and missing sides get none: the direction is not known.
#' @keywords internal
.ppc_leans <- function(fit, sides) {
  sides <- setdiff(unique(sides[!is.na(sides)]), "UNKNOWN")
  mu_s <- if (is.null(fit$mu_s) || !is.finite(fit$mu_s)) 0 else fit$mu_s
  own <- setNames(fit$lean$shrunk, fit$lean$side)
  setNames(vapply(sides, function(s) if (s %in% names(own) && is.finite(own[[s]])) own[[s]] else mu_s, 1), sides)
}

#' Apply the paid-poll correction to one region's polls
#'
#' @param polls From [load_polls()] (the region being forecast).
#' @param cls,sponsor From [poll_sponsor_class()] for `polls`.
#' @param fit From [paid_poll_fit()].
#' @param as_at Cutoff; paid polls after it are left alone (the trend never sees them).
#' @param sides `NULL` (read `sponsor_side.csv` via [paid_poll_side()]) or the side of every row of `polls`.
#' @return List: `polls` (paid polls shifted and relabelled `"<firm> [paid]"`), `firm_factors` (named, the paid
#'   labels at `fit$factor`; `NULL` when no paid poll is in reach), `moved` (data.table of what changed).
#' @keywords internal
paid_poll_apply <- function(polls, cls, sponsor, fit, as_at, sides = NULL) {
  out <- data.table::copy(polls)
  for (a in c("parties", "region")) data.table::setattr(out, a, attr(polls, a))
  ix <- which(cls == "party" & is.finite(polls$date) & polls$date <= as_at)
  if (!length(ix)) return(list(polls = out, firm_factors = NULL, moved = data.table::data.table()))
  side <- if (is.null(sides)) paid_poll_side(sponsor[ix]) else sides[ix]
  ln <- .ppc_leans(fit, side)
  cols <- intersect(c("ALP", "LNP", "GRN", "ONP", "OTH", "IND"), names(polls))
  moved <- vector("list", length(ix))
  for (k in seq_along(ix)) {
    i <- ix[k]; sd_ <- side[k]
    before <- unlist(polls[i, cols, with = FALSE])
    if (sd_ %in% names(ln) && is.finite(ln[[sd_]]) && ln[[sd_]] != 0) {
      sp <- .ppc_side_parties(sd_, cols)
      x <- before
      on <- names(x) %in% sp & is.finite(x); off <- !names(x) %in% sp & is.finite(x)
      if (any(on) && any(off)) {
        x[on] <- x[on] - ln[[sd_]] * x[on] / sum(x[on])
        x[off] <- x[off] + ln[[sd_]] * x[off] / sum(x[off])
        for (p in names(x)[on | off]) data.table::set(out, i = i, j = p, value = unname(x[[p]]))
      }
    }
    lab <- paste0(polls$firm[i], " [paid]")
    data.table::set(out, i = i, j = "firm", value = lab)
    after <- unlist(out[i, cols, with = FALSE])
    moved[[k]] <- data.table::data.table(date = polls$date[i], firm = lab, side = sd_, party = cols,
                                         before = unname(before), after = unname(after))
  }
  labs <- unique(paste0(polls$firm[ix], " [paid]"))
  list(polls = out, firm_factors = setNames(rep(fit$factor, length(labs)), labs), moved = data.table::rbindlist(moved))
}

#' Whether the paid-poll correction is on (`AUSPOL_PAID_POLL_CORRECT`, shipped "1" on 13 Nov 2026)
#' @keywords internal
paid_poll_mode <- function() {
  v <- Sys.getenv("AUSPOL_PAID_POLL_CORRECT", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_PAID_POLL_CORRECT must be \"0\" or \"1\", not ", v)
  v == "1"
}

.ppc_cache <- new.env(parent = emptyenv())
PAID_POLL_REGIONS <- c("fed", "nsw", "vic", "qld", "wa", "sa", "nt", "tas", "act")

#' Paid-poll correction for one region's polls as of a cutoff, as trend_as_at() applies it
#'
#' Sponsor classes come from the Wikipedia poll table the poll layer reads ([poll_wiki_path()]); the lean and noise
#' are fitted on the paid polls of EVERY region up to `as_at` ([paid_poll_fit()]), cached per process by cutoff, table
#' and its mtime. With no paid poll of this region dated on or before `as_at`, nothing is fitted and the polls come
#' back unchanged.
#' @param polls From [load_polls()], with its `region` attribute.
#' @param as_at Cutoff date.
#' @return List: `polls`, `firm_factors` (`NULL` when nothing applies).
#' @keywords internal
paid_poll_for <- function(polls, as_at) {
  path <- poll_wiki_path()
  if (!file.exists(path)) {
    message("PDP0! no poll table with sponsors (", path, "): paid-poll correction NOT applied")
    return(list(polls = polls, firm_factors = NULL))
  }
  rg <- attr(polls, "region")
  cls <- poll_sponsor_class(rg, polls)
  reach <- as.character(cls) == "party" & is.finite(polls$date) & polls$date <= as_at
  if (!any(reach)) return(list(polls = polls, firm_factors = NULL))
  key <- paste(as.character(as_at), path, format(file.mtime(path), "%Y%m%d%H%M%OS3"),
               Sys.getenv("AUSPOL_POLL_SOURCE"), sep = "#")
  fit <- .ppc_cache[[key]]
  if (is.null(fit)) {
    dv <- data.table::rbindlist(lapply(PAID_POLL_REGIONS, function(r) {
      pl <- if (identical(r, rg)) polls else tryCatch(suppressMessages(load_polls(r)), error = function(e) NULL)
      if (is.null(pl)) return(NULL)
      cl <- if (identical(r, rg)) cls else poll_sponsor_class(r, pl)
      paid_poll_deviations(pl, as.character(cl), attr(cl, "sponsor"), as_at)
    }), fill = TRUE)
    fit <- paid_poll_fit(dv)
    assign(key, fit, envir = .ppc_cache)
    message(sprintf("PDP1 paid polls as at %s: %d (all regions); toward-sponsor lean %+.2f (SE %.2f), shrunk per side %s; noise factor %.3f (weight x%.2f)",
                    as_at, fit$n_paid, fit$mu, fit$se_mu,
                    if (nrow(fit$lean)) paste(sprintf("%s %+.2f", fit$lean$side, fit$lean$shrunk), collapse = ", ") else "none",
                    fit$factor, 1 / fit$factor^2))
  }
  ap <- paid_poll_apply(polls, as.character(cls), attr(cls, "sponsor"), fit, as_at)
  list(polls = ap$polls, firm_factors = ap$firm_factors)
}
