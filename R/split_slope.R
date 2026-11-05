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
    match_key(sur, giv, "person")
  }
  PREVT <- data.table::copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]
  NOWT  <- data.table::copy(NOWT)[,  .k := kf(.SD), .SDcols = names(NOWT)]
  align_person_keys(NOWT, PREVT); align_person_keys(PREVT, NOWT)
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
  pairs <- fit_pairs_for(target_election, pairs)   # time-forward (plans/prereg-time-forward-constants-2026-09-28.md)

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

#' Fit the conditional same/new deviation slopes, leave-one-election-out
#'
#' `conditional_slopes()` and `screened_slopes()` carry eight hardcoded
#' numbers -- a "same" and a "new" slope for each of IND, OTH_RIGHT, GRN and
#' ONP -- with no committed script that produced them. This fits them, holding
#' out the election being scored, the same discipline
#' [fit_defector_discount()] uses.
#'
#' Checked like-for-like 2026-09-09
#' (`docs/plans/prereg-fit-conditional-slopes-2026-09-09.md`), IND's shipped
#' constants are correct (new 0.374 fitted vs 0.326 shipped, +1.1 SE; same
#' 0.882 vs 0.907, -0.7 SE). **OTH_RIGHT's are not**: fitted 0.442 / 0.766
#' against shipped 0.325 / 0.891, +3.1 and -3.8 SE, wrong in opposite
#' directions, so the shipped pair over-separates returning from new
#' candidates. ONP "same" is -2.7 SE off on 51 observations.
#'
#' The tiers mean exactly what [candidate_returns()] means by them: "same" is
#' a seat-class where AT LEAST ONE candidate of that class stood before,
#' "new" is one where none did.
#'
#' @param target_election Election being scored; excluded from the fit.
#' @param corpus Optional pre-read candidacy table.
#' @param pairs Optional pair list; [all_election_pairs()] when `NULL`.
#' @param min_n Minimum observations for a class/tier cell to be fitted at
#'   all. Below it the shipped constant is kept -- fitting a slope on a
#'   handful of seats is how this repo has produced confident wrong numbers
#'   before. ONP "same" sits just above this floor at 51.
#' @return A list of `same` and `new` named numeric vectors (shipped values
#'   where a cell was too thin), plus `n` a table of the counts actually used.
#' @export
fit_conditional_slopes <- function(target_election, corpus = NULL, pairs = NULL,
                                    min_n = 40L) {
  SHIP_SAME <- c(IND = 0.907, OTH_RIGHT = 0.891, GRN = 0.994, ONP = 0.610)
  SHIP_NEW  <- c(IND = 0.326, OTH_RIGHT = 0.325, GRN = 0.880, ONP = 0.545)
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      # A guard that can't fail is worse than none: this must be visibly
      # distinguishable from a genuine fit that happened to find nothing,
      # matching governed_population()'s convention (R/salience_screen.R)
      # of message()-ing rather than degrading silently on a missing input.
      message("fit_dispersion_slopes()/fit_conditional_slopes(): ", f,
              " missing -- falling back to SHIP_SAME/SHIP_NEW for every class, ",
              "nothing was fitted")
      return(list(same = SHIP_SAME, new = SHIP_NEW, n = NULL))
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  if (is.null(pairs)) pairs <- all_election_pairs()
  pairs <- fit_pairs_for(target_election, pairs)   # time-forward (plans/prereg-time-forward-constants-2026-09-28.md)

  state_level <- function(el) {
    d <- C[C$election == el]
    if (!nrow(d) || !all(c("votes", "tot") %in% names(d))) return(NULL)
    d <- d[is.finite(d$votes)]
    if (!nrow(d)) return(NULL)
    st <- unique(d[, list(seat, tot)]); den <- sum(st$tot, na.rm = TRUE)
    if (!is.finite(den) || den <= 0) return(NULL)
    d[, list(level = 100 * sum(votes, na.rm = TRUE) / den), by = party]
  }

  rows <- data.table::rbindlist(lapply(pairs, function(pr) {
    lp <- state_level(pr$prev); ln <- state_level(pr$election)
    if (is.null(lp) || is.null(ln)) return(NULL)
    fr <- tryCatch(returning_vote_fraction(pr$prev, pr$election, corpus = C),
                   error = function(e) NULL)
    if (is.null(fr) || !nrow(fr)) return(NULL)
    NOWT <- C[C$election == pr$election]
    nowc <- NOWT[, list(actual_now = sum(pcv, na.rm = TRUE)), by = list(seat, party)]
    P <- data.table::copy(C[C$election == pr$prev])[, .s := normalise_seat(seat)]
    prevc <- P[, list(x = sum(pcv, na.rm = TRUE)), by = list(.s, party)]
    m <- merge(fr, nowc, by = c("seat", "party"))
    m[, .s := normalise_seat(seat)]
    m <- merge(m, prevc, by = c(".s", "party"))
    m <- merge(m, lp[, list(party, level_prev = level)], by = "party")
    m <- merge(m, ln[, list(party, level_now  = level)], by = "party")
    m[, pair := pr$election]; m[x > 0]
  }), fill = TRUE)
  # AUSPOL_SHIP_TIME_FORWARD=1 (default): the SHIP_* constants were fitted on
  # every election, so using them as the fallback carried later elections into
  # early ones (and into ONP's returning-candidate cell in 4 ledger elections).
  # The fallback is now the tier's POOLED slope over all minor classes from the
  # same earlier-elections rows, else 1. plans/prereg-ship-fallback-time-forward-2026-09-29.md.
  ship_tf <- !identical(Sys.getenv("AUSPOL_SHIP_TIME_FORWARD", "1"), "0")
  if (ship_tf) {
    ones <- stats::setNames(rep(1, length(SHIP_SAME)), names(SHIP_SAME))
    if (is.null(rows) || !nrow(rows)) return(list(same = ones, new = ones, n = NULL))
  } else if (is.null(rows) || !nrow(rows)) return(list(same = SHIP_SAME, new = SHIP_NEW, n = NULL))

  rows[, dev := x - level_prev]
  rows[, yy  := actual_now - level_now]
  same <- SHIP_SAME; new <- SHIP_NEW
  if (ship_tf) {
    tier_pool <- function(sub) {
      if (nrow(sub) < min_n) return(1)
      f <- tryCatch(stats::lm(yy ~ 0 + dev, data = sub), error = function(e) NULL)
      cm <- if (is.null(f)) NULL else summary(f)$coefficients
      if (is.null(cm) || !nrow(cm) || !is.finite(cm[1, 1])) 1 else cm[1, 1]
    }
    pool_same <- tier_pool(rows[party %in% names(SHIP_SAME) & n_returning > 0])
    pool_new  <- tier_pool(rows[party %in% names(SHIP_SAME) & n_returning == 0])
    same[] <- pool_same; new[] <- pool_new
  }
  counts <- list()
  for (cl in names(SHIP_SAME)) {
    for (tier in c("same", "new")) {
      sub <- if (tier == "same") rows[party == cl & n_returning > 0]
             else                rows[party == cl & n_returning == 0]
      counts[[length(counts) + 1L]] <-
        data.table::data.table(party = cl, tier = tier, n = nrow(sub))
      if (.slope_shrink_on()) {
        v <- .shrunk_slope(sub, 1)
        if (tier == "same") same[[cl]] <- v else new[[cl]] <- v
        next
      }
      if (nrow(sub) < min_n) next
      fit <- tryCatch(stats::lm(yy ~ 0 + dev, data = sub), error = function(e) NULL)
      if (is.null(fit)) next
      cm <- summary(fit)$coefficients
      # Same rank-deficiency guard as fit_split_slopes(): a degenerate cell
      # drops the term and indexing it by name throws mid-run.
      if (!nrow(cm) || !is.finite(cm[1, 1])) next
      if (tier == "same") same[[cl]] <- cm[1, 1] else new[[cl]] <- cm[1, 1]
    }
  }
  list(same = same, new = new, n = data.table::rbindlist(counts))
}

#' Fit same/new conditional slopes for MAJOR parties, leave-target-out
#'
#' [conditional_slopes()]/[screened_slopes()] have never had a same/new
#' distinction for ALP/LNP/NAT -- `dev_slope()`'s `default = 1` (full,
#' unconditional carryforward of a seat's premium over the state average)
#' applies to every major-party seat regardless of whether the sitting
#' member is standing again. Found 2026-09-16 tracing why Parramatta's
#' `base_pred` gave LNP's 2023 candidate the FULL +12.4 of Geoff Lee's 2019
#' personal-vote premium, undiscounted, after Lee retired --
#' `docs/reviews/base-pred-blind-to-tonights-fixes-2026-09-16.md`.
#'
#' Identical method to [fit_conditional_slopes()] (`yy ~ 0 + dev`, no
#' intercept, split by whether the class had a returning candidate in that
#' seat, leave-target-out): reused rather than duplicated logic diverging.
#' The only real difference is the fallback -- there is no shipped
#' major-party same/new constant to fall back to (majors were never
#' conditioned at all), so a cell that fails `min_n` falls back to `1.0`,
#' i.e. today's actual unconditioned behaviour, not a guessed number.
#'
#' @inheritParams fit_conditional_slopes
#' @export
fit_major_conditional_slopes <- function(target_election, corpus = NULL, pairs = NULL,
                                         min_n = 40L) {
  MAJ <- c("ALP", "LNP", "NAT")
  FALLBACK <- stats::setNames(rep(1, length(MAJ)), MAJ)
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      message("fit_major_conditional_slopes(): ", f,
              " missing -- falling back to 1.0 (uniform swing) for every class")
      return(list(same = FALLBACK, new = FALLBACK, n = NULL))
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  if (is.null(pairs)) pairs <- all_election_pairs()
  pairs <- fit_pairs_for(target_election, pairs)   # time-forward (plans/prereg-time-forward-constants-2026-09-28.md)

  state_level <- function(el) {
    d <- C[C$election == el]
    if (!nrow(d) || !all(c("votes", "tot") %in% names(d))) return(NULL)
    d <- d[is.finite(d$votes)]
    if (!nrow(d)) return(NULL)
    st <- unique(d[, list(seat, tot)]); den <- sum(st$tot, na.rm = TRUE)
    if (!is.finite(den) || den <= 0) return(NULL)
    d[, list(level = 100 * sum(votes, na.rm = TRUE) / den), by = party]
  }

  rows <- data.table::rbindlist(lapply(pairs, function(pr) {
    lp <- state_level(pr$prev); ln <- state_level(pr$election)
    if (is.null(lp) || is.null(ln)) return(NULL)
    fr <- tryCatch(returning_vote_fraction(pr$prev, pr$election, corpus = C),
                   error = function(e) NULL)
    if (is.null(fr) || !nrow(fr)) return(NULL)
    NOWT <- C[C$election == pr$election]
    nowc <- NOWT[, list(actual_now = sum(pcv, na.rm = TRUE)), by = list(seat, party)]
    P <- data.table::copy(C[C$election == pr$prev])[, .s := normalise_seat(seat)]
    prevc <- P[, list(x = sum(pcv, na.rm = TRUE)), by = list(.s, party)]
    m <- merge(fr, nowc, by = c("seat", "party"))
    m[, .s := normalise_seat(seat)]
    m <- merge(m, prevc, by = c(".s", "party"))
    m <- merge(m, lp[, list(party, level_prev = level)], by = "party")
    m <- merge(m, ln[, list(party, level_now  = level)], by = "party")
    m[, pair := pr$election]; m[x > 0]
  }), fill = TRUE)
  if (is.null(rows) || !nrow(rows)) return(list(same = FALLBACK, new = FALLBACK, n = NULL))

  rows[, dev := x - level_prev]
  rows[, yy  := actual_now - level_now]
  same <- FALLBACK; new <- FALLBACK
  counts <- list()
  for (cl in MAJ) {
    for (tier in c("same", "new")) {
      sub <- if (tier == "same") rows[party == cl & n_returning > 0]
             else                rows[party == cl & n_returning == 0]
      counts[[length(counts) + 1L]] <-
        data.table::data.table(party = cl, tier = tier, n = nrow(sub))
      if (.slope_shrink_on()) {
        v <- .shrunk_slope(sub, 1)
        if (tier == "same") same[[cl]] <- v else new[[cl]] <- v
        next
      }
      if (nrow(sub) < min_n) next
      fit <- tryCatch(stats::lm(yy ~ 0 + dev, data = sub), error = function(e) NULL)
      if (is.null(fit)) next
      cm <- summary(fit)$coefficients
      if (!nrow(cm) || !is.finite(cm[1, 1])) next
      if (tier == "same") same[[cl]] <- cm[1, 1] else new[[cl]] <- cm[1, 1]
    }
  }
  list(same = same, new = new, n = data.table::rbindlist(counts))
}

#' Fit the "new"-candidate slope from dispersion, leave-one-election-out
#'
#' The flat `new` constant in [conditional_slopes()] averages hundreds of
#' ordinary no-hoper candidacies with the handful of real emergence/collapse
#' events, and is provably wrong on the events that matter most: shipped
#' `OTH_RIGHT` `new` = 0.325 is 3.1x off fed2013's actual slope (Palmer
#' United's debut), shipped `ONP` `new` = 0.545 is 3.7x off sa2026's.
#'
#' For a no-intercept regression, `slope = corr(dev_before, dev_after) *
#' sd(dev_after) / sd(dev_before)` is an exact identity. Neither ingredient
#' is stable POOLED ACROSS CLASSES (correlation ranges 0.75-0.94 for GRN down
#' to near-zero for OTH; sd-at-a-given-level differs 2.5x between IND and ONP
#' at the same statewide share) -- but each is far more stable within one
#' class, fit leave-target-out over that class's other pairs. Verified
#' 2026-09-09 against the three real ONP/OTH_RIGHT emergence and collapse
#' events in the corpus: predicted slopes within 15-42% of the true fitted
#' slope, versus the flat constants' 1.2x-3.7x errors on the same three
#' cases (`docs/plans/prereg-dispersion-slope-2026-09-09.md`).
#'
#' Falls back to the shipped flat constant for a class when: fewer than
#' `min_pairs` other pairs of that class exist to fit corr/the sd-curve on,
#' the target's own "new"-tier seat history is too thin to measure a real
#' `sd_before` (< 5 seats, or sd < 0.3 -- indistinguishable from noise), or
#' any intermediate fit is non-finite. The predicted slope is clipped to
#' `[0, 3]`; anything outside that range is not credible and falls back too.
#'
#' Only the `new` (no candidate of this class stood here before, and not
#' salience-screen-permitted) tier moves. `same` is returned unchanged at the
#' shipped constants -- this arm does not touch the returning-candidate
#' slope, the sitting-member tier, or the screen's 1.0 override.
#'
#' @param target_election Election being scored; excluded from every fit.
#' @param corpus Optional pre-read candidacy table.
#' @param pairs Optional pair list; [all_election_pairs()] when `NULL`. Must
#'   include the pair that PRODUCES `target_election`, so its own "before"
#'   seat history and (when `level_now` is not supplied) its own actual
#'   statewide result can be read.
#' @param min_pairs Minimum OTHER pairs of a class needed to fit its
#'   correlation and sd-curve. Below it, that class keeps the shipped
#'   constant.
#' @param level_now Optional named numeric vector (by class) of the
#'   statewide share to predict `sd_after` at. `NULL` (the default, used by
#'   every backtest harness) reads the target election's own ACTUAL result
#'   from the corpus -- appropriate for backtesting a known outcome. A live
#'   forecast (no actual result yet) passes the trend model's forecast level
#'   here instead.
#' @param classes Which classes to fit. Default is GRN and ONP only --
#'   real, persistent, single-brand parties, which is what the corr x
#'   sd-ratio mechanism assumes. `IND` and `OTH_RIGHT` are NOT parties in
#'   that sense: `IND` is by definition a different person every election
#'   (`classify_party()`'s own docs: "Independents are their own class ...
#'   not other"), and `OTH_RIGHT` is a residual bucket `classify_party()`
#'   files a dozen-plus unrelated minor-right parties into (DLP, Liberal
#'   Democrats, Palmer United/UAP, Rise Up Australia, Family First, Shooters
#'   Fishers Farmers, Katter's, and more -- see `R/parties.R`). Fitting IND
#'   this way on 2026-09-09 gave fed2013 a slope of 0.071, crushing all 74
#'   of its "new" independent seats toward the state mean, and made fed2013
#'   -- the case the whole arm was built around -- WORSE overall despite
#'   OTH_RIGHT's own fitted slope being closer to the truth (see the result
#'   section of `docs/plans/prereg-dispersion-slope-2026-09-09.md`). Classes
#'   left out of `classes` keep the shipped flat constant untouched -- the
#'   structurally correct default for a bucket with no brand continuity.
#' @return A list: `same` (unchanged `SHIP_SAME`), `new` (named vector, one
#'   entry fitted or falling back per class), `n` (a table of how many other
#'   pairs each class had to fit on, for coverage reporting).
#' @export
fit_dispersion_slopes <- function(target_election, corpus = NULL, pairs = NULL,
                                   min_pairs = 6L, level_now = NULL,
                                   classes = c("GRN", "ONP")) {
  SHIP_SAME <- c(IND = 0.907, OTH_RIGHT = 0.891, GRN = 0.994, ONP = 0.610)
  SHIP_NEW  <- c(IND = 0.326, OTH_RIGHT = 0.325, GRN = 0.880, ONP = 0.545)
  classes <- intersect(classes, names(SHIP_NEW))
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      # A guard that can't fail is worse than none: this must be visibly
      # distinguishable from a genuine fit that happened to find nothing,
      # matching governed_population()'s convention (R/salience_screen.R)
      # of message()-ing rather than degrading silently on a missing input.
      message("fit_dispersion_slopes()/fit_conditional_slopes(): ", f,
              " missing -- falling back to SHIP_SAME/SHIP_NEW for every class, ",
              "nothing was fitted")
      return(list(same = SHIP_SAME, new = SHIP_NEW, n = NULL))
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  if (is.null(pairs)) pairs <- all_election_pairs()
  target_pair <- Find(function(pr) identical(pr$election, target_election), pairs)
  fit_pairs <- fit_pairs_for(target_election, pairs)   # time-forward (plans/prereg-time-forward-constants-2026-09-28.md)

  new_tier_cell <- function(before, after, cls) {
    bb <- C[C$election == before & C$party == cls]
    aa <- C[C$election == after  & C$party == cls]
    if (!nrow(bb) || !nrow(aa)) return(NULL)
    b <- bb[order(-pcv), .SD[1], by = seat][, list(seat, name_before = name, pcv_before = pcv)]
    a <- aa[order(-pcv), .SD[1], by = seat][, list(seat, name_after  = name, pcv_after  = pcv)]
    sw_before <- mean(bb[, sum(pcv), by = seat]$V1)
    sw_after  <- mean(aa[, sum(pcv), by = seat]$V1)
    m <- merge(a, b, by = "seat", all.x = TRUE)
    m[, is_new := is.na(name_before) | name_before != name_after]
    m <- m[m$is_new == TRUE & !is.na(m$pcv_after)]
    if (!nrow(m)) return(NULL)
    m[, dev_before := ifelse(is.na(pcv_before), 0, pcv_before - sw_before)]
    m[, dev_after  := pcv_after - sw_after]
    list(m = m, sw_before = sw_before, sw_after = sw_after)
  }

  new_slopes <- SHIP_NEW
  cov <- list()
  for (cl in classes) {
    rows <- list()
    for (p in fit_pairs) {
      r <- tryCatch(new_tier_cell(p$prev, p$election, cl), error = function(e) NULL)
      if (is.null(r) || nrow(r$m) < 15) next
      co <- suppressWarnings(stats::cor(r$m$dev_before, r$m$dev_after))
      if (is.finite(co)) {
        rows[[length(rows) + 1L]] <- data.table::data.table(
          n = nrow(r$m), corr = co, lvl_after = r$sw_after, sd_after = stats::sd(r$m$dev_after))
      }
    }
    Tc <- data.table::rbindlist(rows)
    cov[[cl]] <- data.table::data.table(class = cl, n_pairs = nrow(Tc))
    if (nrow(Tc) < min_pairs || is.null(target_pair)) next

    class_corr <- stats::weighted.mean(Tc$corr, Tc$n)
    Tc <- Tc[Tc$sd_after > 0]
    Tc[, shape := sqrt(lvl_after * (100 - lvl_after) / 100)]
    Tc <- Tc[Tc$shape > 0]
    if (nrow(Tc) < min_pairs) next
    curve <- tryCatch(stats::lm(log(sd_after) ~ log(shape), data = Tc), error = function(e) NULL)
    if (is.null(curve)) next

    tgt_r <- tryCatch(new_tier_cell(target_pair$prev, target_pair$election, cl), error = function(e) NULL)
    if (is.null(tgt_r) || nrow(tgt_r$m) < 5) next
    sd_before <- stats::sd(tgt_r$m$dev_before)
    if (!is.finite(sd_before) || sd_before < 0.3) next

    lvl_now <- if (!is.null(level_now) && cl %in% names(level_now)) level_now[[cl]] else tgt_r$sw_after
    shape_now <- sqrt(lvl_now * (100 - lvl_now) / 100)
    if (!is.finite(shape_now) || shape_now <= 0) next
    sd_after_pred <- tryCatch(
      exp(stats::predict(curve, newdata = data.frame(shape = shape_now))),
      error = function(e) NA_real_)
    pred_slope <- class_corr * sd_after_pred / sd_before
    if (!is.finite(pred_slope)) next
    new_slopes[[cl]] <- max(0, min(3, pred_slope))
  }
  list(same = SHIP_SAME, new = new_slopes, n = data.table::rbindlist(cov))
}

# AUSPOL_SLOPE_SHRINK=1: a slope through the origin shrunk toward 1 (no
# adjustment) by its precision, instead of a min_n cliff that jumps from the
# fallback to the full estimate (fed2007's departed slope went 1.000 at n=6,
# then 0.56 at n=41 once fits became time-forward). Precision is measured
# ACROSS elections (cluster-robust by `pair`): seats in one election share a
# swing, so the seat-level lm standard error overstates it. The target is 1,
# not the hardcoded SHIP_* fallbacks, which were fitted on every election and
# so would carry later elections into early ones.
# docs/plans/prereg-slope-shrinkage-2026-09-28.md.
.slope_shrink_on <- function() identical(Sys.getenv("AUSPOL_SLOPE_SHRINK", "0"), "1")
.shrunk_slope <- function(sub, target = 1) {
  sub <- sub[is.finite(sub$dev) & is.finite(sub$yy)]
  G <- length(unique(sub$pair))
  # At least 3 elections: a standard error from 2 clusters is itself too
  # unreliable to trust (fed2007's departed slope came out 0.313 from 6 seats
  # in 2 elections). And the LARGER of the cluster-robust and ordinary
  # variance, so a lucky small spread cannot make a thin estimate look precise.
  if (nrow(sub) < 3L || G < 3L || !isTRUE(sum(sub$dev^2) > 0)) return(target)
  b <- sum(sub$dev * sub$yy) / sum(sub$dev^2)
  e <- sub$yy - b * sub$dev
  se2_cl <- sum(tapply(sub$dev * e, sub$pair, sum)^2) / sum(sub$dev^2)^2 * G / (G - 1)
  se2_ols <- (sum(e^2) / max(1, nrow(sub) - 1)) / sum(sub$dev^2)
  se2 <- max(se2_cl, se2_ols)
  d <- b - target
  if (!isTRUE(d^2 + se2 > 0)) return(target)
  target + d * d^2 / (d^2 + se2)
}


#' Fit the slope a major party keeps on its seat deviation when its sitting member departs
#'
#' Leave-target-out over every other pair. For ALP and LNP separately, rows
#' where the class held the seat at the prior election and its member did
#' not return under that label (`mp_departed` from [candidate_returns()]),
#' regress `actual - level_now` on `prior - level_prev` through the origin,
#' exactly the fit [fit_conditional_slopes()] does for the minor classes.
#' Fewer than `min_n` rows for a class leaves it at 1 (the current
#' behaviour). docs/plans/prereg-major-departed-slope-2026-09-18.md.
#'
#' @param target_election Pair excluded from the fit.
#' @param corpus,pairs As in [fit_conditional_slopes()].
#' @param min_n Minimum departed rows per class.
#' @return list(slope, n) for the departed tier, (slope_present, n_present)
#'   for every other ALP/LNP cell, and `rows`, the fitted data.
#' @export
fit_major_departed_slope <- function(target_election, corpus = NULL, pairs = NULL, min_n = 40L) {
  MAJ <- c("ALP", "LNP")
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) stop("fit_major_departed_slope() needs output/candidacies.csv", call. = FALSE)
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  if (is.null(pairs)) pairs <- all_election_pairs()
  pairs <- fit_pairs_for(target_election, pairs)   # time-forward (plans/prereg-time-forward-constants-2026-09-28.md)
  state_level <- function(el) {
    d <- C[C$election == el]
    if (!nrow(d) || !all(c("votes", "tot") %in% names(d))) return(NULL)
    d <- d[is.finite(d$votes)]
    st <- unique(d[, list(seat, tot)]); den <- sum(st$tot, na.rm = TRUE)
    if (!is.finite(den) || den <= 0) return(NULL)
    d[, list(level = 100 * sum(votes, na.rm = TRUE) / den), by = party]
  }
  rows <- data.table::rbindlist(lapply(pairs, function(pr) {
    lp <- state_level(pr$prev); ln <- state_level(pr$election)
    if (is.null(lp) || is.null(ln)) return(NULL)
    r <- tryCatch(candidate_returns(pr$prev, pr$election, corpus = C), error = function(e) NULL)
    if (is.null(r) || !"mp_departed" %in% names(r)) return(NULL)
    NOWT <- C[C$election == pr$election]
    nowc <- NOWT[, list(actual_now = sum(pcv, na.rm = TRUE)), by = list(seat, party)]
    P <- data.table::copy(C[C$election == pr$prev])[, .s := normalise_seat(seat)]
    prevc <- P[, list(x = sum(pcv, na.rm = TRUE)), by = list(.s, party)]
    m <- merge(r[r$party %in% MAJ, list(seat, party, mp_departed)], nowc, by = c("seat", "party"))
    m[, .s := normalise_seat(seat)]
    m <- merge(m, prevc, by = c(".s", "party"))
    m <- merge(m, lp[, list(party, level_prev = level)], by = "party")
    m <- merge(m, ln[, list(party, level_now  = level)], by = "party")
    m[, pair := pr$election]
    m[x > 0]
  }), fill = TRUE)
  slope <- c(ALP = 1, LNP = 1); n <- c(ALP = 0L, LNP = 0L)
  slope_present <- c(ALP = 1, LNP = 1); n_present <- c(ALP = 0L, LNP = 0L)
  if (!nrow(rows)) return(list(slope = slope, n = n, slope_present = slope_present, n_present = n_present, rows = rows))
  rows[, dev := x - level_prev]; rows[, yy := actual_now - level_now]
  fit1 <- function(sub) {
    if (.slope_shrink_on()) return(.shrunk_slope(sub, 1))
    if (nrow(sub) < min_n) return(NA_real_)
    fit <- tryCatch(stats::lm(yy ~ 0 + dev, data = sub), error = function(e) NULL)
    if (is.null(fit)) return(NA_real_)
    cm <- summary(fit)$coefficients
    if (nrow(cm) && is.finite(cm[1, 1])) cm[1, 1] else NA_real_
  }
  pooled <- if (.departed_pool_on()) .pool_departed_slopes(rows[mp_departed %in% TRUE]) else NULL
  for (cl in MAJ) {
    sub <- rows[party == cl & mp_departed %in% TRUE]; n[[cl]] <- nrow(sub)
    s <- if (is.null(pooled)) fit1(sub) else pooled$slope[[cl]]
    if (is.finite(s)) slope[[cl]] <- s
    # THE OTHER TIER: member stayed, or the class never held the seat
    # (docs/plans/prereg-major-present-slope-2026-09-18.md).
    subp <- rows[party == cl & !mp_departed %in% TRUE]; n_present[[cl]] <- nrow(subp)
    sp <- fit1(subp); if (is.finite(sp)) slope_present[[cl]] <- sp
  }
  out <- list(slope = slope, n = n, slope_present = slope_present, n_present = n_present, rows = rows)
  if (!is.null(pooled)) out$pool <- pooled
  out
}

# AUSPOL_DEPARTED_POOL=1: the ALP and LNP departed-member slopes partially pooled
# toward the pooled ALP+LNP departed slope, with no min_n cliff (Pete 2026-10-27,
# option B 2026-11-05; docs/plans/prereg-departed-slope-pool-2026-11-05.md).
#   mu     = slope through the origin over both parties' departed rows
#   own_c  = each party's own slope, se_c^2 the larger of the cluster-robust (by
#            election) and ordinary variance, as in .shrunk_slope()
#   tau^2  = the between-party variance, estimated from EARLIER ELECTIONS' gaps,
#            not from the two cells' own spread: for every pair p with departed
#            rows for both parties, g_p = b_ALP,p - b_LNP,p with sampling variance
#            v_p = s2 / sxx_ALP,p + s2 / sxx_LNP,p, s2 ONE residual variance pooled over every
#            (election, party) cell (prereg amendment 1); E[g_p^2] = v_p + 4 tau^2 when the two true slopes sit at mu +- delta,
#            so tau^2 = max(0, weighted mean(g_p^2 - v_p)) / 4, weights 1 / (v_p + 4 tau^2)^2
#            (the inverse variance of g_p^2), iterated.
#   shrunk = mu + tau^2 / (tau^2 + se_c^2) * (own_c - mu)
# A party with no departed rows takes mu; neither party with rows returns NULL,
# and the caller keeps 1. Rows are already time-forward (fit_pairs_for()).
.departed_pool_on <- function() identical(Sys.getenv("AUSPOL_DEPARTED_POOL", "0"), "1")
.origin_fit <- function(sub) {
  sub <- sub[is.finite(sub$dev) & is.finite(sub$yy)]
  sxx <- sum(sub$dev^2)
  if (nrow(sub) < 2L || !isTRUE(sxx > 0)) return(c(b = NA_real_, se2 = NA_real_))
  b <- sum(sub$dev * sub$yy) / sxx
  e <- sub$yy - b * sub$dev
  se2_ols <- (sum(e^2) / max(1, nrow(sub) - 1)) / sxx
  G <- length(unique(sub$pair))
  se2_cl <- if (G >= 2L) sum(tapply(sub$dev * e, sub$pair, sum)^2) / sxx^2 * G / (G - 1) else 0
  c(b = b, se2 = max(se2_cl, se2_ols))
}
.pool_departed_slopes <- function(dep) {
  MAJ <- c("ALP", "LNP")
  dep <- dep[dep$party %in% MAJ & is.finite(dep$dev) & is.finite(dep$yy)]
  if (!nrow(dep)) return(NULL)
  mu <- .origin_fit(dep)[["b"]]
  if (!is.finite(mu)) return(NULL)
  own <- lapply(stats::setNames(MAJ, MAJ), function(cl) .origin_fit(dep[dep$party == cl]))
  # Per (election, party) cell: its slope and sum of dev^2. Sampling variance uses ONE residual variance pooled over
  # every cell (review 5 Nov: a cell's own variance from 2-3 rows can come out near zero, take almost all the weight
  # and push tau^2 above 1; 19 of the 67 cells behind vic2026 have under 5 rows). A 1-row cell counts, at s2 / dev^2.
  cells <- data.table::rbindlist(lapply(unique(dep$pair), function(pp) data.table::rbindlist(lapply(MAJ, function(cl) {
    d <- dep[dep$pair == pp & dep$party == cl]
    sxx <- sum(d$dev^2)
    if (!nrow(d) || !isTRUE(sxx > 0)) return(NULL)
    b <- sum(d$dev * d$yy) / sxx
    data.table::data.table(pair = pp, cls = cl, b = b, sxx = sxx, n = nrow(d), rss = sum((d$yy - b * d$dev)^2))
  }))))
  gaps <- data.table::data.table(pair = character(0), g = numeric(0), v = numeric(0))
  if (nrow(cells)) {
    df <- sum(cells$n - 1L)
    s2 <- if (df > 0) sum(cells$rss) / df else NA_real_
    both <- intersect(cells$pair[cells$cls == "ALP"], cells$pair[cells$cls == "LNP"])
    if (is.finite(s2) && s2 > 0 && length(both)) {
      A <- cells[cells$cls == "ALP"][match(both, cells$pair[cells$cls == "ALP"])]
      L <- cells[cells$cls == "LNP"][match(both, cells$pair[cells$cls == "LNP"])]
      gaps <- data.table::data.table(pair = both, g = A$b - L$b, v = s2 / A$sxx + s2 / L$sxx)
    }
  }
  gaps <- gaps[is.finite(gaps$v) & gaps$v > 0]
  tau2 <- 0
  if (nrow(gaps)) {
    for (it in 1:50) {
      w <- 1 / (gaps$v + 4 * tau2)^2
      t_new <- max(0, sum(w * (gaps$g^2 - gaps$v)) / sum(w)) / 4
      if (abs(t_new - tau2) < 1e-10) { tau2 <- t_new; break }
      tau2 <- t_new
    }
  }
  slope <- vapply(MAJ, function(cl) {
    o <- own[[cl]]
    if (!is.finite(o[["b"]])) return(mu)
    w <- if (tau2 + o[["se2"]] > 0) tau2 / (tau2 + o[["se2"]]) else 0
    mu + w * (o[["b"]] - mu)
  }, numeric(1))
  list(slope = slope, mu = mu, tau2 = tau2, n_gap_elections = nrow(gaps),
       own = vapply(own, function(o) o[["b"]], numeric(1)), own_se = vapply(own, function(o) sqrt(o[["se2"]]), numeric(1)))
}

# --------------------------------------------------------------------------
# AUSPOL_DEPARTED_RATE: refit the departed-leader retention rate, time-forward.
# docs/plans/prereg-departed-rate-refit-2026-10-03.md (sections 3, 8, 9).
# --------------------------------------------------------------------------
.DR_MIN_ELECTIONS <- 3L        # same floor as .shrunk_slope()
.DR_TAU2_FLOOR    <- 0.01^2    # prereg section 3 step 2
.DR_BIG_SE2       <- 1e4       # "huge" variance for an election with < 2 rows: ~zero weight
.DR_SE2_FLOOR     <- 1e-6      # addendum 2026-10-04 item 2: an exact-fit election must not get infinite weight
.DR_MIN_ROWS      <- 2L        # addendum item 1: an election needs >= 2 departed rows to count toward the floor

# Statewide share (votes over valid votes in every seat) of every class at one election.
.dr_state_level <- function(C, el) {
  d <- C[C$election == el]
  if (!nrow(d) || !all(c("votes", "tot") %in% names(d))) return(NULL)
  d <- d[is.finite(d$votes)]
  st <- unique(d[, list(seat, tot)]); den <- sum(st$tot, na.rm = TRUE)
  if (!is.finite(den) || den <= 0) return(NULL)
  d[, list(level = 100 * sum(votes, na.rm = TRUE) / den), by = party]
}

# The departed-branch rows of ONE earlier election pair: class `cls` cells whose prior
# leader did not return (prior_leader_returns == FALSE; NA counts as returning, exactly as
# screened_slopes() does), that the screen does not permit (permit %in% TRUE is FALSE, so
# NA = silent counts as not permitted, 2026-09-20), and that stood this time.
.dr_pair_rows <- function(pr, C, cls, permit_fn, exclude_fn = NULL) {
  lp <- .dr_state_level(C, pr$prev); ln <- .dr_state_level(C, pr$election)
  if (is.null(lp) || is.null(ln)) return(list(rows = NULL, why = "no state level"))
  # An error drops the pair from the fit; it is LOGGED (message, not warning: R defers
  # warnings to the end of a run), never swallowed.
  r <- tryCatch(candidate_returns(pr$prev, pr$election, corpus = C), error = function(e) {
    message(sprintf("DRT1! pair %s -> %s DROPPED from the departed-rate fit: candidate_returns() failed: %s",
                    pr$prev, pr$election, conditionMessage(e)))
    NULL })
  if (is.null(r) || !"prior_leader_returns" %in% names(r)) return(list(rows = NULL, why = "no returns table"))
  region <- sub("[0-9]+$", "", pr$election)
  pm <- NULL; permit_failed <- FALSE
  utils::capture.output(pm <- tryCatch(permit_fn(pr$election, pr$prev, region), error = function(e) {
    permit_failed <<- TRUE
    message(sprintf("DRT1! pair %s -> %s DROPPED from the departed-rate fit: salience screen failed: %s",
                    pr$prev, pr$election, conditionMessage(e)))
    NULL }))
  if (is.null(pm)) return(list(rows = NULL, why = if (permit_failed) "screen error" else "no screen"))
  # masks computed OUTSIDE `[`, on differently-named locals (data.table NSE)
  want_cls <- cls
  r_idx <- which(r$party == want_cls)
  rr <- r[r_idx]
  p_idx <- which(pm$party == want_cls)
  lut <- stats::setNames(as.logical(pm$permit[p_idx]), pm$seat[p_idx])
  permitted <- unname(lut[rr$seat]) %in% TRUE
  departed  <- !is.na(rr$prior_leader_returns) & !rr$prior_leader_returns
  rr <- rr[which(departed & !permitted)]
  # Amendment 1 item 2 (Pete, 29 Oct): fit only on the cells the rate is APPLIED to. A seat the
  # successor table names for this earlier election takes its successor rate in
  # screened_slopes(), not departed_rate, so it is left out of the fit. Matched exactly on the
  # seat name, as screened_slopes() matches it. The table governs IND only.
  n_excl <- 0L
  if (!is.null(exclude_fn) && identical(want_cls, "IND") && nrow(rr)) {
    ex_failed <- FALSE
    ex <- tryCatch(exclude_fn(pr$election), error = function(e) {
      ex_failed <<- TRUE
      message(sprintf("DRT1! pair %s -> %s DROPPED from the departed-rate fit: successor table unreadable: %s",
                      pr$prev, pr$election, conditionMessage(e)))
      NULL })
    if (ex_failed) return(list(rows = NULL, why = "successor table error", n_excluded = 0L))
    hit <- rr$seat %in% as.character(ex)
    n_excl <- sum(hit)
    rr <- rr[which(!hit)]
  }
  if (!nrow(rr)) return(list(rows = NULL, why = "no departed-branch rows", n_excluded = n_excl))
  NOWT <- C[C$election == pr$election]
  now_idx <- which(NOWT$party == want_cls)
  nowc <- NOWT[now_idx, list(actual_now = sum(pcv, na.rm = TRUE)), by = list(seat, party)]
  P <- data.table::copy(C[C$election == pr$prev])[, .s := normalise_seat(seat)]
  prev_idx <- which(P$party == want_cls)
  prevc <- P[prev_idx, list(x = sum(pcv, na.rm = TRUE)), by = list(.s, party)]
  m <- merge(rr[, list(seat, party)], nowc, by = c("seat", "party"))
  m[, .s := normalise_seat(seat)]
  m <- merge(m, prevc, by = c(".s", "party"))
  m <- merge(m, lp[, list(party, level_prev = level)], by = "party")
  m <- merge(m, ln[, list(party, level_now  = level)], by = "party")
  m[, pair := pr$election]
  m <- m[which(m$x > 0)]
  m[, dev := x - level_prev]; m[, yy := actual_now - level_now]
  list(rows = m, why = if (nrow(m)) "ok" else "no rows with a prior base", n_excluded = n_excl)
}

# The seats the successor table names for one election (they take their own rate, so the
# departed-rate fit leaves them out). character(0) when AUSPOL_DEPARTED_SUCCESSOR is off;
# departed_successor_rates() errors when the switch is on and the election has no rows.
.dr_successor_seats <- function(election) {
  r <- departed_successor_rates(election)
  if (is.null(r)) character(0) else names(r)
}

# One election's slope through the origin and its variance: the LARGER of the ordinary
# regression variance and a leave-one-seat-out jackknife (the same "larger of two" guard as
# .shrunk_slope()), so a 1-row election has a huge variance and almost no weight.
.dr_election_slope <- function(dev, yy) {
  ok <- is.finite(dev) & is.finite(yy)
  dev <- dev[ok]; yy <- yy[ok]; n <- length(dev)
  sxx <- sum(dev^2)
  if (n < 1L || !isTRUE(sxx > 0)) return(list(b = NA_real_, se2 = NA_real_, n = n))
  b <- sum(dev * yy) / sxx
  if (n < 2L) return(list(b = b, se2 = .DR_BIG_SE2, n = n))
  e <- yy - b * dev
  se2_ols <- (sum(e^2) / max(1, n - 1L)) / sxx
  b_i <- (sum(dev * yy) - dev * yy) / (sxx - dev^2)
  b_i <- b_i[is.finite(b_i)]
  se2_jk <- if (length(b_i) >= 2L) (length(b_i) - 1L) / length(b_i) * sum((b_i - mean(b_i))^2) else 0
  se2 <- max(se2_ols, se2_jk)
  if (!is.finite(se2)) se2 <- .DR_BIG_SE2
  # floor: an exact through-the-origin fit has regression variance 0 (and a jackknife of ~0),
  # which would be infinite weight in 1 / se2
  se2 <- max(se2, .DR_SE2_FLOOR)
  list(b = b, se2 = se2, n = n)
}

#' Partial-pooling estimate of a mean from per-group estimates (DerSimonian-Laird)
#'
#' @param b,se2 Per-group estimate and its variance (same length, finite).
#' @param tau2_floor Floor for the between-group variance.
#' @return list(mu, tau2, b_shrunk, w): pooled mean, between-group variance, each
#'   group's shrunk value `mu + tau2 / (tau2 + se2) * (b - mu)`, and the weights.
#' @keywords internal
dl_pool <- function(b, se2, tau2_floor = .DR_TAU2_FLOOR) {
  G <- length(b)
  w_fe <- 1 / se2
  mu_fe <- sum(w_fe * b) / sum(w_fe)
  Q <- sum(w_fe * (b - mu_fe)^2)
  Cc <- sum(w_fe) - sum(w_fe^2) / sum(w_fe)
  if (!all(is.finite(b)) || !all(is.finite(se2)) || any(se2 <= 0))
    stop("dl_pool(): estimates must be finite with positive variances", call. = FALSE)
  tau2 <- if (G > 1L && isTRUE(Cc > 0)) max(tau2_floor, (Q - (G - 1L)) / Cc) else tau2_floor
  w <- 1 / (tau2 + se2)
  mu <- sum(w * b) / sum(w)
  list(mu = mu, tau2 = tau2, b_shrunk = mu + tau2 / (tau2 + se2) * (b - mu), w = w)
}

#' Fit the departed-leader retention rate, strictly time-forward, by partial pooling
#'
#' `screened_slopes()` decays a departed class leader's base toward `departed_rate`
#' (hardcoded `c(IND = 0.38)`, an unfitted in-sample constant: see
#' docs/plans/prereg-departed-rate-refit-2026-10-03.md section 1). This fits it the way
#' [fit_major_departed_slope()] fits the major-party tier -- `actual - level_now` on
#' `prior - level_prev` through the origin -- on exactly the rows that take the departed
#' branch (`prior_leader_returns` FALSE, screen does not permit, class stood this time),
#' but ONLY from elections dated strictly before `target_election` ([fit_pairs_for()]).
#'
#' Per earlier election: slope and variance (larger of the regression and a
#' leave-one-seat-out jackknife variance). Between-election variance by
#' DerSimonian-Laird (floored at 0.01^2), pooled mean `mu`, and the target uses `mu`
#' clipped to [0, 1] (after a finiteness check: a non-finite pooled rate is an error).
#' Per-election variances are floored at 1e-6 so an exact-fit election cannot get infinite
#' weight. Only elections with at least 2 departed rows are informative: fewer than 3
#' informative earlier elections returns `fallback` instead (default: the CONTROL value,
#' `screened_slopes()`'s hardcoded 0.38; addendum 2026-10-04 item 3), and `fallback_reason`
#' says "fallback to control (n informative elections = k)". One-row elections may still
#' enter the pool but cannot satisfy the floor. No `min_n` cliff above that floor.
#'
#' Needs `AUSPOL_TIME_FORWARD_FITS` not `"0"`: under `"0"` the fit would be leave-one-out
#' and read later elections, so this stops rather than leak.
#'
#' @param target_election Election being forecast; only earlier ones are used.
#' @param corpus,pairs As in [fit_major_departed_slope()].
#' @param cls Party class, default `"IND"`.
#' @param permit_fn `function(election, prev_election, region)` returning
#'   `seat, party, permit` or `NULL`; default [salience_permit_for()].
#' @param fallback Rate to return when under-supported; `NULL` is the control value.
#' @param min_elections Minimum earlier INFORMATIVE elections (>= 2 departed rows each).
#' @param pool_fn Pooling function, [dl_pool()]; injectable for tests.
#' @param exclude_fn `function(election)` returning the seats whose IND cell is governed by
#'   another rate at that election and so is left out of the fit (prereg
#'   `docs/plans/prereg-departed-rate-screen-2026-10-25.md` Amendment 1 item 2). Default: the
#'   seats [departed_successor_rates()] names (none when `AUSPOL_DEPARTED_SUCCESSOR` is off).
#'   An error drops that pair from the fit with a `DRT1!` message. `NULL` excludes nothing.
#' @return list(rate, fallback_used, fallback_reason, mu, tau2, G, n, elections,
#'   per_election, rows). `rate` is a length-1 numeric named `cls`.
#' @export
fit_departed_rate <- function(target_election, corpus = NULL, pairs = NULL, cls = "IND",
                              permit_fn = NULL, fallback = NULL,
                              min_elections = .DR_MIN_ELECTIONS, pool_fn = dl_pool,
                              exclude_fn = .dr_successor_seats) {
  if (identical(Sys.getenv("AUSPOL_TIME_FORWARD_FITS", "1"), "0"))
    stop("fit_departed_rate() is time-forward only; AUSPOL_TIME_FORWARD_FITS=0 would read later elections", call. = FALSE)
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) stop("fit_departed_rate() needs output/candidacies.csv", call. = FALSE)
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  if (is.null(permit_fn)) permit_fn <- function(election, prev_election, region) salience_permit_for(election, prev_election, region)
  pairs_in <- if (is.null(pairs)) all_election_pairs() else pairs
  pairs_tf <- fit_pairs_for(target_election, pairs_in)   # strictly earlier elections only
  got <- lapply(pairs_tf, function(pr) .dr_pair_rows(pr, C, cls, permit_fn, exclude_fn))
  rows <- data.table::rbindlist(lapply(got, `[[`, "rows"), fill = TRUE)
  n_screened <- sum(vapply(got, function(g) !g$why %in% c("no screen", "screen error"), logical(1)))
  n_dropped <- sum(vapply(got, function(g) g$why %in% c("no returns table", "screen error", "successor table error"), logical(1)))
  n_excluded <- sum(vapply(got, function(g) if (is.null(g$n_excluded)) 0L else as.integer(g$n_excluded), integer(1)))
  per <- data.table::data.table(election = character(), n = integer(), b = numeric(), se2 = numeric())
  if (nrow(rows)) {
    for (g in unique(rows$pair)) {
      sel <- which(rows$pair == g)
      es <- .dr_election_slope(rows$dev[sel], rows$yy[sel])
      if (is.finite(es$b) && is.finite(es$se2))
        per <- rbind(per, data.table::data.table(election = g, n = es$n, b = es$b, se2 = es$se2))
    }
  }
  G <- nrow(per)
  # Only elections with >= 2 departed rows are informative (addendum item 1): a one-row
  # election may sit in the pool (huge variance, ~zero weight) but cannot satisfy the floor.
  G_inf <- sum(per$n >= .DR_MIN_ROWS)
  base <- list(G = G, G_informative = G_inf, n = if (nrow(rows)) nrow(rows) else 0L, elections = per$election,
               per_election = per, rows = rows, n_pairs = length(pairs_tf), n_screened = n_screened,
               n_dropped = n_dropped, n_excluded = n_excluded)
  if (G_inf < min_elections) {
    # Fallback is the CONTROL value (arm A), not the run's `new` slope: that is
    # fit_conditional_slopes()$new, which returns 1.0 under AUSPOL_SHIP_TIME_FORWARD=1
    # for thin early targets, worse than 0.38 (addendum item 3).
    fb <- fallback
    if (is.null(fb)) fb <- control_rate(cls)
    return(c(list(rate = stats::setNames(fb, cls), fallback_used = TRUE,
                  fallback_reason = sprintf("fallback to control (n informative elections = %d)", G_inf),
                  mu = NA_real_, tau2 = NA_real_), base))
  }
  pl <- pool_fn(per$b, per$se2)
  # A non-finite pooled value is a failure, not a rate; clamp to [0, 1] only after this check.
  if (length(pl$mu) != 1L || !is.finite(pl$mu) || !is.finite(pl$tau2))
    stop(sprintf("fit_departed_rate(%s): pooled rate is not finite (mu = %s, tau2 = %s) from %d election(s)",
                 target_election, format(pl$mu), format(pl$tau2), G), call. = FALSE)
  per[, b_shrunk := pl$b_shrunk]
  base$per_election <- per
  c(list(rate = stats::setNames(max(0, min(1, pl$mu)), cls), fallback_used = FALSE,
         fallback_reason = NA_character_, mu = pl$mu, tau2 = pl$tau2), base)
}

# The control value of the switch: screened_slopes()'s own default departed_rate for `cls`.
# formals() hands back the unevaluated call c(IND = 0.38); eval() of that constant default.
control_rate <- function(cls = "IND") {
  d <- eval(formals(screened_slopes)$departed_rate)
  if (!cls %in% names(d)) stop("screened_slopes() has no default departed_rate for class ", cls, call. = FALSE)
  d[[cls]]
}

#' Apply the AUSPOL_DEPARTED_RATE switch for one target election
#'
#' Reads `AUSPOL_DEPARTED_RATE`: `"0"` (default) or unset returns `NULL` (the caller
#' keeps `screened_slopes()`'s own default, `c(IND = 0.38)`, byte-identically); `"fit"`
#' uses [fit_departed_rate()] (control value 0.38 when under 3 informative earlier
#' elections); `"new"` uses `fit_conditional_slopes()$new` for IND alone (arm D), with its own
#' fallback behaviour stated on the DRT0 line. A non-finite rate is never returned.
#' `"fit_juris"` and `"fit_all"` are registered arms that are NOT implemented yet: they
#' are a loud failure, never a silent no-op. Always prints one `DRT0` line saying what was
#' applied (value, rows, elections, tau, which fallback fired, elections used) so a run
#' can not read as "this does not matter" when the switch did not apply. Any failure
#' prints `BF0d!` and returns `NULL` (default rate kept).
#'
#' @param target_election Election being forecast.
#' @param mode Value of the switch.
#' @param corpus,pairs,permit_fn,fallback As in [fit_departed_rate()].
#' @param active `FALSE` when `screened_slopes()` cannot reach its departed branch in
#'   this run; nothing is fitted and a line says so.
#' @return `NULL` (use the default) or a named numeric vector for `departed_rate`.
#' @export
departed_rate_for_harness <- function(target_election, mode = Sys.getenv("AUSPOL_DEPARTED_RATE", "0"),
                                      corpus = NULL, pairs = NULL, permit_fn = NULL, fallback = NULL,
                                      active = TRUE) {
  if (!isTRUE(active)) {
    # the departed branch cannot run (not screened mode, honour_departed off, or no screen for
    # this pair), so the rate is never read; say so rather than fit a number nothing uses
    cat(sprintf("DRT0 %s departed branch not active (screened mode / AUSPOL_HONOUR_DEPARTED / screen absent): rate unused, switch=%s\n",
                target_election, mode))
    return(NULL)
  }
  if (mode %in% c("0", "")) {
    cat(sprintf("DRT0 %s IND rate %.2f [arm 0: shipped constant, switch off]\n", target_election,
                eval(formals(screened_slopes)$departed_rate)[["IND"]]))
    return(NULL)
  }
  out <- tryCatch({
    if (!mode %in% c("fit", "new"))
      stop(sprintf("AUSPOL_DEPARTED_RATE=%s is not implemented (modes: 0, fit, new)", mode), call. = FALSE)
    if (identical(mode, "new")) {
      # arm D: no departed-specific fit at all; whatever the code computes for the class's
      # time-forward `new` slope. State plainly what that is: under AUSPOL_SHIP_TIME_FORWARD=1
      # fit_conditional_slopes() returns 1.0 (no decay) when the pooled new tier has < 40 rows.
      src <- if (is.null(fallback)) "fit_conditional_slopes()$new[[IND]], time-forward (1.0 = pooled new tier under 40 rows, SHIP_TIME_FORWARD fallback)" else "supplied value"
      fb <- if (is.null(fallback)) fit_conditional_slopes(target_election, corpus = corpus, pairs = pairs)$new[["IND"]] else fallback
      rate <- stats::setNames(fb, "IND")
      if (length(rate) != 1L || !is.finite(rate[["IND"]]))
        stop(sprintf("arm new produced a non-finite rate (%s)", format(rate)), call. = FALSE)
      cat(sprintf("DRT0 %s IND rate %.4f [arm new: NOT a departed-specific fit; own fallback behaviour: rate = %s]\n",
                  target_election, rate[["IND"]], src))
      return(rate)
    }
    f <- fit_departed_rate(target_election, corpus = corpus, pairs = pairs, permit_fn = permit_fn, fallback = fallback)
    # never hand a non-finite value to screened_slopes()
    if (length(f$rate) != 1L || !is.finite(f$rate[["IND"]]))
      stop(sprintf("departed rate is not finite (%s)", format(f$rate)), call. = FALSE)
    cat(sprintf("DRT0 %s IND rate %.4f (%d rows, %d elections of which %d informative, tau2 %s, mu %s, screened %d of %d earlier pairs, %d dropped on error, %d successor-named cells left out) [arm %s%s] elections used: %s\n",
                target_election, f$rate[["IND"]], f$n, f$G, f$G_informative,
                if (is.finite(f$tau2)) sprintf("%.4f", f$tau2) else "NA",
                if (is.finite(f$mu)) sprintf("%.4f", f$mu) else "NA", f$n_screened, f$n_pairs, f$n_dropped, f$n_excluded, mode,
                if (isTRUE(f$fallback_used)) sprintf("; %s", f$fallback_reason) else "",
                if (length(f$elections)) paste(f$elections, collapse = ",") else "none"))
    f$rate
  }, error = function(e) {
    cat(sprintf("BF0d! departed-rate arm %s FAILED for %s, default rate kept: %s\n", mode, target_election, conditionMessage(e)))
    NULL
  })
  out
}
