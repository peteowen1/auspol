# Seat flow tendency per federal election, for AUSPOL_SEAT_FLOW_PERSIST
# (plans/prereg-seat-flow-persistence-2026-11-08.md).
#
# For every federal seat whose final two were Labor and the Coalition:
#   f = (TCP_ALP - FP_ALP) / (100 - FP_ALP - FP_LNP)       share of the other votes that reached Labor
#   d = f - mean f over that election's seats               the seat's own tendency, election swing removed
# from the AEC's own counts (external/elections/aec-fed-tcp.csv; first preferences from
# output/candidacies.csv, classes as classify_party() set them). Seats with under 3% others skipped.
# Also fits, for every target election, the time-forward weight w_T: the slope of d_E on d_{E-1}
# (same seat name) over every pair of consecutive federal elections BEFORE T.
# Writes output/seat-flow-persistence.csv (seat tendencies) and output/seat-flow-persistence-w.csv.
# Emits SFP codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

tcp <- fread(file.path("external", "elections", "aec-fed-tcp.csv"))
cand <- fread("output/candidacies.csv", select = c("election", "region", "seat", "party", "votes"))[region == "fed"]
cat(sprintf("SFP0 TCP rows %d over %d elections; candidacy rows %d\n", nrow(tcp), uniqueN(tcp$election), nrow(cand)))

tw <- tcp[, .(n = .N, alp = sum(votes[party == "ALP"]), lnp = sum(votes[party == "LNP"]), tot = sum(votes)), by = .(election, seat)]
tw <- tw[n == 2 & alp > 0 & lnp > 0]
tw[, tcp_alp := 100 * alp / tot]
fp <- cand[is.finite(votes), .(fp_alp = sum(votes[party == "ALP"]), fp_lnp = sum(votes[party == "LNP"]), fp_tot = sum(votes)), by = .(election, seat)]
fp[, `:=`(fp_alp = 100 * fp_alp / fp_tot, fp_lnp = 100 * fp_lnp / fp_tot)]
x <- merge(tw[, .(election, seat, tcp_alp)], fp[, .(election, seat, fp_alp, fp_lnp)], by = c("election", "seat"))
cat(sprintf("SFP1 ALP v LNP seats with both counts: %d (TCP side %d)\n", nrow(x), nrow(tw)))
x[, others := 100 - fp_alp - fp_lnp]
x <- x[others >= 3]
x[, f := (tcp_alp - fp_alp) / others]
bad <- x[f < -0.05 | f > 1.05]
if (nrow(bad)) { cat(sprintf("SFP2! %d seat(s) with an impossible flow (outside 0-1), dropped:\n", nrow(bad))); print(head(bad, 10)) }
x <- x[f >= -0.05 & f <= 1.05]
x[, d := f - mean(f), by = election]   # raw tendency: kept for reference, NOT the term (prereg amendment)

# OUR prediction of the same quantity, from the published path: our primaries
# (published-predictions.csv) and our Labor-v-Coalition TCP scenario (newest backtest-fedE-ourtcp file).
pp <- fread("output/published-predictions.csv", select = c("pair", "seat", "party", "ours"))[startsWith(pair, "fed")]
ofp <- pp[, .(o_alp = sum(ours[party == "ALP"]), o_lnp = sum(ours[party == "LNP"])), by = .(election = pair, seat)]
otcp <- rbindlist(lapply(unique(x$election), function(e) {
  fs <- list.files("output", pattern = sprintf("^backtest-%s-ourtcp.*[.]csv$", e), full.names = TRUE)
  if (!length(fs)) return(NULL)
  f1 <- fs[which.max(file.mtime(fs))]
  cat(sprintf("SFP1b %s: our TCP from %s\n", e, basename(f1)))
  o <- fread(f1)[(f1 == "ALP" & f2 == "LNP") | (f1 == "LNP" & f2 == "ALP")]
  o[, .(election = e, o_tcp_alp = if (f1[1] == "ALP") f1_tcp_pct[1] else 100 - f1_tcp_pct[1]), by = seat]
}))
x <- merge(x, ofp, by = c("election", "seat"), all.x = TRUE)
x <- merge(x, otcp, by = c("election", "seat"), all.x = TRUE)
x[, f_ours := (o_tcp_alp - o_alp) / (100 - o_alp - o_lnp)]
x[, r := f - f_ours]
cat(sprintf("SFP1c our flow available for %d of %d seat-elections\n", sum(is.finite(x$r)), nrow(x)))
setorder(x, election, seat)
print(x[, .(seats = .N, mean_f = round(mean(f), 3), sd_d = round(sd(d), 3),
            with_ours = sum(is.finite(r)), mean_r = round(mean(r, na.rm = TRUE), 3), sd_r = round(sd(r, na.rm = TRUE), 3)), by = election])
fwrite(x, "output/seat-flow-persistence.csv")

# time-forward weight per target
el <- sort(unique(x$election)); el <- el[order(as.numeric(vapply(el, function(e) as.numeric(election_dates()[[e]]), 0)))]
pairs <- rbindlist(lapply(seq_along(el)[-1], function(i) {
  # the TERM: our miss (r), not the raw tendency (d) -- prereg amendment
  a <- x[election == el[i - 1] & is.finite(r), .(seat, d_prev = r)]; b <- x[election == el[i] & is.finite(r), .(seat, d_now = r)]
  m <- merge(a, b, by = "seat"); if (!nrow(m)) return(NULL); m[, `:=`(prev = el[i - 1], now = el[i])]
}))
targets <- c(el, "fed2028")
wt <- rbindlist(lapply(targets, function(t) {
  tr <- pairs[elections_before(now, t)]
  if (nrow(tr) < 30) return(data.table(target = t, w = NA_real_, n = nrow(tr), cor = NA_real_))
  fit <- lm(d_now ~ 0 + d_prev, data = tr)
  data.table(target = t, w = unname(coef(fit)[1]), n = nrow(tr), cor = cor(tr$d_now, tr$d_prev))
}))
cat("SFP3 time-forward weight w_T (slope of a seat's tendency on its previous one, earlier pairs only):\n")
print(wt[, .(target, w = round(w, 3), n, cor = round(cor, 3))])
fwrite(wt, "output/seat-flow-persistence-w.csv")
cat("SFP4 wrote output/seat-flow-persistence.csv and -w.csv\n")
