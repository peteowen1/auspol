# AUSPOL_IND_RETURN: a returning independent keeps their own vote, not the minor field's swing.
# Pete, 2026-10-25; docs/plans/prereg-ind-return-2026-10-25.md.
#
# Independents are not in the statewide trend model. Their seat cells are scaled to the forecast
# "others" total (fit_seats_full.R's minor-field scale_to, and each harness's), so when One Nation
# absorbs the minor field statewide a returning independent's PERSONAL vote is cut with it: Ali
# Cupper (Mildura, 33.9 in 2022) entered 2026 at 18.9 after a x0.61 scale. Across 90 earlier
# returning independents (>= 10% last time, same seat) their own vote did not track the minor-field
# change (log-log slope 0.13, se 0.16); sitting members kept a median 0.99 of it, losers 0.82.
#
# This SETS the IND cell of a seat whose sole independent stood as an independent in the SAME seat at
# the previous election to r_group x their previous share, the ratio fitted time-forward on every such
# earlier case and shrunk toward 1 (r separate for a previous winner and a previous loser; Amendment 1
# replaced a first-arm linear fit that went flat on few early cases), and rescales the seat's
# other classes pro rata. Disjoint from AUSPOL_IND_PERSON, which takes only people with NO record in
# this seat at the previous election. Applied from inside ind_person_apply(), so every harness and
# fit_seats_full.R reach it through the call they already make.

#' Is the returning-independent rule on, and where?
#'
#' @return `"final"` (after the frozen xgb trees), `"base"` (before them) or `"0"` (off, the default).
#' @noRd
ind_return_mode <- function() {
  v <- Sys.getenv("AUSPOL_IND_RETURN", "0")
  if (!v %in% c("0", "base", "final")) stop("AUSPOL_IND_RETURN must be \"0\", \"base\" or \"final\", not ", v)
  v
}

# Independent cells of `target` whose sole independent stood as an independent in the same seat at
# the previous election of the region (seat renames followed). Time-forward: reads only `target`'s
# nominations and the previous election's results.
#' @noRd
ind_return_cells <- function(target, corpus = NULL) {
  C <- corpus
  if (is.null(C)) C <- data.table::fread(out_path("candidacies.csv"), showProgress = FALSE)
  C <- data.table::as.data.table(C)
  empty <- data.table::data.table(seat = character(0), skey = character(0), name = character(0),
                                  record = numeric(0), won = logical(0))
  region <- sub("[0-9]{4}$", "", target)
  els <- unique(C$election[sub("[0-9]{4}$", "", C$election) == region])
  earlier <- els[elections_before(els, target)]
  if (!length(earlier)) return(empty)
  .pv <- earlier[which.max(as.Date(unname(election_dates()[earlier])))]
  .tg <- target
  NOWT <- C[C$election == .tg]
  ind <- NOWT[NOWT$party == "IND"]
  sole <- ind[, list(n = .N), by = "seat"]
  ind <- ind[ind$seat %in% sole$seat[sole$n == 1L]]
  if (!nrow(ind)) return(empty)
  cand <- .cs_prep(ind)
  cand[, `:=`(seat = ind$seat, name = ind$name)]
  cand <- cand[!is.na(c_key)]
  PREVT <- C[C$election == .pv & C$party == "IND"]
  if (!nrow(cand) || !nrow(PREVT)) return(empty)
  P <- .cs_prep(PREVT)[!is.na(c_key) & is.finite(c_pcv)]
  rn <- seat_rename_map()
  P <- rbind(P, data.table::copy(P[c_s %in% names(rn)])[, c_s := unname(rn[c_s])])
  P <- unique(P, by = c("c_s", "c_key"))
  m <- merge(cand[, list(c_s, c_key, seat, name)], P[, list(c_s, c_key, record = c_pcv, won = c_el)],
             by = c("c_s", "c_key"))
  if (!nrow(m)) return(empty)
  data.table::data.table(seat = m$seat, skey = normalise_seat(m$seat), name = m$name, record = m$record, won = m$won)
}

.ir_memo <- new.env(parent = emptyenv())

# Every returning-independent cell in every election pair, with that person's actual share.
#' @noRd
.ir_cases <- function(C) {
  key <- .cs_fingerprint("ircases", C)
  if (!is.null(.ir_memo[[key]])) return(.ir_memo[[key]])
  els <- vapply(all_election_pairs(), `[[`, "", "election")
  rows <- lapply(els, function(e) {
    x <- ind_return_cells(e, C)
    if (!nrow(x)) return(NULL)
    .e <- e
    a <- C[C$election == .e & C$party == "IND", list(seat, name, actual = pcv)]
    r <- merge(x, a, by = c("seat", "name"))
    if (nrow(r)) r$election <- .e
    r
  })
  r <- data.table::rbindlist(rows, fill = TRUE)
  assign(key, r, envir = .ir_memo)
  r
}

#' The carry for returning independents, fitted on earlier elections only
#'
#' Amendment 1 (the linear fit of the first arm went flat on few early cases: Ingram vic2010 36.8 -> 6.4).
#' A ratio per group (previous winner, previous loser): `rhat` = sum(actual) / sum(record) over that group's
#' cells in elections dated before `target`, shrunk toward 1 ("keeps their whole vote") as
#' `(n x rhat + K) / (n + K)`, `K = 3` (the `AUSPOL_CONSERVE_SHRINK_K` convention). No minimum-n cliff: no
#' earlier cases gives 1.
#'
#' @return list `r_won`, `r_lost`, `raw_won`, `raw_lost`, `n`, `n_won`, `n_lost`, `ok` (always TRUE).
#' @noRd
ind_return_fit <- function(target, corpus = NULL) {
  C <- corpus
  if (is.null(C)) C <- data.table::fread(out_path("candidacies.csv"), showProgress = FALSE)
  cs <- .ir_cases(data.table::as.data.table(C))
  if (nrow(cs)) cs <- cs[elections_before(cs$election, target) & is.finite(cs$actual) & is.finite(cs$record) & cs$record > 0]
  K <- 3
  grp <- function(w) {
    x <- if (nrow(cs)) cs[(cs$won %in% TRUE) == w] else cs
    n <- nrow(x); raw <- if (n) sum(x$actual) / sum(x$record) else NA_real_
    list(n = n, raw = raw, r = if (n) (n * raw + K) / (n + K) else 1)
  }
  gw <- grp(TRUE); gl <- grp(FALSE)
  list(r_won = gw$r, r_lost = gl$r, raw_won = gw$raw, raw_lost = gl$raw, n = gw$n + gl$n,
       n_won = gw$n, n_lost = gl$n, ok = TRUE)
}

#' Set each returning-independent cell to the fitted carry of their own previous share
#'
#' A no-op unless `AUSPOL_IND_RETURN` equals `stage`. Called from ind_person_apply().
#' @noRd
ind_return_apply <- function(shares, target, stage = c("base", "final"), code = "IRT1", corpus = NULL) {
  stage <- match.arg(stage)
  if (!identical(ind_return_mode(), stage) || !"IND" %in% colnames(shares)) return(shares)
  cells <- ind_return_cells(target, corpus)
  f <- ind_return_fit(target, corpus)
  if (!nrow(cells)) {
    cat(sprintf("%s  returning independents (%s) for %s: none\n", code, stage, target))
    return(shares)
  }
  cells$value <- pmax(0, ifelse(cells$won %in% TRUE, f$r_won, f$r_lost) * cells$record)
  ci <- match("IND", colnames(shares))
  ri <- match(cells$skey, normalise_seat(rownames(shares)))
  out <- shares; n <- 0L; log <- character(0)
  for (k in which(!is.na(ri))) {
    i <- ri[k]; old <- shares[i, ci]; tot <- sum(shares[i, ])
    if (tot - old <= 0) next
    new <- min(cells$value[k], tot)
    out[i, ] <- shares[i, ] * (tot - new) / (tot - old)
    out[i, ci] <- new
    n <- n + 1L
    log <- c(log, sprintf("%s %s %.1f -> %.1f (%s %.1f)", cells$seat[k], cells$name[k], old, new,
                          if (cells$won[k] %in% TRUE) "won" else "lost", cells$record[k]))
  }
  cat(sprintf("%s  returning independents (%s) for %s: %d cell(s) set from %d matched; carry x%.3f if won (raw %.3f, n %d), x%.3f if lost (raw %.3f, n %d), shrunk to 1 with K=3%s\n",
              code, stage, target, n, nrow(cells), f$r_won, f$raw_won, f$n_won, f$r_lost, f$raw_lost, f$n_lost,
              if (n) paste0(": ", paste(log, collapse = "; ")) else ""))
  out
}
