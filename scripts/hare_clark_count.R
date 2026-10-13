# hare_clark_count.R -- Hare-Clark (ACT rules) count from ballot-level preferences.
#
# STANDALONE PROTOTYPE (2026-10-13). Reads nothing from R/ and writes nothing to
# output/. Design notes, sources, rules and validation: docs/reviews/hare-clark-prototype-2026-10-13.md
#
# Run:  powershell.exe -Command 'Rscript scripts/hare_clark_count.R'            (all 5 electorates, 2020)
#       powershell.exe -Command 'Rscript scripts/hare_clark_count.R Brindabella'  (one electorate)
# Source it (no run) to use the functions:  source("scripts/hare_clark_count.R")
#
# RULES IMPLEMENTED (ACT Electoral Act 1992 Sch 4 as reverse-engineered from the official 2020 count
# sheets plus the Elections ACT / PRSA descriptions; the Act text itself could not be fetched, see doc):
#   * Quota = floor(formal / (seats + 1)) + 1.
#   * Votes are carried to SIX DECIMAL PLACES (micro-votes below; the official sheets show e.g. 5640.081618).
#     Anything below a micro-vote is "loss by fraction" (it can be negative on exclusions).
#   * A candidate reaching the quota is elected at the end of the count. Several elected at once are queued
#     in order of election, larger surplus first.
#   * Surplus: while any elected candidate has an undistributed surplus, the EARLIEST queued one is distributed
#     before any exclusion. Only the LAST PARCEL (all papers the candidate received at the most recent count
#     at which he received any; for a first-preference quota that is every paper) is distributed.
#     Transfer value (TV) = surplus / number of papers in that parcel that have a next continuing preference,
#     capped at the value each paper already carries (so a TV never exceeds 1, and never rises). Recipients get
#     floor_6dp(papers x TV). The surplus a TV of 1 cannot carry is exhausted votes.
#   * Exclusion: lowest continuing candidate; ALL his papers move to the next continuing preference at the value
#     they already carry (papers grouped by value, floored per recipient and value). One candidate per count.
#     No bulk exclusion (the official 2020 sheets exclude one at a time).
#   * Surpluses are distributed even when the seats are otherwise filled; a candidate is elected WITHOUT quota
#     only when no surplus is queued and continuing candidates == vacancies.
#   * Ties for exclusion: the candidate with fewer votes at the most recent earlier count where the tied
#     candidates differed; if never different, "lot" (here: lowest ballot-paper code, FLAGGED in $ties).
#
# CHECK CODES (prefix HC): HC1 ballots load, HC2 vote conservation, HC3 seats filled,
#   HC4 elected set+order = official, HC5 every count total = official, HC6 negative control.

suppressPackageStartupMessages(library(data.table))

MICRO <- 1e6
.fl <- function(x) floor(x + 1e-6)            # floor a quantity held in micro-votes

hc_check <- function(code, ok, msg) {
  cat(sprintf("  %s %s  %s\n", code, if (isTRUE(ok)) "PASS" else "FAIL", msg))
  invisible(isTRUE(ok))
}

# ---------------------------------------------------------------- loading
# Streams ONE electorate: reads the long file, folds it to unique preference sequences, drops the raw rows.
hc_read_act_ballots <- function(dir, electorate_code, verbose = TRUE) {
  ec <- electorate_code
  enames <- fread(file.path(dir, "Electorates.txt"))
  ename  <- enames[[2]][enames[[1]] == ec]
  cand   <- fread(file.path(dir, "Candidates.txt"))[ecode == ec]
  grp    <- fread(file.path(dir, "Groups.txt"))[ecode == ec]
  stopifnot(nrow(cand) > 0, length(ename) == 1)
  cand[, cid := pcode * 1000L + ccode]
  cand[grp, party := i.pname, on = "pcode"]
  # "DAY, Cathy" -> "Cathy DAY"
  cand[, name := sub("^(.*?), (.*)$", "\\2 \\1", cname, perl = TRUE)]
  cand[, idx := .I]

  f <- file.path(dir, paste0(ename, "Total.txt"))
  d <- fread(f, select = c("batch", "pindex", "pref", "pcode", "ccode"))
  n_rows <- nrow(d)
  d[, cid := pcode * 1000L + ccode]
  setorder(d, batch, pindex, pref)
  d[, bid := rleid(batch, pindex)]
  d[, k := rowid(bid)]
  bad <- d[pref != k, .N]
  d[, cidx := cand$idx[match(cid, cand$cid)]]
  stopifnot(!anyNA(d$cidx))
  seqs <- d[, .(s = paste(cidx, collapse = ",")), by = bid]
  n_ballots <- nrow(seqs)
  u <- seqs[, .(n = .N, bid = bid[1]), by = s]
  u[, sid := .I]
  L <- d[bid %in% u$bid, .(bid, pos = k, cidx)]
  L[u, sid := i.sid, on = "bid"]
  L <- L[, .(sid, pos, cidx)]
  setkey(L, sid, pos)
  rm(d, seqs); invisible(gc(verbose = FALSE))
  npap <- u[order(sid), n]
  if (verbose) cat(sprintf("  %s: %d rows -> %d formal ballots -> %d distinct preference sequences; candidates %d\n",
                           ename, n_rows, n_ballots, nrow(u), nrow(cand)))
  list(name = ename, ecode = ec, cands = cand, L = L, npap = npap,
       n_rows = n_rows, n_ballots = n_ballots, nonseq_rows = bad)
}

# next continuing preference for each distinct sequence id (NA = exhausted)
.next_pref <- function(L, sids, cont) {
  sub <- L[.(sids), nomatch = NULL]
  sub <- sub[cidx %in% cont]
  sub <- sub[!duplicated(sid)]
  data.table(sid = sids, nxt = sub$cidx[match(sids, sub$sid)])
}

# ---------------------------------------------------------------- the count
hc_count <- function(bal, seats = 5L, verbose = FALSE, frac_order = "desc") {
  L <- bal$L; npap <- bal$npap; K <- nrow(bal$cands); nm <- bal$cands$name
  N <- sum(npap); quota <- floor(N / (seats + 1)) + 1; Q <- quota * MICRO
  st <- new.env()
  st$status <- rep("continuing", K); st$votes <- numeric(K)
  st$parcels <- vector("list", K); st$exh <- 0; st$loss <- 0
  st$elected <- integer(0); st$elected_count <- integer(0); st$elected_quota <- logical(0)
  st$queue <- integer(0); st$count <- 0L
  st$rows <- list(); st$ties <- character(0); st$hist <- list()

  record <- function(event, newly) {
    st$count <- st$count + 1L
    st$hist[[st$count]] <- st$votes
    st$rows[[st$count]] <- list(count = st$count, event = event, votes = st$votes / MICRO,
                                exh = st$exh / MICRO, loss = st$loss / MICRO,
                                elected = nm[newly])
    if (verbose) cat(sprintf("  count %2d  %-40s exh %9.3f loss %9.6f%s\n", st$count, event,
                             st$exh / MICRO, st$loss / MICRO,
                             if (length(newly)) paste("  ELECTED:", paste(nm[newly], collapse = "; ")) else ""))
  }
  # end-of-count elections
  elect_step <- function(event) {
    cont <- which(st$status == "continuing")
    hit <- cont[st$votes[cont] >= Q - 1e-6]
    hit <- hit[order(-st$votes[hit], hit)]
    newly <- integer(0)
    for (k in hit) {
      st$status[k] <- "elected"; st$elected <- c(st$elected, k)
      st$elected_count <- c(st$elected_count, st$count + 1L); st$elected_quota <- c(st$elected_quota, TRUE)
      st$queue <- c(st$queue, k); newly <- c(newly, k)
    }
    cont <- which(st$status == "continuing")
    if (!length(st$queue) && length(cont) == seats - length(st$elected) && length(cont) > 0) {
      for (k in cont[order(-st$votes[cont], cont)]) {
        st$status[k] <- "elected"; st$elected <- c(st$elected, k)
        st$elected_count <- c(st$elected_count, st$count + 1L); st$elected_quota <- c(st$elected_quota, FALSE)
        newly <- c(newly, k)
      }
    }
    record(event, newly)
  }
  # papers dt(sid,n,v) -> list(parcels per recipient, T votes per recipient, exhausted exact, floors)
  spread <- function(p, newv = NULL) {
    cont <- which(st$status == "continuing")
    nx <- .next_pref(L, unique(p$sid), cont)
    p <- merge(p, nx, by = "sid", all.x = TRUE, sort = FALSE)
    if (!is.null(newv)) p[!is.na(nxt), v := pmin(v, newv)]
    tr <- p[!is.na(nxt)]; ex <- p[is.na(nxt)]
    g <- tr[, .(votes = .fl(sum(n) * v[1] * MICRO), n = sum(n)), by = .(nxt, v)]
    list(tr = tr, g = g, ex = ex)
  }
  give <- function(tr, g) {
    for (k in unique(tr$nxt)) {
      st$votes[k] <- st$votes[k] + sum(g$votes[g$nxt == k])
      st$parcels[[k]] <- c(st$parcels[[k]], list(list(cnt = st$count + 1L, dt = tr[nxt == k, .(sid, n, v)])))
    }
  }

  # count 1: first preferences
  f <- L[pos == 1L, .(sid, cidx)]; f[, n := npap[sid]]
  for (k in unique(f$cidx)) {
    p <- f[cidx == k, .(sid, n, v = 1)]
    st$parcels[[k]] <- list(list(cnt = 1L, dt = p)); st$votes[k] <- sum(p$n) * MICRO
  }
  st$count <- 0L
  elect_step("First preferences")

  guard <- 0L
  while (length(st$elected) < seats && (guard <- guard + 1L) < 500L) {
    if (length(st$queue)) {
      k <- st$queue[1]; st$queue <- st$queue[-1]
      S <- st$votes[k] - Q
      if (S < 1e-6) { st$votes[k] <- Q; next }                      # exactly a quota: set aside, no count
      cnts <- vapply(st$parcels[[k]], function(z) z$cnt, 1L)
      p <- rbindlist(lapply(st$parcels[[k]][cnts == max(cnts)], `[[`, "dt"))
      p <- p[, .(n = sum(n)), by = .(sid, v)]
      cont <- which(st$status == "continuing")
      nx <- .next_pref(L, unique(p$sid), cont)
      ptrans <- sum(p$n[p$sid %in% nx$sid[!is.na(nx$nxt)]])
      tvs <- if (ptrans > 0) S / MICRO / ptrans else 0           # votes per paper
      sp <- spread(p, newv = tvs)
      Tt <- sum(sp$g$votes)
      exact <- sum(sp$tr$n * sp$tr$v) * MICRO
      E <- .fl(max(S - exact, 0))
      lossnow <- S - Tt - E
      give(sp$tr, sp$g)
      # the official ACT sheets book the non-transferable part of a SURPLUS under "Loss by fraction",
      # and only papers exhausted at an EXCLUSION under "Votes exhausted"; follow that so columns compare.
      st$votes[k] <- Q; st$loss <- st$loss + E + lossnow
      elect_step(sprintf("Surplus of %s", nm[k]))
    } else {
      cont <- which(st$status == "continuing")
      v <- st$votes[cont]; low <- cont[v == min(v)]
      if (length(low) > 1) {
        cand <- low
        for (h in rev(seq_len(st$count))) {
          hv <- st$hist[[h]][cand]; cand <- cand[hv == min(hv)]
          if (length(cand) == 1) break
        }
        if (length(cand) > 1) {
          st$ties <- c(st$ties, sprintf("count %d: LOT among %s", st$count + 1L, paste(nm[cand], collapse = " / ")))
          cand <- cand[1]
        } else st$ties <- c(st$ties, sprintf("count %d: tie %s resolved by earlier count", st$count + 1L, paste(nm[low], collapse = " / ")))
        low <- cand
      }
      x <- low
      p <- rbindlist(lapply(st$parcels[[x]], `[[`, "dt"))[, .(n = sum(n)), by = .(sid, v)]
      st$status[x] <- "excluded"; st$parcels[x] <- list(NULL)
      # ACT exclusion runs in STAGES, one count per distinct transfer value among the candidate's papers
      # (full-value papers first, then each fraction group). "partially excluded" until the last stage.
      vals <- sort(unique(p$v), decreasing = (frac_order == "desc"))
      for (gi in seq_along(vals)) {
        last <- gi == length(vals)
        sp <- spread(p[v == vals[gi]])
        Tt <- sum(sp$g$votes)
        E <- if (nrow(sp$ex)) sum(sp$ex[, .(e = .fl(sum(n) * v[1] * MICRO)), by = v]$e) else 0
        moved <- Tt + E
        lossnow <- if (last) st$votes[x] - moved else 0       # the leftover sub-vote remainder goes with the last stage
        give(sp$tr, sp$g)
        st$votes[x] <- if (last) 0 else st$votes[x] - moved
        st$exh <- st$exh + E; st$loss <- st$loss + lossnow
        elect_step(sprintf("%s %s", if (last) "Exclude" else "Exclude (partial)", nm[x]))
        if (length(st$elected) >= seats) break                # seats full: the count stops, even mid-exclusion
      }
    }
  }
  votes_mat <- do.call(rbind, lapply(st$rows, `[[`, "votes")); colnames(votes_mat) <- nm
  ev <- rbindlist(lapply(st$rows, function(r) data.table(count = r$count, event = r$event, exhausted = r$exh,
                                                         loss = r$loss, elected = paste(r$elected, collapse = "; "))))
  list(name = bal$name, N = N, quota = quota, seats = seats, votes = votes_mat, events = ev,
       elected = data.table(order = seq_along(st$elected), name = nm[st$elected], count = st$elected_count,
                            by_quota = st$elected_quota),
       ties = st$ties, cands = bal$cands)
}

# ---------------------------------------------------------------- official sheet (Table 2, votes)
hc_read_official_act <- function(path) {
  x <- as.data.frame(readxl::read_excel(path, col_names = FALSE, .name_repair = "minimal"),
                     stringsAsFactors = FALSE)
  hdr <- as.character(unlist(x[2, ]))
  ce <- which(hdr == "Votes Exhausted at Count"); stopifnot(length(ce) == 1)
  cols <- 2:(ce - 1)
  nm <- as.character(unlist(x[3, cols]))
  cnt <- suppressWarnings(as.numeric(x[[1]])); is_tot <- !is.na(cnt) & seq_len(nrow(x)) >= 4
  num <- function(j) suppressWarnings(as.numeric(x[[j]]))
  tot <- sapply(cols, function(j) { v <- num(j)[is_tot]; v[is.na(v)] <- 0; v })
  colnames(tot) <- nm; rownames(tot) <- cnt[is_tot]
  rem <- as.character(x[[ce + 3]])
  sent <- unlist(strsplit(rem[!is.na(rem)], "(?<=\\.)\\s+", perl = TRUE))
  m <- regmatches(sent, regexec("^(.*) elected ([0-9]+)\\.$", sent))
  m <- m[lengths(m) == 3]
  el <- data.table(order = as.integer(vapply(m, `[`, "", 3)), name = sub("^First preferences ", "", vapply(m, `[`, "", 2)))[order(order)]
  list(totals = tot, exh = num(ce)[is_tot], loss = num(ce + 1)[is_tot], elected = el, remarks = rem)
}

.norm <- function(s) gsub("[^A-Z]", "", toupper(s))

# compare engine vs official; returns list(ok, first_divergence, per-count max abs diff)
hc_compare <- function(res, off, tol = 2e-6) {
  key_e <- .norm(colnames(res$votes)); key_o <- .norm(colnames(off$totals))
  m <- match(key_o, key_e)
  if (anyNA(m)) stop("official candidate not found in ballots: ", paste(colnames(off$totals)[is.na(m)], collapse = ", "))
  nc <- min(nrow(res$votes), nrow(off$totals))
  mine <- res$votes[seq_len(nc), m, drop = FALSE]
  theirs <- off$totals[seq_len(nc), , drop = FALSE]
  diff <- abs(mine - theirs)
  per <- apply(diff, 1, max)
  bad <- which(per > tol)
  first <- NULL
  if (length(bad)) {
    c1 <- bad[1]; j <- which.max(diff[c1, ])
    first <- list(count = c1, candidate = colnames(theirs)[j], mine = mine[c1, j], official = theirs[c1, j],
                  event = res$events$event[c1])
  }
  el_ok <- identical(.norm(res$elected$name), .norm(off$elected$name))
  list(counts_mine = nrow(res$votes), counts_official = nrow(off$totals), max_diff = per,
       n_bad = length(bad), first = first, elected_ok = el_ok,
       exh_diff = max(abs(res$events$exhausted[seq_len(nc)] - off$exh[seq_len(nc)])),
       loss_diff = max(abs(res$events$loss[seq_len(nc)] - off$loss[seq_len(nc)])))
}

# ---------------------------------------------------------------- driver
hc_run_electorate <- function(dir, ename, ecode, official_dir = dir, seats = 5L, verbose = FALSE) {
  t0 <- Sys.time()
  bal <- hc_read_act_ballots(dir, ecode)
  hc_check("HC1", bal$nonseq_rows == 0 && bal$n_ballots > 40000,
           sprintf("%s: %d ballots, %d rows with a gap/repeat in preference numbers", ename, bal$n_ballots, bal$nonseq_rows))
  res <- hc_count(bal, seats = seats, verbose = verbose)
  cat(sprintf("  %s: formal %d, quota %d, %d counts, %.1fs\n", ename, res$N, res$quota, nrow(res$votes),
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  tot <- rowSums(res$votes) + res$events$exhausted + res$events$loss
  hc_check("HC2", all(abs(tot - res$N) < 1e-4), sprintf("votes + exhausted + loss = %d at every count (max dev %.2g)", res$N, max(abs(tot - res$N))))
  hc_check("HC3", nrow(res$elected) == seats, sprintf("%d seats filled", nrow(res$elected)))
  off <- hc_read_official_act(file.path(official_dir, sprintf("table2_%s-2020-distribution-of-preferences.xlsx", ename)))
  cmp <- hc_compare(res, off)
  hc_check("HC4", cmp$elected_ok, sprintf("elected (order): mine = %s | official = %s",
                                          paste(res$elected$name, collapse = ", "), paste(off$elected$name, collapse = ", ")))
  hc_check("HC5", cmp$n_bad == 0 && cmp$counts_mine == cmp$counts_official,
           sprintf("counts mine %d vs official %d; counts with any total differing: %d; max exhausted diff %.6f, max loss diff %.6f",
                   cmp$counts_mine, cmp$counts_official, cmp$n_bad, cmp$exh_diff, cmp$loss_diff))
  if (!is.null(cmp$first))
    cat(sprintf("    FIRST DIVERGENCE count %d (%s): %s mine %.6f official %.6f\n", cmp$first$count, cmp$first$event,
                cmp$first$candidate, cmp$first$mine, cmp$first$official))
  # HC6 negative control: build a fake "official" from our own totals (must compare clean), nudge one
  # total by 1 vote (the comparison must then flag exactly that count).
  self <- list(totals = res$votes, exh = res$events$exhausted, loss = res$events$loss, elected = res$elected)
  clean <- hc_compare(res, self)$n_bad == 0
  cc <- min(5L, nrow(res$votes)); self$totals[cc, 2] <- self$totals[cc, 2] + 1
  c2 <- hc_compare(res, self)
  hc_check("HC6", clean && !is.null(c2$first) && c2$first$count == cc,
           "negative control: self-compare is clean and a 1-vote perturbation is caught at the right count")
  if (length(res$ties)) cat("  ties:", paste(res$ties, collapse = " | "), "\n")
  invisible(list(res = res, cmp = cmp, off = off))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  root <- "external/reference/elections-act/raw/2020"
  all_e <- c("Brindabella", "Ginninderra", "Kurrajong", "Murrumbidgee", "Yerrabi")
  todo <- if (length(args)) intersect(all_e, args) else all_e
  out <- list()
  for (e in todo) {
    cat("\n== ACT 2020:", e, "\n")
    out[[e]] <- hc_run_electorate(root, e, match(e, all_e), verbose = length(args) > 0)
  }
  cat("\n== Summary (counts differing from the official sheet; elected order identical?)\n")
  for (e in names(out)) cat(sprintf("  %-13s counts %d/%d  differing %d  elected identical %s%s\n", e,
                                    out[[e]]$cmp$counts_mine, out[[e]]$cmp$counts_official, out[[e]]$cmp$n_bad,
                                    out[[e]]$cmp$elected_ok,
                                    if (!is.null(out[[e]]$cmp$first)) sprintf("  first diff: count %d (%s)", out[[e]]$cmp$first$count, out[[e]]$cmp$first$event) else ""))
}
