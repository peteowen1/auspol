#' Federal primary vote in the booths inside each state district
#'
#' From `external/elections/fed-booth-map.csv` (the booth -> district join
#' `scripts/transpose_fed_swing.R` makes) and the AEC first-preferences-by-
#' polling-place files. The federal election is the one before the state
#' election, as the transposed swing uses. plans/prereg-departed-fed-booths-2026-09-30.md.
#'
#' @param election State election label, e.g. `"nsw2023"`.
#' @return data.table `seat`, `class` (ALP, LNP, GRN, OTH), `fed_pct`, `votes`;
#'   empty when no booth map exists for the election.
#' @export
fed_booth_primaries <- function(election) {
  empty <- data.table::data.table(seat = character(0), class = character(0), fed_pct = numeric(0), votes = numeric(0))
  mf <- file.path(pkg_root(), "external", "elections", "fed-booth-map.csv")
  if (!file.exists(mf)) return(empty)
  bm <- data.table::fread(mf, showProgress = FALSE)
  rg <- sub("[0-9]{4}$", "", election); yr <- as.integer(sub("^[a-z]+", "", election))
  bm <- bm[bm$region == rg & bm$cycle == yr]
  if (!nrow(bm)) return(empty)
  fy <- bm$fed[1]
  bf <- file.path(pkg_root(), "external", "reference", "aec", "booths", sprintf("fed%d-%s.csv", fy, toupper(rg)))
  if (!file.exists(bf)) return(empty)
  b <- data.table::fread(bf, skip = 1L, showProgress = FALSE)
  pa <- toupper(b$PartyAb)
  b$class <- ifelse(pa == "ALP", "ALP", ifelse(pa %in% c("LP", "LIB", "NP", "LNP", "LNQ", "CLP", "NAT"), "LNP",
             ifelse(pa %in% c("GRN", "GVIC"), "GRN", "OTH")))
  bb <- b[, list(v = sum(OrdinaryVotes)), by = list(place_id = PollingPlaceID, class)]
  m <- merge(bb, unique(bm[, list(district, place_id)]), by = "place_id")
  d <- m[, list(v = sum(v)), by = list(seat = district, class)]
  d[, `:=`(votes = sum(v), fed_pct = 100 * v / sum(v)), by = seat]
  d[, list(seat, class, fed_pct, votes)]
}

#' Seats whose sitting member left, with the incumbent class and inputs
#'
#' For election T: seats in the retirements record for T, the member's class,
#' their party's primary at the previous state election, the same booths'
#' federal primary, and the gap between them (the member's premium over how
#' their own voters vote federally).
#' @param election State election label.
#' @return data.table `seat`, `class`, `prev`, `fed`, `gap`.
#' @keywords internal
.departed_inputs <- function(election) {
  rf <- file.path(pkg_root(), "external", "reference", "retirements", "retirements.csv")
  out <- data.table::data.table(seat = character(0), class = character(0), prev = numeric(0), fed = numeric(0), gap = numeric(0))
  if (!file.exists(rf)) return(out)
  r <- data.table::fread(rf, showProgress = FALSE)
  el <- election
  r <- r[r$election == el]
  if (!nrow(r)) return(out)
  p <- r$party
  r$class <- ifelse(grepl("Labor", p), "ALP", ifelse(grepl("Liberal|National|LNP", p), "LNP", NA_character_))
  r <- r[!is.na(r$class)]
  fb <- fed_booth_primaries(election)
  if (!nrow(fb) || !nrow(r)) return(out)
  cand <- data.table::fread(out_path("candidacies.csv"), showProgress = FALSE)
  rg <- sub("[0-9]{4}$", "", election)
  prev_el <- rev(sort(unique(cand$election[cand$region == rg & elections_before(cand$election, election)])))[1]
  if (is.na(prev_el)) return(out)
  pv <- cand[cand$election == prev_el, list(prev = sum(pcv)), by = list(seat, class = party)]
  x <- merge(r[, list(seat, class)], pv, by = c("seat", "class"))
  x <- merge(x, fb[, list(seat, class, fed = fed_pct)], by = c("seat", "class"))
  x$gap <- x$prev - x$fed
  x
}

#' Time-forward share k of the gap kept, and blend weight beta, for departed seats
#'
#' On departed seats of elections BEFORE the target: k = the pooled share of
#' the gap that survived (`sum((actual - fed) * gap) / sum(gap^2)`, least
#' squares through the origin, clamped to between 0 and 1); the rule is `fed + k * gap`;
#' beta = least squares of `actual - pred` on `rule - pred`, SE clustered on
#' election, shrunk `b^3/(b^2+se^2)` and clamped to between 0 and 1.
#' @param target_election Label.
#' @return list `k`, `beta`, `b`, `se`, `n`, `els`.
#' @export
departed_fed_weights <- function(target_election) {
  f <- current_seat_predictions()
  zero <- list(k = NA_real_, beta = 0, b = NA_real_, se = NA_real_, n = 0L, els = character(0))
  if (is.null(f)) return(zero)
  els <- unique(f$election)
  els <- els[elections_before(els, target_election) & !grepl("^fed", els)]
  rows <- data.table::rbindlist(lapply(els, function(e) {
    x <- .departed_inputs(e)
    if (!nrow(x)) return(NULL)
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party, pred = xgb_pred_seat, actual = actual_share)]
    x$k_seat <- normalise_seat(x$seat)
    m <- merge(x, fe, by.x = c("k_seat", "class"), by.y = c("seat", "class"))
    if (!nrow(m)) return(NULL)
    m$el <- e
    m
  }), fill = TRUE)
  if (nrow(rows) < 5 || length(unique(rows$el)) < 2) return(modifyList(zero, list(n = nrow(rows))))
  k <- min(1, max(0, sum((rows$actual - rows$fed) * rows$gap) / sum(rows$gap^2)))
  dx <- (rows$fed + k * rows$gap) - rows$pred
  dy <- rows$actual - rows$pred
  b <- sum(dx * dy) / sum(dx^2)
  e <- dy - b * dx
  G <- length(unique(rows$el))
  se <- sqrt(sum(tapply(dx * e, rows$el, sum)^2) / sum(dx^2)^2 * G / max(1, G - 1))
  beta <- if (is.finite(se) && se > 0) min(1, max(0, b * b^2 / (b^2 + se^2))) else 0
  list(k = k, beta = beta, b = b, se = se, n = nrow(rows), els = unique(rows$el))
}

#' Departed-member inputs for one target, computed or shipped
#' @param target_election Label such as `"vic2026"`.
#' @param write Write `output/departed-fed-<target>.csv` for the daily run.
#' @return data.table `seat`, `class`, `prev`, `fed`, `gap` with attribute `w`.
#' @export
departed_fed_table <- function(target_election, write = FALSE) {
  cache <- out_path(sprintf("departed-fed-%s.csv", target_election))
  if (.has_seat_predictions() && file.exists(file.path(pkg_root(), "external", "elections", "fed-booth-map.csv"))) {
    w <- departed_fed_weights(target_election)
    tb <- .departed_inputs(target_election)
    if (write) {
      out <- data.table::copy(tb)
      if (!nrow(out)) out <- data.table::data.table(seat = NA_character_, class = NA_character_, prev = NA_real_, fed = NA_real_, gap = NA_real_)
      out$k <- w$k; out$beta <- w$beta; out$b <- w$b; out$se <- w$se; out$n <- w$n
      data.table::fwrite(out, cache)
    }
  } else if (file.exists(cache)) {
    raw <- data.table::fread(cache, showProgress = FALSE)
    w <- list(k = raw$k[1], beta = raw$beta[1], b = raw$b[1], se = raw$se[1], n = raw$n[1])
    tb <- raw[!is.na(raw$seat), list(seat, class, prev, fed, gap)]
    cat(sprintf("DF0  %s: departed-member inputs read from %s (sources absent)\n", target_election, basename(cache)))
  } else {
    stop("departed-member blend for ", target_election, ": neither the sources nor ", cache, " exist")
  }
  attr(tb, "w") <- w
  tb
}

#' Pull a departed member's party toward the same booths' federal vote
#'
#' A no-op unless `AUSPOL_DEPARTED_FED` is "1". In each seat whose sitting
#' member left: `share += beta * (fed + k * gap - share)` for the member's
#' class, the other classes giving up the difference in proportion.
#' @param shares Matrix of primary shares, rownames = seats, colnames = classes.
#' @param target_election Label.
#' @return `shares`, adjusted.
#' @export
departed_fed_apply <- function(shares, target_election) {
  if (!identical(Sys.getenv("AUSPOL_DEPARTED_FED", "0"), "1")) return(shares)
  tb <- tryCatch(departed_fed_table(target_election), error = function(e) {
    cat(sprintf("DF1! %s: departed-member blend SKIPPED -- %s\n", target_election, conditionMessage(e))); NULL })
  if (is.null(tb)) return(shares)
  w <- attr(tb, "w")
  if (!nrow(tb) || !is.finite(w$beta) || w$beta <= 0 || !is.finite(w$k)) {
    cat(sprintf("DF1  %s: no departed-member blend (beta %.3f, k %s, %d earlier cells, %d departed seats here)\n",
                target_election, w$beta, format(round(w$k, 2)), w$n, nrow(tb)))
    return(shares)
  }
  moved <- character(0)
  for (r in seq_len(nrow(tb))) {
    i <- match(normalise_seat(tb$seat[r]), normalise_seat(rownames(shares))); j <- match(tb$class[r], colnames(shares))
    if (is.na(i) || is.na(j) || shares[i, j] <= 0) next
    target <- tb$fed[r] + w$k * tb$gap[r]
    old <- shares[i, j]
    shares[i, ] <- .shift_cell(shares[i, ], j, w$beta * (target - old))
    moved <- c(moved, sprintf("%s %s %.1f->%.1f", tb$seat[r], tb$class[r], old, shares[i, j]))
  }
  cat(sprintf("DF1  %s: departed-member blend beta %.3f (raw %.3f, se %.3f), k %.2f, %d earlier cells; %s\n",
              target_election, w$beta, w$b, w$se, w$k, w$n, if (length(moved)) paste(moved, collapse = "; ") else "no seat matched"))
  shares
}
