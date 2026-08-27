# Backtest the candidate-level seat model on NSW 2023.
#
# Against docs/plans/prereg-candidate-model-backtest.md (redesigned section),
# committed before this ran. The decision rule and refusals C1-C6 are there.
#
# THE MODEL THAT PUBLISHES EVERY SEAT NUMBER HAS NEVER BEEN SCORED. The
# calibration this repo has -- slope 1.113, Brier 0.0583 -- scores the two-party
# model, which is now a cross-check only.
#
# Nothing here is fitted on NSW 2023:
#   predictors and margins   load_seats(2023, "nsw")  -- the pre-election file
#   seat primaries to swing  nswec-2019-nsw-firstprefs.csv
#   transfer matrix          nsw2019 transfers ONLY, asserted below
#   truth                    nswec-2023-nsw-firstprefs.csv, cross-checked
#
# What this does NOT test: the Victoria-specific One Nation allocation (order by
# Greens share, magnitudes quantile-mapped onto SA). NSW One Nation has a real
# 2019 base to swing from -- 1.10% statewide -- so it is swung like every other
# party. That allocation needs its own test and does not get one here.
#
# Emits BT* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# LEVEL-DEPENDENT SEAT VARIANCE, off by default. AUSPOL_LEVEL_SD="1.10,8.67"
# makes the per-seat deviation sd = a + b*sqrt(p(1-p)) instead of a flat
# seat_sd. Pre-registered in docs/plans/prereg-level-dependent-variance.md;
# unset reproduces the published model exactly.
.level_sd <- local({
  # ADOPTED 2026-08-27. Default ON at the fitted values; AUSPOL_LEVEL_SD="off"
  # reproduces the flat seat_sd exactly. See
  # docs/reviews/level-variance-2026-08-27.md -- federal seats called 99%+ and
  # LOST fall from 23 to 12 over 886 seat-elections, and Brier and log loss
  # improve in every subset on both federal and NSW.
  raw <- Sys.getenv("AUSPOL_LEVEL_SD", "1.10,8.67")
  if (identical(tolower(raw), "off") || !nzchar(raw)) NULL else {
    v <- suppressWarnings(as.numeric(strsplit(raw, ",")[[1]]))
    if (length(v) != 2L || !all(is.finite(v)))
      stop("AUSPOL_LEVEL_SD must be two finite numbers, e.g. 1.10,8.67")
    v
  }
})
cat(sprintf("LV1  level_sd: %s
", if (is.null(.level_sd)) "OFF (flat seat_sd)" else
            sprintf("a=%.2f b=%.2f", .level_sd[1], .level_sd[2])))


# ---- no other jurisdiction's flows reach New South Wales --------------------
# There WAS a Queensland gate here. It was defined and never called, while the
# harness still wrote its output under a "-qld" filename -- so an arm run with
# Queensland on came out byte-identical to the baseline and would have read as
# "Queensland makes no difference to New South Wales" rather than "Queensland
# was never added". That is the same shape as the four identical-output
# incidents CLAUDE.md records, so both the dead function and the misleading
# suffix are gone.
#
# Not calling it was CORRECT, and the reason is restated at the flow matrix
# below: NSW is optional preferential and roughly 12% of its ballots exhaust,
# while Queensland's and Western Australia's are full preferential and exhaust
# almost nothing. Pooling either into NSW estimates a rate describing neither,
# measured at 0.194 of log score worse. Refusal Q2 of prereg-qld-flows.md
# covered only the reverse direction; prereg-wa-flows.md is amended to say so.

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

# THE FLOW FIXES, PORTED. `fallback_smooth` and `flow_sd` were added to the
# South Australian harness on 2026-08-25 and existed NOWHERE ELSE, so setting
# them in the environment for a cross-harness comparison silently did nothing
# here -- an experiment that never ran, reading as an input that does not
# matter. That is the failure CLAUDE.md records under "A fix to one harness is
# a fix to ALL of them", and it recurred in the same session the rule was
# written. Both default to 0, which reproduces the previous behaviour exactly.
# INSURGENCY SURGE, against docs/plans/prereg-insurgency-surge.md. Wired here on
# 2026-08-26 after a four-arm comparison produced BYTE-IDENTICAL results for the
# surge arm and the do-nothing arm in this harness -- the "this input does not
# matter" signature. It was implemented in seat_sim.R and wired into the federal
# and WA harnesses only, so three of five harnesses compared the surge against
# itself. Third breach of the fix-everywhere rule in one day.
SURGE_H <- as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0"))
if (SURGE_H > 0)
  cat(sprintf("BS0s surge hazard %.4f, size N(15.6, 6.1), floor 2%%
", SURGE_H))
FB_SMOOTH <- as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0"))
FLOW_SD   <- as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0"))
cat(sprintf("BS1f fallback_smooth %.2f | flow_sd %.2f
", FB_SMOOTH, FLOW_SD))

# ARM FINGERPRINT. CAL_TAG names the parameters someone remembered to add, and
# twice now a new one was not: AUSPOL_LEVEL_SD and AUSPOL_DEV_SLOPE both wrote
# over another arm's per-seat output, silently, so a comparison read two copies
# of the same run. This appends a short hash of every AUSPOL_* variable that is
# set, so a NEW parameter cannot repeat that without anyone touching this line.
.arm_fingerprint <- local({
  e <- Sys.getenv()
  e <- e[grepl("^AUSPOL_", names(e)) & nzchar(e)]
  e <- e[!names(e) %in% c("AUSPOL_OUT_SUFFIX")]
  if (!length(e)) "" else {
    s <- paste(sort(paste0(names(e), "=", e)), collapse = ";")
    sprintf("-a%s", substr(tolower(paste0(as.hexmode(
      sum(utils::head(utf8ToInt(s), 4000) * seq_along(utils::head(utf8ToInt(s), 4000)))
    ))), 1, 6))
  }
})
CAL_TAG <- paste0(
  if (!is.null(.level_sd)) sprintf("-lv%s", gsub("[.]", "", paste(format(.level_sd, nsmall=2), collapse="_"))) else "",
  if (as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0")) > 0) "-surge" else "",
  # THE SIM COUNT MUST BE IN THE NAME. It reads Sys.getenv rather than N_SIMS
  # because CAL_TAG is built before N_SIMS is defined in this file. Without
  # this clause a 100-sim diagnostic run overwrote the 20000-sim baseline it
  # was meant to be checked against, which is the baseline-clobbering this tag
  # exists to prevent.
  if (as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000")) != 20000L)
    sprintf("-n%d", as.integer(Sys.getenv("AUSPOL_N_SIMS")))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_SHRINK", "0")) != 0)
    sprintf("-sh%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_SHRINK")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0")) != 0)
    sprintf("-el%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER")), nsmall = 1)))
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
  if (SEAT_SD_MULT != 1) sprintf("-m%s", format(SEAT_SD_MULT, nsmall = 1)) else "",
  if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")) "-port" else "",
  # "-corraw" and "-cor" are DIFFERENT correlation matrices. Both used to tag
  # "-cor", so running the raw arm and then the shrunk one wrote the second
  # over the first and a before/after comparison compared an arm with itself.
  if (!is.null(PARTY_COR))
    (if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "-corraw" else "-cor")
  else "",
  # No -qld or -wa suffix: neither is admissible here, so an arm carrying
  # one would be a filename promising a difference the run cannot make.
  "", .arm_fingerprint)

# READ FROM THE ENVIRONMENT like the other three harnesses. This was hardcoded
# to 20000 while backtest_candidate_sa.R, _vic.R and _fed.R all read
# AUSPOL_N_SIMS, so setting that variable for a cross-harness comparison ran
# NSW at 20000 and everything else at whatever was asked for. Two consequences,
# both seen on 2026-08-25:
#
#   - A "paired comparison at 5000 sims" across the four harnesses was not
#     paired. NSW alone ran at 4x the sims.
#   - Asking for 100 sims to make a quick diagnostic run returned metrics
#     IDENTICAL to four decimal places -- accuracy 71/88, Brier 0.1455, slope
#     0.568 -- because the request did nothing. That is the byte-identical
#     output that reads as "this input does not matter", which CLAUDE.md
#     already records once. It is also why every NSW arm was being killed: at
#     20000 sims over 88 independent-heavy seats with per-draw flow noise, a
#     single arm does not finish.
#
# The default is unchanged at 20000, so nothing downstream moves.
N_SIMS <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))
cat(sprintf("NB0  n_sims %d\n", N_SIMS))
SEED   <- 42
SMOOTH <- 0.15
PREF   <- election_data_path()

fp19 <- fread(file.path(PREF, "nswec-2019-nsw-firstprefs.csv"))
fp23 <- fread(file.path(PREF, "nswec-2023-nsw-firstprefs.csv"))
tx   <- fread(file.path(PREF, "nswec-nsw-transfers.csv"))

# LEAKAGE GUARD. The whole point of using NSW is that the flow matrix predates
# the election being scored. Asserted, not assumed -- three leaks have entered
# this repo before, one while fixing another.
# Asserted on the SOURCE, not on the filtered result. Checking that a table
# filtered to nsw2019 contains no nsw2023 rows is true by construction and
# proves only that `==` works -- the "guard that cannot fail" shape CLAUDE.md
# warns about, in the one place this script claims leakage safety.
stopifnot("the transfer file must contain both elections to be filterable" =
            all(c("nsw2019", "nsw2023") %in% tx$election))
tx19 <- tx[election == "nsw2019"]
stopifnot(nrow(tx19) > 0, nrow(tx19) < nrow(tx))
cat(sprintf("\nBT0  flow matrix from %d transfers, elections: %s\n",
            nrow(tx19), paste(unique(tx19$election), collapse = ", ")))
# NEW SOUTH WALES IS OPTIONAL PREFERENTIAL AND MUST NOT TAKE QUEENSLAND'S
# TRANSFERS. About 12% of NSW ballots exhaust; Queensland's are compulsory
# preferential and effectively none do, so pooling them estimates a rate that
# describes neither. CLAUDE.md states the rule and refusal Q2 of
# docs/plans/prereg-qld-flows.md covered only the reverse case -- Queensland's
# own pre-2016 optional-preferential elections.
#
# Measured before it was noticed: adding Queensland here made NSW 2023 WORSE by
# 0.194 of log score, the largest single degradation in the run. That is not a
# finding about Queensland, it is this mistake showing up as data.
fm <- build_flow_matrix(tx19, min_n = 3L)

seats <- as.data.table(load_seats(2023, "nsw"))

# Per-seat 2019 shares as a matrix.
w19 <- dcast(fp19, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(w19[, -1, with = FALSE]); rownames(mat) <- w19$seat
mat <- 100 * mat / rowSums(mat)

state19 <- fp19[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
state23 <- fp23[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
cat("\nBT1  statewide first preferences\n")
print(data.table(party = names(state19), y2019 = round(state19, 2),
                 y2023 = round(state23[names(state19)], 2),
                 swing = round(state23[names(state19)] - state19, 2))[order(-y2023)])

# TRUTH is the NSWEC's own declaration -- the candidate its distribution table
# marks ELECTED -- and NOT this package's exclusion of the actual votes.
#
# That distinction matters more than it looks. Deciding the winner by running
# real 2023 votes through distribute_preferences() would put the SAME flow
# matrix on both sides of the comparison, so any systematic flaw in it would
# cancel and the model would score better than it deserves. It is the leakage
# shape this repo keeps finding: a check that shares its error with the thing
# being checked.
win <- fread(file.path(PREF, "nswec-nsw-winners.csv"))[election == "nsw2023"]
stopifnot(nrow(win) == 93L)
truth <- setNames(win$winner, win$seat)
cat(sprintf("
BT2  truth from the NSWEC's ELECTED rows: %s
",
            paste(sprintf("%s %d", names(table(truth)), as.integer(table(truth))),
                  collapse = ", ")))

# Cross-check against the 2027 file's incumbent. NAT/LIB are recorded separately
# there and classify_party() maps both to LNP, so normalise before comparing --
# raw, eleven rural Coalition seats look like conflicts when both sources agree.
coal <- function(x) fifelse(x %in% c("NAT", "LIB", "LNP", "CLP"), "LNP", x)
inc27 <- as.data.table(load_seats(2027, "nsw"))[, .(seat, incumbent)]
chk <- merge(data.table(seat = names(truth), declared = unname(truth)), inc27, by = "seat")
chk[, `:=`(declared = coal(declared), incumbent = coal(incumbent))]
disagree <- chk[declared != incumbent]
cat(sprintf("BT2  cross-check against the 2027 incumbent: %d of %d differ
",
            nrow(disagree), nrow(chk)))
if (nrow(disagree)) {
  print(disagree)
  cat("BT2  differences are expected where a by-election has since changed hands;
")
  cat("BT2  the DECLARED 2023 result is truth and all 93 seats are scored.
")
}
keep <- names(truth)


# ---- project each seat's 2023 primaries: uniform swing off its 2019 share ----
parties <- colnames(mat)
shares <- mat
# STRONGHOLD ELASTICITY, against docs/plans/prereg-stronghold-elasticity.md.
# Default OFF. Criteria 1 and 3 require this arm on NSW and Victoria as well as
# SA before adoption.
ELASTIC   <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0"))
ELASTIC_D <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_FALL", "2"))
DEV_SLOPE <- dev_slopes_for(union(parties, names(state23)))
# ARM C: slopes conditional on whether the SAME candidate is standing again.
# A single per-class slope averages two populations that behave nothing alike --
# IND 0.907 when the person returns against 0.326 when they do not -- so it is
# wrong for every individual seat. Off unless AUSPOL_DEV_SLOPE_MODE=conditional.
.cond <- Sys.getenv("AUSPOL_DEV_SLOPE_MODE", "") %in% c("conditional", "screened")
.screened <- identical(Sys.getenv("AUSPOL_DEV_SLOPE_MODE", ""), "screened")
.returns <- if (.cond) candidate_returns("nsw2019", "nsw2023") else NULL
if (.cond) cat(sprintf("BN1c conditional slopes ON: %d of %d seat-classes have the same candidate returning
",
                       sum(.returns$same), nrow(.returns)))
# ARM CS: arm C plus the salience screen. Arm C alone was refused -- its harsh
# new-candidate slope (~0.33) is fitted on ~300 candidates who are overwhelmingly
# no-hopers, so it crushed the rare emergent toward the mean. The screen
# identifies that rare group (709 governed-silent candidates across five
# elections, zero winners) and protects anyone it permits by leaving them on
# uniform swing instead. See screened_slopes() and prereg-salience-screen.md.
.permit <- NULL
if (.screened) {
  sf <- file.path("output", "salience-v6.csv")
  if (!file.exists(sf)) stop("AUSPOL_DEV_SLOPE_MODE=screened needs output/salience-v6.csv")
  SAL <- fread(sf, showProgress = FALSE)[election == "nsw2023"]
  surging <- tryCatch(surging_parties("nsw", 2019L, 2023L, 5), error = function(e) character(0))
  rk <- paste(gsub("[^a-z0-9]", "", tolower(.returns$seat)), .returns$party)
  sk <- paste(gsub("[^a-z0-9]", "", tolower(SAL$seat)), SAL$party)
  ret <- .returns$same[match(sk, rk)]; ret[is.na(ret)] <- FALSE
  SAL[, governed := prev_party < 15 & !(party %in% surging) & !ret]
  SAL[, permit := salience_screen(jump, governed)]
  cat(sprintf("BN1s screen ON: registration %.0f%% | governed %d | permitted %d of governed\n",
              100 * salience_registration(SAL$jump), sum(SAL$governed),
              sum(SAL$permit[SAL$governed])))
  # KEYED BY SEAT + PARTY. simulate_seat_contests() reads shares by seat name
  # from `mat`, but the permit vector must be looked up for the CLASS being
  # projected in THIS loop iteration -- a stale merge here would apply another
  # party's screen decision to the wrong candidate.
  .permit <- SAL[, .(seat, party, permit)]
}
cat(sprintf("BN1d  dev slopes: %s%s
",
            if (all(DEV_SLOPE == 1)) "all 1.000 (uniform swing)" else
              paste(sprintf("%s=%.3f", names(DEV_SLOPE), DEV_SLOPE), collapse=" "),
            if (length(attr(DEV_SLOPE, "absent")))
              paste0(" | not contested here: ",
                     paste(attr(DEV_SLOPE, "absent"), collapse=",")) else ""))
pinned <- matrix(FALSE, nrow(mat), ncol(mat), dimnames = dimnames(mat))
for (p in parties) {
  if (!p %in% names(state23)) next
  d_state <- state23[[p]] - state19[[p]]
  sl <- if (.screened) {
    pv <- .permit[.permit$party == p, ]
    lut <- stats::setNames(as.logical(pv$permit), pv$seat)
    pm <- unname(lut[rownames(mat)]); pm[is.na(pm)] <- TRUE
    screened_slopes(p, rownames(mat), .returns, pm)
  } else if (.cond) conditional_slopes(p, rownames(mat), .returns) else DEV_SLOPE[[p]]
  val <- dev_slope(mat[, p], state19[[p]], state23[[p]], sl)
  if (ELASTIC > 0 && d_state < -ELASTIC_D && state19[[p]] > 0) {
    over <- mat[, p] / state19[[p]]
    hit <- is.finite(over) & over > ELASTIC
    if (any(hit)) {
      val[hit] <- pmax(0, mat[hit, p] * state23[[p]] / state19[[p]])
      pinned[hit, p] <- TRUE
    }
  }
  shares[, p] <- val
}
if (ELASTIC > 0) {
  cat(sprintf("NB1e elasticity ON (over %.2f, fall %.1f): %d cells\n",
              ELASTIC, ELASTIC_D, sum(pinned)))
}
# Constrained renormalisation -- a cut cell must not get back a share of the
# vote just removed from it.
if (ELASTIC > 0 && any(pinned)) {
  for (i in which(rowSums(pinned) > 0)) {
    keepc <- pinned[i, ]
    room <- 100 - sum(shares[i, keepc]); rest <- sum(shares[i, !keepc])
    if (rest > 0 && room > 0) shares[i, !keepc] <- shares[i, !keepc] * room / rest
  }
  oth <- which(rowSums(pinned) == 0)
  if (length(oth)) shares[oth, ] <- 100 * shares[oth, , drop = FALSE] / rowSums(shares[oth, , drop = FALSE])
} else {
  shares <- 100 * shares / rowSums(shares)
}

# ---- the seat-swing adjustment, ported from the two-party model -------------
# Against docs/plans/prereg-seat-swing-port-to-candidate.md. Applied as a
# transfer between the two majors in this seat, which is the mechanism the
# statewide anchoring already uses.
#
# The conversion is ONE-FOR-ONE and not a free parameter. A vote moved from the
# LNP primary to the ALP primary was an LNP first preference contributing 1 to
# the Coalition two-party total and is now an ALP first preference contributing
# 1 to Labor's, so shifting x points of primary shifts Labor's two-party share
# by exactly x. fit_seats_full.R already relies on this: its anchoring moves
# `d` points from LNP to ALP and then asserts the two-party mean equals the
# projection to within 0.3.
PORT <- identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")
if (PORT) {
  # `shares` is indexed by 2019 district names; the 2023 seat file uses the
  # post-redistribution ones, so five do not match. Those get an adjustment of
  # ZERO rather than being dropped -- dropping them would change which seats the
  # two arms are scored on and make the comparison meaningless.
  sa <- as.data.table(load_seats(2023, "nsw"))
  idx <- match(rownames(shares), sa$seat)
  adj <- rep(0, nrow(shares))
  adj[!is.na(idx)] <- seat_swing_adjustment(sa[idx[!is.na(idx)]])
  if (anyNA(idx)) {
    cat(sprintf("BT3c %d seats have no post-redistribution match and get no adjustment: %s
",
                sum(is.na(idx)), paste(rownames(shares)[is.na(idx)], collapse = ", ")))
  }
  # Re-centre: seat_swing_adjustment() centres over the seats it was given, and
  # zeroing five of them reintroduces a mean. An uncentred adjustment would
  # shift the whole forecast, which is what the centring exists to prevent.
  adj <- adj - mean(adj)
  stopifnot(all(is.finite(adj)))
  cat(sprintf("BT3c seat-swing port ON: adjustment mean %+.3f sd %.3f range %+.2f..%+.2f
",
              mean(adj), stats::sd(adj), min(adj), max(adj)))
  shares[, "ALP"] <- pmax(0, shares[, "ALP"] + adj)
  shares[, "LNP"] <- pmax(0, shares[, "LNP"] - adj)
  shares <- 100 * shares / rowSums(shares)
} else {
  cat("BT3c seat-swing port OFF (arm A)
")
}

sp <- seat_swing_spread(seats, unname(state23[["ALP"]] - state19[["ALP"]]))
cat(sprintf("\nBT3  seat spread: within %.2f, between %.2f\n", sp$sd_within, sp$sd_between))

set.seed(SEED)
# STATEWIDE UNCERTAINTY, MEASURED. All four harnesses hardcoded 1.5 with no
# derivation. The realised statewide first-preference error over 139
# party-cycles (33 independent cycles) is sd 2.33, so the harnesses were 1.6x
# over-confident BEFORE any seat-level modelling. That is upstream of `shrink`,
# which is a post-hoc patch for uncertainty that should have been present.
# fit_seats_full.R already uses a per-party state_sd and falls back to 1.5 only
# when it is NA. See docs/plans/prereg-party-sd-from-data.md.
PARTY_SD <- as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5"))
psd <- setNames(rep(PARTY_SD, length(parties)), parties)
cat(sprintf("BS1p party_sd %.2f (realised statewide sd is 2.33)
", PARTY_SD))
# THIS HARNESS HAS NEVER PASSED `shrink` -- the same defect fixed in the SA
# harness today. fit_seats_full.R publishes with 0.10; the default here is 0 so
# past runs stay comparable.
SHRINK <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0"))
sim <- simulate_seat_contests(level_sd = .level_sd, shares, fm, party_sd = psd, seat_sd = sp$sd_within * SEAT_SD_MULT,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED, party_cor = PARTY_COR,
                              shrink = SHRINK,
                              fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD,
                                surge_h = SURGE_H)
wp <- as.data.table(sim$win_prob)

sc <- merge(data.table(seat = names(truth), actual = unname(truth))[seat %in% keep],
            wp, by = "seat", all.x = TRUE, allow.cartesian = TRUE)
# A party absent from win_prob won zero draws; that is a real zero, not missing.
p_actual <- sc[party == actual, .(seat, p = prob)]
allseats <- data.table(seat = keep)
p_actual <- merge(allseats, p_actual, by = "seat", all.x = TRUE)
p_actual[is.na(p), p := 0]
pred <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
# COVERAGE, ASSERTED. This merge is an inner join, and the 2019 baseline matrix
# has no row for a seat that did not exist in 2019 -- the 2021 redistribution
# created five. Without this check the script prints "scored 88 seats" with
# nothing to compare it to, and every metric below is computed on 94.6% of the
# chamber with no note of which seats went or why.
res <- merge(p_actual, pred, by = "seat")
missing_seats <- setdiff(names(truth), res$seat)
if (length(missing_seats)) {
  cat(sprintf("BT3b %d of %d seats have no 2019 baseline and are NOT scored: %s
",
              length(missing_seats), length(truth),
              paste(sort(missing_seats), collapse = ", ")))
}
if (length(missing_seats) > 6L) {
  stop("Only ", nrow(res), " of ", length(truth), " seats could be scored. The ",
       "2021 redistribution accounts for five; more than that means the seat ",
       "names stopped matching, not that the chamber changed.")
}
res <- merge(res, data.table(seat = names(truth), actual = unname(truth)), by = "seat")

cat(sprintf("\nBT4  scored %d seats\n", nrow(res)))
cat(sprintf("BT4  winner accuracy: %d of %d (%.1f%%)\n",
            sum(res$pred == res$actual), nrow(res),
            100 * mean(res$pred == res$actual)))
cat(sprintf("BT5  Brier (on the party that won): %.4f\n", mean((1 - res$p)^2)))
eps <- 1e-6
cat(sprintf("BT5  mean log score: %.4f  (worse = more confident misses)\n",
            -mean(log(pmax(res$p, eps)))))
cat(sprintf("BT5  seats where the winner got < 5%% from us: %d\n", sum(res$p < 0.05)))
z <- data.frame(y = as.integer(res$pred == res$actual),
                lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
if (length(unique(z$y)) > 1) {
  cat(sprintf("BT6  calibration slope on the argmax call: %.3f\n",
              stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]]))
}
res[, bin := cut(pred_p, c(0, .6, .7, .8, .9, .95, 1), include.lowest = TRUE)]
cat("BT6  reliability of the argmax call\n")
print(res[, .(n = .N, predicted = round(mean(pred_p), 3),
              observed = round(mean(pred == actual), 3)), by = bin][order(bin)])
cat("\nBT7  misses, worst first\n")
print(res[pred != actual][order(p)][, .(seat, we_said = pred,
                                        our_p = round(pred_p, 3),
                                        actual, p_we_gave_it = round(p, 3))])
# How much of the damage is independents? NSW 2023 elected NINE, and this
# model can barely elect any -- a defect already recorded but never costed.
cat("
BT8  with and without the seats an independent won
")
for (lab in c("all seats", "excluding IND wins")) {
  d <- if (lab == "all seats") res else res[actual != "IND"]
  z2 <- data.frame(y = as.integer(d$pred == d$actual),
                   lo = stats::qlogis(pmin(pmax(d$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z2$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z2, family = stats::binomial()))[["lo"]] else NA_real_
  cat(sprintf("     %-20s n %2d | accuracy %.1f%% | Brier %.4f | slope %s
",
              lab, nrow(d), 100 * mean(d$pred == d$actual),
              mean((1 - d$p)^2),
              if (is.finite(sl)) sprintf("%.3f", sl) else "n/a"))
}
cat(sprintf("BT8  independents won %d of %d scored seats; we gave them a mean %.3f
",
            sum(res$actual == "IND"), nrow(res),
            mean(res[actual == "IND", p])))

fwrite(res[order(seat)], file.path("output", sprintf("backtest-nsw2023%s.csv", CAL_TAG)))
fwrite(data.table(pair = "nsw2023", as.data.table(sim$totals)), file.path("output", sprintf("backtest-nsw2023-totals%s.csv", CAL_TAG)))
# NAME THE FILE ACTUALLY WRITTEN, not the untagged name. Same fix as in
# backtest_candidate_sa.R: a hardcoded filename in the log defeats the tag that
# exists to stop an arm overwriting the baseline it is compared against.
cat(sprintf("\nWrote output/backtest-nsw2023%s.csv and its totals\n", CAL_TAG))
