# AUSPOL_IND_PERSON: an independent's vote follows the PERSON, not the seat.
# Pete, 2026-10-10; docs/plans/prereg-ind-person-2026-10-10.md.
#
# The base is level_now + slope x (seat prior - level_prev) (dev_slope()), so
# the statewide independent level reaches every IND cell however unknown its
# candidate: Stefanopoulos (Malvern 2022, actual 1.6) was published at 8.6
# although his one earlier run was 0.61% (Prahran 2014). The cross-seat credit
# (R/cross_seat_vote.R) already finds such records but applies
# max(class base, carry x record), so it can only raise. This SETS the cell to
# carry x record, up or down, for a sole independent who has no record in this
# seat at the previous election but a personal record elsewhere. Same matching
# as the cross-seat credit (time-forward, surname + full first name, same
# state, ambiguous names refused, personal votes only) and its fitted carry.

#' Is the person-not-seat independent rule on, and where?
#'
#' @return `"0"` (off, shipped), `"base"` (before the frozen xgb trees) or
#'   `"final"` (after them).
#' @export
ind_person_mode <- function() {
  v <- Sys.getenv("AUSPOL_IND_PERSON", "0")
  if (!v %in% c("0", "base", "final")) stop("AUSPOL_IND_PERSON must be \"0\", \"base\" or \"final\", not ", v)
  v
}

#' Independent cells whose candidate's own earlier record replaces the seat base
#'
#' Seats of `target` with exactly one independent candidate, who has no
#' candidacy in the same seat at the previous election of the region, and who
#' has a personal non-major record at an earlier election (or by-election) of
#' the same state, matched as the cross-seat credit matches.
#'
#' @param target Election label; nothing dated on or after it is read.
#' @param corpus Optional pre-read candidacy table (`output/candidacies.csv`).
#' @return data.table `seat`, `skey`, `name`, `record`, `record_election`,
#'   `record_seat`, `carry`, `value` (share points), possibly empty.
#' @export
ind_person_cells <- function(target, corpus = NULL) {
  C <- corpus
  if (is.null(C)) C <- data.table::fread(out_path("candidacies.csv"), showProgress = FALSE)
  C <- data.table::as.data.table(C)
  empty <- data.table::data.table(seat = character(0), skey = character(0), name = character(0), record = numeric(0),
                                  record_election = character(0), record_seat = character(0), carry = numeric(0),
                                  value = numeric(0))
  region <- sub("[0-9]{4}$", "", target)
  els <- unique(C$election[sub("[0-9]{4}$", "", C$election) == region])
  earlier <- els[elections_before(els, target)]
  if (!length(earlier)) return(empty)
  prev <- earlier[which.max(as.Date(unname(election_dates()[earlier])))]
  .tg <- target; .pv <- prev
  NOWT <- C[C$election == .tg]
  PREVT <- C[C$election == .pv]
  ind <- NOWT[NOWT$party == "IND"]
  sole <- ind[, list(n = .N), by = "seat"]
  ind <- ind[ind$seat %in% sole$seat[sole$n == 1L]]
  if (!nrow(ind)) return(empty)
  cand <- .cs_prep(ind)
  cand[, `:=`(.id = .I, seat = ind$seat, name = ind$name)]
  cand <- cand[!is.na(c_key)]
  # anyone with a candidacy in this seat at the previous election belongs to the existing machinery
  rn <- seat_rename_map()
  P <- .cs_prep(PREVT)[!is.na(c_key)]
  P2 <- unique(rbind(P[, list(c_s, c_key)], P[c_s %in% names(rn), list(c_s = unname(rn[c_s]), c_key)]))
  cand <- cand[!paste(c_s, c_key) %in% paste(P2$c_s, P2$c_key)]
  if (!nrow(cand)) return(empty)
  D <- .cs_cached(.cs_fingerprint("prep", C), function() .cs_prep(C), disk = FALSE)
  BW <- .cs_byelection_cached(D, C, list(election = .tg, prev = .pv), .tg)
  # A SITTING MEMBER is not this rule's case, whichever seat they now contest
  # (the prereg's scope): elected at the previous election anywhere in the
  # state, or a by-election winner since. Brock (Frome 2018 -> Stuart 2022) and
  # Bedford (Florey 2018 -> Newland 2022) moved seats in a redistribution.
  sit <- P[P$c_el %in% TRUE, list(c_key, c_state)]
  if (nrow(BW)) sit <- rbind(sit, BW[BW$c_election == .tg & !is.na(BW$c_key), list(c_key, c_state)])
  cand <- cand[!paste(c_key, c_state) %in% paste(sit$c_key, sit$c_state)]
  if (!nrow(cand)) return(empty)
  H <- rbind(D[elections_before(c_election, .tg)], BW, fill = TRUE)
  mt <- .cs_match(cand, H)
  if (!nrow(mt)) return(empty)
  car <- .cs_carry_cached(.tg, C)
  if (!is.finite(car$carry)) return(empty)
  mt <- merge(mt, cand[, list(.id, seat, name)], by = ".id")
  data.table::data.table(seat = mt$seat, skey = normalise_seat(mt$seat), name = mt$name, record = mt$h_pcv,
                         record_election = mt$h_election, record_seat = mt$h_seat, carry = car$carry,
                         value = car$carry * mt$h_pcv)
}

#' Set each person-matched independent cell to carry x their own record
#'
#' A no-op unless `AUSPOL_IND_PERSON` equals `stage`. The cell is set, up or
#' down, and the seat's other classes are rescaled so the row keeps its total.
#'
#' @param shares Seats x classes matrix.
#' @param target Election label.
#' @param stage `"base"` or `"final"`: where the caller sits.
#' @param code Log prefix.
#' @param corpus Optional pre-read candidacy table.
#' @return `shares`.
#' @export
ind_person_apply <- function(shares, target, stage = c("base", "final"), code = "IP1", corpus = NULL) {
  stage <- match.arg(stage)
  if (!identical(ind_person_mode(), stage) || !"IND" %in% colnames(shares)) return(shares)
  cells <- ind_person_cells(target, corpus)
  ci <- match("IND", colnames(shares))
  ri <- match(cells$skey, normalise_seat(rownames(shares)))
  out <- shares; n <- 0L; log <- character(0)
  for (k in which(!is.na(ri))) {
    i <- ri[k]; old <- shares[i, ci]; tot <- sum(shares[i, ])
    if (old <= 0 || tot - old <= 0) next
    new <- min(cells$value[k], tot)
    out[i, ] <- shares[i, ] * (tot - new) / (tot - old)
    out[i, ci] <- new
    n <- n + 1L
    log <- c(log, sprintf("%s %s %.1f -> %.1f (%s %s %.1f x %.2f)", cells$seat[k], cells$name[k], old, new,
                          cells$record_election[k], cells$record_seat[k], cells$record[k], cells$carry[k]))
  }
  cat(sprintf("%s  person-not-seat independents (%s) for %s: %d cell(s) set from %d matched%s\n", code, stage, target, n,
              nrow(cells), if (n) paste0(": ", paste(log, collapse = "; ")) else ""))
  out
}
