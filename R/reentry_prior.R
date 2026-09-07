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
#' over those elections gives p = 0.693, with a 95% interval running from
#' -0.198 to +0.292. At 22 elections this cannot be called either way. Adopted at Pete's direction
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
      # BOTH LEANS. Measured out of fold: flat 3.3459, bloc 3.3082, flow
      # 3.2895, both 3.2519. Flow alone barely beats bloc (12 of 22 elections),
      # but both together gain +0.095 and win in 17 of 22 -- they agree in most
      # seats and disagree usefully in the ones an independent dominates.
      # STATEWIDE SHARE IS AN OFFSET, NOT A FITTED TERM. As a fitted term under
      # a log link it learns an average elasticity across elections where the
      # statewide share barely moves, and then regresses a genuine surge toward
      # that mean. sa2026 is the case: One Nation went 2.6% -> 22.9% statewide
      # and polled a mean of 20.3% in the 29 of 47 seats where they re-entered,
      # and the fitted version projected about 10. As an offset the prediction
      # is proportional to the statewide share by construction -- the flat
      # ratio's one good property -- while the seat covariates still adjust it.
      # THE NON-MAJOR VOTE ENTERS SPLIT, not whole, when the nomination list
      # reached seat_lean(). AUSPOL_REENTRY_SPLIT=0 restores the single
      # `nonmajor_prev` term so the two can be measured against each other on
      # identical data. See the pre-registration named in seat_lean().
      .split <- !identical(Sys.getenv("AUSPOL_REENTRY_SPLIT", "1"), "0") &&
        all(is.finite(d$nonmajor_defended))
      .nmterm <- if (.split) "nonmajor_defended + nonmajor_vacant" else "nonmajor_prev"
      fo <- stats::as.formula(paste(
        "pcv ~ offset(log(state_pcv)) + breadth + safe + lean +",
        if (all(is.finite(d$flow_lean))) "flow_safe + flow_lean +" else "",
        .nmterm))
      f <- try(stats::glm(fo, family = stats::quasipoisson(link = "log"), data = d),
               silent = TRUE)
      if (!inherits(f, "try-error")) fits[[cl]] <- f
      # PRINT WHAT IT APPLIED. CLAUDE.md records an experiment whose edit never
      # ran and whose byte-identical output read as "this input does not
      # matter". A run that silently fell back to the whole-vote term would be
      # indistinguishable from one where the split had no effect.
      if (!.split && !identical(Sys.getenv("AUSPOL_REENTRY_SPLIT", "1"), "0"))
        cat(sprintf("RE1s %s: nomination list absent, fitted on nonmajor_prev
", cl))
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
    # Positions measured WITHOUT the target election, so the flow lean is
    # leave-one-election-out like everything else here.
    ln <- seat_lean(a, positions = party_positions(exclude = p$election),
                    standing = unique(b[, list(seat, party)]))
    st <- b[, list(state_pcv = 100 * sum(votes) / sum(b$votes)), by = "party"]
    m <- merge(b, a[, list(seat, party, prev = pcv)], by = c("seat", "party"),
               all.x = TRUE)
    m <- merge(merge(m, st, by = "party"), ln, by = "seat")
    m <- m[is.na(m$prev) & m$seat %in% a$seat]
    if (!nrow(m)) return(NULL)
    m[, pair := p$election]
    # HOW BROADLY THE CLASS IS RE-ENTERING, as a share of the chamber. A party
    # re-entering a handful of seats has CHOSEN them and beats its statewide
    # share; one re-entering most of the chamber has chosen nothing and lands on
    # it. Measured: ratio 1.84 when re-entering 5-15% of seats and 1.01 above
    # 35%, and for One Nation 5.50 against 0.98. sa2026 is the case -- ONP
    # re-entered 29 of 47 seats on a 22.9% statewide share and polled a mean of
    # 19.7%, while the pooled ratio of 1.458 (an average dominated by narrow
    # re-entries) would have given 33. Knowable from the nomination list, so
    # leakage-free.
    n_seats <- length(unique(b$seat))
    m[, breadth := .N / n_seats, by = "party"]
    m[, list(pair, party, seat, pcv, state_pcv, lean, safe, nonmajor_prev,
             nonmajor_defended, nonmajor_vacant, flow_lean, flow_safe, breadth)]
  })
  D <- data.table::rbindlist(out, fill = TRUE)
  if (!nrow(D)) return(D)
  D[is.finite(D$lean) & is.finite(D$state_pcv) & D$state_pcv > 0]
}

#' Where each party's preferences actually go
#'
#' A party's position on the left-right axis, MEASURED rather than assigned: of
#' its transferred preferences that reach a major, the share reaching the
#' Coalition. 0 flows to Labor, 1 to the Coalition. Over 24.7 million
#' transferred votes this recovers the ordering you would assign by hand —
#' GRN 0.21, OTH 0.44, IND 0.47, OTH_RIGHT 0.64, ONP 0.69 — without assigning
#' anything, and it drifts in ways that are political history: independents move
#' 0.56 to 0.40 across the federal series, which is the teal shift showing up in
#' preference behaviour.
#'
#' ALP AND LNP ARE PINNED at 0 and 1 rather than measured. A major's preferences
#' are only distributed when it is EXCLUDED, which happens when it finishes
#' third or worse, so the measured values are exclusion artefacts: Labor reads
#' 0.997 because the only major left standing in those seats was the Coalition,
#' and the Coalition reads 0.424 because that is Liberal-to-Nationals flow in a
#' three-cornered contest, i.e. the class flowing to itself. They are the
#' anchors of the scale, not points on it.
#'
#' @param exclude Election label to leave out, so the caller stays
#'   leave-one-election-out.
#' @param min_votes A party needs this many transferred votes to get a measured
#'   position; below it, no opinion.
#' @param path Directory holding the transfer files.
#' @return Named numeric vector of positions.
#' @export
party_positions <- function(exclude = NULL, min_votes = 5000,
                            path = election_data_path()) {
  tf <- c("aec-fed-transfers.csv", "nswec-nsw-transfers.csv",
          "ecq-qld-transfers.csv", "vec-2014-vic-transfers.csv",
          "vec-2018-vic-transfers.csv", "vec-2022-vic-transfers.csv")
  TX <- data.table::rbindlist(lapply(tf, function(f) {
    fp <- file.path(path, f)
    if (file.exists(fp)) data.table::fread(fp, showProgress = FALSE) else NULL
  }), fill = TRUE)
  if (!nrow(TX)) return(c(ALP = 0, LNP = 1))
  if (!is.null(exclude)) TX <- TX[!TX$election %in% exclude]
  s <- TX[TX$to %in% c("ALP", "LNP"), list(v = sum(votes)), by = c("from", "to")]
  if (!nrow(s)) return(c(ALP = 0, LNP = 1))
  w <- data.table::dcast(s, from ~ to, value.var = "v", fill = 0)
  if (!"ALP" %in% names(w)) w[, ALP := 0]
  if (!"LNP" %in% names(w)) w[, LNP := 0]
  w[, n := ALP + LNP]
  p <- stats::setNames(w$LNP / w$n, w$from)[w$n >= min_votes]
  p[["ALP"]] <- 0; p[["LNP"]] <- 1
  p
}

#' Seat lean, safeness and non-major share from one election's shares
#'
#' `lean` is the left bloc's share of the two blocs, so 50 is balanced and 100
#' is wholly left. `safe` is its distance from 50. `nonmajor_prev` is everything
#' outside the two majors.
#'
#' @param a A `data.table` of `seat`, `party`, `pcv` for ONE election.
#' @param positions Optional named vector from [party_positions()]. When given,
#'   the result gains `flow_lean` and `flow_safe`: the seat's position weighted
#'   by where each party's preferences actually go, which is defined even when a
#'   major did not contest the seat and the bloc measure saturates at 0 or 100.
#' @return A `data.table` of `seat`, `lean`, `safe`, `nonmajor_prev`.
#' @export
seat_lean <- function(a, positions = NULL, standing = NULL) {
  w <- data.table::dcast(a, seat ~ party, value.var = "pcv", fill = 0)
  gcol <- function(nm) {
    k <- intersect(nm, names(w))
    if (!length(k)) rep(0, nrow(w)) else rowSums(w[, k, with = FALSE])
  }
  L <- gcol(c("ALP", "GRN")); R <- gcol(c("LNP", "ONP", "OTH_RIGHT"))
  nm <- gcol(setdiff(names(w), c("seat", "ALP", "LNP")))
  lean <- ifelse(L + R > 0, 100 * L / (L + R), NA_real_)
  # DEFENDED vs VACANT non-major vote, per
  # docs/plans/prereg-reentry-defended-nonmajor-2026-09-08.md. `nonmajor_prev`
  # reads every vote outside the two majors as room a re-entering minor party
  # can take, which is true only if the vote is AVAILABLE. Traeger qld2024:
  # its 63.3% non-major vote in 2020 was entirely Katter's Australian Party,
  # KAP stood again in 2024 and took 49.3%, and the model predicted One Nation
  # at 74.3% against an actual 6.8%.
  #
  # `standing` is the target election's nomination list, so this is knowable
  # before polling day -- the same fact the prior itself rests on. The two
  # parts sum to `nonmajor_prev` exactly, so nothing is added, only separated.
  nm_cols <- setdiff(names(w), c("seat", "ALP", "LNP"))
  if (!is.null(standing) && length(nm_cols)) {
    if (is.data.frame(standing))
      standing <- paste(standing$seat, standing$party, sep = "|")
    M <- as.matrix(w[, nm_cols, with = FALSE])
    keys <- outer(w$seat, nm_cols, function(sx, px) paste(sx, px, sep = "|"))
    held <- matrix(keys %in% standing, nrow = nrow(w), ncol = length(nm_cols))
    def <- rowSums(M * held)
    vac <- rowSums(M * !held)
  } else {
    # NOT a silent fallback to "all vacant": NA propagates into the model
    # frame, complete.cases() drops the row, and reentry_fit() falls back to a
    # formula without these terms and SAYS SO. A caller that forgets to pass
    # the nomination list gets the old behaviour visibly, not invisibly.
    def <- rep(NA_real_, nrow(w)); vac <- rep(NA_real_, nrow(w))
  }
  out <- data.table::data.table(seat = w$seat, lean = lean, safe = abs(lean - 50),
                                nonmajor_prev = nm,
                                nonmajor_defended = def, nonmajor_vacant = vac)
  # THE FLOW LEAN, alongside the bloc one rather than instead of it. They
  # correlate at 0.956 and using BOTH beats either -- +0.095 mean gain over the
  # bloc measure alone, better in 17 of 22 elections. Where they disagree is
  # seats an independent dominates, which is where the bloc measure breaks:
  # Kimberley 1996 was Bridge (IND) 63.1% and Liberal 36.9%, so its left bloc is
  # EMPTY and it reads lean 0.0, the most right-wing seat possible, for a remote
  # Labor-friendly electorate whose later leans are 59.2, 57.1 and 55.2.
  if (!is.null(positions) && length(positions)) {
    a2 <- data.table::as.data.table(a)
    a2 <- a2[a2$party %in% names(positions)]
    if (nrow(a2)) {
      fl <- a2[, list(flow_lean = 100 * (1 - sum(pcv * unname(positions[party])) /
                                           sum(pcv))), by = "seat"]
      out <- merge(out, fl, by = "seat", all.x = TRUE)
      out[, flow_safe := abs(flow_lean - 50)]
    }
  }
  if (!"flow_lean" %in% names(out)) out[, `:=`(flow_lean = NA_real_, flow_safe = NA_real_)]
  out[]
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
                     flow_lean = if ("flow_lean" %in% names(ld)) ld[sn, "flow_lean"] else NA_real_,
                     flow_safe = if ("flow_safe" %in% names(ld)) ld[sn, "flow_safe"] else NA_real_,
                     nonmajor_prev = ld[sn, "nonmajor_prev"],
                     nonmajor_defended = if ("nonmajor_defended" %in% names(ld))
                       ld[sn, "nonmajor_defended"] else NA_real_,
                     nonmajor_vacant = if ("nonmajor_vacant" %in% names(ld))
                       ld[sn, "nonmajor_vacant"] else NA_real_,
                     breadth = length(hit) / nrow(mat),
                     stringsAsFactors = FALSE)
    # Only the columns the fit actually uses need to be present. Requiring the
    # flow columns too would silently drop every seat when transfers are absent.
    # ONLY THE TERMS THIS CLASS'S FIT ACTUALLY USES. Requiring both the whole
    # and the split non-major columns would drop every row whenever either is
    # absent, which is how a "no rows qualified" silence gets manufactured.
    need <- c("state_pcv", "lean", "safe", "breadth")
    .cf <- if (!is.null(fit$fits[[p]])) names(stats::coef(fit$fits[[p]])) else character(0)
    need <- c(need, if ("nonmajor_defended" %in% .cf)
      c("nonmajor_defended", "nonmajor_vacant") else "nonmajor_prev")
    if ("flow_lean" %in% .cf) need <- c(need, "flow_lean", "flow_safe")
    ok <- stats::complete.cases(nd[, need, drop = FALSE])
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

#' One-call re-entry prior for a harness
#'
#' Wraps [reentry_fit()], [seat_lean()] and [apply_reentry_prior()] so a harness
#' needs one line rather than six, and so all six harnesses do the same thing.
#' Returns `mat` unchanged, with a message, if the switch is off or anything
#' fails — a harness must never be silently skipped, which is the failure this
#' repo keeps recording.
#'
#' @param mat Seat-by-class share matrix.
#' @param fa,fb Long-form `seat`, `party`, `votes` for the PREVIOUS and TARGET
#'   elections.
#' @param state_share Named projected statewide share per class.
#' @param target Target election label, removed from the fit.
#' @param pairs Every candidate pair for the fit.
#' @param code Log prefix, e.g. `"BV1r"`.
#' @return `mat`, with attribute `"reentry"` when applied.
#' @export
reentry_apply_harness <- function(mat, fa, fb, state_share, target, pairs,
                                  code = "RE1") {
  if (!identical(Sys.getenv("AUSPOL_REENTRY", "0"), "1")) return(mat)
  fit <- tryCatch(reentry_fit(Filter(function(z) z$election != target, pairs)),
                  error = function(e) {
                    cat(sprintf("%s! reentry_fit() FAILED, prior NOT applied: %s
",
                                code, conditionMessage(e))); NULL })
  if (is.null(fit)) return(mat)
  fa <- data.table::as.data.table(fa)
  fb <- data.table::as.data.table(fb)
  a_pcv <- fa[, list(votes = sum(votes)), by = c("seat", "party")]
  a_pcv[, pcv := 100 * votes / sum(votes), by = "seat"]
  stand <- unique(fb[fb$votes > 0, list(seat, party)])
  ln <- seat_lean(a_pcv[, list(seat, party, pcv)],
                  positions = party_positions(exclude = target),
                  standing = stand)
  out <- tryCatch(apply_reentry_prior(mat, stand, fit, ln, state_share),
                  error = function(e) {
                    cat(sprintf("%s! apply_reentry_prior() FAILED: %s
",
                                code, conditionMessage(e))); NULL })
  if (is.null(out)) return(mat)
  re <- attr(out, "reentry")
  cat(sprintf("%s  re-entry prior: %d cell(s) filled%s
", code, nrow(re),
              if (nrow(re)) {
                o <- order(-re$value)
                paste0(" | largest: ", paste(utils::head(sprintf(
                  "%s/%s %.1f", re$seat[o], re$party[o], re$value[o]), 3),
                  collapse = ", "))
              } else ""))
  out
}

#' Every consecutive election pair the corpus holds
#'
#' ONE list, in the package, because this repo has already been bitten by six
#' harnesses each carrying their own copy of a pair list: the Queensland surge
#' list had `sa2026` renamed to `qld2024` in a copy-paste and trained without
#' the election with four One Nation winners for as long as nobody diffed them.
#' A caller removes its own target to stay leave-one-election-out.
#'
#' @return A list of `list(election=, prev=)`.
#' @export
all_election_pairs <- function() {
  list(
    list(election = "fed2007", prev = "fed2004"),
    list(election = "fed2010", prev = "fed2007"),
    list(election = "fed2013", prev = "fed2010"),
    list(election = "fed2016", prev = "fed2013"),
    list(election = "fed2019", prev = "fed2016"),
    list(election = "fed2022", prev = "fed2019"),
    list(election = "fed2025", prev = "fed2022"),
    list(election = "vic2014", prev = "vic2010"),
    list(election = "vic2018", prev = "vic2014"),
    list(election = "vic2022", prev = "vic2018"),
    list(election = "nsw2019", prev = "nsw2015"),
    list(election = "nsw2023", prev = "nsw2019"),
    list(election = "sa2026",  prev = "sa2022"),
    list(election = "qld2020", prev = "qld2017"),
    list(election = "qld2024", prev = "qld2020"),
    list(election = "wa2001",  prev = "wa1996"),
    list(election = "wa2005",  prev = "wa2001"),
    list(election = "wa2008",  prev = "wa2005"),
    list(election = "wa2013",  prev = "wa2008"),
    list(election = "wa2017",  prev = "wa2013"),
    list(election = "wa2021",  prev = "wa2017"),
    list(election = "wa2025",  prev = "wa2021"))
}
