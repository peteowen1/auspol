# State-level sitting-member defectors (AUSPOL_DEFECTOR_STATE, default "0" = OFF; PREREG PENDING).
#
# Built 2026-10-06 from docs/reviews/state-defectors-2026-10-06.md. Three changes, all behind
# one switch, all in the shared functions so the six harnesses and fit_seats_full.R get them
# through fit_defector_discount() / personal_prior_vote() with no per-harness edit:
#
#  1. NO min_n CLIFF. fit_defector_discount() used to return NULL below 5 cases, so Kalgoorlie
#     2008 (4 cases) got nothing while Kiama (9) was trusted outright. With the switch on the
#     sitting-member carry for a target is the target LEVEL's median (state for a state target,
#     federal for a federal one) partially pooled toward the all-level median with PSEUDO-CASES:
#         w = n_level / (n_level + K),  rate = pooled + w * (level_median - pooled),  K = 3.
#     Zero cases at the target level gives the pooled rate (w = 0); zero cases anywhere leaves it
#     NULL (Pilbara wa2001 has no earlier evidence and is not forecastable time-forward; no
#     constant is invented). Why pseudo-cases rather than the tau^2 form the by-level arm used:
#     with two groups (state, federal) tau^2 is itself barely estimable, and that form let a
#     3-case state median through almost unshrunk (Hillarys wa2017 21.7 -> 43.9, actual 20.1).
#     n/(n+K) cannot be gamed by a small, tight sample: three cases that happen to agree still
#     only get weight 0.5. K = 3 is the value the review measured (bias +0.16 -> +0.05).
#  2. PERSON MATCH ACROSS SEATS. A sitting member (or major-party candidate) of one seat at the
#     previous election who stands under a non-major label in a DIFFERENT seat of the same
#     jurisdiction is a defector into that seat (Bowler Murchison-Eyre -> Kalgoorlie, D'Orazio
#     Ballajura -> Morley). Guards, each a false-match brake: consecutive elections of one
#     jurisdiction (federal also requires the same state); person key must be unique among the
#     previous election's major-party candidates and among the target's candidates; a key with
#     no given-name stem (surname + initial only) must be a unique surname across every
#     candidate of both elections; anyone with a same-seat record belongs to the existing path.
#  3. THE OLD CLASS GIVES UP WHAT THE DEFECTOR CARRIES. Same-seat: the existing transfer. Cross-seat:
#     the carried amount is removed from the OLD seat's old class (a row keyed by the old seat,
#     the new label, prev_party = old class), because those votes came from there, not from the
#     new seat's own old class.
#
# Every cross-seat match, refusal and removal is printed (DFS2 lines).
.DEFSTATE_K <- 3

#' @noRd
.defstate_on <- function() identical(Sys.getenv("AUSPOL_DEFECTOR_STATE", "0"), "1")

# Sitting-member carry for `target_election` from the earlier cases in `ratios`
# (columns ratio, was_mp, level). Returns the rate and everything printed about it.
#' @noRd
.defstate_rate <- function(ratios, target_election, K = .DEFSTATE_K) {
  rr <- ratios[ratios$was_mp %in% TRUE & is.finite(ratios$ratio), ]
  tl <- if (startsWith(target_election, "fed")) "fed" else "state"
  n_pooled <- nrow(rr)
  pooled <- if (n_pooled) stats::median(rr$ratio) else NA_real_
  lv <- rr$ratio[rr$level == tl]
  n_level <- length(lv)
  est <- if (n_level) stats::median(lv) else NA_real_
  w <- n_level / (n_level + K)
  rate <- if (!is.finite(pooled)) NA_real_ else if (n_level) pooled + w * (est - pooled) else pooled
  list(rate = rate, level = tl, n_level = n_level, n_pooled = n_pooled, w = w,
       level_median = est, pooled = pooled, K = K)
}

# Cross-seat major-to-non-major person matches between two consecutive elections.
# PREVT / NOWT carry .k (person key), .s (normalised seat), party, pcv, name; NOWT of a
# federal pair also needs `state`. Returns one row per matched person, plus (attribute
# "refused") a table of matches that a guard refused, for the log.
#' @noRd
.defector_cross_seat_cases <- function(PREVT, NOWT, election_to, pooled, MAJ = c("ALP", "LNP", "NAT"),
                                       min_prior = 0) {
  empty <- data.table::data.table(.s_new = character(), .k = character(), seat_new = character(),
                                  party_new = character(), target_pcv = numeric(), .s_old = character(),
                                  seat_old = character(), party_old = character(), prior_pcv = numeric(),
                                  was_mp = logical(), person = character())
  refused <- data.table::data.table(person = character(), why = character())
  P <- data.table::as.data.table(PREVT); N <- data.table::as.data.table(NOWT)
  is_fed <- startsWith(election_to, "fed")
  has_state <- is_fed && "state" %in% names(P) && "state" %in% names(N)
  pst <- if (has_state) tolower(P$state) else rep(NA_character_, nrow(P))
  nst <- if (has_state) tolower(N$state) else rep(NA_character_, nrow(N))
  pn <- if ("name" %in% names(P)) P$name else rep(NA_character_, nrow(P))
  nn <- if ("name" %in% names(N)) N$name else rep(NA_character_, nrow(N))
  rn <- seat_rename_map()
  p_el <- if ("elected" %in% names(P)) P$elected %in% TRUE else rep(NA, nrow(P))

  pk <- P$.k; ps <- P$.s; ppar <- P$party; ppcv <- P$pcv
  nk <- N$.k; ns <- N$.s; npar <- N$party; npcv <- N$pcv
  stemmed <- function(k) !is.na(k) & nchar(k) - nchar(gsub("|", "", k, fixed = TRUE)) >= 2L

  # previous-election major-party candidates eligible to carry (member, or anyone when pooled)
  # SITTING members only (the spec; a losing candidate turning up under another label elsewhere is
  # too weak a link to carry a vote on), whatever `pooled` says for the same-seat path.
  pm <- which(nzchar(pk) & ppar %in% MAJ & is.finite(ppcv) & ppcv >= min_prior & p_el %in% TRUE)
  allmaj <- which(nzchar(pk) & ppar %in% MAJ)   # uniqueness is judged over every major candidate, sitting or not
  pg <- given_of(if ("given" %in% names(P)) P$given else NA_character_, pn)
  ng <- given_of(if ("given" %in% names(N)) N$given else NA_character_, nn)
  pg <- tolower(gsub("[^A-Za-z]", "", pg)); ng <- tolower(gsub("[^A-Za-z]", "", ng))
  if (!length(pm)) return(structure(empty, refused = refused))
  # target-election non-major rows
  nm <- which(nzchar(nk) & !npar %in% MAJ & is.finite(npcv))
  if (!length(nm)) return(structure(empty, refused = refused))

  # same-seat record of any party at the previous election (either spelling of a renamed seat)
  prev_pairs <- unique(c(paste(ps, pk), paste(ifelse(ps %in% names(rn), unname(rn[ps]), ps), pk)))
  out <- list()
  for (i in nm[order(-npcv[nm])]) {
    key <- nk[i]; per <- nn[i]
    if (paste(ns[i], key) %in% prev_pairs) next          # same-seat history: existing machinery's
    cand <- pm[pk[pm] == key]
    if (!length(cand)) next
    why <- NULL
    cand_seats <- unique(ps[cand])
    if (length(unique(ps[allmaj[pk[allmaj] == key]])) != 1L) why <- "key matches major candidates in several seats at the previous election"
    # the SAME first name, or one a prefix of the other (Rob/Robert); first-two-letters alone let Brad match Bruce
    if (is.null(why) && stemmed(key)) {
      b0 <- cand[which.max(ppcv[cand])]
      same_given <- nzchar(ng[i]) && nzchar(pg[b0]) && (ng[i] == pg[b0] || .cs_given_ok(ng[i], pg[b0]))
      if (!isTRUE(same_given)) why <- sprintf("given names differ (%s vs %s)", ng[i], pg[b0])
    }
    # the same key on a major-party row of the target election, or on several target seats
    if (is.null(why) && any(nk == key & npar %in% MAJ)) why <- "same person key also stands for a major party in the target election"
    if (is.null(why) && length(unique(ns[nk == key])) != 1L) why <- "same person key stands in several seats in the target election"
    if (is.null(why) && !stemmed(key)) {
      # surname + initial only (or bare surname): demand the surname is unique across EVERY candidate of both elections
      if (sum(pk == key) != 1L || sum(nk == key) != 1L) why <- "no given-name stem and the key is not unique across all candidates"
    }
    if (is.null(why) && has_state) {
      cs <- unique(pst[cand]); ts <- nst[i]
      if (is.na(ts) || !nzchar(ts) || length(cs) != 1L || is.na(cs) || cs != ts) why <- "federal pair: not the same state"
    }
    if (is.null(why) && is_fed && !has_state) why <- "federal pair without a state column"
    if (is.null(why)) {
      s_old <- cand_seats[1L]
      s_old_r <- if (s_old %in% names(rn)) unname(rn[s_old]) else s_old
      if (ns[i] == s_old || ns[i] == s_old_r) next       # same seat under a renamed spelling
      best <- cand[which.max(ppcv[cand])]
      out[[length(out) + 1L]] <- data.table::data.table(
        .s_new = ns[i], .k = key, seat_new = N$seat[i], party_new = npar[i], target_pcv = npcv[i],
        .s_old = s_old, seat_old = P$seat[best], party_old = ppar[best], prior_pcv = ppcv[best],
        was_mp = p_el[best], person = per)
    } else {
      refused <- rbind(refused, data.table::data.table(person = sprintf("%s (%s %s)", per, N$seat[i], npar[i]), why = why))
    }
  }
  res <- if (length(out)) data.table::rbindlist(out) else empty
  # one match per (new seat, key): the best-polling non-major row of that person
  if (nrow(res)) res <- res[, .SD[which.max(target_pcv)], by = list(.s_new, .k)]
  structure(res, refused = refused)
}
