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
  skipped <- setdiff(colnames(shares), classes_known)
  cat(sprintf("%s  %s: zeroed %d cell(s) with no candidate standing (%.1f points of share in total)%s%s%s\n",
              code, label, n0, mass,
              if (mode == "2") sprintf(" | freed share by flows: %d conditional, %d pooled, %d proportional", how[["conditional"]], how[["pooled"]], how[["proportional"]]) else "",
              if (length(worst)) paste0("; >= 5: ", paste(utils::head(worst, 8), collapse = ", ")) else "",
              if (length(skipped)) paste0(" | classes absent from the result table, untouched: ", paste(skipped, collapse = "/")) else ""))
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
#' @param ... passed on to `live_nominations()`.
#' @return `shares`, unchanged unless `AUSPOL_NOM_LIVE=1` and the list passes the count floor.
#' @export
zero_unnominated_live <- function(shares, flows, label = "vic2026", ...) {
  if (is.null(rownames(shares)))
    stop("NZL!! the share matrix has no rownames (seat names); nomination zeroing cannot match seats", call. = FALSE)
  nm <- live_nominations(rownames(shares), election = label, ...)
  if (is.null(nm$target)) {
    cat(sprintf("NZL  %s: nomination zeroing NOT applied (%s); shares unchanged\n", label, nm$reason))
    return(shares)
  }
  for (w in nm$warnings) cat(sprintf("NZL! %s: WARNING %s\n", label, w))
  cat(sprintf("NZL  %s: candidacies per class, seats now/%s: %s\n", label, "vic2022", nm$class_counts))
  zmode <- Sys.getenv("AUSPOL_NOM_ZERO", "2")
  if (!zmode %in% c("1", "2")) {
    # Zeroing was asked for (we are past the gate, so AUSPOL_NOM_LIVE=1) but the
    # mode switch turns it off: contradictory, so stop. Only HERE, not in
    # zero_unnominated(), whose AUSPOL_NOM_ZERO=0 is the harnesses' legitimate off switch.
    .nz_stop(sprintf("AUSPOL_NOM_LIVE=1 asked for nomination zeroing but AUSPOL_NOM_ZERO='%s' is not 1 or 2 (it would turn zeroing off); set AUSPOL_NOM_ZERO=1 or 2, or AUSPOL_NOM_LIVE=0",
                     zmode))
  }
  out <- zero_unnominated(shares, nm$target, label, flows = flows)
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
#' freed share is split by `flows` when given, else proportionally (the `NZ1!`
#' line says so). Which classes stood is read from the election's own result
#' rows (`actual_share > 0`), the same table the harnesses pass as `fb`; a seat
#' with no finite result is left untouched. Each seat's raw total is preserved.
#'
#' @param F data.table with `election`, `seat`, `party`, `xgb_pred`,
#'   `actual_share`.
#' @param flows Optional named list of [build_flow_matrix()] results keyed by
#'   election label.
#' @return A copy of `F` with `xgb_pred` zeroed where no candidate stood, and a
#'   new column `xgb_pred_prezero` holding the value before (absent when
#'   `AUSPOL_NOM_ZERO` is off, so the off table is unchanged).
#' @export
zero_unnominated_asat <- function(F, flows = NULL) {
  F <- data.table::copy(data.table::as.data.table(F))
  if (!Sys.getenv("AUSPOL_NOM_ZERO", "2") %in% c("1", "2")) return(F)   # off: no column added either
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
    m2 <- zero_unnominated(m, tg, el, code = "NZA", flows = if (is.null(flows)) NULL else flows[[el]])
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
