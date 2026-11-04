# Poll-lean screen, arm ANC at the statewide stage (plans/prereg-poll-lean-2026-11-02.md, order of work step 2):
# how hard the trend's day 0 is pinned to the previous result (AUSPOL_ANCHOR_SD_MULT, R/trend.R trend_anchor()).
#
#   powershell.exe -Command 'Rscript "scripts/screen_poll_lean_anc.R"'
#
# For every scored election, refits the published trend (trend_as_at(), day before polling day) under each grid
# value, scores the prereg primary (mean absolute error over ALP, LNP, GRN, ONP where fitted, and everything else,
# against output/candidacies.csv), then picks the value TIME-FORWARD: for election E, the value with the lowest
# mean primary over elections that ended before E's cycle began (no earlier election, or a tie: the published "1").
#   PLA1  per-election primary under every grid value (reported, not deciding)
#   PLA2  the time-forward pick per election and its paired change against the published anchor
#   PLA3  clause 1 (better by > 1 SE, SE over elections), clause 3 (leave-one-election-out), clause 6 (direction)
#   PLA4  the named-in-advance unacceptable win: One Nation's own signed error, and sa2026 on its own
# Writes nothing to output/. Data.table NSE: no local shares a column name inside [...].

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/published_flags.R")
for (k in names(PUBLISHED_FLAGS)) if (Sys.getenv(k) == "") do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[k]]), k))
stopifnot(Sys.getenv("AUSPOL_ANCHOR_SD_MULT") == "1")

GRID <- c("1", "2", "4", "none", "gap:0.5", "gap:1", "gap:2")   # prereg arm 4; "1" is the published anchor
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
    for (g in GRID) {
      Sys.setenv(AUSPOL_ANCHOR_SD_MULT = g)
      fit <- tryCatch(trend_as_at(polls, yr, cycles, ce$end[1] - 1, priors, flw), error = function(e) NULL)
      if (is.null(fit)) next
      s <- score_fit(fit, a_row)
      rows[[length(rows) + 1L]] <- data.table(election = el, start = ce$start[1], end = ce$end[1], mode = g,
                                              mae = s$mae, onp_err = s$onp_err)
    }
    Sys.setenv(AUSPOL_ANCHOR_SD_MULT = "1")
  }
}
d <- rbindlist(rows)
cat(sprintf("PLA0  %d fits over %d elections and %d grid values in %.1f min; AUSPOL_ANCHOR_SD_MULT restored to %s\n",
            nrow(d), uniqueN(d$election), length(GRID), as.numeric(difftime(Sys.time(), t0, units = "mins")),
            Sys.getenv("AUSPOL_ANCHOR_SD_MULT")))
full <- d[, .N, by = election][N == length(GRID)]$election
if (length(full) < uniqueN(d$election)) cat("PLA0! elections missing a grid value (dropped):", setdiff(unique(d$election), full), "\n")
d <- d[d$election %in% full]

wide <- dcast(d, election + start + end ~ mode, value.var = "mae")
setorder(wide, end)
cat("\nPLA1  primary (mean absolute error, points; lower is better) per election under every anchor setting\n")
print(wide[, c("election", GRID), with = FALSE], digits = 3)
cat("PLA1  mean over elections:\n"); print(round(colMeans(wide[, GRID, with = FALSE]), 4))

# time-forward pick
pick <- character(nrow(wide))
for (i in seq_len(nrow(wide))) {
  prev <- wide$end < wide$start[i]
  if (!any(prev)) { pick[i] <- "1"; next }
  mm <- colMeans(wide[prev, GRID, with = FALSE])
  best <- names(mm)[mm == min(mm)]
  pick[i] <- if ("1" %in% best) "1" else best[1]
}
wide[, picked := pick]
wide[, arm := vapply(seq_len(.N), function(i) wide[[pick[i]]][i], 1)]
wide[, diff := arm - wide[["1"]]]
cat("\nPLA2  time-forward pick per election and paired change (arm minus published; negative = better)\n")
print(wide[, .(election, picked, published = round(get("1"), 3), arm = round(arm, 3), diff = round(diff, 4))])
cat("PLA2  picks:\n"); print(table(wide$picked))

n <- nrow(wide); md <- mean(wide$diff); se <- sd(wide$diff) / sqrt(n)
cat(sprintf("\nPLA3  clause 1: mean change %+.4f points, SE %.4f (n %d elections): %s\n", md, se, n,
            if (md < -se) "PASS (better by more than 1 SE)" else "NOT PASSED"))
loo <- vapply(seq_len(n), function(j) { x <- wide$diff[-j]; mean(x) + sd(x) / sqrt(n - 1) }, 1)
cat(sprintf("PLA3  clause 3: leave-one-election-out, still better by > 1 SE in %d of %d drops; worst drop %s\n",
            sum(loo < 0), n, wide$election[which.max(loo)]))
cat(sprintf("PLA3  clause 6: elections moved %d; better %d, worse %d\n", sum(wide$diff != 0), sum(wide$diff < 0), sum(wide$diff > 0)))
for (g in setdiff(GRID, "1")) {
  dd <- wide[[g]] - wide[["1"]]
  cat(sprintf("PLA3  fixed %-8s %+.4f (SE %.4f)  [reported, not deciding]\n", g, mean(dd), sd(dd) / sqrt(n)))
}

# unacceptable-win clause: is the gain One Nation pushed down?
on <- dcast(d[is.finite(d$onp_err)], election ~ mode, value.var = "onp_err")
if (nrow(on)) {
  on <- merge(on, wide[, .(election, picked)], by = "election")
  on[, arm_err := vapply(seq_len(.N), function(i) on[[on$picked[i]]][i], 1)]
  cat("\nPLA4  One Nation signed error (trend minus actual, points; positive = over-states) where ONP is fitted\n")
  print(on[, .(election, published = round(get("1"), 2), picked, arm = round(arm_err, 2))])
  cat(sprintf("PLA4  mean |ONP error|: published %.3f, arm %.3f (n %d)\n", mean(abs(on[["1"]])), mean(abs(on$arm_err)), nrow(on)))
}
sa <- wide[wide$election == "sa2026"]
if (nrow(sa)) cat(sprintf("PLA4  sa2026: published %.3f, arm (%s) %.3f, change %+.4f\n", sa[["1"]], sa$picked, sa$arm, sa$diff))
