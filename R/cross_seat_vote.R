# Cross-seat / cross-jurisdiction personal vote (AUSPOL_CROSS_SEAT_VOTE, SHIPPED "1" 2026-10-06; prereg-crossseat-and-wa-port-2026-10-05.md Amendment A1).
#
# personal_prior_vote() looks at the SAME seat at the PREVIOUS election, so a
# person who earned a personal vote somewhere else (another seat, state vs
# federal, a by-election, or an election they sat out) reads as a newcomer:
# Dai Le got 30.3% in Cabramatta (nsw2019) and was forecast 5.2 in Fowler
# (fed2022); Oakeshott 6.9 in Cowper (fed2016) after Lyne; Brock 25.0 in
# Stuart (sa2022) after Frome. docs/reviews/cross-seat-personal-vote-2026-10-05.md.
# Pete (2026-10-05): "sounds good fix". PREREG PENDING; OFF until measured.
#
# Rules (every one is a leak or false-match guard):
#  * TIME-FORWARD: only elections dated strictly before the target
#    (elections_before(); state and federal interleave, so it is by date).
#  * PERSON KEY: surname + first given name, never initial only. Both given
#    names must be known (3+ letters) and one must be the other's prefix
#    (Rob/Robert yes, Trevor/Tony no, "J" never). Bare-surname rows (WA
#    early years) never match.
#  * SAME STATE: a federal seat and a state seat match only when the federal
#    seat lies in that state; a state-to-state or fed-to-fed move across
#    states is refused too. Unknown state = refuse.
#  * PERSONAL PRIOR ONLY (Pete 2026-10-05): a result won as IND, or as a sitting
#    member (elected) or by-election winner of a non-major class. A non-member
#    One Nation/OTH share stays with the party; a major-party vote is the
#    party's (McBride). Greens neither side. Applies to the credit AND the carry fit.
#  * AMBIGUOUS PERSON REFUSED: another person with the same surname and first
#    initial but a different first name known by the target election = no credit.
#  * Only a class leader with no same-seat identity at the previous election
#    is credited (anyone with a same-seat record belongs to the existing
#    machinery). Same-seat by-election winners are left to AUSPOL_BYELEC_LEVEL.
.CS_NONMAJ <- c("IND", "OTH", "OTH_RIGHT", "ONP")

# One row per candidacy with the columns the person matching needs.
#' @noRd
.cs_prep <- function(d) {
  d <- data.table::as.data.table(d)
  n <- nrow(d)
  nm <- if ("name" %in% names(d)) d$name else rep(NA_character_, n)
  sur <- surname_of(if ("surname" %in% names(d)) d$surname else NA_character_, nm)
  giv <- given_of(if ("given" %in% names(d)) d$given else NA_character_, nm)
  reg <- sub("[0-9]{4}$", "", d$election)
  st <- if ("state" %in% names(d)) ifelse(reg == "fed", tolower(d$state), reg) else ifelse(reg == "fed", NA_character_, reg)
  st[!nzchar(st)] <- NA_character_
  sur <- tolower(gsub("[^A-Za-z]", "", sur))
  stem <- given_stem(giv)
  data.table::data.table(
    c_election = d$election, c_seat = d$seat, c_s = normalise_seat(d$seat),
    c_sur = sur, c_giv = giv, c_stem = stem, c_key = ifelse(nzchar(stem), paste0(sur, "|", stem), NA_character_),
    c_state = st, c_party = d$party, c_pcv = d$pcv, c_src = "general",
    c_el = if ("elected" %in% names(d)) d$elected %in% TRUE else rep(FALSE, n))
}

#' @noRd
.cs_given_ok <- function(a, b) {
  fold <- function(g) { h <- g %in% names(.given_nicknames); g[h] <- unname(.given_nicknames[g[h]]); g }
  a <- fold(a); b <- fold(b)
  nchar(a) >= 3L & nchar(b) >= 3L & (startsWith(a, b) | startsWith(b, a))
}

# Non-major by-election winners from every window whose general election is not
# after `cutoff_election`, as prepared history rows (c_src = "byelection").
#' @noRd
.cs_byelection_rows <- function(D, extra_pair = NULL, cutoff_election) {
  prs <- all_election_pairs()
  if (!is.null(extra_pair)) prs <- c(prs, list(extra_pair))
  prs <- prs[!duplicated(vapply(prs, `[[`, "", "election"))]
  ok <- vapply(prs, function(p) p$election == cutoff_election || elections_before(p$election, cutoff_election), NA)
  fed <- unique(D[grepl("^fed", c_election) & !is.na(c_state), list(c_s, c_state)], by = "c_s")
  rows <- lapply(prs[ok], function(p) {
    bw <- tryCatch({ utils::capture.output(r <- byelection_winner_rows(p$prev, p$election)); r },
                   error = function(e) NULL)
    if (is.null(bw) || !nrow(bw)) return(NULL)
    bw <- data.table::as.data.table(bw)[bw$party %in% .CS_NONMAJ]
    if (!nrow(bw)) return(NULL)
    bw[, election := p$election]
    r <- .cs_prep(bw)
    r[, `:=`(c_pcv = bw$pcv, c_src = "byelection", c_el = TRUE)]
    if (grepl("^fed", p$election)) r[, c_state := fed$c_state[match(c_s, fed$c_s)]]
    r
  })
  r <- data.table::rbindlist(rows)
  if (!ncol(r)) r <- D[0L]
  r
}

# The best qualifying earlier result of each candidate in `cand`, from history
# `H` (both .cs_prep tables). `cand` needs a unique `.id`.
#' @noRd
.cs_match <- function(cand, H) {
  cand <- cand[!is.na(c_key)]
  U <- rbind(H[, list(c_sur, c_giv, c_state, qual = c_party %in% .CS_NONMAJ & is.finite(c_pcv) & (c_party == "IND" | c_el %in% TRUE | c_src == "byelection"))],
             cand[, list(c_sur, c_giv, c_state, qual = FALSE)])   # names known by the target election
  # PERSONAL votes only (Pete 2026-10-05): won as an independent, or as a sitting member /
  # by-election winner of a non-major class. A non-member One Nation/OTH share is the party's.
  H <- H[!is.na(c_key) & c_party %in% .CS_NONMAJ & is.finite(c_pcv) &
           (c_party == "IND" | c_el %in% TRUE | c_src == "byelection")]
  empty <- data.table::data.table(.id = integer(0), h_election = character(0), h_seat = character(0),
                                  h_party = character(0), h_pcv = numeric(0), h_src = character(0), n_hist = integer(0))
  if (!nrow(cand) || !nrow(H)) return(empty)
  hh <- data.table::copy(H)
  data.table::setnames(hh, c("c_election", "c_seat", "c_s", "c_sur", "c_giv", "c_stem", "c_state", "c_party", "c_pcv", "c_src"),
                       c("h_election", "h_seat", "h_s", "h_sur", "h_giv", "h_stem", "h_state", "h_party", "h_pcv", "h_src"))
  m <- merge(cand[, list(.id, c_key, c_giv, c_state, c_s)], hh, by.x = "c_key", by.y = "c_key", allow.cartesian = TRUE)
  m <- m[.cs_given_ok(c_giv, h_giv) & !is.na(c_state) & !is.na(h_state) & c_state == h_state]
  rn <- seat_rename_map()
  c_s2 <- ifelse(m$c_s %in% names(rn), unname(rn[m$c_s]), m$c_s)
  same_seat <- m$h_s == m$c_s | m$h_s == c_s2
  m <- m[!(m$h_src == "byelection" & same_seat)]   # AUSPOL_BYELEC_LEVEL owns these
  if (!nrow(m)) return(empty)
  # AMBIGUOUS PERSON, refused only when it matters: a different-first-name namesake in the SAME STATE
  # who (a) ALSO holds a qualifying personal prior, so the credit could belong to either, or (b) exists
  # at all when this match relied on a prefix/nickname fold rather than an exact first name.
  U <- U[nchar(c_giv) >= 3L & !is.na(c_state)]
  # plain vectors, not split.data.table / per-row data.table subsetting: that was the
  # dominant cost of a warm cross-seat call
  u_giv <- U$c_giv; u_state <- U$c_state; u_qual <- U$qual
  grp <- split(seq_len(nrow(U)), paste0(U$c_sur, "|", substr(u_giv, 1L, 1L)))
  m_key <- paste0(m$h_sur, "|", substr(m$c_giv, 1L, 1L)); m_cgiv <- m$c_giv; m_cst <- m$c_state; m_hgiv <- m$h_giv
  amb <- vapply(seq_len(nrow(m)), function(i) {
    o <- grp[[m_key[i]]]
    if (is.null(o)) return(FALSE)
    o <- o[u_state[o] == m_cst[i] & !.cs_given_ok(u_giv[o], m_cgiv[i]) & u_giv[o] != m_cgiv[i]]
    if (!length(o)) return(FALSE)
    any(u_qual[o]) || m_cgiv[i] != m_hgiv[i]
  }, NA)
  refused <- m[amb, list(h_pcv = if (.N) max(h_pcv) else NA_real_), by = .id]
  m <- m[!m$.id %in% refused$.id]
  if (!nrow(m)) { empty <- data.table::copy(empty); attr(empty, "refused") <- refused; return(empty) }
  m[, n_hist := .N, by = .id]
  data.table::setorderv(m, c(".id", "h_pcv"), c(1L, -1L))
  res <- m[, .SD[1L], by = .id][, list(.id, h_election, h_seat, h_party, h_pcv, h_src, n_hist)]
  attr(res, "refused") <- refused
  res
}

# Weighted median.
#' @noRd
.cs_wmedian <- function(x, w) {
  o <- order(x); x <- x[o]; w <- w[o]
  x[which(cumsum(w) >= sum(w) / 2)[1L]]
}

#' Carry rate for a personal vote earned in another seat or jurisdiction
#'
#' Of the vote a non-major candidate earned elsewhere, the fraction they
#' keep when they stand with no same-seat history. Fitted TIME-FORWARD on
#' the cross-seat cases themselves (every non-major candidate at an earlier
#' election, strictly before `target_election`, whose qualifying prior is a PERSONAL
#' vote: won as IND, or as a sitting member or by-election winner of a non-major
#' class; ambiguous namesakes refused; same matching rules as the credit), as the
#' prior-weighted median of
#' `realised / prior`. Weighting by the prior vote down-weights ratios taken on
#' tiny denominators without a cut-off. It is then PARTIALLY POOLED toward the
#' same-seat returning non-major ratio (same weighted median over consecutive
#' pairs): `carry = r_same + w * (r_cross - r_same)` with
#' `w = d^2 / (d^2 + se^2)`, `d = r_cross - r_same` and `se` the standard error
#' of the cross-seat weighted mean, so a thin or noisy cross-seat sample
#' degrades toward the same-seat ratio instead of falling off a cliff.
#'
#' @param target_election Election being predicted; only elections strictly
#'   before it are used.
#' @param corpus Optional candidacy table; `output/candidacies.csv` when `NULL`.
#' @param pairs Optional pair list, as from [all_election_pairs()].
#' @return A list: `carry` (NA with no cases), `r_cross`, `r_same`, `w`, `n`
#'   (cross-seat cases), `n_same`, `cases` (the cross-seat case table).
#' @export
fit_cross_seat_carry <- function(target_election, corpus = NULL, pairs = NULL) {
  C <- corpus
  if (is.null(C)) C <- data.table::fread(file.path("output", "candidacies.csv"), showProgress = FALSE)
  D <- .cs_prep(C)
  if (is.null(pairs)) pairs <- all_election_pairs()
  pairs <- fit_pairs_for(target_election, pairs)
  rn <- seat_rename_map()
  BY <- .cs_byelection_rows(D, NULL, target_election)   # once; filtered by date per pair below
  cross <- list(); same <- list()
  for (pr in pairs) {
    N <- D[c_election == pr$election & c_party %in% .CS_NONMAJ & !is.na(c_key) & is.finite(c_pcv)]
    P <- D[c_election == pr$prev]
    if (!nrow(N) || !nrow(P)) next
    N[, .id := .I]
    # same-seat returners (any party at the previous election): the existing machinery's
    P2 <- unique(rbind(P[!is.na(c_key), list(c_s, c_key)],
                       P[!is.na(c_key) & c_s %in% names(rn), list(c_s = unname(rn[c_s]), c_key)]))
    Pn <- P[c_party %in% .CS_NONMAJ & is.finite(c_pcv) & !is.na(c_key) & (c_party == "IND" | c_el)]   # personal votes only
    Pn2 <- unique(rbind(Pn[, list(c_s, c_key, prior = c_pcv)],
                        Pn[c_s %in% names(rn), list(c_s = unname(rn[c_s]), c_key, prior = c_pcv)]))
    Pn2 <- Pn2[, list(prior = max(prior)), by = list(c_s, c_key)]
    sm <- merge(N[, list(.id, c_s, c_key, c_pcv)], Pn2, by = c("c_s", "c_key"))
    sm <- sm[prior > 0 & is.finite(prior)]
    if (nrow(sm)) same[[length(same) + 1L]] <- sm[, list(pair = pr$election, prior, next_pcv = c_pcv)]
    has_same <- paste(N$c_s, N$c_key) %in% paste(P2$c_s, P2$c_key)
    cand <- N[!has_same]
    H <- rbind(D[elections_before(c_election, pr$election)],
               BY[BY$c_election == pr$election | elections_before(BY$c_election, pr$election)], fill = TRUE)
    mt <- .cs_match(cand, H)
    if (!nrow(mt)) next
    mt <- merge(mt, cand[, list(.id, c_seat, c_pcv, c_party)], by = ".id")
    mt <- mt[h_pcv > 0]
    if (nrow(mt)) cross[[length(cross) + 1L]] <- mt[, list(pair = pr$election, seat = c_seat, party = c_party,
                                                           prior = h_pcv, next_pcv = c_pcv, h_election, h_seat, h_src)]
  }
  cases <- data.table::rbindlist(cross)
  sm <- data.table::rbindlist(same)
  out <- list(carry = NA_real_, r_cross = NA_real_, r_same = NA_real_, w = NA_real_,
              n = nrow(cases), n_same = nrow(sm), cases = cases)
  if (!nrow(cases)) return(out)
  rs <- cases$next_pcv / cases$prior
  out$r_cross <- .cs_wmedian(rs, cases$prior)
  out$r_same <- if (nrow(sm)) .cs_wmedian(sm$next_pcv / sm$prior, sm$prior) else NA_real_
  if (!is.finite(out$r_same)) { out$carry <- out$r_cross; out$w <- 1; return(out) }
  mw <- stats::weighted.mean(rs, cases$prior)
  n <- nrow(cases)
  se2 <- if (n >= 2L) sum(cases$prior^2 * (rs - mw)^2) / sum(cases$prior)^2 * n / (n - 1L) else Inf
  d2 <- (out$r_cross - out$r_same)^2
  out$w <- if (is.finite(se2)) d2 / (d2 + se2) else 0
  out$carry <- out$r_same + out$w * (out$r_cross - out$r_same)
  out
}

.cs_env <- new.env(parent = emptyenv())

# ---- MEMOISATION -----------------------------------------------------------
# personal_prior_vote() runs inside every harness pair and every rebuild stage, and
# the carry fit plus the by-election history rows are pure functions of (target
# election, corpus, pairs, by-election tables, AUSPOL_* switches). Two layers: an
# in-session environment, and a small on-disk RDS cache so the separate processes of
# a rebuild share one fit. Bump .CS_CACHE_VERSION when the fitting code changes.
.CS_CACHE_VERSION <- "cs-cache-1"
.cs_memo <- new.env(parent = emptyenv())

# Cache directory: the argument, else AUSPOL_CROSS_SEAT_CACHE_DIR, else output/cache/cross-seat.
#' @noRd
.cs_cache_dir <- function(cache_dir = NULL) {
  if (!is.null(cache_dir)) return(cache_dir)
  e <- Sys.getenv("AUSPOL_CROSS_SEAT_CACHE_DIR", "")
  if (nzchar(e)) e else file.path("output", "cache", "cross-seat")
}

# What the cached value depends on, hashed: the corpus (every column), the election pair
# list, the by-election source files, every AUSPOL_* switch and the cache version.
#' @noRd
.cs_fingerprint <- function(what, corpus, ...) {
  bd <- file.path("external", "reference", "byelections")
  bf <- if (dir.exists(bd)) sort(list.files(bd, full.names = TRUE)) else character(0)
  ev <- Sys.getenv(); ev <- ev[grepl("^AUSPOL_", names(ev)) & names(ev) != "AUSPOL_CROSS_SEAT_CACHE_DIR"]
  # The CODE the cached value depends on, too (review 2026-10-06): editing a matching
  # or classification helper must invalidate entries, not wait for a manual version bump.
  fns <- c(".cs_match", "given_stem", "given_conflict", "match_key", "align_person_keys", "seat_rename_map",
           "election_dates", "elections_before", "classify_party", "byelection_winner_rows", "fit_cross_seat_carry")
  code <- lapply(fns, function(f) if (exists(f, mode = "function")) deparse(get(f, mode = "function")) else NULL)
  digest::digest(list(.CS_CACHE_VERSION, what, as.data.frame(corpus), all_election_pairs(),
                      unname(tools::md5sum(bf)), ev[order(names(ev))], code, list(...)), algo = "xxhash64")
}

# Memoise `compute()` under `key` (session environment, then disk). A corrupt or
# unreadable disk entry is recomputed; a failed write is reported, never fatal.
#' @noRd
.cs_cached <- function(key, compute, cache_dir = NULL, disk = TRUE) {
  if (exists(key, envir = .cs_memo, inherits = FALSE)) return(get(key, envir = .cs_memo, inherits = FALSE))
  f <- file.path(.cs_cache_dir(cache_dir), paste0(key, ".rds"))
  val <- NULL
  if (disk && file.exists(f)) val <- tryCatch(readRDS(f), error = function(e) NULL)
  if (is.null(val)) {
    val <- compute()
    if (disk) tryCatch({
      dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
      tmp <- tempfile(pattern = paste0(key, "-"), tmpdir = dirname(f), fileext = ".tmp")
      saveRDS(val, tmp)
      if (!file.rename(tmp, f)) { unlink(tmp); stop("rename failed") }
    }, error = function(e) cat(sprintf("CSV1! cross-seat cache write failed (%s): %s\n", f, conditionMessage(e))))
  }
  assign(key, val, envir = .cs_memo)
  val
}

#' Clear the in-session cross-seat memo (tests and benchmarks)
#' @return Invisibly `NULL`.
#' @export
clear_cross_seat_cache <- function() {
  rm(list = ls(.cs_memo, all.names = TRUE), envir = .cs_memo)
  invisible(NULL)
}

#' @noRd
.cs_carry_cached <- function(target_election, corpus, cache_dir = NULL) {
  key <- .cs_fingerprint("carry", corpus, target_election)
  .cs_cached(key, function() fit_cross_seat_carry(target_election, corpus = corpus), cache_dir)
}

#' @noRd
.cs_byelection_cached <- function(D, corpus, extra_pair, cutoff_election, cache_dir = NULL) {
  key <- .cs_fingerprint("byrows", corpus, extra_pair, cutoff_election)
  .cs_cached(key, function() .cs_byelection_rows(D, extra_pair, cutoff_election), cache_dir)
}

# Called from personal_prior_vote() under AUSPOL_CROSS_SEAT_VOTE=1. `out` is the
# per-(seat, party) leader table; credits only rows whose own_prev_pcv is still
# NA in a non-major class. Returns `out`; the credit table is left in
# .cs_env$last for the dry-run script.
#' @noRd
.apply_cross_seat_credit <- function(out, NOWT, PREVT, C, election_from, election_to, cache_dir = NULL) {
  MAJ <- c("ALP", "LNP", "NAT")
  .cs_env$last <- NULL; .cs_env$refused <- NULL
  D <- .cs_cached(.cs_fingerprint("prep", C), function() .cs_prep(C), disk = FALSE)
  car <- tryCatch(.cs_carry_cached(election_to, C, cache_dir), error = function(e) {
    cat(sprintf("CSV1! carry fit FAILED, no cross-seat credit: %s\n", conditionMessage(e))); NULL })
  if (is.null(car)) return(out)
  if (!is.finite(car$carry)) {
    cat(sprintf("CSV1! %s: no earlier cross-seat cases, no cross-seat credit\n", election_to)); return(out)
  }
  # candidates: non-major rows of the target in a class whose leader has no own vote yet
  need <- out[is.na(out$own_prev_pcv) & out$party %in% .CS_NONMAJ, list(seat, party)]
  if (!nrow(need)) return(out)
  cand <- .cs_prep(NOWT)
  cand[, `:=`(.id = .I, seat = NOWT$seat, party = NOWT$party)]
  cand <- cand[paste(seat, party) %in% paste(need$seat, need$party) & !is.na(c_key)]
  # a person with ANY same-seat record at the previous election belongs to the existing machinery
  rn <- seat_rename_map()
  P <- .cs_prep(PREVT)[!is.na(c_key)]
  P2 <- unique(rbind(P[, list(c_s, c_key)], P[c_s %in% names(rn), list(c_s = unname(rn[c_s]), c_key)]))
  cand <- cand[!paste(c_s, c_key) %in% paste(P2$c_s, P2$c_key)]
  if (!nrow(cand)) return(out)
  H <- rbind(D[elections_before(c_election, election_to)],
             .cs_byelection_cached(D, C, list(election = election_to, prev = election_from), election_to, cache_dir), fill = TRUE)
  mt <- .cs_match(cand, H)
  rf <- attr(mt, "refused")
  if (!is.null(rf) && nrow(rf)) {
    rc <- cand[match(rf$.id, cand$.id), list(seat, party, candidate = paste(c_giv, c_sur))]
    .cs_env$refused <- cbind(rc, prior = rf$h_pcv)
    cat(sprintf("CSV1 %s -> %s: %d ambiguous person match(es) REFUSED: %s
", election_from, election_to, nrow(rc),
                paste(sprintf("%s/%s %s", rc$seat, rc$party, rc$candidate), collapse = "; ")))
  } else .cs_env$refused <- NULL
  if (!nrow(mt)) { cat(sprintf("CSV1 %s -> %s: carry %.3f (n=%d), no candidate credited\n", election_from, election_to, car$carry, car$n)); return(out) }
  mt <- merge(mt, cand[, list(.id, seat, party, c_giv, c_sur)], by = ".id")
  mt[, credit := car$carry * h_pcv]
  mt[, namesakes := 0L]   # ambiguous people were refused inside .cs_match()
  # the class base the seat already had: never credit LESS than that
  cb <- PREVT[, list(cls_pcv = if (.N) max(pcv, na.rm = TRUE) else NA_real_), by = list(.s = normalise_seat(seat), party)]
  mt[, .s := normalise_seat(seat)]
  mt <- merge(mt, cb, by = c(".s", "party"), all.x = TRUE)
  mt[is.na(cls_pcv), cls_pcv := 0]
  mt[, applied := pmax(credit, cls_pcv)]
  data.table::setorderv(mt, c("seat", "party", "applied"), c(1L, 1L, -1L))
  best <- mt[, .SD[1L], by = list(seat, party)]
  # Only a credit that EXCEEDS what the class already had in the seat changes the cell;
  # the rest stay NA (byte-identical to the switch being off for them).
  best[, changed := credit > cls_pcv]
  if (!"transfer" %in% names(out)) out[, transfer := NA_real_]
  ch <- best[best$changed]
  idx <- match(paste(ch$seat, ch$party), paste(out$seat, out$party))
  if (nrow(ch)) {
    # own_prev_source marks a CROSS-SEAT credit. Every harness's .own_x() substitutes
    # own_prev_pcv for the class base wholesale, which is right for a same-seat person
    # but would LOWER a class whose own history is stronger (Stuart IND 25.0 -> 21.9). A
    # cross-seat credit may only RAISE a class: own_prev_substitute() applies it as
    # max(class base, credit). The column exists only when this switch credited something.
    if (!"own_prev_source" %in% names(out)) out[, own_prev_source := NA_character_]
    out[idx, `:=`(own_prev_pcv = ch$applied, prev_party = NA_character_, transfer = NA_real_,
                  own_prev_source = "cross_seat")]
  }
  .cs_env$last <- best[, list(seat, party, candidate = paste(c_giv, c_sur), source_election = h_election, source_seat = h_seat,
                              source = h_src, prior = h_pcv, carry = car$carry, credit, class_base = cls_pcv, own_prev_pcv = applied,
                              changed, namesakes, n_hist)]
  cat(sprintf("CSV1 %s -> %s: carry %.3f (cross-seat %.3f, same-seat %.3f, w %.2f; n=%d cross cases, %d same-seat; target excluded), %d class(es) credited: %s\n",
              election_from, election_to, car$carry, car$r_cross, car$r_same, car$w, car$n, car$n_same, nrow(ch),
              paste(sprintf("%s/%s %s %s %s %s %.1f x %.2f -> %.1f", ch$seat, ch$party, ch$c_giv, ch$c_sur,
                            ch$h_election, ch$h_seat, ch$h_pcv, car$carry, ch$applied), collapse = "; ")))
  out
}
