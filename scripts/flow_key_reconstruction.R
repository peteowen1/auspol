# Answer-key reconstruction for preference flows, sourced by
# scripts/estimate_flows_from_results.R (check codes FR*).
#
# WHAT THE KEY IS. For one election and one first-preference party class k, the share
# of k's first-preference ballots that end with Labor rather than the Coalition. The
# AEC publishes this for federal elections (output/aec-tpp-flows.csv, built by
# scripts/build_aec_tpp_flows.R from the official two-party flow tables). For every
# other election it can only be RECONSTRUCTED from the count-by-count transfer
# files, which record each exclusion's pile split by the recipients' party class,
# never which first preference a ballot started as. So the reconstruction has to
# assume something about the mix inside a pile.
#
# WHY THE FIRST VERSION WAS BIASED (docs/reviews/flow-estimation-validation-2026-10-13.md,
# "Revalidation on a corrected key"). It assumed every ballot in an excluded
# candidate's pile flows like the pile's average ("proportional"). A pile is a mix of
# origins (the Greens' own ballots plus ballots that arrived from smaller parties), and
# those origins do not flow alike: Greens ballots go to Labor far more than the
# pile average, so the proportional rule drags every class toward the middle. On
# the federal elections 2007-2025 it put the Greens 3.4-8 points below the AEC and
# the right-wing minors 4-5 points above.
#
# THE CORRECTED RULE (a choice model). A ballot of origin o in the pile of an excluded
# candidate goes to destination class d with probability proportional to
#       s[o, d] * g[X, d]
# where g[X, d] is a per-exclusion availability weight chosen so that the pile's
# destination totals are reproduced EXACTLY (the transfer files are matched, as before)
# and s[o, d] is a tilt matrix saying how much more origin o favours destination d than
# the pile average does. s is learned from the same transfer files by maximum
# likelihood (an MM/EM fit, `fit_s`, one fit per election, three passes because the pile
# compositions depend on the tilt), then shrunk toward "no tilt" by an exponent
#       lambda_o = KEY_LAMBDA_MAX * M_o / (M_o + KEY_KAPPA)
# where M_o is the origin's first preferences in that election: the tilt of a rare
# origin (One Nation in 2007: 32,650 first preferences nationally) is poorly pinned
# down and an unshrunk fit overshoots. lambda = 1 is the raw fit, 0 the old proportional rule.
#
# KEY_LAMBDA_MAX = 0.75 AND KEY_KAPPA = 100,000 ARE THE ONLY CONSTANTS CALIBRATED AGAINST
# THE AEC. They were chosen from nine variants (uniform exponent 0, 0.5, 0.75, 1; evidence-weighted
# 0.75/1e5, 1/1e5, 1/3e5, 0.85/2e5; and one tilt pooled across elections) by the federal Greens / One Nation
# gap to the AEC, 2007-2025. That makes the federal key an in-sample match to the AEC by
# construction of those two numbers; the per-year gaps printed by FR6 are the honest
# remainder (Greens within 1 point every year, One Nation not: 2010, 2013 and 2025 are out).
# The state keys use the same machinery and constants and have NO official table to check
# against: their bias is unmeasured, plausibly of the federal size before correction.
#
# Federal elections 2004-2025 are tracked ballot-class by candidate from the AEC
# distribution-of-preferences files over ALL 150 seats, the same scope as the AEC's
# table (notional counts included; see `fed_track_year`). State elections and
# fed2001 use the class-level transfer files over seats whose final two are Labor
# and the Coalition.

ORIGS <- c("GRN", "ONP", "OTH", "OTH_RIGHT", "IND", "ALP", "LNP")  # origin / destination classes
NO <- length(ORIGS); ND <- NO + 1L                                 # destinations also include EXHAUST
TERMS <- c("ALP", "LNP")
KEY_LAMBDA_MAX <- as.numeric(Sys.getenv("KEY_LAMBDA_MAX", "0.75"))  # tilt exponent for an origin with unlimited evidence
KEY_KAPPA <- as.numeric(Sys.getenv("KEY_KAPPA", "100000"))      # first preferences at which an origin gets half of it
KEY_PASSES <- 3L
KEY_PURE <- 0.7    # a pile is "near pure" for the tilt starting point if one origin is >= this share

# ---- the choice model -----------------------------------------------------------------
# Flow of each origin's mass m (length NO) to destinations given destination totals t
# (length ND, EXHAUST last), tilt s (NO x ND). Returns the NO x ND matrix of flows;
# columns sum to t on every available destination (up to tolerance).
solve_g <- function(m, t, s, iters = 80L) {
  act <- which(t > 0)
  g <- rep(1, ND)
  for (it in seq_len(iters)) {
    A <- sweep(s[, act, drop = FALSE], 2, g[act], `*`)
    Z <- rowSums(A); Z[Z <= 0] <- 1
    got <- colSums((A / Z) * m)
    ratio <- t[act] / pmax(got, 1e-12)
    g[act] <- g[act] * ratio
    g[act] <- g[act] / mean(g[act])
    if (max(abs(ratio - 1)) < 1e-9) break
  }
  A <- sweep(s[, act, drop = FALSE], 2, g[act], `*`)
  Z <- rowSums(A); Z[Z <= 0] <- 1
  Fm <- matrix(0, NO, ND); Fm[, act] <- (A / Z) * m
  Fm
}

# Evidence-weighted exponent: an origin with few first preferences in the election has a
# poorly pinned-down tilt, so its row of s is shrunk toward 1 (no tilt) harder.
tilt_apply <- function(s_raw, mass_o, lambda_max = KEY_LAMBDA_MAX, kappa = KEY_KAPPA) {
  lam <- lambda_max * mass_o / (mass_o + kappa)
  sweep(log(s_raw), 1, lam, `*`) |> exp()
}

# Fit s from a list of exclusions, each list(m = origin masses, t = destination totals).
# EM from s = 1 is a fixed point (every origin looks alike), so it starts from the
# destination mix of near-pure piles relative to the pooled mix.
fit_s <- function(EX, iters = 200L, pure = KEY_PURE) {
  n <- length(EX)
  s1 <- matrix(1, NO, ND)
  if (n < 20L) return(list(s = s1, iters = 0L, chg = NA_real_, n = n))
  Mm <- t(sapply(EX, `[[`, "m")); Tm <- t(sapply(EX, `[[`, "t"))
  av <- (Tm > 0) * 1
  tot <- colSums(Tm) / sum(Tm)
  s <- s1
  for (o in seq_len(NO)) {
    pu <- which(Mm[, o] / pmax(rowSums(Mm), 1e-9) >= pure)
    if (length(pu) >= 3L) {
      v <- colSums(Tm[pu, , drop = FALSE])
      s[o, ] <- pmax((v / sum(v)) / pmax(tot, 1e-6), 0.05)
    }
  }
  s <- s / rowMeans(s)
  G <- matrix(1, n, ND)
  chg <- NA_real_; it <- 0L
  for (it in seq_len(iters)) {
    A <- array(0, c(n, NO, ND))
    for (o in seq_len(NO)) A[, o, ] <- sweep(G * av, 2, s[o, ], `*`)
    Z <- apply(A, c(1, 2), sum); Z[Z <= 0] <- 1
    Wt <- (A / rep(Z, ND)) * rep(Mm, ND)
    got <- apply(Wt, c(1, 3), sum)
    r <- ifelse(av > 0, Tm / pmax(got, 1e-12), 1)
    G <- G * r
    Wf <- array(0, dim(Wt)); for (o in seq_len(NO)) Wf[, o, ] <- Wt[, o, ] * r
    num <- apply(Wf, c(2, 3), sum)
    den <- matrix(0, NO, ND)
    for (o in seq_len(NO)) den[o, ] <- colSums(Mm[, o] * G * av / Z[, o])
    snew <- num / den
    snew[!is.finite(snew) | den <= 0] <- 1
    snew <- snew / rowMeans(snew)
    chg <- max(abs(log(snew) - log(s))); s <- snew
    G <- G / rowMeans(G * av + (1 - av))
    if (chg < 1e-7) break
  }
  list(s = s, iters = it, chg = chg, n = n)
}

# ---- federal: candidate-level tracking over the AEC distribution-of-preferences ----------
fed_read_dop <- function(year) {
  x <- fread(sprintf("external/reference/aec/fed%d-dop.csv", year), showProgress = FALSE)
  x <- x[CalculationType %in% c("Preference Count", "Transfer Count")]
  w <- dcast(x, DivisionNm + CountNumber + CandidateID + PartyAb + PartyNm ~ CalculationType, value.var = "CalculationValue")
  setnames(w, c("Preference Count", "Transfer Count"), c("pref", "tr"))
  w[, cls := classify_party(PartyNm, PartyAb)]
  w
}

# Division two-party totals over ALL vote types (notional counts included). Downloaded
# from the AEC, columns mapped by header name (order differs by year). 2004 has no
# AEC file on disk: fall back to output/seat-tpp-estimates.csv (Labor TPP percent per
# seat) times the seat's formal votes.
TPPDIV_IDS <- c("2007" = 13745, "2010" = 15508, "2013" = 17496, "2016" = 20499, "2019" = 24310,
                "2022" = 27966, "2025" = 31496)
fed_tpp_div <- function(year, formal) {
  key <- as.character(year)
  if (key %in% names(TPPDIV_IDS)) {
    f <- sprintf("external/reference/aec/raw/tppdiv/HouseTppByDivisionDownload-%d.csv", TPPDIV_IDS[[key]])
    if (!file.exists(f)) {
      dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
      u <- sprintf("https://results.aec.gov.au/%d/Website/Downloads/HouseTppByDivisionDownload-%d.csv",
                   TPPDIV_IDS[[key]], TPPDIV_IDS[[key]])
      utils::download.file(u, f, quiet = TRUE, mode = "wb", headers = c("User-Agent" = "Mozilla/5.0 (auspol research)"))
    }
    t <- fread(f, skip = 1, showProgress = FALSE)
    a <- grep("^Australian Labor Party Votes$", names(t)); l <- grep("^Liberal/National Coalition Votes$", names(t))
    stopifnot(length(a) == 1L, length(l) == 1L)
    return(data.table(DivisionNm = t$DivisionNm, T_ALP = as.numeric(t[[a]]), T_LNP = as.numeric(t[[l]]), src = "aec division file"))
  }
  stopifnot(year == 2004L)
  # 2004: the AEC final counts for seats that ended Labor v Coalition (exact), and for the
  # few that did not, output/seat-tpp-estimates.csv (an ESTIMATE of the Labor TPP percent)
  # times the seat's formal votes.
  tc <- fread("external/elections/aec-fed-tcp.csv")
  tc <- tc[tc$election == "fed2004"]
  tw <- tc[, .(has_both = all(c("ALP", "LNP") %in% party), n = .N,
               T_ALP = sum(votes[party == "ALP"]), T_LNP = sum(votes[party == "LNP"])), by = seat]
  tw <- tw[tw$has_both & tw$n == 2L]
  e <- fread("output/seat-tpp-estimates.csv")[election == "fed2004"]
  est <- merge(formal, data.table(DivisionNm = formal$DivisionNm, seat_l = gsub("[^a-z]", "", tolower(formal$DivisionNm))), by = "DivisionNm")
  est <- merge(est, e[, .(seat_l = gsub("[^a-z]", "", tolower(s)), tpp)], by = "seat_l")
  est <- est[!est$DivisionNm %in% tw$seat]
  stopifnot(nrow(est) + nrow(tw) == nrow(formal))   # every seat has a two-party total
  rbind(data.table(DivisionNm = tw$seat, T_ALP = tw$T_ALP, T_LNP = tw$T_LNP, src = "aec final count"),
        data.table(DivisionNm = est$DivisionNm, T_ALP = est$formal * est$tpp / 100, T_LNP = est$formal * (1 - est$tpp / 100),
                   src = "seat-tpp-estimates x formal"))
}

# One division, one pass. cls_map lets a test swap the Labor / Coalition labels.
fed_track_seat <- function(d, s) {
  cands <- unique(d[, .(CandidateID, cls)])
  cid <- as.character(cands$CandidateID); cl <- setNames(match(cands$cls, ORIGS), cid)
  mass <- setNames(lapply(cid, function(.) numeric(NO)), cid)
  d0 <- d[d$CountNumber == 0]
  for (i in seq_len(nrow(d0))) { id <- as.character(d0$CandidateID[i]); mass[[id]][cl[[id]]] <- d0$pref[i] }
  tA <- numeric(NO); tL <- numeric(NO)
  EXs <- list(); diverged <- FALSE
  for (r in sort(setdiff(unique(d$CountNumber), 0))) {
    rr <- d[d$CountNumber == r]
    ex <- rr[rr$tr < 0]; po <- rr[rr$tr > 0]
    if (!nrow(ex)) next
    exid <- as.character(ex$CandidateID)
    leftcl <- cl[as.character(rr$CandidateID[rr$pref > 0])]
    # Divergence: a Labor or Coalition candidate is excluded with no other candidate of its
    # class left. The AEC's notional two-party count would NOT exclude them (it excludes
    # the next smallest non-major candidate), so the real distribution stops being a
    # guide from here and the mass still held by non-major candidates is settled below.
    bad <- FALSE
    for (e in exid) if (ORIGS[cl[[e]]] %in% TERMS && !any(leftcl == cl[[e]])) bad <- TRUE
    if (bad) { diverged <- TRUE; break }
    V <- -sum(ex$tr); M <- Reduce(`+`, mass[exid])
    for (e in exid) mass[[e]][] <- 0
    if (sum(M) <= 0) next
    M <- M * V / sum(M)
    tcls <- numeric(ND)
    for (i in seq_len(nrow(po))) { k <- cl[[as.character(po$CandidateID[i])]]; tcls[k] <- tcls[k] + po$tr[i] }
    tcls[ND] <- max(0, V - sum(tcls))
    Fm <- solve_g(M, tcls, s)
    EXs[[length(EXs) + 1L]] <- list(m = M, t = tcls)
    for (i in seq_len(nrow(po))) {
      p <- as.character(po$CandidateID[i]); k <- cl[[p]]
      share <- Fm[, k] * po$tr[i] / tcls[k]
      if (ORIGS[k] == "ALP") tA <- tA + share else if (ORIGS[k] == "LNP") tL <- tL + share
      else mass[[p]] <- mass[[p]] + share
    }
  }
  nonterm <- cid[!ORIGS[cl[cid]] %in% TERMS]
  held <- Reduce(`+`, mass[nonterm])
  list(tA = tA, tL = tL, held = held, diverged = diverged, ex = EXs)
}

# Mass still held by non-major candidates when the notional count departs from the real
# one is split between Labor and the Coalition so that the division's TOTAL two-party
# result (AEC division file) is reproduced; origins are tilted by their Labor:Coalition
# odds in s so a Greens ballot is not treated like a One Nation ballot.
fed_alloc_resid <- function(H, resA, resL, s) {
  z <- list(A = numeric(NO), L = numeric(NO))
  if (sum(H) <= 0 || (resA + resL) <= 0) return(z)
  fa <- min(1 - 1e-6, max(1e-6, resA / (resA + resL)))
  odds <- s[, match("ALP", ORIGS)] / s[, match("LNP", ORIGS)]; odds[!is.finite(odds)] <- 1
  shift <- tryCatch(uniroot(function(z0) sum(H * plogis(z0 + log(odds))) - fa * sum(H), c(-30, 30))$root,
                    error = function(e) qlogis(fa))
  pa <- plogis(shift + log(odds))
  list(A = H * pa, L = H * (1 - pa))
}

# All federal divisions of one year. Returns per-seat per-origin flows and the fitted tilt.
# fixed_s: use this tilt and do not refit (for the broken-input test).
fed_track_year <- function(year, lambda_max = KEY_LAMBDA_MAX, kappa = KEY_KAPPA, passes = KEY_PASSES, swap_major = FALSE, fixed_s = NULL) {
  D <- fed_read_dop(year)
  if (swap_major) D[, cls := ifelse(cls == "ALP", "LNP", ifelse(cls == "LNP", "ALP", cls))]
  formal <- D[D$CountNumber == 0, .(formal = sum(pref)), by = DivisionNm]
  fp <- D[D$CountNumber == 0, .(F_ALP = sum(pref[cls == "ALP"]), F_LNP = sum(pref[cls == "LNP"])), by = DivisionNm]
  TP <- fed_tpp_div(year, formal)
  if (swap_major) TP[, c("T_ALP", "T_LNP") := .(T_LNP, T_ALP)]
  TP <- merge(TP, fp, by = "DivisionNm")
  TP[, `:=`(GA = T_ALP - F_ALP, GL = T_LNP - F_LNP)]
  Dl <- split(D, D$DivisionNm)
  stopifnot(setequal(TP$DivisionNm, names(Dl)), !anyNA(TP$GA), !anyNA(TP$GL))   # every division has a two-party total
  mass_o <- sapply(ORIGS, function(o) sum(D$pref[D$CountNumber == 0 & D$cls == o]))
  s <- if (is.null(fixed_s)) matrix(1, NO, ND) else fixed_s
  fit <- NULL
  for (pass in 0:passes) {
    TR <- lapply(Dl, fed_track_seat, s = s)
    if (pass == passes || !is.null(fixed_s)) break
    EX <- unlist(lapply(TR, `[[`, "ex"), recursive = FALSE)
    fit <- fit_s(EX); s <- tilt_apply(fit$s, mass_o, lambda_max, kappa)
  }
  rows <- lapply(names(TR), function(x) {
    r <- TR[[x]]; z <- TP[TP$DivisionNm == x]
    resA <- z$GA - sum(r$tA[-match("ALP", ORIGS)]); resL <- z$GL - sum(r$tL[-match("LNP", ORIGS)])
    al <- if (r$diverged) fed_alloc_resid(r$held, resA, resL, s) else list(A = numeric(NO), L = numeric(NO))
    f0 <- D[D$DivisionNm == x & D$CountNumber == 0]
    Fo <- sapply(ORIGS, function(o) sum(f0$pref[f0$cls == o]))
    data.table(seat = x, diverged = r$diverged, origin = ORIGS, F_votes = Fo,
               toA_tracked = r$tA, toL_tracked = r$tL, toA_resid = al$A, toL_resid = al$L,
               held = sum(r$held), resA = resA, resL = resL,
               count_gainA = z$GA, count_gainL = z$GL)
  })
  list(seats = rbindlist(rows), s = s, fit = fit, mass_o = mass_o, tpp_src = TP$src[1], year = year)
}

# National key table from a fed_track_year result. alp_lnp_only = TRUE restricts to
# divisions whose real final two were Labor and the Coalition (the old key's scope).
fed_key_table <- function(res, alp_lnp_only = FALSE) {
  S <- res$seats
  if (alp_lnp_only) S <- S[S$diverged == FALSE]
  S <- S[S$origin %in% setdiff(ORIGS, TERMS)]
  K <- S[, .(A = sum(toA_tracked + toA_resid), L = sum(toL_tracked + toL_resid), F_votes = sum(F_votes),
             n_seats = sum(F_votes > 0)), by = origin]
  K[, `:=`(party = origin, a = A / (A + L), e = 0)]
  K[, .(party, a, e, F_votes, n_seats)]
}

# ---- class-level tracking (state elections and fed2001) --------------------------------------
# The transfer files give, per exclusion, the pile split by the RECIPIENTS' party class
# (to_n candidates per class are not needed). A class's candidates are pooled in one
# "bucket" holding origin masses; an exclusion of class f takes a share of the bucket:
#  * compulsory: the sum transferred, as a fraction of the bucket;
#  * optional preferential: the smallest remaining candidate of the class plus an equal
#    share of the class's received votes, never less than what was transferred; the
#    rest of the pile exhausts. THE PILE SIZE IS AN APPROXIMATION (the files do not
#    carry it); it is checked against the NSW 2011 detail file in FR2.
# Exclusions of Labor or Coalition candidates (second candidate of the same class) are
# skipped: they hold almost no minor-party origin mass.
class_track_seat <- function(fpseat, tr, optional, s, K) {
  unit <- function(k) { v <- numeric(NO); v[match(k, ORIGS)] <- 1; v }
  zero <- numeric(NO)
  classes <- unique(c(TERMS, K, tr$to, tr$from))
  R <- setNames(lapply(classes, function(.) zero), classes)
  own <- setNames(lapply(classes, function(.) numeric(0)), classes)
  Fv <- sapply(K, function(k) sum(fpseat$votes[fpseat$party == k]))
  for (k in K) own[[k]] <- sort(fpseat$votes[fpseat$party == k])
  skipped <- 0L; exh <- numeric(NO); EXs <- list()
  tr <- tr[order(tr$round)]
  for (r in unique(tr$round)) {
    rr <- tr[tr$round == r]
    for (f in unique(rr$from)) {
      g <- rr[rr$from == f]
      if (!f %in% K) { skipped <- skipped + 1L; next }
      t_by <- tapply(g$votes, g$to, sum); t <- sum(t_by)
      if (t <= 0) next
      if (!optional) {
        mvec <- sum(own[[f]]) * unit(f) + R[[f]]
        sm <- sum(mvec)
        if (sm <= 0) { mvec <- unit(f) * t; sm <- t }
        phi <- min(1, t / sm)
        pile <- mvec * phi
        own[[f]] <- own[[f]] * (1 - phi); R[[f]] <- R[[f]] * (1 - phi)
      } else {
        n <- max(1L, length(own[[f]]))
        o <- if (length(own[[f]])) min(own[[f]]) else 0
        pile <- o * unit(f) + R[[f]] / n
        if (length(own[[f]])) own[[f]] <- own[[f]][-which.min(own[[f]])]
        R[[f]] <- R[[f]] * (1 - 1 / n)
      }
      sp <- sum(pile)
      if (sp <= 0) next
      tcls <- numeric(ND)
      for (d in names(t_by)) { j <- match(d, ORIGS); if (!is.na(j)) tcls[j] <- tcls[j] + t_by[[d]] }
      if (!optional) {
        # compulsory: nothing exhausts, so the pile IS what was transferred; where the tracked
        # bucket is smaller than the transfers (ballots the class bucket does not hold) the
        # pile is scaled up to the transferred total with the same composition
        Fm <- solve_g(pile * t / sp, tcls, s)
        EXs[[length(EXs) + 1L]] <- list(m = pile * t / sp, t = tcls)
      } else {
        Vp <- max(sp, t)
        tcls[ND] <- Vp - t
        Fm <- solve_g(pile * Vp / sp, tcls, s) * (sp / Vp)       # conserve the mass actually tracked
        EXs[[length(EXs) + 1L]] <- list(m = pile * Vp / sp, t = tcls)
      }
      exh <- exh + Fm[, ND]
      for (d in names(t_by)) { j <- match(d, ORIGS); if (!is.na(j)) R[[d]] <- R[[d]] + Fm[, j] }
    }
  }
  pick <- function(v) setNames(v[match(K, ORIGS)], K)
  list(F = Fv, toALP = pick(R[["ALP"]]), toLNP = pick(R[["LNP"]]), exh = pick(exh), skipped = skipped, ex = EXs)
}

# Track a set of seats with KEY_PASSES refits of the tilt. Returns the per-seat results
# (same fields the first version returned, F / toALP / toLNP over K) and the tilt used.
class_track_set <- function(fp, tr_el, seats, optional, K, lambda_max = KEY_LAMBDA_MAX, kappa = KEY_KAPPA,
                            passes = KEY_PASSES, fixed_s = NULL) {
  fpl <- split(fp, fp$seat); trl <- split(tr_el, tr_el$seat)
  mass_o <- sapply(ORIGS, function(o) if (o %in% K) sum(fp$votes[fp$seat %in% seats & fp$party == o]) else 0)
  s <- if (is.null(fixed_s)) matrix(1, NO, ND) else fixed_s
  fit <- NULL
  for (pass in 0:passes) {
    res <- lapply(seats, function(x) class_track_seat(fpl[[x]], trl[[x]], optional, s, K))
    if (pass == passes || !is.null(fixed_s)) break
    EX <- unlist(lapply(res, `[[`, "ex"), recursive = FALSE)
    fit <- fit_s(EX); s <- tilt_apply(fit$s, mass_o, lambda_max, kappa)
  }
  list(res = res, s = s, fit = fit, mass_o = mass_o)
}

# ---- one federal election as a key object (same shape the class-level key returns) ---------
fed_key_object <- function(year, ...) {
  res <- fed_track_year(year, ...)
  S <- res$seats
  minors <- setdiff(ORIGS, TERMS)
  by_seat <- S[S$origin %in% minors, .(tA = sum(toA_tracked), tL = sum(toL_tracked), F = sum(F_votes)), by = seat]
  sd <- unique(S[, .(seat, diverged, count_gainA, count_gainL)])
  by_seat <- merge(by_seat, sd, by = "seat")
  nd <- by_seat[by_seat$diverged == FALSE]
  chk <- c(tracked_alp_gain = sum(nd$tA), count_alp_gain = sum(nd$count_gainA),
           tracked_lnp_gain = sum(nd$tL), count_lnp_gain = sum(nd$count_gainL))
  list(key = fed_key_table(res), key_alplnp = fed_key_table(res, TRUE), seats = unique(S$seat), chk = chk,
       skipped = 0L, dropped = 0L, n_diverged = sum(sd$diverged), res = res,
       per_seat = data.table(seat = nd$seat, tr = nd$tA, gain = nd$count_gainA))
}
