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
  AUSPOL_XGB_PRIMARY_LIVE    = "1",          # 1 = every seat's primary share replaced by the XGBoost challenger,
                                             # v6 (scripts/fit_xgb_primary_v6_final.R, trained on all 22 historical
                                             # pairs; output/xgb-primary-v6-final.model).
                                             #
                                             # SHIPPED 2026-09-11 ON PETE'S REPEATED, EXPLICIT INSTRUCTION. He asked
                                             # for the best pooled seat log loss to go live and to iterate on
                                             # regressions afterwards, said so more than once, and the flag was not
                                             # flipped -- that was my error, not a decision he changed.
                                             #
                                             # THE TRADEOFF, ACCEPTED IN WRITING, NOT HIDDEN. Pooled seat log loss
                                             # 0.3403 -> ~0.3071 leave-one-pair-out, the best of v1-v6. But the last
                                             # live smoke test showed 65 of Victoria's 87 seats predicting IND and
                                             # OTH_RIGHT at ~zero, because the salience features that would carry a
                                             # genuine independent/One Nation emergence only have data for 46 of 88
                                             # seats until vic2026 nominations close (12 noon, 9 Nov 2026). Pete's
                                             # call: the pooled gain is worth having now, the emergence weakness is
                                             # tracked as follow-up work rather than a blocker, and the simulations
                                             # are not yet published to the site.
                                             #
                                             # RE-CHECK AFTER 9 NOV. Re-run scripts/fetch_candidates_vic2026_prenomination.R,
                                             # fetch_seat_salience_vic2026_live.R and build_vic2026_salience_corpus.R
                                             # once the full candidate list exists, then re-measure the statewide
                                             # IND/OTH_RIGHT sums -- that is when this weakness should actually
                                             # resolve. Set back to "0" to revert, no other change needed.
                                             # docs/reviews/xgb-primary-v5-seat-features-2026-09-10.md
  AUSPOL_XGB_FLOWS           = "1",          # 1 = per-seat conditional preference flows from the XGBoost flow
                                             # model (R/xgb_flow_override.R), consulted BEFORE the lookup table
                                             # rather than instead of it -- a key the model does not supply falls
                                             # back exactly as before.
                                             #
                                             # SHIPPED 2026-09-11. Worth -0.0068 pooled seat log loss on top of
                                             # the xgb primary (0.3069 -> 0.3001), all 22 pairs, 3 seeds, better
                                             # in 12 of 22. The flow model beats the table the harness actually
                                             # builds in 7 of 8 elections tested head to head.
                                             #
                                             # THE HEADLINE IS NOT SIGNIFICANT: t = -1.67, p = 0.111 clustered on
                                             # pairs. Shipped on Pete's standing rule -- overall better, one or
                                             # two regressions acceptable -- not because it cleared a bar. Say
                                             # "not significant" when quoting it.
                                             #
                                             # TWO KNOWN REGRESSIONS, both diagnosed, neither a blocker:
                                             #   wa2001 +0.048 -- EXPECTED. No transfer file of its own, so it
                                             #     never enters the flow training corpus. Do not re-investigate.
                                             #   fed2016 +0.035 -- VARIANCE, not a defect. A per-class bias
                                             #     correction was proposed, dry-run and REFUSED: it zeroed the
                                             #     global bias and made the per-election two-party bias worse
                                             #     (shrank in 4 of 25, mean |bias| 0.0275 -> 0.0302), because
                                             #     that bias swings sign and is unpredictable from history
                                             #     (r = 0.282, p = 0.242 against the previous election).
                                             #
                                             # LIVE LIMITATION, verified by smoke test 2026-09-11 and NOT hidden:
                                             # the personal-vote features dest_same / dest_same_mp are 0 on
                                             # 0.0% of 42,108 rows for vic2026, because output/candidacies.csv
                                             # has ZERO vic2026 rows -- candidate_returns(vic2022, vic2026)
                                             # errors and the override says so. Every other feature works; the
                                             # override still builds for 87 of 87 seats. This resolves only when
                                             # scripts/build_candidacies.R is extended to write vic2026 rows
                                             # after nominations close (12 noon, 9 Nov 2026) -- add it to the
                                             # AUSPOL_XGB_PRIMARY_LIVE re-check above, it is the same trip.
                                             #
                                             # Costs ~3x runtime per pair. Set to "0" to revert; no other change
                                             # needed. docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md
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
  AUSPOL_SALIENCE_BLEND      = "1",          # 1 = the salience hazard also moves the POINT ESTIMATE toward surge_mu
                                             # (blend_salience_shares), on top of the stochastic surge in the draw.
                                             # Shipped value is 1 = the behaviour that has always run. Set to "0" to
                                             # measure the suspected double count: both are driven by the same hazard
                                             # fit, so the lift may be ~1.7x intended wherever a corpus exists.
                                             # Added 2026-09-11; docs/ARCHITECTURE.md "What the simulator actually does".
  AUSPOL_SURGE_H             = "0",          # flat fallback hazard, used only when surge-v2 has no corpus
  # switches the harnesses know and the forecast does not: listed so a harness
  # run at "published defaults" has them OFF explicitly, not by accident
  AUSPOL_IND_SALIENCE        = "0",          # v1 national salience ratio -- NOT shipped
  AUSPOL_INSURGENCY_SHRINK   = "0",          # per-seat shrink -- measured and refused 2026-09-06
  AUSPOL_SEAT_SD_MULT        = "1",
  AUSPOL_FLOW_SD             = "0",
  AUSPOL_FALLBACK_SMOOTH     = "0",
  AUSPOL_XGB_PRIMARY         = "1",          # harness-only: 1 = replace every seat's primaries with the challenger's
                                             # LEAVE-ONE-PAIR-OUT out-of-fold predictions. This is the backtest
                                             # counterpart of AUSPOL_XGB_PRIMARY_LIVE and is leakage-free by
                                             # construction; the live flag above is the one that ships.
                                             #
                                             # SET TO "1" 2026-09-11, in the same commit that shipped the flows.
                                             # It was "0" while AUSPOL_XGB_PRIMARY_LIVE was "1", which broke this
                                             # file's whole contract: an unadorned harness run is supposed to
                                             # measure WHAT SHIPS, and it was measuring the pre-xgb primary while
                                             # the published forecast ran v6. That is the exact 2026-09-06
                                             # incident this registry exists to prevent, in a new costume.
                                             #
                                             # It moves the harness baseline: pooled seat log loss at published
                                             # defaults goes 0.3332 -> ~0.3001 (with the flows below). Comparisons
                                             # against pre-2026-09-11 numbers must say which baseline they used.
  AUSPOL_LEVEL_MODE          = "pred",       # where the xgb primary's statewide feature comes from when the
                                             # model is FITTED (scripts/fit_xgb_primary_v6.R).
                                             #   pred = output/level-pred.csv, the poll trend plus leave-one-out
                                             #          fundamentals as at the day BEFORE polling day. Mean
                                             #          absolute error 2.06 points per class over 153 cells.
                                             #   now  = the ACTUAL statewide result. LEAKAGE. Kept only so the
                                             #          cost stays measurable; never a default.
                                             #   none = no statewide feature. Measured and REJECTED -- it removes
                                             #          the model's only route to knowing what is happening
                                             #          nationally and cost sa2026 0.4200 -> 0.6309.
                                             #
                                             # SET TO "pred" 2026-09-11 on Pete's ruling: "everything for an
                                             # election forecast shold be predictive". The previous behaviour read
                                             # the target election's own result, which I had described as the
                                             # harness's deliberate design -- it was deliberately coded and never
                                             # put to him.
                                             #
                                             # IT ALSO FIXED A TRAIN/SERVE MISMATCH. The LIVE path always used the
                                             # predicted statewide (R/xgb_primary_override.R:184 fills level_now
                                             # from state_mean, since vic2026 has no result to read), so the
                                             # published forecast never leaked -- it was trained on the actual and
                                             # served the predicted. Training on the prediction makes them agree.
                                             #
                                             # THE COST, MEASURED, 22 pairs / 2,050 seat-elections, seed 1:
                                             # pooled seat log loss 0.3007 leaked -> 0.3134 honest, +0.0127.
                                             # Concentrated where you would expect: sa2026, the One Nation surge
                                             # election, 0.4200 -> 0.5564. Every headline number quoted before
                                             # 2026-09-11 was the leaked one.
  AUSPOL_XGB_PRIMARY_OOF     = "",           # harness-only: which oof file the line above reads. Empty = the v6
                                             # default (output/xgb-primary-v6-oof-predictions.csv), matching the
                                             # shipped model. Set it to output/xgb-primary-oof-predictions.csv to
                                             # measure v1 instead.
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
