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

#' Live nomination table for the target election, or NULL with the reason
#'
#' The published forecast's candidate list is incomplete until nominations close
#' (vic2026 on Wikipedia: 379 candidacies against vic2022's 731; Labor in 74 of
#' 88 seats, and Labor will contest all 88). Treating a blank as "not standing"
#' would zero parties that are about to nominate, so the table is only returned
#' once a person says it is the final list:
#'   * `AUSPOL_NOM_LIVE=1`: the ONLY way the gate opens, meaning the VEC final
#'     list has been loaded into `output/candidacies.csv`.
#'   * `"auto"` (default) and `"0"`: shut. `auto` says the list is provisional.
#' With `=1` the count floor (`min_ratio`) is a hard check: a list far smaller
#' than the previous election's is a load error. Everything else is a WARNING
#' returned in `$warnings`: `=1` before `closes`; ALP or LNP absent in some seats
#' (they will be zeroed there, and a major party can genuinely not stand); a seat
#' with no candidacy at all (left untouched).
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
#'   warnings = chr).
#' @export
live_nominations <- function(seats, election = "vic2026", prior = "vic2022", corpus = NULL,
                             closes = NOM_GATE_DATE, today = Sys.Date(), min_ratio = 0.85,
                             major = c("ALP", "LNP")) {
  mode <- Sys.getenv("AUSPOL_NOM_LIVE", "auto")
  if (identical(mode, "0")) return(list(target = NULL, reason = "AUSPOL_NOM_LIVE=0"))
  if (!mode %in% c("auto", "1")) return(list(target = NULL, reason = sprintf("AUSPOL_NOM_LIVE=%s not recognised (0, auto, 1)", mode)))
  if (identical(mode, "auto"))
    return(list(target = NULL, reason = "provisional list, set AUSPOL_NOM_LIVE=1 after loading the VEC final list"))
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) return(list(target = NULL, reason = "output/candidacies.csv missing"))
    C <- data.table::fread(f, showProgress = FALSE, select = c("election", "seat", "party"))
  }
  C <- data.table::as.data.table(C)
  elec <- C$election
  keep_now <- !is.na(elec) & elec == election & !is.na(C$party)
  now <- C[keep_now]
  n_prior <- sum(!is.na(elec) & elec == prior)
  if (!nrow(now)) return(list(target = NULL, reason = sprintf("no %s candidacies in the corpus", election)))
  if (n_prior <= 0L) return(list(target = NULL, reason = sprintf("no %s candidacies to size completeness against", prior)))
  # HARD CHECK: overall count against the previous election. With =1 a final
  # list far smaller than the last one is a load error, not a forecast input.
  ratio <- nrow(now) / n_prior
  if (ratio < min_ratio)
    return(list(target = NULL, reason = sprintf("list too small, probably a load error: %d candidacies vs %d at %s (%.0f%% < %.0f%% floor)",
                                                nrow(now), n_prior, prior, 100 * ratio, 100 * min_ratio)))
  # WARNINGS, not blocks: a major party can genuinely not stand in a seat (ABC's
  # list of 2026-10-03 had no ALP in 8 seats and no LNP in 8). Each class listed
  # here WILL be zeroed in the named seats, so the log says so.
  ns <- normalise_seat(seats)
  warns <- character(0)
  if (today < closes)
    warns <- c(warns, sprintf("AUSPOL_NOM_LIVE=1 set on %s, before %s: nominations may not have closed", format(today), format(closes)))
  show <- function(g) paste0(paste(utils::head(g, 8), collapse = ", "), if (length(g) > 8) ", ..." else "")
  for (cl in major) {
    gap <- setdiff(ns, normalise_seat(now$seat[now$party == cl]))
    if (length(gap))
      warns <- c(warns, sprintf("%s has no candidacy in %d of %d seats and will be ZEROED there: %s", cl, length(gap), length(ns), show(gap)))
  }
  missing_seats <- setdiff(ns, normalise_seat(now$seat))
  if (length(missing_seats))
    warns <- c(warns, sprintf("%d seat(s) have no candidacy at all and are left untouched: %s", length(missing_seats), show(missing_seats)))
  list(target = data.table::data.table(seat = now$seat, party = now$party, votes = 1),
       reason = sprintf("%d candidacies (%.0f%% of %s)", nrow(now), 100 * ratio, prior),
       warnings = warns)
}

#' Zero non-standing parties in the live forecast, or say why not
#'
#' Wrapper the published forecast calls after the xgb live override, mirroring
#' the harnesses' `zero_unnominated(shares, fb, ..., flows = fm)`. Always prints
#' one `NZL` line: either what was applied or why nothing was.
#' @param shares Seat-by-class matrix of primaries.
#' @param flows The live [build_flow_matrix()] result.
#' @param label Election label (also the corpus label).
#' @param ... passed on to `live_nominations()`.
#' @return `shares`, unchanged unless `AUSPOL_NOM_LIVE=1` and the list passes the count floor.
#' @export
zero_unnominated_live <- function(shares, flows, label = "vic2026", ...) {
  nm <- live_nominations(rownames(shares), election = label, ...)
  if (is.null(nm$target)) {
    cat(sprintf("NZL  %s: nomination zeroing NOT applied (%s); shares unchanged\n", label, nm$reason))
    return(shares)
  }
  for (w in nm$warnings) cat(sprintf("NZL! %s: WARNING %s\n", label, w))
  zmode <- Sys.getenv("AUSPOL_NOM_ZERO", "2")
  if (!zmode %in% c("1", "2")) {
    cat(sprintf("NZL  %s: no-op: nothing changed (AUSPOL_NOM_ZERO=%s is not 1 or 2; list was complete: %s)\n",
                label, zmode, nm$reason))
    return(shares)
  }
  out <- zero_unnominated(shares, nm$target, label, flows = flows)
  nchg <- sum(abs(out - shares) > 1e-9)
  absent <- setdiff(colnames(shares), unique(nm$target$party))
  note <- if (length(absent)) sprintf("; classes skipped, absent from the nomination table: %s", paste(absent, collapse = "/")) else ""
  if (nchg > 0L) {
    cat(sprintf("NZL  %s: applied: %d cells changed (%s)%s\n", label, nchg, nm$reason, note))
  } else {
    cat(sprintf("NZL  %s: no-op: nothing changed (every class in the forecast stands where it is predicted; %s)%s\n",
                label, nm$reason, note))
  }
  out
}
