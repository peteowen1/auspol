# Hare-Clark candidate-level count for the party-seat forecast -----------------
#
# The party-level block count (hc_party_count()) treats a ticket as one bloc.
# Run on the ACTUAL votes it reproduced 28 of 30 Tasmanian electorates but only
# 9 of 18 ACT ones, because in the ACT the last seat is decided between single
# candidates whose votes have decayed through fractional surpluses and ballots
# that stop inside the ticket. This file counts candidates instead:
#
#   * a ticket's simulated vote is split over anonymous candidate SLOTS (its
#     number one, number two, ...) by the previous election's within-ticket
#     shares, shrunk toward equal, with time-forward noise (hc_split_*());
#   * ballots: the ACT's previous ballot file folded to slot sequences
#     (hc_prepare_ballots()), re-weighted so each slot's first preferences
#     match the draw; Tasmania has no ballot file, so ballots are built from
#     party transfer rates (hc_synthetic_ballots());
#   * the count: hc_stv_cpp() (src/hare_clark_stv.cpp), an inclusive-Gregory
#     candidate count, ~ms per count.

#' Party transfer rates from a published distribution of preferences
#'
#' Tasmania publishes no ballot files, but its count exports record, for every
#' transfer, the papers that went to each ticket and that exhausted
#' (`scripts/build_hare_clark_tas_flows.R`). Papers that stayed in the source
#' ticket are set aside; the rest give the rate at which a ticket's votes go to
#' each class when they leave it -- the quantity [hc_party_count()] uses.
#'
#' @param rows `data.frame` with `src_class`, `to_class` (a class, `SAME` or
#'   `EXH`) and `papers`.
#' @inheritParams hc_flows_from_ballots
#' @return As [hc_flows_from_ballots()], plus attribute `leak`: per transfer
#'   class, the share of transferred papers that left the ticket.
#' @export
hc_flows_from_counts <- function(rows, prior_n = 50, fine = FALSE) {
  r <- as.data.frame(rows)
  out_rows <- r[r$to_class != "SAME", ]
  m <- hc_flows_from_ballots(data.frame(c1 = out_rows$src_class, c2 = out_rows$to_class, n = out_rows$papers),
                             prior_n = prior_n, fine = fine)
  fc <- hc_flow_class(r$src_class, fine)
  lk <- vapply(.hc_fc, function(k) {
    a <- sum(r$papers[fc == k]); if (a <= 0) return(NA_real_)
    sum(r$papers[fc == k & r$to_class != "SAME"]) / a
  }, numeric(1))
  pooled <- sum(r$papers[r$to_class != "SAME"]) / sum(r$papers)
  lk[!is.finite(lk)] <- pooled
  attr(m, "leak") <- lk
  m
}

.hc_profile <- function(s, n) {
  s <- sort(s[is.finite(s) & s >= 0], decreasing = TRUE)
  if (!length(s) || sum(s) <= 0) return(rep(1 / n, n))
  v <- if (length(s) >= n) s[seq_len(n)] else c(s, rep(min(s), n - length(s)))
  if (sum(v) <= 0) return(rep(1 / n, n))
  v / sum(v)
}

#' Within-ticket split priors, fitted time-forward
#'
#' How a ticket's vote divides among its candidates, ranked: the expected
#' sorted shares are `lambda * previous + (1 - lambda) / n` (the previous
#' election's sorted within-ticket shares for that ticket in that electorate,
#' shrunk toward equal), with log-normal noise `sdlog`. `lambda` is the least
#' squares fit over every ticket that stood in consecutive elections dated
#' before `before`, itself shrunk toward `lambda0` by `n0` pseudo-tickets;
#' `sdlog` likewise. `profiles` are the mean sorted shares of tickets with `n`
#' candidates in elections before `before`, for tickets with no history.
#'
#' @param cands `data.frame` region, year, electorate, unit, votes (one row
#'   per candidate; `output/hare-clark-candidates.csv`).
#' @param before Date.
#' @param lambda0,sdlog0,n0 Priors and their weight.
#' @return List `lambda`, `sdlog`, `profiles` (by candidate count), `n_pairs`.
#' @export
hc_split_priors <- function(cands, before, lambda0 = 0.7, sdlog0 = 0.4, n0 = 20) {
  cd <- as.data.frame(cands)
  key <- paste(cd$region, cd$year, cd$electorate, cd$unit, sep = "|")
  grp <- split(cd$votes, key)
  el <- hare_clark_elections()
  pr <- .hc_pairs_before(before)
  xs <- numeric(0); ys <- numeric(0); ps <- numeric(0); cs <- numeric(0); ns <- numeric(0); m <- 0L
  for (i in seq_len(nrow(pr))) {
    ka <- names(grp)[startsWith(names(grp), paste0(pr$region[i], "|", pr$prev[i], "|"))]
    for (k in ka) {
      kb <- sub(paste0("^", pr$region[i], "\\|", pr$prev[i], "\\|"), paste0(pr$region[i], "|", pr$year[i], "|"), k)
      if (is.null(grp[[kb]]) || grepl("\\|(IND|UNG|GRP): ", k)) next
      cur <- sort(grp[[kb]], decreasing = TRUE)
      n <- length(cur)
      if (n < 2L || sum(cur) <= 0) next
      cur <- cur / sum(cur)
      p <- .hc_profile(grp[[k]], n)
      xs <- c(xs, p - 1 / n); ys <- c(ys, cur - 1 / n); ps <- c(ps, p); cs <- c(cs, cur); ns <- c(ns, rep(n, n))
      m <- m + 1L
    }
  }
  lam_hat <- if (length(xs) && sum(xs^2) > 0) sum(xs * ys) / sum(xs^2) else lambda0
  lambda <- min(1, max(0, (n0 * lambda0 + m * lam_hat) / (n0 + m)))
  pred <- lambda * ps + (1 - lambda) / ns
  ok <- cs > 0 & pred > 0
  r <- log(cs[ok] / pred[ok])
  sdlog <- .hc_shrink_sd(sum(r^2), length(r), sdlog0, n0)
  # generic profiles from every election dated before `before`
  yrs <- el[el$date < as.Date(before), c("region", "year")]
  keep <- paste(cd$region, cd$year) %in% paste(yrs$region, yrs$year) & !grepl("^(IND|UNG|GRP): ", cd$unit)
  g2 <- split(cd$votes[keep], key[keep])
  prof <- list()
  for (n in 1:8) {
    vs <- Filter(function(v) length(v) == n && sum(v) > 0, g2)
    prof[[as.character(n)]] <- if (length(vs)) Reduce(`+`, lapply(vs, function(v) sort(v, TRUE) / sum(v))) / length(vs)
                               else rep(1 / n, n)
  }
  list(lambda = lambda, sdlog = sdlog, profiles = prof, n_pairs = m)
}

#' Expected within-ticket shares for the tickets standing in one electorate
#'
#' @param target `data.frame` unit, ncand: the tickets standing.
#' @param prev_e `data.frame` unit, votes: the previous election's candidates in
#'   THIS electorate (empty for a new electorate).
#' @param prev_all `data.frame` unit, electorate, votes: the previous election's
#'   candidates everywhere, used when the ticket did not stand here.
#' @param pri List from [hc_split_priors()].
#' @return Named list by unit of sorted expected shares, one per candidate.
#' @export
hc_split_expected <- function(target, prev_e, prev_all, pri) {
  out <- list()
  for (i in seq_len(nrow(target))) {
    u <- target$unit[i]; n <- target$ncand[i]
    v <- prev_e$votes[prev_e$unit == u]
    p <- if (length(v) && sum(v) > 0) .hc_profile(v, n)
    else if (!grepl("^(IND|UNG|GRP): ", u) && any(prev_all$unit == u)) {
      ee <- unique(prev_all$electorate[prev_all$unit == u])
      Reduce(`+`, lapply(ee, function(e) .hc_profile(prev_all$votes[prev_all$unit == u & prev_all$electorate == e], n))) / length(ee)
    } else {
      g <- pri$profiles[[as.character(n)]]
      if (is.null(g)) rep(1 / n, n) else g
    }
    out[[u]] <- pri$lambda * p + (1 - pri$lambda) / n
  }
  out
}

#' One draw of candidate-slot votes from ticket votes
#'
#' @param unit_votes Numeric ticket votes, aligned with `units`.
#' @param units Ticket keys.
#' @param slots `data.frame` unit, rank: the candidate slots of the ballots.
#' @param split Named list from [hc_split_expected()].
#' @param sdlog Log-normal noise on each candidate's share.
#' @return Numeric votes per slot (rank 1 = the ticket's largest in this draw).
#' @export
hc_split_draw <- function(unit_votes, units, slots, split, sdlog) {
  out <- numeric(nrow(slots))
  for (i in seq_along(units)) {
    j <- which(slots$unit == units[i])
    if (!length(j)) next
    e <- split[[units[i]]]
    if (is.null(e) || length(e) != length(j)) e <- rep(1 / length(j), length(j))
    x <- e * exp(stats::rnorm(length(j), 0, sdlog))
    x <- sort(x / sum(x), decreasing = TRUE)
    out[j] <- unit_votes[i] * x[slots$rank[j]]
  }
  out
}

.hc_pack <- function(tok_t, tok_slot, base, slots) {
  # tok_t: type id per token (in order); tok_slot: 0-based slot; base: weight per type id
  ids <- sort(unique(tok_t))
  tt <- match(tok_t, ids)
  len <- tabulate(tt, nbins = length(ids))
  L <- max(len)
  pos <- stats::ave(seq_along(tt), tt, FUN = seq_along)
  mat <- matrix(-1L, length(ids), L)
  mat[cbind(tt, pos)] <- as.integer(tok_slot)
  b <- base[ids]
  # identical sequences (common after re-keying) are one type with the summed weight
  key <- do.call(paste, c(as.data.frame(mat), sep = ","))
  g <- match(key, unique(key))
  b <- as.numeric(rowsum(b, g, reorder = FALSE))
  mat <- mat[!duplicated(g), , drop = FALSE]
  first <- mat[, 1]
  B <- vapply(seq_len(nrow(slots)) - 1L, function(s) sum(b[first == s]), numeric(1))
  list(mat = mat, base = b, first = first, slots = slots, B = B)
}

#' Ballot types for a candidate count, from an earlier ballot file
#'
#' Re-keys ballot sequences of ticket slots (`"ALP#1>ALP#2>GRN#1"`, from
#' `scripts/build_hare_clark_ballots.R`) to the tickets standing now. A
#' preference for a ticket not standing, or for a slot beyond the number of
#' candidates it now runs, is skipped; a ballot whose FIRST preference is such
#' a slot is dropped (its voters are re-weighted away anyway). A slot with no
#' ballots starting there borrows: from the same ticket's lowest slot (ranks
#' swapped), or, for a ticket with no ballots at all, from the tickets of the
#' same class (renamed), or failing that from every minor ticket.
#'
#' @param seqs Character slot sequences.
#' @param n Ballots of each.
#' @param target `data.frame` unit, ncand, cls: tickets standing now.
#' @param prev_class Named character: class of each earlier ticket key.
#' @return List `mat` (types x preferences, 0-based slot ids, -1 padded),
#'   `base`, `first`, `slots` (unit, rank, cls), `B` (ballots starting at each slot).
#' @export
hc_prepare_ballots <- function(seqs, n, target, prev_class) {
  sp <- strsplit(seqs, ">", fixed = TRUE)
  len <- lengths(sp)
  tid <- rep(seq_along(sp), len); pos <- sequence(len); tok <- unlist(sp, use.names = FALSE)
  u <- sub("#[0-9]+$", "", tok); r <- as.integer(sub("^.*#", "", tok))
  slots <- data.frame(unit = rep(target$unit, target$ncand), rank = sequence(target$ncand),
                      cls = rep(target$cls, target$ncand), stringsAsFactors = FALSE)
  skey <- paste(slots$unit, slots$rank, sep = "#")
  nc <- target$ncand[match(u, target$unit)]
  keep <- !is.na(nc) & r <= nc
  first_ok <- keep[pos == 1L][order(tid[pos == 1L])]
  ok_t <- first_ok[tid] & keep
  T_t <- tid[ok_t]; T_u <- u[ok_t]; T_r <- r[ok_t]
  base <- as.numeric(n)
  fk <- paste(T_u, T_r, sep = "#")[!duplicated(T_t)]
  have <- unique(fk)
  next_id <- length(seqs)
  add_t <- list(); add_u <- list(); add_r <- list(); add_b <- list()
  first_u <- u[pos == 1L][order(tid[pos == 1L])]; first_r <- r[pos == 1L][order(tid[pos == 1L])]
  for (k in setdiff(skey, have)) {
    uu <- sub("#[0-9]+$", "", k); rr <- as.integer(sub("^.*#", "", k))
    own <- have[startsWith(have, paste0(uu, "#"))]
    if (length(own)) {
      r0 <- max(as.integer(sub("^.*#", "", own)))
      d_ids <- which(first_ok & first_u == uu & first_r == r0)
      sel <- tid %in% d_ids & keep
      nu <- u[sel]; nr <- r[sel]
      nr[nu == uu & nr == r0] <- -1L; nr[nu == uu & nr == rr] <- r0; nr[nr == -1L] <- rr
    } else {
      cls_u <- target$cls[match(uu, target$unit)]
      donors <- names(prev_class)[prev_class == cls_u & names(prev_class) != uu]
      d_ids <- which(first_u %in% donors & first_r == 1L)
      if (!length(d_ids)) d_ids <- which(prev_class[first_u] %in% c("OTH") & first_r == 1L)
      if (!length(d_ids)) {          # nothing to borrow: a ballot that stops at its first preference
        next_id <- next_id + 1L
        add_t[[k]] <- next_id; add_u[[k]] <- uu; add_r[[k]] <- rr; add_b[[k]] <- 1
        next
      }
      sel <- tid %in% d_ids
      nu <- u[sel]; nr <- r[sel]
      # rename each donor ballot's own first ticket to the new ticket, swapping ranks 1 and rr
      isown <- nu == first_u[tid[sel]]
      nu[isown] <- uu
      nr2 <- nr; nr2[isown & nr == 1L] <- rr; nr2[isown & nr == rr] <- 1L; nr <- nr2
      nc2 <- target$ncand[match(nu, target$unit)]
      kk <- !is.na(nc2) & nr <= nc2
      st <- tid[sel][kk]; nu <- nu[kk]; nr <- nr[kk]
      dup <- duplicated(paste(st, nu, nr))
      st <- st[!dup]; nu <- nu[!dup]; nr <- nr[!dup]
      ids <- unique(st)
      newid <- next_id + match(st, ids); next_id <- next_id + length(ids)
      add_t[[k]] <- newid; add_u[[k]] <- nu; add_r[[k]] <- nr; add_b[[k]] <- base[ids]
      next
    }
    st <- tid[sel]
    ids <- unique(st)
    newid <- next_id + match(st, ids); next_id <- next_id + length(ids)
    add_t[[k]] <- newid; add_u[[k]] <- nu; add_r[[k]] <- nr; add_b[[k]] <- base[ids]
  }
  all_t <- c(T_t, unlist(add_t)); all_u <- c(T_u, unlist(add_u)); all_r <- c(T_r, unlist(add_r))
  base_all <- c(base, unlist(add_b))
  s0 <- match(paste(all_u, all_r, sep = "#"), skey) - 1L
  if (anyNA(s0)) stop("hc_prepare_ballots(): a kept preference has no slot")
  .hc_pack(all_t, s0, base_all, slots)
}

#' Ballot types for a candidate count, built from party transfer rates
#'
#' For a jurisdiction with no ballot file (Tasmania). A ballot starting at a
#' ticket's slot either stays in the ticket (`1 - leak`: the ticket's other
#' candidates in rank order, then another ticket) or leaves at once (`leak`:
#' another ticket first, then its own ticket). The ticket it goes to, and the
#' one after that, are drawn from `flows` by class and split among that class's
#' tickets by `unit_share`; `flows[, "EXH"]` stops the ballot. Two transfers
#' deep, then exhausted.
#'
#' @param target `data.frame` unit, ncand, cls, fcls.
#' @param unit_share Named numeric expected share of each ticket.
#' @param flows Transfer matrix ([hc_flows_from_ballots()] shape).
#' @param leak Named numeric by transfer class.
#' @return As [hc_prepare_ballots()].
#' @export
hc_synthetic_ballots <- function(target, unit_share, flows, leak) {
  slots <- data.frame(unit = rep(target$unit, target$ncand), rank = sequence(target$ncand),
                      cls = rep(target$cls, target$ncand), stringsAsFactors = FALSE)
  skey <- paste(slots$unit, slots$rank, sep = "#")
  ranks_of <- function(un) { n <- target$ncand[target$unit == un]; paste(un, seq_len(n), sep = "#") }
  dest <- function(from, excl) {           # list of (unit or NA for exhaust, prob)
    fr <- flows[target$fcls[target$unit == from], ]
    cand <- target$unit[!(target$unit %in% excl)]
    if (!length(cand)) return(list(u = NA_character_, p = 1))
    fc <- target$fcls[match(cand, target$unit)]
    sh <- unit_share[cand]; sh[!is.finite(sh) | sh <= 0] <- 1e-6
    cls_w <- vapply(cand, function(v) fr[[fc[cand == v]]] * sh[[v]] / sum(sh[fc == fc[cand == v]]), numeric(1))
    if (sum(cls_w) <= 0) return(list(u = NA_character_, p = 1))
    ex <- fr[["EXH"]]
    list(u = c(cand, NA_character_), p = c(cls_w / sum(cls_w) * (1 - ex), ex))
  }
  tt <- integer(0); ts <- character(0); tb <- numeric(0); id <- 0L
  for (i in seq_len(nrow(slots))) {
    u0 <- slots$unit[i]; own_rest <- setdiff(ranks_of(u0), skey[i])
    lk <- leak[[target$fcls[target$unit == u0]]]
    d1 <- dest(u0, u0)
    for (a in seq_along(d1$u)) {
      v <- d1$u[a]
      d2 <- if (is.na(v)) list(u = NA_character_, p = 1) else dest(v, c(u0, v))
      for (b in seq_along(d2$u)) {
        w2 <- d2$u[b]
        tail_vw <- c(if (!is.na(v)) ranks_of(v), if (!is.na(w2)) ranks_of(w2))
        for (stay in c(TRUE, FALSE)) {
          p <- d1$p[a] * d2$p[b] * (if (stay) 1 - lk else lk)
          if (p <= 0) next
          s <- if (stay) c(skey[i], own_rest, tail_vw) else c(skey[i], tail_vw, own_rest)
          id <- id + 1L
          tt <- c(tt, rep(id, length(s))); ts <- c(ts, s); tb <- c(tb, p)
        }
      }
    }
  }
  .hc_pack(tt, match(ts, skey) - 1L, tb, slots)
}

#' Run a candidate-level count on re-weighted ballot types
#'
#' Scales each ballot type so the ballots starting at each candidate slot sum
#' to that slot's votes, then counts (`hc_stv_cpp()`, the internal C++ count in src/hare_clark_stv.cpp).
#'
#' @param prep From [hc_prepare_ballots()] or [hc_synthetic_ballots()].
#' @param slot_votes First-preference votes per slot.
#' @param seats Members to elect.
#' @return Integer 0/1 elected flag per slot.
#' @export
hc_candidate_count <- function(prep, slot_votes, seats) {
  f <- slot_votes[prep$first + 1L] / prep$B[prep$first + 1L]
  f[!is.finite(f)] <- 0
  hc_stv_cpp(prep$mat, prep$base * f, nrow(prep$slots), as.integer(seats))
}
