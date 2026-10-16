# A Liberal and a National in the same seat, counted as two candidates
# (AUSPOL_COALITION_SPLIT). docs/plans/prereg-lib-nat-two-candidates-2026-10-16.md.
#
# classify_party() files both as `LNP`, so the simulator saw one Coalition
# candidate holding the combined vote and every Coalition vote reached the final
# count. In reality the weaker of the two is excluded and 71% of its votes go to
# the other (207 exclusions, 21 elections); Albany 2013 was lost that way on a
# combined 49.5 against Labor's 39.3. The combined vote is unchanged here; this
# file fits how it divides and how much survives an exclusion, using only
# elections held in an earlier year than the one being predicted.

.cs_cache <- new.env(parent = emptyenv())

#' Which Coalition party a raw party label names
#'
#' @param party_raw Character vector of party labels as the commission printed them.
#' @return `"NAT"`, `"LIB"`, or `NA` for anything else (including the merged
#'   Queensland LNP and the Country Liberals, which field one candidate).
#' @export
coalition_side <- function(party_raw) {
  x <- toupper(trimws(as.character(party_raw)))
  nat <- (grepl("NATIONAL", x) & !grepl("LIBERAL", x)) | x %in% c("NAT", "NP", "NATS")
  lib <- !nat & (grepl("LIBERAL", x) | x %in% c("LIB", "LP")) &
    !grepl("LIBERAL NATIONAL|COUNTRY LIBERAL|DEMOCRAT|LIBERTARIAN", x) & x != "LNP"
  out <- rep(NA_character_, length(x))
  out[nat] <- "NAT"; out[lib] <- "LIB"
  out
}

#' Fit the Coalition split for one election, time-forward
#'
#' @param target_election Election label, e.g. `"wa2013"`.
#' @param cand The candidacy corpus (`output/candidacies.csv`); read if `NULL`.
#' @param transfers Transfer rows (`election, seat, round, from, to, votes`)
#'   from `external/elections/*-transfers.csv`; read if `NULL`.
#' @return A list: `seats` (data.frame: `seat`, `r` junior fraction centre,
#'   `sd`, `has_prev`), `f`, `mu`, `tau`, `s`, `n_hist` (earlier split
#'   seat-elections), `n_pairs` (consecutive pairs), `n_events` (earlier
#'   Coalition-to-Coalition exclusions). `seats` is empty, and `f` `NA`, when
#'   no earlier election supplies the data -- the split is then not applied.
#' @export
coalition_split_fit <- function(target_election, cand = NULL, transfers = NULL) {
  if (is.null(cand)) cand <- data.table::fread(out_path("candidacies.csv"))
  cand <- data.table::as.data.table(cand)
  tgt_el <- as.character(target_election)
  tgt_year <- as.integer(sub("^[a-z]+", "", tgt_el))
  tgt_region <- sub("[0-9]+$", "", tgt_el)
  co <- cand[cand$party == "LNP", c("election", "seat", "party_raw", "pcv"), with = FALSE]
  co[, "side" := coalition_side(get("party_raw"))]
  co <- co[!is.na(get("side"))]
  co[, "region" := sub("[0-9]+$", "", get("election"))]
  co[, "year" := as.integer(sub("^[a-z]+", "", get("election")))]
  by_seat <- co[, list(n_lib = sum(get("side") == "LIB"), n_nat = sum(get("side") == "NAT"),
                       lib = sum(get("pcv")[get("side") == "LIB"], na.rm = TRUE),
                       nat = sum(get("pcv")[get("side") == "NAT"], na.rm = TRUE)),
                by = c("election", "region", "year", "seat")]
  by_seat <- by_seat[get("n_lib") > 0 & get("n_nat") > 0]
  # Target split seats come from NOMINATIONS only; their votes are never read.
  tgt_seats <- unique(by_seat$seat[by_seat$election == tgt_el])

  hist <- by_seat[get("year") < tgt_year & (get("lib") + get("nat")) > 0]
  hist[, "fn" := get("nat") / (get("lib") + get("nat"))]
  hist[, "j" := pmin(get("fn"), 1 - get("fn"))]
  empty <- list(seats = data.frame(seat = character(0), r = numeric(0), sd = numeric(0),
                                   has_prev = logical(0)),
                f = NA_real_, mu = NA_real_, tau = NA_real_, s = NA_real_,
                n_hist = nrow(hist), n_pairs = 0L, n_events = 0L, n_target = length(tgt_seats))

  # Each region's elections in order, to find "the previous election".
  els <- unique(cand[, c("election"), with = FALSE])$election
  el_tab <- data.frame(election = els, region = sub("[0-9]+$", "", els),
                       year = as.integer(sub("^[a-z]+", "", els)), stringsAsFactors = FALSE)
  el_tab <- el_tab[order(el_tab$region, el_tab$year), ]
  el_tab$prev <- stats::ave(el_tab$election, el_tab$region,
                            FUN = function(x) c(NA_character_, utils::head(x, -1)))
  prev_of <- stats::setNames(el_tab$prev, el_tab$election)

  # Consecutive pairs: the same seat split at an election and at the region's
  # previous one, both before the target year.
  hp <- data.table::copy(hist)
  hp[, "prev_el" := unname(prev_of[get("election")])]
  prv <- hist[, c("election", "seat", "fn"), with = FALSE]
  data.table::setnames(prv, c("prev_el", "seat", "fn_prev"))
  pairs <- merge(hp, prv, by = c("prev_el", "seat"))
  d <- pairs$fn - pairs$fn_prev

  # Coalition-to-Coalition rate from earlier elections' exclusions.
  if (is.null(transfers)) {
    fs <- list.files(file.path("external", "elections"), "transfers[.]csv$", full.names = TRUE)
    transfers <- data.table::rbindlist(lapply(fs, function(f) {
      x <- data.table::fread(f)
      x[, c("election", "seat", "round", "from", "to", "votes"), with = FALSE]
    }), fill = TRUE)
  }
  tx <- data.table::as.data.table(transfers)
  tx <- tx[as.integer(sub("^[a-z]+", "", tx$election)) < tgt_year & tx$from == "LNP"]
  ev <- tx[, list(tot = sum(get("votes")), to_lnp = sum(get("votes")[get("to") == "LNP"])),
           by = c("election", "seat", "round")]
  ev <- ev[get("to_lnp") > 0]

  if (nrow(hist) < 2L || length(d) < 2L || nrow(ev) == 0L) {
    empty$n_pairs <- length(d); empty$n_events <- nrow(ev)
    return(empty)
  }
  mu <- mean(hist$j); tau2 <- stats::var(hist$j); s <- stats::sd(d)
  w <- tau2 / (tau2 + s^2)
  f <- sum(ev$to_lnp) / sum(ev$tot)

  pe <- unname(prev_of[tgt_el])
  prev_row <- if (is.na(pe)) hist[0] else hist[hist$election == pe]
  pj <- stats::setNames(prev_row$j, prev_row$seat)
  has_prev <- tgt_seats %in% names(pj)
  r <- ifelse(has_prev, mu + w * (unname(pj[tgt_seats]) - mu), mu)
  # A seat with no earlier split is a draw from the population of split seats
  # (sd tau); one with an earlier split moves from it by the change (sd s).
  sdv <- ifelse(has_prev, s, sqrt(tau2))
  list(seats = data.frame(seat = tgt_seats, r = r, sd = sdv, has_prev = has_prev,
                          stringsAsFactors = FALSE),
       f = f, mu = mu, tau = sqrt(tau2), s = s,
       n_hist = nrow(hist), n_pairs = length(d), n_events = nrow(ev),
       n_target = length(tgt_seats))
}

#' The `coalition_split` argument for one election's simulation
#'
#' Reads `AUSPOL_COALITION_SPLIT`: anything but `"1"` returns `NULL`, the
#' one-candidate count. Prints, per election, the number of split seats, `f`
#' and the mean centre `r` applied (the prereg's plumbing line, code `LN1`).
#'
#' @param target_election Election label.
#' @param seat_names The simulation's seats, in its order.
#' @param ... Passed to [coalition_split_fit()].
#' @return `NULL`, or a list `r`, `sd` (named by seat, `NA` for no split) and `f`.
#' @export
coalition_split_args <- function(target_election, seat_names, ...) {
  if (!identical(Sys.getenv("AUSPOL_COALITION_SPLIT", "0"), "1")) return(NULL)
  # Cached per election for a call with no inputs supplied: the Victorian
  # harness simulates in a loop, and the fit reads two corpora each time.
  # Keyed on the files' modification times too, so a rebuilt corpus refits.
  dots <- list(...)
  key <- paste(target_election, file.mtime(out_path("candidacies.csv")),
               max(file.mtime(list.files(file.path("external", "elections"), "transfers[.]csv$",
                                         full.names = TRUE))))
  fit <- if (!length(dots) && !is.null(.cs_cache[[key]])) .cs_cache[[key]] else {
    x <- coalition_split_fit(target_election, ...)
    if (!length(dots)) assign(key, x, envir = .cs_cache)
    x
  }
  r <- stats::setNames(rep(NA_real_, length(seat_names)), seat_names)
  sdv <- r
  hit <- fit$seats$seat[fit$seats$seat %in% seat_names]
  r[hit] <- fit$seats$r[match(hit, fit$seats$seat)]
  sdv[hit] <- fit$seats$sd[match(hit, fit$seats$seat)]
  miss <- setdiff(fit$seats$seat, seat_names)
  cat(sprintf(paste0("LN1 coalition split %s: %d split seat(s) applied of %d nominated",
                     "%s; f=%.3f (%d earlier exclusions); mean r=%.3f; mu=%.3f tau=%.3f s=%.3f",
                     " (%d earlier split seats, %d pairs)\n"),
              target_election, length(hit), fit$n_target,
              if (length(miss)) paste0(" (not in the simulation: ", paste(miss, collapse = ", "), ")") else "",
              fit$f, fit$n_events, if (length(hit)) mean(r[hit]) else NA_real_,
              fit$mu, fit$tau, fit$s, fit$n_hist, fit$n_pairs))
  if (!length(hit) || !is.finite(fit$f)) return(NULL)
  list(r = r, sd = sdv, f = fit$f)
}
