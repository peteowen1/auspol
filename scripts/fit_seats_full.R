# Candidate-level Victorian seat forecast: every seat, minor parties able to win.
#
# The published seat model (scripts/fit_seats.R) applies a statewide two-party
# swing to each seat's margin. It cannot represent a Green, an independent or
# One Nation winning anything, because a two-party margin is the only thing it
# knows about a seat. This runs the count instead: project each seat's first
# preferences, exclude the lowest, distribute at measured rates, repeat.
#
# Needs data that is NOT in the repo. Run both fetchers first:
#   Rscript scripts/fetch_preferences_vic.R
#   Rscript scripts/fetch_preferences_sa.R
# Both write to external/elections/, gitignored alongside the anchor clone,
# because neither commission publishes a licence. Nothing of theirs is
# committed; see election_data_path().
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_seats_full.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

N_SIMS  <- 20000
SEAT_SD <- 3.5      # within-region seat deviation, from seat_swing_spread()
SMOOTH  <- 0.15     # see distribute_preferences(); NOT optional, see its docs
ONP_B1  <- -0.0968  # Greens-share coefficient, fitted on Victorian federal 2025

PREF <- election_data_path()          # external/elections, gitignored
need <- file.path(PREF, c("vec-2022-vic-transfers.csv",
                          "ecsa-2026-sa-transfers.csv",
                          "vec-2022-vic-firstprefs.csv",
                          "ecsa-2026-sa-onp-shares.csv"))
if (!all(file.exists(need))) {
  cat("Preference data not found; run the fetchers first. Missing:",
      paste(basename(need[!file.exists(need)]), collapse = ", "), "\n")
  quit(save = "no", status = 0)
}

# ---- 1. flow matrix, from both elections -----------------------------------
# Victoria is the right jurisdiction and supplies Greens, independent and
# minor-right behaviour from 452 exclusions. It cannot speak to One Nation --
# 5 of 88 seats contested in 2022 -- which is the only reason SA is here.
tx <- rbind(fread(file.path(PREF, "vec-2022-vic-transfers.csv")),
            fread(file.path(PREF, "ecsa-2026-sa-transfers.csv")))
fm <- build_flow_matrix(tx, min_n = 3L)
cat(sprintf("flow matrix: %d exclusions, %d cells at n>=3 of %d observed\n",
            uniqueN(tx[, .(election, seat, round)]), length(fm$conditional),
            nrow(fm$coverage)))

# ---- 2. each seat's 2022 first preferences, as class shares ----------------
fp <- fread(file.path(PREF, "vec-2022-vic-firstprefs.csv"))
w <- dcast(fp, seat ~ party, value.var = "votes", fill = 0)
mat22 <- as.matrix(w[, -1]); rownames(mat22) <- w$seat
mat22 <- 100 * mat22 / rowSums(mat22)
a22 <- 100 * colSums(as.matrix(dcast(fp, seat ~ party, value.var = "votes",
                                     fill = 0)[, -1])) /
       sum(fp$votes)
cat(sprintf("seats with 2022 first preferences: %d\n", nrow(mat22)))

# ---- 3. statewide 2026, from the model rather than assumed -----------------
cycles <- load_election_cycles(); polls <- load_polls("vic")
pri <- load_prior_results(); kp <- pri$region == "vic" & pri$year == 2026
priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
fl <- flows_for(load_preference_flows(), 2026, "vic", quiet = TRUE)
now <- trend_as_at(polls, 2026, cycles, Sys.Date(), priors, fl, with_series = TRUE)
last <- as.data.table(now$series)[, .SD[which.max(date)], by = party]
tppr <- last[party == "TPP_ALP"]
mix <- fread("output/projection-mix.csv")
days_out <- as.integer(cycles[region == "vic" & year == 2026, end] - Sys.Date())
fdat <- build_fundamentals_data(); m_tpp <- fit_fundamentals(fdat, "@TPP")
live <- build_fundamentals_data(polled_only = FALSE, require_actual = FALSE)
kf <- live$region == "vic" & live$year == 2026 & live$party == "@TPP"
pj <- project_result(now$tpp, predict_fundamentals(m_tpp, live[which(kf), ]),
                     mix, days_out)
growth <- pj$sd / ((tppr$hi95 - tppr$lo95) / (2 * 1.96))
cat(sprintf("projected ALP two-party %.2f (95%%: %.2f-%.2f), %d days out, sd x%.2f\n",
            pj$mean, pj$lo95, pj$hi95, days_out, growth))

sw <- last[party != "TPP_ALP"]
sw[, sd_proj := (hi95 - lo95) / (2 * 1.96) * growth]
state_mean <- setNames(sw$mean, sw$party)
state_sd   <- setNames(sw$sd_proj, sw$party)

# ---- 4. project each seat's primaries --------------------------------------
# Every party swings uniformly off its own 2022 seat share -- EXCEPT One
# Nation, which polled 0.28% statewide in 2022 and has nothing to swing from.
# Its allocation is the weakest part of this model and is documented and
# checked separately: order by Greens share, which replicates with a negative
# coefficient in NSW, QLD and WA, and magnitude quantile-mapped onto SA 2026's
# observed spread, within 1.41x. See docs/plans/prereg-onp-allocation-vic.md
# and docs/reviews/onp-allocation-checks-2026-08-18.md. Its ordering beats a
# uniform allocation by only 0.122 MAE: trust the ONP TOTAL, not any one seat.
sa_fp <- fread(file.path(PREF, "ecsa-2026-sa-onp-shares.csv"), showProgress = FALSE)
sa_ratio <- sort(sa_fp$pct / mean(sa_fp$pct))
idx <- ONP_B1 * mat22[, "GRN"]
ord <- order(idx)                 # lowest index (strongest Greens) first
onp_ratio <- numeric(nrow(mat22)); names(onp_ratio) <- rownames(mat22)
for (r in seq_along(ord)) {
  q <- (r - 1) / (length(ord) - 1)
  pos <- q * (length(sa_ratio) - 1)
  lo <- floor(pos) + 1; hi <- min(lo + 1, length(sa_ratio))
  onp_ratio[rownames(mat22)[ord[r]]] <-
    sa_ratio[lo] + (pos - (lo - 1)) * (sa_ratio[hi] - sa_ratio[lo])
}

parties <- colnames(mat22)
shares <- mat22
modelled <- intersect(parties, names(state_mean))
for (p in setdiff(modelled, "ONP")) {
  shares[, p] <- pmax(0, mat22[, p] + (state_mean[[p]] - a22[[p]]))
}
# The trend models five classes; the seat data carries seven, splitting OTH
# into OTH, OTH_RIGHT and IND. Those three must be SCALED to the forecast OTH
# total, not left at their 2022 size. Leaving them alone kept a 17% minor field
# where the forecast says 10.5%, which diluted every other party after
# normalisation -- One Nation's median fell from 5 seats to 1 -- and inflated
# the pooled-fallback rate from 28% to 53% by keeping rare classes alive in
# survivor sets the matrix has never observed.
unmodelled <- setdiff(parties, modelled)
if (length(unmodelled) && !is.na(state_mean["OTH"])) {
  base_share <- sum(a22[unmodelled], a22[["OTH"]], na.rm = TRUE)
  scale_to <- state_mean[["OTH"]] / base_share
  for (p in unmodelled) shares[, p] <- pmax(0, mat22[, p] * scale_to)
  if ("OTH" %in% modelled) shares[, "OTH"] <- pmax(0, mat22[, "OTH"] * scale_to)
  cat(sprintf("minor field scaled x%.2f: %s at 2022 %.1f%% -> forecast %.1f%%
",
              scale_to, paste(c(unmodelled, "OTH"), collapse = "+"),
              base_share, state_mean[["OTH"]]))
}
shares[, "ONP"] <- pmax(0, state_mean[["ONP"]] * onp_ratio[rownames(mat22)])
shares <- 100 * shares / rowSums(shares)

# ---- 5. simulate ------------------------------------------------------------
psd <- vapply(parties, function(p) if (is.na(state_sd[p])) 1.5 else state_sd[[p]],
              numeric(1))
t0 <- Sys.time()
sim <- simulate_seat_contests(shares, fm, party_sd = psd, seat_sd = SEAT_SD,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = 42)
cat(sprintf("\nsimulated %d seats x %d runs in %.0fs | pooled fallback %.1f%%\n",
            nrow(shares), N_SIMS,
            as.numeric(difftime(Sys.time(), t0, units = "secs")),
            100 * sim$fallback_rate))

cat("\n=== seats won ===\n")
for (p in parties) {
  v <- sort(sim$totals[, p]); if (max(v) == 0) next
  q <- function(x) v[max(1, round(x * length(v)))]
  cat(sprintf("  %-10s median %3d   90%%: %3d-%-3d\n", p, q(.5), q(.05), q(.95)))
}
wp <- as.data.table(sim$win_prob)
cat("\n=== seats where a non-major has >=10% ===\n")
minor <- wp[party %in% c("GRN","ONP","IND","OTH","OTH_RIGHT") & prob >= 0.10]
print(minor[order(-prob)], nrows = 40)
fwrite(wp, "output/seat-probs-vic-2026.csv")
fwrite(as.data.table(sim$totals), "output/seat-sims-full-vic-2026.csv")
cat("\nwrote output/seat-probs-vic-2026.csv\n")
