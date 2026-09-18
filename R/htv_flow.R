# HOW-TO-VOTE CARDS DECIDE ONE CELL OF THE FLOW TABLE, AND THE MODEL HAD NO
# INPUT FOR THEM. Liberal/LNP preferences with both ALP and GRN still alive
# went 58% to ALP in vic2018 (Liberal cards put Labor above the Greens) and
# 35% in vic2022 (cards put the Greens above Labor); qld2020 36%, qld2024
# 73% (Greens last); federal 59-73%. The flow table learned the PREVIOUS
# election's split and applied it, which is exactly wrong when the card
# flips -- Footscray, Richmond, Brunswick, Pascoe Vale (vic2022) and South
# Brisbane (qld2024) were all 6-8 points of 2CP out with the ACTUAL
# primaries and our flows (docs/SEAT-REGISTRY.md, 2026-09-18).
#
# A card order is public before polling day, so it is a legitimate input.
# external/reference/htv/liberal-alp-grn-order.csv records it per election
# (and optionally per seat); the two flow rows it selects between are
# MEASURED from the transfer files of every earlier election, labelled by
# their own observed split -- not typed in.

#' Read the Liberal how-to-vote order table
#'
#' @param path CSV with columns election, seat ("ALL" or a seat name),
#'   greens_above_labor (TRUE/FALSE), source.
#' @return data.table, or NULL with a message when the file is absent.
#' @export
htv_order_table <- function(path = file.path("external", "reference", "htv", "liberal-alp-grn-order.csv")) {
  if (!file.exists(path)) { cat(sprintf("HTV0! how-to-vote table missing at %s -- AUSPOL_HTV_FLOW does NOTHING this run\n", path)); return(NULL) }
  d <- data.table::fread(path, showProgress = FALSE)
  need <- c("election", "seat", "greens_above_labor")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop("HTV table lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  d[, greens_above_labor := as.logical(greens_above_labor)]
  d
}

#' Observed Liberal-to-ALP share when ALP and GRN are both alive, per election
#'
#' From the transfer files under `dir`: for every election, the share of
#' Liberal/LNP votes distributed to ALP (of those going to ALP or GRN) in
#' rounds where both received. `label` is "greens_above" when under 50%.
#'
#' @param dir Directory holding `*-transfers.csv` files.
#' @return data.table: election, alp_share, n_seats, label.
#' @export
htv_observed_splits <- function(dir = file.path("external", "elections")) {
  fs <- list.files(dir, pattern = "-transfers[.]csv$", full.names = TRUE)
  if (!length(fs)) return(NULL)
  tx <- data.table::rbindlist(lapply(fs, function(f) {
    d <- data.table::fread(f, showProgress = FALSE)
    d[d$from == "LNP" & d$to %in% c("ALP", "GRN"), list(election, seat, round, to, votes)]
  }), fill = TRUE)
  if (!nrow(tx)) return(NULL)
  both <- tx[, list(nn = data.table::uniqueN(to)), by = list(election, seat, round)][nn == 2L]
  tx <- merge(tx, both[, list(election, seat, round)], by = c("election", "seat", "round"))
  out <- tx[, list(alp_share = 100 * sum(votes[to == "ALP"]) / sum(votes), n_seats = data.table::uniqueN(seat)),
            by = election]
  out[, label := ifelse(alp_share < 50, "greens_above", "labor_above")]
  out[order(election)]
}

#' Fit the two Liberal-to-ALP shares the card order selects between
#'
#' Leave-target-out mean of the observed splits with the same label, seat-
#' weighted. Elections with fewer than `min_seats` qualifying seats are
#' dropped as too thin to label.
#'
#' @param target_election Election excluded from the fit.
#' @param dir,min_seats See [htv_observed_splits()].
#' @return list(greens_above = ALP share, labor_above = ALP share, n = table).
#' @export
fit_htv_flow_rows <- function(target_election, dir = file.path("external", "elections"), min_seats = 2L) {
  obs <- htv_observed_splits(dir)
  if (is.null(obs)) return(NULL)
  obs <- obs[obs$election != target_election & obs$n_seats >= min_seats]
  f <- function(lab) { s <- obs[obs$label == lab]; if (!nrow(s)) NA_real_ else sum(s$alp_share * s$n_seats) / sum(s$n_seats) }
  list(greens_above = f("greens_above"), labor_above = f("labor_above"), n = obs)
}

#' Apply the how-to-vote card to the Liberal-excluded, ALP+GRN-alive flow rows
#'
#' For every seat, every conditional key whose excluded party is LNP and
#' whose survivor set contains both ALP and GRN gets its ALP:GRN split
#' replaced by the fitted share for the card order recorded for that
#' election (and seat, where the table names one); every other survivor's
#' share is untouched. No table entry for the election: nothing changes.
#'
#' @param ov Per-seat conditional list (from
#'   [xgb_flow_conditional_override_for()]) or `NULL`.
#' @param fm A [build_flow_matrix()] result, used when `ov` is `NULL` or a
#'   seat has no entry.
#' @param target_election Election label.
#' @param seats Seat names to cover.
#' @param table,rows Injectable for tests; default read from disk / fitted.
#' @return The per-seat list (built from `fm$conditional` where needed),
#'   with attribute `htv` = list(applied, share, order) -- or `ov` unchanged.
#' @export
htv_flow_override <- function(ov, fm, target_election, seats, table = NULL, rows = NULL) {
  tab <- if (is.null(table)) htv_order_table() else data.table::as.data.table(table)
  if (is.null(tab)) { cat("HTV0! no how-to-vote table -- flow rows unchanged (the switch is on but has no input)\n"); return(ov) }
  tab <- tab[tab$election == target_election]
  if (!nrow(tab)) { cat(sprintf("HTV0 no how-to-vote entry for %s -- flow rows unchanged\n", target_election)); return(ov) }
  fr <- if (is.null(rows)) fit_htv_flow_rows(target_election) else rows
  if (is.null(fr)) { cat("HTV0! no transfer files to fit the card shares from -- flow rows unchanged\n"); return(ov) }
  if (!is.finite(fr$greens_above) || !is.finite(fr$labor_above))
    cat(sprintf("HTV0! a card share could not be fitted (greens-above %s, labor-above %s): seats needing the missing one are left unchanged\n",
                format(fr$greens_above), format(fr$labor_above)))
  share_for <- function(above) if (isTRUE(above)) fr$greens_above else fr$labor_above
  all_entry <- tab[tab$seat == "ALL"]
  seat_entry <- tab[tab$seat != "ALL"]
  out <- if (is.null(ov)) list() else ov
  applied <- 0L; orders <- character(0); skipped_na <- character(0)
  for (s in seats) {
    above <- if (s %in% seat_entry$seat) seat_entry[seat_entry$seat == s]$greens_above_labor[1]
             else if (nrow(all_entry)) all_entry$greens_above_labor[1] else NA
    if (is.na(above)) next
    share <- share_for(above)
    if (!is.finite(share)) { skipped_na <- c(skipped_na, s); next }
    L <- if (!is.null(out[[s]])) out[[s]] else fm$conditional
    touched <- FALSE
    for (k in names(L)) {
      if (!startsWith(k, "LNP|")) next
      r <- L[[k]]
      if (!all(c("ALP", "GRN") %in% names(r))) next
      tot <- r[["ALP"]] + r[["GRN"]]
      if (!is.finite(tot) || tot <= 0) next
      r[["ALP"]] <- tot * share / 100; r[["GRN"]] <- tot * (1 - share / 100)
      L[[k]] <- r; touched <- TRUE
    }
    if (touched) { out[[s]] <- L; applied <- applied + 1L; orders <- c(orders, if (above) "greens_above" else "labor_above") }
  }
  if (!is.null(ov)) for (a in setdiff(names(attributes(ov)), "names")) attr(out, a) <- attr(ov, a)
  if (length(skipped_na)) cat(sprintf("HTV0! %d seat(s) skipped because their card share is NA: %s\n", length(skipped_na), paste(utils::head(skipped_na, 8), collapse = ", ")))
  attr(out, "htv") <- list(applied = applied, share = fr[c("greens_above", "labor_above")], order = table(orders), skipped_na = skipped_na)
  cat(sprintf("HTV1 %s: Liberal card applied to %d of %d seats (%s); fitted Liberal->ALP share when ALP+GRN alive: greens-above %.0f%%, labor-above %.0f%%\n",
              target_election, applied, length(seats), paste(sprintf("%s=%d", names(table(orders)), as.integer(table(orders))), collapse = " "),
              fr$greens_above, fr$labor_above))
  out
}
