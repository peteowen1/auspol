# Arm PPC screen at the statewide stage (docs/plans/prereg-paid-poll-correction-2026-11-13.md): party- and
# advocacy-paid polls get a shrunk lean toward the sponsor's side and extra noise, learned from same-time independent
# polls (R/paid_poll.R), then the published trend is refitted.
#
#   AUSPOL_POLL_WIKI=<fresh statewide_polls_wiki.csv> powershell.exe -Command 'Rscript "scripts/screen_paid_poll.R"'
#
#   PPC0  the paid polls the trend fits, per region: date, firm, client, side
#   PPC1  C1 placebo: 20 random independent 2024+ polls labelled paid, 20 repeats
#   PPC2  per election: paid polls in reach, published vs arm day-before mean absolute error (lower is better)
#   PPC3  C2 untouched elections byte-identical; C3 do-no-harm on the touched ones
#   PPC4  C4 live walk vic2026: lean table, noise factor, each paid poll before/after, trend with and without
# Writes nothing to output/. Data.table NSE: no local shares a column name inside [...].

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/published_flags.R")
for (k in names(PUBLISHED_FLAGS)) if (Sys.getenv(k) == "") do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[k]]), k))
Sys.setenv(AUSPOL_PAID_POLL_CORRECT = "0")   # the screen applies the arm by hand; trend_as_at() must not apply it again
cat("PPC0  poll table read for sponsors:", poll_wiki_path(), "\n")

REGIONS <- c("fed", "nsw", "vic", "qld", "wa", "sa", "nt", "tas")
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

P <- list(); CLS <- list(); SPON <- list()
for (rg in REGIONS) {
  pl <- tryCatch(suppressMessages(load_polls(rg)), error = function(e) NULL)
  if (is.null(pl)) { cat("PPC0  no polls for", rg, "\n"); next }
  cl <- poll_sponsor_class(rg, pl)
  P[[rg]] <- pl; CLS[[rg]] <- as.character(cl); SPON[[rg]] <- attr(cl, "sponsor")
}
cat("PPC0  paid polls (class 'party') the trend fits:\n")
pp <- rbindlist(lapply(names(P), function(rg) { ix <- which(CLS[[rg]] == "party")
  if (!length(ix)) return(NULL)
  data.table(region = rg, date = P[[rg]]$date[ix], firm = P[[rg]]$firm[ix], client = substr(SPON[[rg]][ix], 1, 40),
             side = paid_poll_side(SPON[[rg]][ix])) }))
print(pp[order(region, date)])
stopifnot(nrow(pp) > 0)

fit_at <- function(asat, cls_list = CLS, spon_list = SPON) {
  dv <- rbindlist(lapply(names(P), function(rg) {
    d <- paid_poll_deviations(P[[rg]], cls_list[[rg]], spon_list[[rg]], asat)
    if (nrow(d)) d[, region := rg]
    d }), fill = TRUE)
  paid_poll_fit(dv)
}

# ---- C1 placebo ---------------------------------------------------------------------------------------------------
set.seed(20261113)
real_sp <- unlist(lapply(names(P), function(rg) SPON[[rg]][CLS[[rg]] == "party"]))
real_sp <- real_sp[paid_poll_side(real_sp) != "UNKNOWN"]
pool <- rbindlist(lapply(names(P), function(rg) { ix <- which(CLS[[rg]] %in% c("media", "unknown") & P[[rg]]$date >= as.Date("2024-01-01"))
  data.table(region = rep(rg, length(ix)), i = ix) }))
plc <- rbindlist(lapply(1:20, function(rep_) {
  pick <- pool[sample(nrow(pool), 20)]
  cl2 <- CLS; sp2 <- SPON
  for (rg in names(cl2)) { real <- cl2[[rg]] == "party"; cl2[[rg]][real] <- "excluded" }
  for (j in seq_len(nrow(pick))) { rg <- pick$region[j]; cl2[[rg]][pick$i[j]] <- "party"; sp2[[rg]][pick$i[j]] <- sample(real_sp, 1) }
  f <- fit_at(Sys.Date(), cl2, sp2)
  worst <- if (nrow(f$lean)) max(abs(f$lean$shrunk) / f$lean$se) else 0
  data.table(rep = rep_, sides = nrow(f$lean), max_abs_lean = if (nrow(f$lean)) max(abs(f$lean$shrunk)) else 0,
             max_lean_in_se = worst, factor = f$factor, pass = worst < 1 && f$factor < 1.1)
}))
cat("\nPPC1  C1 placebo (random independent polls labelled paid; lean in points of the side's share; factor = noise sd multiplier)\n")
print(plc[, .(rep, sides, max_abs_lean = round(max_abs_lean, 2), max_lean_in_se = round(max_lean_in_se, 2), factor = round(factor, 3), pass)])
cat(sprintf("PPC1  C1: %d of 20 pass (need 16): %s\n", sum(plc$pass), if (sum(plc$pass) >= 16) "PASS" else "FAIL -- the estimator invents bias; stop"))

# ---- C2/C3 scored elections --------------------------------------------------------------------------------------
score_fit <- function(fit, a_row) {
  ends <- fit$fp
  ps <- intersect(MAIN, names(ends))
  stopifnot(length(ps) >= 2L, all(is.finite(ends[ps])))
  got <- setNames(a_row$share, a_row$party)
  a <- vapply(ps, function(p) if (p %in% names(got)) got[[p]] else 0, 1)
  e <- unname(ends[ps]) - unname(a)
  mean(abs(c(e, (100 - sum(ends[ps])) - (100 - sum(a)))))
}
t0 <- Sys.time()
rows <- list()
for (rg in names(P)) {
  polls <- P[[rg]]
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
    in_cyc <- CLS[[rg]] == "party" & polls$date >= ce$start[1] & polls$date <= asat
    f <- if (any(in_cyc)) fit_at(asat) else NULL
    ap <- paid_poll_apply(polls, ifelse(in_cyc, "party", "media"), SPON[[rg]], f, asat)
    arm <- tryCatch(trend_as_at(ap$polls, yr, cycles, asat, priors, flw, extra_firm_factors = ap$firm_factors),
                    error = function(e) NULL)
    if (is.null(arm)) { cat("PPC2! arm fit failed for", el, "\n"); next }
    rows[[el]] <- data.table(election = el, end = ce$end[1], paid_in_cycle = sum(in_cyc),
                             factor = if (is.null(f)) NA_real_ else f$factor,
                             published = score_fit(base, a_row), arm = score_fit(arm, a_row),
                             max_fp_change = max(abs(arm$fp[names(base$fp)] - base$fp)))
  }
}
w <- rbindlist(rows)
setorder(w, end)
w[, diff := arm - published]
cat(sprintf("\nPPC2  %d elections in %.1f min. Day-before mean absolute error, points (lower is better); diff = arm - published\n",
            nrow(w), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
print(w[, .(election, paid_in_cycle, factor = round(factor, 3), published = round(published, 3), arm = round(arm, 3),
            diff = round(diff, 4), max_fp_change = signif(max_fp_change, 3))])
un <- w[w$paid_in_cycle == 0]
cat(sprintf("\nPPC3  C2: %d untouched elections, %d with any primary changed by more than 1e-9: %s\n", nrow(un),
            sum(un$max_fp_change > 1e-9), if (all(un$max_fp_change <= 1e-9)) "PASS" else "FAIL"))
tc <- w[w$paid_in_cycle > 0]
if (nrow(tc)) {
  cat(sprintf("PPC3  C3: %d touched elections; mean change %+.4f points; worse in %d\n", nrow(tc), mean(tc$diff), sum(tc$diff > 0)))
} else cat("PPC3  C3: no scored election has a paid poll before its cutoff\n")

# ---- C4 live walk vic2026 ----------------------------------------------------------------------------------------
lf <- fit_at(Sys.Date())
cat(sprintf("\nPPC4  live fit (every paid poll to today, %d): overall toward-sponsor lean mu %+.2f (SE %.2f, kept %.0f%%), between-side tau^2 %.2f\n",
            lf$n_paid, lf$mu, lf$se_mu, 100 * lf$w0, lf$tau2))
cat("PPC4  per side: n polls, raw mean gap of the side's share vs same-time independent polls (points), SE, weight on own mean, shrunk lean\n")
print(lf$lean[, .(side, n, raw_gap = round(m, 2), se = round(se, 2), w = round(w, 2), shrunk_lean = round(shrunk, 2))])
cat(sprintf("PPC4  baseline: an independent poll's mean squared gap from its neighbours %.2f (sd %.2f points); paid extra variance %.2f (shrunk); noise factor %.3f (weight x%.2f)\n",
            lf$v0, sqrt(lf$v0), lf$x2, lf$factor, 1 / lf$factor^2))
vp <- P[["vic"]]
ap <- paid_poll_apply(vp, CLS[["vic"]], SPON[["vic"]], lf, Sys.Date())
cat("PPC4  each paid Vic poll, before and after (points):\n")
print(dcast(ap$moved[, .(date, firm, side, party, v = sprintf("%.1f->%.1f", before, after))], date + firm + side ~ party, value.var = "v"))
m <- pri$region == "vic" & pri$year == 2026
priors <- setNames(pri$prev1[m], pri$party[m])
flw <- flows_for(pf, 2026, "vic", quiet = TRUE)
b <- trend_as_at(vp, 2026, cycles, Sys.Date(), priors, flw)
a <- trend_as_at(ap$polls, 2026, cycles, Sys.Date(), priors, flw, extra_firm_factors = ap$firm_factors)
cat("PPC4  vic2026 trend endpoint (primary %), published vs arm:\n")
print(round(rbind(published = b$fp, arm = a$fp[names(b$fp)], change = a$fp[names(b$fp)] - b$fp), 2))
