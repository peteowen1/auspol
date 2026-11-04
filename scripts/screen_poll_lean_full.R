# Poll-lean screen, arm FULL at the statewide stage (plans/prereg-poll-lean-2026-11-02.md, order of work step 4): every
# term together, each estimated time-forward.
#
#   powershell.exe -Command 'Rscript "scripts/screen_poll_lean_full.R"'
#
# FULL, per scored election E (only elections ended before E's cycle began are used for any of it):
#   1. lean against results, BACKFITTED so no source of lean is counted twice: firm lean (arm REC) first; the sponsor
#      class lean (arm SPN) estimated on what the firm lean leaves; the method class lean (arm MOD) on what both
#      leave. All three shrunk to zero (R/poll_lean.R). Applied to the polls as three logit offsets.
#   2. noise: trend_as_at(weights = "record"), each firm's noise from its record at earlier elections (9 Oct arm).
#   3. day-0 anchor strength (arm ANC): every grid value fitted under 1-2, the value picked TIME-FORWARD (lowest mean
#      primary over earlier elections, ties to the published "1").
# Not in FULL: arm AGE (the campaign walk), replaced by BLD under Amendment 1 (Pete's choice); and BLD itself, which
# acts on the post-trend recent-poll blend, not the trend this screen scores (BLD alone: +0.069 worse, SE 0.055).
#   PLF0  backfit check: the three error tables line up row for row
#   PLF1  per election: the anchor pick and the paired change against the published trend
#   PLF2  clause 1, clause 3 (leave-one-election-out), clause 6 (direction)
#   PLF3  One Nation's signed error and sa2026 (the named-in-advance unacceptable win)
#   PLF4  the live walk: vic2026 with every completed election, published vs FULL
# Writes nothing to output/. Data.table NSE: no local shares a column name inside [...].

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/published_flags.R")
for (k in names(PUBLISHED_FLAGS)) if (Sys.getenv(k) == "") do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[k]]), k))
stopifnot(Sys.getenv("AUSPOL_ANCHOR_SD_MULT") == "1")

GRID <- c("1", "2", "4", "none", "gap:0.5", "gap:1", "gap:2")   # arm ANC's grid; "1" is the published anchor
REGIONS <- c("fed", "nsw", "vic", "qld", "wa", "sa", "nt")
LIVE <- c("vic2026", "nsw2027")
MAIN <- c("ALP", "LNP", "GRN", "ONP")

cand <- fread("output/candidacies.csv", select = c("election", "region", "year", "party", "votes"))
cand[, votes := as.numeric(votes)]
tot <- cand[, .(tot = sum(votes, na.rm = TRUE)), by = .(election)]
act <- merge(cand[, .(v = sum(votes, na.rm = TRUE)), by = .(election, region, year, party)], tot, by = "election")
act[, share := 100 * v / tot]
cycles <- as.data.table(load_election_cycles())
pri <- as.data.table(load_prior_results())
pf <- load_preference_flows()

# ---- the three groupings, one label per load_polls() row --------------------------------------------------------
ERAS <- poll_method_eras()
SPN <- list(); MOD <- list()
spn_of <- function(rg, pl) { if (is.null(SPN[[rg]])) SPN[[rg]] <<- poll_sponsor_class(rg, pl); stopifnot(length(SPN[[rg]]) == nrow(pl)); SPN[[rg]] }
mod_of <- function(rg, pl) { if (is.null(MOD[[rg]])) MOD[[rg]] <<- poll_method_class(rg, pl, eras = ERAS); stopifnot(length(MOD[[rg]]) == nrow(pl)); MOD[[rg]] }
e_f <- poll_lean_errors()
e_s <- poll_lean_errors(group_by = spn_of, tag = "sponsor")
e_m <- poll_lean_errors(group_by = mod_of, tag = "method")
same <- nrow(e_f) == nrow(e_s) && nrow(e_f) == nrow(e_m) &&
  isTRUE(all.equal(e_f$d, e_s$d)) && isTRUE(all.equal(e_f$d, e_m$d)) &&
  identical(e_f$election, e_s$election) && identical(e_f$party, e_m$party)
cat(sprintf("PLF0  error tables: %d poll-party rows each; aligned row for row: %s\n", nrow(e_f), same))
if (!same) stop("PLF0! the firm, sponsor and method error tables do not line up, so the backfit would pair wrong rows")

# per-row lean lookup (vectors outside [...]: `lean` is a column of the table)
row_lean <- function(tab, grp, party) {
  key_t <- paste(tab$firm, tab$party); v <- tab$lean
  out <- v[match(paste(grp, party), key_t)]
  out[!is.finite(out)] <- 0
  out
}
# The backfitted lean tables for a cutoff
full_leans <- function(as_of) {
  lf <- poll_lean_table(as_of, e_f)
  es <- copy(e_s); es$d <- e_s$d - row_lean(lf, e_f$firm, e_f$party)
  ls <- poll_lean_table(as_of, es)
  em <- copy(e_m); em$d <- es$d - row_lean(ls, e_s$firm, e_s$party)
  lm <- poll_lean_table(as_of, em)
  list(firm = lf, sponsor = ls, method = lm)
}
apply_full <- function(polls, rg, L) {
  a <- apply_poll_lean(polls, L$firm)
  a <- apply_poll_lean(a, L$sponsor, group = spn_of(rg, polls))
  apply_poll_lean(a, L$method, group = mod_of(rg, polls))
}

score_fit <- function(fit, a_row) {
  ends <- fit$fp
  ps <- intersect(MAIN, names(ends))
  stopifnot(length(ps) >= 2L, all(is.finite(ends[ps])))
  got <- setNames(a_row$share, a_row$party)
  a <- vapply(ps, function(p) if (p %in% names(got)) got[[p]] else 0, 1)
  e <- unname(ends[ps]) - unname(a)
  list(mae = mean(abs(c(e, (100 - sum(ends[ps])) - (100 - sum(a))))),
       onp_err = if ("ONP" %in% ps) e[ps == "ONP"] else NA_real_)
}

# ---- every election: published fit, and FULL's lean + record weights under each anchor value -------------------
t0 <- Sys.time()
rows <- list()
for (rg in REGIONS) {
  polls <- load_polls(rg)
  for (el in unique(act[act$region == rg]$election)) {
    if (el %in% LIVE) next
    yr <- act[act$election == el]$year[1]
    ce <- cycles[cycles$region == rg & cycles$year == yr]
    if (!nrow(ce)) next
    m <- pri$region == rg & pri$year == yr
    priors <- setNames(pri$prev1[m], pri$party[m])
    flw <- tryCatch(flows_for(pf, yr, rg, quiet = TRUE), error = function(e) NULL)
    a_row <- act[act$election == el]
    asat <- ce$end[1] - 1
    base <- tryCatch(trend_as_at(polls, yr, cycles, asat, priors, flw), error = function(e) NULL)
    if (is.null(base)) next
    s0 <- score_fit(base, a_row)
    adj <- apply_full(polls, rg, full_leans(ce$start[1]))
    for (g in GRID) {
      Sys.setenv(AUSPOL_ANCHOR_SD_MULT = g)
      fit <- tryCatch(trend_as_at(adj, yr, cycles, asat, priors, flw, weights = "record"), error = function(e) NULL)
      Sys.setenv(AUSPOL_ANCHOR_SD_MULT = "1")
      if (is.null(fit)) next
      s <- score_fit(fit, a_row)
      rows[[length(rows) + 1L]] <- data.table(election = el, start = ce$start[1], end = ce$end[1], mode = g,
                                              published = s0$mae, mae = s$mae, onp_pub = s0$onp_err, onp = s$onp_err)
    }
  }
}
stopifnot(Sys.getenv("AUSPOL_ANCHOR_SD_MULT") == "1")
d <- rbindlist(rows)
full_set <- d[, .N, by = election][N == length(GRID)]$election
if (length(full_set) < uniqueN(d$election)) cat("PLF0! elections missing an anchor value (dropped):", setdiff(unique(d$election), full_set), "\n")
d <- d[d$election %in% full_set]
cat(sprintf("PLF1  %d fits over %d elections in %.1f min\n", nrow(d), uniqueN(d$election),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# time-forward anchor pick, as arm ANC
wide <- dcast(d, election + start + end ~ mode, value.var = "mae")
setorder(wide, end)
pick <- character(nrow(wide))
for (i in seq_len(nrow(wide))) {
  prev <- wide$end < wide$start[i]
  if (!any(prev)) { pick[i] <- "1"; next }
  mm <- colMeans(wide[prev, GRID, with = FALSE])
  best <- names(mm)[mm == min(mm)]
  pick[i] <- if ("1" %in% best) "1" else best[1]
}
sel <- data.table(election = wide$election, mode = pick)
w <- merge(d, sel, by = c("election", "mode"))
w[, diff := mae - published]
setorder(w, end)
cat("PLF1  Primary = day-before mean absolute error, points (lower is better); diff = FULL - published\n")
print(w[, .(election, anchor = mode, published = round(published, 3), full = round(mae, 3), diff = round(diff, 4))])
cat("PLF1  anchor picks:", paste(names(table(w$mode)), table(w$mode), collapse = ", "), "\n")

n <- nrow(w); md <- mean(w$diff); se <- sd(w$diff) / sqrt(n)
cat(sprintf("\nPLF2  clause 1: mean change %+.4f points, SE %.4f (n %d elections): %s\n", md, se, n,
            if (md < -se) "PASS (better by more than 1 SE)" else "NOT PASSED"))
loo <- vapply(seq_len(n), function(j) { x <- w$diff[-j]; mean(x) + sd(x) / sqrt(n - 1) }, 1)
cat(sprintf("PLF2  clause 3: leave-one-election-out, still better by > 1 SE in %d of %d drops; worst drop %s\n",
            sum(loo < 0), n, w$election[which.max(loo)]))
cat(sprintf("PLF2  clause 6: elections moved %d; better %d, worse %d\n", sum(abs(w$diff) > 1e-12),
            sum(w$diff < -1e-12), sum(w$diff > 1e-12)))
fixed <- d[d$mode == "1"]
cat(sprintf("PLF2  reported only, anchor held at the published 1 (lean + record weights alone): %+.4f, SE %.4f\n",
            mean(fixed$mae - fixed$published), sd(fixed$mae - fixed$published) / sqrt(nrow(fixed))))

on <- w[is.finite(w$onp_pub)]
cat("\nPLF3  One Nation signed error (trend minus actual, points; positive = over-states)\n")
print(on[, .(election, published = round(onp_pub, 2), full = round(onp, 2))])
cat(sprintf("PLF3  mean |ONP error| published %.3f, FULL %.3f (n %d)\n", mean(abs(on$onp_pub)), mean(abs(on$onp)), nrow(on)))
sa <- w[w$election == "sa2026"]
if (nrow(sa)) cat(sprintf("PLF3  sa2026: published %.3f, FULL %.3f, change %+.4f\n", sa$published, sa$mae, sa$diff))

# ---- live walk ---------------------------------------------------------------------------------------------------
mm <- colMeans(wide[, GRID, with = FALSE]); best <- names(mm)[mm == min(mm)]
g_live <- if ("1" %in% best) "1" else best[1]
vp <- load_polls("vic")
m <- pri$region == "vic" & pri$year == 2026
priors <- setNames(pri$prev1[m], pri$party[m])
flw <- flows_for(pf, 2026, "vic", quiet = TRUE)
b <- trend_as_at(vp, 2026, cycles, Sys.Date(), priors, flw)
Sys.setenv(AUSPOL_ANCHOR_SD_MULT = g_live)
a <- trend_as_at(apply_full(vp, "vic", full_leans(Sys.Date())), 2026, cycles, Sys.Date(), priors, flw, weights = "record")
Sys.setenv(AUSPOL_ANCHOR_SD_MULT = "1")
cat(sprintf("\nPLF4  vic2026 trend endpoint, published vs FULL (anchor %s, picked over all %d elections):\n", g_live, nrow(wide)))
print(round(rbind(published = b$fp, full = a$fp[names(b$fp)]), 2))
