# Poll-lean screen, arm REC at the statewide stage (plans/prereg-poll-lean-2026-11-02.md, step 3): each company's
# lean against RESULTS at earlier elections, shrunk to zero (R/poll_lean.R), taken out of its polls before the
# published trend is fitted.
#
#   powershell.exe -Command 'Rscript "scripts/screen_poll_lean_rec.R"'
#
# For every scored election E: lean table from elections with polling day before E's cycle began, polls adjusted,
# trend_as_at() refitted the day before polling day, scored on the prereg primary (mean absolute error over ALP, LNP,
# GRN, ONP where fitted, and everything else, against output/candidacies.csv), paired against the published trend.
#   PLR1  per election: firm-party leans with weight > 0, polls moved, largest shift, published vs arm primary
#   PLR2  clause 1, clause 3 (leave-one-election-out), clause 6 (direction)
#   PLR3  One Nation's signed error and sa2026 (the named-in-advance unacceptable win)
#   PLR4  the live walk: the lean table vic2026 would get (every completed election), and the trend with and without
# Writes nothing to output/. Data.table NSE: no local shares a column name inside [...].

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/published_flags.R")
for (k in names(PUBLISHED_FLAGS)) if (Sys.getenv(k) == "") do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[k]]), k))

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
errs <- poll_lean_errors()
cat(sprintf("PLR0  lean errors: %d poll-party rows from %d elections, %d firms\n", nrow(errs),
            uniqueN(paste(errs$region, errs$year)), uniqueN(errs$firm)))

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
    asat <- ce$end[1] - 1
    base <- tryCatch(trend_as_at(polls, yr, cycles, asat, priors, flw), error = function(e) NULL)
    if (is.null(base)) next
    lean <- poll_lean_table(ce$start[1], errs)
    adj <- apply_poll_lean(polls, lean)
    cyc_moved <- {
      cp0 <- cycle_polls(polls, yr, cycles); cp1 <- cycle_polls(adj, yr, cycles)
      pc <- intersect(MAIN, names(cp0)); k_in <- cp0$date <= asat
      dm <- as.matrix(cp1[k_in, pc, with = FALSE]) - as.matrix(cp0[k_in, pc, with = FALSE])
      c(n = sum(abs(dm) > 1e-9, na.rm = TRUE), max = if (any(is.finite(dm))) max(abs(dm), na.rm = TRUE) else 0)
    }
    arm <- tryCatch(trend_as_at(adj, yr, cycles, asat, priors, flw), error = function(e) NULL)
    if (is.null(arm)) { cat("PLR1! arm fit failed for", el, "\n"); next }
    s0 <- score_fit(base, a_row); s1 <- score_fit(arm, a_row)
    rows[[el]] <- data.table(election = el, end = ce$end[1], n_elec_used = attr(lean, "n_elections"),
                             leans_live = sum(lean$w > 0), cells_moved = cyc_moved[["n"]],
                             max_shift = cyc_moved[["max"]], published = s0$mae, arm = s1$mae,
                             diff = s1$mae - s0$mae, onp_pub = s0$onp_err, onp_arm = s1$onp_err)
  }
}
w <- rbindlist(rows)
setorder(w, end)
cat(sprintf("\nPLR1  %d elections in %.1f min. Primary = mean absolute error, points (lower is better); diff = arm - published\n",
            nrow(w), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
print(w[, .(election, n_elec_used, leans_live, cells_moved, max_shift = round(max_shift, 2),
            published = round(published, 3), arm = round(arm, 3), diff = round(diff, 4))])

n <- nrow(w); md <- mean(w$diff); se <- sd(w$diff) / sqrt(n)
cat(sprintf("\nPLR2  clause 1: mean change %+.4f points, SE %.4f (n %d elections): %s\n", md, se, n,
            if (md < -se) "PASS (better by more than 1 SE)" else "NOT PASSED"))
loo <- vapply(seq_len(n), function(j) { x <- w$diff[-j]; mean(x) + sd(x) / sqrt(n - 1) }, 1)
cat(sprintf("PLR2  clause 3: leave-one-election-out, still better by > 1 SE in %d of %d drops; worst drop %s\n",
            sum(loo < 0), n, w$election[which.max(loo)]))
cat(sprintf("PLR2  clause 6: elections moved %d; better %d, worse %d\n", sum(w$diff != 0), sum(w$diff < 0), sum(w$diff > 0)))

on <- w[is.finite(w$onp_pub)]
cat("\nPLR3  One Nation signed error (trend minus actual, points; positive = over-states)\n")
print(on[, .(election, published = round(onp_pub, 2), arm = round(onp_arm, 2))])
cat(sprintf("PLR3  mean |ONP error| published %.3f, arm %.3f (n %d)\n", mean(abs(on$onp_pub)), mean(abs(on$onp_arm)), nrow(on)))
sa <- w[w$election == "sa2026"]
if (nrow(sa)) cat(sprintf("PLR3  sa2026: published %.3f, arm %.3f, change %+.4f\n", sa$published, sa$arm, sa$diff))

# live walk: what vic2026 would get
lv <- poll_lean_table(Sys.Date(), errs)
cat(sprintf("\nPLR4  live lean table (every completed election, %d): firm-party leans with weight > 0\n", attr(lv, "n_elections")))
vp <- load_polls("vic"); vfirms <- unique(cycle_polls(vp, 2026, cycles)$firm)
show <- lv[lv$firm %in% vfirms]
show[, lean_pts_at_20 := round(from_link(to_link(20, "logit")$z + lean, "logit") - 20, 2)]
print(show[order(party, -abs(lean)), .(firm, party, k, est = round(est, 3), se = round(se, 3), w = round(w, 3), lean = round(lean, 3), lean_pts_at_20)])
m <- pri$region == "vic" & pri$year == 2026
priors <- setNames(pri$prev1[m], pri$party[m])
flw <- flows_for(pf, 2026, "vic", quiet = TRUE)
b <- trend_as_at(vp, 2026, cycles, Sys.Date(), priors, flw)
a <- trend_as_at(apply_poll_lean(vp, lv), 2026, cycles, Sys.Date(), priors, flw)
cat("PLR4  vic2026 trend endpoint, published vs arm:\n")
print(round(rbind(published = b$fp, arm = a$fp[names(b$fp)]), 2))
