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

# Nominations close at noon on 9 November 2026. The gate opens the day AFTER, so
# a clock in any timezone cannot fire it before they have closed.
NOM_GATE_DATE <- as.Date("2026-11-10")

#' Live nomination table for the target election, or NULL with the reason
#'
#' The published forecast's candidate list is incomplete until nominations close
#' (vic2026 on Wikipedia: 379 candidacies against vic2022's 731; Labor in 74 of
#' 88 seats, and Labor will contest all 88). Treating a blank as "not standing"
#' would zero parties that are about to nominate, so the table is only returned
#' once it is plausibly the final list:
#'   * `AUSPOL_NOM_LIVE=0`: off.
#'   * `"auto"` (default): only on or after `closes`, AND the list passes the
#'     completeness floor below.
#'   * `"1"`: skips the date test only. The completeness floor always applies.
#' Completeness: PRIMARY, ALP and LNP each have a candidacy in every seat of
#' `seats` (the failing class and seat count are reported); SECONDARY, the list
#' holds at least `min_ratio` of the previous election's candidacies, and every
#' seat has some candidacy.
#'
#' @param seats Seat names of the forecast (rownames of the share matrix).
#' @param election,prior Corpus labels.
#' @param corpus `candidacies.csv` data.table (seat, party, election); read from
#'   `output/candidacies.csv` when NULL.
#' @param closes First date the `auto` gate opens (`NOM_GATE_DATE`).
#' @param major Classes that must stand in every seat.
#' @param today Injectable for tests.
#' @param min_ratio Completeness floor against the previous election's count.
#' @return list(target = data.table(seat, party, votes) or NULL, reason = chr).
#' @export
live_nominations <- function(seats, election = "vic2026", prior = "vic2022", corpus = NULL,
                             closes = NOM_GATE_DATE, today = Sys.Date(), min_ratio = 0.85,
                             major = c("ALP", "LNP")) {
  mode <- Sys.getenv("AUSPOL_NOM_LIVE", "auto")
  if (identical(mode, "0")) return(list(target = NULL, reason = "AUSPOL_NOM_LIVE=0"))
  if (!mode %in% c("auto", "1")) return(list(target = NULL, reason = sprintf("AUSPOL_NOM_LIVE=%s not recognised (0, auto, 1)", mode)))
  if (identical(mode, "auto") && today < closes)
    return(list(target = NULL, reason = sprintf("nominations not closed until %s", format(closes))))
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
  # PRIMARY CHECK: both majors have a candidacy in EVERY seat. Labor and the
  # Coalition contest every seat, so a gap is an unannounced candidate, never a
  # decision not to stand. A raw count cannot see this: a list can pass any count
  # floor while Labor is still missing from a dozen seats.
  ns <- normalise_seat(seats)
  for (cl in major) {
    gap <- setdiff(ns, normalise_seat(now$seat[now$party == cl]))
    if (length(gap))
      return(list(target = NULL, reason = sprintf("list incomplete: %s has no candidacy in %d of %d seats (%s%s)",
                                                  cl, length(gap), length(ns), paste(utils::head(gap, 4), collapse = ", "),
                                                  if (length(gap) > 4) ", ..." else "")))
  }
  ratio <- nrow(now) / n_prior
  # SECONDARY CHECK: overall count against the previous election.
  if (ratio < min_ratio)
    return(list(target = NULL, reason = sprintf("list incomplete: %d candidacies vs %d at %s (%.0f%% < %.0f%% floor)",
                                                nrow(now), n_prior, prior, 100 * ratio, 100 * min_ratio)))
  missing_seats <- setdiff(normalise_seat(seats), normalise_seat(now$seat))
  if (length(missing_seats))
    return(list(target = NULL, reason = sprintf("%d seat(s) have no candidacy: %s", length(missing_seats),
                                                paste(utils::head(missing_seats, 6), collapse = ", "))))
  list(target = data.table::data.table(seat = now$seat, party = now$party, votes = 1),
       reason = sprintf("%d candidacies (%.0f%% of %s)", nrow(now), 100 * ratio, prior))
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
#' @return `shares`, unchanged unless the live list is complete.
#' @export
zero_unnominated_live <- function(shares, flows, label = "vic2026", ...) {
  nm <- live_nominations(rownames(shares), election = label, ...)
  if (is.null(nm$target)) {
    cat(sprintf("NZL  %s: nomination zeroing NOT applied (%s); shares unchanged\n", label, nm$reason))
    return(shares)
  }
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
