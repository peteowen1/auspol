# THE PUBLISHED CONFIGURATION, IN ONE PLACE.
#
# Every AUSPOL_* switch the forecast honours, with the value the published
# Victoria forecast runs at. Two things read this file:
#
#   scripts/fit_seats_full.R   applies it to every switch the caller left unset
#                              and refuses to write the published filename when
#                              any switch differs (its S6 check);
#   scripts/harness_defaults.R applies it to every switch the caller left unset
#                              in the five backtest harnesses, so an unadorned
#                              harness run measures what ships.
#
# WHY. On 2026-09-06 the "shipped config" harness runs behind a day of
# headline numbers turned out to have surge-v2 OFF (fit_seats_full.R has it
# ON) and the v1 national salience ratio ON (fit_seats_full.R never reads it).
# fed2025 read 0.2886 against AE Forecasts' 0.3025; what actually ships scores
# 0.3017. And fit_seats_full.R's own RUN_FLAGS list still said shrink 0.10 a
# day after the code default moved to 0.01, so a run with surge-v2 switched
# off would have overwritten the published file as a "default run". A list
# maintained in two places drifts in both; this is the only copy.
#
# RULE: a Sys.getenv("AUSPOL_...") default anywhere in scripts/ or R/ that
# disagrees with this file is a bug in whichever is wrong. When a new switch
# is added to fit_seats_full.R, add it here in the same commit.
PUBLISHED_FLAGS <- c(
  # the seat model
  AUSPOL_SHRINK              = "0.01",       # calibration coin toss; a CAP on every seat, lowest the evidence allows
  AUSPOL_COV_LOO             = "1",          # statewide correlation held out of its own target; 0 = the in-sample matrix
  AUSPOL_LEVEL_SD            = "1.10,8.67",  # level-dependent seat variance, a + b*sqrt(p(1-p))
  AUSPOL_DEV_SLOPE_MODE      = "screened",   # candidate-conditional slopes + salience screen (arm CS)
  AUSPOL_MP_SLOPE            = "1",          # sitting-member slope tier from output/mp-slope-by-*.csv
  AUSPOL_DEFECT_DISCOUNT     = "1",          # major-party defector carries a fitted fraction of their vote
  AUSPOL_SALIENCE_SURGE_V2   = "1",          # per-seat emergence hazard from the salience corpus
  AUSPOL_SURGE_SCALE         = "1",          # multiplier on that hazard, capped at 1; docs/plans/prereg-surge-hazard-scale-2026-09-06.md
  AUSPOL_SURGE_RECIPIENT     = "1",          # the surge goes to the class the hazard was fitted for; shipped 2026-09-07 (prereg-surge-recipient-2026-09-06.md, stage 2)
  AUSPOL_SURGE_FROM_ZERO     = "0",          # 1 = a named recipient surges from zero share; docs/plans/prereg-recipient-at-zero-2026-09-07.md
  AUSPOL_SALIENCE_SMOOTH     = "1",          # exp_pcv/exp_sd from a monotone cubic on log(1-pctile), not six unequal bins; 0 = the old bands
  AUSPOL_SALIENCE_EXP_SD     = "0",          # 1 = a governed candidate's deviation sd is their salience band's, not level_sd; prereg-salience-expected-and-variance-2026-09-07.md
  AUSPOL_SALIENCE_EXPECTED   = "0",          # 1 = a governed candidate polls their salience band's expected vote; docs/plans/prereg-salience-expected-primary-2026-09-07.md
  AUSPOL_PARTY_COR           = "shrunk",     # correlated statewide deviations
  AUSPOL_LEVEL_MULT_IND      = "1",          # per-class multiplier on level_sd (IND); prereg-class-specific-variance, refused, stays 1
  AUSPOL_LEVEL_MULT_OTH      = "1",          # per-class multiplier on level_sd (other non-majors)
  AUSPOL_DEV_SLOPE           = "",           # explicit per-class slope table; empty = uniform swing, the base under screened mode
  AUSPOL_SPLIT_SLOPE         = "0",          # 1 = returning/departed portions get separate fitted slopes -- built, measured, REFUSED 2026-09-09; docs/plans/prereg-partial-return-split-slope-2026-09-09.md
  AUSPOL_FIT_SLOPES          = "0",          # 1 = conditional same/new slopes fitted leave-one-election-out -- built, measured, REFUSED 2026-09-09 (pooled log loss FAIL, panel FAIL); docs/plans/prereg-fit-conditional-slopes-2026-09-09.md
  AUSPOL_DISPERSION_SLOPE    = "0",          # 1 = flat "new"-candidate slope (GRN/ONP only -- IND/OTH_RIGHT are not real parties) replaced by corr(class) x sd-ratio(class, level), leave-target-out -- built, measured TWICE, REFUSED both times 2026-09-09. Round 1 (4 classes) FAILED (t=-0.35); round 2 (GRN/ONP only, Pete's correction) still FAILED (t=0.06, ~zero pooled effect) -- fed2013 genuinely regresses since OTH_RIGHT is correctly left untouched. docs/plans/prereg-dispersion-slope-2026-09-09.md
  AUSPOL_XGB_PRIMARY_LIVE    = "0",          # 1 = every seat's primary share replaced by the XGBoost challenger
                                             # (scripts/fit_xgb_primary_final.R, trained on all 22 historical pairs).
                                             # NOT SHIPPED. Backtest result is real (leave-one-pair-out pooled seat
                                             # log loss 0.3358 -> 0.3122, t=-2.89, better in 17 of 22 pairs) but it is
                                             # WORSE than the model it replaces specifically on rare independent/
                                             # minor-party emergences (worst-20-seats-vs-AEF mean error: shipped
                                             # 14.54, xgb 15.18) -- exactly the shape of a One Nation surge, which is
                                             # what this forecast is making for Victoria right now. Held pending the
                                             # fix queue in docs/NEXT-STEPS.md; do not flip this without Pete's
                                             # explicit sign-off after that weakness is addressed or accepted in
                                             # writing. docs/reviews/xgb-primary-challenger-2026-09-09.md
  AUSPOL_DEFECT_POOLED       = "2",          # 2 = separate member (0.282) / losing-candidate (0.142) defector rates.
                                             # ADOPTED BY PETE ON MECHANISM 2026-09-09, not on the criterion: the arm
                                             # missed its own primary bar (t -2.04 vs 2.08) but passed R1 in both arms,
                                             # breached no floor, improved pooled log loss / Victoria / WA, and made only
                                             # ONE panel metric worse. Recorded as a JUDGEMENT, not a measurement.
                                             # docs/plans/prereg-defector-two-rate-2026-09-09.md
  # the statewide input and the simulation
  AUSPOL_N_SIMS              = "20000",
  AUSPOL_SIM_ENGINE          = "cpp",        # compiled core; proven byte-identical to the R engine on a full fed2022 run 2026-09-07 (45 s vs ~11 min)
  AUSPOL_SEED                = "42",
  AUSPOL_FP_SD_MODE          = "additive",
  AUSPOL_ONP_ORDER           = "federal",
  AUSPOL_ONP_FIX             = "1",
  AUSPOL_QLD_FLOWS           = "1",
  AUSPOL_WA_FLOWS            = "0",
  AUSPOL_FLOW_SHIFT          = "0",
  AUSPOL_FORCE_FP            = "",
  AUSPOL_ONP_CV              = "0.365",     # One Nation seat-concentration target -- partially pooled 2026-09-09
                                             # (SA 2026's own 0.346, weight 0.83, vs corpus-typical 0.479 at
                                             # Victoria's ~21% level). Was unset (SA's raw 0.327). Moves ONP
                                             # median seats 9 -> 10 (90%: 3-18 -> 4-20). Pete's call: publish
                                             # the pooled estimate, not SA's point value alone.
                                             # docs/reviews/onp-concentration-validated-2026-09-09.md
  AUSPOL_SURGE_H             = "0",          # flat fallback hazard, used only when surge-v2 has no corpus
  # switches the harnesses know and the forecast does not: listed so a harness
  # run at "published defaults" has them OFF explicitly, not by accident
  AUSPOL_IND_SALIENCE        = "0",          # v1 national salience ratio -- NOT shipped
  AUSPOL_INSURGENCY_SHRINK   = "0",          # per-seat shrink -- measured and refused 2026-09-06
  AUSPOL_SEAT_SD_MULT        = "1",
  AUSPOL_FLOW_SD             = "0",
  AUSPOL_FALLBACK_SMOOTH     = "0",
  AUSPOL_FLOW_SHRINK_K       = "0"           # data-weighted flow-cell smoothing -- REFUSED 2026-09-10, worse pooled at every tested k (0.339-0.354 vs baseline 0.339); helps Ballarat's own cell exactly as designed but federal/WA dominate the aggregate. docs/reviews/flow-cell-shrinkage-REFUSED-2026-09-10.md
)

# Apply to whatever the caller left unset. Returns the names it set.
apply_published_flags <- function(flags = PUBLISHED_FLAGS) {
  unset <- names(flags)[!nzchar(Sys.getenv(names(flags), unset = ""))]
  # AUSPOL_FORCE_FP's published value IS the empty string, so "unset" and
  # "published" coincide and nothing needs doing for it.
  unset <- setdiff(unset, names(flags)[!nzchar(flags)])
  if (length(unset)) do.call(Sys.setenv, as.list(flags[unset]))
  unset
}
