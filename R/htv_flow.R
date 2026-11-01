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
  # THE SHIPPED BUNDLE IS THE ONLY SOURCE WHEN PRESENT (1 Nov 2026). The forecast runner fetches only some
  # transfers files, so the published card fit read 35% Liberal->ALP (greens-above) while the backtests read 37.9%
  # from all 13, and the scenario job 40%, which failed every What-If publish from 31 Oct (CSC7). The Coalition-split
  # bundle already carries every LNP row of every local transfers file (coalition_split_transfers(), shipped by
  # promote_rebuild.R; byte-identical splits on all 26 elections), so a partial set cannot leak in beside it.
  bundle <- file.path(dir, "coalition-split-events.csv")
  if (file.exists(bundle) && !nzchar(Sys.getenv("AUSPOL_HTV_EXCLUDE", ""))) {
    tx <- coalition_split_transfers(dir)
    tx <- tx[tx$to %in% c("ALP", "GRN"), list(election, seat, round, to, votes)]
  } else {
  fs <- list.files(dir, pattern = "-transfers[.]csv$", full.names = TRUE)
  # AUSPOL_HTV_EXCLUDE: comma-separated transfer files to leave out (diagnostic; attribution of a new file's effect)
  ex <- strsplit(Sys.getenv("AUSPOL_HTV_EXCLUDE", ""), ",")[[1]]
  if (length(ex)) fs <- fs[!basename(fs) %in% trimws(ex)]
  if (!length(fs)) return(NULL)
  tx <- data.table::rbindlist(lapply(fs, function(f) {
    d <- data.table::fread(f, showProgress = FALSE)
    d[d$from == "LNP" & d$to %in% c("ALP", "GRN"), list(election, seat, round, to, votes)]
  }), fill = TRUE)
  }
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
#' Time-forward mean of the observed splits with the same label, seat-
#' weighted: only elections before `target_election` count (line below,
#' `elections_before()`). Elections with fewer than `min_seats` qualifying
#' seats are dropped as too thin to label. Every `*-transfers.csv` in `dir`
#' is read, so adding an older election's transfer file adds training data
#' for every later target (2026-10-13: vec-2006, nswec-2011, aec-fed-2001),
#' unless `dir` holds `coalition-split-events.csv` (the shipped bundle the
#' forecast runner downloads): then that bundle is the only source.
#'
#' @param target_election Election whose splits are fitted from earlier elections.
#' @param dir,min_seats See [htv_observed_splits()].
#' @return list(greens_above = ALP share, labor_above = ALP share, n = table).
#' @export
fit_htv_flow_rows <- function(target_election, dir = file.path("external", "elections"), min_seats = 2L) {
  obs <- htv_observed_splits(dir)
  if (is.null(obs)) return(NULL)
  obs <- obs[elections_before(obs$election, target_election) & obs$n_seats >= min_seats]   # time-forward
  # AUSPOL_HTV_RECENCY_HL (years; "0" = the plain seat-weighted mean): each election also weighted 0.5^(age / hl),
  # so a rising share (Greens-last: 58, 59, 65, 73) is not averaged back to its past. With one election per label the
  # weights cancel and it is the plain mean. docs/plans/prereg-htv-recency-2026-10-31.md.
  hl <- htv_recency_hl()
  yr <- function(x) suppressWarnings(as.numeric(sub("^.*?([0-9]{4})$", "\\1", x)))
  age <- yr(target_election) - yr(obs$election)
  rw <- if (hl > 0) 0.5^(pmax(0, age) / hl) else rep(1, length(age))
  rw[!is.finite(rw)] <- 1   # a label with no 4-digit year (test fixtures) keeps the plain weight
  obs$w <- obs$n_seats * rw
  f <- function(lab) { s <- obs[obs$label == lab]; if (!nrow(s)) NA_real_ else sum(s$alp_share * s$w) / sum(s$w) }
  list(greens_above = f("greens_above"), labor_above = f("labor_above"), n = obs)
}

#' Probability the Liberal card puts Labor above the Greens, for an election whose card is not yet known
#'
#' `AUSPOL_HTV_CARD_P`, per region: `"vic=0.67"` or `"vic=0.67,nsw=0.8"` (`""` or `"off"` = off). A region with no
#' entry gets no mix, so one state's estimate never reaches another's forecast (review 31 Oct: nsw2027 would have
#' taken Victoria's 0.67). Used ONLY when the how-to-vote table has no row for `target_election`; once the card is
#' published, add its row and this stops applying (Pete, 31 Oct: "put a probability on it ... turn to 100% once you
#' have the new info"). A card is statewide, so the forecast simulates each card on its own draws and mixes them
#' (`fit_seats_full.R`, HTV2).
#' @param target_election Election label, e.g. `"vic2026"`; its region is the letters before the year.
#' @param table Injectable how-to-vote table; default [htv_order_table()].
#' @return The probability in `[0, 1]`, or `NA` when off, the region has no entry, or the card is known.
#' @export
htv_card_p <- function(target_election, table = NULL) {
  raw <- trimws(Sys.getenv("AUSPOL_HTV_CARD_P", "vic=0.67"))   # the published value (scripts/published_flags.R)
  if (!nzchar(raw) || identical(tolower(raw), "off")) return(NA_real_)   # "off": an empty value cannot be set from PowerShell
  parts <- strsplit(strsplit(raw, ",", fixed = TRUE)[[1]], "=", fixed = TRUE)
  if (!all(lengths(parts) == 2L))
    stop("HTV10! AUSPOL_HTV_CARD_P must be region=probability pairs, e.g. 'vic=0.67'; got '", raw, "'", call. = FALSE)
  ps <- suppressWarnings(as.numeric(vapply(parts, `[`, "", 2L)))
  names(ps) <- tolower(trimws(vapply(parts, `[`, "", 1L)))
  if (anyDuplicated(names(ps))) stop("HTV10! AUSPOL_HTV_CARD_P names a region twice; got '", raw, "'", call. = FALSE)
  if (any(!is.finite(ps) | ps < 0 | ps > 1)) stop("HTV10! AUSPOL_HTV_CARD_P probabilities must be in [0, 1]; got '", raw, "'", call. = FALSE)
  region <- tolower(sub("[0-9]+$", "", target_election))
  if (!region %in% names(ps)) return(NA_real_)
  tab <- if (is.null(table)) htv_order_table() else data.table::as.data.table(table)
  if (!is.null(tab) && any(tab$election == target_election)) return(NA_real_)   # the card is known: use it
  unname(ps[region])
}

#' Half-life, in years, of the recency weight on the how-to-vote flow rows
#'
#' `AUSPOL_HTV_RECENCY_HL`, validated: a finite number >= 0 ("0" is the plain mean; "8", published since 2026-11-01).
#' @return Numeric scalar.
#' @export
htv_recency_hl <- function() {
  v <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_HTV_RECENCY_HL", "8")))   # the published value
  if (length(v) != 1L || !is.finite(v) || v < 0)
    stop("HTV11! AUSPOL_HTV_RECENCY_HL must be a number >= 0 (years); got '", Sys.getenv("AUSPOL_HTV_RECENCY_HL"), "'", call. = FALSE)
  v
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

#' Mix two seat simulations run under the two how-to-vote cards, by the card probability
#'
#' Both runs must use the same seed and draw count, so draw i shares its statewide draw in each. The first
#' `round(p * n)` draws come from `labor_above`, the rest from `greens_above`: every seat in a draw has the same card,
#' as a real statewide card does. `win_prob` is the two runs' table weighted by the same fractions.
#' @param labor_above,greens_above [simulate_seat_contests()] results, card Labor-above and Greens-above.
#' @param p Probability the card puts Labor above the Greens.
#' @return A result of the same shape, with attribute `htv_card` = list(p, n_labor_above, n).
#' @export
htv_mix_sims <- function(labor_above, greens_above, p) {
  a <- labor_above; b <- greens_above
  n <- nrow(a$totals)
  if (nrow(b$totals) != n || !identical(colnames(a$totals), colnames(b$totals)))
    stop("HTV12! the two card runs differ in draws or parties: cannot mix", call. = FALSE)
  if (!is.finite(p) || p < 0 || p > 1) stop("HTV12! card probability must be in [0, 1]", call. = FALSE)
  n1 <- as.integer(round(p * n)); ia <- seq_len(n) <= n1
  out <- a
  for (f in c("totals", "tcp_winner", "tcp_runnerup", "tcp_share")) if (!is.null(a[[f]])) out[[f]][!ia, ] <- b[[f]][!ia, ]
  if (!is.null(a$fp_draws)) out$fp_draws[!ia, , ] <- b$fp_draws[!ia, , ]
  wa <- data.table::as.data.table(a$win_prob); wb <- data.table::as.data.table(b$win_prob)
  wa[, prob := prob * n1 / n]; wb[, prob := prob * (n - n1) / n]
  wp <- data.table::rbindlist(list(wa, wb))[, list(prob = sum(prob)), by = list(seat, party)]
  out$win_prob <- as.data.frame(wp[wp$prob > 0])
  attr(out, "htv_card") <- list(p = p, n_labor_above = n1, n = n)
  out
}
