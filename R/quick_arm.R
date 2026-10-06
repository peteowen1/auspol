# Helpers for scripts/quick_arm.R, the fast screen for a model tweak.
#
# WHY IT EXISTS. A full arm is six harnesses x 20,000 simulations x 22
# elections, 10-40 minutes, even when the tweak changes a few dozen cells.
# Profiled 2026-10-07 on the Victorian harness: at 20,000 simulations the
# simulation is ~20% of the run (183 s against 145 s at 500), and the rest is
# fitting that is spread over dozens of functions with no single hot spot. So
# the screen cannot be "fewer simulations" alone; it is (1) one harness run per
# ELECTION, so an arm that touches one pair pays for one pair, (2) a cached
# BASELINE shared by every arm, and (3) common random numbers: baseline and arm
# run the same seed at the same low simulation count, so a pair the arm does
# not touch is byte-identical and contributes exactly zero.
#
# Everything here is pure (data in, numbers out) so it can be tested on
# synthetic input; the process handling lives in scripts/quick_arm.R.

#' One harness run per election: the 22 scored pairs
#'
#' @return data.frame: `id` (election label), `harness` (fed, wa, vic, nsw, qld, sa),
#'   `var` (the environment variable that restricts that harness to one pair),
#'   `val` (its value).
#' @keywords internal
#' @noRd
quick_units <- function() {
  mk <- function(h, var, vals, ids = paste0(h, vals)) {
    data.frame(id = ids, harness = h, var = var, val = as.character(vals), stringsAsFactors = FALSE)
  }
  rbind(
    mk("fed", "AUSPOL_FED_PAIRS", c(2007, 2010, 2013, 2016, 2019, 2022, 2025)),
    mk("wa",  "AUSPOL_WA_PAIR",   c(2001, 2005, 2008, 2013, 2017, 2025)),
    mk("vic", "AUSPOL_VIC_PAIR",  c(2014, 2018, 2022)),
    mk("nsw", "AUSPOL_NSW_PAIR",  c(2019, 2023)),
    mk("qld", "AUSPOL_QLD_PAIR",  c(2020, 2024)),
    mk("sa",  "AUSPOL_SA_PAIR",   c(2022, 2026)))
}

#' Parse "AUSPOL_X=1 AUSPOL_Y=0" into a named character vector
#'
#' Refuses anything that is not a NAME=value pair, and a name that is not an
#' `AUSPOL_` switch: a typo that parsed to nothing would be an arm that never
#' ran, which reads exactly like an arm with no effect.
#' @param s One string of space-separated assignments (may be empty).
#' @return Named character vector (possibly empty).
#' @keywords internal
#' @noRd
quick_parse_env <- function(s) {
  s <- if (is.null(s)) "" else trimws(s)
  if (!nzchar(s)) return(stats::setNames(character(0), character(0)))
  parts <- strsplit(s, "[[:space:]]+")[[1]]
  bad <- parts[!grepl("^AUSPOL_[A-Z0-9_]+=", parts)]
  if (length(bad))
    stop("quick_arm: not an AUSPOL_NAME=value assignment: ", paste(bad, collapse = ", "), call. = FALSE)
  nm <- sub("=.*$", "", parts)
  val <- sub("^[^=]*=", "", parts)
  if (anyDuplicated(nm)) stop("quick_arm: switch set twice: ", paste(nm[duplicated(nm)], collapse = ", "), call. = FALSE)
  stats::setNames(val, nm)
}

#' Winner probability per (pair, seat) from a harness allprobs table
#'
#' @param ap data.frame with `pair`, `seat`, `party`, `prob`, `actual`.
#' @return data.frame `pair`, `seat`, `p`: the probability the model gave the
#'   party that actually won; 0 when that party has no row (it was never drawn).
#' @keywords internal
#' @noRd
quick_winner_prob <- function(ap) {
  need <- c("pair", "seat", "party", "prob", "actual")
  if (!all(need %in% names(ap))) stop("quick_arm: allprobs is missing ", paste(setdiff(need, names(ap)), collapse = ", "), call. = FALSE)
  key <- paste(ap$pair, ap$seat, sep = "\r")
  w <- ap$party == ap$actual
  w[is.na(w)] <- FALSE
  p_hit <- tapply(ap$prob[w], key[w], sum)
  keys <- unique(key)
  p <- as.numeric(p_hit[keys]); p[is.na(p)] <- 0
  first <- match(keys, key)
  data.frame(pair = ap$pair[first], seat = ap$seat[first], p = p, stringsAsFactors = FALSE)
}

#' Mean paired change with a standard error clustered on one column
#'
#' The same formula `scripts/score_arm.R` uses (SA3/SA6): seats within an
#' election share a statewide draw, so the election, not the seat, is the unit.
#' @param d Numeric per-row paired change (arm minus baseline).
#' @param cluster Cluster label per row.
#' @return `list(mean, se, n, clusters)`; `se` is `NA` with fewer than 2 clusters.
#' @keywords internal
#' @noRd
quick_clustered <- function(d, cluster) {
  stopifnot(length(d) == length(cluster), length(d) > 0, !anyNA(d))
  s <- tapply(d, cluster, sum); n <- tapply(d, cluster, length)
  m <- sum(s) / sum(n); k <- length(s)
  se <- if (k < 2) NA_real_ else sqrt(k / (k - 1) * sum((s - n * m)^2)) / sum(n)
  list(mean = m, se = se, n = length(d), clusters = k)
}

#' Seat-winner log loss, baseline against arm, per election and pooled
#'
#' @param base_ap,arm_ap Harness allprobs tables (see [quick_winner_prob()]).
#' @param eps Floor on the winner probability before the log. The full runs use
#'   1e-6 at 20,000 simulations; at N simulations a probability under 1/N is
#'   indistinguishable from zero, so the screen floors at `0.5 / n_sims`.
#' @return `list(per_pair, overall, seats, matched)`.
#' @keywords internal
#' @noRd
quick_seat_ll <- function(base_ap, arm_ap, eps = 1e-6) {
  a <- quick_winner_prob(base_ap); b <- quick_winner_prob(arm_ap)
  a$key <- paste(a$pair, a$seat, sep = "\r"); b$key <- paste(b$pair, b$seat, sep = "\r")
  j <- match(a$key, b$key)
  # COVERAGE, not presence: a seat scored in one run and not the other would
  # silently shrink the compared set.
  if (anyNA(j) || nrow(a) != nrow(b))
    stop(sprintf("quick_arm: seat sets differ (baseline %d, arm %d, %d baseline seats missing from the arm)",
                 nrow(a), nrow(b), sum(is.na(j))), call. = FALSE)
  ll <- function(p) -log(pmax(eps, p))
  seats <- data.frame(pair = a$pair, seat = a$seat, p_base = a$p, p_arm = b$p[j],
                      ll_base = ll(a$p), ll_arm = ll(b$p[j]), stringsAsFactors = FALSE)
  seats$dd <- seats$ll_arm - seats$ll_base
  per <- do.call(rbind, lapply(split(seats, seats$pair), function(g) {
    data.frame(pair = g$pair[1], seats = nrow(g), seats_changed = sum(abs(g$dd) > 1e-12),
               ll_base = mean(g$ll_base), ll_arm = mean(g$ll_arm), change = mean(g$dd),
               stringsAsFactors = FALSE)
  }))
  rownames(per) <- NULL
  list(per_pair = per, overall = quick_clustered(seats$dd, seats$pair), seats = seats,
       ll_base = mean(seats$ll_base), ll_arm = mean(seats$ll_arm))
}

#' Share-level comparison: which cells moved, and did the move land nearer the result
#'
#' @param base_sd,arm_sd Harness sharedetail tables: `pair`, `seat`, `party`,
#'   `pred_share`, `actual_share`.
#' @param tol A cell counts as changed when its prediction moves by more than this
#'   many points (default 0.05, the tolerance `AUSPOL_XGB_BASE_DELTA` itself uses).
#' @return `list(per_pair, primary, cells)`. `primary` is the squared error on the
#'   changed cells: baseline, arm, change, and SE treating cells as the units
#'   (`sd(d) * sqrt(n)`, as `scripts/score_arm.R` SA2).
#' @keywords internal
#' @noRd
quick_share_diff <- function(base_sd, arm_sd, tol = 0.05) {
  need <- c("pair", "seat", "party", "pred_share", "actual_share")
  for (x in list(base_sd, arm_sd))
    if (!all(need %in% names(x))) stop("quick_arm: sharedetail is missing ", paste(setdiff(need, names(x)), collapse = ", "), call. = FALSE)
  ka <- paste(base_sd$pair, base_sd$seat, base_sd$party, sep = "\r")
  kb <- paste(arm_sd$pair, arm_sd$seat, arm_sd$party, sep = "\r")
  if (anyDuplicated(ka) || anyDuplicated(kb)) stop("quick_arm: duplicate (pair, seat, party) rows in sharedetail", call. = FALSE)
  j <- match(ka, kb)
  if (anyNA(j) || length(ka) != length(kb))
    stop(sprintf("quick_arm: cell sets differ (baseline %d, arm %d, %d baseline cells missing from the arm)",
                 length(ka), length(kb), sum(is.na(j))), call. = FALSE)
  cells <- data.frame(pair = base_sd$pair, seat = base_sd$seat, party = base_sd$party,
                      actual = base_sd$actual_share, base = base_sd$pred_share,
                      arm = arm_sd$pred_share[j], stringsAsFactors = FALSE)
  if (!isTRUE(all.equal(cells$actual, arm_sd$actual_share[j], tolerance = 1e-9)))
    stop("quick_arm: the two runs disagree on the actual result; they are not scoring the same election", call. = FALSE)
  cells$moved <- abs(cells$arm - cells$base) > tol
  cells$moved[is.na(cells$moved)] <- FALSE
  cells$d <- (cells$actual - cells$arm)^2 - (cells$actual - cells$base)^2
  per <- do.call(rbind, lapply(split(cells, cells$pair), function(g) {
    m <- g[g$moved, ]
    data.frame(pair = g$pair[1], cells = nrow(g), changed = nrow(m),
               sq_err_change = if (nrow(m)) sum(m$d) else 0, stringsAsFactors = FALSE)
  }))
  rownames(per) <- NULL
  m <- cells[cells$moved, ]
  primary <- if (nrow(m) < 2) list(n = nrow(m), base = NA_real_, arm = NA_real_, change = NA_real_, se = NA_real_) else {
    b <- sum((m$actual - m$base)^2)
    list(n = nrow(m), base = b, arm = b + sum(m$d), change = sum(m$d), se = stats::sd(m$d) * sqrt(nrow(m)))
  }
  list(per_pair = per, primary = primary, cells = cells)
}

#' Ledger (AEF-7 subset) log-loss change
#'
#' @param seat_ll Result of [quick_seat_ll()].
#' @param ledger data.frame with `pair` and `seat`: the AEF-7 comparison rows.
#' @return `list(n, ll_base, ll_arm, overall)` over the ledger's seats that were
#'   scored; `n` against `nrow(ledger)` is the coverage.
#' @keywords internal
#' @noRd
quick_ledger_ll <- function(seat_ll, ledger) {
  s <- seat_ll$seats
  hit <- paste(s$pair, s$seat, sep = "\r") %in% paste(ledger$pair, ledger$seat, sep = "\r")
  s <- s[hit, ]
  if (!nrow(s)) return(list(n = 0L, rows = nrow(ledger), ll_base = NA_real_, ll_arm = NA_real_, overall = NULL))
  list(n = nrow(s), rows = nrow(ledger), ll_base = mean(s$ll_base), ll_arm = mean(s$ll_arm),
       overall = quick_clustered(s$dd, s$pair))
}

#' One-word reading of a paired change against its standard error
#' @keywords internal
#' @noRd
quick_word <- function(m, se) {
  if (is.na(se)) return("no SE (fewer than 2 elections)")
  if (m < -se) "BETTER by more than 1 SE" else if (m > se) "WORSE by more than 1 SE" else "within 1 SE"
}
