# Preference flow matrices ---------------------------------------------------
#
# [distribute_preferences()] needs a table of transfer rates keyed on the
# excluded party AND the set of survivors. This builds one from observed
# counts: for every exclusion in a real election, where did that candidate's
# ballots actually go?
#
# The input is deliberately plain -- one row per (election, seat, round,
# excluded party, destination party, votes) -- so that any source that can be
# reduced to "these votes moved from here to there" can feed it, whether the
# origin was a VEC HTML table or an ECSA JSON endpoint.
#
# Cells are NOT filled in where nothing was observed. A count is returned with
# every row so a caller can see which rates rest on two exclusions and which
# rest on fifty, rather than being handed a table that looks uniformly
# authoritative.

#' Build a preference flow matrix from observed transfers
#'
#' @param transfers data.frame with columns `seat`, `round`, `from` (excluded
#'   party), `to` (receiving party), `votes`, and optionally `election`.
#' @param multiplicity Condition each cell on how many CANDIDATES of a class
#'   survived the round, not merely on which classes did. Requires a `to_n`
#'   column giving that count. Default `FALSE` reproduces the previous key
#'   exactly, which is refusal M1 of `docs/plans/prereg-survivor-multiplicity.md`.
#'
#'   Why it might matter: our classes are deliberately coarse, and `OTH_RIGHT`,
#'   `OTH` and `IND` are buckets. A seat with three minor-right candidates gives
#'   `OTH_RIGHT` a multiplicity of three and keys identically to a seat with one,
#'   so the bucket collects three candidates' worth of preferences and the matrix
#'   reads that as the bucket being popular. Measured at 44.5% of Victorian
#'   exclusion rounds -- see `reviews/gate1-survivor-multiplicity-2026-08-22.md`.
#' @param min_n Minimum number of distinct exclusion events for a
#'   survivor-conditional cell to be reported in `conditional`. Cells below
#'   this are still counted in `coverage` but withheld, so a caller falls back
#'   to the pooled rate rather than trusting a rate built from one seat.
#' @return List with `conditional` (named list keyed `"FROM|A+B+C"`), `pooled`
#'   (named list keyed by excluded party), and `coverage`, a data.frame of
#'   every cell with its event count and total votes — including the withheld
#'   ones, which is the point.
#' @export
build_flow_matrix <- function(transfers, min_n = 3L, multiplicity = FALSE) {
  need <- c("seat", "round", "from", "to", "votes")
  miss <- setdiff(need, names(transfers))
  if (length(miss)) {
    stop("transfers is missing column(s): ", paste(miss, collapse = ", "))
  }
  d <- data.table::as.data.table(transfers)
  if (!"election" %in% names(d)) d[, "election" := "unknown"]
  d <- d[which(is.finite(d$votes) & d$votes > 0), ]
  if (!nrow(d)) stop("No positive transfers to build a matrix from")

  # An exclusion EVENT is one (election, seat, round). The survivor set is
  # every party that received votes in it -- which is why a party receiving
  # zero in a round is indistinguishable here from one not standing, and why
  # smoothing in distribute_preferences() is not optional.
  if (multiplicity) {
    if (!"to_n" %in% names(d)) {
      stop("multiplicity = TRUE needs a `to_n` column: the number of candidates ",
           "of each class that received votes in that round. Re-run the ",
           "fetchers, which emit it. Without it this would silently fall back ",
           "to the class-set key and be indistinguishable from the control.")
    }
    if (anyNA(d$to_n) || any(d$to_n < 1L)) {
      stop("`to_n` has missing or non-positive values, so some rounds would be ",
           "keyed on a multiplicity that was never counted.")
    }
    # One entry per surviving class, carrying its candidate count: "ALP1+LNP2".
    d[, "surv_key" := paste0(get("to"), get("to_n"))]
  } else {
    d[, "surv_key" := get("to")]
  }
  ev <- d[, list(surv = paste(sort(unique(get("surv_key"))), collapse = "+")),
          by = c("election", "seat", "round", "from")]
  d <- merge(d, ev, by = c("election", "seat", "round", "from"))
  d[, "cell" := paste0(get("from"), "|", get("surv"))]

  cell_tot <- d[, list(votes = sum(get("votes"))),
                by = c("cell", "from", "surv", "to")]
  cell_n <- d[, list(n = data.table::uniqueN(
                paste(get("election"), get("seat"), get("round")))),
              by = c("cell", "from", "surv")]
  cell_tot <- merge(cell_tot, cell_n, by = c("cell", "from", "surv"))
  cell_tot[, "share" := 100 * get("votes") / sum(get("votes")), by = "cell"]

  mk <- function(dt, keycol) {
    keys <- unique(dt[[keycol]])
    stats::setNames(lapply(keys, function(k) {
      s <- dt[dt[[keycol]] == k, ]
      stats::setNames(s$share, s$to)
    }), keys)
  }
  conditional <- mk(cell_tot[cell_tot$n >= min_n, ], "cell")

  pool <- d[, list(votes = sum(get("votes"))), by = c("from", "to")]
  pool[, "share" := 100 * get("votes") / sum(get("votes")), by = "from"]
  pooled <- mk(pool, "from")

  # AVAILABILITY-CONDITIONED BACKOFF, between the exact cell and the pooled
  # row. Cells key on the EXACT survivor set, so they fragment and most never
  # reach min_n; the consumer then falls back to `pooled` and renormalises it
  # over whoever is actually alive. That is the renormalisation trap
  # CLAUDE.md records, and it is not a small error:
  #
  #   LNP excluded, ALP and IND both surviving
  #     pooled row renormalised over {ALP, IND} :  IND 22.2%   ALP 77.8%
  #     what actually happened (39 rounds, 18 seat-elections)
  #                                             :  IND 69.9%   ALP 26.3%
  #
  # Backwards by three times, on the transfer that decides Fowler, Mayo,
  # Clark, Indi, Bean, Calwell, Franklin, Fremantle, Watson and Kennedy. The
  # pooled row is diluted by every round where no independent was available
  # to receive anything, so renormalising it onto a contest that HAS one
  # asserts a rate measured on a different contest.
  #
  # `pairwise[[from]][[to]]` is instead the share of `from`'s votes going to
  # `to` among only those rounds where `to` was actually a survivor. Shares
  # across destinations do not sum to 100 (each has its own denominator), so
  # a consumer renormalises over the alive set -- which is now legitimate,
  # because every rate in it was measured on rounds where that destination
  # could receive.
  avail <- d[, list(votes = sum(get("votes")),
                    denom = sum(get("votes"))), by = c("from", "to")]
  rd <- unique(d[, c("election", "seat", "round", "from", "surv"), with = FALSE])
  tot_round <- d[, list(rv = sum(get("votes"))),
                 by = c("election", "seat", "round", "from")]
  rd <- merge(rd, tot_round, by = c("election", "seat", "round", "from"))
  classes <- unique(d$to)
  pw <- data.table::rbindlist(lapply(classes, function(cl) {
    hit <- rd[vapply(strsplit(rd$surv, "+", fixed = TRUE),
                     function(z) cl %in% sub("[0-9]+$", "", z), logical(1))]
    if (!nrow(hit)) return(NULL)
    got <- merge(d[d$to == cl, ], hit[, c("election", "seat", "round", "from"), with = FALSE],
                 by = c("election", "seat", "round", "from"))
    if (!nrow(got)) return(NULL)
    data.table::data.table(
      from = got[, list(v = sum(get("votes"))), by = "from"]$from,
      to = cl,
      share = 100 * got[, list(v = sum(get("votes"))), by = "from"]$v /
        hit[, list(rv = sum(get("rv"))), by = "from"][
          match(got[, list(v = sum(get("votes"))), by = "from"]$from,
                hit[, list(rv = sum(get("rv"))), by = "from"]$from)]$rv)
  }), fill = TRUE)
  pairwise <- if (is.null(pw) || !nrow(pw)) list() else
    stats::setNames(lapply(unique(pw$from), function(f) {
      s <- pw[pw$from == f, ]
      stats::setNames(s$share, s$to)
    }), unique(pw$from))

  coverage <- unique(cell_tot[, c("cell", "from", "surv", "n"), with = FALSE])
  cov_votes <- cell_tot[, list(votes = sum(get("votes"))), by = "cell"]
  coverage <- merge(coverage, cov_votes, by = "cell")
  coverage[, "used" := get("n") >= min_n]
  data.table::setorderv(coverage, "votes", -1L)

  # STAMPED, so a consumer can refuse a matrix it cannot read rather than
  # silently skipping every cell in it. See simulate_seat_contests().
  list(conditional = conditional, pooled = pooled, pairwise = pairwise,
       coverage = as.data.frame(coverage), min_n = min_n,
       multiplicity = multiplicity)
}
