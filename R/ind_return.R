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
# the previous election to a + b_group x their previous share, the line fitted time-forward on every
# such earlier case (b separate for a previous winner and a previous loser), and rescales the seat's
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
#' Ordinary least squares `actual ~ record + record:lost` over every returning-independent cell of an
#' election dated before `target`: one intercept, a slope for a previous winner and one for a previous
#' loser. Slopes bounded to [0, 1.5] (a member can grow; a negative carry is not a model).
#'
#' @return list `a`, `b_won`, `b_lost`, `n`, `n_won`, `n_lost`, `ok` (FALSE below 5 cases).
#' @noRd
ind_return_fit <- function(target, corpus = NULL) {
  C <- corpus
  if (is.null(C)) C <- data.table::fread(out_path("candidacies.csv"), showProgress = FALSE)
  cs <- .ir_cases(data.table::as.data.table(C))
  bad <- list(a = NA_real_, b_won = NA_real_, b_lost = NA_real_, n = 0L, n_won = 0L, n_lost = 0L, ok = FALSE)
  if (!nrow(cs)) return(bad)
  cs <- cs[elections_before(cs$election, target) & is.finite(cs$actual) & is.finite(cs$record)]
  bad$n <- nrow(cs)
  if (nrow(cs) < 5L) return(bad)
  cs[, lost := !(won %in% TRUE)]
  if (length(unique(cs$lost)) < 2L) {
    co <- stats::coef(stats::lm(actual ~ record, data = cs)); b_w <- b_l <- unname(co[2])
  } else {
    co <- stats::coef(stats::lm(actual ~ record + record:lost, data = cs))
    b_w <- unname(co[2]); b_l <- unname(co[2] + co[3])
  }
  cl <- function(b) min(max(if (is.finite(b)) b else 0, 0), 1.5)
  list(a = unname(co[1]), b_won = cl(b_w), b_lost = cl(b_l), n = nrow(cs), n_won = sum(!cs$lost),
       n_lost = sum(cs$lost), ok = TRUE)
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
  if (!nrow(cells) || !f$ok) {
    cat(sprintf("%s  returning independents (%s) for %s: %d matched, %s -- nothing set\n", code, stage, target,
                nrow(cells), if (!f$ok) sprintf("only %d earlier case(s), no fit", f$n) else "no cells"))
    return(shares)
  }
  cells$value <- pmax(0, f$a + ifelse(cells$won %in% TRUE, f$b_won, f$b_lost) * cells$record)
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
  cat(sprintf("%s  returning independents (%s) for %s: %d cell(s) set from %d matched; carry %.2f + %.3f x record if won, %.3f if lost (n=%d earlier cases: %d won, %d lost)%s\n",
              code, stage, target, n, nrow(cells), f$a, f$b_won, f$b_lost, f$n, f$n_won, f$n_lost,
              if (n) paste0(": ", paste(log, collapse = "; ")) else ""))
  out
}
