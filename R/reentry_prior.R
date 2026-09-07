#' Predict what a class polls when it did not contest the seat last time
#'
#' When a class contests a seat at the target election but not at the previous
#' one, the model has no prior share for it: swinging zero forward leaves
#' approximately zero. Across the 22-pair corpus **1,418 seat-class rows** are
#' in that state, and predicting zero for them costs a mean absolute error of
#' **5.27 points**.
#'
#' Kimberley 2001 is the case this exists for. Labor did not stand there in
#' 1996; Carol Martin won it with 42.2%; the model projected 2.1% and gave the
#' actual winner a probability of 0.000000 — one of the five worst-scored seats
#' in the corpus.
#'
#' The fit is per class, on the log scale, from three seat facts plus the
#' class's own statewide share:
#'
#' * `state_pcv` — the class's projected statewide share. The dominant term.
#' * `safe` — `abs(lean - 50)`, how uncompetitive the seat is. A minor party
#'   re-entering a safe seat does far better than one re-entering a marginal:
#'   independents run 1.04x statewide in the most marginal quartile and 1.78x in
#'   the second-safest, because a safe seat has a weak second major and leaves
#'   room.
#' * `lean` — the left bloc's share of the two blocs at the previous election.
#'   Weak for most classes and real for the minor right, which does better in
#'   right-leaning seats.
#' * `nonmajor_prev` — how much of the seat already went to non-majors, i.e. how
#'   receptive it is.
#'
#' All four are computable from the PREVIOUS election alone, so this is
#' leakage-free, and unlike the census they exist for all 22 pairs.
#'
#' HOW THIS PERFORMS, out of fold, leave-one-election-out over 1,418 rows:
#'
#' | predictor | mean absolute error |
#' | --- | --- |
#' | zero, which is what the model did before | 5.2718 |
#' | flat class ratio times statewide | 3.4063 |
#' | **this model** | **3.3484** |
#'
#' AND THE HONEST CAVEAT, recorded here rather than in a commit message nobody
#' re-reads. Nearly all of that gain — 1.87 of the 1.92 points — comes from
#' moving off zero to a flat class ratio. The covariates add 0.047, against a
#' per-election spread of 0.553; they win in 15 of 22 elections but a paired t
#' over those elections gives p = 0.693 with a 95% interval of [-0.198, +0.292].
#' At 22 elections this cannot be called either way. Adopted at Pete's direction
#' on the consistent direction and the in-sample structure; the flat ratio is
#' available by passing `covariates = FALSE` and is the control to re-run
#' against when more elections exist.
#'
#' @param pairs A list of `list(election=, prev=)` EXCLUDING the target, from
#'   which the model is fitted.
#' @param min_n A class with fewer rows than this gets the flat ratio instead of
#'   its own fit — four coefficients on a dozen points is not a model.
#' @param min_ratio_n Below this a class gets a ratio of 1 — its statewide
#'   share — rather than a ratio estimated from a handful of rows. Labor has one
#'   re-entry row in the entire corpus.
#' @param covariates `FALSE` fits the flat class ratio only, which is the
#'   control arm.
#' @param cand_path Candidacy corpus.
#' @return An object for [reentry_predict()], carrying one fit or ratio per
#'   class and the row counts behind each.
#' @export
reentry_fit <- function(pairs, min_n = 40L, min_ratio_n = 20L, covariates = TRUE,
                        cand_path = file.path("output", "candidacies.csv")) {
  D <- reentry_training(pairs, cand_path)
  cls <- unique(D$party)
  fits <- list(); ratios <- c(); ns <- c()
  for (cl in cls) {
    d <- D[D$party == cl]
    ns[cl] <- nrow(d)
    # A RATIO NEEDS OBSERVATIONS TOO, not just the model. Labor has ONE
    # re-entry row in the whole corpus (Alfred Cove 2005, 22.8% against a 41.9%
    # statewide), and taking that single point as its ratio gave Kimberley 20.3%
    # -- a number resting entirely on one unrelated seat. Below min_ratio_n a
    # class falls back to 1, meaning "assume it polls its statewide share",
    # which is a neutral prior rather than one seat's accident.
    # A RATIO NEEDS OBSERVATIONS TOO. Labor has ONE re-entry row in the corpus
    # (Alfred Cove 2005) and the Coalition five, so below min_ratio_n a class
    # falls back to 1 -- "assume it polls its statewide share".
    #
    # POOLING THE TWO MAJORS WAS TRIED AND IS WORSE, 2026-09-07. Together they
    # have eight rows and a ratio of 0.84, which sounds better than assuming 1.
    # Measured on Western Australia it cost accuracy (87.5% -> 87.3%), Brier
    # (0.0992 -> 0.0998) and Kimberley (0.560 -> 0.331), and did not rescue the
    # seat it was meant to -- Alfred Cove stayed on the floor either way. A
    # measured ratio on eight rows is not automatically better than a neutral
    # assumption, and this is the evidence.
    ratios[cl] <- if (nrow(d) >= min_ratio_n) mean(d$pcv) / mean(d$state_pcv) else 1
    if (covariates && nrow(d) >= min_n) {
      f <- try(stats::glm(pcv ~ log(state_pcv) + safe + lean + nonmajor_prev,
                          family = stats::quasipoisson(link = "log"), data = d),
               silent = TRUE)
      if (!inherits(f, "try-error")) fits[[cl]] <- f
    }
  }
  structure(list(fits = fits, ratios = ratios, n = ns, covariates = covariates),
            class = "auspol_reentry")
}

#' Training rows for the re-entry model
#'
#' One row per (seat, class) that contested at the target and not at the prior
#' election, for each pair. Seats absent from the PRIOR election are excluded:
#' that is a redistribution, a different problem, and pooling the two would let
#' boundary churn set a coefficient meant to describe a party's decision to
#' contest.
#'
#' @inheritParams reentry_fit
#' @return A `data.table` with `pcv`, `state_pcv`, `lean`, `safe`,
#'   `nonmajor_prev`, `party` and `pair`.
#' @export
reentry_training <- function(pairs,
                             cand_path = file.path("output", "candidacies.csv")) {
  if (!file.exists(cand_path)) stop("needs ", cand_path, call. = FALSE)
  CB <- data.table::fread(cand_path, showProgress = FALSE)
  agg <- CB[, list(votes = sum(votes)), by = c("election", "seat", "party")]
  agg[, pcv := 100 * votes / sum(votes), by = c("election", "seat")]
  out <- lapply(pairs, function(p) {
    a <- agg[agg$election == p$prev]
    b <- agg[agg$election == p$election]
    if (!nrow(a) || !nrow(b)) return(NULL)
    ln <- seat_lean(a)
    st <- b[, list(state_pcv = 100 * sum(votes) / sum(b$votes)), by = "party"]
    m <- merge(b, a[, list(seat, party, prev = pcv)], by = c("seat", "party"),
               all.x = TRUE)
    m <- merge(merge(m, st, by = "party"), ln, by = "seat")
    m <- m[is.na(m$prev) & m$seat %in% a$seat]
    if (!nrow(m)) return(NULL)
    m[, pair := p$election]
    m[, list(pair, party, seat, pcv, state_pcv, lean, safe, nonmajor_prev)]
  })
  D <- data.table::rbindlist(out, fill = TRUE)
  if (!nrow(D)) return(D)
  D[is.finite(D$lean) & is.finite(D$state_pcv) & D$state_pcv > 0]
}

#' Seat lean, safeness and non-major share from one election's shares
#'
#' `lean` is the left bloc's share of the two blocs, so 50 is balanced and 100
#' is wholly left. `safe` is its distance from 50. `nonmajor_prev` is everything
#' outside the two majors.
#'
#' @param a A `data.table` of `seat`, `party`, `pcv` for ONE election.
#' @return A `data.table` of `seat`, `lean`, `safe`, `nonmajor_prev`.
#' @export
seat_lean <- function(a) {
  w <- data.table::dcast(a, seat ~ party, value.var = "pcv", fill = 0)
  gcol <- function(nm) {
    k <- intersect(nm, names(w))
    if (!length(k)) rep(0, nrow(w)) else rowSums(w[, k, with = FALSE])
  }
  L <- gcol(c("ALP", "GRN")); R <- gcol(c("LNP", "ONP", "OTH_RIGHT"))
  nm <- gcol(setdiff(names(w), c("seat", "ALP", "LNP")))
  lean <- ifelse(L + R > 0, 100 * L / (L + R), NA_real_)
  data.table::data.table(seat = w$seat, lean = lean, safe = abs(lean - 50),
                         nonmajor_prev = nm)
}

#' Predicted re-entry share for given seats and classes
#'
#' @param fit From [reentry_fit()].
#' @param newdata A `data.frame` with `party`, `state_pcv`, `lean`, `safe`,
#'   `nonmajor_prev`.
#' @return Numeric vector, one predicted share per row. A class with no fit
#'   falls back to its flat ratio, and one seen in no training row to its
#'   statewide share.
#' @export
reentry_predict <- function(fit, newdata) {
  out <- rep(NA_real_, nrow(newdata))
  for (cl in unique(newdata$party)) {
    idx <- which(newdata$party == cl)
    f <- fit$fits[[cl]]
    if (!is.null(f)) {
      p <- try(as.numeric(stats::predict(f, newdata = newdata[idx, , drop = FALSE],
                                         type = "response")), silent = TRUE)
      if (!inherits(p, "try-error")) { out[idx] <- p; next }
    }
    r <- if (cl %in% names(fit$ratios)) unname(fit$ratios[[cl]]) else 1
    out[idx] <- r * newdata$state_pcv[idx]
  }
  pmax(out, 0)
}

#' Apply the re-entry prior to a seat-by-class share matrix
#'
#' Fills cells that are zero because the class did not contest the seat last
#' time AND is contesting it now. Every other cell is untouched, so a run with
#' no qualifying cell is byte-identical.
#'
#' Whether a class is standing comes from the nomination list, which closes
#' before polling day, and the harnesses already read exactly that to ZERO an
#' independent column where nobody nominated. This is the same fact in the
#' other direction: that rule removes a party that is not standing, this one
#' gives a base to a party that is.
#'
#' @param mat Numeric matrix, seats in rows (named), classes in columns.
#' @param standing `data.frame` with `seat` and `party` for classes contesting
#'   the target election, or a character vector of `"seat|class"` keys.
#' @param fit From [reentry_fit()].
#' @param lean_dt From [seat_lean()] on the PREVIOUS election.
#' @param state_share Named numeric vector, projected statewide share per class.
#' @param eps A cell at or below this counts as no prior vote.
#' @return `mat` with qualifying cells filled and attribute `"reentry"` naming
#'   what was set — print it, because a rule that fills nothing is an arm that
#'   looks like it ran and did not.
#' @export
apply_reentry_prior <- function(mat, standing, fit, lean_dt, state_share,
                                eps = 0.01) {
  if (is.data.frame(standing)) {
    standing <- paste(standing$seat, standing$party, sep = "|")
  }
  ld <- as.data.frame(lean_dt)
  rownames(ld) <- ld$seat
  rows <- list()
  for (p in intersect(colnames(mat), names(state_share))) {
    hit <- which(mat[, p] <= eps &
                   paste(rownames(mat), p, sep = "|") %in% standing)
    if (!length(hit)) next
    sn <- rownames(mat)[hit]
    nd <- data.frame(party = p,
                     state_pcv = unname(state_share[[p]]),
                     lean = ld[sn, "lean"], safe = ld[sn, "safe"],
                     nonmajor_prev = ld[sn, "nonmajor_prev"],
                     stringsAsFactors = FALSE)
    ok <- stats::complete.cases(nd)
    if (!any(ok)) next
    v <- reentry_predict(fit, nd[ok, , drop = FALSE])
    mat[sn[ok], p] <- v
    rows[[p]] <- data.frame(seat = sn[ok], party = p, value = v,
                            stringsAsFactors = FALSE)
  }
  attr(mat, "reentry") <- if (length(rows)) do.call(rbind, rows) else
    data.frame(seat = character(0), party = character(0), value = numeric(0))
  mat
}
