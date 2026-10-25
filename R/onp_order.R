#' Federal Senate One Nation share by state seat, time-forward
#'
#' Looks up each seat's One Nation share of the federal SENATE vote, measured in
#' its own booths (`output/senate-onp-by-district.csv`, written by
#' `scripts/build_onp_senate.R`). The Senate ballot is the same in every seat,
#' so unlike the House vote it does not depend on who else stood locally
#' (docs/reviews/market-disagreement-vic2026-2026-10-25.md: Maribyrnong and
#' Corio had no other right-wing minor in 2025, Bendigo had a first-time
#' Nationals candidate).
#'
#' Time-forward: the table row for a target names the federal election it was
#' measured at (`fed`), and that election must be dated strictly before the
#' target's polling day. A later or same-day federal election is an error, not
#' a fallback.
#'
#' @param seats Seat names, as the caller names them.
#' @param target Election label, e.g. `"qld2020"`.
#' @param lookup Names to look the Senate share up by (renames), same length
#'   as `seats`.
#' @param senate The Senate table (`region, cycle, fed, district,
#'   senate_pct`); when `NULL`, `output/senate-onp-by-district.csv`, or for a
#'   cycle it lacks the One Nation rows of `output/senate-by-district-class.csv`.
#' @return Named numeric vector over `seats` (`NA` where the table has no
#'   share), with attribute `fed` (the federal election year), or `NULL` when
#'   the table is missing or has no row for the target.
#' @export
onp_senate_key <- function(seats, target, lookup = seats, senate = NULL) {
  stopifnot(length(lookup) == length(seats))
  rg <- sub("[0-9]{4}$", "", target); cy <- suppressWarnings(as.integer(sub("^[a-z]+", "", target)))
  if (is.null(senate)) {
    # The One Nation table first; the all-class table (scripts/build_senate_by_district.R,
    # which also covers WA and nsw2027) for a cycle the first does not have.
    sf <- out_path("senate-onp-by-district.csv")
    senate <- if (file.exists(sf)) data.table::fread(sf, showProgress = FALSE) else NULL
    if (is.null(senate) || !any(senate$region == rg & senate$cycle %in% cy)) {
      cf <- out_path("senate-by-district-class.csv")
      if (!file.exists(cf)) return(NULL)
      cl <- data.table::fread(cf, showProgress = FALSE)
      senate <- cl[cl$cls == "ONP", ]
    }
  }
  kk <- senate$region == rg & senate$cycle %in% cy
  if (!any(kk)) return(NULL)
  fy <- unique(senate$fed[kk])
  if (length(fy) != 1L) stop("onp_senate_key: ", target, " has rows from more than one federal election (", paste(fy, collapse = ", "), ")")
  if (!isTRUE(elections_before(paste0("fed", fy), target)))
    stop("onp_senate_key: the Senate table for ", target, " is from fed", fy,
         ", which is not before the target's polling day -- that would be leakage")
  sub_d <- normalise_seat(senate$district[kk])
  if (anyDuplicated(sub_d)) stop("onp_senate_key: duplicated districts for ", target)
  out <- stats::setNames(senate$senate_pct[kk][match(normalise_seat(lookup), sub_d)], seats)
  attr(out, "fed") <- fy
  out
}

#' Re-order an allocation by a key, keeping its values
#'
#' The sorted `values` are handed out in the order of `key`: the seat with the
#' lowest key gets the smallest value, and so on. The set of values, so the
#' spread and the mean, is unchanged; only which seat gets which value moves.
#' This is the "ordering only" arm of `AUSPOL_ONP_ORDER=senate_rank`.
#'
#' @param values Numeric vector (the current allocation), named.
#' @param key Numeric vector of the same length, no `NA`.
#' @return `values` re-assigned, names kept in the original order.
#' @export
onp_rank_reassign <- function(values, key) {
  if (length(values) != length(key)) stop("onp_rank_reassign: values and key differ in length")
  if (anyNA(values) || anyNA(key)) stop("onp_rank_reassign: NA in values or key")
  out <- values
  out[order(key)] <- sort(unname(values))
  out
}

#' Re-rank a harness's One Nation shares on the Senate vote, then refill
#'
#' For the seats One Nation contests (share > 0), keep the harness's own set of
#' One Nation shares and re-assign them by Senate rank ([onp_rank_reassign()]).
#' Seats with no Senate share keep theirs.
#'
#' `refill = "none"` only swaps the One Nation cells, for a harness that
#' renormalises every row afterwards (SA and Qld do, which is how their
#' shipped path treats its own One Nation values). `refill = "prop"` makes the
#' other classes in each moved seat give up or take the difference in
#' proportion to their size, keeping each row's total -- the fill the refused
#' `senate` rule used, for a harness whose rows already sum to 100 here (NSW).
#'
#' @param shares Seat x class matrix with an `"ONP"` column.
#' @param target Election label.
#' @param lookup Names to look the Senate share up by.
#' @param code Check code printed with the result.
#' @param senate Optional Senate table (tests).
#' @param refill `"prop"` or `"none"`, see above.
#' @return The new matrix, or `NULL` (with a message) when the arm cannot
#'   apply: no table, fewer than three contested seats, or more than 10% of the
#'   contested seats unmatched.
#' @export
onp_senate_rank_apply <- function(shares, target, lookup = rownames(shares), code = "ONR1", senate = NULL,
                                  refill = c("prop", "none")) {
  refill <- match.arg(refill)
  if (!"ONP" %in% colnames(shares)) { cat(sprintf("%s! %s: no One Nation column -- senate_rank not applied\n", code, target)); return(NULL) }
  if (anyDuplicated(rownames(shares))) stop("onp_senate_rank_apply: duplicated seat names")
  con <- which(shares[, "ONP"] > 0)
  if (length(con) < 3L) { cat(sprintf("%s! %s: One Nation contests %d seat(s) -- senate_rank not applied\n", code, target, length(con))); return(NULL) }
  key <- onp_senate_key(rownames(shares)[con], target, lookup = lookup[con], senate = senate)
  if (is.null(key)) { cat(sprintf("%s! %s: no Senate One Nation table for this election -- senate_rank not applied\n", code, target)); return(NULL) }
  miss <- is.na(key)
  if (mean(miss) > 0.1) {
    cat(sprintf("%s! %s: no Senate share for %d of %d contested seats -- senate_rank NOT applied\n", code, target, sum(miss), length(key)))
    return(NULL)
  }
  idx <- con[!miss]
  old <- shares[idx, "ONP"]
  new <- onp_rank_reassign(old, key[!miss])
  oth <- setdiff(colnames(shares), "ONP")
  for (j in seq_along(idx)) {
    i <- idx[j]
    tot <- sum(shares[i, ]); rest <- sum(shares[i, oth])
    if (refill == "prop" && rest > 0) shares[i, oth] <- shares[i, oth] * (tot - new[[j]]) / rest
    shares[i, "ONP"] <- new[[j]]
  }
  rho <- suppressWarnings(stats::cor(old, new, method = "spearman"))
  cat(sprintf("%s  %s: One Nation re-ranked on the fed%d SENATE vote over %d contested seats%s; same values (mean %.2f, range %.1f-%.1f), %d seats moved > 1 point, rank corr old v new %.3f, refill %s\n",
              code, target, attr(key, "fed"), length(idx),
              if (any(miss)) sprintf(" (%d without a Senate share keep theirs)", sum(miss)) else "",
              mean(new), min(new), max(new), sum(abs(new - old) > 1), rho, refill))
  shares
}

#' Fill One Nation's seat-level deviation by the statewide draw betas
#'
#' The shipped fill (`AUSPOL_ONP_FILL=prop`) scales every other cell in a seat
#' by `(100 - onp) / rest`, so where One Nation is weak each party gets back a
#' share of the gap in proportion to its size there. This arm
#' (`AUSPOL_ONP_FILL=uniform_major`) hands the gap out by the statewide
#' scenario response instead: class `c` takes `gap * w_c`, with
#' `w_c = max(0, -beta_c)` from the One Nation row of
#' `output/statewide-draw-betas-<stem>.csv` (how each class moves per point of
#' One Nation across the statewide draws), renormalised over the classes
#' present and not held in that seat. Classes the betas do not name (OTH,
#' OTH_RIGHT, IND, ...) share the `OTH` weight in proportion to their size.
#' A cell pushed below zero is floored at zero and the row's free cells are
#' rescaled to the exact total.
#'
#' @param shares Seat x class matrix (the ONP column is ignored and not set).
#' @param onp_target One Nation share per seat (same order as rows).
#' @param betas Data frame with `moved`, `class`, `beta`.
#' @param held Optional logical matrix like `shares`; held cells keep their value.
#' @param code Check code printed with the result.
#' @return `shares` with every non-ONP, non-held cell refilled; attribute
#'   `onp_fill` holds the weights and the number of floored cells.
#' @export
onp_fill_betas <- function(shares, onp_target, betas, held = NULL, code = "ONF1") {
  stopifnot(length(onp_target) == nrow(shares), !anyNA(onp_target))
  b <- betas[betas$moved == "ONP", , drop = FALSE]
  if (!nrow(b)) stop("onp_fill_betas: no One Nation row in the betas")
  if (anyDuplicated(b$class)) stop("onp_fill_betas: duplicated classes in the One Nation betas")
  if (any(!is.finite(b$beta))) stop("onp_fill_betas: non-finite beta")
  w0 <- stats::setNames(pmax(0, -b$beta), b$class)
  if (sum(w0) <= 0) stop("onp_fill_betas: no class loses votes to One Nation in the betas")
  other <- setdiff(colnames(shares), "ONP")
  named <- intersect(setdiff(names(w0), "OTH"), other)
  oth_grp <- setdiff(other, named)
  if (is.null(held)) held <- matrix(FALSE, nrow(shares), ncol(shares), dimnames = dimnames(shares))
  n_floor <- 0L
  for (i in seq_len(nrow(shares))) {
    free <- other[!held[i, other] & shares[i, other] > 0]
    if (!length(free)) next
    total <- max(0, 100 - onp_target[i] - sum(shares[i, other[held[i, other]]]))
    gap <- total - sum(shares[i, free])
    cw <- stats::setNames(numeric(length(free)), free)
    for (p in intersect(free, named)) cw[p] <- w0[[p]]
    og <- intersect(free, oth_grp)
    if (length(og) && "OTH" %in% names(w0)) cw[og] <- w0[["OTH"]] * shares[i, og] / sum(shares[i, og])
    if (sum(cw) <= 0) cw[] <- shares[i, free]          # no weighted class present: proportional
    v <- shares[i, free] + gap * cw / sum(cw)
    if (any(v < 0)) { n_floor <- n_floor + sum(v < 0); v <- pmax(v, 0) }
    if (sum(v) > 0) v <- v * total / sum(v)
    shares[i, free] <- v
  }
  wn <- w0 / sum(w0)
  attr(shares, "onp_fill") <- list(weights = wn, floored = n_floor)
  cat(sprintf("%s  One Nation fill by the statewide draw betas (uniform_major): weights %s; %d seat(s), %d cell(s) floored at 0\n",
              code, paste(sprintf("%s %.3f", names(wn), wn), collapse = ", "), nrow(shares), n_floor))
  shares
}
