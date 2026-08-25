# Backtest the candidate-level seat model on South Australia 2022 -> 2026.
#
# WHY THIS PAIR MATTERS MORE THAN ITS 47 SEATS. Every other backtest is a
# two-major contest. South Australia 2026 is the only completed election where
# One Nation contested at the level Victoria is forecasting -- 22.87% of the
# statewide primary against Victoria's projected ~21% -- and it elected four
# One Nation members while the Liberal vote fell from 36.15% to 19.03%.
#
# So this is the only place the model can be scored on the thing that is
# actually in doubt: whether it can call seats when a third party displaces a
# major.
#
# THE FLOW MATRIX COMES FROM ANOTHER JURISDICTION, which no other harness here
# does. ECSA publishes a full distribution of preferences for 2026 and NOT for
# 2022, so there is no South Australian matrix predating the election being
# predicted. Federal 2025 is used: full preferential like South Australia, held
# in May 2025 and therefore before the March 2026 poll, and the largest transfer
# corpus available at 2,606 exclusion events.
#
# That is a real difference from the Victorian and NSW harnesses and it is NOT
# a workaround -- it is the situation the live Victorian forecast is in, since
# no Victorian election has ever seen One Nation transfer a meaningful number of
# votes. If the model degrades badly here, that matters more than the sample
# size suggests.
#
# NOTHING LEAKS. First preferences from 2022, flow matrix from federal 2025,
# scored against ECSA's declared 2026 winners.
#
# ---------------------------------------------------------------------------
# READ THIS BEFORE QUOTING THE ONE NATION NUMBER.
#
# This harness allocates a party's statewide movement to districts UNIFORMLY:
# every seat gets the same shift. So does backtest_candidate_vic.R,
# backtest_candidate_nsw.R and backtest_candidate_fed.R.
#
# `fit_seats_full.R` -- the model that publishes -- does NOT. It has a
# dedicated One Nation allocation: seats are ORDERED by the transposed federal
# One Nation vote and the statewide total is spread across them to hit a target
# coefficient of variation of 0.327, concentrating the vote where that party is
# actually strong.
#
# That step is the entire reason One Nation can win a seat in the published
# Victorian forecast, and NO BACKTEST IN THIS REPO IMPLEMENTS IT. So a One
# Nation result here is a bound on the model WITHOUT its allocation, and must
# not be reported as the published model's performance.
#
# The gap matters in exactly one direction. One Nation's South Australian vote
# was concentrated -- 37.7% in Narungga and 35.1% in MacKillop against 22.87%
# statewide -- which is what a uniform shift cannot produce and what the
# allocation exists to produce.
#
# The useful consequence: SA 2026 is the only completed election that can test
# that allocation out of sample, and it never has been.
# ---------------------------------------------------------------------------
#
# Emits BS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# ---- other jurisdictions' flows, date-filtered ------------------------------
# Against docs/plans/prereg-qld-flows.md and docs/plans/prereg-wa-flows.md.
# Queensland 2020 and 2024 add 750 exclusion events; Western Australia's seven
# admissible elections add 1,634 and take One Nation's from 198 to 359.
#
# Either may only be used to predict an election held AFTER it. That rule lives
# in pool_configured_flows() rather than in a copy per harness -- there were
# four byte-identical copies, one of which had rotted into a gate that was
# defined and never called, and it is the one rule here that must never be
# wrong. Both sources default OFF.

# ARM B of docs/plans/prereg-calibration.md. A multiplier on the per-seat
# spread, so the simulation carries more genuine seat-level uncertainty. Default
# 1 reproduces the published behaviour exactly; the run prints what it applied,
# because CLAUDE.md records an experiment whose edit never ran and whose
# byte-identical output read as "this input does not matter".
SEAT_SD_MULT <- as.numeric(Sys.getenv("AUSPOL_SEAT_SD_MULT", "1"))
if (SEAT_SD_MULT != 1) cat(sprintf("CAL  seat_sd multiplier %.2f applied
", SEAT_SD_MULT))

# OUTPUT FILENAME CARRIES THE CONFIG, and it must. These harnesses used to write
# to one fixed name, so running an experimental arm SILENTLY OVERWROTE the
# baseline it was meant to be compared against. That happened on 2026-08-21: a
# seat_sd sweep overwrote backtest-fed.csv and backtest-vic.csv, and the
# resulting comparison showed a difference of EXACTLY +0.0000 for all six
# federal elections because both arms were the same file. It read as "this
# input does not matter", which is the failure mode CLAUDE.md already records
# for an experiment that never ran.
#
# A default run still writes the plain name, so nothing downstream changes.

# ARM B/C of docs/plans/prereg-statewide-covariance.md. AUSPOL_PARTY_COR=shrunk
# correlates the parties' statewide deviations instead of drawing them
# independently. Empty (the default) reproduces the previous behaviour exactly.
PARTY_COR <- NULL
if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", ""))) {
  .co <- readRDS("output/statewide-cov.rds")
  PARTY_COR <- if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) .co$cor else .co$cor_shrunk
  cat(sprintf("COV  party correlation ON (%s): cor(ONP,LNP) = %+.2f
",
              Sys.getenv("AUSPOL_PARTY_COR"), PARTY_COR["ONP", "LNP"]))
}

# Read from the environment like the federal and Victorian harnesses, and
# tagged into the filename below. Hardcoded, this script could not be run
# at the same sim count as the arms it is compared against, and a paired
# comparison across jurisdictions at different sim counts is not paired.
N_SIMS <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))

CAL_TAG <- paste0(
  if (SEAT_SD_MULT != 1) sprintf("-m%s", format(SEAT_SD_MULT, nsmall = 1)) else "",
  # The concentration arm MUST be in the tag. Without it the arm overwrites
  # backtest-sa.csv and a before/after comparison compares an arm with itself
  # -- the baseline-clobbering that has already produced four byte-identical
  # comparisons in this repo.
  if (as.numeric(Sys.getenv("AUSPOL_ONP_CONC_SD", "0")) > 0)
    sprintf("-conc%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_ONP_CONC_SD")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_SHRINK", "0")) != 0)
    sprintf("-sh%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_SHRINK")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0")) != 0)
    sprintf("-fb%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0")) != 0)
    sprintf("-fsd%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_FLOW_SD")), nsmall = 1)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5")) != 1.5)
    sprintf("-psd%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_PARTY_SD")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0")) != 0)
    sprintf("-el%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER")), nsmall = 1)))
  else "",
  if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")) "-port" else "",
  # "-corraw" and "-cor" are DIFFERENT correlation matrices. Both used to tag
  # "-cor", so running the raw arm and then the shrunk one wrote the second
  # over the first and a before/after comparison compared an arm with itself.
  if (!is.null(PARTY_COR))
    (if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "-corraw" else "-cor")
  else "",
  if (N_SIMS != 20000L) sprintf("-n%d", N_SIMS) else "",
  if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1")) "-qld" else "",
  if (identical(Sys.getenv("AUSPOL_WA_FLOWS", "0"), "1")) "-wa" else "",
  # The control arm of refusal W1 runs with the flows switched ON and a cutoff
  # that admits nothing. Without this it would write to the same "-wa" name as
  # the real arm and overwrite it -- the baseline-clobbering that has already
  # produced four byte-identical comparisons here.
  if (nzchar(Sys.getenv("AUSPOL_WA_CUTOFF", "")) ||
      nzchar(Sys.getenv("AUSPOL_QLD_CUTOFF", ""))) "-cut" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_3C", "0"), "1")) "-no3c" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_LNP", "0"), "1")) "-nolnp" else "")

SEED <- 42; SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()
FLOW_FROM <- "fed2025"

need <- c("ecsa-2022-sa-firstprefs.csv", "ecsa-2026-sa-firstprefs.csv",
          "ecsa-sa-winners.csv", "aec-fed-transfers.csv")
miss <- need[!file.exists(file.path(P, need))]
if (length(miss)) {
  stop("Missing ", paste(miss, collapse = ", "), ". Run ",
       "scripts/fetch_sa2022_and_winners.R and scripts/fetch_preferences_fed.R.")
}

fa <- fread(file.path(P, "ecsa-2022-sa-firstprefs.csv"), showProgress = FALSE)
fb <- fread(file.path(P, "ecsa-2026-sa-firstprefs.csv"), showProgress = FALSE)
win <- fread(file.path(P, "ecsa-sa-winners.csv"),
             showProgress = FALSE)[election == "sa2026", .(seat, winner)]
tx <- fread(file.path(P, "aec-fed-transfers.csv"),
            showProgress = FALSE)[election == FLOW_FROM]
# Guard on the row count as well as the id: all() over an empty table is TRUE,
# which is the guard-that-cannot-fail pattern CLAUDE.md records.
stopifnot(nrow(tx) > 100L, all(tx$election == FLOW_FROM))
tx <- pool_configured_flows(tx, "2026-03-21")
fm <- build_flow_matrix(tx, min_n = 3L)
cat(sprintf("\nBS1  flow matrix from %s: %d exclusions\n",
            FLOW_FROM, uniqueN(tx[, paste(seat, round)])))

wide <- dcast(fa, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(wide[, -1, with = FALSE]); rownames(mat) <- wide$seat
mat <- 100 * mat / rowSums(mat)
st_a <- fa[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
st_b <- fb[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

parties <- colnames(mat); shares <- mat

# STRONGHOLD ELASTICITY, against docs/plans/prereg-stronghold-elasticity.md.
# Default OFF; a plain run is byte-identical.
#
# A uniform swing takes the same POINTS from a seat holding 67% as from one
# holding 30%. Measured across 2,878 observations, that is right on average and
# badly wrong in one specific place: a STRONGHOLD of a party FALLING statewide,
# where proportional nearly halves the error (MAE 6.964 -> 3.848 at >1.5x
# over-index, n=102). For all parties regardless of direction the same band has
# uniform better by 1.155, so the effect is conditional on falling.
#
# Both thresholds are FIXED by the plan and are not tuned here.
ELASTIC   <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0"))   # 0 = off; 1.5 = on
ELASTIC_D <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_FALL", "2"))   # min statewide fall
n_elastic <- 0L; elastic_seats <- character(0)
# Which (seat, party) cells the rule cut. Renormalisation must NOT hand a
# stronghold back a share of the vote just taken off it -- measured on
# MacKillop, plain renormalisation undid 38% of the cut (35.3 -> 40.6).
pinned <- matrix(FALSE, nrow(mat), ncol(mat), dimnames = dimnames(mat))

for (p in parties) if (p %in% names(st_b) && p %in% names(st_a)) {
  d_state <- st_b[[p]] - st_a[[p]]
  val <- pmax(0, mat[, p] + d_state)
  if (ELASTIC > 0 && d_state < -ELASTIC_D && st_a[[p]] > 0) {
    over <- mat[, p] / st_a[[p]]
    hit  <- is.finite(over) & over > ELASTIC
    if (any(hit)) {
      val[hit] <- pmax(0, mat[hit, p] * st_b[[p]] / st_a[[p]])
      pinned[hit, p] <- TRUE
      n_elastic <- n_elastic + sum(hit)
      elastic_seats <- c(elastic_seats, sprintf("%s:%s", p, rownames(mat)[hit]))
    }
  }
  shares[, p] <- val
}
# PRINT WHAT IT APPLIED. CLAUDE.md records an experiment whose edit never ran
# and whose byte-identical output read as "this input does not matter".
if (ELASTIC > 0) {
  cat(sprintf("BS1e elasticity ON (over-index > %.2f, statewide fall > %.1f): %d (seat, party) cells\n",
              ELASTIC, ELASTIC_D, n_elastic))
  if (n_elastic) {
    cat(sprintf("BS1e fired on: %s\n",
                paste(utils::head(sort(elastic_seats), 12), collapse = ", ")))
  }
} else {
  cat("BS1e elasticity OFF (uniform swing)\n")
}
# One Nation stood in 19 of 47 districts in 2022 and all 47 in 2026, so 28
# districts have a ZERO baseline for the party that went on to make the final
# two in 32 of them. Adding the statewide shift to a zero baseline is the only
# thing that can be done without inventing a district-level distribution -- but
# it means the model enters those seats assuming One Nation polls its statewide
# average there. That is recorded because it is the single biggest source of
# error here, not because it can be fixed.
absent22 <- setdiff(names(st_b)[st_b > 1], names(st_a)[st_a > 1])
zero_base <- sum(mat[, "ONP"] == 0)
cat(sprintf("BS1  districts with no 2022 One Nation vote to swing from: %d of %d\n",
            zero_base, nrow(mat)))
if (length(absent22)) {
  cat(sprintf("BS1  parties polling >1%% in 2026 but not 2022: %s\n",
              paste(absent22, collapse = ", ")))
}
# ---- ARM: transported One Nation concentration -----------------------------
# Against docs/plans/prereg-onp-concentration-transport.md. Default OFF, so a
# plain run reproduces the uniform-allocation figures exactly.
#
# The uniform path above gives every district the statewide One Nation figure,
# which is why the party finishes second nearly everywhere and first nowhere.
# This arm orders districts by the transposed federal One Nation vote -- the
# step already validated out of sample here at Spearman +0.939 -- and spreads
# the same statewide total to a target SD.
#
# THE TARGET SD IS NOT FITTED ON THIS ELECTION. It comes from
# SD = a * statewide^k estimated on the OTHER elections only. sa_ratio, the
# published curve, IS fitted on SA 2026 (its CV 0.327 against SA's actual
# 0.334) and is deliberately not used here -- that would be fitting and
# testing on one election.
ONP_CONC <- as.numeric(Sys.getenv("AUSPOL_ONP_CONC_SD", "0"))
if (ONP_CONC > 0) {
  ftr <- fread(file.path(P, "federal-transposed-to-state.csv"), showProgress = FALSE)
  fo <- ftr[region == "sa" & party == "ONP" & cycle == 2026L, .(seat, pct)]
  stopifnot(!any(duplicated(fo$seat)))
  # Frome -> Ngadjuri, the 2025 redistribution rename. That mapping is applied
  # further down (RENAMES) but AFTER this block, and the transposition file
  # already uses the new name -- so the lookup has to translate here or it
  # fails on exactly the seat One Nation won. Applied to the lookup key only;
  # `shares` is left alone so the rename below still does its job.
  lookup_names <- rownames(shares)
  lookup_names[lookup_names == "Frome"] <- "Ngadjuri"
  ix <- fo$pct[match(lookup_names, fo$seat)]
  if (anyNA(ix)) {
    stop("No transposed federal One Nation vote for: ",
         paste(lookup_names[is.na(ix)], collapse = ", "))
  }
  lvl <- mean(shares[, "ONP"])
  # Normal quantile map: rank by federal ONP, assign z-scores, scale to the
  # target SD. Minimal choice -- it hits the SD without importing any shape
  # information from the election being predicted.
  rk <- rank(ix, ties.method = "first")
  z <- stats::qnorm((rk - 0.5) / length(rk))
  newonp <- pmax(0, lvl + ONP_CONC * z)
  newonp <- newonp * (lvl / mean(newonp))     # preserve the statewide total
  cat(sprintf("BS1c ONP concentration ARM ON: target SD %.2f, delivered %.2f, mean %.2f -> %.2f\n",
              ONP_CONC, sd(newonp), lvl, mean(newonp)))
  cat(sprintf("BS1c ONP range across districts: %.1f to %.1f\n",
              min(newonp), max(newonp)))
  shares[, "ONP"] <- newonp
}

# ZERO IND WHERE NO INDEPENDENT STOOD. Ported from backtest_candidate_fed.R,
# which got this fix today; this harness never had it.
#
# Six South Australian seats had an independent in 2022 and none in 2026, and
# the model swings the departed candidate's vote forward regardless. Frome --
# renamed Ngadjuri, and one of the four seats One Nation won -- carried a
# 16.6% independent in 2022 who did not recontest, so roughly 15 points of the
# seat is assigned to a candidate who does not exist and every real party is
# dragged down when the seat renormalises.
#
# This is NOMINATION data, not the result: which classes contest a seat is
# knowable before polling day. There is no pre-election nomination list here,
# only "IND received a nonzero vote in the target election" as a proxy, so it
# is the same oracle input this harness already uses for `st_b` -- consistent
# with the default path, and it is why the federal version is gated OFF under
# FORECAST_MODE.
if ("IND" %in% colnames(shares)) {
  ind_seats <- fb[party == "IND" & votes > 0, unique(seat)]
  no_ind <- setdiff(rownames(shares), ind_seats)
  zeroed <- no_ind[shares[no_ind, "IND"] > 0.5]
  shares[no_ind, "IND"] <- 0
  cat(sprintf("BS1i zeroed IND in %d seat(s) with no independent nominated%s\n",
              length(zeroed),
              if (length(zeroed)) paste0(": ", paste(sort(zeroed), collapse = ", ")) else ""))
}

# CONSTRAINED RENORMALISATION. Plain renormalisation scales every party in the
# seat, including one the elasticity rule just cut -- so the cut party receives
# back a share of its own removed vote. Measured on MacKillop: elasticity takes
# the Coalition to 35.3 (AEF forecast 35.0, actual 26.9) and renormalising puts
# it straight back to 40.6, undoing 38% of the correction.
#
# Where a cell was cut, it is PINNED at its elastic value and only the other
# parties in that seat are scaled to fill the remainder.
if (ELASTIC > 0 && any(pinned)) {
  for (i in which(rowSums(pinned) > 0)) {
    keep <- pinned[i, ]
    fixed_tot <- sum(shares[i, keep])
    rest <- shares[i, !keep]
    rest_tot <- sum(rest)
    room <- 100 - fixed_tot
    if (rest_tot > 0 && room > 0) {
      shares[i, !keep] <- rest * room / rest_tot
    }
  }
  # every other seat renormalises as before
  other <- which(rowSums(pinned) == 0)
  if (length(other)) {
    shares[other, ] <- 100 * shares[other, , drop = FALSE] / rowSums(shares[other, , drop = FALSE])
  }
  cat(sprintf("BS1e constrained renormalisation applied to %d seat(s)\n",
              sum(rowSums(pinned) > 0)))
} else {
  shares <- 100 * shares / rowSums(shares)
}

# FROME WAS RENAMED NGADJURI at the 2025 South Australian redistribution, and
# it is the only name that differs between the two polls. It is MAPPED rather
# than dropped, which is the opposite of what backtest_candidate_vic.R does with
# Eureka -- so the reason has to be better than convenience.
#
# It is: One Nation WON Ngadjuri. Dropping the seat would remove one of its four
# wins from a 47-seat test whose entire purpose is scoring how the model handles
# a One Nation surge, and would do so in the direction that flatters the model.
# Excluding a seat is not neutral when the exclusion is correlated with the
# outcome under test.
#
# What is NOT verified is whether the boundaries moved materially as well as the
# name. If they did, this seat carries more error than the rest, and it is named
# here so nobody has to rediscover which one it is.
RENAMES <- c(Frome = "Ngadjuri")
idx <- match(rownames(shares), names(RENAMES))
rownames(shares)[!is.na(idx)] <- unname(RENAMES[idx[!is.na(idx)]])
cat(sprintf("BS1  renamed for the 2025 redistribution: %s\n",
            paste(sprintf("%s -> %s", names(RENAMES), RENAMES), collapse = ", ")))

keep <- intersect(rownames(shares), win$seat)
shares <- shares[keep, , drop = FALSE]
truth <- setNames(win$winner, win$seat)[keep]
if (length(keep) != 47L) {
  stop("Only ", length(keep), " of 47 districts matched between the 2022 first ",
       "preferences and the 2026 winners after applying the rename map. ",
       "Unmatched: ",
       paste(setdiff(win$seat, rownames(shares)), collapse = ", "))
}

# ---- seat-swing port, third testable election ------------------------------
# Against docs/plans/prereg-seat-swing-port-round2.md, which had TWO elections
# and a clustered standard error on one degree of freedom. South Australia is
# the third: 2026sa.txt carries fed_swing for all 47 seats. The federal corpus
# cannot help -- its seat files carry fed_swing for zero seats, because "how
# this seat swung at the preceding federal election" has no federal analogue.
#
# Same block as the Victorian and NSW harnesses, unchanged in substance
# (refusal P4).
PORT <- identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")
if (PORT) {
  sf_to <- as.data.table(load_seats(2026L, "sa"))
  idx_p <- match(rownames(shares), sf_to$seat)
  adj <- rep(0, nrow(shares))
  adj[!is.na(idx_p)] <- seat_swing_adjustment(sf_to[idx_p[!is.na(idx_p)]])
  if (anyNA(idx_p)) {
    cat(sprintf("BS1c %d seats have no match in the seat file and get no adjustment: %s\n",
                sum(is.na(idx_p)), paste(rownames(shares)[is.na(idx_p)], collapse = ", ")))
  }
  adj <- adj - mean(adj)
  stopifnot(all(is.finite(adj)))
  cat(sprintf("BS1c seat-swing port ON: adjustment mean %+.3f sd %.3f range %+.2f..%+.2f\n",
              mean(adj), stats::sd(adj), min(adj), max(adj)))
  shares[, "ALP"] <- pmax(0, shares[, "ALP"] + adj)
  shares[, "LNP"] <- pmax(0, shares[, "LNP"] - adj)
  shares <- 100 * shares / rowSums(shares)
}

# Per-seat spread from the seat file of the election being predicted.
sp <- seat_swing_spread(as.data.table(load_seats(2026L, "sa")),
                        unname(st_b[["ALP"]] - st_a[["ALP"]]))
# STATEWIDE UNCERTAINTY. 1.5 was hardcoded in all four harnesses; the realised
# statewide first-preference error over 139 party-cycles is sd 2.33, so the
# harnesses were 1.6x over-confident BEFORE any seat-level modelling. That is
# upstream of `shrink`, which is a post-hoc patch for uncertainty that should
# have been present. fit_seats_full.R already uses a per-party state_sd and
# falls back to 1.5 only when it is NA.
PARTY_SD <- as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5"))
psd <- setNames(rep(PARTY_SD, length(parties)), parties)
cat(sprintf("BS1p party_sd %.2f (realised statewide sd is 2.33)
", PARTY_SD))

# THIS HARNESS HAS NEVER PASSED `shrink`, which is the same defect
# docs/reviews/calibration-2026-08-21.md found in the federal, Victorian and
# NSW harnesses and which was never fixed here.
#
# fit_seats_full.R -- the model that PUBLISHES -- passes shrink = 0.10, the
# per-draw calibration shrink adopted after measuring over-confidence on 1,187
# seats. simulate_seat_contests() defaults it to 0. So every calibration figure
# this harness has produced, including the slope of 0.299 and the four One
# Nation seats at 0.000, describes a configuration we DO NOT SHIP.
#
# It matters most in exactly the seats that fail here. Shrink is a coin toss
# between the FINAL TWO, so where One Nation makes the final pair and loses, it
# still collects roughly shrink/2 of the draws instead of nothing.
#
# Defaulted to 0 so past runs stay comparable and nothing changes silently.
SHRINK <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0"))
stopifnot(is.finite(SHRINK), SHRINK >= 0, SHRINK < 1)
cat(sprintf("BS1s shrink %.2f (fit_seats_full.R publishes with 0.10)\n", SHRINK))

set.seed(SEED)
# The two flow fixes, both default OFF so a plain run is unchanged.
# docs/reviews/flow-matrix-is-the-defect-2026-08-25.md: this matrix has NO
# conditional cell for ALP|LNP+ONP, LNP|ALP+ONP or GRN|LNP+ONP, so every
# One Nation contest falls back to a pooled rate that gives ONP 2.9% of Labor
# preferences (actual 22.1%) and 4.5% of Coalition preferences (actual 54.0%).
FB_SMOOTH <- as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0"))
FLOW_SD   <- as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0"))
cat(sprintf("BS1f fallback_smooth %.2f | flow_sd %.2f\n", FB_SMOOTH, FLOW_SD))

sim <- simulate_seat_contests(shares, fm, party_sd = psd, seat_sd = sp$sd_within * SEAT_SD_MULT,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED,
                              shrink = SHRINK, party_cor = PARTY_COR,
                              fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD)
wp <- as.data.table(sim$win_prob)

pa <- merge(data.table(seat = keep, actual = unname(truth)),
            wp[, .(seat, party, prob)],
            by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
pa[is.na(prob), prob := 0]
pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
res <- merge(pa, pr, by = "seat")
stopifnot(nrow(res) == length(keep))
res[, pair := "sa2026"]

z <- data.frame(y = as.integer(res$pred == res$actual),
                lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
sl <- if (length(unique(z$y)) > 1)
  stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
cat(sprintf("\nBS2  accuracy %d/%d (%.1f%%) | Brier %.4f | log %.4f | slope %.3f\n",
            sum(res$pred == res$actual), nrow(res),
            100 * mean(res$pred == res$actual), mean((1 - res$prob)^2),
            -mean(log(pmax(res$prob, eps))), sl))

# The question this election exists to answer.
cat("\nBS3  ONE NATION, the reason this pair is worth 47 seats\n")
onp_true <- res[actual == "ONP"]
cat(sprintf("BS3  seats One Nation actually won: %d | our mean probability there: %.3f\n",
            nrow(onp_true), if (nrow(onp_true)) mean(onp_true$prob) else NA_real_))
if (nrow(onp_true)) {
  print(onp_true[, .(seat, we_said = pred, our_p = round(pred_p, 3),
                     gave_ONP = round(prob, 3))][order(-gave_ONP)])
}
onp_pred <- res[pred == "ONP"]
cat(sprintf("BS3  seats we called for One Nation: %d\n", nrow(onp_pred)))
exp_onp <- wp[party == "ONP", sum(prob)]
cat(sprintf("BS3  expected One Nation seats across the simulation: %.1f (actual 4)\n",
            exp_onp))

cat("\nBS4  misses, worst first\n")
print(head(res[pred != actual][order(prob),
                               .(seat, we_said = pred, our_p = round(pred_p, 3),
                                 actual, gave_winner = round(prob, 3))], 10))
fwrite(res, file.path("output", sprintf("backtest-sa%s.csv", CAL_TAG)))

# RETAIN THE FULL PER-SEAT PER-PARTY PROBABILITY TABLE.
#
# `res` above keeps only two rows' worth of information per seat -- the
# predicted winner and the actual winner -- so the probabilities for every
# other party are computed and thrown away. That is why a printed comparison
# does not sum to 1, and why "did we give anyone else a chance?" could not be
# answered without a fresh 25-minute run.
#
# Same shape as the seat-TCP finding earlier today: the quantity exists in
# memory and is discarded at the last step. docs/NEXT-STEPS.md records the
# federal version of this ("The full per-seat per-party probability table is
# never saved").
full <- merge(wp[, .(seat, party, prob)],
              data.table(seat = names(truth), actual = unname(truth)),
              by = "seat", all.x = TRUE)
full[, is_actual := party == actual]
setorder(full, seat, -prob)
fwrite(full, file.path("output", sprintf("backtest-sa-allprobs%s.csv", CAL_TAG)))
cat(sprintf("BS5  wrote the full probability table: %d rows, %d seats, %d parties\n",
            nrow(full), uniqueN(full$seat), uniqueN(full$party)))
# A seat's probabilities must sum to 1. If they do not, the simulation dropped
# a draw somewhere and every number above is suspect.
chk <- full[, .(s = sum(prob)), by = seat]
if (any(abs(chk$s - 1) > 0.01)) {
  stop("Per-seat probabilities do not sum to 1 in ",
       sum(abs(chk$s - 1) > 0.01), " seat(s); worst ",
       round(max(abs(chk$s - 1)), 4))
}
cat("BS5  every seat's probabilities sum to 1 (max deviation checked)\n")
fwrite(data.table(pair = "sa2026", as.data.table(sim$totals)), file.path("output", sprintf("backtest-sa-totals%s.csv", CAL_TAG)))

# NAME THE FILE ACTUALLY WRITTEN. This line was a hardcoded string and printed
# "backtest-sa.csv" for every arm, including arms that correctly wrote a tagged
# name. The tag mechanism exists because an untagged arm once overwrote the
# baseline it was being compared against; a log line that reports the untagged
# name recreates that confusion at the point where someone reads the result.
cat(sprintf("\nBS5  wrote output/backtest-sa%s.csv and its totals\n", CAL_TAG))
