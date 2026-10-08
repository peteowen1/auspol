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
# THE PUBLISHED CONFIGURATION lives in scripts/published_flags.R and nowhere
# else. Every switch the caller left unset takes its value from there, so the
# scattered Sys.getenv() defaults below are documentation, not behaviour.
source("scripts/published_flags.R")
.pf_applied <- apply_published_flags()
cat(sprintf("S0   published flags applied to %d unset switch(es); caller set: %s
",
            length(.pf_applied),
            { .cs <- setdiff(names(PUBLISHED_FLAGS), .pf_applied); .cs <- .cs[nzchar(Sys.getenv(.cs, ""))]
              if (length(.cs)) paste(sprintf("%s=%s", .cs, Sys.getenv(.cs)), collapse = " ") else "(none)" }))
suppressMessages(library(data.table))

# LEVEL-DEPENDENT SEAT VARIANCE, ON BY DEFAULT since 2026-08-27. The per-seat
# deviation sd is a + b*sqrt(p(1-p)) instead of a flat seat_sd, with a and b
# from AUSPOL_LEVEL_SD (default "1.10,8.67"). AUSPOL_LEVEL_SD="off" reproduces
# the pre-2026-08-27 published model exactly.
#
# This comment said "off by default" until 2026-09-03, contradicting the line
# five below it that has said ADOPTED since the day it shipped. It cost a
# recommendation to re-run an experiment that had already shipped.
# Pre-registered in docs/plans/prereg-level-dependent-variance.md and scored in
# docs/reviews/level-variance-2026-08-27.md -- READ THAT FILE TO ITS END: it
# refuses the change and then amends the same day to ship it.
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


N_SIMS  <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))
SEAT_SD <- 3.5      # within-region seat deviation, from seat_swing_spread()
# AUSPOL_SEAT_SD_MULT NEVER REACHED THE PUBLISHED FORECAST -- found
# 2026-09-09 checking every published switch against fit_seats_full.R and
# all six harnesses directly. All six harnesses apply this multiplier (a
# fix that itself took until 2026-09-06 to be inert-no-longer everywhere);
# this script, which produces the actual published number, never did.
# Harmless while the shipped value is 1 (a no-op), but a future tune of
# this switch would silently not reach Victoria's forecast. Same pattern
# as every harness's own block: scales whichever spread is actually in
# force (level_sd if set, else the flat SEAT_SD), and says which.
SEAT_SD_MULT <- as.numeric(Sys.getenv("AUSPOL_SEAT_SD_MULT", "1"))
if (!is.finite(SEAT_SD_MULT) || SEAT_SD_MULT <= 0)
  stop("AUSPOL_SEAT_SD_MULT must be a positive number; got ", SEAT_SD_MULT)
if (SEAT_SD_MULT != 1) {
  if (is.null(.level_sd)) {
    SEAT_SD <- SEAT_SD * SEAT_SD_MULT
    cat(sprintf("CAL  seat_sd multiplier %.2f applied (flat seat_sd path)\n", SEAT_SD_MULT))
  } else {
    .level_sd <- .level_sd * SEAT_SD_MULT
    cat(sprintf("CAL  spread multiplier %.2f applied to LEVEL_SD -> a=%.3f b=%.3f (seat_sd is inert here)\n",
                SEAT_SD_MULT, .level_sd[1], .level_sd[2]))
  }
}
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
# ---- TARGET ELECTION -----------------------------------------------------------
# One published script for every live election (plans/nsw2027-itg-scope-2026-10-08.md).
# AUSPOL_TARGET unset is vic2026, byte-identical to the Victoria-only script.
# nsw2027 is wired for identity only: its Senate/booth/council tables and the
# optional-preferential flow pooling are the next steps in that plan.
.TARGETS <- list(
  vic2026 = list(tgt = "vic2026", prev = "vic2022", region = "vic", year = 2026L,
                 fp_file = "vec-2022-vic-firstprefs.csv", tx_file = "vec-2022-vic-transfers.csv", tx_recipe = "pooled",
                 n_seats = 88L, out_stem = "vic-2026"),
  nsw2027 = list(tgt = "nsw2027", prev = "nsw2023", region = "nsw", year = 2027L,
                 fp_file = "nswec-2023-nsw-firstprefs.csv", tx_file = "nswec-nsw-transfers.csv", tx_recipe = "own_prev",
                 n_seats = 93L, out_stem = "nsw-2027"))
.tgt_arg <- Sys.getenv("AUSPOL_TARGET", "vic2026")
if (!.tgt_arg %in% names(.TARGETS)) stop("AUSPOL_TARGET must be one of ", paste(names(.TARGETS), collapse = ", "), ", not ", .tgt_arg)
TARGET <- .TARGETS[[.tgt_arg]]
TGT <- TARGET$tgt; PREV <- TARGET$prev; REGION <- TARGET$region; YEAR <- TARGET$year
cat(sprintf("TG0  target %s (previous %s, region %s, %d seats)
", TGT, PREV, REGION, TARGET$n_seats))
# Diagnostic arms for the One Nation allocation, declared HERE beside the other
# overrides so the S6 default-run check below can see them. Defined only
# further down, a toggle would change the published allocation with nothing in
# the run log -- which is exactly what S6 exists to prevent.
ONP_ORDER   <- Sys.getenv("AUSPOL_ONP_ORDER", "federal")   # federal | greens | senate
ONP_FIX     <- Sys.getenv("AUSPOL_ONP_FIX", "1")           # 1 = compression fixed
stopifnot(ONP_ORDER %in% c("federal", "greens", "senate"), ONP_FIX %in% c("0", "1"))
stopifnot(FP_SD_MODE %in% c("growth", "additive"))
stopifnot(is.finite(SEED))

SMOOTH  <- 0.15     # see distribute_preferences(); NOT optional, see its docs
ONP_B1  <- -0.0968  # Greens-share coefficient, fitted on Victorian federal 2025
# AUSPOL_FALLBACK_SMOOTH AND AUSPOL_FLOW_SD NEVER REACHED THE PUBLISHED
# FORECAST -- found 2026-09-09 alongside the AUSPOL_SEAT_SD_MULT gap, same
# shape: registered in published_flags.R, honoured by all six backtest
# harnesses since the flow fixes were ported, never wired here. Both
# default to 0 (a no-op), so this changes nothing today; wired so a future
# tune of either reaches Victoria's forecast rather than silently not.
FB_SMOOTH <- as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0"))
SHRINK_K  <- as.numeric(Sys.getenv("AUSPOL_FLOW_SHRINK_K", "0"))    # EXPERIMENTAL, docs/plans/prereg-flow-cell-shrinkage-2026-09-10.md
FLOW_SD   <- as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0"))
cat(sprintf("BS1f fallback_smooth %.2f | flow_sd %.2f\n", FB_SMOOTH, FLOW_SD))

PREF <- election_data_path()          # external/elections, gitignored
need <- file.path(PREF, c(TARGET$tx_file,
                          "ecsa-2026-sa-transfers.csv",
                          TARGET$fp_file,
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

# The files above degrade to a clean S5 SKIP. The ones below do NOT -- they are
# hard requirements of the published path, and a missing one is a broken
# pipeline rather than absent data. Checked HERE, together, rather than at
# their read sites 50, 267 and 533 lines down.
#
# The reason is a cost paid three times on 2026-09-03. The nightly run had been
# red since 2026-08-21 on the Queensland file; fixing that got it three seconds
# further, to a cryptic fread() on the transposed federal file; fixing THAT got
# it three seconds further still, to a bare `gzfile(file, "rb"): cannot open
# the connection` on the statewide covariance. All three had the same cause --
# the script that produces the file was never added to the workflow -- and each
# one cost a separate thirteen-minute CI run to discover, because the checks
# sat at the read sites instead of together at the top.
#
# The third slipped past the first version of this guard, which checked only
# PREF. statewide-cov.rds lives under output/, and that difference is the
# entire reason it was missed. So this list is keyed on FULL PATHS: a new hard
# input belongs here whatever directory it lives in.
hard <- c(
  "ecq-qld-transfers.csv"           = "scripts/fetch_preferences_qld.R",
  "federal-transposed-to-state.csv" = "scripts/transpose_federal_to_state.R")
names(hard) <- file.path(PREF, names(hard))
if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "1"), "0")) {
  hard <- hard[names(hard) != file.path(PREF, "ecq-qld-transfers.csv")]
}
# Same condition as the read site far below, deliberately duplicated rather
# than hoisted: AUSPOL_PARTY_COR=off is a real arm of
# docs/plans/prereg-statewide-covariance.md and must not require the file.
.cor_mode <- Sys.getenv("AUSPOL_PARTY_COR", "shrunk")
if (!identical(.cor_mode, "off") && nzchar(.cor_mode)) {
  hard["output/statewide-cov.rds"] <- "scripts/estimate_statewide_cov.R"
}
absent <- hard[!file.exists(names(hard))]
if (length(absent)) {
  stop("S5 missing ", length(absent), " required file(s):\n",
       paste0("  ", names(absent), "  <- run ", absent, collapse = "\n"))
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
# ON, BY PETE'S DECISION, 2026-08-21. Refusal Q4 said to stop and report if any
# party's Victoria 2026 median moved by more than 2 seats. It did:
#
#   ALP 40 -> 37   ONP 5 -> 9   LNP 37 -> 36   GRN 4 -> 5
#
# So the change was measured, held, and put to him rather than shipped. He took
# it. Q4 did its job -- it is not a veto, it is a stop sign that forces the
# judgement onto a person.
#
# The reasoning for taking it: this is a DATA change, not a parameter tweak.
# The same One Nation preference rates are now estimated from 198 exclusion
# events instead of 18. Better data moving the answer is the system working.
#
# Set AUSPOL_QLD_FLOWS=0 to reproduce the pre-2026-08-21 forecast exactly.
if (identical(TARGET$tx_recipe, "own_prev")) {
  # NSW IS OPTIONAL PREFERENTIAL: its own previous election only, never pooled with
  # Queensland, South Australia or Western Australia (the NSW harness recipe,
  # scripts/backtest_candidate_nsw.R; pooling Queensland cost nsw2023 0.194 of log score).
  tx <- fread(file.path(PREF, TARGET$tx_file))
  .p <- PREV
  if (!.p %in% tx$election) stop("TG1! ", TARGET$tx_file, " has no ", .p, " transfers")
  tx <- tx[tx$election == .p]
  POLL_DAY <- format(as.Date(unname(election_dates()[TGT])))
  cat(sprintf("TG1  %s flows: %d %s transfers only (own previous election, no pooling)
", TGT, nrow(tx), .p))
} else {
  tx <- rbind(fread(file.path(PREF, TARGET$tx_file)),
              fread(file.path(PREF, "ecsa-2026-sa-transfers.csv")))
  if (!identical(Sys.getenv("AUSPOL_QLD_FLOWS", "1"), "0")) {
    qf <- file.path(PREF, "ecq-qld-transfers.csv")
    if (!file.exists(qf)) stop("Run scripts/fetch_preferences_qld.R first.")
    tx <- rbind(tx, fread(qf), fill = TRUE)
  }
  # WESTERN AUSTRALIA, OFF BY DEFAULT. Against docs/plans/prereg-wa-flows.md,
  # which requires the backtest measurement before this ships. Seven admissible
  # elections, 1,634 exclusion events, taking One Nation's from 198 to 359.
  #
  # Routed through pool_external_flows() with the Victorian polling day, so the
  # same date guard the backtests use applies here rather than being assumed
  # unnecessary. The Queensland line above predates the helper and is left as it
  # is deliberately: it is on the published path, and the smallest diff that adds
  # Western Australia is the one least able to move the current forecast.
  POLL_DAY <- format(as.Date(unname(election_dates()[TGT])))
  if (identical(Sys.getenv("AUSPOL_WA_FLOWS", "0"), "1")) {
    tx <- pool_external_flows(tx, POLL_DAY, "wa")
  }
}
fm <- build_flow_matrix(tx, min_n = 3L)
cat(sprintf("flow matrix: %d exclusions, %d cells at n>=3 of %d observed\n",
            uniqueN(tx[, .(election, seat, round)]), length(fm$conditional),
            nrow(fm$coverage)))

# ---- 2. each seat's 2022 first preferences, as class shares ----------------
fp <- fread(file.path(PREF, TARGET$fp_file))
# A SUPPLEMENTARY ELECTION IS THE SEAT'S GENERAL ELECTION HELD LATE. Narracan's
# 2022 poll was deferred by a candidate's death and held on 28 January 2023;
# the VEC file has no Narracan row, so until 2026-09-19 the forecast simulated
# 87 of 88 seats and the Legislative Assembly's majority line was mis-set.
# The by-election results table carries the supplementary result at
# candidate level; a seat absent from the general-election file whose
# by-election falls in the window is appended here as its 2022 baseline.
.sup <- tryCatch({
  bt <- byelection_table(); dts <- election_dates()
  bt[bt$region == REGION & !bt$seat %in% unique(fp$seat) & bt$date > dts[[PREV]] & bt$date < dts[[TGT]]]
}, error = function(e) NULL)
if (!is.null(.sup) && nrow(.sup)) {
  add <- .sup[, .(votes = sum(votes)), by = .(seat, party)]
  fp <- rbind(fp[, .(seat, party, votes)], add, fill = TRUE)
  cat(sprintf("SUP1 supplementary election(s) appended as the 2022 baseline: %s
",
              paste(unique(add$seat), collapse = ", ")))
}
w <- dcast(fp, seat ~ party, value.var = "votes", fill = 0)
mat22 <- as.matrix(w[, -1]); rownames(mat22) <- w$seat
mat22 <- 100 * mat22 / rowSums(mat22)
a22 <- 100 * colSums(as.matrix(dcast(fp, seat ~ party, value.var = "votes",
                                     fill = 0)[, -1])) /
       sum(fp$votes)
cat(sprintf("seats with 2022 first preferences: %d\n", nrow(mat22)))
# A FLOOR, not just a printed number. The seat count reached the simulation as
# a cat() line nobody is obliged to read, so a join or a missing first-
# preference row that dropped a seat would print a different, equally
# plausible figure and quietly simulate a smaller chamber. 88 districts:
# 87 from the VEC file plus Narracan's supplementary election (above).
if (nrow(mat22) < TARGET$n_seats) {
  stop("Only ", nrow(mat22), " seats have ", PREV, " first preferences; ", TARGET$n_seats, " expected ",
       "(87 from the VEC file plus Narracan's supplementary election from the by-election table). A seat has been lost upstream.")
}

# ---- 3. statewide 2026, from the model rather than assumed -----------------
cycles <- load_election_cycles(); polls <- load_polls(REGION)
pri <- load_prior_results(); kp <- pri$region == REGION & pri$year == YEAR
priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
fl <- flows_for(load_preference_flows(), YEAR, REGION, quiet = TRUE)
# THE FLOWS THIS RUN USES, every run. flows_for() re-estimates each party's
# flow from earlier elections, so the anchor file's number is not the one used:
# on 2026-10-08 the anchor's NSW One Nation 25.5 was taken for the model's
# value, which was 33.7, and an override was half-built before anyone printed it.
cat(sprintf("FL0  %s flows used (to Labor %% / exhausted %%, source): %s\n", TGT,
            paste(sprintf("%s %.1f/%.0f (%s)", fl$party, fl$flow_alp, fl$exhaust,
                          if ("flow_source" %in% names(fl)) fl$flow_source else "as supplied"),
                  collapse = "; ")))
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
# EVERY environment variable that changes what this script COMPUTES, with the
# value a default publish run carries. The previous version of this check
# listed six by hand and missed six more -- AUSPOL_SHRINK, AUSPOL_PARTY_COR,
# AUSPOL_QLD_FLOWS, AUSPOL_WA_FLOWS, AUSPOL_FORCE_FP, AUSPOL_ONP_CV and
# AUSPOL_N_SIMS -- so a run with the calibration shrink switched off would
# write over output/seat-probs-vic-2026.csv with a materially different,
# over-confident forecast while S6 printed PASS.
#
# AUSPOL_PARTY_COR=off was the worst of them: the one line that would have
# revealed it sits inside `if (!is.null(sw_cor))`, which is NULL exactly when
# the flag is off. A silent divergence, certified as the default run.
#
# Derived from the list rather than restated, so adding a flag without adding
# it here is the only remaining way to reopen the hole -- and S6 now prints
# what actually differs, which a hand-maintained boolean could not.
RUN_FLAGS <- PUBLISHED_FLAGS  # scripts/published_flags.R -- the only copy
.now <- vapply(names(RUN_FLAGS), function(k) Sys.getenv(k, RUN_FLAGS[[k]]),
               character(1))
changed <- names(RUN_FLAGS)[.now != RUN_FLAGS]
default_run <- length(changed) == 0L && OUT_SUFFIX == ""

# AND REFUSE TO WRITE THE PUBLISHED FILENAME FROM A NON-DEFAULT RUN. Reporting
# was not enough: S6 is one line in a long log, and by the time it prints the
# overwrite has already happened. A diagnostic run stays legitimate -- it just
# has to name its own output.
if (length(changed) && OUT_SUFFIX == "") {
  stop("This run changes ", paste(changed, collapse = ", "),
       " but would write to the PUBLISHED filenames. Set AUSPOL_OUT_SUFFIX to ",
       "something naming the arm, or unset those variables. Overwriting ",
       "output/seat-probs-vic-2026.csv from a diagnostic run is how a ",
       "forecast nobody chose gets published.")
}
cat(sprintf(paste0("S6  run config: seed %d, FP sd %s, flow %+.2f, ",
                   "ONP %s/fix%s, suffix %s  %s
"),
            SEED, FP_SD_MODE, FLOW_SHIFT, ONP_ORDER, ONP_FIX,
            if (OUT_SUFFIX == "") "(none)" else OUT_SUFFIX,
            if (default_run) "PASS" else
              paste("FAIL -- NOT A DEFAULT PUBLISH RUN; changed:",
                    paste(changed, collapse = ", "))))
now <- trend_as_at(polls, YEAR, cycles, Sys.Date(), priors, fl, with_series = TRUE)

# ---- S7: does the PUBLISHED trend follow the polls it was fitted to? --------
#
# This check existed since 2026-08-18 and was wired into `fit_vic.R` (`L3`),
# `fit_federal.R` (`FL3`) and `fit_nsw.R` (`NL3`) -- every script EXCEPT this
# one, which is the only one whose fit is published. All three of those fit
# with `sigmas = "per_cycle"` and `weights = "firm_factors"`; the call above
# takes the defaults. So a green `L3` said "the model we do not publish tracks
# its polls", and the model we DO publish was unasserted.
#
# That is not a hypothetical gap. The two paths give different answers for the
# same party on the same polls -- on 2026-09-14 the per-cycle Victorian fit had
# One Nation 2.44 points off its polls where the published fit had it 2.47 off,
# and on data four weeks older they were 2.44 against 2.85, i.e. opposite sides
# of the bound. The number that goes into `state_mean` below, and therefore
# into every seat, was the unchecked one either way.
#
# REPORTS RATHER THAN HALTING, for the same reason `L3` does: this is the
# target stage, and a `stopifnot` here means the Victorian forecast never
# publishes. The breach goes to its OWN marker file that `run_all.R` exits
# non-zero on after the page is built -- a separate file from `L3-BREACH.txt`
# and `NL3-BREACH.txt` on purpose, so a breach on the published cycle can
# never be masked by, or overwrite, one on a cycle nobody publishes.
S7_MARKER <- file.path("output", if (TGT == "vic2026") "S7-BREACH.txt" else sprintf("S7-BREACH-%s.txt", TGT))   # run_all.R reads the vic2026 name

# `now` is NULL on any of trend_as_at()'s several thin-cycle paths. Say which
# quantity is missing rather than letting it surface as `stopifnot(length(fits)
# > 0L)` inside the check, or as a data.table error on `now$series` twenty
# lines below: `NULL$anything` is NULL in R, so a NULL fit propagates silently
# until something unrelated trips over it.
if (is.null(now)) {
  stop(sub("@T", TGT, "trend_as_at() returned NULL for @T, so there is no trend ", fixed = TRUE),
       "to publish, to check with S7, or to draw. Too few polls, no ALP ",
       "series, or the fit failed -- rerun it directly to see which.")
}

# WRAPPED, because an S7 that THROWS would halt this stage -- and this stage
# publishes. The whole point of reporting rather than halting is that a
# tracking gap must not stop the Victorian forecast; a check that crashes
# instead of reporting takes the page down for the exact reason the design
# says it must not.
#
# The failure is recorded as a BREACH LINE, not swallowed. A check that cannot
# run is not a check that passed, and turning "S7 errored" into a green build
# would be the silent failure S7 exists to catch, arriving through S7.
s7 <- tryCatch(poll_tracking_check(now$polls, now$fits), error = function(e) e)
s7_lines <- if (inherits(s7, "error")) {
  cat(sprintf("S7  THE CHECK ITSELF FAILED: %s\n", conditionMessage(s7)))
  sprintf("2026 S7 COULD NOT RUN: %s", conditionMessage(s7))
} else {
  report_poll_tracking(s7, "S7")
  s7_bad <- s7[breach == TRUE | dropped == TRUE]
  if (nrow(s7_bad)) {
    sprintf("2026 %s fitted %.2f against %.2f from %d polls (bound %.1f)%s",
            s7_bad$party, s7_bad$fitted, s7_bad$poll_mean, s7_bad$n,
            attr(s7, "bound"),
            ifelse(s7_bad$dropped, "  [DROPPED FROM THE FIT]", ""))
  } else character(0)
}

# WRITE THE MARKER EVERY RUN, AND PUT THIS RUN'S PROVENANCE IN IT.
#
# The first version gated both the unlink and the write on `default_run`, and
# run_all.R gated the READ on `!quick` -- "did this stage run at all", which is
# a much weaker condition. `default_run` additionally requires every AUSPOL_*
# variable to match published_flags.R and OUT_SUFFIX to be empty, and stages
# inherit the shell (run_all.R's system2() call passes no `env`). So a full run
# with AUSPOL_OUT_SUFFIX set would leave the marker neither refreshed nor
# cleared, and run_all.R would report a PREVIOUS run's verdict as this one's.
# Found by review, 2026-09-14.
#
# Neither obvious repair is right, which is why the file carries a header now:
#
#   - Write unconditionally, and a diagnostic arm's breach gets reported by
#     run_all.R as a breach "on the published forecast". It is not; it is a
#     breach in a configuration nobody publishes.
#   - Unlink unconditionally but write only when default, and a diagnostic run
#     ERASES a real breach. The next run_all.R sees no marker and goes green.
#     That is the silent failure this check exists to prevent, introduced by
#     the check itself.
#
# The marker encoded two states where there are three: never ran, ran on a
# non-default config, ran on the published config. So it records which, and
# run_all.R decides. A missing file now means "the stage did not get here",
# which is distinguishable from "it ran and was clean" -- something L3 and NL3
# cannot currently tell apart.
writeLines(c(sprintf("#run %s default_run=%s",
                     format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), default_run),
             s7_lines), S7_MARKER)
if (length(s7_lines) && !default_run) {
  cat("S7  breach recorded as NON-DEFAULT: this run changed",
      paste(c(changed, if (OUT_SUFFIX != "") "AUSPOL_OUT_SUFFIX"), collapse = ", "),
      "\n    so it does not describe the published forecast, and run_all.R",
      "will not fail on it.\n")
}

last <- as.data.table(now$series)[, .SD[which.max(date)], by = party]
tppr <- last[party == "TPP_ALP"]
mix <- fread("output/projection-mix.csv")
.reg <- REGION; .yr <- YEAR   # never a bare column-name symbol inside [ (CLAUDE.md, data.table NSE)
days_out <- as.integer(cycles[cycles$region == .reg & cycles$year == .yr, end] - Sys.Date())
fdat <- build_fundamentals_data(); m_tpp <- fit_fundamentals(fdat, "@TPP")
live <- build_fundamentals_data(polled_only = FALSE, require_actual = FALSE)
kf <- live$region == REGION & live$year == YEAR & live$party == "@TPP"
fund_now <- predict_fundamentals(m_tpp, live[which(kf), ])
pj <- project_result(now$tpp, fund_now, mix, days_out)
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

# ---- LL1: the statewide LEVEL anchored to the projection, as the backtests do
# The backtests hand the seats colMeans() of the ANCHORED draws
# (forecast_statewide_or_oracle()), so their level implies the projected
# two-party. Here the seats are built from `state_mean`, and the draws'
# anchoring further down moves only the draws -- whose mean
# simulate_seat_contests() subtracts (R/seat_sim.R:970) -- so the fundamentals
# pull never reached a seat and the ledger scored a recipe this script did not
# run. Shifting Labor and the Coalition here, with the same flows the draws'
# anchoring uses, makes the two the same recipe. Before AUSPOL_FORCE_FP on
# purpose: a forced vote must stay where it was forced.
# docs/plans/prereg-live-level-anchor-2026-09-28.md.
ll_flow <- function(p) { f <- fl$flow_alp[fl$party == p]; if (length(f)) f[1] / 100 else 0.489 }
ll_implied <- function(sm) {
  mnr <- setdiff(names(sm), c("ALP", "LNP"))
  sm[["ALP"]] + sum(vapply(mnr, function(p) sm[[p]] * ll_flow(p), numeric(1)))
}
LEVEL_ANCHOR <- identical(Sys.getenv("AUSPOL_LIVE_LEVEL_ANCHOR", "0"), "1")
# The trend fits each party separately, so its endpoints need not sum to 100
# (97.93 on 2026-09-28). The seat shares are renormalised later, so the level
# they actually carry is this one rescaled -- which implied 48.90 two-party
# where the raw sum read 47.88. The backtests close the total by making OTH the
# remainder (R/forecast_mode.R, `mu[["OTH"]] <- 100 - sum(...)`); do the same,
# THEN anchor, or the shift is computed on a level no seat ever sees.
ll_sum_raw <- sum(state_mean)
if (LEVEL_ANCHOR && "OTH" %in% names(state_mean)) {
  if (identical(Sys.getenv("AUSPOL_CLOSE_PROPORTIONAL", "0"), "1")) {
    # as R/forecast_mode.R under the same switch: rescale every class, not
    # just OTH (plans/prereg-close-proportional-2026-09-28.md)
    state_mean <- state_mean * 100 / sum(state_mean)
  } else {
    state_mean[["OTH"]] <- max(0.1, 100 - sum(state_mean[setdiff(names(state_mean), "OTH")]))
  }
} else if (!LEVEL_ANCHOR) {
  # Un-anchored (v56): the backtests' "live" recipe rescales EVERY fitted class
  # by 100 / sum (R/forecast_mode.R, close_prop). Do the same here, or One
  # Nation's target and the xgb base margin below read the raw endpoints
  # (sum 97.93) while the backtests read them rescaled. Review gate 2026-09-30.
  state_mean <- state_mean * 100 / sum(state_mean)
}
ll_before <- ll_implied(state_mean * 100 / sum(state_mean))
ll_delta <- pj$mean - ll_before
if (LEVEL_ANCHOR) {
  state_mean[["ALP"]] <- state_mean[["ALP"]] + ll_delta
  state_mean[["LNP"]] <- state_mean[["LNP"]] - ll_delta
}
cat(sprintf("LL1  statewide level %s: trend endpoints sum %.2f (OTH now %.2f, sum %.2f); trend implies %.2f two-party, projection %.2f; ALP %+.2f, LNP %+.2f first preference; now implies %.2f\n",
            if (LEVEL_ANCHOR) "ANCHORED" else "NOT anchored (AUSPOL_LIVE_LEVEL_ANCHOR=0)",
            ll_sum_raw, state_mean[["OTH"]], sum(state_mean),
            ll_before, pj$mean, if (LEVEL_ANCHOR) ll_delta else 0,
            if (LEVEL_ANCHOR) -ll_delta else 0, ll_implied(state_mean * 100 / sum(state_mean))))
if (LEVEL_ANCHOR && abs(ll_implied(state_mean) - pj$mean) > 0.01) {
  stop("LL1 FAILED: the anchored level implies ", round(ll_implied(state_mean), 3),
       " two-party against a projection of ", round(pj$mean, 3), ".")
}

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
# The what-if slider's zero point: the level BEFORE any forcing.
cat(sprintf("FP0  statewide primaries before forcing: %s\n",
            paste(sprintf("%s %.2f", names(state_mean), state_mean), collapse = ", ")))
if (!nzchar(Sys.getenv("AUSPOL_FORCE_FP", ""))) {
  # scripts/build_scenarios.R steps each party 10 points either side of these.
  fwrite(data.table(party = names(state_mean), level = unname(state_mean)),
         sprintf("output/statewide-level-%s%s.csv", TARGET$out_stem, OUT_SUFFIX))
}
# AUSPOL_FORCE_FP_RULE: "draws" (default, Pete 2026-10-04) moves the others by
# the published run's own statewide-draw regression and holds the forced party
# exactly at X in every draw ("if ONP GETS X%"); "draws-polled" uses the same
# regression but keeps the usual statewide spread around X ("if ONP is POLLING
# X%", Pete 2026-10-08: the slider offers both); "sa" is the older South
# Australia response, ONP only, with the spread kept.
.fp_rule <- Sys.getenv("AUSPOL_FORCE_FP_RULE", "draws")
if (!.fp_rule %in% c("draws", "draws-polled", "sa")) stop("AUSPOL_FORCE_FP_RULE must be draws, draws-polled or sa, not ", .fp_rule)
FORCE_DRAWS_RULE <- nzchar(FORCE_FP) && .fp_rule %in% c("draws", "draws-polled")
FORCE_HOLD_EXACT <- FORCE_DRAWS_RULE && identical(.fp_rule, "draws")
.forced_parties <- character(0)
if (FORCE_DRAWS_RULE) {
  .bf <- sprintf("output/statewide-draw-betas-%s.csv", TARGET$out_stem)
  if (!file.exists(.bf)) stop("AUSPOL_FORCE_FP_RULE=draws needs ", .bf,
                              ", written by a default run of this script. Run one first.")
  .fp_betas <- fread(.bf, showProgress = FALSE)
}
if (nzchar(FORCE_FP)) {
  for (x in strsplit(strsplit(FORCE_FP, ",", fixed = TRUE)[[1]], "=", fixed = TRUE)) {
    fp_party <- trimws(x[1]); fp_target <- as.numeric(x[2])
    if (!fp_party %in% names(state_mean)) {
      stop("AUSPOL_FORCE_FP names a party the model does not carry: ", fp_party,
           ". Known: ", paste(names(state_mean), collapse = ", "))
    }
    fp_delta <- fp_target - state_mean[[fp_party]]
    if (FORCE_DRAWS_RULE) {
      .fpb <- .fp_betas[.fp_betas$moved == fp_party]
      if (!nrow(.fpb)) stop("No scenario betas for ", fp_party, " in ", .bf)
      if (length(.forced_parties)) stop("AUSPOL_FORCE_FP_RULE=draws forces one party at a time")
      state_mean[[fp_party]] <- fp_target
      for (i in seq_len(nrow(.fpb))) {
        q <- .fpb$class[i]
        state_mean[[q]] <- max(0.1, state_mean[[q]] + fp_delta * .fpb$beta[i])
      }
      .forced_parties <- c(.forced_parties, fp_party)
      cat(sprintf("FP1  forced %s to %.1f (was %.1f, %+.1f), others by the draws' regression\n",
                  fp_party, fp_target, fp_target - fp_delta, fp_delta))
      next
    }
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
fed_onp <- fed_tr[fed_tr$region == .reg & fed_tr$cycle == .yr & fed_tr$party == "ONP", .(seat, pct)]
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

# SENATE RULE (AUSPOL_ONP_ORDER = "senate", 2026-10-01, from Pete's chart).
# Replaces both the ordering and the borrowed SA spread above: each seat's
# share comes from its own 2025 SENATE One Nation vote through the log curve
# of the most One-Nation-heavy earlier election (SA 2026), floored at that
# fit's lowest Senate share, then scaled so the statewide level is unchanged.
# Out of sample it nearly halves the error at a Victoria-like level (RMSE
# 3.25 vs 5.28 on SA 2026 + Qld 2017); scripts/build_onp_senate.R has the
# whole comparison. Table: output/onp-senate-vic2026.csv (ships with the models).
if (identical(Sys.getenv("AUSPOL_ONP_ORDER", "federal"), "senate")) {
  .os_f <- file.path("output", sprintf("onp-senate-%s.csv", TGT))
  if (file.exists(.os_f)) {
    .os <- fread(.os_f, showProgress = FALSE)
    .os_v <- .os$senate_pct[match(rownames(mat22), .os$seat)]
    if (anyNA(.os_v)) stop(basename(.os_f), " has no Senate share for: ", paste(rownames(mat22)[is.na(.os_v)], collapse = ", "))
    .os_p <- .os$curve_a[1] + .os$curve_b[1] * log(pmax(.os_v, .os$floor_pct[1]))
    if (any(!is.finite(.os_p)) || any(.os_p <= 0)) stop("Senate One Nation curve gave a non-positive share; floor or curve is wrong")
    onp_ratio[] <- .os_p / mean(.os_p)
    cat(sprintf("ONP1  One Nation by the SENATE rule (curve from %s, %d districts, R2 %.3f): ratio %.2f-%.2f, CV %.3f\n",
                .os$source[1], .os$n_fit[1], .os$r2[1], min(onp_ratio), max(onp_ratio), stats::sd(onp_ratio) / mean(onp_ratio)))
  } else {
    cat("ONP1!! AUSPOL_ONP_ORDER=senate but", .os_f, "is missing -- One Nation allocated by the FEDERAL HOUSE rule instead\n")
  }
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
ONP_CV <- as.numeric(Sys.getenv("AUSPOL_ONP_CV", "0.365"))
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

# PER-CLASS DEVIATION SLOPE. Uniform swing moves every seat by the same number
# of points, which is the same as asserting that a seat's DEVIATION from the
# statewide mean persists intact -- a slope of exactly 1.000. Estimated across
# the 17 election pairs in output/candidacies.csv, that is rejected for every
# class, hardest for the minor ones:
#
#   OTH 0.215 (t -29.9) | ONP 0.551 | OTH_RIGHT 0.580 | IND 0.618 (t -17.8)
#   LNP 0.863 (t -11.2) | ALP 0.901 (t -8.9) | GRN 0.926 (t -6.1)
#
# THE DEFAULT HERE IS 1.000 FOR EVERY CLASS, which reproduces uniform swing
# byte-for-byte. The slopes above are NOT wired in by this commit: changing them
# changes the published forecast, and that needs measuring across all five
# backtest harnesses first. This commit is the plumbing and its no-op proof.
#
# The statewide level still comes from the trend model, not from the fit. Only
# the seat's deviation around that level is shrunk, so poll information is
# preserved -- a naive `pcv ~ prev` regression would absorb the statewide shift
# into its intercept and throw the polls away.
SLOPE <- dev_slopes_for(colnames(mat22), default = 1.0)
# PRINT WHAT WAS APPLIED, and print it before any result is read. An experiment
# that never ran looks exactly like an experiment with no effect; on 2026-08-19
# a file edit died and two runs behind it used the unmodified script, returning
# byte-identical output that read as "this input does not matter".
cat(sprintf("DS1  deviation slopes: %s\n",
            paste(sprintf("%s=%.3f", names(SLOPE), SLOPE), collapse = " ")))
if (all(SLOPE == 1)) cat("DS1  all 1.000 -- uniform swing, output must be unchanged\n")

# ARM CS: slopes conditional on candidate identity, gated by the salience
# screen. ADOPTED 2026-08-27 -- see docs/reviews/arm-c-conditional-slopes-2026-08-27.md
# and the fed2022/vic2022/sa2026/nsw2023 backtest results in the commits around
# afb7fef and 203610e. Default ON; AUSPOL_DEV_SLOPE_MODE=off reproduces uniform
# swing exactly.
#
# CANNOT RUN YET FOR VICTORIA 2026: candidate_returns() and
# salience_permit_for() both need the TARGET election's own candidate list, and
# vic2026 nominations do not close until shortly before polling day, 28
# November 2026. Until then this falls back to plain uniform swing (SLOPE
# above) -- not silently: printed, and reported as a fallback rather than a
# result. Re-running this script after nominations close activates arm CS with
# no further code change.
.mode <- Sys.getenv("AUSPOL_DEV_SLOPE_MODE", "screened")
.cond <- .mode %in% c("conditional", "screened")
.screened <- identical(.mode, "screened")
# Off by default -- see the matching comment in backtest_candidate_fed.R.
.honour_departed <- Sys.getenv("AUSPOL_HONOUR_DEPARTED", "1") %in% c("1", "TRUE", "true")
.departed_hold <- Sys.getenv("AUSPOL_DEPARTED_HOLD", "0") %in% c("1", "TRUE", "true")   # docs/plans/prereg-departed-hold-fixed-2026-10-04.md
.succ_on <- departed_successor_mode() != "0"   # docs/plans/prereg-departed-successor-flag-2026-10-07.md
if (.succ_on && .departed_hold) stop("AUSPOL_DEPARTED_SUCCESSOR holds its own cells; do not combine it with AUSPOL_DEPARTED_HOLD", call. = FALSE)
.SUCC_RATE <- departed_successor_rates(TGT)   # NULL when off: byte-identical
if (.succ_on) { cat(sprintf("DSR1 departed successor rates (%s): %d seat(s) for %s, held through renormalisation
", departed_successor_mode(), length(.SUCC_RATE), TGT)); .departed_hold <- TRUE }
.hold_min <- as.numeric(Sys.getenv("AUSPOL_DEPARTED_HOLD_MIN_PRIOR", "0"))   # arm B (amendment 2026-10-05)
# EVERY caught fallback records WHY. "vic2026 has no candidates yet" and "a
# bug in candidate_returns()" used to print the same line, so once nominations
# close a real failure would have read as the expected pre-nomination gap.
.why <- new.env()
.try <- function(name, expr) tryCatch(expr, error = function(e) {
  assign(name, conditionMessage(e), envir = .why); NULL })
.reason <- function(name) if (exists(name, envir = .why)) sprintf(" (%s)", get(name, envir = .why)) else ""
.returns <- if (.cond) .try("returns", candidate_returns(PREV, TGT)) else NULL
.permit  <- if (.screened && !is.null(.returns))
              .try("permit", salience_permit_for(TGT, PREV, REGION)) else NULL
if (.cond && is.null(.returns)) {
  cat(sprintf(sub("@T", TGT, "DS2  arm CS requested but @T has no candidate list yet -- FALLING BACK to uniform swing%s\n", fixed = TRUE),
              .reason("returns")))
} else if (.cond) {
  cat(sprintf("DS2  arm C ON: %d of %d seat-classes have the same candidate returning%s\n",
              sum(.returns$same), nrow(.returns),
              if (.screened && !is.null(.permit)) "" else " | screen: no salience data, arm C only"))
}
# SITTING-MEMBER SLOPE TIER and DEFECTOR DISCOUNT, wired into the PUBLISHED
# forecast 2026-09-06. Both were validated in the backtest harnesses and then
# sat there: this script called personal_prior_vote(), screened_slopes() and
# conditional_slopes() without either argument, so the thing the harnesses
# measured was not the thing being published.
#
# Values come from scripts/fit_mp_slope.R, never hard-coded. vic2026 has not
# happened, so there is no fold to hold out and the ALL-DATA per-class fit is
# both correct and leak-free here -- unlike a backtest, where the target's own
# pair must be removed. That distinction is the reason a target-keyed table and
# a pooled table are both written.
.MP_SLOPE <- NULL
.defect   <- NULL
if (!identical(Sys.getenv("AUSPOL_MP_SLOPE", "1"), "0")) {
  .mpf <- "output/mp-slope-by-class.csv"
  if (!file.exists(.mpf))
    stop("the MP slope tier needs ", .mpf, " -- run scripts/fit_mp_slope.R.
",
         "  Set AUSPOL_MP_SLOPE=0 to publish without it.")
  .mpc <- data.table::fread(.mpf, showProgress = FALSE)
  # GRN is excluded: its member slope (1.000) and also-ran slope (1.023) are
  # indistinguishable, so a separate member value would assert a distinction the
  # data does not contain. ONP is excluded by the n floor below -- no One Nation
  # member has ever personally re-contested, and its shipped 0.610 was the
  # also-ran slope written into the member row over zero observations.
  .keep <- .mpc[is.finite(.mpc$member) & .mpc$n_member >= 8L &
                  .mpc$party != "GRN", ]
  if (nrow(.keep)) .MP_SLOPE <- stats::setNames(as.numeric(.keep$member), .keep$party)
}
if (!identical(Sys.getenv("AUSPOL_DEFECT_DISCOUNT", "1"), "0")) .defect <- 0.282

# MINOR-TO-MINOR DEFECTOR DISCOUNT, same AUSPOL_MINOR_DEFECT switch and same
# fit_minor_defector_discount() call fit_xgb_primary_v6.R:271 uses to build
# the xgb TRAINING feature -- computed here so the LIVE xgb feature can match
# it. Found missing entirely 2026-09-17 while measuring
# docs/plans/prereg-major-defector-conserve-2026-09-17.md: this script had no
# reference to minor_discount anywhere, so the live own_prev_pcv the xgb
# model is SERVED never carried the discount the model was TRAINED on for a
# minor-to-minor defector. Not dormant -- vic2026's partial candidate list
# already has 5 such cases (Frankston, Broadmeadows, Lara, Werribee,
# Sydenham) being served the wrong value.
.minor_disc <- NULL; .minor_disc_loser <- NULL
if (!identical(Sys.getenv("AUSPOL_MINOR_DEFECT", "1"), "0")) {
  .mfd <- tryCatch(fit_minor_defector_discount(TGT), error = function(e) {
    cat(sprintf("CAL! minor-defector fit FAILED, no discount applied: %s\n", conditionMessage(e)))
    list(discount = NULL, discount_mp = NULL, discount_loser = NULL, n = 0L)
  })
  if (!is.null(.mfd$discount) && is.finite(.mfd$discount)) {
    .minor_disc <- .mfd$discount
    # TWO-RATE, REVISED 2026-09-18: docs/reviews/minor-defector-two-rate-
    # 2026-09-17.md. A confirmed sitting-member switcher gets NO discount at
    # all (leave-one-out cross-validated against all 5 sitting corpus cases:
    # flat 1.0 halves the squared error a fitted rate gets, 0.405 vs 0.782 --
    # n=5 is too thin to fit below 1 usefully). `.minor_disc` here is only
    # the fallback rate for a switcher whose sitting status is unknown.
    # Real today: check whether any of vic2026's 5 known cases (Frankston,
    # Broadmeadows, Lara, Werribee, Sydenham -- see comment above) are
    # sitting-member switches before trusting the live forecast reflects
    # this correctly.
    if (!is.null(.mfd$discount_loser) && is.finite(.mfd$discount_loser)) .minor_disc_loser <- .mfd$discount_loser
  } else {
    cat(sprintf("CAL! minor-defector discount not fit (n=%s), no discount applied\n",
                if (is.null(.mfd$n)) "NULL" else .mfd$n))
  }
}
cat(sprintf("CAL  MP tier: %s | defector discount: %s | minor-defector discount: %s
",
            if (is.null(.MP_SLOPE)) "OFF" else
              paste(sprintf("%s=%.4f", names(.MP_SLOPE), .MP_SLOPE), collapse = " "),
            if (is.null(.defect)) "OFF" else sprintf("%.3f", .defect),
            if (is.null(.minor_disc)) "OFF" else sprintf("%.3f", .minor_disc)))

# THE BASE VALUE, not just the slope -- see personal_prior_vote()'s docs. Same
# candidate-list gating as .returns above: NULL until vic2026 nominations close.
# THIS ONE FEEDS mat22 (the base_pred blend) ONLY -- major_discount matches
# the six harnesses' own base_pred convention. It deliberately carries NO
# minor_discount: AUSPOL_MINOR_DEFECT_BASE_PRED (that arm, not this one) was
# measured and REFUSED for base_pred 2026-09-16 (helped Mirani, made the
# pooled aggregate worse), so base_pred stays byte-identical to before this
# fix regardless of AUSPOL_MINOR_DEFECT.
.own_prev <- if (.cond && !is.null(.returns))
  .try("own_prev", personal_prior_vote(PREV, TGT, major_discount = .defect)) else NULL
# THIS ONE FEEDS xgb_primary_predict_live()'s own_prev_pcv FEATURE ONLY --
# mirrors fit_xgb_primary_v6.R:271's TRAINING call exactly: minor_discount,
# and deliberately NO major_discount (training's xgb feature never gets one
# either -- personal_prior_vote()'s major-defector branch is gated on
# major_discount, which the training call never passes). Serving anything
# else here would itself be a second train/serve mismatch in the opposite
# direction: applying a discount at serve time the model was never trained
# to expect.
.own_prev_xgb <- if (.cond && !is.null(.returns))
  .try("own_prev_xgb", personal_prior_vote(PREV, TGT, minor_discount = .minor_disc, minor_discount_loser = .minor_disc_loser)) else NULL
# THE VOTE MOVES WITH THE PERSON: .own_x() below substitutes a returning
# candidate's own prior vote into their new class; this takes it out of the
# class it came from. No-op until vic2026 nominations exist.
# BY-ELECTION AS THE SEAT BASELINE (AUSPOL_BYELECTION_PRIOR=1): a by-election between the two
# general elections where both majors stood replaces the seat's prior row (R/byelection_prior.R,
# external/reference/byelections/byelection-results.csv). docs/plans/prereg-byelection-prior-2026-09-18.md
if (Sys.getenv("AUSPOL_BYELECTION_PRIOR", "blend") %in% c("1", "blend")) {
  mat22 <- tryCatch(byelection_prior(mat22, PREV, TGT, weight = if (identical(Sys.getenv("AUSPOL_BYELECTION_PRIOR"), "blend")) 0.5 else 1), error = function(e) { cat(sprintf("BF0b! by-election prior FAILED, prior kept: %s\n", conditionMessage(e))); mat22 })
  .by <- attr(mat22, "byelection")
  if (!is.null(.by)) cat(sprintf("BF0b by-election prior: %d seat(s) replaced%s%s\n", length(.by$applied),
                                if (length(.by$applied)) paste0(" (", paste(.by$applied, collapse = ", "), ")") else "",
                                if (length(.by$skipped)) paste0("; SKIPPED ", paste(.by$skipped, collapse = ", ")) else ""))
}
mat22 <- remove_transferred_votes(mat22, .own_prev)
mat22 <- (function(m) {
  # A DEPARTED DEFECTOR'S VOTE GOES HOME (AUSPOL_DEPARTED_ORIGIN: "1" = leave-
  # target-out median share, "mean" = mean). docs/plans/prereg-departed-origin-return-2026-09-18.md
  .dor <- Sys.getenv("AUSPOL_DEPARTED_ORIGIN", "0")
  if (!.dor %in% c("1", "mean")) { if (!.dor %in% c("0", "")) cat(sprintf("BF0o! AUSPOL_DEPARTED_ORIGIN=%s is not a mode (\"1\" or \"mean\") -- treated as OFF\n", .dor)); return(m) }
  .fdo <- tryCatch(fit_departed_origin_return(TGT, stat = if (.dor == "mean") "mean" else "median"),
                   error = function(e) { cat(sprintf("BF0o! departed-origin fit FAILED, nothing routed: %s
", conditionMessage(e))); NULL })
  if (is.null(.fdo) || is.null(.fdo$frac)) { cat(sprintf("BF0o! departed-origin: %d case(s), no rate fitted, nothing routed
", if (is.null(.fdo)) 0L else .fdo$n)); return(m) }
  m2 <- route_departed_origin(m, PREV, TGT, .fdo$frac)
  .a <- attr(m2, "departed_origin")
  cat(sprintf("BF0o departed-origin share %.3f from %d cases (target excluded): %d routed%s
", .fdo$frac, .fdo$n, .a$applied,
              if (length(.a$skipped)) paste0("; SKIPPED ", paste(.a$skipped, collapse = ", ")) else ""))
  m2
})(mat22)
# MAJOR-PARTY SLOPE TIERS: departed member (AUSPOL_MAJOR_DEPARTED, shipped) and every other
# ALP/LNP cell (AUSPOL_MAJOR_SLOPE). docs/plans/prereg-major-departed-slope-2026-09-18.md,
# docs/plans/prereg-major-present-slope-2026-09-18.md
.MAJDEP <- NULL; .MAJPRES <- NULL
if (identical(Sys.getenv("AUSPOL_MAJOR_DEPARTED", "1"), "1") || identical(Sys.getenv("AUSPOL_MAJOR_SLOPE", "1"), "1")) {
  .fmd <- tryCatch(fit_major_departed_slope(TGT), error = function(e) { cat(sprintf("BF0m! major slope fit FAILED, majors keep slope 1: %s\n", conditionMessage(e))); NULL })
  if (!is.null(.fmd)) {
    if (identical(Sys.getenv("AUSPOL_MAJOR_DEPARTED", "1"), "1")) .MAJDEP <- .fmd$slope
    if (identical(Sys.getenv("AUSPOL_MAJOR_SLOPE", "1"), "1")) .MAJPRES <- .fmd$slope_present
    cat(sprintf("BF0m major slopes, target excluded: departed ALP %.3f (n=%d) LNP %.3f (n=%d) [%s] | present ALP %.3f (n=%d) LNP %.3f (n=%d) [%s]\n",
                .fmd$slope[["ALP"]], .fmd$n[["ALP"]], .fmd$slope[["LNP"]], .fmd$n[["LNP"]], if (is.null(.MAJDEP)) "off" else "ON",
                .fmd$slope_present[["ALP"]], .fmd$n_present[["ALP"]], .fmd$slope_present[["LNP"]], .fmd$n_present[["LNP"]], if (is.null(.MAJPRES)) "off" else "ON"))
  }
}
.tr <- attr(mat22, "transfers"); if (!is.null(.tr)) cat(sprintf("DS2t transfers moved with the person: %d applied%s\n", .tr$applied, if (length(.tr$skipped)) paste0("; SKIPPED ", length(.tr$skipped), ": ", paste(utils::head(.tr$skipped, 5), collapse = ", ")) else ""))
if (.cond && !is.null(.returns)) {
  if (is.null(.own_prev)) {
    cat(sprintf("DS2o personal_prior_vote() FAILED -- class-level base kept for every seat%s\n",
                .reason("own_prev")))
  } else {
    cat(sprintf("DS2o personal prior vote ON: %d seat-classes take the returning candidate's own previous share\n",
                sum(is.finite(.own_prev$own_prev_pcv))))
  }
}
# Shared with every harness: own_prev_substitute() (R/candidate_returns.R). A cross-seat
# credit (AUSPOL_CROSS_SEAT_VOTE) can only RAISE the class base, never lower it.
.own_x <- function(p, seats, x) own_prev_substitute(.own_prev, p, seats, x)
# ARM SURGE-V2, ON by default since 2026-09-04 -- see R/salience_surge.R,
# docs/plans/prereg-salience-surge-v2.md, docs/reviews/surge-v2-widened-and-majors-bug-2026-09-04.md,
# docs/reviews/surge-v2-person-level-prevparty-2026-09-04.md,
# docs/reviews/surge-v2-examples-corrected-2026-09-04.md.
# Widened to 9 election pairs / 18 governed winners after fixing three
# governed_population() bugs found in sequence on 2026-09-04: a majors-
# contamination bug, prev_party read as the IND/OTH CLASS's prior vote
# instead of this candidate's own, and a seat-rename bug that unmasked once
# the second fix was applied. Nested LOO log loss 0.0404 vs base-rate 0.0595,
# beats baseline in 7 of 9 elections (fed2013 and vic2022 are each a small
# wash on a single governed winner). SAME
# candidate-list gating as arm CS above: vic2026 has no salience corpus until
# nominations close, so this falls back to flat SURGE_H (default 0) until then,
# printed rather than silent -- so this flip is a no-op on the published
# Victoria forecast today and activates automatically once vic2026 candidate
# salience is fetched (nominations close 12 noon, 9 Nov 2026).
.surge_v2_on <- identical(Sys.getenv("AUSPOL_SALIENCE_SURGE_V2", "1"), "1")
surge_arg <- as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0"))
surge_party_arg <- NULL
surge_mu_arg <- 15.6; surge_sd_arg <- 6.1
if (.surge_v2_on) {
  .v2_train_pairs <- list(
    list(election = "fed2010", prev = "fed2007", region = "fed"),
    list(election = "fed2013", prev = "fed2010", region = "fed"),
    list(election = "fed2016", prev = "fed2013", region = "fed"),
    list(election = "fed2019", prev = "fed2016", region = "fed"),
    list(election = "fed2022", prev = "fed2019", region = "fed"),
    list(election = "vic2022", prev = "vic2018", region = "vic"),
    list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
    list(election = "sa2026",  prev = "sa2022",  region = "sa"),
    list(election = "wa2008",  prev = "wa2005",  region = "wa"))
  .hz <- .try("hz", surge_hazard_for(TGT, PREV, REGION, .v2_train_pairs))
  if (is.null(.hz)) {
    cat(sprintf(sub("@T", TGT, "DS3  surge-v2 requested but @T has no salience corpus yet -- FALLING BACK to flat surge_h%s\n", fixed = TRUE),
                .reason("hz")))
  } else {
    # `shares` does not exist yet at this point in the script -- it is first
    # created at `shares <- mat22` further down. This branch was DEAD until a
    # real vic2026 salience corpus existed (previously .hz was always NULL
    # here), so the bug was never exercised: it would have crashed the
    # published forecast the day real candidate salience data became
    # available (nominations close 9 Nov 2026), unrelated to anything else.
    # Seat names are identical to what `shares` will have (shares <- mat22,
    # unchanged since), so mat22's rownames are the correct, already-defined
    # substitute.
    sn <- rownames(mat22)
    if (is.null(sn) && is.data.frame(shares)) sn <- as.character(shares$seat)
    v <- setNames(.hz$seat_hazard$surge_h, .hz$seat_hazard$seat)[sn]
    miss <- sum(is.na(v)); v[is.na(v)] <- 0
    surge_arg <- unname(v); surge_mu_arg <- .hz$surge_mu; surge_sd_arg <- .hz$surge_sd
    if (identical(Sys.getenv("AUSPOL_SURGE_RECIPIENT", "1"), "1") && !is.null(.hz$seat_recipient)) {
      # THE SURGE GOES TO THE CLASS THE HAZARD WAS FITTED FOR (prereg-surge-recipient-2026-09-06.md).
      surge_party_arg <- unname(setNames(.hz$seat_recipient$party, .hz$seat_recipient$seat)[sn])
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
    cat(sprintf("DS3  surge-v2 hazard for %d of %d seats (%d absent -> 0) | mean %.4f | mu %.2f sd %.2f | lambda %.1f | train winners %d\n",
                length(sn) - miss, length(sn), miss, mean(surge_arg),
                surge_mu_arg, surge_sd_arg, .hz$lambda, .hz$n_train_winners))
  }
}
# DISPERSION SLOPE (AUSPOL_DISPERSION_SLOPE=1, default OFF -- unset
# reproduces this forecast byte-for-byte). Replaces the flat "new"-candidate
# constant with corr(class) x sd-ratio(class, level), fit leave-target-out;
# see fit_dispersion_slopes() and docs/plans/prereg-dispersion-slope-2026-09-09.md.
# level_now is the FORECAST state_mean, not an actual result -- vic2026 has
# not happened -- which is exactly what fit_dispersion_slopes()'s level_now
# argument exists for.
.fitsl <- if (identical(Sys.getenv("AUSPOL_DISPERSION_SLOPE", "0"), "1")) {
  # vic2026 is not in all_election_pairs() (it names completed elections
  # only); add it here so the target's own "prev" seat history (vic2022) is
  # found, same as .returns above handles the same gap for candidate_returns().
  .try("fitsl", fit_dispersion_slopes(TGT, level_now = state_mean,
                                       pairs = c(all_election_pairs(),
                                                 list(list(election = TGT, prev = PREV)))))
} else if (identical(Sys.getenv("AUSPOL_FIT_SLOPES", "0"), "1")) {
  .try("fitsl", fit_conditional_slopes(TGT))
} else NULL
.slope_arm_requested <- identical(Sys.getenv("AUSPOL_DISPERSION_SLOPE", "0"), "1") ||
  identical(Sys.getenv("AUSPOL_FIT_SLOPES", "0"), "1")
if (!is.null(.fitsl)) {
  cat(sprintf("FS1  fitted slopes | same %s | new %s%s\n",
    paste(sprintf("%s=%.3f", names(.fitsl$same), .fitsl$same), collapse=" "),
    paste(sprintf("%s=%.3f", names(.fitsl$new),  .fitsl$new),  collapse=" "),
    if (!is.null(.fitsl$n)) sprintf(" | n_pairs %s",
      paste(sprintf("%s=%d", .fitsl$n$class, .fitsl$n$n_pairs), collapse=" ")) else " | n_pairs unavailable (fallback constants, nothing fitted)"))
} else if (.slope_arm_requested) {
  # .try() records a thrown error into .why; this branch fires on the OTHER
  # failure shape -- the call returned NULL/threw without .try capturing a
  # message, or ran and every class fell back internally. Either way, this
  # must be visible: a silent success-only branch here is the exact "guard
  # that can't fail" pattern that let a real bug print nothing, indistinguishable
  # from "the arm is simply off."
  cat(sprintf("FS1! fitted-slope arm requested but produced no result%s -- falling back to shipped constants\n",
              .reason("fitsl")))
}
.vic_slope <- function(p, seats) {
  if (.screened && !is.null(.permit) && !is.null(.returns)) {
    pv <- .permit[.permit$party == p, ]
    lut <- .permit_lut(pv)
    pm <- unname(lut[seats]); # a missing permit row is NOT a permit (NA = silent; 2026-09-20)
    return(screened_slopes(p, seats, .returns, pm, same_mp = .MP_SLOPE, major_departed = .MAJDEP, major_present = .MAJPRES,
                            honour_departed = .honour_departed, with_flags = .departed_hold, successor_rate = .SUCC_RATE,
                            same = if (is.null(.fitsl)) formals(screened_slopes)$same else .fitsl$same,
                            new  = if (is.null(.fitsl)) formals(screened_slopes)$new  else .fitsl$new))
  }
  if (.cond && !is.null(.returns))
    return(conditional_slopes(p, seats, .returns, same_mp = .MP_SLOPE, major_departed = .MAJDEP, major_present = .MAJPRES,
                               same = if (is.null(.fitsl)) formals(conditional_slopes)$same else .fitsl$same,
                               new  = if (is.null(.fitsl)) formals(conditional_slopes)$new  else .fitsl$new))
  SLOPE[[p]]
}

# RE-ENTRY PRIOR (AUSPOL_REENTRY, default "0" = off; never decided, plans/prereg-reentry-prior-2026-09-07.md).
# A class contesting a seat now that did not contest it in 2022 has no base, so
# swinging zero forward leaves ~0 (vic2022 Richmond Liberals: predicted 0.0, actual
# 18.8). The cells are identified HERE, pre-swing, while mat22 still shows which are
# empty, fitted time-forward (reentry_apply_harness -> fit_pairs_for("vic2026")), and
# landed POST-swing below with protect_personal_vote_cells(), the same shape as the
# six backtest harnesses. Who is standing comes from the live nomination list
# (AUSPOL_NOM_LIVE=1); without one nothing is filled, and that is printed.
# Switch "0": this block is skipped and .re_cells stays NULL, so nothing below changes.
.re_cells <- NULL
if (!identical(reentry_mode(), "0")) {   # "1" general prior (refused) | "majors" own history
  .re_sl <- tryCatch(reentry_standing_live(rownames(mat22), TGT, PREV),
                     error = function(e) list(standing = NULL, reason = conditionMessage(e)))
  # "majors" only FILLS a major that stands now, never zeroes, so the provisional
  # list is safe before nominations close (Narracan 2026 Labor: 4.4% without it).
  if (is.null(.re_sl$standing) && identical(reentry_mode(), "majors")) {
    cat(sprintf("BV1r  full nomination list unavailable (%s); majors carry uses the provisional list\n", .re_sl$reason))
    .re_sl <- reentry_standing_provisional(rownames(mat22), TGT)
    cat(sprintf("BV1r  %s\n", .re_sl$reason))
  }
  if (is.null(.re_sl$standing)) {
    cat(sprintf("BV1r!! AUSPOL_REENTRY=%s but no live nomination list (%s): re-entry prior NOT applied\n", reentry_mode(), .re_sl$reason))
  } else {
    # statewide share per class: the trend's classes as forecast, the unmodelled
    # minor classes scaled with OTH exactly as the minor-field block below scales them
    .re_state <- state_mean
    .re_un <- setdiff(colnames(mat22), names(state_mean))
    if (length(.re_un) && !is.na(state_mean["OTH"])) {
      .re_sc <- state_mean[["OTH"]] / sum(a22[c(.re_un, "OTH")], na.rm = TRUE)
      .re_state <- c(.re_state, setNames(a22[.re_un] * .re_sc, .re_un))
    }
    .re_cells <- attr(reentry_apply_harness(mat22, fp, .re_sl$standing, .re_state,
                                            target = TGT, pairs = all_election_pairs(),
                                            code = "BV1r"), "reentry")
  }
}

parties <- colnames(mat22)
shares <- mat22
HELD <- matrix(FALSE, nrow(mat22), ncol(mat22), dimnames = dimnames(mat22))
modelled <- intersect(parties, names(state_mean))
for (p in setdiff(modelled, "ONP")) {
  # At SLOPE 1 (the fallback) this is mat22 + (state_mean - a22), unchanged.
  .sl <- .vic_slope(p, rownames(mat22)); .hd <- attr(.sl, "departed"); if (.departed_hold && !is.null(.hd)) HELD[, p] <- ((.hd %in% TRUE) & (mat22[, p] >= .hold_min)) %in% TRUE
  shares[, p] <- dev_slope(.own_x(p, rownames(mat22), mat22[, p]), a22[[p]], state_mean[[p]], .sl)
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
  # THE MULTIPLICATIVE PATH NEEDS THE SLOPE TOO, and it is the one that carries
  # IND -- the class with the worst seat-level error in the corpus (RMSE ~7.2,
  # double every other class) and the second-lowest slope. Applying the slope to
  # the additive path alone would have left independents on uniform swing while
  # claiming the model had been changed, which is the "fix one harness, miss the
  # others" failure in a single file.
  #
  # Shrink toward the class's own scaled statewide level, so at SLOPE 1 this is
  # exactly mat22[, p] * scale_to as before.
  for (p in c(unmodelled, if ("OTH" %in% modelled) "OTH")) {
    tgt <- a22[[p]] * scale_to
    .sl <- .vic_slope(p, rownames(mat22)); .hd <- attr(.sl, "departed"); if (.departed_hold && !is.null(.hd)) HELD[, p] <- ((.hd %in% TRUE) & (mat22[, p] >= .hold_min)) %in% TRUE
    shares[, p] <- dev_slope(.own_x(p, rownames(mat22), mat22[, p]) * scale_to, tgt, tgt, .sl)
  }
  cat(sprintf("minor field scaled x%.2f: %s at 2022 %.1f%% -> forecast %.1f%%
",
              scale_to, paste(c(unmodelled, "OTH"), collapse = "+"),
              base_share, state_mean[["OTH"]]))
}
# Re-entry prior lands here, on the POST-swing projection (see BV1r above): the
# prediction is a target-election share, so it must not be swung a second time.
# protect_personal_vote_cells() keeps .own_prev's identity-matched defector floor.
# An ONP cell is overwritten by the ONP allocation below, so it is counted but moot.
if (!is.null(.re_cells) && nrow(.re_cells)) {
  .rc <- protect_personal_vote_cells(.re_cells, .own_prev)
  .ri <- cbind(match(.rc$seat, rownames(shares)), match(.rc$party, colnames(shares)))
  .rk <- stats::complete.cases(.ri)
  shares[.ri[.rk, , drop = FALSE]] <- .rc$value[.rk]
  cat(sprintf("BV1r  re-entry applied post-swing to %d cell(s)%s%s\n", sum(.rk),
              if (nrow(.re_cells) - nrow(.rc)) sprintf(" | %d protected by own_prev", nrow(.re_cells) - nrow(.rc)) else "",
              if (any(.rc$party[.rk] == "ONP")) " | ONP cells are then overridden by the ONP allocation" else ""))
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
stopifnot(ONP_ORDER %in% c("federal", "greens", "senate"))
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
  if (.departed_hold && any(HELD[, other_cols, drop = FALSE])) {
    # Held cells (a departed leader's decayed class) keep their value; only the
    # others are scaled to fill what ONP and the held cells leave.
    # docs/plans/prereg-departed-hold-fixed-2026-10-04.md
    hld <- HELD[, other_cols, drop = FALSE]
    rest <- rowSums(shares[, other_cols, drop = FALSE] * !hld)
    fill <- pmax(0, 100 - onp_target - rowSums(shares[, other_cols, drop = FALSE] * hld)) / pmax(rest, 1e-9)
    for (p in other_cols) shares[, p] <- ifelse(HELD[, p], shares[, p], shares[, p] * fill)
  } else
  for (p in other_cols) shares[, p] <- shares[, p] * fill
}
shares[, "ONP"] <- onp_target
if (.departed_hold) {
  shares <- renorm_hold(shares, HELD)
  cat(sprintf("DH0  departed hold: %d cell(s) held in %d seat(s)%s\n", sum(HELD), sum(rowSums(HELD) > 0),
              if (length(attr(shares, "skipped"))) paste0(" | not held (others zero or hold >= 100): ", paste(attr(shares, "skipped"), collapse = ", ")) else ""))
  attr(shares, "skipped") <- NULL
  if (nzchar(Sys.getenv("AUSPOL_DEPARTED_HOLD_DUMP"))) { .w <- which(HELD, arr.ind = TRUE); utils::write.csv(data.frame(seat = rownames(HELD)[.w[, 1]], party = colnames(HELD)[.w[, 2]]), Sys.getenv("AUSPOL_DEPARTED_HOLD_DUMP"), row.names = FALSE) }   # which cells were held, for the scoring script
} else shares <- 100 * shares / rowSums(shares)
# XGBOOST PRIMARY CHALLENGER, v6 (AUSPOL_XGB_PRIMARY_LIVE). Best pooled seat
# log loss of v1-v6, leave-one-pair-out: 0.3403 -> ~0.3071
# (R/xgb_primary_override.R's own docstring carries the full detail and the
# ship-decision record -- read that, not this comment, for the current
# state). KNOWN, NOT fixed: worse than this model specifically on rare
# independent/minor-party emergences -- SA2026 One Nation and vic2014 both
# regress -- which is what a One Nation surge in Victoria is. Tracked in
# docs/NEXT-STEPS.md as the active improvement queue, not a blocker to
# shipping. Wrapped in .try(), same as every other pre-nomination-dependent
# feature in this script (.returns/.permit/.own_prev above) -- this now runs
# inside the published forecast, so an unhandled error here would otherwise
# crash the whole run rather than falling back to the shipped-only model.
# AUSPOL_NEW_IND_SHRINK (POST-XGB, shipped "1"): a nameless first-time sole
# independent is over-called at base. Lands here, before the base reaches the
# trees as base_margin, the same point as the re-entry fill. R/new_ind_shrink.R.
# Wrapped like every other optional input here: a missing features file must not
# crash the daily forecast, and the fallback is printed, not silent.
.nis <- .try("new_ind", new_ind_shrink_apply(shares, TGT, code = "BV1n"))
if (!is.null(.nis)) shares <- .nis else if (!identical(new_ind_mode(), "0"))
  cat(sprintf("BV1n!! new_ind_shrink_apply() FAILED%s -- the new-independent shrink is NOT applied to this forecast\n",
              .reason("new_ind")))
shares_x <- .try("xgb_live", xgb_primary_predict_live(shares, mat22, a22, state_mean, .returns,
                                                        own_prev = .own_prev_xgb, region = REGION,
                                                        year = YEAR, prev_year = as.integer(sub("^[a-z]+", "", PREV))))
if (!is.null(shares_x)) {
  shares <- shares_x
} else if (identical(Sys.getenv("AUSPOL_XGB_PRIMARY_LIVE", "1"), "1")) {
  cat(sprintf("XG4!! xgb_primary_predict_live() FAILED%s -- shares UNCHANGED, shipped-only model used\n",
              .reason("xgb_live")))
}
# (v61 nomination zeroing runs after blend_salience_shares() below, the last step
# that can add share to a cell -- see the NZL block there.)
# Time-forward seat-swing port (AUSPOL_SEAT_SWING_PORT=2), AFTER the override,
# which would otherwise overwrite it. plans/prereg-seat-swing-port-v2-2026-09-29.md
.shares_p <- .try("seat_swing_port", seat_swing_port_apply(shares, TGT))
if (!is.null(.shares_p)) {
  shares <- .shares_p
} else if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "2"), "2")) {
  cat(sprintf("SP2!! seat-swing port FAILED%s -- shares UNPORTED, the published forecast is not v48
",
              .reason("seat_swing_port")))
}
.shares_b <- .try("seat_poll_blend", seat_poll_blend_apply(shares, TGT))
if (!is.null(.shares_b)) {
  shares <- .shares_b
} else if (Sys.getenv("AUSPOL_SEAT_POLL_BLEND", "1") %in% c("1", "2", "3")) {
  cat(sprintf("SPB!! seat-poll blend FAILED%s -- shares UNBLENDED
", .reason("seat_poll_blend")))
}
# Demographic correction (AUSPOL_DEMO_RESID=2: Labor and Greens), same position
# as in the harnesses. plans/prereg-demographic-labor-greens-2026-09-29.md
.shares_d <- .try("demo_resid", if (Sys.getenv("AUSPOL_DEMO_RESID", "2") %in% c("1", "2"))
  demographic_residual_apply(shares, TGT) else shares)
if (!is.null(.shares_d)) {
  shares <- .shares_d
} else {
  cat(sprintf("DR1!! demographic correction FAILED%s -- shares WITHOUT it\n", .reason("demo_resid")))
}
# Leader-seat bonus then departed-member blend (AUSPOL_DEPARTED_FED), same order
# as the harnesses. plans/prereg-departed-fed-booths-2026-09-30.md
# Leader-seat bonus (AUSPOL_LEADER_SEAT), same position as in the harnesses
# relative to the seat-poll blend. plans/prereg-leader-seat-2026-09-29.md
.shares_l <- .try("leader_seat", leader_seat_apply(shares, TGT))
if (!is.null(.shares_l)) {
  shares <- .shares_l
} else if (identical(Sys.getenv("AUSPOL_LEADER_SEAT", "1"), "1")) {
  cat(sprintf("LS1!! leader-seat bonus FAILED%s -- shares WITHOUT it\n", .reason("leader_seat")))
}
.shares_f <- .try("departed_fed", departed_fed_apply(shares, TGT))
if (!is.null(.shares_f)) {
  shares <- .shares_f
} else if (!identical(Sys.getenv("AUSPOL_DEPARTED_FED", "0"), "0")) {
  cat(sprintf("DF1!! departed-member blend FAILED%s -- shares WITHOUT it
", .reason("departed_fed")))
}
# THE SALIENCE POINT ESTIMATE REACHES THE PUBLISHED FORECAST, 2026-09-07.
# It never had: the blend lived inline in the federal harness only, so every
# figure this script published described a model without it while the federal
# backtest measured one with it. No-op until vic2026 has a salience corpus
# (.hz is NULL before nominations close), which is why this could sit unnoticed.
.exp_mode <- suppressWarnings(as.integer(Sys.getenv("AUSPOL_SALIENCE_EXPECTED", "0")))
if (is.na(.exp_mode)) .exp_mode <- 0L
shares <- blend_salience_shares(shares, if (exists(".hz")) .hz else NULL, surge_mu_arg[1],
                                expected = .exp_mode > 0L)
cat(sprintf("DS3b salience point estimate applied to %d (seat,party) cells%s\n",
            attr(shares, "cells"),
            if (is.null(if (exists(".hz")) .hz else NULL)) sub("@T", TGT, " (no corpus for @T yet)", fixed = TRUE) else ""))
# v61 NOMINATION ZEROING, AFTER every step that can add share to a cell, with the
# live flow matrix `fm`. Read from the function bodies 2026-10-03:
#   CAN add share to a cell (pmax(0, x + adj), a blend toward a target, or a shift
#   onto the leader's class): seat_swing_port_apply (ALP/LNP), demographic_residual_apply,
#   leader_seat_apply (.shift_cell on the leader's class), blend_salience_shares
#   (surge blend; pmax(shares, expected)).
#   CANNOT (only touch cells already > 0, and rescale rows, so a 0 stays 0):
#   seat_poll_blend_apply (all three modes), departed_fed_apply.
# blend_salience_shares is the last step, so this sits straight after it. Placed
# earlier (before the port), a positive adj revived a zeroed Labor cell.
# A no-op, logged as NZL, unless AUSPOL_NOM_LIVE=1; with =1 any failure STOPS the
# run. plans/prereg-nomination-zero-2026-10-03.md
.nz_before <- shares
shares <- tryCatch(zero_unnominated_live(shares, fm, TGT, prior = PREV), error = function(e) {
  if (nom_zero_requested()) stop(conditionMessage(e), call. = FALSE)
  cat(sprintf("NZL!! nomination zeroing FAILED (%s) -- shares WITHOUT it\n", conditionMessage(e)))
  .nz_before
})
.nz_cells <- nomination_zeroed_cells(.nz_before, shares)
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
  # NULL TARGET ON PURPOSE: this is the live forecast. Victoria 2026 has not
  # happened, so no pair in the fit is the one being predicted and there is
  # nothing to leave out. The backtests pass their target and get a
  # leave-one-out matrix; withholding data here would be superstition rather
  # than hygiene. See docs/plans/prereg-statewide-cov-loo-2026-09-07.md.
  cm <- statewide_cor(NULL, mode = if (identical(COR_MODE, "raw")) "raw" else "shrunk")
  cat(sprintf("COV  statewide correlation: %s
", attr(cm, "cor_source")))
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
# LL3. THE OTHERS BUCKET WAS COUNTED TWICE HERE: state_mean[["OTH"]] is the
# whole unpolled total, which the seat shares above split into OTH, IND and
# OTH_RIGHT (scale_to), yet the draws took the WHOLE total for OTH and added
# IND and OTH_RIGHT on top -- ~7 points renormalised away, shrinking every
# class's spread and putting the draws' two-party ~1 point off the level
# (LL2 read -1.0 with the level anchored). The backtests split the bucket
# with its total preserved (R/forecast_statewide.R), so this is the same
# recipe. docs/plans/prereg-live-level-anchor-2026-09-28.md (amendment).
DRAW_BUCKET_FIX <- identical(Sys.getenv("AUSPOL_LIVE_DRAW_BUCKET", "1"), "1")
if (DRAW_BUCKET_FIX && length(unmodelled) && !is.na(state_mean["OTH"])) {
  for (p in intersect(c(unmodelled, "OTH"), parties)) mu[[p]] <- a22[[p]] * scale_to
  if (!all(is.finite(mu))) stop("LL3: a bucket class has no 2022 share to split by: ",
                                paste(names(mu)[!is.finite(mu)], collapse = ", "))
  cat(sprintf("LL3  others bucket in the draws split, not double-counted: %s (sum %.2f = state OTH %.2f)\n",
              paste(sprintf("%s %.2f", intersect(c(unmodelled, "OTH"), parties),
                            mu[intersect(c(unmodelled, "OTH"), parties)]), collapse = ", "),
              sum(mu[intersect(c(unmodelled, "OTH"), parties)]), state_mean[["OTH"]]))
}
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
# AUSPOL_ANCHOR_IMPLIED=1 (arm, plans/prereg-anchor-implied-tpp-2026-09-20.md):
# the mix's trend input becomes the two-party these draws already imply, not
# the trend's published TPP series, so the anchoring applies only the
# fundamentals' pull. Same change as R/forecast_mode.R, minus its phantom-vote
# half: here an unpolled class draws around its seat mean (line ~1141), not 0.
if (identical(Sys.getenv("AUSPOL_ANCHOR_IMPLIED", "0"), "1")) {
  pj_pub <- pj
  pj <- project_result(mean(implied), fund_now, mix, days_out)
  cat(sprintf(sub("@T", TGT, "AI2  @T: mix trend input = implied %.2f (published TPP %.2f); projection %.2f -> %.2f\n", fixed = TRUE),
              mean(implied), now$tpp, pj_pub$mean, pj$mean))
}
target <- stats::rnorm(N_SIMS, pj$mean, pj$sd)
# AUSPOL_ANCHOR_EXHAUST=1: implied two-party net of exhausted ballots, as in
# R/forecast_mode.R (plans/prereg-anchor-exhaust-2026-09-27.md). Victoria's
# flows carry no exhaust, so this is inert here by construction; it is wired
# so the live and backtest anchoring stay one recipe.
ex_share <- .exhaust_shares(fl, minors)
if (identical(Sys.getenv("AUSPOL_ANCHOR_EXHAUST", "0"), "1") && any(ex_share > 0)) {
  lost <- vapply(minors, function(p) sw_draws[, p] * ex_share[[p]], numeric(N_SIMS))
  den <- 100 - rowSums(lost)
  implied <- 100 * (implied - rowSums(sweep(lost, 2, vapply(minors, flow_of, 1), "*"))) / den
  d <- (target - implied) * den / 100
} else {
  d <- target - implied
}
# With LL1 on, the level already implies the projection, so this mean shift
# should be ~0; with it off it is the whole trend-to-projection gap.
cat(sprintf("LL2  draws' anchoring mean shift %+.3f (LL1 %s)\n", mean(d),
            if (LEVEL_ANCHOR) "on" else "off"))
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

# SCENARIO RESPONSE. How each class gives way when one party's statewide vote
# moves, measured on THESE draws: beta = cov(other, moved) / var(moved), with the
# OTH, IND and OTH_RIGHT columns summed into the trend's OTH class. Rows sum to
# 100, so each moved party's betas sum to exactly -1. Written on every run;
# AUSPOL_FORCE_FP_RULE="draws" reads the unsuffixed (published) copy. Pete's
# choice for the what-if slider, plans/scenario-tool-scoping-2026-10-03.md 5b.
.draw_class <- ifelse(parties %in% setdiff(modelled, "OTH"), parties, "OTH")
.betas <- rbindlist(lapply(intersect(c("ALP", "LNP", "GRN", "ONP"), parties), function(p) {
  b <- vapply(parties, function(j) stats::cov(sw_draws[, j], sw_draws[, p]) /
                stats::var(sw_draws[, p]), numeric(1))
  b <- b[parties != p]
  data.table(moved = p, class = .draw_class[parties != p], beta = b)[
    , .(beta = sum(beta)), by = .(moved, class)]
}))
.bsum <- .betas[, .(s = sum(beta)), by = moved]
if (any(abs(.bsum$s + 1) > 1e-6)) stop("FP2: scenario betas do not sum to -1: ",
                                       paste(.bsum$moved, round(.bsum$s, 4), collapse = ", "))
fwrite(.betas, sprintf("output/statewide-draw-betas-%s%s.csv", TARGET$out_stem, OUT_SUFFIX))
cat(sprintf("FP2  per point of ONP: %s\n", paste(sprintf("%s %+.3f",
            .betas[moved == "ONP"]$class, .betas[moved == "ONP"]$beta), collapse = ", ")))
# HOLD THE FORCED PARTY EXACTLY AT X (Pete, 5a): zero statewide spread for it,
# and every other column takes its regression residual, which is the Gaussian
# conditional given that party's level. Row sums stay 100.
if (FORCE_HOLD_EXACT) {
  for (fp_party in .forced_parties) {
    sp <- sw_draws[, fp_party] - mean(sw_draws[, fp_party])
    for (j in setdiff(parties, fp_party)) {
      sw_draws[, j] <- sw_draws[, j] -
        stats::cov(sw_draws[, j], sw_draws[, fp_party]) / stats::var(sw_draws[, fp_party]) * sp
    }
    sw_draws[, fp_party] <- mean(sw_draws[, fp_party])
    if (max(abs(rowSums(sw_draws) - 100)) > 1e-6) stop("FP3: holding ", fp_party,
      " broke the draws' row sums (max error ", signif(max(abs(rowSums(sw_draws) - 100)), 3), ")")
    cat(sprintf("FP3  %s held at %.2f in every draw (sd 0); rows sum %.2f-%.2f\n", fp_party,
                sw_draws[1, fp_party], min(rowSums(sw_draws)), max(rowSums(sw_draws))))
  }
}

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
# Set AUSPOL_SHRINK=0 to reproduce the pre-2026-08-21 forecast exactly, and
# AUSPOL_SHRINK=0.10 for the 2026-08-21..2026-09-06 published value.
#
# LOWERED 0.10 -> 0.02 ON 2026-09-06. A scalar shrink caps EVERY seat at
# 1 - shrink/2, so 0.10 meant no seat could be called above 0.95. Measured on
# the federal output: max p was 0.9505 and 19 of 150 seats sat against that
# ceiling, each paying -log(0.95) = 0.051 where -log(0.99) = 0.010 was
# available -- about 0.006 of mean log loss spent on the cap alone.
#
# Swept on fed2025 (forecast mode, screened slopes): 0.10 -> 0.3042,
# 0.05 -> 0.2933, 0.02 -> 0.2891, 0.00 -> 0.2914. Three seeds at 0.02 give
# 0.2891 / 0.2899 / 0.2867, mean 0.2886 against AE Forecasts' 0.3025.
#
# Validated election-wide before shipping, because shrink is a GENERAL
# parameter and was tuned on one election:
#   federal, 6 pairs   mean log 0.4154 -> 0.4047, better in 5 of 6, Brier in 6 of 6
#   Victoria           mean log 0.3020 -> 0.2997, Brier 0.0789 -> 0.0761
#   NSW                0.4062 -> 0.3822, Brier 0.0947 -> 0.0936
#   SA                 0.3976 -> 0.3857, Brier 0.1272 -> 0.1255
#   WA                 accuracy 87.0% -> 87.3%, Brier 0.0984 -> 0.0986 (flat)
# fed2013 is the one log-loss regression (+0.0359) and its Brier still improves,
# so it is a confidence effect rather than a loss of correctness.
#
# LOWERED AGAIN 0.02 -> 0.01 on 2026-09-06, on Pete's rule that this is a hack
# and should sit at the lowest value that survives the evidence, rising only for
# a benefit that is actually significant. Six federal pairs, seed 42:
#   0.10 mean log 0.4154 | 0.02 0.4047 | 0.01 0.4096 | 0.00 0.4282
#   mean Brier            0.1000       | 0.0983      | 0.0982      | 0.0983
# 0.02's 0.005 edge over 0.01 is one seed on six pairs and is NOT established as
# significant; 0.01 has the best mean Brier of the four. On fed2025 the three
# low values are indistinguishable (0.2891 / 0.2898 / 0.2914) and all beat AE
# Forecasts' 0.3025.
#
# Why it stays NON-ZERO, which is the one thing the evidence refuses: shrink
# absorbs a non-major taking a seat called safe for a major, and 0.00 costs
# 0.0235 of mean log loss against 0.02, concentrated in fed2013 (+0.0975) and
# fed2022 (+0.0243). That risk is invisible on fed2025, which is a well-behaved
# election -- tuning this on fed2025 alone would have turned it off and taken
# the fed2013 blow-up unseen.
#
# EXPECTED TO BE SUPERSEDED. AUSPOL_INSURGENCY_SHRINK gives each seat its OWN
# fitted risk, so most seats get zero and only seats with a non-major in reach
# pay anything -- the outcome this scalar approximates badly. Partial six-pair
# numbers had it ahead of every scalar on fed2013 (0.3966-0.4092 against 0.4543).
# See docs/NEXT-STEPS.md; it was not finished in this session.
SHRINK <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0.01"))
if (SHRINK > 0) cat(sprintf("CAL  calibration shrink %.2f applied
", SHRINK))
# XGBOOST PREFERENCE FLOWS (AUSPOL_XGB_FLOWS). Per-seat conditional flow
# dictionaries replacing the lookup table's, consulted before it rather than
# instead of it -- a key the model does not supply still falls back exactly as
# before. Worth -0.0068 pooled seat log loss on top of the xgb primary
# (0.3069 -> 0.3001) across all 22 pairs, better in 12 of 22.
#
# SHIPPED 2026-09-11 with its weaknesses named rather than buried, and the
# headline is NOT significant: t = -1.67, p = 0.111 clustered on pairs. It goes
# in on the same standing rule as the primary -- overall better, one or two
# regressions acceptable -- not because it cleared a bar.
#
#   - wa2001 REGRESSES (+0.048) and that is EXPECTED, not a mystery to chase
#     later: it has no transfer file of its own, so it never enters the flow
#     training corpus at all.
#   - fed2016 regresses (+0.035) and that is VARIANCE, not a defect. A per-class
#     bias correction was proposed, dry-run, and REFUSED -- it fixed the global
#     bias and made the per-election two-party bias worse, because that bias
#     swings sign and is unpredictable (r = 0.282, p = 0.242 against the
#     previous election in the same jurisdiction).
#
# For vic2026 there is no leave-one-out model and there cannot be -- the
# election has not happened, so it is not in the corpus and the all-data model
# has not seen it. That is the correct artifact for a live forecast, and
# R/xgb_flow_override.R says so explicitly rather than warning about leakage.
#
# .try() for the same reason as xgb_primary_predict_live() above: this depends
# on pre-nomination candidate data, and an unhandled error here would crash the
# published run instead of falling back to the shipped flow table.
# docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md
.cond_ov <- NULL
if (identical(Sys.getenv("AUSPOL_XGB_FLOWS", "1"), "1")) {
  .cond_ov <- .try("xgb_flows", xgb_flow_conditional_override_for(shares, TGT, PREV, REGION))
  if (is.null(.cond_ov))
    cat(sprintf("XF4!! xgb_flow_conditional_override_for() FAILED%s -- flows UNCHANGED, shipped lookup table used\n",
                .reason("xgb_flows")))
}
# HOW-TO-VOTE CARD (AUSPOL_HTV_FLOW=1): the Liberal-excluded, ALP+GRN-alive flow rows follow the recorded
# card order for this election (R/htv_flow.R, external/reference/htv/liberal-alp-grn-order.csv).
.htv_ov <- if (identical(Sys.getenv("AUSPOL_HTV_FLOW", "1"), "1")) tryCatch(htv_flow_override(.cond_ov, fm, TGT, rownames(shares)),
  error = function(e) { cat(sprintf("HTV9! how-to-vote override FAILED, flow rows unchanged: %s\n", conditionMessage(e))); .cond_ov }) else .cond_ov
# BREAKOUT MIXTURE (AUSPOL_BREAKOUT_MIX, R/breakout_mix.R): NULLs when off.
# Live, the classifier reads the feature rows xgb_primary_predict_live() built.
.bo <- breakout_mix_args(TGT, shares)
sim <- simulate_seat_contests(level_sd = .level_sd, level_mult = .lm(shares), shares, fm, party_sd = psd, seat_sd = SEAT_SD, shrink = SHRINK,
                              breakout_p = .bo$p, breakout_q = .bo$q,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED,
                              conditional_override = .htv_ov, conditional_override_sd = attr(.htv_ov, "sd"),
                              statewide_draws = sw_draws,
                              fallback_smooth = FB_SMOOTH, shrink_k = SHRINK_K, flow_sd = FLOW_SD,
                              surge_h = surge_arg, surge_party = surge_party_arg,
                              surge_from_zero = identical(Sys.getenv("AUSPOL_SURGE_FROM_ZERO", "0"), "1"), surge_mu = surge_mu_arg, surge_sd = surge_sd_arg,
                              keep_fp = TRUE)   # per-seat ranges for the page; draws no random number
cat(sprintf("S6e  engine %s | surge recipient fell back: %d class(es) absent, %d seat-draws at zero share\n", sim$engine, sim$surge_recipient_fallback, sim$surge_recipient_fallback_draws))
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
# ---- S5, the seat-total sanity check ---------------------------------------
# THIS USED TO CALL simulate_seats() -- the RETIRED two-party seat model -- and
# compare its ALP total against the candidate model's. CLAUDE.md forbids exactly
# that: "Anything it can still do that the candidate model cannot gets PORTED,
# then the two-party version is deleted. Not kept as a cross-check." It was
# being kept as a cross-check, in the published script.
#
# What that check was FOR is worth keeping: a bug once left the two medians
# agreeing while the RANGES disagreed, so a check on the median alone would have
# missed it. What it needed a second model for was a reference range.
#
# It does not need one. Two identities tie a set of per-seat win probabilities
# to the distribution of the seat total, and the simulation must satisfy both
# whatever model produced it:
#
#   1. The expected total IS the sum of the per-seat probabilities. Exactly --
#      the total is a sum of Bernoulli indicators, and expectation is linear
#      regardless of how strongly the seats correlate.
#   2. The total's variance is AT LEAST the independent-seat variance,
#      sum p(1-p). Seats here share a statewide draw, so they are positively
#      correlated, and positive correlation can only ADD variance. A total
#      tighter than the independence floor is arithmetically impossible and is
#      precisely the "range too narrow" bug the old check caught by accident.
#
# Both are properties of the candidate model alone. The reference is arithmetic
# rather than another model, which makes this a stronger check than the one it
# replaces as well as a rule-compliant one.
# The arithmetic lives in check_seat_totals(), which has tests proving it fails
# on each thing it exists to catch -- totals centred where the probabilities do
# not imply, and a spread below the independence floor. An inline copy here
# could not be tested against a deliberately broken input.
chk5 <- check_seat_totals(wp[party == "ALP", prob], sim$totals[, "ALP"])
cl_q <- stats::quantile(sim$totals[, "ALP"], c(0.05, 0.5, 0.95))
cat(sprintf("\nS5  ALP seats: mean %.2f against sum of per-seat probabilities %.2f\n",
            chk5$mean_total, chk5$expected))
cat(sprintf("    spread sd %.2f against the independence floor %.2f (ratio %.2f)\n",
            chk5$sd_total, chk5$floor_sd, chk5$sd_ratio))
cat(sprintf("    median %d (90%%: %d-%d)\n", round(cl_q[2]), round(cl_q[1]), round(cl_q[3])))
cat(sprintf("    mean gap %.2f (max 0.50), sd ratio %.2f (min 1.00)  %s\n",
            chk5$mean_gap, chk5$sd_ratio, if (chk5$ok) "PASS" else "FAIL"))
if (!chk5$ok) {
  stop(sprintf(paste0("S5 FAILED. Mean ALP total %.2f against sum of per-seat ",
                      "probabilities %.2f (gap %.2f), and spread sd %.2f against ",
                      "an independence floor of %.2f. The first is an identity ",
                      "and the second cannot be violated by positively ",
                      "correlated seats, so the seat totals and the per-seat ",
                      "probabilities do not describe the same simulation."),
               chk5$mean_total, chk5$expected, chk5$mean_gap,
               chk5$sd_total, chk5$floor_sd))
}

# UPSET INSURANCE (AUSPOL_UPSET_FLOOR=1, R/upset_floor.R): the same mixture the
# backtests use, with eps fitted on every backtest election (all precede 2026),
# applied AFTER S5 because S5 checks the simulation's own consistency. eps is
# ~0.003, so no seat moves by more than a third of a point; the chamber totals
# remain the simulation's.
if (identical(Sys.getenv("AUSPOL_UPSET_FLOOR", "0"), "1")) {
  .uf <- out_path("upset-floor-eps.csv")
  if (!file.exists(.uf)) stop("UF0! AUSPOL_UPSET_FLOOR=1 but output/upset-floor-eps.csv is missing (stage 6b / shipped-models)")
  .uf_t <- data.table::fread(.uf); .eps <- .uf_t$eps[.uf_t$pair == TGT]
  if (length(.eps) != 1L || !is.finite(.eps)) stop("UF0! upset-floor-eps.csv has no ", TGT, " row")
  .sh <- data.table::data.table(seat = rep(rownames(shares), ncol(shares)),
                                party = rep(colnames(shares), each = nrow(shares)), share = as.vector(shares))
  wp <- upset_floor_mix(wp[, .(seat, party, prob)], .sh, .eps)
  cat(sprintf("UF1  upset insurance: eps %.4f applied to %d seats' win probabilities
", .eps, data.table::uniqueN(wp$seat)))
}
# Hard check: nothing after the nomination zeroing may have revived a cell it zeroed.
assert_nomination_zeros(shares, .nz_cells)
# The projected per-seat primaries the simulation runs on. Written out because
# nothing else can reconstruct them without duplicating the projection above,
# and a second copy of that logic would drift from this one.
fwrite(data.table(seat = rownames(shares), as.data.table(shares)),
       sprintf("output/seat-shares-%s%s.csv", TARGET$out_stem, OUT_SUFFIX))
fwrite(wp, sprintf("output/seat-probs-%s%s.csv", TARGET$out_stem, OUT_SUFFIX))
fwrite(as.data.table(sim$totals), sprintf("output/seat-sims-full-%s%s.csv", TARGET$out_stem, OUT_SUFFIX))
# PER-SEAT RANGES for the ITG seat pages (2026-09-30), from this run's own
# draws. Primaries: each party's share in every draw, after noise and surge and
# before preferences, normalised to 100. Final two: the pairing drawn most often,
# its leader (the member who wins it more often), the leader's two-candidate
# share across the draws with that pairing, and the swing to flip -- the median
# share minus 50, i.e. how far the leader's two-candidate vote must fall.
.qs <- c(0.05, 0.25, 0.5, 0.75, 0.95)
.qn <- c("q05", "q25", "q50", "q75", "q95")
.fp <- sim$fp_draws
stopifnot(!is.null(.fp), identical(dimnames(.fp)[[2]], rownames(shares)))
.prim <- rbindlist(lapply(dimnames(.fp)[[2]], function(st) rbindlist(lapply(dimnames(.fp)[[3]], function(pt) {
  x <- .fp[, st, pt]; x <- x[is.finite(x)]
  if (!length(x) || mean(x) < 0.05) return(NULL)
  data.table(seat = st, party = pt, mean = round(mean(x), 2), t(setNames(round(stats::quantile(x, .qs, names = FALSE), 2), .qn)))
}))))
.tcp <- rbindlist(lapply(seq_len(ncol(sim$tcp_winner)), function(j) {
  w <- sim$tcp_winner[, j]; r <- sim$tcp_runnerup[, j]; sh2 <- sim$tcp_share[, j]
  ok <- !is.na(w) & !is.na(r) & is.finite(sh2)
  if (!any(ok)) return(NULL)
  pair <- ifelse(w < r, paste(w, r, sep = "|"), paste(r, w, sep = "|"))
  top <- names(which.max(table(pair[ok])))
  k <- ok & pair == top
  a <- strsplit(top, "|", fixed = TRUE)[[1]]
  lead <- a[which.max(c(sum(w[k] == a[1]), sum(w[k] == a[2])))]
  other <- setdiff(a, lead)
  sl <- 100 * ifelse(w[k] == lead, sh2[k], 1 - sh2[k])
  q <- stats::quantile(sl, .qs, names = FALSE)
  data.table(seat = colnames(sim$tcp_winner)[j], leader = lead, other = other,
             p_pair = round(mean(k), 4), p_leader_wins_pair = round(mean(w[k] == lead), 4),
             t(setNames(round(q, 2), paste0("leader_tcp_", .qn))),
             swing_to_flip = round(q[3] - 50, 2))
}))
stopifnot(nrow(.tcp) == nrow(shares), anyDuplicated(.prim[, .(seat, party)]) == 0L)
fwrite(.prim, sprintf("output/seat-primary-ranges-%s%s.csv", TARGET$out_stem, OUT_SUFFIX))
fwrite(.tcp, sprintf("output/seat-tcp-ranges-%s%s.csv", TARGET$out_stem, OUT_SUFFIX))
cat(sprintf("RG1  per-seat ranges: %d party rows, %d seats with a final pair (median P(that pair) %.2f)
",
            nrow(.prim), nrow(.tcp), stats::median(.tcp$p_pair)))
rm(.fp)
cat(sprintf("
wrote output/seat-probs-vic-2026%s.csv
", OUT_SUFFIX))
