# Preference distribution ---------------------------------------------------
#
# A two-party model needs one number per party: the share of its preferences
# reaching Labor. Deciding a SEAT needs more, because who a party's preferences
# go to depends on who is still standing -- Liberal preferences split
# differently against Labor-versus-Greens than against Labor-versus-One Nation.
# Measured from the 2026 South Australian count, that difference is tens of
# points, so a single scalar cannot express it.
#
# This distributes preferences the way a count actually runs: exclude the
# lowest, transfer its votes at estimated rates, repeat until two remain.
#
# The hazard this file exists to avoid: a flow table is SPARSE. When no
# observed rate exists for the exact set of survivors, the obvious fallback --
# take that party's pooled row and renormalise over whoever is left -- is
# actively dangerous, because a pooled row carries 0% for destinations that
# never co-occurred. Renormalising then assigns 100% of the transfer to
# whichever party happens to have mass. That is not a hypothetical: it gave
# One Nation every Labor ballot in seats where Labor was excluded with the
# Greens standing, and produced One Nation winning Richmond.
#
# So absence of evidence is never treated as certainty of zero. Every row is
# mixed with a uniform distribution over the survivors.

#' Distribute preferences to a final two
#'
#' @param shares Named numeric vector of first-preference shares. Names are
#'   party classes; zero or negative entries are dropped.
#' @param conditional Named list of flow rows keyed `"FROM|A+B+C"`, where the
#'   key's tail is the sorted survivor set. Each element is a named numeric
#'   vector of destination shares (any scale; renormalised on use).
#' @param pooled Named list of flow rows keyed by excluded party, used when no
#'   conditional row matches.
#' @param smooth Weight given to a uniform distribution over the survivors,
#'   in `[0, 1)`. **Do not set this to zero** without reading the note above:
#'   it is what stops an unobserved destination being treated as impossible.
#' @return List: `winner`, `final_two`, `final_shares` (the two-candidate-
#'   preferred count for those two, in the units `shares` was given in),
#'   `order` (exclusion order), and `fallbacks` (how many transfers had no
#'   conditional row).
#' @export
distribute_preferences <- function(shares, conditional = list(),
                                   pooled = list(), smooth = 0.15) {
  # This receives only the conditional LIST, so it cannot see the matrix's
  # multiplicity stamp. It checks the key shape instead: a survivor label
  # ending in a digit is a multiplicity key ("LNP2"), which the lookup below
  # would never match -- every cell missed, no error, pooled rates used
  # throughout. Refused rather than silently ignored.
  if (length(conditional)) {
    sv <- unlist(strsplit(sub("^[^|]*[|]", "", names(conditional)), "+", fixed = TRUE))
    if (any(grepl("[0-9]$", sv))) {
      stop("Conditional flow keys carry a survivor multiplicity (e.g. ",
           "\"LNP2\"), which this function cannot match. Build the matrix ",
           "with multiplicity = FALSE.")
    }
  }
  stopifnot(is.numeric(shares), !is.null(names(shares)),
            smooth >= 0, smooth < 1)
  # Names must be unique. Exclusion removes BY NAME, so two entries sharing one
  # -- two independents both bucketed as "IND", say -- are deleted together
  # while only the smaller one's votes are redistributed. The rest vanish and
  # the count silently runs a round short. Refused rather than quietly summed,
  # because a caller that produced duplicates has a bug worth seeing.
  dup <- unique(names(shares)[duplicated(names(shares))])
  if (length(dup)) {
    stop("shares has duplicate name(s): ", paste(dup, collapse = ", "),
         ". Aggregate to one entry per party before distributing.")
  }
  v <- shares[which(shares > 0)]
  if (!length(v)) stop("No candidate has a positive share")
  excluded <- character(0)
  fallbacks <- 0L

  while (length(v) > 2L) {
    # `which.min` on a named vector returns a position; take the NAME, since
    # the vector is reordered as parties are removed.
    from <- names(v)[which.min(v)]
    pot <- v[[from]]
    v <- v[setdiff(names(v), from)]
    surv <- names(v)

    key <- paste0(from, "|", paste(sort(surv), collapse = "+"))
    row <- conditional[[key]]
    if (is.null(row)) {
      row <- pooled[[from]]
      fallbacks <- fallbacks + 1L
    }
    w <- if (is.null(row)) {
      stats::setNames(rep(0, length(surv)), surv)
    } else {
      r <- row[intersect(names(row), surv)]
      out <- stats::setNames(rep(0, length(surv)), surv)
      if (length(r)) out[names(r)] <- pmax(0, r)
      out
    }
    tot <- sum(w)
    unif <- 1 / length(surv)
    p <- if (tot <= 0) {
      stats::setNames(rep(unif, length(surv)), surv)
    } else {
      (1 - smooth) * (w / tot) + smooth * unif
    }
    v[surv] <- v[surv] + pot * p[surv]
    excluded <- c(excluded, from)
  }

  # `final_shares` is the two-candidate-preferred count -- the number every
  # commission and every other forecaster publishes as "the two-party result in
  # this seat", and which this package could not previously state at all. It is
  # returned in the SAME UNITS the caller passed in, so shares given as
  # percentages come back as percentages of the formal vote. The pair sums to
  # the original total, since exclusion moves votes without destroying them.
  list(winner = names(v)[which.max(v)],
       final_two = names(v),
       final_shares = v,
       order = excluded,
       fallbacks = fallbacks)
}
