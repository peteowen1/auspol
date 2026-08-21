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

N_SIMS  <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))
SEAT_SD <- 3.5      # within-region seat deviation, from seat_swing_spread()
# NOT adopted: One Nation was given its own, larger seat sd here (5.5, the
# measured RMSE of its allocation against SA 2026) and it failed its
# pre-registration. Widening a party that is BEHIND in most seats is a one-way
# ratchet: its win probability rose in 71 of 87 seats and fell in 1, because
# upside noise lets it cross a threshold while downside costs nothing where it
# was already losing. simulate_seat_contests() keeps the per-party seat_sd
# capability, unused here. See docs/reviews/onp-seat-uncertainty-2026-08-19.md.
# How statewide first-preference uncertainty is inflated from the trend band.
#
#   "growth"   -- MULTIPLICATIVE, the historical behaviour: scale every party's
#                 sd by the same ratio the two-party projection inflates the
#                 two-party trend sd.
#   "additive" -- a constant added in quadrature, which is the structure the
#                 residuals actually support. estimate_fp_extra_var.R REFUTED
#                 the multiplicative form directly: cor(|error|, posterior sd)
#                 = -0.036, p = 0.68, so a well-determined trend is no more
#                 accurate in absolute terms and there is nothing to scale.
#
# ADOPTED 2026-08-19: "additive", after both the coverage test and F4 passed.
# See docs/reviews/fp-widening-choice-2026-08-19.md.
#
# The measured factor is 2.419, the two-party projection error -- the value
# pre-registered FIRST, chosen on a tie-break written before either candidate's
# result was known.
#
# F4 was the check that mattered, because widening a party that is BEHIND in
# most seats is a one-way ratchet -- that is why the ONP seat_sd experiment
# above was refused. It is NOT a ratchet here, because this widens every party
# symmetrically at the statewide level rather than one party at the seat level:
# One Nation's expected seats move 2.96 -> 3.10 (+0.14 against a 1.0 limit) and
# its probability of winning at least one seat FALLS, 0.926 -> 0.897. Stable
# across seeds 42/101/202.
FP_SD_MODE  <- Sys.getenv("AUSPOL_FP_SD_MODE", "additive")
FP_EXTRA_SD <- 2.419   # adopted factor A; docs/reviews/fp-widening-choice-*.md
OUT_SUFFIX  <- Sys.getenv("AUSPOL_OUT_SUFFIX", "")
# Overridable ONLY so a change can be checked for stability across seeds. A
# difference that flips sign with the seed is Monte Carlo noise, which this
# repo has already mistaken for a result once.
SEED        <- as.integer(Sys.getenv("AUSPOL_SEED", "42"))
# Diagnostic arms for the One Nation allocation, declared HERE beside the other
# overrides so the S6 default-run check below can see them. Defined only
# further down, a toggle would change the published allocation with nothing in
# the run log -- which is exactly what S6 exists to prevent.
ONP_ORDER   <- Sys.getenv("AUSPOL_ONP_ORDER", "federal")   # federal | greens
ONP_FIX     <- Sys.getenv("AUSPOL_ONP_FIX", "1")           # 1 = compression fixed
stopifnot(ONP_ORDER %in% c("federal", "greens"), ONP_FIX %in% c("0", "1"))
stopifnot(FP_SD_MODE %in% c("growth", "additive"))
stopifnot(is.finite(SEED))

SMOOTH  <- 0.15     # see distribute_preferences(); NOT optional, see its docs
ONP_B1  <- -0.0968  # Greens-share coefficient, fitted on Victorian federal 2025

PREF <- election_data_path()          # external/elections, gitignored
need <- file.path(PREF, c("vec-2022-vic-transfers.csv",
                          "ecsa-2026-sa-transfers.csv",
                          "vec-2022-vic-firstprefs.csv",
                          "ecsa-2026-sa-onp-shares.csv"))
if (!all(file.exists(need))) {
  # Emitted WITH the check code so run_all.R's summary shows it. Without the
  # prefix the line is filtered out, and a poisoned cache or a failed fetch
  # would leave the candidate model and S5 silently not running behind a green
  # build -- exactly the silent failure this project keeps meeting.
  cat("S5  SKIPPED: preference data absent, candidate-level model did not run.",
      "Missing:", paste(basename(need[!file.exists(need)]), collapse = ", "), "
")
  quit(save = "no", status = 0)
}

# ---- 1. flow matrix, from both elections -----------------------------------
# Victoria is the right jurisdiction and supplies Greens, independent and
# minor-right behaviour from 452 exclusions. It cannot speak to One Nation --
# 5 of 88 seats contested in 2022 -- which is the only reason SA is here.
# QUEENSLAND, ADDED 2026-08-21. Against docs/plans/prereg-qld-flows.md: the
# matrix was 746 exclusions with just 18 One Nation exclusions behind every One
# Nation preference rate the forecast publishes. Queensland 2020 and 2024 make
# that 1,496 and 198.
#
# Both precede the November 2026 Victorian election, so neither leaks, and both
# are Compulsory Preferential -- Queensland's pre-2016 optional-preferential
# elections are excluded by the fetcher and must stay excluded, because
# exhausting ballots make those rates mean something else.
#
# Measured at +1.55 SE across the four backtest elections it can reach, with
# every election predating it byte-identical.
#
# DEFAULT IS OFF, AND REFUSAL Q4 IS WHY. That clause said to stop and report if
# any party's Victoria 2026 median moved by more than 2 seats. Measured:
#
#   ALP 40 -> 37   ONP 5 -> 9   LNP 37 -> 36   GRN 4 -> 5
#
# Labor moves 3 and One Nation 4, so the rule stops it. Set AUSPOL_QLD_FLOWS=1
# to run with the fuller matrix.
#
# The judgement Q4 exists to force is genuinely open here. It was written with a
# COVARIANCE change in mind, where a moved centre means something went wrong.
# This is a DATA change, and better data moving the answer is not a defect --
# One Nation preference rates that rested on 18 exclusion events now rest on
# 198. But a 4-seat move in a published forecast is a decision for Pete rather
# than a consequence of a script, which is exactly what the clause is for.
tx <- rbind(fread(file.path(PREF, "vec-2022-vic-transfers.csv")),
            fread(file.path(PREF, "ecsa-2026-sa-transfers.csv")))
if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1")) {
  qf <- file.path(PREF, "ecq-qld-transfers.csv")
  if (!file.exists(qf)) stop("Run scripts/fetch_preferences_qld.R first.")
  tx <- rbind(tx, fread(qf), fill = TRUE)
}
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
# DIAGNOSTIC ONLY, default 0. Shifts every party's flow-to-Labor by a fixed
# number of POINTS, to size what getting the flows wrong is worth before
# deciding whether to model flow uncertainty properly. Flows currently enter as
# CONSTANTS, identical in all draws -- a known unknown treated as known.
#
# APPLIED HERE, AT THE SOURCE, and the placement is the point. Shifting only
# `flow_of()` further down reaches just the statewide two-party anchoring, and
# that path is INERT by construction: the anchoring moves the MEAN of the
# statewide draws, while simulate_seat_contests() applies only
# `statewide_draws[s, ] - centre` (R/seat_sim.R), so a shift in the mean is
# subtracted straight back out. Shifting `fl` here also reaches trend_as_at()
# below, which is the live path.
FLOW_SHIFT <- as.numeric(Sys.getenv("AUSPOL_FLOW_SHIFT", "0"))
if (FLOW_SHIFT != 0) {
  fl$flow_alp <- pmin(95, pmax(5, fl$flow_alp + FLOW_SHIFT))
  cat(sprintf("DIAGNOSTIC: flows shifted %+.2f pts -> %s
", FLOW_SHIFT,
              paste(sprintf("%s %.1f", fl$party, fl$flow_alp), collapse = ", ")))
}

# Emitted as a CHECK CODE, not a plain cat, and this is the point of it.
# run_all.R keeps only lines matching ^[A-Z]{1,2}[0-9]+[a-c]?[ ] from each
# stage and DISCARDS the rest, so a plain message never reaches the pipeline
# log, the Actions step summary or the uploaded artifacts. A leftover
# AUSPOL_FP_SD_MODE=growth -- a mode this repo measured and REFUTED -- would
# otherwise change the published seat forecast with nothing anywhere to show
# it. Reported rather than fatal, because the diagnostic runs are legitimate;
# what must never happen is one going unnoticed.
default_run <- SEED == 42L && OUT_SUFFIX == "" && FLOW_SHIFT == 0 &&
  FP_SD_MODE == "additive" &&
  ONP_ORDER == "federal" && ONP_FIX == "1"
cat(sprintf(paste0("S6  run config: seed %d, FP sd %s, flow %+.2f, ",
                   "ONP %s/fix%s, suffix %s  %s
"),
            SEED, FP_SD_MODE, FLOW_SHIFT, ONP_ORDER, ONP_FIX,
            if (OUT_SUFFIX == "") "(none)" else OUT_SUFFIX,
            if (default_run) "PASS" else "FAIL -- NOT A DEFAULT PUBLISH RUN"))
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
# Computed OUTSIDE the brackets: `growth` and the mode are locals, and a bare
# name inside `[` binds to a column if one shares it. Six instances so far.
trend_sd <- (sw$hi95 - sw$lo95) / (2 * 1.96)
sd_vec <- if (FP_SD_MODE == "additive") {
  sqrt(trend_sd^2 + FP_EXTRA_SD^2)
} else {
  trend_sd * growth
}
sw[, sd_proj := sd_vec]
cat(sprintf("FP sd mode: %s; statewide sds %.2f-%.2f (trend %.2f-%.2f)
",
            FP_SD_MODE, min(sd_vec), max(sd_vec), min(trend_sd), max(trend_sd)))
state_mean <- setNames(sw$mean, sw$party)
state_sd   <- setNames(sw$sd_proj, sw$party)

# ---- where a party's extra votes come from ----------------------------------
# South Australia, March 2026, is the only completed election where One Nation
# moved on the scale Victoria is forecasting, and it says where the votes came
# from: One Nation +20.24, Liberal -17.12, Labor -2.48, independents -1.74,
# other-right -1.49, Greens +1.27, other +1.32.
#
# So a point of One Nation costs the Coalition 0.85 and Labor only 0.12, and the
# Greens RISE slightly. That is not what proportional renormalisation does, and
# the difference matters because One Nation's winnable seats are the ones where
# it fights the Coalition.
SA_RESPONSE <- c(LNP = -0.846, ALP = -0.123, IND = -0.086,
                 OTH_RIGHT = -0.074, GRN = 0.063, OTH = 0.065)

# AUSPOL_FORCE_FP="ONP=30" moves one party's statewide first preference to a
# stated level and rebalances the rest on that response, so the seat count can
# be read as a FUNCTION of the primary vote rather than only at today's point.
# Nothing is forced by default.
FORCE_FP <- Sys.getenv("AUSPOL_FORCE_FP", "")
if (nzchar(FORCE_FP)) {
  for (x in strsplit(strsplit(FORCE_FP, ",", fixed = TRUE)[[1]], "=", fixed = TRUE)) {
    fp_party <- trimws(x[1]); fp_target <- as.numeric(x[2])
    if (!fp_party %in% names(state_mean)) {
      stop("AUSPOL_FORCE_FP names a party the model does not carry: ", fp_party,
           ". Known: ", paste(names(state_mean), collapse = ", "))
    }
    fp_delta <- fp_target - state_mean[[fp_party]]
    resp <- SA_RESPONSE[intersect(names(SA_RESPONSE), names(state_mean))]
    resp <- resp[setdiff(names(resp), fp_party)]
    # Renormalised so the rebalance is exactly -delta and the total stays 100.
    resp <- resp / sum(abs(resp))
    state_mean[[fp_party]] <- fp_target
    for (q in names(resp)) {
      state_mean[[q]] <- max(0.1, state_mean[[q]] + fp_delta * resp[[q]])
    }
    cat(sprintf("FP1  forced %s to %.1f (was %.1f, %+.1f), rebalanced on the SA response\n",
                fp_party, fp_target, fp_target - fp_delta, fp_delta))
  }
  cat(sprintf("FP1  statewide primaries now: %s (sum %.1f)\n",
              paste(sprintf("%s %.1f", names(state_mean), state_mean),
                    collapse = ", "), sum(state_mean)))
}

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
# ORDERING, replaced 2026-08-20. Was the GREENS share, a proxy; is now each
# district's FEDERAL One Nation vote, measured in its own booths by
# scripts/transpose_federal_to_state.R.
#
# On NSW 2023 the federal ordering reaches a Spearman of +0.814 against the
# actual One Nation ordering where the Greens-share rule reaches +0.331, and
# cuts allocation MAE from 3.287 to 1.594. The old rule is WORSE than a uniform
# allocation (2.595), so it was subtracting value rather than adding it.
#
# The geography it relies on is stable: federal One Nation ordering persists at
# Spearman +0.876 from 2019 to 2022 (58 divisions) and +0.772 from 2022 to 2025
# (145). See docs/plans/prereg-onp-allocation-federal.md.
#
# Only the ORDERING changes. Federal One Nation polled 5.3% in Victoria against
# a state forecast near 20%, so nothing but shape transfers.
fed_tr <- fread(file.path(PREF, "federal-transposed-to-state.csv"),
                showProgress = FALSE)
fed_onp <- fed_tr[region == "vic" & cycle == 2026 & party == "ONP", .(seat, pct)]
idx_v <- fed_onp$pct[match(rownames(mat22), fed_onp$seat)]
if (anyNA(idx_v)) {
  stop("No transposed federal One Nation vote for: ",
       paste(rownames(mat22)[is.na(idx_v)], collapse = ", "),
       ". Run scripts/transpose_federal_to_state.R.")
}
ord <- if (Sys.getenv("AUSPOL_ONP_ORDER", "federal") == "greens") order(ONP_B1 * mat22[, "GRN"]) else order(idx_v)
onp_ratio <- numeric(nrow(mat22)); names(onp_ratio) <- rownames(mat22)
for (r in seq_along(ord)) {
  q <- (r - 1) / (length(ord) - 1)
  pos <- q * (length(sa_ratio) - 1)
  lo <- floor(pos) + 1; hi <- min(lo + 1, length(sa_ratio))
  onp_ratio[rownames(mat22)[ord[r]]] <-
    sa_ratio[lo] + (pos - (lo - 1)) * (sa_ratio[hi] - sa_ratio[lo])
}

# SENSITIVITY HANDLE on the single most load-bearing unvalidated number here.
# `sa_ratio` sets how CONCENTRATED One Nation's vote is across seats, and
# concentration decides how many seats it LEADS -- which, on South Australian
# evidence, is most of winning. It is fitted on one election.
#
# docs/reviews/onp-concentration-2026-08-21.md bounds it. Federal One Nation
# polls 4-9% against Victoria's forecast ~20%, and the two ways of carrying a
# concentration across that gap disagree by a factor of 4.4: holding the SD in
# points fixed implies a CV of 0.110 at 22.9%, holding the CV fixed implies
# 0.482. South Australia actually delivered 0.334, between them.
#
# AUSPOL_ONP_CV rescales the ratio about 1 to hit a stated CV, so the seat range
# can be reported at both ends of that bound instead of at one unvalidated
# point. Unset leaves the shape exactly as measured.
ONP_CV <- as.numeric(Sys.getenv("AUSPOL_ONP_CV", "0"))
if (is.finite(ONP_CV) && ONP_CV > 0) {
  cur <- stats::sd(onp_ratio) / mean(onp_ratio)
  # VECTOR FIRST. pmax(0.02, x) drops x's NAMES, exactly as pmax(0.1, m) drops a
  # matrix's dim -- and onp_ratio is looked up BY SEAT NAME immediately after,
  # so the whole allocation silently became NA. Second time this argument order
  # has bitten today.
  onp_ratio <- pmax(1 + (ONP_CV / cur) * (onp_ratio - 1), 0.02)
  cat(sprintf("CN1  One Nation concentration forced: CV %.3f -> %.3f (delivered %.3f)\n",
              cur, ONP_CV, stats::sd(onp_ratio) / mean(onp_ratio)))
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
# COMPRESSION FIX, separate from the ordering change and reported separately.
# Setting One Nation and then dividing the whole row by its total shrank the
# spread by 13.7%: a district allocated a high share has a larger row total, so
# renormalising cut it hardest. The quantile map produced a CV of 0.327 --
# matching South Australia's 0.334 as intended -- and normalisation reduced it
# to 0.283.
#
# Instead the other parties are scaled to fill exactly what One Nation leaves,
# so the row already sums to 100 and the intended share survives.
# Toggles exist ONLY so the two changes can be attributed separately, which the
# pre-registration requires: without them a spread increase from the
# compression fix would be credited to the new ordering. Both default to the
# adopted behaviour.
ONP_ORDER <- Sys.getenv("AUSPOL_ONP_ORDER", "federal")   # federal | greens
ONP_FIX   <- Sys.getenv("AUSPOL_ONP_FIX", "1")           # 1 = compression fixed
stopifnot(ONP_ORDER %in% c("federal", "greens"))
cat(sprintf("ONP arms: ordering %s, compression fix %s
", ONP_ORDER, ONP_FIX))
# A sanity bound, not a modelling choice: no district comes near it (the
# maximum allocation is 33.0). It exists so a future statewide forecast times
# the largest quantile ratio cannot exceed 100 and drive the fill negative.
ONP_CAP <- 80
onp_target <- pmin(pmax(0, state_mean[["ONP"]] * onp_ratio[rownames(mat22)]), ONP_CAP)
if (ONP_FIX == "1") {
  other_cols <- setdiff(colnames(shares), "ONP")
  rest <- rowSums(shares[, other_cols, drop = FALSE])
  fill <- pmax(0, 100 - onp_target) / pmax(rest, 1e-9)
  for (p in other_cols) shares[, p] <- shares[, p] * fill
}
shares[, "ONP"] <- onp_target
shares <- 100 * shares / rowSums(shares)
cvf <- function(x) stats::sd(x) / mean(x)
cat(sprintf("ONP allocation: target CV %.3f, delivered %.3f (previously compressed to 0.283)
",
            cvf(onp_target), cvf(shares[, "ONP"])))

# ---- 5. statewide draws, ANCHORED to the projection -------------------------
# Drawing each party independently and renormalising destroys the
# Labor-versus-Coalition covariance: measured, it reproduced only 60% of the
# projection's two-party spread (sd 1.52 against 2.52) and centred 1.2 points
# too favourable to Labor, because the party trends are today's while the
# projection is election day's. Both errors make the seat range too tight and
# too Labor-friendly.
#
# The projection is the calibrated object here -- its 95% intervals contain the
# truth 92.8% of the time over 195 election-horizon pairs -- so the seat model
# inherits it rather than rebuilding it. Each simulation draws a two-party
# figure from the projection, then moves the Labor/Coalition split by exactly
# the gap needed to hit it. Moving d points from LNP to ALP moves the two-party
# figure by d, so the correction is exact rather than iterative.
set.seed(SEED)
psd <- vapply(parties, function(p) if (is.na(state_sd[p])) 1.5 else state_sd[[p]],
              numeric(1))
# CORRELATED ACROSS PARTIES, not independent. Drawing each party on its own and
# renormalising means a simulation where One Nation runs five points hot takes
# those votes evenly from Labor, the Greens and the Coalition alike. Measured
# across the ten election pairs this repo holds, the statewide change in One
# Nation's vote correlates with the Coalition's at -0.83 and with Labor's at
# -0.12: it takes Coalition votes and almost nothing else.
#
# That biases in a knowable direction. One Nation's winnable seats are the ones
# it takes from the Coalition, so under independence its good simulations are
# not systematically the Coalition's bad ones and it crosses the line less often
# than it should.
#
# AUSPOL_PARTY_COR=off restores independent draws exactly. The value is "off"
# rather than an empty string because PowerShell REMOVES an environment
# variable when it is set to '', so R falls back to the default and the arm
# silently runs the opposite way -- which is how the first attempt at this
# comparison ran the correlated branch while claiming to be the baseline.
# See docs/plans/prereg-statewide-covariance.md and
# scripts/estimate_statewide_cov.R.
COR_MODE <- Sys.getenv("AUSPOL_PARTY_COR", "shrunk")
sw_cor <- NULL
if (!identical(COR_MODE, "off") && nzchar(COR_MODE)) {
  .co <- readRDS("output/statewide-cov.rds")
  cm <- if (identical(COR_MODE, "raw")) .co$cor else .co$cor_shrunk
  miss <- setdiff(parties, colnames(cm))
  if (length(miss)) {
    stop("The statewide correlation has no entry for: ",
         paste(miss, collapse = ", "),
         ". Re-run scripts/estimate_statewide_cov.R.")
  }
  sw_cor <- cm[parties, parties, drop = FALSE]
}
mu <- vapply(parties, function(p) {
  if (is.na(state_mean[p])) mean(shares[, p]) else state_mean[[p]]
}, numeric(1))
if (is.null(sw_cor)) {
  sw_draws <- vapply(parties, function(p)
    pmax(0.1, stats::rnorm(N_SIMS, mu[[p]], psd[[p]])), numeric(N_SIMS))
} else {
  Z <- matrix(stats::rnorm(N_SIMS * length(parties)), nrow = N_SIMS)
  sw_draws <- Z %*% chol(sw_cor)
  sw_draws <- sweep(sweep(sw_draws, 2, psd[parties], "*"), 2, mu, "+")
  # pmax(0.1, m) DROPS the dim attribute, so the matrix arrives first.
  sw_draws <- pmax(sw_draws, 0.1)
}
colnames(sw_draws) <- parties
sw_draws <- sw_draws / rowSums(sw_draws) * 100
# VERIFY the correlation SURVIVED renormalisation, rather than assuming it. The
# rescale to 100 is itself a transformation and could undo what was imposed; if
# One Nation and the Coalition come out uncorrelated here, the draws going into
# the simulation are not the ones that were measured.
if (!is.null(sw_cor) && all(c("ONP", "LNP") %in% parties)) {
  realised <- stats::cor(sw_draws[, "ONP"], sw_draws[, "LNP"])
  cat(sprintf("COV  statewide draws correlated (%s): cor(ONP,LNP) target %+.2f, realised %+.2f\n",
              COR_MODE, sw_cor["ONP", "LNP"], realised))
  if (realised > -0.10) {
    stop("The imposed correlation did not survive renormalisation: target ",
         round(sw_cor["ONP", "LNP"], 2), ", realised ", round(realised, 2), ".")
  }
}

flow_of <- function(p) {
  f <- fl$flow_alp[fl$party == p]
  if (length(f)) f[1] / 100 else 0.489
}
minors <- setdiff(parties, c("ALP", "LNP"))
implied <- sw_draws[, "ALP"] +
  rowSums(vapply(minors, function(p) sw_draws[, p] * flow_of(p), numeric(N_SIMS)))
target <- stats::rnorm(N_SIMS, pj$mean, pj$sd)
d <- target - implied
sw_draws[, "ALP"] <- pmax(0.1, sw_draws[, "ALP"] + d)
sw_draws[, "LNP"] <- pmax(0.1, sw_draws[, "LNP"] - d)
sw_draws <- sw_draws / rowSums(sw_draws) * 100

chk <- sw_draws[, "ALP"] +
  rowSums(vapply(minors, function(p) sw_draws[, p] * flow_of(p), numeric(N_SIMS)))
cat(sprintf("
statewide draws anchored: two-party mean %.2f sd %.3f (projection %.2f / %.3f)
",
            mean(chk), sd(chk), pj$mean, pj$sd))
stopifnot(abs(mean(chk) - pj$mean) < 0.3, abs(sd(chk) - pj$sd) < 0.3)

t0 <- Sys.time()
# CALIBRATION SHRINK. Measured on 1,187 seats across 10 elections in
# docs/reviews/calibration-2026-08-21.md: this model's calibration slope was
# below 1 in nine of them, so a seat called at 95% won about 70% of the time. A
# per-draw shrink of 0.10 -- fitted leave-one-election-out and identical in all
# ten folds -- beats both the status quo (+3.04 SE) and a post-hoc temperature
# on the output (+3.36 SE) on held-out log score.
#
# ON BY DEFAULT, and K5 is why it is allowed to be. That refusal required the
# effect on the Victorian seat medians to be reported before shipping, with a
# 2-seat move on any party stopping it. Measured:
#
#   ALP 41 -> 40   LNP 38 -> 37   GRN 4 -> 4   ONP 4 -> 5   IND 0 -> 0
#
# No party moves by more than one. The centres barely shift while the intervals
# widen, which is what a calibration fix should do and what a fix that had
# quietly become a forecast change would not. One Nation's 90% interval moves
# from 0-9 to 1-11.
#
# Set AUSPOL_SHRINK=0 to reproduce the pre-2026-08-21 forecast exactly.
SHRINK <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0.10"))
if (SHRINK > 0) cat(sprintf("CAL  calibration shrink %.2f applied
", SHRINK))
sim <- simulate_seat_contests(shares, fm, party_sd = psd, seat_sd = SEAT_SD, shrink = SHRINK,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED,
                              statewide_draws = sw_draws)
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
# ---- 6. S5: cross-check against the two-party seat model --------------------
# The two-party model cannot represent a non-major winner, which is why it is
# no longer the published seat forecast. It is kept as a CHECK because it is
# the only independent estimate of Labor's seat count, built from the anchor's
# notional margins rather than from primaries and flows, and it costs seconds.
#
# It has already earned its place: when the candidate model was rebuilding the
# statewide distribution instead of inheriting the projection, the two medians
# still agreed while the RANGES did not, and that mismatch is what exposed the
# bug. A check on the median alone would have missed it, so this checks both.
# Restricted to the seats the candidate model actually covers. It has 87:
# Narracan has no ordinary 2022 first preferences, its election having failed
# after a candidate died and the January 2023 supplementary going uncontested
# by Labor. simulate_seats() has all 88 and counts Narracan as a classic seat,
# so comparing the totals unrestricted compares different populations and lets
# a real divergence hide behind a one-seat offset.
seats_all <- load_seats(2026, "vic")
seats26 <- seats_all[seats_all$seat %in% rownames(mat22), ]
if (nrow(seats26) != nrow(seats_all)) {
  cat(sprintf("S5  comparing on %d seats; absent from the candidate model: %s
",
              nrow(seats26),
              paste(setdiff(seats_all$seat, rownames(mat22)), collapse = ", ")))
}
sp22 <- seat_swing_spread(seats26, 55.00 - 57.60)
sp18 <- seat_swing_spread(load_seats(2022, "vic"), 57.60 - 51.99)
tp <- simulate_seats(seats26, pj$mean, pj$sd, 55.00,
                     mean(c(sp22$sd_within, sp18$sd_within)),
                     region_sd = mean(c(sp22$sd_between, sp18$sd_between)),
                     n_sims = 50000, seed = SEED)
tp_q <- stats::quantile(tp$alp_total, c(0.05, 0.5, 0.95))
cl_alp <- sort(sim$totals[, "ALP"])
cl_q <- cl_alp[pmax(1, round(c(0.05, 0.5, 0.95) * length(cl_alp)))]

med_gap <- abs(cl_q[2] - tp_q[2])
wid_ratio <- (cl_q[3] - cl_q[1]) / (tp_q[3] - tp_q[1])
cat(sprintf("
S5  two-party seat model : ALP median %2d (90%%: %2d-%2d)
",
            tp_q[2], tp_q[1], tp_q[3]))
cat(sprintf("    candidate-level model: ALP median %2d (90%%: %2d-%2d)
",
            cl_q[2], cl_q[1], cl_q[3]))
cat(sprintf("    median gap %d seats (max 5), 90%%-width ratio %.2f (0.7-1.4)  %s
",
            med_gap, wid_ratio,
            if (med_gap <= 5 && wid_ratio >= 0.7 && wid_ratio <= 1.4) "PASS" else "FAIL"))
if (med_gap > 5 || wid_ratio < 0.7 || wid_ratio > 1.4) {
  stop(sprintf(paste0("S5 FAILED: the two seat models disagree. Median gap %d ",
                      "seats, 90%%-width ratio %.2f. One of them is wrong and ",
                      "the published figure cannot be trusted until it is known ",
                      "which."), med_gap, wid_ratio))
}

# The projected per-seat primaries the simulation runs on. Written out because
# nothing else can reconstruct them without duplicating the projection above,
# and a second copy of that logic would drift from this one.
fwrite(data.table(seat = rownames(shares), as.data.table(shares)),
       sprintf("output/seat-shares-vic-2026%s.csv", OUT_SUFFIX))
fwrite(wp, sprintf("output/seat-probs-vic-2026%s.csv", OUT_SUFFIX))
fwrite(as.data.table(sim$totals), sprintf("output/seat-sims-full-vic-2026%s.csv", OUT_SUFFIX))
cat(sprintf("
wrote output/seat-probs-vic-2026%s.csv
", OUT_SUFFIX))
