#' One Nation in seats with no state history: the shared rule
#'
#' `AUSPOL_ONP_NEWSEAT_RULE` (default `"1"`, the rule, shipped 2026-10-26;
#' `"0"` the old behaviour, which stage 1 of rebuild_forecasts.sh pins). docs/plans/prereg-onp-newseat-rule-2026-10-25.md,
#' docs/reviews/onp-newseat-parity-2026-10-25.md.
#'
#' The live Victorian forecast has no One Nation state history to swing (0.28%
#' statewide, 4 seats, in 2022), so it allocates One Nation's statewide level
#' across EVERY seat by rank on the most recent earlier federal One Nation vote
#' in each seat's booths, spread by South Australia 2026's quantile shape forced
#' to `AUSPOL_ONP_CV`. The backtest harnesses mostly start each seat from One
#' Nation's own previous state result instead, and in a seat where One Nation
#' did not stand last time that is a uniform swing off zero: every such seat
#' gets the same number. So the method the Victorian forecast depends on is
#' barely tested. This file is that method as one set of functions:
#'
#' * [onp_rank_ratio()] and [onp_cv_force()] are the live allocation's two
#'   steps, extracted from `scripts/fit_seats_full.R` unchanged (that script
#'   now calls them at every setting, so live and backtests share the code).
#' * [onp_federal_key()] is the ordering key: the federal HOUSE One Nation vote
#'   (`AUSPOL_ONP_ORDER=federal`) or SENATE vote (`senate_rank`) of the most
#'   recent federal election dated strictly before the target.
#' * [onp_newseat_cv()] is the spread for a backtest target, fitted only on
#'   elections dated before it.
#' * [onp_newseat_prepare()] and [onp_newseat_apply()] are what each harness
#'   calls.
#' @name onp_newseat
NULL

#' Read `AUSPOL_ONP_NEWSEAT_RULE`
#'
#' @return `TRUE` for `"1"`, `FALSE` for `"0"`; any other value is an error (a
#'   typo must not run as the default and read as "no effect").
#' @export
onp_newseat_rule <- function() {
  v <- Sys.getenv("AUSPOL_ONP_NEWSEAT_RULE", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_ONP_NEWSEAT_RULE must be \"0\" or \"1\", got \"", v, "\"", call. = FALSE)
  identical(v, "1")
}

#' Hand a sorted shape out by rank (the live allocation's quantile map)
#'
#' The seat at rank `r` of `ord` gets the value at quantile `(r-1)/(n-1)` of
#' `shape`, linearly interpolated. With `length(shape) == length(ord)` each
#' seat gets `shape[r]` exactly. Extracted verbatim from
#' `scripts/fit_seats_full.R` stage 4, so the live forecast is unchanged.
#'
#' @param ord Integer permutation: `ord[1]` is the lowest-ranked seat.
#' @param shape Sorted numeric vector (ratios to the mean).
#' @param seats Seat names, in the row order `ord` indexes.
#' @return Named numeric vector over `seats`.
#' @export
onp_rank_ratio <- function(ord, shape, seats) {
  if (length(ord) != length(seats)) stop("onp_rank_ratio: ord and seats differ in length")
  if (is.unsorted(shape)) stop("onp_rank_ratio: shape must be sorted")
  out <- numeric(length(seats)); names(out) <- seats
  for (r in seq_along(ord)) {
    q <- (r - 1) / (length(ord) - 1)
    pos <- q * (length(shape) - 1)
    lo <- floor(pos) + 1; hi <- min(lo + 1, length(shape))
    out[seats[ord[r]]] <- shape[lo] + (pos - (lo - 1)) * (shape[hi] - shape[lo])
  }
  out
}

#' Rescale ratios about 1 to a target coefficient of variation
#'
#' `pmax(1 + (cv / cur) * (ratio - 1), 0.02)` with `cur` the current CV:
#' the live `AUSPOL_ONP_CV` step, extracted verbatim. Vector first in `pmax()`
#' so the names survive (the live allocation is then looked up by seat name).
#'
#' @param ratio Named numeric vector.
#' @param cv Target CV, finite and positive.
#' @return The rescaled vector, names kept.
#' @export
onp_cv_force <- function(ratio, cv) {
  if (!is.finite(cv) || cv <= 0) stop("onp_cv_force: cv must be finite and positive")
  cur <- stats::sd(ratio) / mean(ratio)
  pmax(1 + (cv / cur) * (ratio - 1), 0.02)
}

#' Federal One Nation vote by seat, for ordering, time-forward
#'
#' `order = "federal"`: the federal HOUSE One Nation share in each seat's
#' booths, from `external/elections/federal-transposed-to-state.csv` (the file
#' the live forecast ranks on) or, for an election it lacks, from
#' `output/house-onp-by-district.csv` (`scripts/build_onp_house.R`). A zero or
#' missing House share means One Nation did not stand there federally, which
#' carries no ordering information, so it is returned as `NA`.
#'
#' `order = "senate_rank"`: the federal SENATE One Nation share,
#' [onp_senate_key()] for a state target; for a federal target, the previous
#' federal election's Senate share by division
#' (`output/senate-by-division-class.csv`).
#'
#' A federal target has no House key: the previous House vote in a division IS
#' that division's own history, so a division with no history has none.
#'
#' Every source must be dated strictly before the target ([elections_before()]),
#' or this is an error, as in [onp_senate_key()].
#'
#' @param seats Seat names.
#' @param target Election label, e.g. `"qld2017"`.
#' @param order `"federal"` (House) or `"senate_rank"` (Senate).
#' @param lookup Names to look the seats up by (renames), same length as `seats`.
#' @param house,senate,division Optional tables (tests); read from disk when `NULL`.
#' @return Named numeric vector over `seats` (`NA` where there is no share)
#'   with attributes `fed` (year) and `source`; or, when the target has no
#'   table, an empty list whose attribute `why` says so (the caller prints it).
#' @export
onp_federal_key <- function(seats, target, order = c("federal", "senate_rank"), lookup = seats,
                            house = NULL, senate = NULL, division = NULL) {
  order <- match.arg(order)
  stopifnot(length(lookup) == length(seats))
  none <- function(why) structure(list(), why = why)
  rg <- sub("[0-9]{4}$", "", target)
  cy <- suppressWarnings(as.integer(sub("^[a-z]+", "", target)))
  guard <- function(fy, what) {
    if (!isTRUE(elections_before(paste0("fed", fy), target)))
      stop("onp_federal_key: the ", what, " table for ", target, " is from fed", fy,
           ", which is not before the target's polling day -- that would be leakage")
  }
  if (identical(rg, "fed")) {
    if (order == "federal")
      return(none("a federal target's House key is the division's own previous result, which a no-history division does not have"))
    if (is.null(division)) {
      f <- out_path("senate-by-division-class.csv")
      if (!file.exists(f)) return(none("output/senate-by-division-class.csv missing (scripts/build_senate_by_district.R)"))
      division <- data.table::fread(f, showProgress = FALSE)
    }
    division <- as.data.frame(division)   # data.table's `[` with drop = would not stay a table
    d <- division[division$cls == "ONP", , drop = FALSE]
    fys <- sort(unique(d$fed))
    fys <- fys[elections_before(paste0("fed", fys), target)]
    if (!length(fys)) return(none(sprintf("no federal Senate table dated before %s", target)))
    fy <- max(fys)
    guard(fy, "Senate division")
    d <- d[d$fed == fy, , drop = FALSE]
    k <- normalise_seat(d$division)
    if (anyDuplicated(k)) stop("onp_federal_key: duplicated divisions in the fed", fy, " Senate table")
    out <- stats::setNames(d$senate_pct[match(normalise_seat(lookup), k)], seats)
    attr(out, "fed") <- fy; attr(out, "source") <- sprintf("fed%d SENATE (by division)", fy)
    return(out)
  }
  if (order == "senate_rank") {
    k <- onp_senate_key(seats, target, lookup = lookup, senate = senate)
    if (is.null(k)) return(none(sprintf("no Senate One Nation table for %s", target)))
    attr(k, "source") <- sprintf("fed%d SENATE", attr(k, "fed"))
    return(k)
  }
  # House
  pick <- function(tab, fcol, dcol, vcol, src) {
    kk <- tab$region == rg & tab$cycle %in% cy
    if (!is.null(tab$party)) kk <- kk & tab$party == "ONP"
    if (!any(kk)) return(NULL)
    fy <- unique(tab[[fcol]][kk])
    if (length(fy) != 1L) stop("onp_federal_key: ", target, " has House rows from more than one federal election")
    guard(fy, "House")
    k <- normalise_seat(tab[[dcol]][kk])
    if (anyDuplicated(k)) stop("onp_federal_key: duplicated seats in the House table for ", target)
    v <- tab[[vcol]][kk][match(normalise_seat(lookup), k)]
    v[!is.na(v) & v <= 0] <- NA            # One Nation did not stand there federally: no ordering information
    out <- stats::setNames(v, seats)
    attr(out, "fed") <- fy; attr(out, "source") <- sprintf("fed%d HOUSE (%s)", fy, src)
    out
  }
  if (is.null(house)) {
    tf <- election_data_path("federal-transposed-to-state.csv")
    if (file.exists(tf)) {
      tr <- data.table::fread(tf, showProgress = FALSE)
      out <- pick(tr, "fed_election", "seat", "pct", "federal-transposed-to-state.csv")
      if (!is.null(out)) return(out)
    }
    hf <- out_path("house-onp-by-district.csv")
    if (!file.exists(hf)) return(none(sprintf("no House One Nation table for %s (federal-transposed-to-state.csv lacks it; output/house-onp-by-district.csv missing -- run scripts/build_onp_house.R)", target)))
    house <- data.table::fread(hf, showProgress = FALSE)
  }
  out <- pick(house, "fed", "district", "house_pct", "house-onp-by-district.csv")
  if (is.null(out)) return(none(sprintf("no House One Nation table for %s", target)))
  out
}

#' One Nation seat spread for a target, fitted only on earlier elections
#'
#' The seat SD of One Nation's vote rises with its level: `SD = a * level^k`,
#' k about 0.5 (`scripts/estimate_onp_concentration.R`). That script's table
#' (`output/onp-concentration-curve.csv`, read by the shipped South Australian
#' arm) is not usable here for two reasons: its rows are leave-one-out, so they
#' still train on LATER elections, and its SD is over every seat with zeros
#' where One Nation did not stand, which mixes the spread with where it chose
#' to stand. This rule allocates over seats One Nation contests, so the curve
#' is refitted on exactly that: for every election in `output/candidacies.csv`
#' dated STRICTLY before the target where One Nation contested at least
#' `min_seats` seats, the mean and SD of its share over those seats.
#'
#' `k` is partially pooled toward 0.5 with weight `df / (df + 3)`, `df = n - 2`,
#' so a thin history degrades to the prior instead of falling off a cliff; `a`
#' is then the mean of `log(sd) - k * log(level)`. The CV at `level` is
#' `a * level^(k - 1)`.
#'
#' @param target Election label.
#' @param level The mean One Nation share of the seats being allocated.
#' @param cand Optional candidacies table (`election`, `seat`, `party`, `pcv`).
#' @param k_prior,k_shrink,min_seats Prior exponent, shrinkage constant and
#'   fewest contested seats for an election to count (docs/CONSTANTS.md).
#' @return list(cv, a, k, n, sources), or `NULL` when no earlier election qualifies.
#' @export
onp_newseat_cv <- function(target, level, cand = NULL, k_prior = 0.5, k_shrink = 3, min_seats = 10L) {
  if (!is.finite(level) || level <= 0) return(NULL)
  if (is.null(cand)) {
    f <- out_path("candidacies.csv")
    if (!file.exists(f)) return(NULL)
    cand <- data.table::fread(f, showProgress = FALSE, select = c("election", "seat", "party", "pcv"))
  }
  cand <- data.table::as.data.table(cand)
  ko <- cand$party == "ONP" & is.finite(cand$pcv) & cand$pcv > 0
  o <- cand[ko, list(v = sum(pcv)), by = c("election", "seat")]
  s <- o[, list(n = .N, lvl = mean(v), sd = stats::sd(v)), by = "election"]
  ok <- s$n >= min_seats & s$election != target & elections_before(s$election, target) &
    is.finite(s$sd) & s$sd > 0
  if (!any(ok)) return(NULL)
  ls <- log(s$sd[ok]); lx <- log(s$lvl[ok]); n <- sum(ok)
  df <- max(0L, n - 2L)
  k_ols <- if (n >= 3L && stats::var(lx) > 0) unname(stats::coef(stats::lm(ls ~ lx))[2]) else k_prior
  w <- df / (df + k_shrink)
  k <- k_prior + w * (k_ols - k_prior)
  a <- exp(mean(ls - k * lx))
  list(cv = a * level^(k - 1), a = a, k = k, n = n, sources = s$election[ok])
}

#' Give a harness a One Nation column when One Nation is new to the state
#'
#' A harness whose seat matrix is built from the PREVIOUS election's results
#' has no One Nation column at all when One Nation did not stand then (sa2022,
#' nsw2019, vic2022), so One Nation is predicted 0 in every seat it contests.
#' Under the rule, a zero column is added (and a zero previous level) so the
#' harness's own swing gives those seats the statewide level and
#' [onp_newseat_apply()] can then allocate it. Called only when the rule is on.
#'
#' @param mat Seat x class matrix of the previous election.
#' @param prev_level Named previous statewide shares.
#' @param standing Seats where One Nation stands at the target (nomination data).
#' @param target Election label (for the message).
#' @param code Check code.
#' @return list(mat, prev_level, history): `history` is a named logical over
#'   `rownames(mat)`, TRUE where One Nation had a vote at the previous election.
#' @export
onp_newseat_prepare <- function(mat, prev_level, standing, target, code = "ONN1") {
  if ("ONP" %in% colnames(mat)) {
    h <- mat[, "ONP"] > 0
    names(h) <- rownames(mat)
    return(list(mat = mat, prev_level = prev_level, history = h))
  }
  h <- stats::setNames(rep(FALSE, nrow(mat)), rownames(mat))
  n_st <- sum(rownames(mat) %in% standing)
  if (!n_st) {
    cat(sprintf("%s  %s: One Nation stood neither last time nor now -- nothing to allocate\n", code, target))
    return(list(mat = mat, prev_level = prev_level, history = h))
  }
  mat <- cbind(mat, ONP = 0)
  prev_level[["ONP"]] <- 0
  cat(sprintf("%s  %s: One Nation had NO column (absent at the previous election); added at zero, stands in %d of %d seats\n",
              code, target, n_st, nrow(mat)))
  list(mat = mat, prev_level = prev_level, history = h)
}

#' Allocate One Nation across its no-history seats by federal rank
#'
#' Over the seats where One Nation had no vote at the previous state election
#' and has a positive share now, keep the MEAN of the harness's current One
#' Nation shares (the target level for those seats) and re-allocate it by rank
#' on [onp_federal_key()], spread to the time-forward CV of [onp_newseat_cv()]
#' with a normal-quantile shape (the shipped SA concentration arm's shape; the
#' live forecast uses South Australia 2026's quantiles, which no backtest
#' target on or before 2026-03 may see). Seats WITH history are not touched.
#'
#' `refill = "none"` sets only the One Nation cells, for a harness that
#' renormalises every row afterwards; `"prop"` makes the other classes in the
#' seat give or take the difference in proportion, for a harness whose rows
#' already sum to 100 at that point (NSW).
#'
#' @param shares Seat x class matrix with an `"ONP"` column.
#' @param target Election label.
#' @param history Named logical over seats: TRUE = One Nation stood there last time.
#' @param order `"federal"` or `"senate_rank"` (`AUSPOL_ONP_ORDER`).
#' @param lookup Names to look the federal key up by.
#' @param refill `"none"` or `"prop"`.
#' @param standing Optional seats where One Nation stands at the target
#'   (nomination data, the same proxy every harness's nomination zeroing uses);
#'   when given, only those seats are allocated, so the rank and the spread are
#'   over the seats One Nation actually contests. A seat counts as standing
#'   under either its own name or its `lookup` name (renames).
#' @param code Check code printed with the result.
#' @param key,cv Optional precomputed key (named over the no-history seats) and
#'   CV (tests); computed when `NULL`.
#' @return `shares`, changed or not; when applied, attribute `onp_newseat`
#'   (seats, fed, source, level, cv).
#' @export
onp_newseat_apply <- function(shares, target, history, order = Sys.getenv("AUSPOL_ONP_ORDER", "senate_rank"),
                              lookup = rownames(shares), refill = c("none", "prop"), standing = NULL, code = "ONN1",
                              key = NULL, cv = NULL) {
  refill <- match.arg(refill)
  if (length(lookup) != nrow(shares)) stop("onp_newseat_apply: lookup must have one name per row of shares")
  if (!order %in% c("federal", "senate_rank"))
    stop("AUSPOL_ONP_NEWSEAT_RULE=1 orders by the federal House (AUSPOL_ONP_ORDER=federal) or Senate (senate_rank) vote; got ",
         order, call. = FALSE)
  if (!"ONP" %in% colnames(shares)) { cat(sprintf("%s  %s: no One Nation column -- rule not applied (One Nation stands nowhere)\n", code, target)); return(shares) }
  if (anyDuplicated(rownames(shares))) stop("onp_newseat_apply: duplicated seat names")
  hist <- unname(history[rownames(shares)])
  if (anyNA(hist)) stop("onp_newseat_apply: no history flag for ", paste(utils::head(rownames(shares)[is.na(hist)], 5), collapse = ", "))
  st <- if (is.null(standing)) rep(TRUE, nrow(shares)) else rownames(shares) %in% standing | lookup %in% standing
  cand <- which(!hist & shares[, "ONP"] > 0 & st)
  n_hist <- sum(hist & shares[, "ONP"] > 0 & st)
  if (length(cand) < 3L) {
    cat(sprintf("%s  %s: %d seat(s) with no One Nation history and a positive share -- rule not applied (needs 3); %d with history keep their own path\n",
                code, target, length(cand), n_hist))
    return(shares)
  }
  if (is.null(key)) {
    key <- onp_federal_key(rownames(shares)[cand], target, order = order, lookup = lookup[cand])
  } else {
    ks <- attr(key, "source"); kf <- attr(key, "fed")
    key <- key[rownames(shares)[cand]]
    attr(key, "source") <- ks; attr(key, "fed") <- kf
  }
  if (is.list(key) && !length(key)) {
    cat(sprintf("%s! %s: %s -- rule NOT applied to %d no-history seat(s)\n", code, target, attr(key, "why"), length(cand)))
    return(shares)
  }
  # Subsetting drops attributes: keep the source and year now, or the ONN1 line below prints nothing
  # (sprintf with a NULL argument returns character(0), silently).
  k_src <- attr(key, "source"); k_fed <- attr(key, "fed")
  if (is.null(k_src)) k_src <- "given"
  miss <- is.na(key)
  if (mean(miss) > 0.1) {
    cat(sprintf("%s! %s: no %s One Nation share for %d of %d no-history seats (%s) -- rule NOT applied\n",
                code, target, if (order == "federal") "House" else "Senate", sum(miss), length(key),
                paste(utils::head(names(key)[miss], 5), collapse = ", ")))
    return(shares)
  }
  idx <- cand[!miss]; key <- key[!miss]
  old <- shares[idx, "ONP"]
  lvl <- mean(old)
  sp <- if (is.null(cv)) onp_newseat_cv(target, lvl) else list(cv = cv, a = NA_real_, k = NA_real_, n = NA_integer_)
  if (is.null(sp)) {
    cat(sprintf("%s! %s: no earlier election to fit the One Nation spread on -- rule NOT applied to %d seat(s)\n", code, target, length(idx)))
    return(shares)
  }
  n <- length(idx)
  shape <- 1 + stats::qnorm(((seq_len(n)) - 0.5) / n)
  ratio <- onp_rank_ratio(order(key), shape, rownames(shares)[idx])
  ratio <- onp_cv_force(ratio, sp$cv)
  ratio <- ratio / mean(ratio)
  new <- lvl * ratio
  oth <- setdiff(colnames(shares), "ONP")
  for (j in seq_along(idx)) {
    i <- idx[j]
    tot <- sum(shares[i, ]); rest <- sum(shares[i, oth])
    if (refill == "prop" && rest > 0) shares[i, oth] <- shares[i, oth] * (tot - new[[j]]) / rest
    shares[i, "ONP"] <- new[[j]]
  }
  cat(sprintf("%s  %s: %d seat(s) with no One Nation state history allocated by rank on the %s One Nation vote%s; level %.2f kept; CV %.3f%s; range %.1f-%.1f; %d moved > 1 point; %d seat(s) with history untouched; refill %s\n",
              code, target, n, k_src,
              if (any(miss)) sprintf(" (%d without a key keep theirs)", sum(miss)) else "",
              mean(new), sp$cv,
              if (is.finite(sp$k)) sprintf(" (SD = %.2f * level^%.2f from %d earlier elections)", sp$a, sp$k, sp$n) else "",
              min(new), max(new), sum(abs(new - old) > 1), n_hist, refill))
  attr(shares, "onp_newseat") <- list(seats = rownames(shares)[idx], fed = k_fed,
                                      source = k_src, level = lvl, cv = sp$cv)
  shares
}
