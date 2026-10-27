#' Zero every class with no candidate standing in a seat
#'
#' Which classes contest a seat is nomination data, public before polling day.
#' The harnesses zeroed independents where nobody stood, but BEFORE the xgb
#' override, which then wrote its own prediction back over the zero wherever
#' its feature rows (built from an earlier nomination list) had that class --
#' and no other class was ever zeroed. Found 2026-10-03 from the AEF-7 ledger's
#' largest miss: Narracan 2022, whose supplementary election Labor did not
#' contest, forecast Labor 33.4. Across the 22 backtest elections 2,125 cells
#' carried more than 0.5% for a class with no candidate (Churchlands 2008
#' Liberal 33.3, Alfred Cove 2001 Labor 28.4, Callide 2020 One Nation 13.5).
#' plans/prereg-nomination-zero-2026-10-03.md.
#'
#' A class is zeroed in a seat only when the target table has that seat and the
#' class appears somewhere in the table (so a class-label mismatch between the
#' prediction and the result cannot zero a whole column).
#'
#' @param shares Seat-by-class matrix of primaries.
#' @param target data.table with `seat`, `party`, `votes` for the election
#'   being predicted; a class with `votes > 0` in a seat had a candidate.
#' @param label Election label for the log line.
#' @param code Log code.
#' @param flows The harness's [build_flow_matrix()] result; with
#'   `AUSPOL_NOM_ZERO=2` the freed share follows it (else proportional).
#' @return `shares` with unnominated cells zeroed and rows renormalised to 100.
#' @export
zero_unnominated <- function(shares, target, label, code = "NZ1", flows = NULL) {
  mode <- Sys.getenv("AUSPOL_NOM_ZERO", "2")
  if (!mode %in% c("1", "2")) return(shares)
  if (mode == "2" && is.null(flows)) cat(sprintf("%s! %s: AUSPOL_NOM_ZERO=2 but no flow matrix; freed share split proportionally\n", code, label))
  tg <- data.table::as.data.table(target)
  tg <- tg[is.finite(tg$votes) & tg$votes > 0]
  if (!nrow(tg)) { cat(sprintf("%s! %s: no nomination rows; nothing zeroed\n", code, label)); return(shares) }
  stood <- paste(normalise_seat(tg$seat), tg$party)
  seats_known <- unique(normalise_seat(tg$seat))
  classes_known <- unique(tg$party)
  rk <- normalise_seat(rownames(shares))
  tot <- rowSums(shares)
  orig <- shares
  n0 <- 0L; mass <- 0; worst <- character(0); how <- c(conditional = 0L, pooled = 0L, proportional = 0L)
  zcells <- list()
  for (cl in intersect(colnames(shares), classes_known)) {
    z <- rk %in% seats_known & !(paste(rk, cl) %in% stood) & shares[, cl] > 0
    if (any(z)) {
      n0 <- n0 + sum(z); mass <- mass + sum(shares[z, cl])
      big <- which(z & shares[, cl] >= 5)
      if (length(big)) worst <- c(worst, sprintf("%s %s %.1f", rownames(shares)[big], cl, shares[big, cl]))
      zcells[[cl]] <- which(z)
    }
  }
  freed <- matrix(0, nrow(shares), ncol(shares), dimnames = dimnames(shares))
  for (cl in names(zcells)) { i <- zcells[[cl]]; freed[i, cl] <- shares[i, cl]; shares[i, cl] <- 0 }
  # A row whose every predicted class had no candidate (the result table names
  # only classes we never predicted there) would be left with nothing to hold
  # the share -- 0/0 = NaN downstream. Keep it as it was, and say so.
  empty <- which(rowSums(shares) <= 0 & rowSums(freed) > 0)
  if (length(empty)) {
    n0 <- n0 - sum(freed[empty, , drop = FALSE] > 0)
    mass <- mass - sum(freed[empty, , drop = FALSE])
    shares[empty, ] <- shares[empty, , drop = FALSE] + freed[empty, , drop = FALSE]
    freed[empty, ] <- 0
    cat(sprintf("%s! %s: %d seat(s) left with no standing class kept unchanged: %s\n", code, label,
                length(empty), paste(rownames(shares)[empty], collapse = ", ")))
  }
  if (mode == "2" && !is.null(flows)) {
    # Mode 2 (plans/prereg-nomination-zero-2026-10-03.md, amendment): the freed
    # share goes where that class's voters go, from the preference-flow matrix
    # the harness already built: the survivor-conditional cell for this seat's
    # actual field, else the class's pooled flows, else proportional.
    for (i in which(rowSums(freed) > 0)) {
      left <- colnames(shares)[shares[i, ] > 0]
      if (!length(left)) next   # nobody left standing in the row: nothing to receive the share
      for (cl in colnames(freed)[freed[i, ] > 0]) {
        key <- paste0(cl, "|", paste(sort(left), collapse = "+"))
        f <- flows$conditional[[key]]; src <- "conditional"
        if (is.null(f) || !any(names(f) %in% left)) { f <- flows$pooled[[cl]]; src <- "pooled" }
        f <- if (is.null(f)) NULL else f[names(f) %in% left]
        if (is.null(f) || !length(f) || sum(f) <= 0) {
          src <- "proportional"
          f <- shares[i, left]
        }
        shares[i, names(f)] <- shares[i, names(f)] + freed[i, cl] * f / sum(f)
        how[[src]] <- how[[src]] + 1L
      }
    }
    rs <- rowSums(shares); k <- rs > 0
    shares[k, ] <- shares[k, , drop = FALSE] * (tot[k] / rs[k])
  } else {
    rs <- rowSums(shares); k <- rs > 0
    shares[k, ] <- 100 * shares[k, , drop = FALSE] / rs[k]
  }
  shares <- class_conserve(shares, orig, rk %in% seats_known, names(zcells), tot, label, code)
  skipped <- setdiff(colnames(shares), classes_known)
  cat(sprintf("%s  %s: zeroed %d cell(s) with no candidate standing (%.1f points of share in total)%s%s%s\n",
              code, label, n0, mass,
              if (mode == "2") sprintf(" | freed share by flows: %d conditional, %d pooled, %d proportional", how[["conditional"]], how[["pooled"]], how[["proportional"]]) else "",
              if (length(worst)) paste0("; >= 5: ", paste(utils::head(worst, 8), collapse = ", ")) else "",
              if (length(skipped)) paste0(" | classes absent from the result table, untouched: ", paste(skipped, collapse = "/")) else ""))
  shares
}


# Classes that are ONE party statewide, so a seat it skips is vote it keeps elsewhere (plans/prereg-partial-contest
# amendment 1). IND, OTH and OTH_RIGHT are buckets of unrelated candidates and are never conserved.
CONSERVE_CLASSES <- c("ALP", "LNP", "GRN", "ONP")

#' @noRd
class_conserve_on <- function() {
  m <- Sys.getenv("AUSPOL_CLASS_CONSERVE", "0")
  if (!m %in% c("0", "1")) stop("AUSPOL_CLASS_CONSERVE must be \"0\" or \"1\", got \"", m, "\"")
  identical(m, "1")
}

#' Keep a party's statewide total in the seats it contests (AUSPOL_CLASS_CONSERVE, arm A)
#'
#' After nomination zeroing, a single-party class that skipped seats has lost that share to the skipped seats'
#' other classes. Under `AUSPOL_CLASS_CONSERVE=1` its contested cells are scaled so its seat-mean total over the
#' nominated seats equals the pre-zeroing one, and each such row's other cells absorb the difference in proportion
#' to their size. A row whose
#' conserved cells would exceed its total is left as it was and named. plans/prereg-partial-contest-2026-10-19.md.
#' @param shares Zeroed shares. @param orig Shares before zeroing. @param rows Logical, the nominated seats.
#' @param classes Classes that had cells zeroed. @param tot Row totals to keep. @return `shares`.
#' @noRd
class_conserve <- function(shares, orig, rows, classes, tot, label, code) {
  if (!class_conserve_on()) return(shares)
  cl_c <- intersect(classes, CONSERVE_CLASSES)
  if (!length(cl_c) || !any(rows)) {
    cat(sprintf("%sC %s: AUSPOL_CLASS_CONSERVE=1, no single-party class skipped a seat\n", code, label)); return(shares)
  }
  scale <- setNames(rep(1, length(cl_c)), cl_c); msg <- character(0)
  for (cl in cl_c) {
    before <- mean(orig[rows, cl]); after <- mean(shares[rows, cl]); k <- sum(rows & shares[, cl] > 0)
    if (k == 0L || after <= 0) { msg <- c(msg, sprintf("%s stood nowhere, nothing to conserve", cl)); next }
    scale[[cl]] <- before / after
    msg <- c(msg, sprintf("%s in %d of %d seats, seat-mean %.2f -> %.2f restored (x%.2f)", cl, k, sum(rows), before, after, before / after))
  }
  bad <- character(0)
  for (i in which(rows)) {
    hit <- cl_c[shares[i, cl_c] > 0 & scale[cl_c] != 1]
    if (!length(hit)) next
    new_c <- shares[i, hit] * scale[hit]
    others <- setdiff(colnames(shares)[shares[i, ] > 0], hit)   # every other class in the row gives up share proportionally
    room <- tot[i] - sum(new_c)
    if (!length(others) || room <= 0) { bad <- c(bad, rownames(shares)[i]); next }
    shares[i, others] <- shares[i, others] * room / sum(shares[i, others])
    shares[i, hit] <- new_c
  }
  cat(sprintf("%sC %s: AUSPOL_CLASS_CONSERVE=1: %s%s\n", code, label, paste(msg, collapse = "; "),
              if (length(bad)) paste0(" | rows left unscaled (no room): ", paste(bad, collapse = ", ")) else ""))
  shares
}

# Nominations close at noon on 9 November 2026. WARNING-ONLY: AUSPOL_NOM_LIVE=1
# set before this date logs a loud warning; it never blocks.
NOM_GATE_DATE <- as.Date("2026-11-10")

# A class standing in fewer than this share of its vic2022 seat count is warned
# about by name. A warning threshold only (nothing is blocked by it), so it is
# a display choice, not a model constant.
NOM_CLASS_WARN_RATIO <- 0.8

#' Has someone asked for live nomination zeroing?
#'
#' TRUE for any `AUSPOL_NOM_LIVE` other than `"0"` and `"auto"`. When TRUE, every
#' way of not applying it is an error (a typo such as `true` or `"1 "` included),
#' because a forecast that silently runs without the zeroing Pete asked for is
#' the failure this guards against. `auto` keeps the quiet no-op.
#' @return logical(1)
#' @export
nom_zero_requested <- function() !Sys.getenv("AUSPOL_NOM_LIVE", "auto") %in% c("0", "auto")

.nz_stop <- function(...) stop("NZL!! ", ..., call. = FALSE)

#' Live nomination table for the target election, or NULL with the reason
#'
#' The published forecast's candidate list is incomplete until nominations close
#' (vic2026 on Wikipedia: 379 candidacies against vic2022's 731; Labor in 74 of
#' 88 seats, and Labor will contest all 88). Treating a blank as "not standing"
#' would zero parties that are about to nominate, so the table is only returned
#' once a person says it is the final list:
#'   * `AUSPOL_NOM_LIVE=1`: the ONLY way the gate opens, meaning the VEC final
#'     list has been loaded into `output/candidacies.csv`.
#'   * `"auto"` (default) and `"0"`: shut, quietly (`auto` says the list is
#'     provisional).
#'   * anything else, or `1` and then a failure below: an ERROR, never a quiet
#'     no-op.
#' With `=1` the count floor (`min_ratio`) is a hard check (a final list far
#' smaller than the previous election's is a load error), as are a missing
#' `candidacies.csv`, no `election` rows, and no `prior` baseline. Everything
#' else is a WARNING returned in `$warnings`: `=1` before `closes`; ALP or LNP
#' absent in some seats (a major party can genuinely not stand; any predicted
#' share there WILL be zeroed); any class standing in under
#' `NOM_CLASS_WARN_RATIO` of its previous seat count; a seat with no candidacy at
#' all (left untouched); candidacy seats matching no forecast seat.
#'
#' @param seats Seat names of the forecast (rownames of the share matrix).
#' @param election,prior Corpus labels.
#' @param corpus `candidacies.csv` data.table (seat, party, election); read from
#'   `output/candidacies.csv` when NULL.
#' @param closes Date before which `=1` logs a warning (`NOM_GATE_DATE`); never blocks.
#' @param major Classes whose absence from a seat is warned about.
#' @param today Injectable for tests.
#' @param min_ratio Hard floor against the previous election's count.
#' @return list(target = data.table(seat, party, votes) or NULL, reason = chr,
#'   warnings = chr, class_counts = chr).
#' @export
live_nominations <- function(seats, election = "vic2026", prior = "vic2022", corpus = NULL,
                             closes = NOM_GATE_DATE, today = Sys.Date(), min_ratio = 0.85,
                             major = c("ALP", "LNP")) {
  mode <- Sys.getenv("AUSPOL_NOM_LIVE", "auto")
  if (identical(mode, "0")) return(list(target = NULL, reason = "AUSPOL_NOM_LIVE=0"))
  if (identical(mode, "auto"))
    return(list(target = NULL, reason = "provisional list, set AUSPOL_NOM_LIVE=1 after loading the VEC final list"))
  if (!identical(mode, "1"))
    .nz_stop(sprintf("AUSPOL_NOM_LIVE='%s' is not recognised (use 0, auto or 1); refusing to run without the zeroing that was asked for", mode))
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) .nz_stop("AUSPOL_NOM_LIVE=1 but output/candidacies.csv is missing")
    C <- data.table::fread(f, showProgress = FALSE, select = c("election", "seat", "party"))
  }
  C <- data.table::as.data.table(C)
  elec <- C$election
  # masks computed OUTSIDE the brackets: `election` is also a column of C, and a
  # bare `election` inside C[...] would bind to it (data.table NSE trap).
  mask_now <- !is.na(elec) & elec == election & !is.na(C$party)
  mask_prv <- !is.na(elec) & elec == prior & !is.na(C$party)
  now <- C[mask_now]
  prv <- C[mask_prv]
  if (!nrow(now)) .nz_stop(sprintf("AUSPOL_NOM_LIVE=1 but the corpus has no %s candidacies", election))
  if (!nrow(prv)) .nz_stop(sprintf("AUSPOL_NOM_LIVE=1 but the corpus has no %s candidacies to size completeness against", prior))
  # HARD CHECK: overall count against the previous election.
  ratio <- nrow(now) / nrow(prv)
  if (ratio < min_ratio)
    .nz_stop(sprintf("list too small, probably a load error: %d candidacies vs %d at %s (%.0f%% < %.0f%% floor)",
                     nrow(now), nrow(prv), prior, 100 * ratio, 100 * min_ratio))
  # WARNINGS, not blocks: a major party can genuinely not stand in a seat (ABC's
  # list of 2026-10-03 had no ALP in 8 seats and no LNP in 8).
  ns <- normalise_seat(seats)
  now_seats <- normalise_seat(now$seat)
  warns <- character(0)
  if (today < closes)
    warns <- c(warns, sprintf("AUSPOL_NOM_LIVE=1 set on %s, before %s: nominations may not have closed", format(today), format(closes)))
  show <- function(g) paste0(paste(utils::head(g, 8), collapse = ", "), if (length(g) > 8) ", ..." else "")
  missing_seats <- setdiff(ns, now_seats)
  for (cl in major) {
    # seats with no candidacy at all are left untouched, so they are not "zeroed"
    gap <- setdiff(ns, c(missing_seats, normalise_seat(now$seat[now$party == cl])))
    if (length(gap))
      warns <- c(warns, sprintf("%s has no candidacy in %d of %d forecast seats; any predicted %s share there will be ZEROED: %s",
                                cl, length(gap), length(ns), cl, show(gap)))
  }
  if (length(missing_seats))
    warns <- c(warns, sprintf("%d forecast seat(s) have no candidacy at all and are left untouched: %s", length(missing_seats), show(missing_seats)))
  stray <- setdiff(unique(now_seats), ns)
  if (length(stray))
    warns <- c(warns, sprintf("%d candidacy seat name(s) match no forecast seat: %s", length(stray), show(stray)))
  # Per class: seats standing now against the previous election.
  cls <- sort(unique(c(now$party, prv$party)))
  n_now <- vapply(cls, function(cl) length(unique(normalise_seat(now$seat[now$party == cl]))), integer(1))
  n_prv <- vapply(cls, function(cl) length(unique(normalise_seat(prv$seat[prv$party == cl]))), integer(1))
  for (k in seq_along(cls)) {
    if (n_prv[k] > 0L && n_now[k] < NOM_CLASS_WARN_RATIO * n_prv[k])
      warns <- c(warns, sprintf("%s stands in %d seats against %d at %s (under %.0f%%): check the list is complete for this class",
                                cls[k], n_now[k], n_prv[k], prior, 100 * NOM_CLASS_WARN_RATIO))
  }
  list(target = data.table::data.table(seat = now$seat, party = now$party, votes = 1),
       reason = sprintf("%d candidacies (%.0f%% of %s)", nrow(now), 100 * ratio, prior),
       warnings = warns,
       class_counts = paste(sprintf("%s %d/%d", cls, n_now, n_prv), collapse = " "))
}

#' Cells a nomination step zeroed
#'
#' @param before,after Share matrices around the zeroing step.
#' @return data.frame(seat, class) of cells positive before and exactly 0 after.
#' @export
nomination_zeroed_cells <- function(before, after) {
  w <- which(before > 0 & after == 0, arr.ind = TRUE)
  data.frame(seat = rownames(before)[w[, 1]], class = colnames(before)[w[, 2]], stringsAsFactors = FALSE)
}

#' Stop if any cell the nomination step zeroed is no longer exactly 0
#'
#' The zeroing must come AFTER every step that can add share to a cell; this is
#' the check at the final write that it did (the seat-swing port, demographic
#' correction, leader-seat bonus and salience blend can each resurrect a zeroed
#' cell if the zeroing is placed ahead of them).
#' @param shares The share matrix about to be written.
#' @param cells Output of [nomination_zeroed_cells()].
#' @return `TRUE` invisibly.
#' @export
assert_nomination_zeros <- function(shares, cells) {
  if (is.null(cells) || !nrow(cells)) return(invisible(TRUE))
  v <- shares[cbind(match(cells$seat, rownames(shares)), match(cells$class, colnames(shares)))]
  bad <- is.na(v) | v != 0
  if (any(bad))
    stop(sprintf("NZL!! %d cell(s) zeroed for having no candidate are no longer 0 at the final write: %s",
                 sum(bad), paste(utils::head(sprintf("%s %s = %.3f", cells$seat[bad], cells$class[bad], v[bad]), 10), collapse = ", ")),
         call. = FALSE)
  invisible(TRUE)
}

#' Where in the harness pipeline does nomination zeroing run?
#'
#' `AUSPOL_NOM_ZERO_ORDER`: `"late"` (the default since 2026-10-04, what ships)
#' zeroes after the last step that can write a share back into a zeroed cell
#' (seat-swing port, demographic correction, leader-seat bonus, salience
#' blend), the same position the published forecast uses; `"early"` (the order
#' v61 was first measured on) zeroes right after the xgb override and lets those
#' steps revive a zeroed cell. Anything else is an error: an unrecognised value
#' that silently fell back to the other order would be an arm that looks like it ran.
#' plans/prereg-zero-order-2026-10-03.md
#' @return `"early"` or `"late"`.
#' @export
nom_zero_order <- function() {
  o <- Sys.getenv("AUSPOL_NOM_ZERO_ORDER", "late")
  if (!o %in% c("early", "late"))
    stop(sprintf("NZO!! AUSPOL_NOM_ZERO_ORDER='%s' is not 'early' or 'late'", o), call. = FALSE)
  o
}

#' [zero_unnominated()] at one of its two harness positions
#'
#' Runs the zeroing only when `stage` is the configured [nom_zero_order()];
#' otherwise returns `shares` untouched. With `stage = "early"` and the default
#' order this is exactly the call the harnesses made before the switch existed.
#' @param stage `"early"` (after the xgb override) or `"late"` (after the last
#'   reviving step).
#' @inheritParams zero_unnominated
#' @return `shares`, zeroed if `stage` is the configured order.
#' @export
zero_unnominated_at <- function(stage, shares, target, label, code = "NZ1", flows = NULL) {
  stopifnot(length(stage) == 1L, stage %in% c("early", "late"))
  if (!identical(nom_zero_order(), stage)) return(shares)
  zero_unnominated(shares, target, label, code = code, flows = flows)
}

#' The final-write check for `AUSPOL_NOM_ZERO_ORDER = "late"`
#'
#' A no-op in `"early"` mode, where a zeroed cell can legitimately be revived by
#' a later step (the known leak this order switch exists to remove) and the
#' check would fire on it. In `"late"` mode, stops if any cell the zeroing step
#' zeroed is no longer exactly 0. Cells for seats no longer in `shares` (a
#' pair's unscored seats, dropped before the write) are not checked.
#' @param shares The share matrix the harness writes out.
#' @param cells Output of [nomination_zeroed_cells()], or NULL.
#' @return `TRUE` invisibly.
#' @export
nom_zero_assert_late <- function(shares, cells) {
  if (!identical(nom_zero_order(), "late")) return(invisible(TRUE))
  if (!is.null(cells) && nrow(cells)) {
    cells <- cells[cells$seat %in% rownames(shares), , drop = FALSE]
  }
  assert_nomination_zeros(shares, cells)
}

#' Zero non-standing parties in the live forecast, or say why not
#'
#' Wrapper the published forecast calls AFTER the last step that can add share
#' to a cell, mirroring the harnesses' `zero_unnominated(shares, fb, ...,
#' flows = fm)`. Always prints one `NZL` line: either what was applied or why
#' nothing was. Errors (rather than a quiet no-op) whenever
#' [nom_zero_requested()] and zeroing cannot be applied.
#' @param shares Seat-by-class matrix of primaries, with rownames.
#' @param flows The live [build_flow_matrix()] result.
#' @param label Election label (also the corpus label).
#' @param prior The previous election's label, for the per-class seat counts.
#' @param code Log code for [zero_unnominated()]'s summary line.
#' @param ... passed on to `live_nominations()`.
#' @return `shares`, unchanged unless `AUSPOL_NOM_LIVE=1` and the list passes the count floor.
#' @export
zero_unnominated_live <- function(shares, flows, label = "vic2026", prior = "vic2022", code = "NZ1", ...) {
  if (is.null(rownames(shares)))
    stop("NZL!! the share matrix has no rownames (seat names); nomination zeroing cannot match seats", call. = FALSE)
  nm <- live_nominations(rownames(shares), election = label, prior = prior, ...)
  if (is.null(nm$target)) {
    cat(sprintf("NZL  %s: nomination zeroing NOT applied (%s); shares unchanged\n", label, nm$reason))
    return(shares)
  }
  for (w in nm$warnings) cat(sprintf("NZL! %s: WARNING %s\n", label, w))
  cat(sprintf("NZL  %s: candidacies per class, seats now/%s: %s\n", label, prior, nm$class_counts))
  zmode <- Sys.getenv("AUSPOL_NOM_ZERO", "2")
  if (!zmode %in% c("1", "2")) {
    # Zeroing was asked for (we are past the gate, so AUSPOL_NOM_LIVE=1) but the
    # mode switch turns it off: contradictory, so stop. Only HERE, not in
    # zero_unnominated(), whose AUSPOL_NOM_ZERO=0 is the harnesses' legitimate off switch.
    .nz_stop(sprintf("AUSPOL_NOM_LIVE=1 asked for nomination zeroing but AUSPOL_NOM_ZERO='%s' is not 1 or 2 (it would turn zeroing off); set AUSPOL_NOM_ZERO=1 or 2, or AUSPOL_NOM_LIVE=0",
                     zmode))
  }
  out <- zero_unnominated(shares, nm$target, label, code = code, flows = flows)
  zc <- nomination_zeroed_cells(shares, out)
  nchg <- sum(abs(out - shares) > 1e-9)
  absent <- setdiff(colnames(shares), unique(nm$target$party))
  note <- if (length(absent)) sprintf("; classes skipped, absent from the nomination table: %s", paste(absent, collapse = "/")) else ""
  if (nchg > 0L) {
    per <- table(zc$class)
    cat(sprintf("NZL  %s: applied: %d cells changed, %d zeroed (%s) (%s)%s\n", label, nchg, nrow(zc),
                paste(sprintf("%s %d", names(per), as.integer(per)), collapse = ", "), nm$reason, note))
  } else {
    cat(sprintf("NZL  %s: no-op: nothing changed (every class in the forecast stands where it is predicted; %s)%s\n",
                label, nm$reason, note))
  }
  out
}

#' Is the live pre-xgb nomination zero on? (`AUSPOL_NOM_ZERO_PRE_XGB`)
#'
#' `"0"` (default, published): off. `"1"`: the published forecast ALSO runs
#' [zero_unnominated_live()] on the base just before the xgb trees, so the trees'
#' `base_pred` / `base_margin` has the same exact zeros and flow-redistributed
#' share the training base has (stage 1 of `rebuild_forecasts.sh` writes its
#' sharedetail after the harnesses' nomination zero). Audit F18,
#' plans/prereg-nom-zero-pre-xgb-2026-10-25.md. Anything else is an error.
#' @return `"0"` or `"1"`.
#' @export
nom_zero_pre_xgb_mode <- function() {
  m <- Sys.getenv("AUSPOL_NOM_ZERO_PRE_XGB", "0")
  if (!m %in% c("0", "1"))
    stop(sprintf("NZP1!! AUSPOL_NOM_ZERO_PRE_XGB='%s' is not '0' or '1'", m), call. = FALSE)
  m
}

#' The live nomination zero on the BASE, before the xgb trees (`AUSPOL_NOM_ZERO_PRE_XGB`)
#'
#' Off (`"0"`), returns `shares` untouched and prints one `NZP1` line saying so.
#' On, runs exactly [zero_unnominated_live()] (same list, same gate, same mode-2
#' flow redistribution as training's zero); the cells it zeroed are counted on
#' the `NZL` and `NZP2` lines that follow the `NZP1` line. Until
#' `AUSPOL_NOM_LIVE=1` opens the gate it changes nothing, and says so. On, every
#' error propagates, whatever `AUSPOL_NOM_LIVE` says. The post-xgb call is kept
#' as the final guard: the trees write a prediction back into every cell, zeroed
#' ones included.
#' @inheritParams zero_unnominated_live
#' @return `shares`, zeroed when on and the nomination gate is open.
#' @export
zero_unnominated_live_pre_xgb <- function(shares, flows, label = "vic2026", prior = "vic2022", ...) {
  if (identical(nom_zero_pre_xgb_mode(), "0")) {
    cat(sprintf("NZP1  %s: pre-xgb nomination zero OFF (AUSPOL_NOM_ZERO_PRE_XGB=0); base unchanged\n", label))
    return(shares)
  }
  # The counts are not repeated here: the NZL lines (cells changed and zeroed, per class) and the NZP2
  # line that follow are this call's, and say so by sitting under this one.
  cat(sprintf("NZP1  %s: pre-xgb nomination zero ON: zeroing the base before the trees (counts: the NZL/NZP2 lines below)\n", label))
  zero_unnominated_live(shares, flows, label, prior = prior, code = "NZP2", ...)
}

#' Where a harness leaves the flow matrix its nomination zeroing used
#' @param label Election label, e.g. `"vic2022"`.
#' @param dir Output directory.
#' @return File path.
#' @export
nom_zero_flows_path <- function(label, dir = "output") file.path(dir, sprintf("nomzero-flows-%s.rds", label))

#' Save the flow matrix a harness hands to [zero_unnominated_at()]
#'
#' Each harness builds its own time-forward `fm` (its own prior election, source
#' file and pooling), and there is no shared constructor. Rather than re-derive
#' six recipes in the forecasts table, the harness writes the very object it
#' zeroes with, beside the zeroing call, and [zero_unnominated_asat()] reads it.
#' An `fm` of NULL (WA with no transfers) is saved as NULL: the harness then
#' split proportionally itself, and the table says so.
#' @param fm The harness's [build_flow_matrix()] result, or NULL.
#' @param label Election label.
#' @param dir Output directory.
#' @return `invisible(path)`.
#' @export
nom_zero_save_flows <- function(fm, label, dir = "output") {
  p <- nom_zero_flows_path(label, dir)
  saveRDS(list(label = label, flows = fm, saved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
               xgb_primary = Sys.getenv("AUSPOL_XGB_PRIMARY")), p)   # provenance only: what the saving run had set
  invisible(p)
}

#' Read the saved flow matrices for a set of elections, or stop
#'
#' @param labels Election labels in the table.
#' @param dir Output directory.
#' @param newer_than Path of a file every flows file must be newer than (the
#'   as-at predictions), or `NULL` to skip the freshness check.
#' @param xgb_primary The `AUSPOL_XGB_PRIMARY` value the saving run must have
#'   had (`"1"`, stage 6), or `NULL` to skip.
#' @return Named list of flow matrices (an element may be NULL, see
#'   [nom_zero_save_flows()]).
#' @export
nom_zero_load_flows <- function(labels, dir = "output", newer_than = NULL, xgb_primary = "1") {
  out <- list()
  # A flows file is only trusted if a STAGE-6 run wrote it: newer than the as-at
  # predictions it zeroes (`newer_than`, stage 4), and saved by a harness run at
  # AUSPOL_XGB_PRIMARY = `xgb_primary`. Stage 1 (xgb 0) and any hand run write
  # the same path, so existence alone would accept a stale or off-config matrix.
  ref_t <- if (!is.null(newer_than)) file.mtime(newer_than) else NA
  if (!is.null(newer_than) && is.na(ref_t))
    stop(sprintf("NZA!! reference file for flows freshness not found: %s", newer_than), call. = FALSE)
  for (l in labels) {
    p <- nom_zero_flows_path(l, dir)
    if (!file.exists(p))
      stop(sprintf("NZA!! no saved flow matrix for %s (%s): run its harness (stage 6) first. Refusing to fall back to proportional redistribution, which v61 refused.", l, p), call. = FALSE)
    if (!is.na(ref_t) && file.mtime(p) <= ref_t)
      stop(sprintf("NZA!! flow matrix for %s (%s, %s) is OLDER than %s (%s): stale, rerun stage 6.", l, p,
                   format(file.mtime(p)), basename(newer_than), format(ref_t)), call. = FALSE)
    o <- readRDS(p)
    if (!is.null(xgb_primary) && !identical(o$xgb_primary, xgb_primary))
      stop(sprintf("NZA!! flow matrix for %s was saved by a run at AUSPOL_XGB_PRIMARY='%s', expected '%s' (stage 6): a stage-1 or hand run overwrote it.",
                   l, o$xgb_primary %||% "<missing>", xgb_primary), call. = FALSE)
    cat(sprintf("NZA  %s: flows from %s (saved %s)%s\n", l, basename(p), o$saved_at,
                if (is.null(o$flows)) " -- harness had NO flow matrix, it split proportionally too" else ""))
    out[l] <- list(o$flows)
  }
  out
}

#' Nomination zeroing for the as-at forecasts table
#'
#' `output/forecasts.csv` is built from the as-at XGBoost predictions
#' (`scripts/fit_xgb_primary_asat.R`), which never passed through
#' [zero_unnominated()]: the six harnesses and `fit_seats_full.R` zero a class
#' that did not stand, the table did not, so it still scored vic2022 Narracan
#' Labor at 23.9 when Labor did not contest (actual 0). 95 cells with actual 0
#' and forecast >= 3 were 1.45% of the table's squared error (2026-10-05,
#' docs/reviews/worst-overcalls-2026-10-05.md, bug 4).
#'
#' Applied at the same point as the harnesses' late step: the xgb prediction is
#' final (`pmax(0, raw)`) and nothing later in this table adds share to a cell.
#' It honours `AUSPOL_NOM_ZERO` (`0` leaves the table byte-identical), and the
#' freed share is split by each election's `flows`, the matrix its harness used
#' (see [nom_zero_save_flows()]). Which classes stood is read from the election's own result
#' rows (`actual_share > 0`), the same table the harnesses pass as `fb`; a seat
#' with no finite result is left untouched. Each seat's raw total is preserved.
#'
#' @param F data.table with `election`, `seat`, `party`, `xgb_pred`,
#'   `actual_share`.
#' @param flows Named list of [build_flow_matrix()] results keyed by election
#'   label, from [nom_zero_load_flows()]. Required at `AUSPOL_NOM_ZERO=2`.
#' @param allow_proportional Let an election without flows split the freed
#'   share proportionally (tests only; v61 refused that variant).
#' @return A copy of `F` with `xgb_pred` zeroed where no candidate stood, and a
#'   new column `xgb_pred_prezero` holding the value before (absent when
#'   `AUSPOL_NOM_ZERO` is off, so the off table is unchanged).
#' @export
zero_unnominated_asat <- function(F, flows = NULL, allow_proportional = FALSE) {
  F <- data.table::copy(data.table::as.data.table(F))
  mode <- Sys.getenv("AUSPOL_NOM_ZERO", "2")
  if (!mode %in% c("1", "2")) return(F)   # off: no column added either
  if (mode == "2" && !allow_proportional) {
    miss <- setdiff(unique(F$election), names(flows))
    if (length(miss))
      stop(sprintf("NZA!! AUSPOL_NOM_ZERO=2 needs a flow matrix per election; missing for: %s (v61 refused proportional redistribution)",
                   paste(miss, collapse = ", ")), call. = FALSE)
  }
  F[, "xgb_pred_prezero" := F$xgb_pred]
  for (el in unique(F$election)) {
    idx <- which(F$election == el)
    d <- F[idx]
    ok <- is.finite(d$xgb_pred)
    if (!any(ok)) next
    seats <- unique(d$seat); classes <- unique(d$party)
    m <- matrix(0, length(seats), length(classes), dimnames = list(seats, classes))
    m[cbind(match(d$seat[ok], seats), match(d$party[ok], classes))] <- d$xgb_pred[ok]
    st <- is.finite(d$actual_share) & d$actual_share > 0
    tg <- data.table::data.table(seat = d$seat[st], party = d$party[st], votes = 1)
    m2 <- zero_unnominated(m, tg, el, code = "NZA", flows = flows[[el]])
    # zero_unnominated() renormalises a row to 100 when it splits the freed share
    # proportionally; these rows are RAW xgb output (they do not sum to 100, the
    # classes the model never predicts are absent), so put each touched row back
    # to its own total and leave every untouched row exactly as it was.
    touched <- rowSums(m > 0 & m2 == 0) > 0
    rs2 <- rowSums(m2)
    k <- touched & rs2 > 0
    m2[k, ] <- m2[k, , drop = FALSE] * (rowSums(m)[k] / rs2[k])
    m2[!touched, ] <- m[!touched, , drop = FALSE]
    new <- m2[cbind(match(d$seat, seats), match(d$party, classes))]
    new[!ok] <- d$xgb_pred[!ok]
    data.table::set(F, idx, "xgb_pred", new)
  }
  F
}
