# Upper-house (Legislative Council) count with preferences measured from real ballots.
#
# Victoria abolished group voting tickets for 2026 (Electoral Amendment (Miscellaneous Matters) Act 2026, new
# s 93A and s 112A): voters number at least 5 boxes, a lone 1 above the line is still formal, and preferences follow
# what each voter wrote. The Senate has worked that way since 2016, and its ballot-level files record every
# Victorian voter's order. This file:
#   * classes the parties on a ballot (named where the party stands both in the Senate and in a 2026 region, else a
#     left / right / centre pool),
#   * turns the Senate ballots into class sequences and the summaries Pete reads (boxes numbered, next-preference
#     flows with n per cell),
#   * maps those sequences onto one region's groups and runs a group-level STV count over them.
# Plan and validation: docs/plans/upper-house-count-model-2026-11-26.md. Only data.table is needed, so
# scripts/build_upper_house_forecast.R can source this file without loading the package.

# ---- party classes -------------------------------------------------------------------------------------------

# Named classes, tried in order (first match wins, so Libertarian and Labour DLP come before Liberal and Labor).
UH_NAMED <- c(
  LIBT = "libertarian|liberal democrat",
  DLP  = "labour dlp|democratic labour",
  ALP  = "labor party|^labor$",
  LNP  = "liberal|national",
  GRN  = "greens",
  ONP  = "one nation",
  LCA  = "cannabis",
  AJP  = "animal justice",
  FF   = "family first",
  VS   = "victorian socialists",
  SAL  = "socialist alliance",
  SAP  = "sustainable australia",
  SFF  = "shooters",
  DEM  = "australian democrats",
  CIT  = "citizens party",
  UAP  = "united australia|trumpet of patriots")
UH_BLOC <- c(LIBT = "R", DLP = "R", ALP = "L", LNP = "R", GRN = "L", ONP = "R", LCA = "L", AJP = "L", FF = "R",
             VS = "L", SAL = "L", SAP = "C", SFF = "R", DEM = "C", CIT = "C", UAP = "R")
# Bloc of a party with no named class (the pools). Same split as the forecast script's LEFT / RIGHT, extended to the
# Senate's other parties.
UH_LEFT  <- "labor|greens|socialist|cannabis|animal justice|indigenous|aboriginal|reason|progressives|justice party"
UH_RIGHT <- paste0("liberal|national|one nation|family first|libertarian|shooters|dlp|christian|trumpet|united australia|",
                   "rennick|people first|federation|great australian|informed medical")

#' Party class of each group name: a named class, or POOL_L / POOL_R / POOL_C.
#' @noRd
uh_party_class <- function(name) {
  n <- tolower(ifelse(is.na(name), "", name))
  out <- rep(NA_character_, length(n))
  for (k in names(UH_NAMED)) { hit <- is.na(out) & grepl(UH_NAMED[[k]], n); out[hit] <- k }
  pool <- ifelse(grepl(UH_RIGHT, n), "POOL_R", ifelse(grepl(UH_LEFT, n), "POOL_L", "POOL_C"))
  ifelse(is.na(out), pool, out)
}

#' Bloc (L / R / C) of a class token.
#' @noRd
uh_bloc <- function(cls) {
  out <- unname(UH_BLOC[cls])
  pool <- grepl("^POOL_", cls)
  out[pool] <- sub("^POOL_", "", cls[pool])
  out[is.na(out)] <- "C"
  out
}

# ---- fitting from Senate ballots -----------------------------------------------------------------------------

#' Turn Senate ballot sequences into class sequences (the "flows" object).
#'
#' @param seqs data.table from scripts/parse_senate_formal_prefs.py: kind, atl_marks, btl_marks, seq (group
#'   letters joined by '>'), n.
#' @param groups data.table: letter, name (the matching -groups.csv).
#' @param min_marks the instructed above-the-line minimum on that ballot (6 for the Senate).
#' @return list(seq = data.table(first, rest, at_min, n), named = named classes present, min_marks, n_ballots).
#'   `rest` is the class tokens after the first, joined by '>'; at_min marks above-the-line ballots that stopped at
#'   exactly the instructed minimum.
#' @noRd
uh_fit_flows <- function(seqs, groups, min_marks = 6L, label = NA_character_) {
  seqs <- data.table::as.data.table(seqs); groups <- data.table::as.data.table(groups)
  stopifnot(all(c("kind", "atl_marks", "seq", "n") %in% names(seqs)), all(c("letter", "name") %in% names(groups)))
  cl <- stats::setNames(uh_party_class(groups$name), groups$letter)
  tok <- strsplit(seqs$seq, ">", fixed = TRUE)
  len <- lengths(tok)
  ct <- unname(cl[unlist(tok)])
  if (anyNA(ct)) stop("uh_fit_flows: ballot letters with no group row: ",
                      paste(utils::head(unique(unlist(tok)[is.na(ct)])), collapse = ", "))
  ct <- split(ct, rep(seq_along(tok), len))
  first <- vapply(ct, `[`, "", 1L)
  rest <- vapply(ct, function(z) paste(z[-1L], collapse = ">"), "")
  at_min <- seqs$kind == "ATL" & seqs$atl_marks == min_marks
  out <- data.table::data.table(first = first, rest = rest, at_min = at_min, n = seqs$n)[
    , list(n = sum(n)), by = c("first", "rest", "at_min")]
  list(seq = out, named = sort(unique(cl[!grepl("^POOL_", cl)])), min_marks = as.integer(min_marks),
       n_ballots = sum(seqs$n), label = label)
}

#' How many boxes above-the-line voters numbered.
#' @noRd
uh_box_distribution <- function(seqs) {
  s <- data.table::as.data.table(seqs)[kind == "ATL", list(n = sum(n)), by = "atl_marks"][order(atl_marks)]
  s[, share := n / sum(n)][]
}

#' First-to-next preference flows by class, with n per cell, shrunk toward the bloc's pooled row.
#'
#' share = n_ij / n_i; shrunk = (n_ij + K * bloc_share_j) / (n_i + K), the bloc row pooling every first-preference
#' class in the same bloc. "EXH" = the ballot numbers nothing after its first party.
#' @noRd
uh_flow_matrix <- function(flows, K = 200) {
  s <- flows$seq
  nx <- sub(">.*$", "", s$rest); nx[nx == ""] <- "EXH"
  d <- data.table::data.table(first = s$first, nxt = nx, n = s$n)[, list(n = sum(n)), by = c("first", "nxt")]
  d[, n_first := sum(n), by = "first"]; d[, share := n / n_first]
  d[, bloc := uh_bloc(first)]
  b <- d[, list(nb = sum(n)), by = c("bloc", "nxt")][, bshare := nb / sum(nb), by = "bloc"]
  full <- data.table::CJ(first = unique(d$first), nxt = unique(d$nxt))
  full <- merge(full, d[, c("first", "nxt", "n")], by = c("first", "nxt"), all.x = TRUE)
  full[is.na(n), n := 0]
  full[, n_first := sum(n), by = "first"]; full[, bloc := uh_bloc(first)]
  full <- merge(full, b[, c("bloc", "nxt", "bshare")], by = c("bloc", "nxt"), all.x = TRUE)
  full[is.na(bshare), bshare := 0]
  full[, `:=`(share = n / n_first, shrunk = (n + K * bshare) / (n_first + K))]
  out <- full[first != nxt][order(-n_first, first, -n)]
  data.table::setcolorder(out, c("first", "nxt", "n", "n_first", "share", "shrunk", "bloc", "bshare"))
  out[]
}

#' A smaller flows object to ship with the code: per first class, the `top` most frequent class sequences exactly
#' and `tail` weighted draws standing for the rest (same scheme as uh_region_patterns()), so the ballot files
#' themselves can stay out of git. Weights per first class still sum to that class's ballots.
#' @noRd
uh_compact_flows <- function(flows, top = 3000L, tail = 3000L, seed = 1L) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  set.seed(seed)
  s <- flows$seq[order(first, -n)]
  out <- s[, {
    if (.N <= top + tail) list(rest = rest, at_min = at_min, n = as.numeric(n)) else {
      tw <- sum(n[-seq_len(top)]); pk <- top + sample.int(.N - top, tail, replace = TRUE, prob = n[-seq_len(top)])
      d <- data.table::data.table(rest = c(rest[seq_len(top)], rest[pk]), at_min = c(at_min[seq_len(top)], at_min[pk]),
                                  n = c(as.numeric(n[seq_len(top)]), rep(tw / tail, tail)))
      d[, list(n = sum(n)), by = c("rest", "at_min")]
    }
  }, by = "first"]
  flows$seq <- out; flows$compact <- c(top = top, tail = tail); flows
}

#' Write / read a flows object as one CSV (first, rest, at_min, n) plus a one-line header comment.
#' @noRd
uh_write_flows <- function(flows, path) {
  con <- gzfile(path, "w"); on.exit(close(con))
  writeLines(sprintf("# uh_flows label=%s min_marks=%d n_ballots=%.0f named=%s", flows$label, flows$min_marks,
                     flows$n_ballots, paste(flows$named, collapse = ",")), con)
  utils::write.csv(flows$seq, con, row.names = FALSE)
}
uh_read_flows <- function(path) {
  h <- readLines(path, n = 1L)
  if (!grepl("^# uh_flows ", h)) stop("uh_read_flows: ", path, " is not a flows file")
  f <- function(k) sub(paste0("^.*", k, "=([^ ]*).*$"), "\\1", h)
  seq <- data.table::fread(path, skip = 1L, colClasses = list(character = c("first", "rest"), logical = "at_min", numeric = "n"))
  seq[is.na(rest), rest := ""]
  list(seq = seq, named = strsplit(f("named"), ",", fixed = TRUE)[[1]], min_marks = as.integer(f("min_marks")),
       n_ballots = as.numeric(f("n_ballots")), label = f("label"))
}

# ---- mapping a fitted ballot set onto one region's groups ---------------------------------------------------

#' Region ballot patterns: every class sequence mapped to the region's groups, aggregated.
#'
#' For group g with class k: the ballots whose first class is k, mixed with the ballots of k's whole bloc at weight
#' K / (n_k + K) (all bloc ballots when k has none, e.g. a party on no Senate ballot). Each later class token goes to
#' the region's group of that class; a named class not standing here, or a pool token, goes to a not-yet-used group
#' of the same bloc's pool, then to any unused group of the same bloc, else it is dropped (with a pool or bloc group
#' chosen at random, the draw fixed by `seed`). Ballots that stopped at the Senate minimum are cut to `min_to`
#' tokens when `min_to` is smaller (a voter following the instruction numbers the new minimum).
#'
#' `absent` sets that substitution rule, and it moves the forecast (docs/reviews/upper-house-count-validation-2026-11-26.md):
#' "pool" (the pre-registered rule, above), "bloc" (any unused group of the same bloc, equally likely, named
#' parties included), "skip" (the mark is dropped and the voter's next mark is used; ballots get shorter).
#'
#' @param group_names names of the region's groups (order = the vote vector's order).
#' @param top,tail the `top` most frequent class sequences per group are kept exactly; the rest are represented by
#'   `tail` draws (with replacement, by weight), each carrying an equal share of the rest's weight. Unbiased.
#' @return list(S = integer matrix P x (G + 1), S[, 1] the first group and 0 after the ballot ends; share = each
#'   pattern's share of its first group's votes; group = group_names; class; diag = effective length summary).
#' @noRd
uh_region_patterns <- function(group_names, flows, min_to = NULL, K = 200, top = 2000L, tail = 2000L, seed = 1L,
                               absent = c("pool", "bloc", "skip")) {
  absent <- match.arg(absent)
  G <- length(group_names)
  min_from <- flows$min_marks; if (is.null(min_to)) min_to <- min_from
  cls <- uh_party_class(group_names)
  cls[!(cls %in% flows$named) & !grepl("^POOL_", cls)] <- paste0("POOL_", uh_bloc(cls[!(cls %in% flows$named) & !grepl("^POOL_", cls)]))
  bl <- uh_bloc(cls)
  s <- flows$seq
  s_bloc <- uh_bloc(s$first)
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  set.seed(seed)
  rows <- vector("list", G); diag <- vector("list", G)
  for (g in seq_len(G)) {
    own <- s[first == cls[g]]; n_own <- sum(own$n)
    bb <- s[s_bloc == bl[g]]
    w_own <- if (n_own > 0) n_own / (n_own + K) else 0
    if (n_own == 0 && !nrow(bb)) stop("uh_region_patterns: no ballots for ", group_names[g], " (", cls[g],
                                      ") or anyone in its bloc: its votes would vanish from the count")
    src <- data.table::rbindlist(list(
      if (n_own > 0) own[, list(rest, at_min, w = w_own * n / n_own)],
      bb[, list(rest, at_min, w = (1 - w_own) * n / sum(n))]))
    src <- src[, list(w = sum(w)), by = c("rest", "at_min")][order(-w)]
    cover <- 1
    if (nrow(src) > top + tail) {                  # the top sequences exactly, plus an unbiased sample of the rest
      tl <- src[-seq_len(top)]; tw <- sum(tl$w); cover <- 1 - tw
      pick <- tl[sample.int(nrow(tl), tail, replace = TRUE, prob = tl$w)][, w := tw / tail]
      src <- data.table::rbindlist(list(src[seq_len(top)], pick))[, list(w = sum(w)), by = c("rest", "at_min")]
    }
    tk <- strsplit(src$rest, ">", fixed = TRUE)
    M <- matrix(0L, nrow(src), G + 1L); M[, 1] <- g
    eff <- integer(nrow(src))
    for (p in seq_along(tk)) {
      t <- tk[[p]]
      if (src$at_min[p] && min_to < min_from) t <- t[seq_len(min(length(t), min_to - 1L))]
      used <- logical(G); used[g] <- TRUE; j <- 1L
      for (z in t) {
        h <- which(cls == z & !used)
        if (!length(h) && absent != "skip") {
          b <- uh_bloc(z)
          if (absent == "pool") h <- which(cls == paste0("POOL_", b) & !used)
          if (!length(h)) h <- which(bl == b & !used)
        }
        if (!length(h)) next
        if (length(h) > 1L) h <- h[sample.int(length(h), 1L)]
        j <- j + 1L; M[p, j] <- h; used[h] <- TRUE
      }
      eff[p] <- j
    }
    rows[[g]] <- list(M = M, w = src$w)
    diag[[g]] <- data.table::data.table(group = group_names[g], class = cls[g], n_own = n_own, w_own = w_own,
                                        top_cover = cover, mean_len = sum(eff * src$w), len_at_min = if (any(src$at_min))
                                          sum((eff * src$w)[src$at_min]) / sum(src$w[src$at_min]) else NA_real_)
  }
  S <- do.call(rbind, lapply(rows, `[[`, "M")); w <- unlist(lapply(rows, `[[`, "w"))
  pk <- do.call(paste, c(as.data.frame(S), sep = "."))      # identical mapped ballots collapse (column not "key":
  agg <- data.table::data.table(pk = pk, w = w, i = seq_along(w))[, list(w = sum(w), i = i[1L]), by = "pk"]  # data.table() eats key=)
  list(S = S[agg$i, , drop = FALSE], share = agg$w, group = group_names, class = cls,
       diag = data.table::rbindlist(diag))
}

#' Patterns from real ballots (every distinct sequence, no model): for checking the count itself.
#' @noRd
uh_ballot_patterns <- function(seqs, letters) {
  G <- length(letters)
  tok <- strsplit(seqs$seq, ">", fixed = TRUE); len <- lengths(tok)
  S <- matrix(0L, length(tok), G + 1L)
  S[cbind(rep(seq_along(tok), len), sequence(len))] <- match(unlist(tok), letters)
  stopifnot(!anyNA(S))
  vv <- .uh_tab(S[, 1], as.numeric(seqs$n), G)
  list(S = S, share = seqs$n / vv[S[, 1]], votes = vv, group = letters)
}

# ---- the count -----------------------------------------------------------------------------------------------

.uh_tab <- function(k, w, G) {
  keep <- k > 0L
  out <- numeric(G)
  if (any(keep)) { s <- rowsum(w[keep], k[keep]); out[as.integer(rownames(s))] <- s[, 1] }
  out
}

#' Group-level STV for one region.
#'
#' Droop quota = total / (seats + 1). A group at a quota wins a seat and keeps the rest for its next candidate,
#' every ballot in its pile scaled by (votes - quota) / votes. A group out of candidates passes its pile on.
#' Otherwise the lowest group is excluded and each ballot moves to the next group on it still in the count, or
#' exhausts. When the groups left equal the seats left, all are elected; with two left for the last seat, the
#' higher wins without the other being excluded (as the Senate and VEC counts stop).
#'
#' @param v votes by group (length G, same order as the patterns' groups).
#' @param pat list(S, share) from uh_region_patterns() or uh_ballot_patterns().
#' @param cands candidates per group (default: seats each, i.e. no limit).
#' @param trace TRUE also returns each step (what happened, live votes, exhausted votes) and the tally after it.
#' @param replay optional integer vector of actions to follow instead of choosing (+g elect group g, -g exclude
#'   group g), e.g. the actual count's order, so two ballot sets can be compared step by step on the same path.
#' @return integer seats won per group (or list(won, steps, order, tallies, ...) when trace = TRUE).
#' @noRd
uh_stv <- function(v, pat, seats = 5L, cands = NULL, trace = FALSE, replay = NULL) {
  S <- pat$S; G <- ncol(S) - 1L; P <- nrow(S)
  stopifnot(length(v) == G, all(v >= 0))
  if (is.null(cands)) cands <- rep(seats, G)
  cur <- S[, 1]; ptr <- rep(1L, P)
  w <- v[cur] * pat$share
  tally <- .uh_tab(cur, w, G)
  q <- sum(v) / (seats + 1)
  alive <- tally > 0 & cands > 0
  won <- integer(G); exh <- 0; ord <- integer(0); steps <- NULL
  move <- function(gi) {
    idx <- which(cur == gi)
    tally[gi] <<- 0
    pend <- idx
    while (length(pend)) {
      ptr[pend] <<- ptr[pend] + 1L
      nx <- S[cbind(pend, ptr[pend])]
      end <- nx == 0L
      land <- !end; land[land] <- alive[nx[land]]
      cur[pend[end]] <<- 0L
      cur[pend[land]] <<- nx[land]
      pend <- pend[!(end | land)]
    }
    add <- .uh_tab(cur[idx], w[idx], G)
    exh <<- exh + sum(w[idx][cur[idx] == 0L])
    tally <<- tally + add
  }
  tallies <- NULL
  log_step <- function(what, gi) if (trace) {
    steps[[length(steps) + 1L]] <<- data.frame(step = length(steps) + 1L, what = what, group = gi, live = sum(tally),
                                               exhausted = exh, elected = sum(won))
    tallies[[length(tallies) + 1L]] <<- tally
  }
  elect <- function(i) {
    won[i] <<- won[i] + 1L; ord <<- c(ord, i)
    idx <- which(cur == i); f <- if (tally[i] > 0) max(0, (tally[i] - q) / tally[i]) else 0
    w[idx] <<- w[idx] * f; tally[i] <<- max(0, tally[i] - q)
    log_step("elected", i)
    if (won[i] >= cands[i]) { alive[i] <<- FALSE; move(i); log_step("surplus passed on", i) }
  }
  if (!is.null(replay)) {
    for (a in replay) {
      if (a > 0L) elect(a) else { alive[-a] <- FALSE; move(-a); log_step("excluded", -a) }
    }
    if (!trace) return(won)
    return(list(won = won, order = ord, steps = do.call(rbind, steps), tallies = do.call(rbind, tallies),
                tally = tally, exhausted = exh, quota = q))
  }
  repeat {
    left <- seats - sum(won); if (left <= 0L || !any(alive)) break
    hit <- which(alive & tally >= q * (1 - 1e-12))
    if (length(hit)) {
      elect(hit[which.max(tally[hit])])
      next
    }
    if (left == 1L && sum(alive) == 2L) {          # last two for the last seat: the higher wins, no exclusion
      ai <- which(alive); i <- ai[which.max(tally[ai])]
      won[i] <- won[i] + 1L; ord <- c(ord, i); log_step("elected: higher of the last two", i); break
    }
    if (sum(alive) <= left) {
      ai <- which(alive)[order(-tally[alive])]
      won[ai] <- won[ai] + 1L; ord <- c(ord, ai); log_step("elected: groups left = seats left", ai[1L]); break
    }
    lo <- which(alive)[which.min(tally[alive])]
    alive[lo] <- FALSE; move(lo); log_step("excluded", lo)
  }
  if (!trace) return(won)
  list(won = won, order = ord, steps = do.call(rbind, steps), tallies = do.call(rbind, tallies), tally = tally,
       exhausted = exh, quota = q)
}

#' The action list of a traced count, for uh_stv(replay = ): +g elect, -g exclude.
#' @noRd
uh_replay_of <- function(tr) {
  st <- tr$steps; out <- integer(0)
  for (k in seq_len(nrow(st))) {
    a <- st$what[k]; gi <- st$group[k]
    if (a %in% c("elected", "elected: higher of the last two")) out <- c(out, gi)
    else if (a == "excluded") out <- c(out, -gi)
    else if (a == "elected: groups left = seats left") out <- c(out, utils::tail(tr$order, length(tr$order) - sum(out > 0)))
  }
  out
}

#' Seats won per group in one region, for one or many simulations.
#'
#' @param votes_by_group numeric vector (one count) or N x G matrix (one row per simulation), any unit; columns in
#'   the order of `group_bloc_or_class`.
#' @param group_bloc_or_class the region's group names (classed by uh_party_class()).
#' @param flows a uh_fit_flows() object, or a prebuilt uh_region_patterns() list for these groups.
#' @param seats seats in the region (5 for a Victorian region).
#' @param cands candidates per group (default no limit).
#' @param min_to above-the-line minimum on the target ballot (5 for Victoria from 2026).
#' @param top,tail pattern-bank size per group when `flows` is a fitted object (150 / 150 is what was timed:
#'   about 90 s for 4,000 simulations x 8 regions).
#' @param absent how a party not standing in the region is substituted (see uh_region_patterns()).
#' @return integer N x G matrix of seats won.
#' @noRd
count_region <- function(votes_by_group, group_bloc_or_class, flows, seats = 5L, cands = NULL, min_to = 5L, seed = 1L,
                         top = 150L, tail = 150L, absent = "pool") {
  V <- if (is.matrix(votes_by_group)) votes_by_group else matrix(votes_by_group, nrow = 1L)
  stopifnot(ncol(V) == length(group_bloc_or_class))
  pat <- if (!is.null(flows$S)) flows else
    uh_region_patterns(group_bloc_or_class, flows, min_to = min_to, top = top, tail = tail, seed = seed, absent = absent)
  W <- t(vapply(seq_len(nrow(V)), function(i) uh_stv(V[i, ], pat, seats, cands), integer(ncol(V))))
  if (ncol(V) == 1L) W <- t(W)
  colnames(W) <- if (is.null(colnames(V))) group_bloc_or_class else colnames(V)
  W
}

utils::globalVariables(c("kind", "atl_marks", "share", "n_first", "bloc", "nb", "bshare", "nxt", "shrunk",
                         "rest", "at_min", "w", "first", "pk", "i"))
