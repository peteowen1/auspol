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
#'   changed cells: baseline, arm, change, and the SE of that TOTAL clustered on
#'   election (cells share seats and seats share an election's statewide draw, so
#'   the election is the unit, as [quick_clustered()] does for the log loss).
#'   `se` is `NA` (not assessable) with changed cells in fewer than 2 elections;
#'   `clusters` is the number of elections with a changed cell.
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
  primary <- if (nrow(m) < 2) list(n = nrow(m), base = NA_real_, arm = NA_real_, change = NA_real_, se = NA_real_, clusters = length(unique(m$pair))) else {
    b <- sum((m$actual - m$base)^2)
    cl <- quick_clustered(m$d, m$pair)
    # quick_clustered's se is for the MEAN; the change reported is the TOTAL over the n cells
    list(n = nrow(m), base = b, arm = b + sum(m$d), change = sum(m$d),
         se = if (is.na(cl$se)) NA_real_ else cl$se * nrow(m), clusters = cl$clusters)
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

#' Verdict for Q2 from [quick_share_diff()]'s `primary`
#'
#' Keeps the PASS / WORSE labels, on the election-clustered SE; with no SE
#' (changed cells in fewer than 2 elections) there is no verdict.
#' @param p The `primary` element of [quick_share_diff()].
#' @return One string.
#' @keywords internal
#' @noRd
quick_q2_verdict <- function(p) {
  if (is.null(p$se) || is.na(p$se)) return("NOT ASSESSABLE (changed cells in fewer than 2 elections)")
  if (p$change < -2 * p$se && p$change < -0.1 * p$base) "PASS (< -2 SE and < -10%)"
  else if (p$change > 2 * p$se) "WORSE by more than 2 SE"
  else "FAIL / not clear"
}

#' Largest absolute difference between baseline and arm, per election
#'
#' What "byte-identical to baseline" must rest on: every cell's predicted share
#' AND every party's win probability, not just the cells that moved by more than
#' the 0.05 reporting tolerance. A party with no allprobs row in one run has
#' probability 0 there (it was never drawn); a share present in only one run, or
#' NA in only one, counts as an infinite difference.
#' @param base_sd,arm_sd Sharedetail tables (`pair`, `seat`, `party`, `pred_share`).
#' @param base_ap,arm_ap Allprobs tables (`pair`, `seat`, `party`, `prob`).
#' @return data.frame `pair`, `max_share_diff`, `max_prob_diff`, `max_diff`.
#' @keywords internal
#' @noRd
quick_max_diff <- function(base_sd, arm_sd, base_ap, arm_ap) {
  one <- function(a, b, val, absent_zero) {
    for (x in list(a, b)) if (!all(c("pair", "seat", "party", val) %in% names(x)))
      stop("quick_arm: table is missing one of pair, seat, party, ", val, call. = FALSE)
    ka <- paste(a$pair, a$seat, a$party, sep = "\r"); kb <- paste(b$pair, b$seat, b$party, sep = "\r")
    va <- tapply(a[[val]], ka, sum); vb <- tapply(b[[val]], kb, sum)
    keys <- union(names(va), names(vb))
    x <- as.numeric(va[keys]); y <- as.numeric(vb[keys])
    if (absent_zero) { x[!keys %in% names(va)] <- 0; y[!keys %in% names(vb)] <- 0 }
    d <- abs(x - y)
    d[is.na(x) & is.na(y)] <- 0
    d[is.na(d)] <- Inf
    tapply(d, sub("\r.*$", "", keys), max)
  }
  s <- one(base_sd, arm_sd, "pred_share", FALSE)
  p <- one(base_ap, arm_ap, "prob", TRUE)
  pairs <- sort(union(names(s), names(p)))
  ms <- as.numeric(s[pairs]); mp <- as.numeric(p[pairs])
  ms[is.na(ms)] <- Inf; mp[is.na(mp)] <- Inf   # an election scored on one level only is not provably identical
  data.frame(pair = pairs, max_share_diff = ms, max_prob_diff = mp, max_diff = pmax(ms, mp), stringsAsFactors = FALSE)
}

#' Stop on switches that are not registered in PUBLISHED_FLAGS
#'
#' The harnesses only read (and HD1 only reports) switches named in
#' `scripts/published_flags.R`; a typo or an unregistered name is never read, so
#' the arm would silently be the baseline.
#' @param switches Character vector of switch names.
#' @param registry Names of PUBLISHED_FLAGS.
#' @return Invisibly `switches`; stops listing the unregistered ones.
#' @keywords internal
#' @noRd
quick_check_registered <- function(switches, registry) {
  bad <- setdiff(switches, registry)
  if (length(bad))
    stop("quick_arm: not a switch in PUBLISHED_FLAGS (scripts/published_flags.R), so no harness reads it: ",
         paste(bad, collapse = ", "), call. = FALSE)
  invisible(switches)
}

#' Check a harness log's HD1 line against what this run was told to set
#'
#' HD1 lists every PUBLISHED_FLAGS switch the caller set. A name there that this
#' task did not set is a leak from an earlier task; a name the user named that is
#' missing was never applied (or was set to the empty string).
#' @param hd1 The HD1 line, or `NA` when the log has none.
#' @param env_names Switch names this task was given.
#' @param named Switch names the user named (arm and `--base`) that must appear.
#' @return `list(ok, seen, foreign, missing, no_hd1)`.
#' @keywords internal
#' @noRd
quick_hd1_check <- function(hd1, env_names, named) {
  no_hd1 <- is.null(hd1) || length(hd1) == 0L || is.na(hd1[1])
  seen <- if (no_hd1) character(0) else regmatches(hd1[1], gregexpr("AUSPOL_[A-Z0-9_]+(?==)", hd1[1], perl = TRUE))[[1]]
  foreign <- setdiff(seen, env_names)
  missing <- setdiff(named, seen)
  list(ok = !no_hd1 && !length(foreign) && !length(missing), seen = seen, foreign = foreign, missing = missing, no_hd1 = no_hd1)
}

#' md5 of a string, 12 hex characters
#' @keywords internal
#' @noRd
quick_md5 <- function(s) {
  tf <- tempfile(); on.exit(unlink(tf)); writeLines(s, tf)
  substr(unname(tools::md5sum(tf)), 1, 12)
}

#' A token that differs on every call, for an input that could not be read
#'
#' Folded into a cache key it cannot match a stored run: an unreadable input
#' must invalidate the cache, never be ignored.
#' @keywords internal
#' @noRd
quick_unreadable <- function(what) {
  paste0("UNREADABLE(", what, "):", format(Sys.time(), "%Y%m%d%H%M%OS6"), ":", sample.int(1e9, 1))
}

#' Signature of every file under a directory: relative path, size, mtime (recursive)
#' @param dir A directory.
#' @return A 12-character digest, or an always-different token when `dir` or any file in it cannot be read.
#' @keywords internal
#' @noRd
quick_tree_sig <- function(dir) {
  if (!dir.exists(dir)) return(quick_unreadable(dir))
  f <- sort(list.files(dir, recursive = TRUE, all.files = TRUE, no.. = TRUE))
  if (!length(f)) return(quick_md5(paste0("empty:", dir)))
  i <- file.info(file.path(dir, f))
  if (anyNA(i$size) || anyNA(i$mtime)) return(quick_unreadable(dir))
  quick_md5(paste(f, i$size, as.integer(i$mtime), sep = ":", collapse = "|"))
}

QUICK_MARKER <- ".quick-arm-root"

#' Refuse to use or delete a directory quick_arm did not create
#'
#' @param dir The scratch root.
#' @param create `TRUE` to create it (and write the marker) when absent or empty;
#'   `FALSE` (for `--clean`) to require an existing marked directory.
#' @return Invisibly `dir`; stops otherwise.
#' @keywords internal
#' @noRd
quick_check_root <- function(dir, create = TRUE) {
  mk <- file.path(dir, QUICK_MARKER)
  if (file.exists(mk)) return(invisible(dir))
  if (create && (!dir.exists(dir) || !length(list.files(dir, all.files = TRUE, no.. = TRUE)))) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(dir)) stop("quick_arm: cannot create ", dir, call. = FALSE)
    writeLines("created by scripts/quick_arm.R; --clean only removes directories that carry this file", mk)
    return(invisible(dir))
  }
  stop("quick_arm: ", dir, if (dir.exists(dir)) paste0(" exists but has no ", QUICK_MARKER,
       " marker, so this tool did not create it; refusing to reuse or delete it (if it is an old scratch directory of this tool, remove its junctions with `cmd /c rmdir`, or touch the marker)")
       else paste0(" does not exist (no ", QUICK_MARKER, " marker); nothing to clean"), call. = FALSE)
}

#' Stop unless none of the junction paths still exist as directories
#'
#' Called before any recursive `unlink` of a slot or the root: a junction that
#' survived its `rmdir` would make `unlink(recursive = TRUE)` delete the checkout
#' it points at.
#' @param root A slot directory.
#' @param links Names of the junction/symlink entries inside it.
#' @keywords internal
#' @noRd
quick_assert_no_links <- function(root, links) {
  live <- links[dir.exists(file.path(root, links))]
  if (length(live))
    stop("quick_arm: junction(s) still present in ", root, ": ", paste(live, collapse = ", "),
         "; refusing a recursive delete that could follow them into the real tree", call. = FALSE)
  invisible(TRUE)
}
