#' Senate-to-state One Nation curve for a target election, time-forward
#'
#' A district's state One Nation vote tracks its federal SENATE One Nation vote
#' (r 0.92 in SA 2026, concave). The curve `state = a + b * log(senate)` is
#' fitted on the most One-Nation-heavy election BEFORE the target that has
#' district Senate shares, over the districts One Nation contested. Out of
#' sample this was the best of eleven allocation rules at a Victoria-like
#' level (scripts/build_onp_senate.R).
#'
#' @param target Election label, e.g. `"sa2026"`.
#' @param senate District Senate shares (`output/senate-onp-by-district.csv`);
#'   read when `NULL`.
#' @param cand Candidacies (`output/candidacies.csv`); read when `NULL`.
#' @param min_seats Fewest contested districts a source election needs.
#' @return list(a, b, floor, source, level, n, r2), or `NULL` when no earlier
#'   election qualifies.
#' @export
onp_senate_curve <- function(target, senate = NULL, cand = NULL, min_seats = 20L) {
  if (is.null(senate)) senate <- data.table::fread(out_path("senate-onp-by-district.csv"), showProgress = FALSE)
  if (is.null(cand)) cand <- data.table::fread(out_path("candidacies.csv"), showProgress = FALSE)
  els <- unique(paste0(senate$region, senate$cycle))
  els <- els[els != target & elections_before(els, target)]
  if (!length(els)) return(NULL)
  ko <- cand$party == "ONP" & cand$election %in% els
  lev <- cand[ko, list(level = mean(pcv), n = data.table::uniqueN(seat)), by = "election"]
  lev <- lev[lev$n >= min_seats]
  if (!nrow(lev)) return(NULL)
  src <- lev$election[which.max(lev$level)]
  key <- function(z) normalise_seat(z)
  ks <- cand$election == src & cand$party == "ONP"
  act <- cand[ks, list(actual = sum(pcv)), by = list(k = key(seat))]
  rg <- sub("[0-9]{4}$", "", src); cy <- as.integer(sub("^[a-z]+", "", src))
  kk <- senate$region == rg & senate$cycle == cy
  ss <- senate[kk, list(k = key(district), senate_pct)]
  j <- merge(act, ss, by = "k")
  if (nrow(j) < min_seats) return(NULL)
  f <- stats::lm(actual ~ log(senate_pct), data = j)
  list(a = unname(stats::coef(f)[1]), b = unname(stats::coef(f)[2]), floor = min(j$senate_pct),
       source = src, level = lev$level[which.max(lev$level)], n = nrow(j), r2 = summary(f)$r.squared)
}

#' One Nation shares by the Senate rule, keeping the statewide level
#'
#' Each seat's One Nation share becomes `level * p / mean(p)` with
#' `p = a + b * log(max(senate, floor))` from [onp_senate_curve()], over the
#' seats given (pass only the seats One Nation contests).
#'
#' @param seats Seat names (as the harness or live script names them).
#' @param target Election label.
#' @param current Current One Nation shares over `seats`; their mean over the
#'   seats that get a Senate share is preserved.
#' @param lookup Optional names to look the Senate share up by (renames).
#' @return Named numeric vector over the seats that have a Senate share (a
#'   seat without one -- e.g. forecast under a pre-redistribution name -- is
#'   left out and keeps its share), or `NULL`, with a message, when the Senate
#'   table or a curve is missing or more than 10% of seats are unmatched.
#' @export
onp_senate_alloc <- function(seats, target, current, lookup = seats) {
  sf <- out_path("senate-onp-by-district.csv")
  if (!file.exists(sf)) { cat("ONS1! output/senate-onp-by-district.csv missing -- run scripts/build_onp_senate.R\n"); return(NULL) }
  senate <- data.table::fread(sf, showProgress = FALSE)
  rg <- sub("[0-9]{4}$", "", target); cy <- as.integer(sub("^[a-z]+", "", target))
  kk <- senate$region == rg & senate$cycle == cy
  s <- senate$senate_pct[kk][match(normalise_seat(lookup), normalise_seat(senate$district[kk]))]
  if (anyNA(s)) {
    bad <- mean(is.na(s)) > 0.1
    cat(sprintf("ONS1%s %s: no Senate One Nation share for %d of %d seats (%s)%s\n", if (bad) "!" else " ",
                target, sum(is.na(s)), length(s), paste(utils::head(seats[is.na(s)], 6), collapse = ", "),
                if (bad) " -- rule NOT applied" else " -- those keep their share"))
    if (bad) return(NULL)
  }
  ok <- !is.na(s); seats <- seats[ok]; s <- s[ok]; level <- mean(current[ok])
  cv <- onp_senate_curve(target, senate = senate)
  if (is.null(cv)) { cat(sprintf("ONS1! %s: no earlier election to fit the Senate curve on\n", target)); return(NULL) }
  p <- cv$a + cv$b * log(pmax(s, cv$floor))
  if (any(!is.finite(p)) || any(p <= 0)) { cat(sprintf("ONS1! %s: Senate curve gave a non-positive share\n", target)); return(NULL) }
  out <- stats::setNames(level * p / mean(p), seats)
  cat(sprintf("ONS1  %s: One Nation by the Senate rule, curve from %s (level %.1f, %d districts, R2 %.2f); %d seats, mean %.2f, range %.1f-%.1f\n",
              target, cv$source, cv$level, cv$n, cv$r2, length(out), mean(out), min(out), max(out)))
  out
}
