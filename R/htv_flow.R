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
#' @param path `NULL` (the default: the shipped `liberal-alp-grn-order.csv`, or the researched table under
#'   `AUSPOL_HTV_TABLE=researched`, [htv_researched_table()]), or a CSV with columns election, seat ("ALL" or a seat name),
#'   greens_above_labor (TRUE/FALSE), source.
#' @return data.table, or NULL with a message when the file is absent.
#' @export
htv_order_table <- function(path = NULL) {
  # AUSPOL_HTV_TABLE (6 Nov; SHIPPED "researched" 6 Nov, Pete; "shipped" = the old 9-row file): "researched" reads coalition-card-order-researched.csv instead (36
  # elections from sources dated before polling day; scripts/agent research 6 Nov). Its card orders map onto the same
  # flag: GRN_ABOVE_ALP TRUE, ALP_ABOVE_GRN FALSE. An OPEN ("just vote 1"), NO_CARD, SPLIT or UNKNOWN card, and any LOW
  # confidence row, give no row, so the flows learned from earlier counts stand. Liberal / LNP / CLP rows only.
  # plans/prereg-htv-researched-2026-11-06.md
  mode <- Sys.getenv("AUSPOL_HTV_TABLE", "researched")   # the published value (shipped 6 Nov)
  if (!mode %in% c("shipped", "researched")) stop("AUSPOL_HTV_TABLE must be shipped or researched, not ", mode, call. = FALSE)
  if (is.null(path) && identical(mode, "researched")) return(htv_researched_table())
  if (is.null(path)) path <- file.path("external", "reference", "htv", "liberal-alp-grn-order.csv")
  if (!file.exists(path)) { cat(sprintf("HTV0! how-to-vote table missing at %s -- AUSPOL_HTV_FLOW does NOTHING this run\n", path)); return(NULL) }
  d <- data.table::fread(path, showProgress = FALSE)
  need <- c("election", "seat", "greens_above_labor")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop("HTV table lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  d[, greens_above_labor := as.logical(greens_above_labor)]
  d
}

#' The researched Coalition card order as a how-to-vote table
#'
#' Reads `external/reference/htv/coalition-card-order-researched.csv` (columns `election`, `seat` ("ALL", a seat, or
#' seats separated by ";"), `party`, `order`, `confidence`, `source_url`, ...) and returns the shape
#' [htv_order_table()] returns: one row per election and seat with a HIGH or MED confidence Liberal / LNP / CLP card
#' that orders the two (`GRN_ABOVE_ALP` TRUE, `ALP_ABOVE_GRN` FALSE), plus `OPEN` cards as `NA` (statewide or seat;
#' an open seat does not take the election's ALL row). Prints HTV13 with what it kept and dropped.
#' @param path The researched CSV.
#' @return data.table `election`, `seat`, `greens_above_labor`, `source`; NULL with a message when the file is absent.
#' @export
htv_researched_table <- function(path = file.path("external", "reference", "htv", "coalition-card-order-researched.csv")) {
  if (!file.exists(path)) { cat(sprintf("HTV0! researched card table missing at %s -- AUSPOL_HTV_FLOW does NOTHING this run\n", path)); return(NULL) }
  d <- data.table::fread(path, showProgress = FALSE)
  need <- c("election", "seat", "party", "order", "confidence", "source_url")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop("researched HTV table lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  # A SEAT-level OPEN card (15 Nov 2026, Pete: Brunswick vic2026, "1 Liberal, then your choice") is kept with NA, so
  # htv_flow_override() leaves that seat's learned flows alone instead of giving it the election's ALL row. An OPEN ALL
  # row stays dropped: with no statewide order there is nothing for a seat to inherit, which is the same as no row.
  # A statewide OPEN row is kept too (15 Nov, prereg-htv-card-labels-2026-11-15.md): it trains and receives the open
  # share under AUSPOL_HTV_LABELS=card; under "outcome" (published) an NA row applies to no seat, as when it was dropped.
  map <- c(GRN_ABOVE_ALP = TRUE, ALP_ABOVE_GRN = FALSE, OPEN = NA)
  keep <- d$party %in% c("LIB", "LNP", "CLP") & d$confidence %in% c("HIGH", "MED") & d$order %in% names(map)
  k <- d[keep]
  seats <- strsplit(as.character(k$seat), ";", fixed = TRUE)
  out <- data.table::data.table(election = rep(k$election, lengths(seats)), seat = trimws(unlist(seats)),
                                greens_above_labor = unname(rep(map[k$order], lengths(seats))),
                                source = rep(k$source_url, lengths(seats)))
  dup <- out[duplicated(out[, c("election", "seat"), with = FALSE])]
  if (nrow(dup)) stop("researched HTV table has two kept rows for: ", paste(unique(paste(dup$election, dup$seat)), collapse = ", "), call. = FALSE)
  cat(sprintf("HTV13 researched card table: %d rows kept (%d elections; %d open card row(s)), %d dropped (no card/split/unknown/low confidence or not Liberal)\n",
              nrow(out), data.table::uniqueN(out$election), sum(is.na(out$greens_above_labor)), sum(!keep)))
  out
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
  sp <- htv_seat_splits(dir)
  if (is.null(sp)) return(NULL)
  out <- sp[, list(alp_share = 100 * sum(alp) / sum(tot), n_seats = data.table::uniqueN(seat)), by = election]
  out[, label := ifelse(alp_share < 50, "greens_above", "labor_above")]
  out[order(election)]
}

#' Liberal votes to ALP and to ALP+GRN per election and seat, where both are alive
#'
#' The seat-level counts behind [htv_observed_splits()], which sums them per election.
#' @inheritParams htv_observed_splits
#' @return data.table election, seat, alp (votes to ALP), tot (votes to ALP or GRN); NULL when there are none.
#' @export
htv_seat_splits <- function(dir = file.path("external", "elections")) {
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
  tx[, list(alp = sum(votes[to == "ALP"]), tot = sum(votes)), by = list(election, seat)]
}

#' Final-three Liberal exclusions only: `AUSPOL_HTV_FINAL3`
#'
#' `"1"`: the share written into the exact `LNP|ALP+GRN` key (the Liberal excluded third, Labor and the Greens the
#' last two, which decides a Labor-v-Greens seat) is fitted from earlier FINAL-THREE exclusions only: Liberal
#' exclusions whose votes went to Labor and the Greens and nobody else. Every wider `LNP|...ALP+GRN...` key keeps the
#' share fitted from all exclusions. `"0"`: one share for every key, byte-identical to before. Published `"1"` since
#' 27 Nov 2026 (Pete's override of the Victorian seat guard, DECISIONS 27 Nov).
#' Measured 27 Nov 2026: in Labor-above federal elections the final-three share ran 65-73% while the earlier,
#' many-candidate exclusions ran 44-62%, and the pooled fit (seat-count weights) is pulled toward the earlier ones.
#' `docs/plans/prereg-htv-final3-2026-11-27.md`.
#' @return `TRUE` when on.
#' @export
htv_final3_on <- function() {
  v <- Sys.getenv("AUSPOL_HTV_FINAL3", "1")
  if (!v %in% c("0", "1")) stop("HTV16! AUSPOL_HTV_FINAL3 must be 0 or 1, not '", v, "'", call. = FALSE)
  identical(v, "1")
}

#' Liberal votes to ALP and ALP+GRN in final-three exclusions, per election and seat
#'
#' A final-three exclusion is a Liberal/LNP round whose votes went to ALP and GRN and to no other candidate (so they
#' were the last two). Same sources and shape as [htv_seat_splits()].
#' @inheritParams htv_observed_splits
#' @return data.table election, seat, alp, tot; NULL when there are none.
#' @export
htv_seat_splits_final3 <- function(dir = file.path("external", "elections")) {
  bundle <- file.path(dir, "coalition-split-events.csv")
  tx <- if (file.exists(bundle) && !nzchar(Sys.getenv("AUSPOL_HTV_EXCLUDE", ""))) coalition_split_transfers(dir) else {
    fs <- list.files(dir, pattern = "-transfers[.]csv$", full.names = TRUE)
    if (!length(fs)) return(NULL)
    data.table::rbindlist(lapply(fs, function(f) {
      d <- data.table::fread(f, showProgress = FALSE)
      d[d$from == "LNP", list(election, seat, round, to, votes)]
    }), fill = TRUE)
  }
  tx <- data.table::as.data.table(tx)[tx$votes > 0, list(election, seat, round, to, votes)]
  if (!nrow(tx)) return(NULL)
  rec <- tx[, list(rset = paste(sort(unique(to)), collapse = "+")), by = list(election, seat, round)]
  f3 <- rec[rec$rset == "ALP+GRN", list(election, seat, round)]
  if (!nrow(f3)) return(NULL)
  tx <- merge(tx, f3, by = c("election", "seat", "round"))
  tx[, list(alp = sum(votes[to == "ALP"]), tot = sum(votes)), by = list(election, seat)]
}

#' Which labels train the card shares: `AUSPOL_HTV_LABELS`
#'
#' `"outcome"` (published until 15 Nov 2026): each earlier election is labelled by its own observed split (under 50% to Labor is
#' Greens-above). `"card"`: labels come from the card table, per election and seat, with a third label `open`
#' (`docs/plans/prereg-htv-card-labels-2026-11-15.md`). `"hybrid"` (amendment 1): the card label where a dated card
#' exists; seats with none are labelled by their election's pooled result, as under `"outcome"`. Published since
#' 15 Nov 2026 (a tie, -0.0001 SE 0.0002 over 18 elections; shipped by Pete as a correctness fix).
#' @return `"outcome"`, `"card"` or `"hybrid"`.
#' @export
htv_labels_mode <- function() {
  v <- Sys.getenv("AUSPOL_HTV_LABELS", "hybrid")   # the published value (scripts/published_flags.R; SHIPPED 15 Nov, was "outcome")
  if (!v %in% c("outcome", "card", "hybrid")) stop("HTV14! AUSPOL_HTV_LABELS must be outcome, card or hybrid, not '", v, "'", call. = FALSE)
  v
}

#' Card shares from card-labelled cells, partial-pooled (AUSPOL_HTV_LABELS=card)
#'
#' Each earlier (election, seat) split takes the label of its card: the seat's row, else the election's ALL row, else
#' it is left out. Cells are (election, label); each label's share is the recency- and seat-weighted mean of its
#' cells, shrunk toward the pooled mean by `tau^2 / (tau^2 + se^2)`.
#' @param target_election Target; only earlier elections train.
#' @param sp [htv_seat_splits()] result.
#' @param tab Card table ([htv_order_table()] shape).
#' @param hl Recency half-life in years.
#' @param fallback_outcome TRUE (`hybrid`): seats with no card label are labelled by their election's pooled split
#'   among those seats (under 50% to Labor is Greens-above) instead of being left out.
#' @return list(greens_above, labor_above, open, n = cells table, shrink = per-label table); NULL with no cells.
#' @export
htv_card_label_shares <- function(target_election, sp, tab, hl = htv_recency_hl(), fallback_outcome = FALSE) {
  if (is.null(sp) || is.null(tab) || !nrow(sp) || !nrow(tab)) return(NULL)
  sp <- data.table::as.data.table(sp); tab <- data.table::as.data.table(tab)
  sp <- sp[elections_before(sp$election, target_election)]
  lab_of <- function(x) ifelse(is.na(x), "open", ifelse(x, "greens_above", "labor_above"))
  seat_rows <- tab[tab$seat != "ALL", list(election, seat, seat_label = lab_of(greens_above_labor))]
  all_rows <- tab[tab$seat == "ALL", list(election, all_label = lab_of(greens_above_labor))]
  sp <- merge(sp, seat_rows, by = c("election", "seat"), all.x = TRUE)
  sp <- merge(sp, all_rows, by = "election", all.x = TRUE)
  # as.character: with no ALL (or no seat) rows the merged column is all-NA logical, which fifelse refuses to mix
  sp[, label := data.table::fifelse(!is.na(seat_label), as.character(seat_label), as.character(all_label))]
  if (isTRUE(fallback_outcome) && anyNA(sp$label)) {
    unl <- sp[is.na(sp$label), list(fb = data.table::fifelse(100 * sum(alp) / sum(tot) < 50, "greens_above", "labor_above")), by = election]
    sp <- merge(sp, unl, by = "election", all.x = TRUE)
    sp[is.na(label), label := fb]
    sp[, fb := NULL]
  }
  sp <- sp[!is.na(sp$label)]
  if (!nrow(sp)) return(NULL)
  cells <- sp[, list(alp_share = 100 * sum(alp) / sum(tot), n_seats = .N), by = list(election, label)]
  yr <- function(x) suppressWarnings(as.numeric(sub("^.*?([0-9]{4})$", "\\1", x)))
  age <- yr(target_election) - yr(cells$election)
  rw <- if (hl > 0) 0.5^(pmax(0, age) / hl) else rep(1, length(age))
  rw[!is.finite(rw)] <- 1
  cells[, w := n_seats * rw]
  mu <- sum(cells$alp_share * cells$w) / sum(cells$w)
  by_lab <- cells[, list(m = sum(alp_share * w) / sum(w), k = .N,
                         v = if (.N > 1L) sum(w * (alp_share - sum(alp_share * w) / sum(w))^2) / sum(w) * .N / (.N - 1L) else NA_real_,
                         neff = sum(w)^2 / sum(w^2)), by = label]
  v_pool <- if (any(is.finite(by_lab$v))) mean(by_lab$v[is.finite(by_lab$v)]) else stats::var(cells$alp_share)
  if (!is.finite(v_pool)) v_pool <- 0
  by_lab[!is.finite(v), v := v_pool]
  by_lab[, se2 := v / neff]
  tau2 <- if (nrow(by_lab) > 1L) max(0, stats::var(by_lab$m) - mean(by_lab$se2)) else 0
  by_lab[, wt := if (tau2 > 0) tau2 / (tau2 + se2) else 0]
  by_lab[, share := mu + wt * (m - mu)]
  cat(sprintf("HTV14 %s card-labelled shares (pooled %.1f%%, tau^2 %.1f): %s\n", target_election, mu, tau2,
              paste(sprintf("%s %.1f%% (raw %.1f, %d cells, shrink w %.2f)", by_lab$label, by_lab$share, by_lab$m, by_lab$k, by_lab$wt), collapse = "; ")))
  jur <- if (htv_jur_shrink_on()) htv_jur_adjust(cells, by_lab, target_election) else NULL
  if (!is.null(jur)) by_lab <- merge(by_lab, jur[, list(label, adj)], by = "label", all.x = TRUE) else by_lab[, adj := 0]
  by_lab[is.na(adj), adj := 0]
  by_lab[, share := share + adj]
  pick <- function(l) { r <- by_lab[by_lab$label == l]; if (nrow(r)) r$share else NA_real_ }
  list(greens_above = pick("greens_above"), labor_above = pick("labor_above"), open = pick("open"), n = cells, shrink = by_lab)
}

#' Per-jurisdiction level in the card shares: `AUSPOL_HTV_JUR_SHRINK`
#'
#' `"1"`: each card share is moved toward the target jurisdiction's own cells, partial-pooled
#' (`docs/plans/prereg-htv-jur-shrink-2026-11-17.md`). `"0"` (published): no jurisdiction level.
#' @return `TRUE` when on.
#' @export
htv_jur_shrink_on <- function() {
  v <- Sys.getenv("AUSPOL_HTV_JUR_SHRINK", "0")
  if (!v %in% c("0", "1")) stop("HTV15! AUSPOL_HTV_JUR_SHRINK must be 0 or 1, not '", v, "'", call. = FALSE)
  identical(v, "1")
}

#' Jurisdiction adjustment to the card shares
#'
#' Cells are grouped by (label, jurisdiction), the jurisdiction being the election name without its year (`fed`,
#' `vic`, ...). Each group's weighted mean deviates from its label's weighted mean; the deviation is shrunk by
#' `tau_j^2 / (tau_j^2 + se_j^2)`, where `se_j^2` is the pooled within-group cell variance over the group's effective
#' number of cells and `tau_j^2` the method-of-moments between-group variance (mean squared deviation less mean
#' `se_j^2`, floored at 0). Only the target's own jurisdiction is returned; a label with no cell there gets no adjustment.
#' @param cells,by_lab From [htv_card_label_shares()]: cells with `election, label, alp_share, w`; per-label `m`.
#' @param target_election Target election.
#' @return data.table `label, adj` (points added to the label's share) for the target's jurisdiction, or `NULL`.
#' @export
htv_jur_adjust <- function(cells, by_lab, target_election) {
  jof <- function(x) sub("[0-9]+$", "", x)
  cj <- data.table::copy(cells)[, jur := jof(election)]
  g <- cj[, list(mj = sum(alp_share * w) / sum(w), k = .N, neff = sum(w)^2 / sum(w^2),
                 vw = if (.N > 1L) sum(w * (alp_share - sum(alp_share * w) / sum(w))^2) / sum(w) * .N / (.N - 1L) else NA_real_),
          by = list(label, jur)]
  g <- merge(g, by_lab[, list(label, m)], by = "label")
  v_in <- if (any(is.finite(g$vw))) stats::weighted.mean(g$vw[is.finite(g$vw)], g$k[is.finite(g$vw)] - 1L) else NA_real_
  if (!is.finite(v_in)) { cat(sprintf("HTV15 %s jurisdiction level: no group with two cells, no adjustment\n", target_election)); return(NULL) }
  g[, se2 := v_in / neff][, dev := mj - m]
  tau2j <- max(0, mean(g$dev^2) - mean(g$se2))
  g[, wj := if (tau2j > 0) tau2j / (tau2j + se2) else 0][, adj := wj * dev]
  tj <- jof(target_election); out <- g[jur == tj]
  cat(sprintf("HTV15 %s jurisdiction level (within-group var %.1f, tau_j^2 %.1f, %d groups): %s\n", target_election, v_in, tau2j, nrow(g),
              if (nrow(out)) paste(sprintf("%s %s mean %.1f vs label %.1f, %d cells, w %.2f, adj %+.1f", out$label, tj, out$mj, out$m, out$k, out$wj, out$adj), collapse = "; ")
              else paste0("no ", tj, " cells, no adjustment")))
  if (!nrow(out)) return(NULL)
  out[, list(label, adj)]
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
  # AUSPOL_HTV_LABELS=card: labels from the card table, not the result; a third (open) share; shrinkage, no min_seats.
  lm <- htv_labels_mode()
  if (lm %in% c("card", "hybrid")) {
    tab <- htv_order_table()
    fr <- htv_card_label_shares(target_election, htv_seat_splits(dir), tab, fallback_outcome = identical(lm, "hybrid"))
    # AUSPOL_HTV_FINAL3=1: a second set of shares, from final-three exclusions only, for the exact LNP|ALP+GRN key.
    if (!is.null(fr) && htv_final3_on()) {
      f3 <- utils::capture.output(r3 <- htv_card_label_shares(target_election, htv_seat_splits_final3(dir), tab,
                                                              fallback_outcome = identical(lm, "hybrid")))
      fr$final3 <- if (is.null(r3)) NULL else r3[c("greens_above", "labor_above", "open")]
      cat(sprintf("HTV16 %s final-three shares for LNP|ALP+GRN (all-exclusion shares in brackets): %s\n", target_election,
                  if (is.null(r3)) "none fitted, the all-exclusion shares stand" else
                    paste(sprintf("%s %.1f%% [%.1f%%] from %d cells", c("labor_above", "greens_above", "open"),
                                  unlist(r3[c("labor_above", "greens_above", "open")]), unlist(fr[c("labor_above", "greens_above", "open")]),
                                  vapply(c("labor_above", "greens_above", "open"), function(l) sum(r3$n$label == l), 0L)), collapse = "; ")))
    }
    return(fr)
  }
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
  list(greens_above = f("greens_above"), labor_above = f("labor_above"), open = NA_real_, n = obs)
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
    # No seat row and no ALL row: the table says nothing about this seat, which is NOT an open card (review 15 Nov:
    # vic2018 has only two open seat rows, and its other 86 seats were taking the open share). Leave it alone.
    if (!(s %in% seat_entry$seat) && !nrow(all_entry)) next
    above <- if (s %in% seat_entry$seat) seat_entry[seat_entry$seat == s]$greens_above_labor[1]
             else all_entry$greens_above_labor[1]
    # An open card (NA) takes the open share when one is fitted (AUSPOL_HTV_LABELS=card); otherwise the seat keeps its flows.
    if (is.na(above) && !is.finite(if (is.null(fr$open)) NA_real_ else fr$open)) next
    share <- if (is.na(above)) fr$open else share_for(above)
    if (!is.finite(share)) { skipped_na <- c(skipped_na, s); next }
    # AUSPOL_HTV_FINAL3: the exact final-three key takes its own share when one was fitted (fit_htv_flow_rows()).
    share3 <- if (is.null(fr$final3)) NA_real_ else if (is.na(above)) fr$final3$open else if (isTRUE(above)) fr$final3$greens_above else fr$final3$labor_above
    if (is.null(share3) || !is.finite(share3)) share3 <- share
    L <- if (!is.null(out[[s]])) out[[s]] else fm$conditional
    touched <- FALSE
    for (k in names(L)) {
      if (!startsWith(k, "LNP|")) next
      r <- L[[k]]
      if (!all(c("ALP", "GRN") %in% names(r))) next
      tot <- r[["ALP"]] + r[["GRN"]]
      if (!is.finite(tot) || tot <= 0) next
      sh <- if (identical(k, "LNP|ALP+GRN")) share3 else share
      r[["ALP"]] <- tot * sh / 100; r[["GRN"]] <- tot * (1 - sh / 100)
      L[[k]] <- r; touched <- TRUE
    }
    if (touched) { out[[s]] <- L; applied <- applied + 1L; orders <- c(orders, if (is.na(above)) "open" else if (above) "greens_above" else "labor_above") }
  }
  if (!is.null(ov)) for (a in setdiff(names(attributes(ov)), "names")) attr(out, a) <- attr(ov, a)
  if (length(skipped_na)) cat(sprintf("HTV0! %d seat(s) skipped because their card share is NA: %s\n", length(skipped_na), paste(utils::head(skipped_na, 8), collapse = ", ")))
  attr(out, "htv") <- list(applied = applied, share = fr[intersect(c("greens_above", "labor_above", "open"), names(fr))], order = table(orders), skipped_na = skipped_na)
  cat(sprintf("HTV1 %s: Liberal card applied to %d of %d seats (%s); fitted Liberal->ALP share when ALP+GRN alive: greens-above %.0f%%, labor-above %.0f%%, open %s\n",
              target_election, applied, length(seats), paste(sprintf("%s=%d", names(table(orders)), as.integer(table(orders))), collapse = " "),
              fr$greens_above, fr$labor_above,
              if (is.finite(if (is.null(fr$open)) NA_real_ else fr$open)) sprintf("%.0f%%", fr$open) else "none"))
  # Nothing applied (e.g. an election with only open seat cards, vic2018): hand back the caller's own value. `out`
  # would be an empty list when ov is NULL, which simulate_seat_contests() rejects as a wrong-length override.
  if (applied == 0L) return(ov)
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
