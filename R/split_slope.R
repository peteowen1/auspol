#' What fraction of a class's prior seat vote belongs to candidates standing again
#'
#' The seat model projects a class's seat share forward with ONE deviation
#' slope chosen by a BINARY flag -- did the class's leading candidate return
#' ([candidate_returns()]'s `same`). That makes the projection depend on an
#' accident of who polls highest, and it is internally inconsistent: when the
#' leader is new the model keeps the whole class total, and when the leader is
#' a returner it keeps only that one person's share.
#'
#' This is the input to the fix. For every (seat, class) at the target
#' election it reports what share of the PRIOR election's vote for that class
#' sat with candidates who are standing again, so the projection can give the
#' returning and departed portions their own slopes
#' ([split_dev_slope()], [fit_split_slopes()]).
#'
#' Identity matching is [candidate_returns()]'s: surname plus first initial,
#' matched across the SEAT rather than within the party label (a candidate who
#' changes party is the same person), and against both spellings of a renamed
#' seat. It inherits that matching's known weakness on common surnames.
#'
#' @param election_from,election_to Election labels as in the corpus.
#' @param corpus Optional pre-read candidacy table; read from
#'   `output/candidacies.csv` when `NULL`.
#' @return A `data.table` of `seat`, `party`, `ret_frac` (in `[0, 1]`),
#'   `n_prior`, `n_returning`, keyed on the PRIOR election's seat naming
#'   normalised via [normalise_seat()] and reported under the target
#'   election's own seat names where they match.
#' @export
returning_vote_fraction <- function(election_from, election_to, corpus = NULL) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      stop("returning_vote_fraction() needs output/candidacies.csv; run ",
           "scripts/build_candidacies.R", call. = FALSE)
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  need <- c("election", "seat", "party", "pcv")
  miss <- setdiff(need, names(C))
  if (length(miss)) stop("corpus lacks: ", paste(miss, collapse = ", "), call. = FALSE)

  PREVT <- C[C$election == election_from]
  NOWT  <- C[C$election == election_to]
  if (!nrow(PREVT) || !nrow(NOWT)) {
    return(data.table::data.table(seat = character(0), party = character(0),
                                   ret_frac = numeric(0), n_prior = integer(0),
                                   n_returning = integer(0)))
  }
  kf <- function(d) {
    sur <- surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
                      if ("name" %in% names(d)) d$name else NA_character_)
    giv <- given_of(if ("given" %in% names(d)) d$given else NA_character_,
                    if ("name" %in% names(d)) d$name else NA_character_)
    match_key(sur, giv, "initial")
  }
  PREVT <- data.table::copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]
  NOWT  <- data.table::copy(NOWT)[,  .k := kf(.SD), .SDcols = names(NOWT)]
  PREVT[, .s := normalise_seat(seat)]
  NOWT[,  .s := normalise_seat(seat)]
  rn <- seat_rename_map()
  PREVT[, .s_renamed := .s]
  PREVT[.s %in% names(rn), .s_renamed := rn[.s]]

  now_keys <- unique(NOWT[nzchar(.k), list(.s, .k)])
  now_paste <- paste(now_keys$.s, now_keys$.k)
  PREVT[, came_back := nzchar(.k) &
          (paste(.s, .k) %in% now_paste | paste(.s_renamed, .k) %in% now_paste)]

  agg <- PREVT[nzchar(.k),
               list(returner_vote = sum(pcv[came_back], na.rm = TRUE),
                    departed_vote = sum(pcv[!came_back], na.rm = TRUE),
                    n_prior       = .N,
                    n_returning   = sum(came_back)),
               by = list(.s, party)]
  agg[, tot_prior := returner_vote + departed_vote]
  # A class with no prior vote at all has no composition to report -- NA, not
  # 0, so a caller cannot silently read "nobody returned" from "nobody stood".
  agg[, ret_frac := data.table::fifelse(tot_prior > 0, returner_vote / tot_prior, NA_real_)]

  # Report under the TARGET election's own seat spelling.
  seat_key <- unique(NOWT[, list(seat, .s)])
  out <- merge(agg, seat_key, by = ".s", allow.cartesian = TRUE)
  out[, list(seat, party, ret_frac, n_prior, n_returning)]
}

#' Project a seat's class share with separate slopes for returning and departed vote
#'
#' The two-slope generalisation of [dev_slope()]. Where `dev_slope()` applies
#' one slope to the whole deviation `x - level_prev`, this splits `x` into the
#' portion held by candidates standing again and the portion held by those who
#' are not, allocates `level_prev` between them in the same proportion, and
#' gives each its own slope:
#'
#' ```
#' projected = level_now + s_ret * (x*f - level_prev*f)
#'                       + s_dep * (x*(1-f) - level_prev*(1-f))
#' ```
#'
#' where `f` is `ret_frac`. **At the extremes this reduces exactly to
#' [dev_slope()]**: `f = 1` gives `dev_slope(..., s_ret)` and `f = 0` gives
#' `dev_slope(..., s_dep)`. Only genuinely mixed classes move, which is the
#' population the change targets
#' (`docs/plans/prereg-partial-return-split-slope-2026-09-09.md`).
#'
#' @param x Numeric vector of the class's seat-level shares at the PREVIOUS
#'   election, in percentage points -- the same input [dev_slope()] takes.
#' @param ret_frac Numeric vector, same length as `x`: the share of that prior
#'   vote held by candidates standing again, from
#'   [returning_vote_fraction()]. `NA` falls back to `fallback_frac`.
#' @param level_prev,level_now Statewide class shares, as in [dev_slope()].
#' @param s_ret,s_dep Slopes for the returning and departed portions.
#' @param fallback_frac Used where `ret_frac` is `NA` (no prior vote to
#'   decompose). Defaults to 1, which reproduces the returning-candidate slope
#'   -- chosen because a class with no prior vote has a deviation of
#'   `-level_prev` either way and the two slopes differ least there.
#' @return Numeric vector of projected shares, floored at zero.
#' @export
split_dev_slope <- function(x, ret_frac, level_prev, level_now,
                             s_ret, s_dep, fallback_frac = 1) {
  if (length(ret_frac) != length(x)) {
    stop("ret_frac must match x in length: ", length(ret_frac), " vs ",
         length(x), call. = FALSE)
  }
  if (!is.finite(level_prev) || !is.finite(level_now))
    stop("level_prev and level_now must both be finite", call. = FALSE)
  if (!is.finite(s_ret) || !is.finite(s_dep))
    stop("s_ret and s_dep must both be finite", call. = FALSE)
  f <- ret_frac
  f[!is.finite(f)] <- fallback_frac
  f <- pmin(1, pmax(0, f))
  dev_ret <- x * f       - level_prev * f
  dev_dep <- x * (1 - f) - level_prev * (1 - f)
  pmax(0, level_now + s_ret * dev_ret + s_dep * dev_dep)
}

#' Fit the returning and departed deviation slopes, leave-one-election-out
#'
#' Fits the two slopes [split_dev_slope()] consumes, over every election pair
#' the corpus holds EXCEPT the one being scored -- the same discipline
#' [fit_defector_discount()] uses, so a target election never contributes to
#' the slopes used to predict it.
#'
#' Fitted on NON-MAJOR classes only, because that is the population the arm
#' acts on and majors are dominated by the statewide swing rather than by who
#' is standing. Regression through the origin of the seat's deviation from the
#' statewide level on the two decomposed deviations, exactly the quantity
#' [dev_slope()] is defined in terms of.
#'
#' Measured pooled over all 22 pairs (2026-09-09): `s_ret` **0.899**
#' (se 0.013), `s_dep` **0.575** (se 0.013), separated by 17.6 SE. The
#' returning figure closely reproduces the frozen 0.907 the repo already
#' carried; the departed figure is far ABOVE its frozen 0.326 counterpart --
#' a departed candidate's vote persists considerably more than that constant
#' assumed.
#'
#' @param target_election The election being scored; excluded from the fit.
#' @param corpus Optional pre-read candidacy table.
#' @param pairs Optional list of `list(election=, prev=)`; [all_election_pairs()]
#'   when `NULL`. Exposed for tests.
#' @param min_n Minimum fitting rows required; below this both slopes come
#'   back `NULL` and a caller should fall back to [dev_slope()].
#' @return A list: `s_ret`, `s_dep` (or `NULL`), `se_ret`, `se_dep`, `n`.
#' @export
fit_split_slopes <- function(target_election, corpus = NULL, pairs = NULL,
                              min_n = 200L) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      stop("fit_split_slopes() needs output/candidacies.csv; run ",
           "scripts/build_candidacies.R", call. = FALSE)
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  MAJ <- c("ALP", "LNP", "NAT")
  if (is.null(pairs)) pairs <- all_election_pairs()
  pairs <- Filter(function(pr) !identical(pr$election, target_election), pairs)

  state_level <- function(el) {
    d <- C[C$election == el]
    if (!nrow(d) || !all(c("votes", "tot") %in% names(d))) return(NULL)
    d <- d[is.finite(d$votes)]
    if (!nrow(d)) return(NULL)
    seat_tot <- unique(d[, list(seat, tot)])
    denom <- sum(seat_tot$tot, na.rm = TRUE)
    if (!is.finite(denom) || denom <= 0) return(NULL)
    d[, list(level = 100 * sum(votes, na.rm = TRUE) / denom), by = party]
  }

  rows <- data.table::rbindlist(lapply(pairs, function(pr) {
    lp <- state_level(pr$prev); ln <- state_level(pr$election)
    if (is.null(lp) || is.null(ln)) return(NULL)
    fr <- tryCatch(returning_vote_fraction(pr$prev, pr$election, corpus = C),
                   error = function(e) NULL)
    if (is.null(fr) || !nrow(fr)) return(NULL)
    NOWT <- C[C$election == pr$election]
    now_cls <- NOWT[, list(actual_now = sum(pcv, na.rm = TRUE)), by = list(seat, party)]
    PREVT <- C[C$election == pr$prev]
    PREVT <- data.table::copy(PREVT)[, .s := normalise_seat(seat)]
    prev_cls <- PREVT[, list(x = sum(pcv, na.rm = TRUE)), by = list(.s, party)]
    m <- merge(fr, now_cls, by = c("seat", "party"))
    m[, .s := normalise_seat(seat)]
    m <- merge(m, prev_cls, by = c(".s", "party"))
    m <- merge(m, lp[, list(party, level_prev = level)], by = "party")
    m <- merge(m, ln[, list(party, level_now  = level)], by = "party")
    m[!party %in% MAJ & is.finite(ret_frac) & x > 0]
  }), fill = TRUE)

  if (is.null(rows) || nrow(rows) < min_n) {
    return(list(s_ret = NULL, s_dep = NULL, se_ret = NA_real_, se_dep = NA_real_,
                n = if (is.null(rows)) 0L else nrow(rows)))
  }
  rows[, dev_ret := x * ret_frac       - level_prev * ret_frac]
  rows[, dev_dep := x * (1 - ret_frac) - level_prev * (1 - ret_frac)]
  rows[, yy := actual_now - level_now]
  fit <- stats::lm(yy ~ 0 + dev_ret + dev_dep, data = rows)
  cf <- stats::coef(fit)
  cm <- summary(fit)$coefficients
  # A RANK-DEFICIENT FIT DROPS A TERM SILENTLY. If every row happens to be all
  # returning (or all departed), or the two columns are collinear, lm() returns
  # an NA coefficient or omits the row from the summary entirely, and indexing
  # it by name throws -- which would take down a whole harness run on thin
  # data rather than degrading to dev_slope(). Caught by a test on a two-pair
  # synthetic corpus, 2026-09-09. Both slopes must be present and finite or
  # this reports "no fit" and the caller falls back.
  want <- c("dev_ret", "dev_dep")
  ok <- all(want %in% names(cf)) && all(is.finite(cf[want])) &&
        all(want %in% rownames(cm))
  if (!ok) {
    return(list(s_ret = NULL, s_dep = NULL, se_ret = NA_real_, se_dep = NA_real_,
                n = nrow(rows)))
  }
  se <- cm[, "Std. Error"]
  list(s_ret = unname(cf[["dev_ret"]]), s_dep = unname(cf[["dev_dep"]]),
       se_ret = unname(se[["dev_ret"]]), se_dep = unname(se[["dev_dep"]]),
       n = nrow(rows))
}

#' Everything a harness needs to use the split slope, or NULL when it is off
#'
#' ONE constructor because six harnesses and the published forecast each build
#' their shares slightly differently, and a parameter wired into some but not
#' all of them produces numbers that look like findings -- the failure this
#' repo has already paid for twice (see [dev_slope()]'s own note, and the
#' frozen-0.282 defector discount [fit_defector_discount()] replaced).
#'
#' Returns `NULL` -- meaning "carry on with [dev_slope()] exactly as before" --
#' whenever the arm is off, the corpus is unavailable, or the fit does not
#' converge on enough rows. A caller therefore needs no branch beyond
#' `is.null()`.
#'
#' @param election_from,election_to Election labels for the pair being run.
#' @param corpus Optional pre-read candidacy table.
#' @param enabled Logical; defaults to the `AUSPOL_SPLIT_SLOPE` environment
#'   variable being `"1"`. Off by default, so an unset environment reproduces
#'   the shipped model byte-for-byte.
#' @return `NULL`, or a list with `s_ret`, `s_dep`, `n`, and `frac(party,
#'   seats)` returning the returning-vote fraction aligned to `seats`.
#' @export
split_slope_context <- function(election_from, election_to, corpus = NULL,
                                 enabled = NULL) {
  if (is.null(enabled)) {
    enabled <- identical(Sys.getenv("AUSPOL_SPLIT_SLOPE", "0"), "1")
  }
  if (!isTRUE(enabled)) return(NULL)
  fit <- tryCatch(fit_split_slopes(election_to, corpus = corpus),
                  error = function(e) {
                    cat(sprintf("SS0! split-slope fit FAILED, falling back to dev_slope: %s\n",
                                conditionMessage(e)))
                    NULL
                  })
  if (is.null(fit) || is.null(fit$s_ret) || is.null(fit$s_dep)) {
    cat("SS0! split-slope fit unavailable; dev_slope() unchanged\n")
    return(NULL)
  }
  fr <- tryCatch(returning_vote_fraction(election_from, election_to, corpus = corpus),
                 error = function(e) NULL)
  if (is.null(fr) || !nrow(fr)) {
    cat("SS0! returning_vote_fraction() empty; dev_slope() unchanged\n")
    return(NULL)
  }
  FR <- data.table::as.data.table(fr)
  cat(sprintf("SS1  split slope ON: s_ret=%.4f (se %.4f) s_dep=%.4f (se %.4f) | fit n=%d | %d seat-class fractions\n",
              fit$s_ret, fit$se_ret, fit$s_dep, fit$se_dep, fit$n, nrow(FR)))
  list(
    s_ret = fit$s_ret, s_dep = fit$s_dep, n = fit$n,
    frac = function(want_party, seats) {
      sub <- FR[FR$party == want_party]
      if (!nrow(sub)) return(rep(NA_real_, length(seats)))
      v <- stats::setNames(sub$ret_frac, sub$seat)[seats]
      unname(v)
    })
}
