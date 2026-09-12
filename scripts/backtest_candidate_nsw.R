# Backtest the candidate-level seat model on New South Wales.
#
# Against docs/plans/prereg-candidate-model-backtest.md (redesigned section),
# committed before this ran. The decision rule and refusals C1-C6 are there.
#
# TWO PAIRS since 2026-09-07, selected with AUSPOL_NSW_PAIR (default "2023"):
#
#   pair    scores    from      seat file    flows
#   2023    nsw2023   nsw2019   2023nsw.txt  nsw2019
#   2019    nsw2019   nsw2015   2019nsw.txt  nsw2015
#
# The 2019 pair became scoreable when the nsw2015 preference distributions were
# fetched. Before that the target was a literal in seventeen places.
#
# Nothing here is fitted on the election being scored. For either pair:
#   predictors and margins   the pre-election seat file for the target year
#   seat primaries to swing  the PREVIOUS election's first preferences
#   transfer matrix          the PREVIOUS election's transfers only, asserted
#   truth                    the NSWEC's own ELECTED rows, cross-checked
#
# What this does NOT test: the Victoria-specific One Nation allocation (order by
# Greens share, magnitudes quantile-mapped onto SA). NSW One Nation has a real
# base to swing from -- 1.10% statewide in 2019 -- so it is swung like every
# other party. That allocation needs its own test and does not get one here.
#
# Emits BT* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
# NSW-SCOPED DEFAULT, not a published_flags.R change. Arm C (salience point
# estimate + variance, docs/plans/prereg-salience-expected-and-variance-
# 2026-09-07.md) was measured 2026-09-09 across all five harnesses with a
# salience corpus: federal and NSW both improve, Queensland/SA/Victoria all
# get WORSE, SA and Victoria beyond the pre-registration's own 0.01
# per-jurisdiction refusal bound. Victoria is the LIVE TARGET, so this is
# NOT set in published_flags.R. Defaults ON here and in
# backtest_candidate_fed.R only, before published_flags.R's own registry
# runs, so an explicit caller override (either direction) still works.
# docs/reviews/salience-arm-federal-nsw-scoped-2026-09-09.md has the full
# jurisdiction table.
if (!nzchar(Sys.getenv("AUSPOL_SALIENCE_EXPECTED", ""))) Sys.setenv(AUSPOL_SALIENCE_EXPECTED = "1")
if (!nzchar(Sys.getenv("AUSPOL_SALIENCE_EXP_SD", ""))) Sys.setenv(AUSPOL_SALIENCE_EXP_SD = "1")
source("scripts/harness_defaults.R")  # published defaults for every unset AUSPOL_* switch; see that file
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

# PER-CLASS SLOPE MULTIPLIER, both 1 by default so this is a no-op until an arm
# sets it. AUSPOL_LEVEL_MULT_IND and AUSPOL_LEVEL_MULT_OTH scale level_sd's
# slope for independents and for every other non-major; majors are never
# touched. Pre-registered in docs/plans/prereg-class-specific-variance.md.
#
# WHY IT EXISTS. level_sd above ships ONE curve for every party, and the review
# that adopted it measured that the seats it fixed were not the seats it
# widened: on NSW the calibration slope went 0.565 -> 0.720 across all seats but
# 0.959 -> 1.272 EXCLUDING seats an independent won. The majors were already
# almost right and got widened past 1 anyway.
.level_mult <- local({
  g <- function(v) {
    x <- suppressWarnings(as.numeric(Sys.getenv(v, "1")))
    if (!is.finite(x) || x < 0) stop(v, " must be a finite, non-negative number")
    x
  }
  c(ind = g("AUSPOL_LEVEL_MULT_IND"), oth = g("AUSPOL_LEVEL_MULT_OTH"))
})
# Printed unconditionally, including when it is off. An arm that silently did
# not apply is indistinguishable from an arm that made no difference -- the
# failure CLAUDE.md records under "an experiment that never ran".
cat(sprintf("LV2  level_mult: %s
",
            if (all(.level_mult == 1)) "OFF (one curve for every class)" else
              sprintf("IND x%.2f, other non-major x%.2f",
                      .level_mult[["ind"]], .level_mult[["oth"]])))
# Built per call site from that seat file's own columns, because
# simulate_seat_contests() rejects a name that is not a share column.
.lm <- function(sh) level_mult_for(colnames(sh), .level_mult[["ind"]],
                                   .level_mult[["oth"]])


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
if (!is.finite(SEAT_SD_MULT) || SEAT_SD_MULT <= 0)
  stop("AUSPOL_SEAT_SD_MULT must be a positive number; got ", SEAT_SD_MULT)
# PORTED FROM THE FEDERAL HARNESS 2026-09-06: simulate_seat_contests() computes
# sd_cell from `level_sd` and IGNORES seat_sd whenever level_sd is given, and
# level_sd is on by default, so `seat_sd * SEAT_SD_MULT` at the call site was
# inert here while this printed "applied". The multiplier now scales whichever
# spread is actually in force, and the message says which.
if (SEAT_SD_MULT != 1) {
  if (is.null(.level_sd)) {
    cat(sprintf("CAL  seat_sd multiplier %.2f applied (flat seat_sd path)
", SEAT_SD_MULT))
  } else {
    .level_sd <- .level_sd * SEAT_SD_MULT
    cat(sprintf("CAL  spread multiplier %.2f applied to LEVEL_SD -> a=%.3f b=%.3f (seat_sd is inert here)
",
                SEAT_SD_MULT, .level_sd[1], .level_sd[2]))
  }
}

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
# THE MATRIX IS CHOSEN PER TARGET, and the target is not known yet -- this
# harness picks its pair further down. So only the MODE is read here and the
# matrix itself is fetched beside the pair, by statewide_cor(). Until
# 2026-09-07 every harness read one all-pairs correlation and scored against
# it, including the pairs that were in the fit, so an election was correlated
# using its own statewide swing. See
# docs/plans/prereg-statewide-cov-loo-2026-09-07.md.
PARTY_COR <- NULL

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
SHRINK_K  <- as.numeric(Sys.getenv("AUSPOL_FLOW_SHRINK_K", "0"))    # EXPERIMENTAL, docs/plans/prereg-flow-cell-shrinkage-2026-09-10.md
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
  # KEYED ON THE SWITCH, NOT ON THE MATRIX. PARTY_COR is now fetched per
  # target, which happens AFTER this tag is built, so testing the matrix
  # here silently dropped "-cor" from every filename while the run still
  # used a correlation -- a file whose name says one arm and whose
  # contents are another, which is the fingerprint failure this tag exists
  # to prevent.
  if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", "")))
    (if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "-corraw" else "-cor")
  else "",
  # No -qld or -wa suffix: neither is admissible here, so an arm carrying
  # one would be a filename promising a difference the run cannot make.
  "", .arm_fingerprint, .code_tag)

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
# READ FROM THE ENVIRONMENT, like the federal harness. AUSPOL_SEED is in
# scripts/published_flags.R, and until 2026-09-07 this harness hardcoded 42
# and ignored it -- so a reseed run to measure the noise floor returned
# byte-identical output, and the only tell was that it was TOO identical.
SEED   <- as.integer(Sys.getenv("AUSPOL_SEED", "42"))
# Arm B default: NULL, so a bare run is byte-identical.
SD_OVR <- NULL
SMOOTH <- 0.15
PREF   <- election_data_path()

# WHICH PAIR THIS RUN SCORES. Until 2026-09-07 the target election was written
# out as a literal in seventeen places and only nsw2023 could be run. The
# nsw2015 preference distributions were fetched that day, which makes
# nsw2015 -> nsw2019 scoreable on flows that predate it, and NSW goes from one
# pair to two.
#
# `next_seats` is the seat file used ONLY for the winner cross-check below. It
# is the election AFTER the one being scored, because that file's `incumbent`
# is who holds the seat now. CLAUDE.md records that this field is contaminated
# by by-elections and carries the anchor's party classes rather than ours, so
# it is a printed disagreement count and never the truth.
NSW_PAIRS <- list(
  "2019" = list(to = 2019L, from = 2015L, next_seats = 2023L),
  "2023" = list(to = 2023L, from = 2019L, next_seats = 2027L))
.k <- Sys.getenv("AUSPOL_NSW_PAIR", "2023")
if (!.k %in% names(NSW_PAIRS)) {
  stop("AUSPOL_NSW_PAIR must be one of ", paste(names(NSW_PAIRS), collapse = ", "),
       " and was ", sQuote(.k))
}
PAIR <- NSW_PAIRS[[.k]]
TO   <- PAIR$to
FROM <- PAIR$from
TGT  <- sprintf("nsw%d", TO)
PRV  <- sprintf("nsw%d", FROM)
cat(sprintf("BT0p pair %s -> %s | flows from %s | seat file %dnsw.txt
",
            PRV, TGT, PRV, TO))

# The correlation matrix for THIS target. The source is printed because a
# silent fallback is the failure this repo keeps finding: a run using a
# different input from the one its log implies.
if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", ""))) {
  PARTY_COR <- statewide_cor(TGT,
                             mode = if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "raw" else "shrunk")
  cat(sprintf("COV  party correlation ON (%s): cor(ONP,LNP) = %+.2f | %s\n",
              Sys.getenv("AUSPOL_PARTY_COR"), PARTY_COR["ONP", "LNP"],
              attr(PARTY_COR, "cor_source")))
}




fp_prev <- fread(file.path(PREF, sprintf("nswec-%d-nsw-firstprefs.csv", FROM)))
fp_tgt  <- fread(file.path(PREF, sprintf("nswec-%d-nsw-firstprefs.csv", TO)))
tx      <- fread(file.path(PREF, "nswec-nsw-transfers.csv"))

# LEAKAGE GUARD. The whole point of using NSW is that the flow matrix predates
# the election being scored. Asserted, not assumed -- three leaks have entered
# this repo before, one while fixing another.
# Asserted on the SOURCE, not on the filtered result. Checking that a table
# filtered to nsw2019 contains no nsw2023 rows is true by construction and
# proves only that `==` works -- the "guard that cannot fail" shape CLAUDE.md
# warns about, in the one place this script claims leakage safety.
stopifnot("the transfer file must contain both elections to be filterable" =
            all(c(PRV, TGT) %in% tx$election))
# PRV_ not PRV inside the brackets: `election` is a column of tx, and a bare
# symbol on either side of `==` there binds to the column. That is this repo's
# most-repeated fault, eight times recorded.
PRV_ <- PRV
tx_prev <- tx[election == PRV_]
stopifnot(nrow(tx_prev) > 0, nrow(tx_prev) < nrow(tx))
cat(sprintf("\nBT0  flow matrix from %d transfers, elections: %s\n",
            nrow(tx_prev), paste(unique(tx_prev$election), collapse = ", ")))
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
fm <- build_flow_matrix(tx_prev, min_n = 3L)

seats <- as.data.table(load_seats(TO, "nsw"))

# Per-seat 2019 shares as a matrix.
w_prev <- dcast(fp_prev, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(w_prev[, -1, with = FALSE]); rownames(mat) <- w_prev$seat
mat <- 100 * mat / rowSums(mat)

state_prev <- fp_prev[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
state_tgt <- fp_tgt[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
# RE-ENTRY PRIOR, docs/plans/prereg-reentry-prior-2026-09-07.md. A class
# contesting this seat but not the last one has no prior share, so swinging
# zero forward leaves approximately zero -- 1,418 seat-class rows across the
# corpus, costing 5.27 points of mean absolute error against 3.25 for the
# model. Kimberley 2001 is the case: Labor did not stand there in 1996,
# Carol Martin won it with 42.2%, and the model projected 2.1%.
REENTRY_CELLS <- attr(reentry_apply_harness(mat, fp_prev, fp_tgt, state_tgt,
                             target = TGT, pairs = all_election_pairs(),
                             code = "BT1r"),
                      "reentry")
cat("\nBT1  statewide first preferences\n")
# Column names carry the ACTUAL years. They were the literals y2019 and y2023,
# which on the 2019 pair labelled nsw2015 figures as 2019 and nsw2019 figures
# as 2023 -- a printed table that is wrong in a way nothing downstream can
# catch.
.bt1 <- data.table(party = names(state_prev), prev = round(state_prev, 2),
                   now = round(state_tgt[names(state_prev)], 2),
                   swing = round(state_tgt[names(state_prev)] - state_prev, 2))
setnames(.bt1, c("prev", "now"), sprintf("y%d", c(FROM, TO)))
print(.bt1[order(-get(sprintf("y%d", TO)))])

# TRUTH is the NSWEC's own declaration -- the candidate its distribution table
# marks ELECTED -- and NOT this package's exclusion of the actual votes.
#
# That distinction matters more than it looks. Deciding the winner by running
# real 2023 votes through distribute_preferences() would put the SAME flow
# matrix on both sides of the comparison, so any systematic flaw in it would
# cancel and the model would score better than it deserves. It is the leakage
# shape this repo keeps finding: a check that shares its error with the thing
# being checked.
TGT_ <- TGT
win <- fread(file.path(PREF, "nswec-nsw-winners.csv"))[election == TGT_]
stopifnot(nrow(win) == 93L)
truth <- setNames(win$winner, win$seat)
cat(sprintf("
BT2  truth from the NSWEC's ELECTED rows: %s
",
            paste(sprintf("%s %d", names(table(truth)), as.integer(table(truth))),
                  collapse = ", ")))

# Cross-check against the NEXT election's seat file, whose `incumbent` is who
# holds the seat now. NAT/LIB are recorded separately there and
# classify_party() maps both to LNP, so normalise before comparing --
# raw, eleven rural Coalition seats look like conflicts when both sources agree.
coal <- function(x) fifelse(x %in% c("NAT", "LIB", "LNP", "CLP"), "LNP", x)
inc_next <- as.data.table(load_seats(PAIR$next_seats, "nsw"))[, .(seat, incumbent)]
chk <- merge(data.table(seat = names(truth), declared = unname(truth)), inc_next, by = "seat")
chk[, `:=`(declared = coal(declared), incumbent = coal(incumbent))]
disagree <- chk[declared != incumbent]
cat(sprintf("BT2  cross-check against the %d incumbent file: %d of %d differ
",
            PAIR$next_seats, nrow(disagree), nrow(chk)))
if (nrow(disagree)) {
  print(disagree)
  cat("BT2  differences are expected where a by-election has since changed hands;
")
  cat("BT2  the DECLARED result is truth and all 93 seats are scored.
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
DEV_SLOPE <- dev_slopes_for(union(parties, names(state_tgt)))
# ARM C: slopes conditional on whether the SAME candidate is standing again.
# A single per-class slope averages two populations that behave nothing alike --
# IND 0.907 when the person returns against 0.326 when they do not -- so it is
# wrong for every individual seat. Off unless AUSPOL_DEV_SLOPE_MODE=conditional.
.cond <- Sys.getenv("AUSPOL_DEV_SLOPE_MODE", "") %in% c("conditional", "screened")
.screened <- identical(Sys.getenv("AUSPOL_DEV_SLOPE_MODE", ""), "screened")
.returns <- if (.cond) candidate_returns(PRV, TGT) else NULL
if (.cond) cat(sprintf("BN1c conditional slopes ON: %d of %d seat-classes have the same candidate returning
",
                       sum(.returns$same), nrow(.returns)))
# PORTED FROM THE FEDERAL HARNESS 2026-09-05, per this repo's rule that a fix
# to one harness is a fix to all of them. Both default OFF, so the default path
# is byte-identical until an arm sets them.
#   AUSPOL_MP_SLOPE        -- returning MEMBER (0.954) vs returning also-ran
#                             (0.800); the shipped slope pooled them at 0.907.
#   AUSPOL_DEFECT_DISCOUNT -- the measured form of the very exclusion the
#                             comment below argues for: a sitting major-party
#                             member re-contesting under a non-major label
#                             brings 0.282 of their major vote, ADDED to that
#                             class's base rather than replacing it. Fitted
#                             federally; MacKillop (62.3 -> 14.8) is the case
#                             that sets the discount low.
.MP_SLOPE <- NULL
if (identical(Sys.getenv("AUSPOL_MP_SLOPE", "0"), "1")) {
  # Values are READ FROM DISK, per target election, never hard-coded. The first
  # version of this tier carried c(IND = 0.954, OTH_RIGHT = 0.954, GRN = 0.994,
  # ONP = 0.610) from an uncommitted fit that had seen the elections it was then
  # scored on. Refitted leave-one-election-out (scripts/fit_mp_slope.R) the tier
  # is real -- the member/also-ran gap is positive in 18 of 18 folds -- but three
  # of those four numbers were wrong, and ONP's was the also-ran slope written
  # into the member row over ZERO member observations.
  .mpf <- "output/mp-slope-by-target.csv"
  if (!file.exists(.mpf))
    stop("AUSPOL_MP_SLOPE=1 needs ", .mpf, " -- run scripts/fit_mp_slope.R")
  .mpt <- data.table::fread(.mpf, showProgress = FALSE)
  .tgt <- TGT                       # copied to a differently-named local: a bare
  .row <- .mpt[.mpt$target == .tgt & is.finite(.mpt$member), ]  # `target` inside
  if (!nrow(.row))                                              # `[` would bind
    stop("no leave-one-out MP slopes for ", .tgt, " in ", .mpf) # to the column
  if (!identical(Sys.getenv("AUSPOL_MP_SLOPE_GRN", "0"), "1"))
    .row <- .row[.row$party != "GRN", ]   # GRN's member/also-ran gap is ~0
  .MP_SLOPE <- stats::setNames(as.numeric(.row$member), .row$party)
}
cat(sprintf("BT1m  MP tier: %s
",
            if (is.null(.MP_SLOPE)) "OFF" else
              paste(sprintf("%s=%.4f", names(.MP_SLOPE), .MP_SLOPE), collapse = " ")))
# PORTED to fit_defector_discount() 2026-09-09 -- was a frozen 0.282 snapshot
# of one federal-only run; now pooled across all six jurisdictions, refit
# leave-this-target-out. See R/candidate_returns.R's docs.
.defect <- NULL
if (identical(Sys.getenv("AUSPOL_DEFECT_DISCOUNT", "0"), "1")) {
  .fd <- tryCatch(fit_defector_discount(TGT), error = function(e) {
  cat(sprintf("BN0d! defector-discount fit FAILED, no discount applied: %s
",
              conditionMessage(e)))
  list(discount = NULL, discount_mp = NULL, discount_loser = NULL, n = 0L)
})
  if (is.null(.fd$discount)) {
    cat(sprintf("BN0d! only %d defector case(s) (need >=5); no discount applied\n", .fd$n))
  } else {
    cat(sprintf("BN0d defector discount %.3f from %d cases (target excluded, pooled all jurisdictions)\n",
                .fd$discount, .fd$n))
    .defect <- .fd$discount
  }
}
# THE BASE VALUE, not just the slope -- see personal_prior_vote()'s docs.
# Philip Donato (Orange), Helen Dalton (Murray) and Roy Butler (Barwon) are
# sitting members who switched from Shooters-Fishers-Farmers to Independent
# between nsw2019 and nsw2023. candidate_returns() correctly flags them as
# the same returning person, but the slope that fact selects still
# multiplied the IND class's seat-level prior vote -- 0% in every one of
# these seats, since none of them were registered IND in 2019.
# Gareth Ward (Kiama, Liberal -> Independent) is NOT covered here --
# personal_prior_vote() deliberately excludes a prior MAJOR-party
# registration, since the one other example of that transition in this
# corpus (McBride, MacKillop, LNP 62.3% -> IND 14.8%) shows it can badly
# overestimate a defector who loses the party's machine, not just his own
# vote. This is what makes the base itself carry their real prior vote.
# SPLIT SLOPE (AUSPOL_SPLIT_SLOPE=1, default OFF -- unset reproduces this
# harness byte-for-byte). Gives the returning and departed portions of a
# class's prior vote their own fitted slope instead of one slope chosen by
# a binary flag. docs/plans/prereg-partial-return-split-slope-2026-09-09.md
# FITTED CONDITIONAL SLOPES (AUSPOL_FIT_SLOPES=1, default OFF). Replaces the
# eight hardcoded same/new constants with a leave-this-target-out fit;
# structure untouched. docs/plans/prereg-fit-conditional-slopes-2026-09-09.md
.fitsl <- if (identical(Sys.getenv("AUSPOL_DISPERSION_SLOPE", "0"), "1")) {
  fit_dispersion_slopes(TGT)
} else if (identical(Sys.getenv("AUSPOL_FIT_SLOPES", "0"), "1")) {
  fit_conditional_slopes(TGT)
} else NULL
if (!is.null(.fitsl)) cat(sprintf("FS1  fitted slopes | same %s | new %s
",
  paste(sprintf("%s=%.3f", names(.fitsl$same), .fitsl$same), collapse=" "),
  paste(sprintf("%s=%.3f", names(.fitsl$new),  .fitsl$new),  collapse=" ")))
.split <- split_slope_context(PRV, TGT)
.own_prev <- if (.cond) tryCatch(personal_prior_vote(PRV, TGT, major_discount = .defect), error = function(e) { cat(sprintf("BT1p! personal_prior_vote() FAILED; class-level bases kept and NO transfer removed: %s\n", conditionMessage(e))); NULL }) else NULL
mat <- remove_transferred_votes(mat, .own_prev)  # the vote moves with the person; see personal_prior_vote()
.tr <- attr(mat, "transfers"); if (!is.null(.tr)) cat(sprintf("TR1  transfers moved with the person: %d applied%s\n", .tr$applied, if (length(.tr$skipped)) paste0("; SKIPPED ", length(.tr$skipped), ": ", paste(utils::head(.tr$skipped, 5), collapse = ", ")) else ""))
.own_x <- function(p, seats, x) {
  if (is.null(.own_prev)) return(x)
  ov <- .own_prev[.own_prev$party == p, ]
  v <- stats::setNames(ov$own_prev_pcv, ov$seat)[seats]
  out <- x
  hit <- !is.na(v)
  out[hit] <- unname(v[hit])
  out
}
# ARM CS: arm C plus the salience screen. Arm C alone was refused -- its harsh
# new-candidate slope (~0.33) is fitted on ~300 candidates who are overwhelmingly
# no-hopers, so it crushed the rare emergent toward the mean. The screen
# identifies that rare group (709 governed-silent candidates across five
# elections, zero winners) and protects anyone it permits by leaving them on
# uniform swing instead. See screened_slopes() and prereg-salience-screen.md.
.permit <- if (.screened) salience_permit_for(TGT, PRV, "nsw") else NULL
cat(sprintf("BN1d  dev slopes: %s%s
",
            if (all(DEV_SLOPE == 1)) "all 1.000 (uniform swing)" else
              paste(sprintf("%s=%.3f", names(DEV_SLOPE), DEV_SLOPE), collapse=" "),
            if (length(attr(DEV_SLOPE, "absent")))
              paste0(" | not contested here: ",
                     paste(attr(DEV_SLOPE, "absent"), collapse=",")) else ""))
pinned <- matrix(FALSE, nrow(mat), ncol(mat), dimnames = dimnames(mat))
for (p in parties) {
  if (!p %in% names(state_tgt)) next
  d_state <- state_tgt[[p]] - state_prev[[p]]
  sl <- if (.screened) {
    pv <- .permit[.permit$party == p, ]
    lut <- stats::setNames(as.logical(pv$permit), pv$seat)
    pm <- unname(lut[rownames(mat)]); pm[is.na(pm)] <- TRUE
    screened_slopes(p, rownames(mat), .returns, pm, same_mp = .MP_SLOPE, same = if (is.null(.fitsl)) formals(screened_slopes)$same else .fitsl$same, new = if (is.null(.fitsl)) formals(screened_slopes)$new else .fitsl$new)
  } else if (.cond) conditional_slopes(p, rownames(mat), .returns, same_mp = .MP_SLOPE, same = if (is.null(.fitsl)) formals(conditional_slopes)$same else .fitsl$same, new = if (is.null(.fitsl)) formals(conditional_slopes)$new else .fitsl$new) else DEV_SLOPE[[p]]
  x_p <- .own_x(p, rownames(mat), mat[, p])
  val <- if (is.null(.split)) dev_slope(x_p, state_prev[[p]], state_tgt[[p]], sl) else
    split_dev_slope(x_p, .split$frac(p, rownames(mat)), state_prev[[p]], state_tgt[[p]], .split$s_ret, .split$s_dep)
  if (ELASTIC > 0 && d_state < -ELASTIC_D && state_prev[[p]] > 0) {
    over <- x_p / state_prev[[p]]
    hit <- is.finite(over) & over > ELASTIC
    if (any(hit)) {
      val[hit] <- pmax(0, x_p[hit] * state_tgt[[p]] / state_prev[[p]])
      pinned[hit, p] <- TRUE
    }
  }
  shares[, p] <- val
}
# Re-entry prior lands here, on the POST-SWING projection. See BT1r above.
# The prediction is a target-election share; filling it into the prior-election
# matrix let dev_slope() swing it a second time.
if (!is.null(REENTRY_CELLS) && nrow(REENTRY_CELLS)) {
  # PERSONAL-VOTE PRIORITY, docs/plans/prereg-reentry-personal-vote-priority-
  # 2026-09-08.md. Kiama (Gareth Ward, LNP -> IND) is the case this exists
  # for: .own_prev's identity-matched defector floor must not be overwritten
  # by the generic re-entry GLM, which has no idea who the candidate is.
  .rc <- protect_personal_vote_cells(REENTRY_CELLS, .own_prev)
  .ri <- cbind(match(.rc$seat,  rownames(shares)),
               match(.rc$party, colnames(shares)))
  .rk <- stats::complete.cases(.ri)
  shares[.ri[.rk, , drop = FALSE]] <- .rc$value[.rk]
  .protected <- nrow(REENTRY_CELLS) - nrow(.rc)
  cat(sprintf("BT1r  re-entry applied post-swing to %d cell(s)%s\n", sum(.rk),
              if (.protected) sprintf(" | %d protected by own_prev", .protected) else ""))
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

# ZERO IND WHEREVER NOBODY ACTUALLY STOOD AT THE TARGET ELECTION. Ported from
# backtest_candidate_fed.R (present there and in SA; missing here and in vic and
# WA). Which classes contest a seat is nomination data, knowable before polling
# day, unlike the vote share those classes go on to get.
#
# Without this, the model swings the PRIOR election's independent vote forward
# with no check that anyone recontested. Caught investigating why arm CS's
# 90-99% band got worse on NSW 2023: Dubbo carried Mathew Dickerson's 2019 IND
# vote (28.4%) forward into 2023, though he did not stand again and Saunders
# (LNP) won 54.3% unopposed by any independent. Both arms already called Dubbo
# wrong -- base at 87.1% confidence, a pre-existing bug this masked rather than
# caused. Arm C's harsh shrinkage of "new" candidates happened to dampen it
# by accident; the screen correctly stops shrinking an UNGOVERNED candidate
# (Dubbo's IND prior, 28.4%, is above the 15% governed threshold), which
# removed that accidental damping and pushed the wrong call to 93.6%.
#
# fp_tgt is this harness's analogue of fed's `fb`: the TARGET election's own
# first preferences, read only to answer "did anyone stand", not for vote share.
if ("IND" %in% colnames(shares)) {
  ind_seats <- fp_tgt[party == "IND" & votes > 0, unique(seat)]
  no_ind <- setdiff(rownames(shares), ind_seats)
  zeroed <- no_ind[shares[no_ind, "IND"] > 0]
  shares[no_ind, "IND"] <- 0
  if (length(zeroed)) {
    cat(sprintf("BT0  %s: zeroed IND in %d seat(s) with no independent nominated: %s\n",
                TGT, length(zeroed), paste(sort(zeroed), collapse = ", ")))
  }
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
  sa <- as.data.table(load_seats(TO, "nsw"))
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
shares <- xgb_primary_override(shares, TGT)

sp <- seat_swing_spread(seats, unname(state_tgt[["ALP"]] - state_prev[["ALP"]]))
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
# ARM SURGE-V2: see R/salience_surge.R and scripts/backtest_candidate_fed.R.
surge_arg <- SURGE_H; surge_mu_arg <- 15.6; surge_sd_arg <- 6.1
surge_party_arg <- NULL
if (identical(Sys.getenv("AUSPOL_SALIENCE_SURGE_V2", "0"), "1")) {
  v2_pairs <- list(
    list(election = "fed2010", prev = "fed2007", region = "fed"),
    list(election = "fed2013", prev = "fed2010", region = "fed"),
    list(election = "fed2016", prev = "fed2013", region = "fed"),
    list(election = "fed2019", prev = "fed2016", region = "fed"),
    list(election = "fed2022", prev = "fed2019", region = "fed"),
    list(election = "vic2022", prev = "vic2018", region = "vic"),
    list(election = TGT, prev = PRV, region = "nsw"),
    list(election = "sa2026",  prev = "sa2022",  region = "sa"),
    list(election = "wa2008",  prev = "wa2005",  region = "wa"))
  train_pairs <- Filter(function(p) p$election != TGT, v2_pairs)
  hz <- tryCatch(surge_hazard_for(TGT, PRV, "nsw", train_pairs),
                 error = function(e) { cat(sprintf("BN0v! surge-v2 failed: %s\n", conditionMessage(e))); NULL })
  if (!is.null(hz)) {
    sn <- rownames(shares)
    if (is.null(sn) && is.data.frame(shares)) sn <- as.character(shares$seat)
    v <- setNames(hz$seat_hazard$surge_h, hz$seat_hazard$seat)[sn]
    miss <- sum(is.na(v)); v[is.na(v)] <- 0
    surge_arg <- unname(v); surge_mu_arg <- hz$surge_mu; surge_sd_arg <- hz$surge_sd
    # THE SALIENCE POINT ESTIMATE, ported from the federal harness 2026-09-07.
    # This harness used the hazard for the DRAW only, so a governed candidate
    # with real salience kept a uniform-swing projection here while the same
    # candidate would have been blended federally.
    .exp_mode <- suppressWarnings(as.integer(Sys.getenv("AUSPOL_SALIENCE_EXPECTED", "0")))
    if (is.na(.exp_mode)) .exp_mode <- 0L
    shares <- blend_salience_shares(shares, hz, surge_mu_arg[1], expected = .exp_mode > 0L)
    # ARM B, docs/plans/prereg-salience-expected-and-variance-2026-09-07.md.
    # level_sd is binomial-shaped and gives a major on 30% MORE uncertainty
    # than a top-percentile insurgent on 13.9%; the salience band has
    # measured the latter at 12.6. exp_sd has existed since
    # surge_hazard_for() was written and was read by nothing. n_set is
    # printed because an override filling no cells is an arm that looks
    # like it ran and did not.
    if (identical(Sys.getenv("AUSPOL_SALIENCE_EXP_SD", "0"), "1")) {
      SD_OVR <- salience_sd_matrix(shares, hz)
      cat(sprintf("BT0d salience sd override: %d of %d cells set\n",
                  attr(SD_OVR, "n_set"), length(SD_OVR)))
    }
    cat(sprintf("BT0b salience point estimate applied to %d (seat,party) cells\n", attr(shares, "cells")))
    if (identical(Sys.getenv("AUSPOL_SURGE_RECIPIENT", "1"), "1") && !is.null(hz$seat_recipient)) {
      # THE SURGE GOES TO THE CLASS THE HAZARD WAS FITTED FOR (prereg-surge-recipient-2026-09-06.md).
      surge_party_arg <- unname(setNames(hz$seat_recipient$party, hz$seat_recipient$seat)[sn])
      cat(sprintf("SR1  surge recipient ON: %d of %d seats name a class (%s)\n", sum(!is.na(surge_party_arg)), length(sn),
                  paste(sprintf("%s=%d", names(table(surge_party_arg)), as.integer(table(surge_party_arg))), collapse = " ")))
    }
    # THE SCALE OF THE HAZARD (docs/plans/prereg-surge-hazard-scale-2026-09-06.md).
    # The ridge fit shrinks every seat toward the base rate, so the top-ranked
    # emergence seats carry 0.03-0.05; this multiplies before the blend and
    # the draw, capped at 1. Published value 1 until the sweep decides.
    .surge_scale <- as.numeric(Sys.getenv("AUSPOL_SURGE_SCALE", "1"))
    if (!is.finite(.surge_scale) || .surge_scale <= 0) stop("AUSPOL_SURGE_SCALE must be a positive number")
    if (.surge_scale != 1) {
      surge_arg <- pmin(1, surge_arg * .surge_scale)
      cat(sprintf("SC1  surge hazard x%.1f: mean %.4f, max %.4f, seats at the cap %d\n",
                  .surge_scale, mean(surge_arg), max(surge_arg), sum(surge_arg >= 1)))
    }
    cat(sprintf("BN0v %s: surge-v2 hazard for %d of %d seats (%d absent -> 0) | mean %.4f | mu %.2f sd %.2f | lambda %.1f | train winners %d\n",
                TGT, length(sn) - miss, length(sn), miss, mean(surge_arg),
                surge_mu_arg, surge_sd_arg, hz$lambda, hz$n_train_winners))
  }
}
  # ARM H, docs/plans/prereg-reentry-flatratio-variance-2026-09-08.md. Widens
  # the SIMULATED uncertainty, not the point estimate, for cells that fell
  # back to the flat re-entry ratio -- point-shrinkage was tried and refused
  # for these classes (docs/NEXT-STEPS.md 2026-09-08). Off by default
  # (AUSPOL_REENTRY_SD_K=0); combined with any salience sd_override by taking
  # the larger of the two, never adding them.
  .reentry_sd_k <- as.numeric(Sys.getenv("AUSPOL_REENTRY_SD_K", "0"))
  if (.reentry_sd_k > 0) {
    # n_set is read BEFORE combine_sd_override(), which builds a fresh matrix
    # and does not carry attributes from either input forward.
    .re_sd <- reentry_sd_matrix(shares, REENTRY_CELLS, .level_sd, .lm(shares), .reentry_sd_k)
    cat(sprintf("RH1  re-entry sd widening ON (k=%.1f): %d cell(s)
",
                .reentry_sd_k, attr(.re_sd, "n_set")))
    SD_OVR <- combine_sd_override(SD_OVR, .re_sd)
  }
# XGB PER-CELL PRIMARY SD (AUSPOL_XGB_PRIMARY_SD). The replacement for the
# surge: instead of firing a jump at one candidate, be honestly WIDE on cells
# that could plausibly emerge and let the simulator's own tail carry it.
# Combined by taking the larger of the two, never added -- same convention as
# the salience and re-entry overrides above.
if (identical(Sys.getenv("AUSPOL_XGB_PRIMARY_SD", "0"), "1")) {
  .xsd <- tryCatch(xgb_primary_sd_matrix(shares, TGT),
                   error = function(e) {
                     cat(sprintf("XD9! xgb primary sd FAILED: %s
", conditionMessage(e))); NULL })
  if (!is.null(.xsd)) SD_OVR <- combine_sd_override(SD_OVR, .xsd)
}
.xgb_flow_ov <- NULL
if (identical(Sys.getenv("AUSPOL_XGB_FLOWS", "0"), "1")) {
  .xgb_flow_ov <- tryCatch(xgb_flow_conditional_override_for(shares, TGT, PRV, "nsw"),
                            error = function(e) { cat(sprintf("XF9! xgb flows per-seat FAILED: %s\n", conditionMessage(e))); NULL })
}
# XGB SURGE PARAMETERS (AUSPOL_XGB_SURGE). Replaces the salience-derived
# surge_h / surge_party / surge_mu / surge_sd with the emergence model's.
# No simulator change: all four are already per-seat vectors.
if (identical(Sys.getenv("AUSPOL_XGB_SURGE", "0"), "1")) {
  .xs <- tryCatch(xgb_surge_params_for(shares, TGT),
                  error = function(e) { cat(sprintf("XS9! xgb surge FAILED: %s
", conditionMessage(e))); NULL })
  if (!is.null(.xs)) {
    surge_arg <- .xs$surge_h; surge_party_arg <- .xs$surge_party
    surge_mu_arg <- .xs$surge_mu; surge_sd_arg <- .xs$surge_sd
  }
}
sim <- simulate_seat_contests(level_sd = .level_sd, sd_override = SD_OVR, level_mult = .lm(shares), shares, fm, party_sd = psd, seat_sd = sp$sd_within * SEAT_SD_MULT,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED, party_cor = PARTY_COR,
                              shrink = SHRINK, conditional_override = .xgb_flow_ov,
                              fallback_smooth = FB_SMOOTH, shrink_k = SHRINK_K, flow_sd = FLOW_SD,
                              surge_h = surge_arg, surge_party = surge_party_arg,
                                surge_from_zero = identical(Sys.getenv("AUSPOL_SURGE_FROM_ZERO", "0"), "1"), surge_mu = surge_mu_arg, surge_sd = surge_sd_arg)
cat(sprintf("BT5e  engine %s | surge recipient fell back: %d class(es) absent, %d seat-draws at zero share\n", sim$engine, sim$surge_recipient_fallback, sim$surge_recipient_fallback_draws))
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
.rr <- seat_share_rmse(shares, fp_tgt)  # the second metric: point-estimate seat-share RMSE vs actual
cat(sprintf("BT5r  seat-share RMSE %.3f | MAE %.3f | by class %s | %d seats%s\n", .rr$rmse, .rr$mae,
            paste(sprintf("%s=%.2f", names(.rr$by_class), .rr$by_class), collapse = " "),
            .rr$n_seats, if (.rr$n_dropped) sprintf(" (%d unmatched dropped)", .rr$n_dropped) else ""))
cat(sprintf("BT5  mean log score: %.4f  (worse = more confident misses)\n",
            -mean(log(pmax(res$p, eps)))))
cat(sprintf("BT5  seats where the winner got < 5%% from us: %d\n", sum(res$p < 0.05)))
# ONE SUMMARY LINE IN THE SAME SHAPE AS EVERY OTHER HARNESS (BF2/BV2/BQ2/BS2/BW2).
# Coded BT4s, not BT2: BT2 already labels the by-election truth notes above, and
# CLAUDE.md records a case where one code meaning two things broke a grep.
# All three numbers were already printed, but spread over three lines and with
# log loss called "mean log score" -- so a grep for "log" across the six harness
# logs returns nothing for New South Wales, and scripts/pool_backtests.R was the
# only way to read its primary metric. Cost: this comparison was nearly reported
# with New South Wales missing.
cat(sprintf("BT4s %s: accuracy %d/%d (%.1f%%) | Brier %.4f | log %.4f\n",
            TGT, sum(res$pred == res$actual), nrow(res),
            100 * mean(res$pred == res$actual), mean((1 - res$p)^2),
            -mean(log(pmax(res$p, eps)))))
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

fwrite(res[order(seat)], file.path("output", sprintf("backtest-%s%s.csv", TGT, CAL_TAG)))
fwrite(data.table(pair = TGT, as.data.table(sim$totals)), file.path("output", sprintf("backtest-%s-totals%s.csv", TGT, CAL_TAG)))
# PERSIST THE POINT ESTIMATE, not just the aggregate RMSE -- see fed's
# equivalent line, 2026-09-09.
fwrite(as.data.table(.rr$detail)[, pair := TGT], file.path("output", sprintf("backtest-%s-sharedetail%s.csv", TGT, CAL_TAG)))
# NAME THE FILE ACTUALLY WRITTEN, not the untagged name. Same fix as in
# backtest_candidate_sa.R: a hardcoded filename in the log defeats the tag that
# exists to stop an arm overwriting the baseline it is compared against.
cat(sprintf("\nWrote output/backtest-%s%s.csv and its totals\n", TGT, CAL_TAG))
