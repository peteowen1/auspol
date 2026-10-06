# AUSPOL_NEW_IND_SHRINK: a nameless first-time independent is over-called at
# base level. docs/reviews/vic-ind-overcall-2026-10-06.md (section 3): an
# independent who is the only one in the seat and has no previous vote anywhere
# was given about 6 points by base_pred and polled about 3 in Victoria
# (+3.16, SE 0.31, n = 75 cells; vic2014 +2.44, vic2018 +4.54, vic2022 +3.16),
# and about 0 in South Australia (n = 18).
#
# A POST-XGB FIX, exactly like AUSPOL_REENTRY: the as-at trees must never train
# on it, and it is measured through AUSPOL_XGB_BASE_DELTA (frozen trees, new
# base as both base_margin and the base_pred feature). post_xgb_switches()
# below is the one place that lists such switches.

#' The validated `AUSPOL_NEW_IND_SHRINK` switch
#'
#' `"0"` off, `"1"` on (shipped 2026-10-06, so also unset or empty). Anything else is an error: a typo
#' that quietly reads as off is an arm that never ran.
#'
#' @return `"0"` or `"1"`.
#' @export
new_ind_mode <- function() {
  m <- Sys.getenv("AUSPOL_NEW_IND_SHRINK", "1")
  if (!nzchar(m)) m <- "1"   # empty = unset = the shipped value
  if (!m %in% c("0", "1"))
    stop("AUSPOL_NEW_IND_SHRINK must be \"0\" or \"1\"; got \"", m, "\"", call. = FALSE)
  m
}

#' Every switch that changes the base AFTER the xgb trees were trained
#'
#' A base built with one of these on must not become the stage-1 training base
#' or the base-delta reference: the as-at trees would learn the fix and the
#' stage-6 delta would read zero. [xgb_primary_override()] refuses to record a
#' reference with any of them active and warns (`XG9!!`) when a stage-1-style
#' base is built with one on. Add the next post-xgb switch HERE, and in
#' `scripts/rebuild_forecasts.sh` stage 1.
#'
#' @return Named character vector of the switches that are NOT off, name = env
#'   var, value = its validated setting. Empty when everything is off.
#' @export
post_xgb_switches <- function() {
  cur <- c(AUSPOL_REENTRY = reentry_mode(), AUSPOL_NEW_IND_SHRINK = new_ind_mode())
  cur[cur != "0"]
}

# Corpus columns this file needs.
.NI_COLS <- c("election", "region", "seat", "name", "surname", "given", "party", "votes")

.ni_read_corpus <- function(corpus = NULL) {
  if (is.null(corpus)) {
    f <- out_path("candidacies.csv")
    if (!file.exists(f))
      stop("new_ind needs output/candidacies.csv; run scripts/build_candidacies.R", call. = FALSE)
    corpus <- data.table::fread(f, select = .NI_COLS, showProgress = FALSE)
  }
  C <- data.table::as.data.table(corpus)
  for (v in setdiff(.NI_COLS, names(C))) C[[v]] <- if (v == "votes") NA_real_ else NA_character_
  C
}

# The person key every cross-election join in R/ uses.
.ni_person_key <- function(d) {
  match_key(surname_of(d$surname, d$name), given_of(d$given, d$name), "person")
}

# By-election candidates as person keys. The table writes "Given Surname", the
# reverse of the commissions' "SURNAME Given", so split on the last space.
.ni_byelection_people <- function(byelection = NULL) {
  tab <- byelection
  if (is.null(tab)) {
    f <- file.path(pkg_root(), "external", "reference", "byelections", "byelection-results.csv")
    if (!file.exists(f)) {
      cat("NI1! by-election table missing: by-election candidates are NOT excluded from the cell set\n")
      return(data.table::data.table(region = character(0), date = as.Date(character(0)), pkey = character(0)))
    }
    tab <- data.table::fread(f, select = c("region", "date", "candidate"), showProgress = FALSE)
  }
  tab <- data.table::as.data.table(tab)
  nm <- trimws(as.character(tab$candidate))
  sur <- sub("^.*[[:space:]]", "", nm)
  giv <- ifelse(grepl("[[:space:]]", nm), sub("[[:space:]].*$", "", nm), "")
  data.table::data.table(region = tab$region, date = as.Date(tab$date),
                         pkey = match_key(surname_of(sur, NA_character_), given_of(giv, NA_character_), "person"))
}

#' The cells AUSPOL_NEW_IND_SHRINK applies to, at one election
#'
#' An independent cell is in the set when ALL of these hold (a person is
#' matched with `match_key(rule = "person")`, never by party class):
#'
#' * the seat has exactly ONE independent candidate at `target`;
#' * that person has no row at any strictly earlier election of the same
#'   region, in any seat and any party. That removes an own prior vote, a
#'   cross-seat credit, a defector and a sitting member in one test, because
#'   every one of them needs an earlier row;
#' * that person was not a candidate (so not a winner) at a by-election of the
#'   region dated before `target`'s polling day;
#' * the seat's independent class vote at the previous election is not a
#'   departed leader's: the class share minus the class's statewide share is
#'   below `prior_max` (the review's `dev_prev` below 10; a missing value,
#'   a seat new at the previous election, counts as below).
#'
#' Time-forward: only rows of elections dated strictly before `target` are read
#' for the person test and the class prior. The first election of a region in
#' the corpus has no history, so everyone looks new there (those elections are
#' not scored pairs anyway); at the second the history is one election deep,
#' which can only INCLUDE a returning person from before that, never exclude a
#' new one.
#'
#' @param target Election label, e.g. `"vic2022"`.
#' @param corpus,byelection Optional pre-read candidacy and by-election tables.
#' @param prior_max Class-prior cut, share points.
#' @param code Log prefix; `quiet = TRUE` suppresses the count line.
#' @param quiet Logical.
#' @return `data.table` of `seat`, `skey` (normalised seat), `name`, `dev_prev`,
#'   with attribute `"counts"`.
#' @export
new_ind_cells <- function(target, corpus = NULL, byelection = NULL, prior_max = 10,
                          code = "NI1", quiet = FALSE) {
  C <- .ni_read_corpus(corpus)
  region <- sub("[0-9]{4}$", "", target)
  els <- unique(C$election[C$region == region])
  empty <- data.table::data.table(seat = character(0), skey = character(0),
                                  name = character(0), dev_prev = numeric(0))
  if (!target %in% els) {
    if (!quiet) cat(sprintf("%s! %s is not in the candidacy corpus: no new-independent cells\n", code, target))
    attr(empty, "counts") <- c(single = 0L, returning = 0L, byelection = 0L, prior = 0L, cells = 0L)
    return(empty)
  }
  earlier <- els[elections_before(els, target)]
  tdate <- election_dates()[[target]]
  cur <- C[C$election == target & C$party == "IND", ]
  cur[, `:=`(pkey = .ni_person_key(cur), skey = normalise_seat(seat))]
  nper <- cur[, list(n_ind = .N), by = "skey"]
  single <- cur[cur$skey %in% nper$skey[nper$n_ind == 1L], ]
  # a person with any earlier row, any seat, any party
  hist <- C[C$election %in% earlier, ]
  hkeys <- unique(.ni_person_key(hist))
  hkeys <- hkeys[nzchar(hkeys)]
  ret <- single$pkey %in% hkeys
  # by-election candidates before the polling day
  be <- .ni_byelection_people(byelection)
  bkeys <- be$pkey[be$region == region & !is.na(be$date) & be$date < tdate]
  bye <- !ret & single$pkey %in% bkeys
  # departed-leader class prior at the previous election
  devp <- rep(NA_real_, nrow(single))
  if (length(earlier)) {
    prev <- earlier[which.max(as.Date(unname(election_dates()[earlier])))]
    P <- C[C$election == prev, ]
    P[, skey := normalise_seat(seat)]
    sv <- P[, list(tot = sum(votes, na.rm = TRUE),
                   ind = sum(votes[party == "IND"], na.rm = TRUE)), by = "skey"]
    state <- sum(sv$ind) / sum(sv$tot) * 100
    sv[, cls := 100 * ind / tot]
    devp <- sv$cls[match(single$skey, sv$skey)] - state
  }
  hi <- !ret & !bye & is.finite(devp) & devp >= prior_max
  keep <- !ret & !bye & !hi
  out <- data.table::data.table(seat = single$seat[keep], skey = single$skey[keep],
                                name = single$name[keep], dev_prev = devp[keep])
  cnt <- c(single = nrow(single), returning = sum(ret), byelection = sum(bye),
           prior = sum(hi), cells = nrow(out))
  attr(out, "counts") <- cnt
  if (!quiet)
    cat(sprintf("%s  new-independent cells for %s: %d of %d single-IND seats (excluded: %d returning person, %d by-election candidate, %d class prior >= %g)\n",
                code, target, cnt[["cells"]], cnt[["single"]], cnt[["returning"]],
                cnt[["byelection"]], cnt[["prior"]], prior_max))
  out
}

# Cluster-robust SE of a ratio-of-sums k = sum(a)/sum(b), clustered by election.
# Returns c(k, se, G). With fewer than two elections the clustered SE is not
# estimable; the cell-level (n/(n-1)) SE is returned with G = 1 and the caller
# scales it by a design effect.
.ni_ratio <- function(a, b, el) {
  sb <- sum(b)
  k <- sum(a) / sb
  u <- a - k * b
  G <- length(unique(el))
  if (G >= 2L) {
    U <- tapply(u, el, sum)
    se <- sqrt(G / (G - 1) * sum(U^2)) / sb
  } else {
    n <- length(a)
    se <- if (n >= 2L) sqrt(n / (n - 1) * sum(u^2)) / sb else NA_real_
  }
  c(k = k, se = se, G = G)
}

#' Fit the new-independent factor, time-forward, partially pooled by jurisdiction
#'
#' For each scored election strictly before `target` (elections with a row in
#' the stage-1 feature table `output/xgb-primary-v6-features.csv`), takes the
#' [new_ind_cells()] set and the cell's `actual_share` and `base_pred`. The
#' factor is MULTIPLICATIVE: `k = sum(actual) / sum(base)` over the cells, so a
#' cell predicted 10 is cut more than a cell predicted 3 (base share is what a
#' nameless candidate is credited with, and the credit is proportional to the
#' class vote it is carried from). Per jurisdiction `k_j` is shrunk toward the
#' all-jurisdiction pooled `k`:
#' `w = tau^2 / (tau^2 + se_j^2)`, `k_shrunk = k + w (k_j - k)`,
#' `tau^2` the DerSimonian-Laird between-jurisdiction variance of the `k_j`, `se_j`
#' clustered by election (a jurisdiction with one election gets its cell-level
#' SE times the design effect measured on the all-jurisdiction fit). The factor
#' is bounded to `[0, 1]`: this fix only ever lowers a cell.
#'
#' @param target Election label; nothing dated on or after it is read.
#' @param corpus,byelection,features Optional pre-read tables; `features` is the
#'   stage-1 feature table (`pair, seat, party, actual_share, base_pred`).
#' @param tau2 `NULL` estimates it; a number forces it (`0` gives complete
#'   pooling).
#' @param prior_max Passed to [new_ind_cells()].
#' @param code,quiet Logging.
#' @return A list: `factor` (for the target's jurisdiction), `table` (one row
#'   per jurisdiction: `region, n, n_el, k, se, w, factor`), `pooled`, `tau2`,
#'   `train` (the cells used).
#' @export
new_ind_fit <- function(target, corpus = NULL, byelection = NULL, features = NULL,
                        tau2 = NULL, prior_max = 10, code = "NI1", quiet = FALSE) {
  C <- .ni_read_corpus(corpus)
  if (is.null(features)) {
    f <- out_path("xgb-primary-v6-features.csv")
    if (!file.exists(f))
      stop("new_ind_fit() needs ", f, " (the stage-1 base_pred and actuals)", call. = FALSE)
    features <- data.table::fread(f, select = c("pair", "seat", "party", "actual_share", "base_pred"),
                                  showProgress = FALSE)
  }
  FT <- data.table::as.data.table(features)
  FT <- FT[FT$party == "IND", ]
  FT[, skey := normalise_seat(seat)]
  trg_region <- sub("[0-9]{4}$", "", target)
  pairs <- unique(FT$pair)
  pairs <- pairs[elections_before(pairs, target)]
  rows <- lapply(pairs, function(E) {
    cl <- new_ind_cells(E, corpus = C, byelection = byelection, prior_max = prior_max, quiet = TRUE)
    if (!nrow(cl)) return(NULL)
    ft <- FT[FT$pair == E, ]
    m <- ft[match(cl$skey, ft$skey), ]
    d <- data.table::data.table(election = E, region = sub("[0-9]{4}$", "", E),
                                seat = cl$seat, a = m$actual_share, b = m$base_pred)
    d[is.finite(d$a) & is.finite(d$b) & d$b > 0, ]
  })
  Tr <- data.table::rbindlist(rows)
  none <- list(factor = 1, table = data.frame(), pooled = NA_real_, tau2 = NA_real_, train = Tr)
  if (!nrow(Tr)) {
    if (!quiet) cat(sprintf("%s! %s: no earlier new-independent cells with a base to fit on; factor 1\n", code, target))
    return(none)
  }
  pool <- .ni_ratio(Tr$a, Tr$b, Tr$election)
  deff <- if (is.finite(pool[["se"]]) && pool[["G"]] >= 2) {
    nv <- .ni_ratio(Tr$a, Tr$b, seq_len(nrow(Tr)))   # every cell its own cluster
    if (is.finite(nv[["se"]]) && nv[["se"]] > 0) pool[["se"]] / nv[["se"]] else 1
  } else 1
  regs <- sort(unique(Tr$region))
  tb <- do.call(rbind, lapply(regs, function(r) {
    d <- Tr[Tr$region == r, ]
    z <- .ni_ratio(d$a, d$b, d$election)
    se <- if (z[["G"]] < 2) z[["se"]] * deff else z[["se"]]
    data.frame(region = r, n = nrow(d), n_el = z[["G"]], k = z[["k"]], se = se,
               stringsAsFactors = FALSE)
  }))
  ok <- is.finite(tb$k) & is.finite(tb$se) & tb$se > 0
  # DerSimonian-Laird between-jurisdiction variance
  tau2_hat <- 0
  if (sum(ok) >= 2L) {
    wi <- 1 / tb$se[ok]^2
    mu_w <- sum(wi * tb$k[ok]) / sum(wi)
    Q <- sum(wi * (tb$k[ok] - mu_w)^2)
    tau2_hat <- max(0, (Q - (sum(ok) - 1)) / (sum(wi) - sum(wi^2) / sum(wi)))
  }
  t2 <- if (is.null(tau2)) tau2_hat else tau2
  tb$w <- ifelse(ok, t2 / (t2 + tb$se^2), 0)
  tb$w[!is.finite(tb$w)] <- 0
  # AUSPOL_NEW_IND_SHRINK_CAP: "1" bounds the factor to [0, 1] (only ever lowers a cell); "0" lets
  # it rise where earlier elections under-called these candidates (federal and NSW: k ~1.5). Pete,
  # 2026-10-06: a one-sided cap keeps only the half of a fix that helps.
  .hi <- if (identical(Sys.getenv("AUSPOL_NEW_IND_SHRINK_CAP", "1"), "0")) Inf else 1
  tb$factor <- pmin(.hi, pmax(0, pool[["k"]] + tb$w * (tb$k - pool[["k"]])))
  fac <- if (trg_region %in% tb$region) tb$factor[tb$region == trg_region]
         else pmin(.hi, pmax(0, pool[["k"]]))
  if (!quiet) {
    cat(sprintf("%s  fit for %s: %d cell(s) in %d election(s), pooled k %.3f (se %.3f, design effect %.2f), tau2 %.4f%s\n",
                code, target, nrow(Tr), length(unique(Tr$election)), pool[["k"]], pool[["se"]],
                deff, t2, if (is.null(tau2)) "" else " (FORCED)"))
    for (i in seq_len(nrow(tb)))
      cat(sprintf("%s    %-4s n %3d (%d election%s) | k %.3f | se %.3f | w %.3f | factor %.3f%s\n",
                  code, tb$region[i], tb$n[i], as.integer(tb$n_el[i]), if (tb$n_el[i] == 1) "" else "s",
                  tb$k[i], tb$se[i], tb$w[i], tb$factor[i],
                  if (tb$region[i] == trg_region) "  <- target" else ""))
    if (!trg_region %in% tb$region)
      cat(sprintf("%s    %s has no earlier cells: pooled factor %.3f used\n", code, trg_region, fac))
  }
  list(factor = fac, table = tb, pooled = pool[["k"]], tau2 = t2, train = Tr)
}

#' Apply the new-independent factor to a share matrix
#'
#' Each cell of [new_ind_cells()] present in `shares` (class `IND`, share above
#' zero) is multiplied by the fitted factor, and the freed share goes back to
#' the seat's other classes in proportion: others are scaled by
#' `(rowsum - new) / (rowsum - old)`, so the row total is unchanged and the cell
#' ends at exactly `factor * old`. Switch `"0"` returns `shares` itself with no
#' file read, so a run with it off is byte-identical.
#'
#' Called in every harness and in `fit_seats_full.R` immediately before the xgb
#' override (backtests) or the live xgb prediction, i.e. after nomination
#' zeroing and the salience blend, the same point as the re-entry fill. Sites:
#' `backtest_candidate_{fed,vic,nsw,qld,sa,wa}.R` and `scripts/fit_seats_full.R`.
#'
#' @param shares Seats x classes matrix, rownames seats.
#' @param target Election label.
#' @param code Log prefix.
#' @param ... Passed to [new_ind_cells()] / [new_ind_fit()] (`corpus`,
#'   `byelection`, `features`, `tau2`).
#' @return `shares`, with attribute `"new_ind"` (`seat, base_old, base_new,
#'   factor`) when the switch is on.
#' @export
new_ind_shrink_apply <- function(shares, target, code = "NI1", ...) {
  if (identical(new_ind_mode(), "0")) return(shares)
  if (!"IND" %in% colnames(shares)) return(shares)
  a <- list(...)
  cells <- do.call(new_ind_cells, c(list(target, code = code),
                                    a[intersect(names(a), c("corpus", "byelection", "prior_max"))]))
  fit <- do.call(new_ind_fit, c(list(target, code = code),
                                a[intersect(names(a), c("corpus", "byelection", "features", "tau2", "prior_max"))]))
  f <- fit$factor
  ri <- match(cells$skey, normalise_seat(rownames(shares)))
  ri <- ri[!is.na(ri)]
  ci <- match("IND", colnames(shares))
  ri <- ri[shares[ri, ci] > 0]
  out <- shares
  log <- data.frame(seat = character(0), base_old = numeric(0), base_new = numeric(0))
  for (i in ri) {
    old <- shares[i, ci]; new <- f * old; tot <- sum(shares[i, ])
    if (tot - old <= 0) next
    out[i, ] <- shares[i, ] * (tot - new) / (tot - old)
    out[i, ci] <- new
    log <- rbind(log, data.frame(seat = rownames(shares)[i], base_old = old, base_new = new))
  }
  log$factor <- rep(f, nrow(log))
  cat(sprintf("%s  new-independent shrink for %s: factor %.3f applied to %d of %d cell(s) in the share matrix\n",
              code, target, f, nrow(log), nrow(cells)))
  if (nrow(log)) {
    o <- utils::head(order(-(log$base_old - log$base_new)), 5L)
    for (j in o) cat(sprintf("%s    %-22s IND %6.2f -> %6.2f\n", code, log$seat[j], log$base_old[j], log$base_new[j]))
  }
  attr(out, "new_ind") <- log
  out
}
