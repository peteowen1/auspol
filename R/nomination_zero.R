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
    shares <- shares * (tot / rowSums(shares))
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
