# Fundamentals ------------------------------------------------------------
#
# What the result would look like knowing nothing about current polling: the
# party's own history, whether it is in government and for how long, and — for
# state elections — whether its federal counterpart holds power, which is the
# well-documented tendency of voters to punish a state party whose federal
# cousins are in office.
#
# Following the anchor: a penalised linear regression per party category,
# validated leave-one-election-out, with economic variables deliberately
# excluded (they are weak predictors in Australia and he tested them).

#' Read a hand-maintained anchor CSV with ragged rows
#'
#' These files carry trailing free-text comments on some rows, so a row may
#' have more fields than the header implies. `fread` STOPS EARLY on the first
#' such row rather than erroring: eventual-results.csv reads 263 of its 421
#' lines that way, and the fundamentals models were quietly fitted on 62% of
#' the data before this was caught. Splitting the lines by hand and taking the
#' leading fields is the only safe route, and it is what the other loaders in
#' this package already do.
#'
#' @param file Filename within the anchor data directory.
#' @param col_names Names for the leading fields; extra fields are dropped.
#' @keywords internal
read_anchor_csv <- function(file, col_names) {
  lines <- readLines(anchor_data_path(file), warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  parts <- strsplit(lines, ",", fixed = TRUE)
  n <- length(col_names)
  parts <- parts[vapply(parts, length, 1L) >= n]
  m <- do.call(rbind, lapply(parts, function(p) trimws(p[seq_len(n)])))
  out <- data.table::as.data.table(m)
  data.table::setnames(out, col_names)
  # Anything that parses cleanly as a number becomes one; codes stay character.
  for (cn in col_names) {
    v <- out[[cn]]
    num <- suppressWarnings(as.numeric(v))
    if (!any(is.na(num) & !is.na(v))) out[[cn]] <- num
  }
  out[]
}

#' Actual election results (the training target)
#'
#' @return data.table: `year`, `region`, `party` ("@TPP" or a party code),
#'   `actual` (percent).
#' @export
load_eventual_results <- function() {
  x <- read_anchor_csv("eventual-results.csv",
                       c("year", "region", "party", "actual"))
  x[, party := sub(" FP$", "", party)]
  x[, actual := suppressWarnings(as.numeric(actual))]
  out <- x[!is.na(actual) & !is.na(year)]
  # Guard against the ragged-row truncation this loader exists to avoid.
  if (nrow(out) < 380) {
    warning(sprintf("eventual-results.csv parsed only %d rows - expected ~415",
                    nrow(out)))
  }
  out
}

#' Who was in government at each election, and for how long
#'
#' @return data.table: `year`, `region`, `incumbent`, `opposition`, `years`.
#' @export
load_incumbency <- function() {
  x <- read_anchor_csv("incumbency.csv",
                       c("year", "region", "incumbent", "opposition", "years"))
  x[, `:=`(incumbent = sub(" FP$", "", incumbent),
           opposition = sub(" FP$", "", opposition),
           years = suppressWarnings(as.numeric(years)))]
  x[!is.na(year)]
}

#' Which party held federal government at the time of each state election
#'
#' @return data.table: `year`, `region`, `fed_govt`, `fed_opp`.
#' @export
load_federal_situation <- function() {
  x <- read_anchor_csv("federal-situation.csv",
                       c("year", "region", "fed_govt", "fed_opp"))
  x[, `:=`(fed_govt = sub(" FP$", "", fed_govt),
           fed_opp = sub(" FP$", "", fed_opp))]
  x[!is.na(year)]
}

#' Elections for which voting-intention polling exists
#' @return data.table: `year`, `region`.
#' @export
load_polled_elections <- function() {
  read_anchor_csv("polled-elections.csv", c("year", "region"))[!is.na(year)]
}

#' Assemble the fundamentals training table
#'
#' One row per (election, party). `@TPP` is Labor's two-party share, so its
#' incumbency features are defined relative to Labor.
#'
#' @param parties Party codes to include, plus "@TPP".
#' @param min_year Elections before this are dropped (the anchor uses 1990;
#'   earlier Australian elections are structurally different and the minor
#'   parties barely existed).
#' @param polled_only Restrict to elections with polling, so the same set can
#'   be used for the projection stage.
#' @param require_actual Keep only elections whose result is known. Set FALSE
#'   to build the feature row for an election that has not happened yet — the
#'   whole point of a fundamentals model — in which case `actual` is `NA`.
#' @return data.table with `actual` and the feature columns.
#' @export
build_fundamentals_data <- function(parties = c("@TPP", "ALP", "LNP", "GRN",
                                                "ONP", "OTH"),
                                    min_year = 1990, polled_only = TRUE,
                                    require_actual = TRUE) {
  ev <- load_eventual_results()
  pri <- load_prior_results()
  inc <- load_incumbency()
  fed <- load_federal_situation()

  # Built from prior-results, not from results: an upcoming election has
  # priors and a political situation but no result yet, and starting from
  # results would silently exclude exactly the case being forecast.
  keep_pri <- pri$party %in% parties & pri$year >= min_year
  dat <- pri[which(keep_pri), ]
  if (polled_only) {
    pol <- load_polled_elections()
    dat <- merge(dat, pol, by = c("year", "region"))
  }
  dat <- merge(dat, ev[, c("year", "region", "party", "actual"), with = FALSE],
               by = c("year", "region", "party"), all.x = TRUE)

  prev_cols <- grep("^prev[0-9]+$", names(dat), value = TRUE)
  prev_cols <- prev_cols[order(as.integer(sub("prev", "", prev_cols)))]
  # Long-run average: the anchor uses a six-election mean for majors, which
  # carries the party's structural level rather than one election's noise.
  use <- utils::head(prev_cols, 6)
  dat[, prev_avg := rowMeans(as.matrix(.SD), na.rm = TRUE), .SDcols = use]
  dat[, prev1 := as.numeric(prev1)]

  dat <- merge(dat, inc[, c("year", "region", "incumbent", "opposition", "years"),
                        with = FALSE],
               by = c("year", "region"), all.x = TRUE)
  dat <- merge(dat, fed[, c("year", "region", "fed_govt", "fed_opp"), with = FALSE],
               by = c("year", "region"), all.x = TRUE)

  # "@TPP" is Labor's share, so it inherits Labor's political position.
  dat[, ref_party := data.table::fifelse(party == "@TPP", "ALP", party)]
  dat[, `:=`(
    is_incumbent = as.numeric(!is.na(incumbent) & ref_party == incumbent),
    is_opposition = as.numeric(!is.na(opposition) & ref_party == opposition)
  )]
  dat[, `:=`(
    govt_years = is_incumbent * data.table::fifelse(is.na(years), 0, years),
    opp_years = is_opposition * data.table::fifelse(is.na(years), 0, years)
  )]
  # +1 if this party's federal counterpart governs, -1 if it is in federal
  # opposition, 0 at federal elections or where unknown.
  dat[, fed_aligned := data.table::fifelse(
    !is.na(fed_govt) & ref_party == fed_govt, 1,
    data.table::fifelse(!is.na(fed_opp) & ref_party == fed_opp, -1, 0))]

  keep <- c("year", "region", "party", "actual", "prev1", "prev_avg",
            "is_incumbent", "is_opposition", "govt_years", "opp_years",
            "fed_aligned")
  out <- dat[, keep, with = FALSE]
  ok <- !is.na(out$prev1)
  if (require_actual) ok <- ok & !is.na(out$actual)
  out <- out[which(ok), ]
  out[is.na(prev_avg), prev_avg := prev1]
  out[order(party, region, year)]
}

FUNDAMENTALS_FEATURES <- c("prev1", "prev_avg", "is_incumbent", "is_opposition",
                           "govt_years", "opp_years", "fed_aligned")

#' Ridge regression with a leave-one-out path, no external dependency
#'
#' glmnet is the obvious tool but is not a hard dependency of this package, so
#' this implements the piece actually needed: an L2 penalty chosen by
#' leave-one-out error. Predictors are standardised, the intercept is left
#' unpenalised, and lambda = 0 is on the path so an unpenalised fit wins when
#' it deserves to.
#'
#' @param X Numeric matrix of predictors. @param y Response.
#' @param lambdas Penalty path.
#' @return List: `beta`, `intercept`, `lambda`, `loo_mae`, `loo_errors`
#'   (per-election held-out errors, for paired comparisons), `centre`,
#'   `scale`, and `features` (the retained predictor names, which
#'   [predict_fundamentals()] reads).
#' @keywords internal
ridge_loo <- function(X, y, lambdas = 10^seq(-6, 3, length.out = 40)) {
  n <- nrow(X)
  standardise <- function(rows) {
    s <- apply(X[rows, , drop = FALSE], 2, stats::sd)
    s[!is.finite(s) | s < 1e-10] <- 1
    list(centre = colMeans(X[rows, , drop = FALSE]), scale = s)
  }
  full <- standardise(seq_len(n))
  Xs <- scale(X, center = full$centre, scale = full$scale)

  fit_one <- function(Xs, y, lam) {
    p <- ncol(Xs)
    A <- crossprod(Xs) + lam * diag(p)
    b <- solve(A, crossprod(Xs, y - mean(y)))
    list(beta = as.numeric(b), intercept = mean(y))
  }
  # Each fold is standardised on its OWN training rows. Centring and scaling
  # once on the full sample lets the held-out election influence the scale of
  # the model that predicts it — narrower than a full leave-one-out violation,
  # since the response is already re-centred per fold, but it still flatters
  # `loo_mae`, and most where it matters least: `fit_fundamentals()` accepts
  # categories with as few as 10 elections, where one row moves the mean and
  # sd appreciably.
  errs_for <- function(lam) vapply(seq_len(n), function(i) {
    rows <- setdiff(seq_len(n), i)
    st <- standardise(rows)
    Xtr <- scale(X[rows, , drop = FALSE], center = st$centre, scale = st$scale)
    m <- fit_one(Xtr, y[rows], lam)
    xi <- (X[i, ] - st$centre) / st$scale
    y[i] - (m$intercept + sum(xi * m$beta))
  }, numeric(1))
  all_errs <- lapply(lambdas, errs_for)
  loo <- vapply(all_errs, function(e) mean(abs(e)), numeric(1))
  k <- which.min(loo)
  best <- lambdas[k]
  m <- fit_one(Xs, y, best)
  list(beta = m$beta, intercept = m$intercept, lambda = best,
       loo_mae = loo[k],
       # Per-election held-out errors, so an improvement over a baseline can be
       # tested as a paired comparison rather than eyeballed from two means.
       loo_errors = all_errs[[k]],
       centre = full$centre, scale = full$scale, features = colnames(X))
}

#' Fit the fundamentals model for one party category
#'
#' @param dat From [build_fundamentals_data()].
#' @param party Party code, or "@TPP".
#' @param features Predictor columns.
#' @return List with the fitted model plus leave-one-out comparisons against
#'   two naive baselines: predicting the previous result, and predicting the
#'   long-run average.
#' @export
fit_fundamentals <- function(dat, party, features = FUNDAMENTALS_FEATURES) {
  # Mask computed OUTSIDE the brackets: `party` is both an argument here and a
  # column of `dat`, and data.table resolves the bare name to the column, so
  # the obvious `dat[dat$party == party, ]` filters nothing and silently fits
  # every party's rows at once. Caught because all six categories returned
  # identical coefficients and n = 194.
  keep_rows <- dat$party == party
  d <- dat[which(keep_rows), ]
  if (nrow(d) < 10) stop("Only ", nrow(d), " elections for ", party)
  # Drop predictors with no variation within this party's rows (e.g.
  # fed_aligned is identically 0 if the party only contests federal seats).
  keep <- features[vapply(features, function(f) stats::sd(d[[f]]) > 1e-10, TRUE)]
  # ...then drop exact linear dependencies. For a major party `is_opposition`
  # is precisely `1 - is_incumbent`, which makes the design rank-deficient and
  # the unpenalised end of the ridge path singular. QR pivoting keeps one of
  # each dependent set rather than failing.
  if (length(keep) > 1) {
    q <- qr(scale(as.matrix(d[, keep, with = FALSE])))
    keep <- keep[sort(q$pivot[seq_len(q$rank)])]
  }
  X <- as.matrix(d[, keep, with = FALSE])
  y <- d$actual

  m <- ridge_loo(X, y)
  m$party <- party
  m$n <- nrow(d)
  m$features <- keep
  m$baseline_prev1_mae <- mean(abs(y - d$prev1))
  m$baseline_avg_mae <- mean(abs(y - d$prev_avg))
  m$data <- d
  m
}

#' Predict from a fundamentals model
#'
#' @param model From [fit_fundamentals()].
#' @param newdata data.table carrying the model's feature columns.
#' @return Numeric vector of predicted shares (percent).
#' @export
predict_fundamentals <- function(model, newdata) {
  X <- as.matrix(newdata[, model$features, with = FALSE])
  Xs <- scale(X, center = model$centre, scale = model$scale)
  as.numeric(model$intercept + Xs %*% model$beta)
}
