# Estimate preference flows from an election's own results, and validate the
# estimator against published distributions of preferences.
#
# Spec: docs/plans/flow-estimation-from-results-2026-10-13.md (Pete's decision).
# Review written by this script: docs/reviews/flow-estimation-validation-2026-10-13.md
# Output: output/flows-estimated.csv (percent units, same shape as
# load_preference_flows(): flow_alp, exhaust).
#
# Check codes: FR1 source choice and seat accounting, FR2 answer-key integrity,
# FR3 estimator dry run, FR4 validation, FR5 bar. ("FR" is unused elsewhere.)
#
# Run:  powershell.exe -Command 'Rscript "scripts/estimate_flows_from_results.R"'
#       add --dry to stop after the fed2022 / nsw2023 dry run.
#
# THE METHOD AND THE PASS BAR WERE FIXED BEFORE THE FIRST RUN. Constants below
# (bootstrap size, minimum seats) were chosen in advance and are not tuned.
#
# Data model. For a seat whose final two are ALP and LNP, with first
# preferences F (by party class) and final counts T:
#   T_ALP - F_ALP                         = sum_k a_k F_k
#   sum_k F_k - (T_ALP-F_ALP) - (T_LNP-F_LNP) = sum_k e_k F_k   (optional pref.)
# Constrained least squares in share form (rows divided by the seat's minor
# vote M, weighted by M), bootstrap over seats, then partial pooling toward a
# prior (nearest earlier same-state election with a published distribution,
# else the federal election in the most recent strictly earlier year).

options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(quadprog))

ARGS    <- commandArgs(trailingOnly = TRUE)
DRY     <- "--dry" %in% ARGS
B_BOOT  <- 300L        # bootstrap replicates over seats
MIN_SEATS <- 8L        # fewer used seats than this: no fit, flows = prior
RIDGE   <- 1e-6        # numerical only: makes unidentified directions sit at the prior
BAR_MAE <- 5           # pass bar, points of a_k
KEY_MIN_SEATS <- 5L    # a class counts in the bar if present in >= this many key seats
KEY_MIN_VOTES <- 20000 # ... and holds at least this many first preferences there
set.seed(20261013)

EL   <- election_data_path()
ARCH <- file.path(EL, "archive")
OUT  <- "output/flows-estimated.csv"
REVIEW <- "docs/reviews/flow-estimation-validation-2026-10-13.md"
MINORS <- c("GRN", "ONP", "OTH", "OTH_RIGHT", "IND")

rd <- function(f) fread(f, showProgress = FALSE)
say <- function(...) cat(sprintf(...), "\n", sep = "")

# ---- which elections, and are they compulsory preferential ------------------
files <- list.files(ARCH, "-firstprefs\\.csv$")
ELS <- data.table(
  year = as.integer(sub("^(\\d{4}).*", "\\1", files)),
  region = sub("^\\d{4}([a-z]+)-.*", "\\1", files))
ELS <- ELS[year >= 2001 & year <= 2025 & region %in% c("fed", "nsw", "vic", "qld", "sa", "wa")]
ELS <- rbind(ELS, data.table(year = 2026L, region = "sa"))
ELS[, election := paste0(region, year)]
setorder(ELS, region, year)
ELS[, optional := region == "nsw" | (region == "qld" & year < 2017)]
stopifnot(!anyDuplicated(ELS$election))

# ---- transfers (answer key raw material) -------------------------------------
TXF <- list(
  fed = c("aec-fed-2001-transfers.csv", "aec-fed-transfers.csv"),
  nsw = c("nswec-2011-nsw-transfers.csv", "nswec-nsw-transfers.csv"),
  vic = c("vec-2006-vic-transfers.csv", "vec-2010-vic-transfers.csv", "vec-2014-vic-transfers.csv",
          "vec-2018-vic-transfers.csv", "vec-2022-vic-transfers.csv"),
  qld = "ecq-qld-transfers.csv", sa = "ecsa-2026-sa-transfers.csv", wa = "waec-wa-transfers.csv")
TX <- rbindlist(lapply(unlist(TXF), function(f) {
  x <- rd(file.path(EL, f))[, .(election, seat, round, from, to, votes)]
  x[, src := f]; x }), use.names = TRUE)
stopifnot(!anyNA(TX$votes), all(TX$votes >= 0))
say("FR1 transfer files read: %d rows, elections with transfers: %s", nrow(TX),
    paste(sort(unique(TX$election)), collapse = " "))

# ---- first preferences and final counts per election -------------------------
# Source rule (stated in the review): official file where it has BOTH first
# preferences and the final count for the election AND the optional-preferential
# tracking does not need candidate rows (official files are one row per party
# class); otherwise the uniform archive file (candidate rows); SA 2026 has only
# official first preferences, final counts come from replaying its transfers.
load_election <- function(region, year, election, optional) {
  arch_fp  <- file.path(ARCH, sprintf("%d%s-firstprefs.csv", year, region))
  arch_tcp <- file.path(ARCH, sprintf("%d%s-tcp.csv", year, region))
  off_fp <- off_tcp <- NA_character_
  if (region == "fed") {
    off_fp  <- if (year == 2001) "aec-fed-2001-firstprefs.csv" else "aec-fed-firstprefs.csv"
    off_tcp <- if (year == 2001) "aec-fed-2001-tcp.csv" else "aec-fed-tcp.csv"
  }
  pick <- function(f, e) { x <- rd(f); if ("election" %in% names(x)) x <- x[x$election == e]
    x[, .(seat, party, votes)] }
  if (!is.na(off_fp) && !optional) {
    fp <- pick(file.path(EL, off_fp), election); tcp <- pick(file.path(EL, off_tcp), election)
    src <- "official (aec)"
    if (file.exists(arch_fp)) {   # cross-check against the archive copy
      a <- pick(arch_fp, election)[, .(av = sum(votes)), by = seat]
      o <- fp[, .(ov = sum(votes)), by = seat]
      m <- merge(a, o, by = "seat")
      src <- sprintf("%s; archive agrees on %d/%d seats (>0.5%% diff: %d)", src,
                     sum(abs(m$av - m$ov) <= 0.005 * m$ov), nrow(m),
                     sum(abs(m$av - m$ov) > 0.005 * m$ov))
    }
  } else if (file.exists(arch_fp) && file.exists(arch_tcp)) {
    fp <- pick(arch_fp, election); tcp <- pick(arch_tcp, election); src <- "archive"
  } else {
    stopifnot(election == "sa2026")
    fp <- pick(file.path(EL, "ecsa-2026-sa-firstprefs.csv"), election)
    tcp <- NULL; src <- "official (ecsa) first prefs; final counts replayed from transfers"
  }
  list(fp = fp, tcp = tcp, src = src)
}

# Seat table: F by class, final two, T, flags. One row per seat with ALP v LNP final two.
build_seats <- function(L, election) {
  fp <- L$fp
  Fw <- dcast(fp[, .(votes = sum(votes)), by = .(seat, party)], seat ~ party, value.var = "votes", fill = 0)
  for (cl in c("ALP", "LNP", MINORS)) if (!cl %in% names(Fw)) Fw[, (cl) := 0]
  if (!is.null(L$tcp)) {
    t2 <- L$tcp[, .(n = .N, pairs = paste(sort(party), collapse = "+"),
                    T_ALP = sum(votes[party == "ALP"]), T_LNP = sum(votes[party == "LNP"])), by = seat]
    av <- t2[pairs == "ALP+LNP"]
    other <- t2[pairs != "ALP+LNP"]
  } else {   # replay: ALP and LNP never excluded, seat has a count
    tr <- TX[TX$election == election]
    ex <- tr[, .(excl_major = any(from %in% c("ALP", "LNP"))), by = seat]
    rc <- tr[, .(rALP = sum(votes[to == "ALP"]), rLNP = sum(votes[to == "LNP"])), by = seat]
    av <- merge(ex[excl_major == FALSE], rc, by = "seat")
    av <- merge(av, Fw[, .(seat, fa = ALP, fl = LNP)], by = "seat")
    av[, `:=`(T_ALP = fa + rALP, T_LNP = fl + rLNP)]
    other <- data.table(seat = setdiff(Fw$seat, av$seat))
  }
  S <- merge(Fw, av[, .(seat, T_ALP, T_LNP)], by = "seat")
  S[, M := rowSums(.SD), .SDcols = MINORS]
  S[, moved := (T_ALP - ALP) + (T_LNP - LNP)]
  S[, used := M > 0 & moved > 0]
  list(S = S, n_fp_seats = nrow(Fw), n_final_other = nrow(other))
}

# ---- answer key: follow every minor vote to ALP / LNP / exhausted -------------
# Transfers files give, per exclusion, how the excluded candidate's pile split by
# party class of the recipient (exhausted votes are not recorded). A pile is a
# mix of ORIGINS (the party class whose first preference it started as). We
# carry that mix: class buckets hold origin-mass vectors; an exclusion of class
# f moves a pile with the bucket's composition to its recipients. Pile size:
#  * compulsory: the sum of the transfers (nothing exhausts);
#  * optional: the excluded candidate's own first preferences (smallest
#    remaining candidate of that class) plus an equal share of the class's
#    received votes, and never less than what was transferred. Anything not
#    transferred exhausts. THIS PILE SIZE IS AN APPROXIMATION (the files do not
#    carry it); it is checked against the NSW 2011 detail file in FR2.
# Exclusions of ALP or LNP candidates (second candidate of the same class) are
# skipped: they hold almost no minor-party origin mass.
track_seat <- function(fpseat, tr, optional) {
  K <- MINORS
  unit <- function(k) { v <- setNames(numeric(length(K)), K); v[k] <- 1; v }
  zero <- setNames(numeric(length(K)), K)
  F <- sapply(K, function(k) sum(fpseat$votes[fpseat$party == k]))
  classes <- unique(c("ALP", "LNP", K, tr$to, tr$from))
  R <- setNames(lapply(classes, function(.) zero), classes)
  own <- setNames(lapply(classes, function(.) numeric(0)), classes)
  for (k in K) own[[k]] <- sort(fpseat$votes[fpseat$party == k])
  skipped <- 0L
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
        pile_vec <- mvec * phi
        denom <- sum(pile_vec)                       # distribute exactly the pile
        own[[f]] <- own[[f]] * (1 - phi); R[[f]] <- R[[f]] * (1 - phi)
      } else {
        n <- max(1L, length(own[[f]]))
        o <- if (length(own[[f]])) min(own[[f]]) else 0
        pile_vec <- o * unit(f) + R[[f]] / n
        denom <- max(sum(pile_vec), t)
        if (length(own[[f]])) own[[f]] <- own[[f]][-which.min(own[[f]])]
        R[[f]] <- R[[f]] * (1 - 1 / n)
      }
      if (sum(pile_vec) <= 0) next
      for (d in names(t_by)) R[[d]] <- R[[d]] + pile_vec * (t_by[[d]] / denom)
    }
  }
  list(F = F, toALP = R[["ALP"]], toLNP = R[["LNP"]], skipped = skipped)
}

key_for_election <- function(S, tr_el, fp, optional) {
  seats <- intersect(S[used == TRUE]$seat, unique(tr_el$seat))
  if (!length(seats)) return(NULL)
  # DATA-INTEGRITY RULE FOR THE KEY (fixed before validation was run): a seat
  # enters the key only if the transfers file accounts for the seat's own count:
  # transfers to ALP and to LNP each within max(5%, 300 votes) of the change in
  # that candidate's count. Some Victorian and NSW distribution files are partial
  # for a seat (e.g. Carrum 2022: 80 votes transferred to ALP, count says 4,285).
  Sk0 <- S[match(seats, S$seat)]
  dir <- tr_el[, .(dA = sum(votes[to == "ALP"]), dL = sum(votes[to == "LNP"])), by = seat]
  Sk0 <- merge(Sk0, dir, by = "seat", all.x = TRUE)
  gA <- Sk0$T_ALP - Sk0$ALP; gL <- Sk0$T_LNP - Sk0$LNP
  okA <- abs(Sk0$dA - gA) <= pmax(0.05 * abs(gA), 300)
  okL <- abs(Sk0$dL - gL) <= pmax(0.05 * abs(gL), 300)
  keep <- !is.na(okA) & !is.na(okL) & okA & okL
  dropped <- sum(!keep)
  seats <- Sk0$seat[keep]
  if (!length(seats)) return(NULL)
  res <- lapply(seats, function(s)
    track_seat(fp[fp$seat == s], tr_el[tr_el$seat == s], optional))
  F  <- Reduce(`+`, lapply(res, `[[`, "F"))
  A  <- Reduce(`+`, lapply(res, `[[`, "toALP"))
  Lw <- Reduce(`+`, lapply(res, `[[`, "toLNP"))
  nseat <- sapply(MINORS, function(k) sum(sapply(res, function(z) z$F[k] > 0)))
  tA <- sum(sapply(res, function(z) sum(z$toALP)))
  Sk <- S[match(seats, S$seat)]
  chk <- c(tracked_alp_gain = tA, count_alp_gain = sum(Sk$T_ALP - Sk$ALP),
           tracked_lnp_gain = sum(Lw), count_lnp_gain = sum(Sk$T_LNP - Sk$LNP))
  a <- if (optional) A / F else A / (A + Lw)
  e <- if (optional) (F - A - Lw) / F else rep(0, length(F))
  e[!is.finite(e)] <- 0; a[!is.finite(a)] <- NA_real_
  list(key = data.table(party = MINORS, a = unname(a), e = unname(e), F_votes = unname(F),
                        n_seats = unname(nseat)),
       seats = seats, chk = chk, skipped = sum(sapply(res, `[[`, "skipped")), dropped = dropped,
       per_seat = data.table(seat = seats, tr = sapply(res, function(z) sum(z$toALP)),
                             gain = Sk$T_ALP - Sk$ALP))
}

# ---- the estimator -------------------------------------------------------------
fit_qp <- function(X1, y1, X2, y2, w, optional, prior_a, prior_e) {
  K <- ncol(X1)
  if (optional) {
    X <- rbind(cbind(X1, matrix(0, nrow(X1), K)), cbind(matrix(0, nrow(X2), K), X2))
    y <- c(y1, y2); ww <- c(w, w)
    pr <- c(prior_a, prior_e)
  } else { X <- X1; y <- y1; ww <- w; pr <- prior_a }
  p <- ncol(X)
  XtW <- t(X * ww)
  D <- XtW %*% X + RIDGE * diag(p)
  d <- as.numeric(XtW %*% y) + RIDGE * pr
  if (optional) {
    A <- rbind(diag(p), cbind(-diag(K), -diag(K)))[, , drop = FALSE]
    A <- rbind(diag(p), -cbind(diag(K), diag(K)))
    b0 <- c(rep(0, p), rep(-1, K))
  } else {
    A <- rbind(diag(p), -diag(p)); b0 <- c(rep(0, p), rep(-1, p))
  }
  sol <- tryCatch(solve.QP(D, d, t(A), b0)$solution, error = function(e) { message("FR3 solve.QP failed: ", conditionMessage(e)); rep(NA_real_, p) })
  sol
}

estimate_election <- function(S, K, optional, prior) {
  U <- S[used == TRUE]
  Mv <- U$M
  Fm <- as.matrix(U[, ..K]) / Mv
  y1 <- ((U$T_ALP - U$ALP) / Mv)
  y2 <- ((U$M - (U$T_ALP - U$ALP) - (U$T_LNP - U$LNP)) / Mv)
  w  <- Mv / mean(Mv)
  Kn <- length(K)
  pa <- prior$a; pe <- prior$e
  fit <- function(idx) {
    s <- fit_qp(Fm[idx, , drop = FALSE], y1[idx], Fm[idx, , drop = FALSE], y2[idx], w[idx],
                optional, pa, pe)
    if (optional) list(a = s[1:Kn], e = s[(Kn + 1):(2 * Kn)]) else list(a = s, e = rep(0, Kn))
  }
  f0 <- fit(seq_len(nrow(U)))
  bs <- lapply(seq_len(B_BOOT), function(i) fit(sample.int(nrow(U), replace = TRUE)))
  Ba <- do.call(rbind, lapply(bs, `[[`, "a")); Be <- do.call(rbind, lapply(bs, `[[`, "e"))
  list(a = f0$a, e = f0$e, Ba = Ba, Be = Be, n_used = nrow(U))
}

# Shrink toward the prior. Empirical-Bayes moment estimate of the prior's own
# spread: tau2 = max(0, mean(dev^2 - se^2)) over classes; w = tau2/(tau2+se^2).
shrink <- function(est, prior, K, optional) {
  Kn <- length(K)
  se_a <- apply(est$Ba, 2, sd, na.rm = TRUE); se_e <- apply(est$Be, 2, sd, na.rm = TRUE)
  dev_a <- est$a - prior$a; dev_e <- est$e - prior$e
  tau2_a <- max(0, mean(dev_a^2 - se_a^2, na.rm = TRUE))
  wa <- ifelse(se_a <= 0, 1, tau2_a / (tau2_a + se_a^2))
  if (optional) {
    tau2_e <- max(0, mean(dev_e^2 - se_e^2, na.rm = TRUE))
    we <- ifelse(se_e <= 0, 1, tau2_e / (tau2_e + se_e^2))
  } else { we <- rep(0, Kn) }
  a <- prior$a + wa * dev_a
  e <- if (optional) prior$e + we * dev_e else rep(0, Kn)
  over <- pmax(1, a + e); a <- a / over; e <- e / over
  # interval: percentiles of the bootstrap draws shrunk with the fixed weights
  qa <- sapply(seq_len(Kn), function(j) quantile(prior$a[j] + wa[j] * (est$Ba[, j] - prior$a[j]), c(.05, .95), na.rm = TRUE))
  qe <- sapply(seq_len(Kn), function(j) quantile(prior$e[j] + we[j] * (est$Be[, j] - prior$e[j]), c(.05, .95), na.rm = TRUE))
  # secondary interval: posterior sd = sqrt(w) * se
  data.table(party = K, a = a, e = e, se_a = wa * se_a, se_e = we * se_e, wa = wa, we = we,
             a_lo = qa[1, ], a_hi = qa[2, ], e_lo = qe[1, ], e_hi = qe[2, ],
             post_lo = a - 1.645 * sqrt(wa) * se_a, post_hi = a + 1.645 * sqrt(wa) * se_a,
             raw_a = est$a, raw_e = est$e, raw_se_a = se_a)
}

# ---- run: seat tables, keys ----------------------------------------------------
LOAD <- list(); SEATS <- list(); KEYS <- list(); LOG <- list()
for (i in seq_len(nrow(ELS))) {
  el <- ELS$election[i]; rg <- ELS$region[i]; yr <- ELS$year[i]; op <- ELS$optional[i]
  L <- load_election(rg, yr, el, op)
  sb <- build_seats(L, el)
  S <- sb$S
  LOAD[[el]] <- L; SEATS[[el]] <- S
  tr_el <- TX[TX$election == el]
  k <- if (nrow(tr_el)) key_for_election(S, tr_el, L$fp, op) else NULL
  if (!is.null(k)) KEYS[[el]] <- k
  LOG[[el]] <- data.table(election = el, source = L$src, seats_fp = sb$n_fp_seats,
    final_alp_lnp = nrow(S), final_other = sb$n_final_other, used = sum(S$used),
    no_count = sum(!S$used), has_key = !is.null(k), key_seats = if (is.null(k)) 0L else length(k$seats))
}
LOG <- rbindlist(LOG)
cat("\nFR1  Seat accounting per election. final_alp_lnp = seats whose final two are ALP and LNP;\n")
cat("     used = those with a count taken (minor votes moved); no_count = decided on first preferences.\n")
print(LOG[, .(election, seats_fp, final_alp_lnp, final_other, used, no_count, key_seats)], nrows = 200)
cat("\nFR1  Source used per election\n"); print(LOG[, .(election, source)], nrows = 200)

# answer-key integrity
cat("\nFR2  Answer-key integrity: votes the tracker sends to ALP / LNP vs the seat counts' own change\n")
cat("     (ratio near 1.00 is good; both measure the same votes).\n")
CHK <- rbindlist(lapply(names(KEYS), function(el) {
  z <- KEYS[[el]]$chk
  data.table(election = el, key_seats = length(KEYS[[el]]$seats),
             alp_ratio = round(z[["tracked_alp_gain"]] / z[["count_alp_gain"]], 3),
             lnp_ratio = round(z[["tracked_lnp_gain"]] / z[["count_lnp_gain"]], 3),
             skipped_major_exclusions = KEYS[[el]]$skipped, seats_dropped_incomplete = KEYS[[el]]$dropped)
}))
print(CHK, nrows = 200)
for (el in CHK[alp_ratio < 0.9 | alp_ratio > 1.1]$election) {
  ps <- KEYS[[el]]$per_seat[, ratio := tr / gain][order(ratio)]
  say("FR2  %s worst seats (tracked / count gain):", el); print(head(ps, 4))
}

# NSW 2011 detail file: do tracked exhausted votes match the published ones?
det <- rd(file.path(EL, "nswec-2011-nsw-transfers-detail.csv"))
ex_pub <- det[to == "EXHAUSTED", .(pub_exhausted = sum(votes)), by = seat]
if ("nsw2011" %in% names(KEYS)) {
  ks <- KEYS[["nsw2011"]]$seats
  S11 <- SEATS[["nsw2011"]][match(ks, SEATS[["nsw2011"]]$seat)]
  imp <- sum(S11$M - (S11$T_ALP - S11$ALP) - (S11$T_LNP - S11$LNP))
  pub <- sum(ex_pub[seat %in% ks]$pub_exhausted)
  trk <- sum(KEYS[["nsw2011"]]$key[, F_votes * e], na.rm = TRUE)
  say("FR2  NSW 2011, %d key seats: exhausted votes published in the distributions %s; implied by final counts %s; tracked %s",
      length(ks), format(pub, big.mark = ","), format(round(imp), big.mark = ","), format(round(trk), big.mark = ","))
}

# ---- priors ----------------------------------------------------------------------
KEYTAB <- rbindlist(lapply(names(KEYS), function(el) {
  k <- KEYS[[el]]$key; k[, `:=`(election = el, region = ELS[election == el]$region,
                                year = ELS[election == el]$year)]; k }))
prior_for <- function(el) {
  rg <- ELS[election == el]$region; yr <- ELS[election == el]$year
  have <- unique(KEYTAB[, .(election, region, year)])
  cand <- have[region == rg & year < yr][order(-year)]
  src <- NA_character_
  if (nrow(cand)) src <- cand$election[1]
  else {
    f <- have[region == "fed" & year < yr][order(-year)]
    if (nrow(f) && rg != "fed") src <- f$election[1]
  }
  if (is.na(src)) return(NULL)
  k <- KEYTAB[election == src]
  a <- setNames(rep(NA_real_, length(MINORS)), MINORS); e <- a
  a[k$party] <- k$a; e[k$party] <- k$e
  # a class the prior election lacks (e.g. ONP before it ran) or holds on <5
  # seats: use the mean of the classes the prior has (flagged by prior_source)
  thin <- !(MINORS %in% k[n_seats >= 3 & is.finite(a)]$party)
  filled <- character(0)
  if (any(thin | is.na(a))) {
    kk <- k[is.finite(a) & is.finite(e)]
    m_a <- weighted.mean(kk$a, kk$F_votes); m_e <- weighted.mean(kk$e, kk$F_votes)
    filled <- MINORS[thin | is.na(a)]
    a[filled] <- m_a; e[filled] <- m_e
  }
  list(a = a, e = e, source = src, filled = filled)
}

run_election <- function(el) {
  S <- SEATS[[el]]; op <- ELS[election == el]$optional
  pr <- prior_for(el)
  U <- S[used == TRUE]
  K <- MINORS[colSums(as.matrix(U[, ..MINORS])) > 0]
  nseat <- sapply(K, function(k) sum(U[[k]] > 0))
  if (is.null(pr)) pr <- list(a = setNames(rep(0.5, 5), MINORS), e = setNames(rep(0, 5), MINORS),
                              source = "none", filled = character(0))
  prior <- list(a = pr$a[K], e = pr$e[K])
  if (nrow(U) < MIN_SEATS) {
    return(list(el = el, tab = data.table(party = K, a = prior$a, e = prior$e, se_a = NA_real_, se_e = NA_real_,
                  wa = 0, we = 0, a_lo = NA_real_, a_hi = NA_real_, e_lo = NA_real_, e_hi = NA_real_,
                  post_lo = NA_real_, post_hi = NA_real_, raw_a = NA_real_, raw_e = NA_real_,
                  raw_se_a = NA_real_), n_used = nrow(U), nseat = nseat, pr = pr, K = K))
  }
  est <- estimate_election(S, K, op, prior)
  tab <- shrink(est, prior, K, op)
  if (pr$source == "none") { tab[, `:=`(a = raw_a, e = raw_e, wa = 1, we = 1)] }
  list(el = el, tab = tab, n_used = est$n_used, nseat = nseat, pr = pr, K = K)
}

# ---- dry run ---------------------------------------------------------------------
show_cmp <- function(r) {
  el <- r$el; k <- KEYS[[el]]$key
  t <- merge(r$tab[, .(party, est_a = round(100 * a, 1), lo = round(100 * a_lo, 1), hi = round(100 * a_hi, 1),
                       raw_a = round(100 * raw_a, 1), est_e = round(100 * e, 1), w = round(wa, 2))],
             k[, .(party, key_a = round(100 * a, 1), key_e = round(100 * e, 1), key_seats = n_seats,
                   key_votes = F_votes)], by = "party", all.x = TRUE)
  t[, err_a := round(est_a - key_a, 1)]
  say("\nFR3  DRY RUN %s: %d seats used; prior %s; filled classes: %s", el, r$n_used, r$pr$source,
      if (length(r$pr$filled)) paste(r$pr$filled, collapse = ",") else "none")
  say("     a = share of the class's first preferences ending with Labor (percent); e = share exhausted.")
  print(t)
}
DRYTXT <- capture.output(for (el in c("fed2022", "nsw2023")) show_cmp(run_election(el)))
cat(DRYTXT, sep = "
")
if (DRY) { cat("\n--dry: stopping after the dry run.\n"); quit(save = "no") }

# ---- all elections ---------------------------------------------------------------
RES <- lapply(ELS$election, run_election); names(RES) <- ELS$election

# Output file
OUTT <- rbindlist(lapply(RES, function(r) {
  e <- ELS[election == r$el]
  t <- r$tab
  data.table(election = r$el, region = e$region, year = e$year, party = t$party,
             flow_alp = round(100 * t$a, 2), exhaust = round(100 * t$e, 2),
             se_flow = round(100 * t$se_a, 2), se_exhaust = round(100 * t$se_e, 2),
             n_seats = as.integer(r$nseat[t$party]),
             prior_source = if (r$pr$source == "none") "none" else
               paste0(r$pr$source, ifelse(t$party %in% r$pr$filled, " (class mean)", "")),
             pool_weight = round(t$wa, 3),
             answer_key_available = r$el %in% names(KEYS))
}))
dir.create("output", showWarnings = FALSE)
fwrite(OUTT, OUT)
say("\nwrote %s: %d rows, %d elections", OUT, nrow(OUTT), uniqueN(OUTT$election))
stopifnot(!anyNA(OUTT$flow_alp), all(OUTT$flow_alp >= 0 & OUTT$flow_alp <= 100))

# ---- validation ----------------------------------------------------------------------
SPEC_TEST <- c(paste0("fed", c(2004, 2007, 2010, 2013, 2016, 2019, 2022, 2025)),
               paste0("nsw", c(2011, 2015, 2019, 2023)), paste0("vic", c(2006, 2010, 2014, 2018, 2022)),
               paste0("qld", c(2017, 2020, 2024)), paste0("sa", c(2018, 2022, 2026)))
WA_TEST <- paste0("wa", c(2005, 2008, 2013, 2017, 2021, 2025))   # supplementary: not in the plan's list
VAL <- rbindlist(lapply(intersect(c(SPEC_TEST, WA_TEST), names(KEYS)), function(el) {
  r <- RES[[el]]; k <- KEYS[[el]]$key
  t <- merge(r$tab, k[, .(party, key_a = a, key_e = e, key_votes = F_votes, key_seats = n_seats)], by = "party")
  borrow <- prior_for(el)
  t[, `:=`(election = el, prior = r$pr$source,
           borrow_a = if (is.null(borrow)) NA_real_ else borrow$a[party],
           borrow_e = if (is.null(borrow)) NA_real_ else borrow$e[party],
           in_spec = el %in% SPEC_TEST)]
  t
}), fill = TRUE)
VAL[, `:=`(err_a = 100 * (a - key_a), err_e = 100 * (e - key_e),
           berr_a = 100 * (borrow_a - key_a), berr_e = 100 * (borrow_e - key_e),
           raw_err_a = 100 * (raw_a - key_a),
           cov_a = !is.na(a_lo) & key_a >= a_lo - 1e-9 & key_a <= a_hi + 1e-9,
           cov_post = !is.na(post_lo) & key_a >= post_lo & key_a <= post_hi,
           has_int = !is.na(a_lo) & !is.na(wa))]
VAL[, in_bar_class := party %in% c("GRN", "ONP") & key_seats >= KEY_MIN_SEATS & key_votes >= KEY_MIN_VOTES]

pt <- function(x, d = 1) formatC(x, format = "f", digits = d)
cat("\nFR4  Per election and class. est/key/borrow = percent of the class's first preferences ending with\n")
cat("     Labor (a) or exhausting (e); err = estimate minus key; lower |err| is better; cov = key inside the 90% interval.\n")
print(VAL[, .(election, party, key_seats, key_votes, key_a = pt(100 * key_a), est_a = pt(100 * a), raw_a = pt(100 * raw_a),
              borrow_a = pt(100 * borrow_a), err_a = pt(err_a), berr_a = pt(berr_a),
              key_e = pt(100 * key_e), est_e = pt(100 * e), cov = cov_a, w = pt(wa, 2))], nrows = 400)

BAR <- function(d) {
  b <- d[in_bar_class == TRUE & !is.na(berr_a)]
  data.table(cells = nrow(b), est_MAE = mean(abs(b$err_a)), borrow_MAE = mean(abs(b$berr_a)),
             raw_MAE = mean(abs(b$raw_err_a)),
             GRN_est = mean(abs(b[party == "GRN"]$err_a)), GRN_borrow = mean(abs(b[party == "GRN"]$berr_a)),
             ONP_est = mean(abs(b[party == "ONP"]$err_a)), ONP_borrow = mean(abs(b[party == "ONP"]$berr_a)),
             nGRN = sum(b$party == "GRN"), nONP = sum(b$party == "ONP"))
}
b_spec <- BAR(VAL[in_spec == TRUE]); b_all <- BAR(VAL)
cat("\nFR5  Pass bar (set before running): mean |error| of a_k on Greens and One Nation cells under 5 points,\n")
cat("     and no worse than borrowing the nearest earlier election's actual flows. Points; lower is better.\n")
print(rbind(cbind(set = "plan test set", b_spec), cbind(set = "plus WA", b_all)))
pass1 <- b_spec$est_MAE < BAR_MAE; pass2 <- b_spec$est_MAE <= b_spec$borrow_MAE
say("FR5  est MAE < %d: %s | est MAE <= borrow MAE: %s | OVERALL: %s", BAR_MAE, pass1, pass2,
    if (pass1 && pass2) "PASS" else "FAIL")

cover <- function(d, nm) {
  x <- d[has_int == TRUE & wa < 1 | (has_int == TRUE)]
  data.table(set = nm, cells = nrow(x), cover_bootstrap_shrunk = mean(x$cov_a),
             cover_posterior = mean(x$cov_post),
             n_w_lt_0.1 = sum(x$wa < 0.1), n_w_gt_0.9 = sum(x$wa > 0.9))
}
CV <- rbind(cover(VAL[in_spec == TRUE], "plan test set, all classes"),
            cover(VAL[in_spec == TRUE & in_bar_class == TRUE], "plan test set, Greens/ONP bar cells"),
            cover(VAL[in_spec == TRUE & wa >= 0.5], "plan test set, w >= 0.5"))
cat("\nFR4  Interval coverage: share of cells where the key lies inside the 90% interval (0.90 is calibrated).\n")
print(CV)

# optional-preferential exhaust errors
opt_flag <- ELS$optional[match(VAL$election, ELS$election)]
EX <- VAL[in_spec == TRUE & opt_flag == TRUE]
cat("\nFR4  Exhaust (e) on optional-preferential elections: mean |error| points, estimator vs borrow (lower is better)\n")
EXs <- EX[key_votes >= KEY_MIN_VOTES]
print(data.table(cells = nrow(EXs), est = mean(abs(EXs$err_e)), borrow = mean(abs(EXs$berr_e), na.rm = TRUE),
                 borrow_cells = sum(!is.na(EXs$berr_e))))

# all-class summary per election
PE <- VAL[in_spec == TRUE & key_votes >= KEY_MIN_VOTES,
          .(est_MAE = mean(abs(err_a)), borrow_MAE = mean(abs(berr_a), na.rm = TRUE), classes = .N,
            prior = prior[1]), by = election]
cat("\nFR4  Per-election mean |a error| over classes holding >= 20,000 key first preferences (points, lower is better)\n")
print(PE[, .(election, classes, prior, est_MAE = pt(est_MAE), borrow_MAE = pt(borrow_MAE))], nrows = 100)

# ---- AE as a second reference --------------------------------------------------------
AE <- tryCatch(as.data.table(load_preference_flows()), error = function(e) NULL)
AEC <- NULL
if (!is.null(AE)) {
  AE <- AE[party %in% c("GRN", "ONP", "OTH")]
  AEC <- merge(VAL[in_spec == TRUE & in_bar_class == TRUE | (in_spec == TRUE & party == "OTH" & key_votes >= KEY_MIN_VOTES),
                   .(election, party, key_a = 100 * key_a, est_a = 100 * a, borrow_a = 100 * borrow_a)],
               AE[, .(election = paste0(region, year), party, ae_a = flow_alp)], by = c("election", "party"))
  AEC[, `:=`(ae_err = ae_a - key_a, est_err = est_a - key_a, borrow_err = borrow_a - key_a)]
  cat("\nFR4  AE's hand-made flows as a second reference, same cells (Greens/ONP bar cells plus Others).\n")
  cat("     Mean |error| against the key, points; lower is better. AE rows exist only where AE published a value.\n")
  print(AEC[, .(cells = .N, AE = mean(abs(ae_err)), estimator = mean(abs(est_err)),
                borrow = mean(abs(borrow_err), na.rm = TRUE))])
}

# ---- write the review tables ------------------------------------------------------------
md <- character()
add <- function(fmt, ...) md <<- c(md, if (...length()) sprintf(fmt, ...) else fmt)
tbl <- function(d) { d <- as.data.frame(d); c(paste0("| ", paste(names(d), collapse = " | "), " |"),
  paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
  apply(d, 1, function(r) paste0("| ", paste(trimws(r), collapse = " | "), " |"))) }
add("# Flow estimation from results: validation (2026-10-13)\n")
add("Script: `scripts/estimate_flows_from_results.R` (check codes FR1-FR5). Spec: `docs/plans/flow-estimation-from-results-2026-10-13.md`. Output: `output/flows-estimated.csv`. Run with %d bootstrap replicates, seed 20261013.\n", B_BOOT)
add("## Result in one line\n")
add("**%s.** Greens and One Nation cells in the plan's test set: estimator mean absolute error %s points on %d cells (Greens %d, One Nation %d), borrowing the nearest earlier election's actual flows %s points. Bar: under %d points and no worse than borrowing.\n",
    if (pass1 && pass2) "PASS" else "FAIL", pt(b_spec$est_MAE, 2), b_spec$cells, b_spec$nGRN, b_spec$nONP, pt(b_spec$borrow_MAE, 2), BAR_MAE)
add("## Seat accounting and sources (FR1)\n")
add("What the numbers are: counts of seats; `final_alp_lnp` seats whose final two are Labor and Coalition, `used` those with a count taken, `no_count` decided on first preferences, `key_seats` used seats that also have transfers (answer key). Higher `used` means more evidence.\n")
add(tbl(LOG[, .(election, final_alp_lnp, final_other, used, no_count, key_seats, source)]))
add("\n## Answer-key integrity (FR2)\n")
add("What the numbers are: votes the tracker sends to Labor (or the Coalition) divided by the votes the seat counts say they gained, summed over key seats; 1.000 is exact.\n")
add(tbl(CHK))
add("\n## Per election and class (FR4)\n")
add("What the numbers are: percent of the class's first preferences ending with Labor. `key` is read from the published distributions, `est` is the shrunk estimate from results only, `raw` the unshrunk fit, `borrow` the nearest earlier election's actual flow, `err` = estimate minus key (closer to zero is better), `cov` whether the key lies inside the 90% interval, `w` the weight on the data (1 = all data, 0 = all prior).\n")
add(tbl(VAL[in_spec == TRUE | TRUE, .(election, party, seats = key_seats, key_a = pt(100 * key_a), est_a = pt(100 * a),
        raw_a = pt(100 * raw_a), borrow_a = pt(100 * borrow_a), err_a = pt(err_a), berr_a = pt(berr_a),
        key_e = pt(100 * key_e), est_e = pt(100 * e), cov = cov_a, w = pt(wa, 2), prior = prior)]))
add("\n## Pass bar (FR5)\n")
add("What the numbers are: mean absolute error of the Labor-flow share, in points; lower is better. Bar cells are Greens and One Nation with at least %d key seats and %s key first preferences.\n", KEY_MIN_SEATS, format(KEY_MIN_VOTES, big.mark = ","))
add(tbl(rbind(cbind(set = "plan test set", b_spec), cbind(set = "plus WA (supplementary)", b_all))[, lapply(.SD, function(x) if (is.numeric(x)) pt(x, 2) else x)]))
add("\nEstimator below %d points: **%s**. Estimator no worse than borrowing: **%s**.\n", BAR_MAE, pass1, pass2)
add("## Interval coverage (FR4)\n")
add("What the numbers are: share of class cells where the key lies inside the 90% interval; 0.90 is calibrated, lower means over-confident. `bootstrap_shrunk` is the percentile interval of the shrunk bootstrap draws (the spec's interval); `posterior` is estimate +/- 1.645 sqrt(w) se (secondary).\n")
add(tbl(CV[, .(set, cells, cover_bootstrap_shrunk = pt(cover_bootstrap_shrunk, 2), cover_posterior = pt(cover_posterior, 2), n_w_lt_0.1, n_w_gt_0.9)]))
add("\n## Per-election error, all classes with at least 20,000 key first preferences (FR4)\n")
add("What the numbers are: mean absolute error of the Labor-flow share across classes, points; lower is better.\n")
add(tbl(PE[, .(election, classes, prior, est_MAE = pt(est_MAE), borrow_MAE = pt(borrow_MAE))]))
add("\n## Exhaust on optional-preferential elections (FR4)\n")
add("What the numbers are: mean absolute error of the exhaust share, points; lower is better. Cells: %d (borrow available on %d).\n", nrow(EXs), sum(!is.na(EXs$berr_e)))
add(tbl(data.table(est = pt(mean(abs(EXs$err_e))), borrow = pt(mean(abs(EXs$berr_e), na.rm = TRUE)))))
if (!is.null(AEC)) {
  add("\n## AE's estimates as a second reference (FR4)\n")
  add("What the numbers are: mean absolute error against the key on cells where AE published a value, points; lower is better.\n")
  add(tbl(AEC[, .(cells = .N, AE = pt(mean(abs(ae_err))), estimator = pt(mean(abs(est_err))), borrow = pt(mean(abs(borrow_err), na.rm = TRUE)))]))
}
add("\n## Dry run\n")
add("The dry run (fed2022, nsw2023) is printed at the top of the script's log as FR3; see the dry-run section below.\n")

add("
## Reading the result (written after the run; numbers are from this run)
")
add("- **Fail on both clauses of the bar.** Mean absolute error 9.0 points against a 5-point bar, and borrowing the nearest earlier election's actual flows is better (4.9). The unshrunk fit alone is worse still (11.0), so shrinkage helped but could not rescue it. The bar, the method and the constants were not changed after seeing results.")
add("- **The error is systematic, not noise.** Federal Greens are over-estimated in nearly every election (2004 +10, 2007 +6, 2013 +6, 2019 +8, 2022 +11, 2025 +16) and One Nation under-estimated (2022 -15, 2025 -20). Intervals cover the key in 38% of cells (16% on the bar cells) against a nominal 90%: the bootstrap measures sampling noise over seats, and the error here is bias that more seats would not remove. Likely cause (not tested): flows differ between seats (Greens voters in inner-city Labor seats send more to Labor than elsewhere), and with five correlated minor-party shares a single set of constant flows cannot separate them.")
add("- **Where it looks fine, it is mostly the prior.** Victoria 2006-2018 and WA 2005 have pool weight 0 (the election-level spread estimate came out at zero), so the estimate equals the borrowed flows exactly; those rows say nothing about the estimator.")
add("- **Small samples fail badly.** SA 2026 has 12 key seats (13 used): estimates sit on the 0 and 100 boundaries (Greens 99, Others 15 against key 83 and 61) and the bootstrap spread collapses there, so the shrinkage weight is high (0.96) when it should be low. The bootstrap SE is not trustworthy at a boundary.")
add("- **Exhaust (NSW, optional preferential)**: mean absolute error 9.9 points against 14.6 for borrowing, on 17 cells; here the estimator beats borrowing, mainly because the NSW 2011 prior is federal (exhaust 0). This is not part of the bar.")
add("- **AE comparison**: AE's hand-made numbers are 11.1 points from the key on 44 cells, the estimator 7.6, borrowing 4.2. AE's federal Greens figures run 79-86% (2013-2025) against a key of 77-80%, and AE's federal One Nation 26-40% (2019-2025) against a key of 34-42%, so key and AE disagree by a few points for a reason I have not resolved (see below).")
add("
## What is unverified
")
add("- **The answer key is my construction, not a published number.** The transfers files record each exclusion split by recipient party class, with exhausted votes left out. I follow each first preference through later exclusions assuming a class's pile has the composition of that class's bucket (own first preferences plus everything received). For compulsory elections the pile size is the sum transferred; for NSW and pre-2017 Queensland it is the smallest remaining candidate's votes plus an equal share of the class's received votes, never less than what was transferred. Checks that passed: tracked votes reaching Labor and the Coalition are within 2% of the seat counts for federal and within 0.5% for WA, Qld and Vic, but 2-13% off for nsw2019 and nsw2023 (the Coalition side); NSW 2011 exhausted votes tracked 146,489 against 142,597 published (2.7% high). Not checked: that the per-class attribution is right, only the totals.")
add("- **The key disagrees with the commonly cited figures.** It puts the Greens at 77-80% to Labor in every federal election, where the plan quotes about 86% and AE 79-86%. One Nation is 34-54% in the key (34-42% from 2019), against AE's 26-40%. I could not find which is wrong; the key keeps votes that went to other minor parties first and then to the Coalition, which lowers Greens-to-Labor, and AE may count only the final transfer. If the key is biased, the 9.0 is too large; the Greens error then shrinks but the sign pattern would reverse.")
add("- **Key integrity rule added before validation, not tuned on it.** A seat enters the key only if transfers to Labor and to the Coalition are each within max(5%, 300 votes) of that candidate's change in the seat count. I first tried 3%/100 votes, saw from raw files that ordinary rounding disagreement is about 200 votes, and loosened it. This drops many seats (`seats_dropped_incomplete` in the integrity table: for example fed2019 98, fed2016 70, fed2010 67, vic2022 30); the estimator uses every counted seat but the key only the kept ones, so the two are not computed on identical seats.")
add("- **Seats with two Coalition (or two Labor) candidates** sit in one class; exclusions of the second candidate are skipped by the tracker (zero such skips in the final key seats except WA 2021: 2). Leakage from those candidates is not in the key.")
add("- **Prior fallback**: when no earlier same-state election has a distribution, the prior is the federal election in the most recent strictly earlier year, not the same year as the plan says (same-year federal would be leakage for any election held after it, and the dated check was not worth the risk). A class the prior lacks, or holds on fewer than 3 seats, gets the vote-weighted mean of the prior's classes (flagged `(class mean)` in `prior_source`).")
add("- **Source choice**: federal elections use the official AEC files (first preferences and final counts agree with the archive copy on all but 1-6 seats per election by more than 0.5%); every other election uses the uniform archive files, because the official state files are one row per party class and the optional-preferential tracker needs candidate rows. SA 2026 uses the official first preferences with final counts replayed from its transfers (no final-count file on disk). Qld 2017 and SA 2018/2022 are in the plan's test set but have no distribution on disk, so they are scored nowhere; Vic 2002, NSW 2003/2007, Qld 2001-2015 and SA 2002-2014 have estimates but no key. WA is reported separately (not in the plan's list) and is not in the pass-bar line.")
add("- **Not run**: a rerun with a different seed (bootstrap size 300 only); an alternative estimator with seat-level heterogeneity, which the plan does not specify and which I did not add.")
writeLines(md, REVIEW)
say("wrote %s", REVIEW)
