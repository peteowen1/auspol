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
  AUSPOL_HONOUR_DEPARTED     = "1",          # a departed class leader's base decays toward the measured 0.38 retention rate, independent of whether the screen separately permits a new emergence (0.907/1.0 previously applied even when the "same" candidate was an unrelated minor figure, e.g. Morwell/Tracie Lund masking Russell Northe's real departure). 2026-09-06's refusal conflated "departure" with "no new emergence" as one mechanism; re-measured 2026-09-18 on the fuller 593-case corpus -- docs/reviews/departed-leader-retention-2026-09-15.md, docs/reviews/departed-leader-honour-fix-2026-09-18.md. Isolated in base_pred: pooled log loss 0.2810->0.2801 (5 harnesses, n=1751), vic2022 alone 0.2789->0.2587, Morwell 3.049->1.877.
  AUSPOL_DEPARTED_HOLD       = "0",          # REFUSED 2026-10-05 (docs/plans/prereg-departed-hold-fixed-2026-10-04.md, docs/reviews/departed-hold-sweep-2026-10-05.md): hold a departed leader's decayed cell fixed through renormalisation (the 0.38 was measured on final shares, applied before renormalising, effective 0.6-0.7). Both arms refused by the prereg; switch kept off, byte-identical when off.
  AUSPOL_DEPARTED_HOLD_MIN_PRIOR = "0",     # arm B (post hoc): hold only classes with at least this prior seat share; 15 = the retention review's population. Refused too.
  AUSPOL_DEPARTED_ORIGIN     = "0",          # MEASURING 2026-09-18 (docs/plans/prereg-departed-origin-return-2026-09-18.md): when a departed
                                             # non-major class leader earlier stood for a major party in the seat, route a fitted share of
                                             # their prior vote back to that party in the prior matrix ("1" = leave-target-out median ~0.21,
                                             # "mean" ~0.36) before the departed decay applies to the rest. Morwell vic2022 (Northe, National ->
                                             # IND -> retired; Nationals 27.2 predicted vs 38.4). route_departed_origin(), all six harnesses +
                                             # fit_seats_full.R at the remove_transferred_votes() step. "0" = today's pro-rata release.
  AUSPOL_MAJOR_DEPARTED      = "1",          # SHIPPED 2026-09-18 (docs/plans/prereg-major-departed-slope-2026-09-18.md): ALP/LNP seats
                                             # whose sitting member did not re-stand get a fitted (leave-target-out) slope on their deviation
                                             # from the statewide level instead of 1.0 -- base_pred over-predicts them by 2.8 points on 361
                                             # cells, scaling with the vote. fit_major_departed_slope(), conditional_slopes(major_departed=).
                                             # Measured base_pred-only, 20k sims, all 23 pairs: departed-cell error 5.37 -> 4.66 points
                                             # (-0.71, SE 0.11), bias 2.7 -> 1.0; pooled seat log loss 0.2979 -> 0.2951, 14 of 23 pairs
                                             # better; other classes in those seats unchanged. Parramatta 2.20 -> 1.47, Monaro 2.66 -> 1.98.
  AUSPOL_MAJOR_SLOPE         = "1",          # SHIPPED 2026-09-18 (docs/plans/prereg-major-present-slope-2026-09-18.md): every OTHER ALP/LNP
                                             # cell (member stayed, or class never held the seat) gets a fitted leave-target-out slope on its
                                             # deviation too -- a major predicted under 15 lands +3.4 higher on average, one over 55 lands
                                             # -1.6 lower. fit_major_departed_slope()$slope_present (ALP ~0.95, LNP ~0.89), conditional_slopes(
                                             # major_present=). Measured on top of AUSPOL_MAJOR_DEPARTED, base_pred-only, 20k sims: non-departed
                                             # cell error 3.579 -> 3.530 (-0.049, SE 0.013), the 0-15 band -0.77; pooled log loss 0.2951 ->
                                             # 0.2957 (within 1 SE), accuracy 0.8878 -> 0.8902. New England ALP 12.7 -> 14.0 (actual 18.6).
  AUSPOL_NOTIONAL            = "2",          # redistribution-adjusted (notional) prior for EVERY seat build_notional_baselines.R covers, not just brand-new names; upgraded from "1" (missing-seat fallback only) 2026-09-13 -- Antony Green's own booth-respread method, leakage-free. Currently a no-op under AUSPOL_XGB_PRIMARY=1 (which overrides the table this feeds) except the few cells XGB has no prediction for; shipped anyway because it is the methodologically correct baseline, not because it moves the pooled number -- docs/reviews/notional-prior-redistribution-2026-09-13.md
  AUSPOL_STATE_NOTIONAL      = "1",          # SHIPPED v57 2026-10-01: state redistributions -- prior rebuilt on the target's boundaries from booth results (R/state_notional.R, scripts/build_state_notionals.py); also feeds x_notional_adj. plans/prereg-state-notional-2026-10-01.md
                                             # HOW FAR THIS ACTUALLY REACHES (2026-09-14, found by the review gate): the FEDERAL BACKTEST only. fit_seats_full.R -- the live Victorian forecast -- has no notional path at all, and build_notional_baselines.R reads the federal AEC polling-place download, so it cannot produce Victorian data. Nor does fit_xgb_primary_v6_final.R, which builds the model artifact xgb_primary_predict_live() serves, so output/xgb-primary-v6-final-cols.json carries no x_notional_adj either. Setting this flag does not change the published Victoria 2026 numbers; it changes what the federal backtest measures.
  AUSPOL_MP_SLOPE            = "1",          # sitting-member slope tier from output/mp-slope-by-*.csv
  AUSPOL_DEFECT_DISCOUNT     = "1",          # major-party defector carries a fitted fraction of their vote
  AUSPOL_SALIENCE_SURGE_V2   = "1",          # per-seat emergence hazard from the salience corpus
  AUSPOL_SURGE_SCALE         = "1",          # multiplier on that hazard, capped at 1; docs/plans/prereg-surge-hazard-scale-2026-09-06.md
  AUSPOL_SURGE_RECIPIENT     = "1",          # the surge goes to the class the hazard was fitted for; shipped 2026-09-07 (prereg-surge-recipient-2026-09-06.md, stage 2)
  AUSPOL_SURGE_FROM_ZERO     = "0",          # 1 = a named recipient surges from zero share; docs/plans/prereg-recipient-at-zero-2026-09-07.md
  AUSPOL_SALIENCE_SMOOTH     = "1",          # exp_pcv/exp_sd from a monotone cubic on log(1-pctile), not six unequal bins; 0 = the old bands
  AUSPOL_SALIENCE_EXP_SD     = "0",          # 1 = a governed candidate's deviation sd is their salience band's, not level_sd; prereg-salience-expected-and-variance-2026-09-07.md
                                             # (both switches run at 0 in every harness; see the note below.)
  AUSPOL_SALIENCE_EXPECTED   = "0",          # 1 = a governed candidate polls their salience band's expected vote; docs/plans/prereg-salience-expected-primary-2026-09-07.md
                                             #
                                             # NOTE (2026-10-03): all harnesses now run both salience switches at the
                                             # published 0, as does fit_seats_full.R. The "arm C" scoping of 2026-09-09
                                             # (commit 01c8e1c: backtest_candidate_fed.R and backtest_candidate_nsw.R
                                             # defaulted both to 1) was removed because a rebuild exports the published
                                             # flags first, so the scoping never fired in the rebuild/ledger and hand
                                             # runs differed from what was scored. See
                                             # docs/reviews/fed-nsw-snapshot-gap-2026-10-03.md and
                                             # docs/plans/prereg-salience-fed-nsw-onoff-2026-10-03.md. An explicit
                                             # AUSPOL_SALIENCE_EXPECTED=1 AUSPOL_SALIENCE_EXP_SD=1 still selects arm C
                                             # in any harness.
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
                                             # LIVE LIMITATION, RESOLVED 2026-09-15 -- left here because the
                                             # old note said the opposite and a reader needs to know it moved.
                                             # It read: dest_same / dest_same_mp populated on 0.0% of 42,108
                                             # vic2026 rows, because output/candidacies.csv had ZERO vic2026
                                             # rows. It now has 379, from the announced-candidates list
                                             # scripts/build_candidacies.R:879 reads out of Wikipedia, and the
                                             # smoke test measures dest_same at 19.6% / dest_same_mp at 15.5%.
                                             # Those rows carry names and no votes, which is correct: a
                                             # preselection is public long before nominations close, so this is
                                             # knowable now and is not a leak. Expect the rate to rise again at
                                             # the close of nominations (12 noon, 9 Nov 2026), when the full
                                             # field replaces the announced one -- still on the
                                             # AUSPOL_XGB_PRIMARY_LIVE re-check above, same trip.
                                             #
                                             # Costs ~3x runtime per pair. Set to "0" to revert; no other change
                                             # needed. docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md
  AUSPOL_FLOW_ASAT           = "1",          # SHIPPED 2026-09-18: the per-election flow model the harnesses read is trained on EARLIER
                                             # elections only (scripts/fit_xgb_flows_asat.R, output/xgb-flows-v1-asat-<election>.model),
                                             # not the leave-one-election-out model that sees later elections. Same leak, same fix as
                                             # AUSPOL_XGB_PRIMARY_OOF. Not a scored change: an honest number replacing a leaked one.
  AUSPOL_HTV_FLOW            = "1",          # SHIPPED 2026-09-18 (docs/plans/prereg-htv-flow-2026-09-18.md): the Liberal how-to-vote card
                                             # order for ALP-v-GRN seats (external/reference/htv/liberal-alp-grn-order.csv) selects the
                                             # Liberal-excluded, ALP+GRN-alive flow row -- 35% to ALP when the card puts Greens above Labor,
                                             # ~61% otherwise, both fitted leave-target-out from the transfer files. R/htv_flow.R. Measured
                                             # base_pred-only, 20k sims: real-pairing 2CP error on ALP-v-GRN seats 6.19 -> 5.08 (n=26, SE
                                             # 0.32), other pairings unchanged, pooled log loss 0.2945 -> 0.2938. No entry for an election
                                             # (wa, sa, vic2026 until the cards are out) = unchanged.
  AUSPOL_BYELECTION_PRIOR    = "blend",      # SHIPPED 2026-09-18 as a HALF BLEND (docs/plans/prereg-byelection-prior-2026-09-18.md): a by-election held
                                             # between the two general elections, where both majors stood, replaces that seat's prior row
                                             # (external/reference/byelections/byelection-results.csv, R/byelection_prior.R). Black sa2026,
                                             # Werribee/Mulgrave for the live vic2026 run. A by-election a major skipped is not used. Full
                                             # replacement ("1") was REFUSED: protest swings revert (Inala, Ipswich West, Upper Hunter), error
                                             # +0.59 on 17 seats. "blend" = half by-election, half general election: error 2.78 -> 2.44 (SE
                                             # 0.24), pooled log loss 0.2945 -> 0.2936. Black 34.2 -> ~38 on ALP (actual 43.0).
  AUSPOL_BYELECTION_FILL     = "0",          # REFUSED 2026-09-30 (docs/plans/prereg-byelection-fill-2026-09-30.md): only Lyne improved, xgb error +0.01: use a by-election
                                             # a major skipped (18 of 54; Lyne 2008, Prahran 2025), giving the absent major its prior share
                                             # plus the statewide poll swing to that date, taken from the non-majors. Off = skipped as before.
  AUSPOL_BYELECTION_MP       = "1",         # SHIPPED 2026-09-19: the by-election WINNER is the seat's sitting member for every
                                             # candidate-identity test (same_mp, mp_departed, historic_elected), not the previous general
                                             # election's member. Black sa2026: Speirs read as the returning member of the IND class (+5 pts
                                             # from the xgb layer), Dighton as a newcomer. byelection_winner_rows(), candidate_returns().
                                             # Measured base_pred-only, 20k sims: the 12 changed-member seats' cell error 5.39 -> 4.87 (SE
                                             # 0.27); pooled log loss 0.2920 -> 0.2906, 15 of 22 pairs better; other cells unchanged.
  AUSPOL_MINOR_DEFECT_CONSERVE = "1",        # SHIPPED 2026-09-19 (docs/plans/prereg-minor-defector-conserve-2026-09-19.md): a minor-to-
                                             # minor defector's ORIGIN class keeps a fitted leave-target-out share (median ~0.38, n=26) of
                                             # their prior vote; the shipped path removed all of it (Mirani: One Nation 0.9 predicted, 11.9
                                             # actual). fit_minor_defector_conserve(), applied inside personal_prior_vote() for every caller.
                                             # Measured base_pred-only, 20k sims, 26 origin cells: error 3.98 -> 2.56 (SE 0.69); the
                                             # defector's new class +0.10 (SE 0.18); pooled log loss -0.0003 (SE 0.0004). Mirani ONP 0.9
                                             # -> 11.4 (11.9), Lockyer 0 -> 9.5 (13.3), Hunter 5.0 -> 11.2 (10.0); Orange/Miranda worse.
  AUSPOL_FLOW_FRAG           = "1",          # 1 = the flow model also sees lead_primary, the seat's LEADING
                                             # first-preference share. Flows track how fragmented the field is,
                                             # not how close the contest is: the 2CP margin's slope collapses
                                             # from +0.357 to +0.003 once this term enters (872 observations),
                                             # and the leader's own share carries all of it at t = +3.69.
                                             #
                                             # SHIPPED 2026-09-15 ON PETE'S CALL, over my recommendation. The
                                             # pre-registered criterion said adopt if out-of-fold RMSE improves,
                                             # and it did -- 0.098070 -> 0.097987 over 36,064 transfer rows,
                                             # deterministic (the baseline ran three times to 0.0981). I argued
                                             # -0.084% is too small to earn a column and wanted the criterion
                                             # rewritten with a size threshold; he shipped it on the criterion as
                                             # written, which is the right reading of a pre-registration. The
                                             # threshold belongs in the NEXT plan, not in a re-reading of this one.
                                             #
                                             # NOT MEASURED: pooled seat log loss, the plan's own confirming
                                             # guard. Its MDE is near 0.003 and a 0.084% flow change cannot reach
                                             # that, so the number would be simulation variance. Reported as
                                             # unmeasured rather than run to produce a believable-looking figure.
                                             #
                                             # TRAIN/SERVE: training reads the seat's ACTUAL leading share;
                                             # R/xgb_flow_override.R's per-seat path reads the simulation's
                                             # PREDICTED one from the same `shares` row that already supplies
                                             # to_primary/from_primary. Same substitution those two make, not a
                                             # new one. The retired statewide path takes the statewide maximum
                                             # and says so. docs/plans/prereg-flow-fragmentation-2026-09-15.md
  AUSPOL_DEFECT_POOLED       = "2",          # 2 = separate member (0.282) / losing-candidate (0.142) defector rates.
  AUSPOL_BYELEC_LEVEL        = "1",          # SHIPPED 2026-10-05 (Pete override of the 2-SE clause; -72% on the winners) (docs/plans/prereg-byelection-level-2026-10-05.md): a non-major by-election winner is credited the median next-election share of sitting non-major members (~41), fitted time-forward, instead of no own vote.
  AUSPOL_BYELEC_DEPARTED     = "1",          # SHIPPED 2026-10-05 (same plan): a major that lost the seat at a by-election keeps its 'member departed' flag at the next general election.
  AUSPOL_CROSS_SEAT_VOTE     = "1",          # SHIPPED 2026-10-06 (Amendment A1 PASS: -34% on its cells, ledger 0.2822 -> 0.2809). Was: PREREG PENDING, OFF (built 2026-10-05, Pete: "sounds good fix"; R/cross_seat_vote.R): a class leader with no same-seat history is credited carry x their best earlier NON-MAJOR result in another seat / jurisdiction / skipped cycle (time-forward, surname + full first name, same state; carry fitted on the cross-seat cases, shrunk toward the same-seat ratio). Fowler/Dai Le, Cowper/Oakeshott, Stuart/Brock.
  AUSPOL_DEFECT_BY_LEVEL     = "2",         # SHIPPED 2026-10-05: 2 = federal targets get their own shrunk sitting-member defector carry (~0.16-0.23), states keep the pooled rate; 1 = federal and state rates (REFUSED); 0 = one all-level median. PREREG (docs/plans/prereg-defector-by-level-2026-10-05.md): sitting-member defector carry pooled by federal vs state with shrinkage (federal ~0.2, state ~0.4-0.6) instead of one all-level median.
                                             # ADOPTED BY PETE ON MECHANISM 2026-09-09, not on the criterion: the arm
                                             # missed its own primary bar (t -2.04 vs 2.08) but passed R1 in both arms,
                                             # breached no floor, improved pooled log loss / Victoria / WA, and made only
                                             # ONE panel metric worse. Recorded as a JUDGEMENT, not a measurement.
                                             # docs/plans/prereg-defector-two-rate-2026-09-09.md
  AUSPOL_DEFECT_CONSERVE     = "1",          # 1 (shipped) = a major-party defector's UNCLAIMED vote stays with
                                             # their old party (conserving); 0 = it evaporates instead, matching
                                             # AUSPOL_MINOR_DEFECT's own non-conserving treatment. Measured and
                                             # REFUSED 2026-09-17: non-conserving is 209% worse RMSE on the fixed
                                             # 33-case set (8.5878 -> 26.5369), worse in every jurisdiction except
                                             # NSW, only 1 of 33 cases improved. Most major-party defector seats
                                             # retain 70-97% of their vote, so full removal massively under-predicts
                                             # almost everywhere -- kept inert for reuse, not because the question
                                             # is still open. docs/plans/prereg-major-defector-conserve-2026-09-17.md
  AUSPOL_ASAT_MIN_PAIRS      = "4",          # fit_xgb_primary_asat.R: a target election gets its own point-in-time
                                             # model only if at least this many earlier pairs exist to train it on;
                                             # below that it keeps base_pred and the log says so. Added 2026-09-18
                                             # with the as-at models (see AUSPOL_XGB_PRIMARY_OOF below).
  AUSPOL_XGB_BASE_MARGIN     = "2",          # fit_xgb_primary_v6.R: 2 = base_pred set as the training DMatrix's
                                             # base_margin AND kept as an ordinary feature -- forces every tree to
                                             # boost on the residual to base_pred while still letting the tree use
                                             # base_pred's own value to size the correction. (1 = margin-only,
                                             # base_pred removed as a feature -- measured WORSE than plain-feature,
                                             # 3.8563 vs 3.8012 pooled all-23 RMSE; not shipped.)
                                             # SHIPPED 2026-09-17, decided against AEF7 (fed2022/fed2025/nsw2023/
                                             # qld2024/sa2026/vic2022/wa2025) as the working criterion, per Pete's
                                             # call that day: faster to iterate on than the full 23-pair pooled bar.
                                             # Pooled AEF7 primary RMSE: 3.6082 (base_margin) vs 3.6662 (plain
                                             # feature) vs 3.6715 (v7f, the mechanism this REPLACES -- see
                                             # AUSPOL_XGB_PRIMARY_OOF below). Also beats v7f pooled across all 23
                                             # pairs (3.7603 vs 3.7914). Driven mostly by sa2026 (One Nation, the
                                             # single pair the standing AEF gap analysis names as our biggest
                                             # deficit): 4.852 -> 4.219 vs v6-plain, 5.096 -> 4.219 vs v7f.
                                             # On the full 23-pair pooled SEAT log loss bar (the OTHER standing
                                             # criterion, CLAUDE.md's "THE OBJECTIVE"), this arm was measured
                                             # 2026-09-17 and REFUSED (0.2841 -> 0.2880, worse, concentrated in 2 of
                                             # 23 pairs) -- shipped anyway on the AEF7 decision, which is a policy
                                             # change from that standing rule, not a reversal of the seat-log-loss
                                             # measurement. docs/NEXT-STEPS.md carries both numbers.
  AUSPOL_MINOR_DEFECT        = "1",          # discount a candidate's own_prev_pcv when they switched between two
                                             # NON-major parties (Stephen Andrew, ONP -> KAP, Mirani qld2024) --
                                             # fit_minor_defector_discount(), leave-target-out median, same shape as
                                             # AUSPOL_DEFECT_POOLED but for the case MAJ <- c("ALP","LNP","NAT")
                                             # excludes by design. Sized on 33 corpus cases (geometric mean retention
                                             # 0.49, p=0.0003), measured: targeted RMSE 9.2363 -> 8.8813, pooled RMSE
                                             # 3.8161 -> 3.8178 (well within the ~0.014-per-column noise floor found
                                             # the same session). docs/reviews/minor-to-minor-defector-2026-09-16.md
  AUSPOL_MINOR_DEFECT_BASE_PRED = "1",       # SHIPPED 2026-09-18, reversing the 2026-09-16 refusal. Same
                                             # mechanism as AUSPOL_MINOR_DEFECT above but reaching base_pred
                                             # (dev_slope()), not just the xgb feature -- gated separately because
                                             # the single-rate version was refused here 2026-09-16 (helped Mirani,
                                             # targeted RMSE 8.8813 -> 11.4315, worse). Revised to a two-rate split
                                             # (personal_prior_vote()'s minor_discount/minor_discount_loser) after
                                             # finding Murray/Orange/Barwon (nsw2023, real sitting Shooters-
                                             # Fishers-and-Farmers-to-Independent departures, retention 108-136%)
                                             # were badly under-predicted by the single pooled rate. A CONFIRMED
                                             # SITTING MEMBER gets NO discount at all (not a fitted rate) --
                                             # leave-one-out cross-validated against all 5 sitting corpus cases,
                                             # flat 1.0 halves the squared error a fitted rate gets (0.405 vs
                                             # 0.782; n=5 is too thin to fit below 1 usefully). A confirmed
                                             # NON-sitting switcher still gets the fitted rate (median 0.276,
                                             # n=13, well-powered). Measured: pooled RMSE across the 14
                                             # affected pairs 4.0554 -> 4.0568 (n=8910, negligible), Murray/
                                             # Orange/Barwon move from ~14-18 to 52.44/39.78/37.25 (actual
                                             # 53.08/53.31/45.83) -- a large, correctly-directed improvement.
                                             # Honest trade-off: Mirani and Kennedy (the other 2 of 5 sitting
                                             # cases, both of whom actually LOST vote) also revert to NO
                                             # discount, undoing 2026-09-16's Mirani-specific improvement --
                                             # accepted because the aggregate evidence favours one rule over
                                             # cherry-picking per seat. docs/reviews/minor-defector-two-rate-
                                             # 2026-09-17.md.
  AUSPOL_XGB_SEATPREV_NAFILL = "1",          # fit_xgb_primary_v6.R (build-time) AND xgb_primary_predict_live()
                                             # (live serving, R/xgb_primary_override.R) -- both must read the same
                                             # default or a retrain reintroduces a train/serve mismatch (found by
                                             # review 2026-09-17, f3bd280). NA-fill seat_prev_pcv instead of
                                             # 0-fill when a party did not contest that seat last time (16.7% of
                                             # rows, concentrated in ONP/IND/OTH_RIGHT -- 24.2% of minor-party rows
                                             # vs 4.5% major). Same shape as seat_outperf's NA-fill fix. SHIPPED
                                             # 2026-09-17. Measured through the real v6->v7(v7f)->shipped-snapshot
                                             # pipeline, not v6 alone -- a first pass on v6 in isolation overstated
                                             # the gain 5-6x (sa2026 claimed -0.0242, real -0.0044). Real result,
                                             # all 23 pairs: pooled seat log loss 0.2817 -> 0.2811, Brier -0.0005,
                                             # FED/NSW/QLD/SA/VIC better, WA +0.0039 worse. docs/NEXT-STEPS.md.
  # the statewide input and the simulation
  AUSPOL_N_SIMS              = "20000",
  AUSPOL_SIM_ENGINE          = "cpp",        # compiled core; proven byte-identical to the R engine on a full fed2022 run 2026-09-07 (45 s vs ~11 min)
  AUSPOL_SEED                = "42",
  AUSPOL_XGB_SEED            = "42",         # xgb training seed (fit_xgb_*); varied only to MEASURE how much an equally valid refit moves the metrics (plans/noise-floor-2026-10-02.md)
  AUSPOL_XGB_ENSEMBLE        = "3",          # SHIPPED v58 2026-10-02: average K seed-varied xgb fits (as-at and production; one CV, K trainings). plans/prereg-seed-ensemble-2026-10-02.md
  AUSPOL_FP_SD_MODE          = "additive",
  AUSPOL_XGB_SENATE          = "0",          # "1", "minor", "dev" all REFUSED 2026-10-01 (each costs Victorian Labor or loses the gains); parked. TESTED (plans/prereg-xgb-senate-2026-10-01.md): each party's federal Senate share in the seat (and its deviation from the class mean) as xgb features, time-forward, R/senate_features.R.
  AUSPOL_XGB_COUNCIL         = "1",          # SHIPPED v58 2026-10-02: council history (mayor / councillor / stood and lost / council share) as xgb features, every state and federal row (R/council_features.R). plans/prereg-council-2026-10-02.md
  AUSPOL_XGB_BOOTH           = "0",          # TESTING 2026-10-02: booth spread and early-vote gap from the previous election (R/booth_features.R). plans/prereg-booth-features-2026-10-02.md
  AUSPOL_XGB_ENDORSE         = "1",          # SHIPPED v59 2026-10-02: Climate 200 / Voices endorsement as xgb features (R/endorsement_features.R). plans/prereg-endorsement-2026-10-02.md
  AUSPOL_UPSET_FLOOR         = "0",          # TESTING 2026-10-02: time-forward upset insurance for minor contenders (R/upset_floor.R, stage 6b). plans/prereg-upset-floor-2026-10-02.md
  AUSPOL_ONP_ORDER           = "federal",    # "senate" REFUSED 2026-10-01 (plans/prereg-onp-senate-2026-10-01.md): SA 2026 seat log loss +1.7 SE.
  AUSPOL_ONP_FIX             = "1",
  AUSPOL_QLD_FLOWS           = "1",
  AUSPOL_WA_FLOWS            = "0",
  AUSPOL_FLOW_SHIFT          = "0",
  AUSPOL_FORCE_FP            = "",
  AUSPOL_ONP_CONC_SD         = "auto",      # BACKTEST-side One Nation seat concentration, SHIPPED 2026-09-14 on
                                             # Pete's call. Orders a state's seats by their own transposed FEDERAL
                                             # One Nation vote -- a fresher, independent signal than the seat's own
                                             # stale prior state result -- and quantile-maps the statewide total onto
                                             # a target SD. Worth a lot where it applies: sa2026 seat log loss
                                             # 0.4339 -> 0.3577 and 39/47 -> 41/47 seats, replicated at two seeds,
                                             # and it survives a full retrain through the xgb primary layer.
                                             # It COSTS vic2022 (72/78 -> 69/78) via a pre-existing IND weakness it
                                             # amplifies rather than creates; pooled over 738 seat-elections it is
                                             # still a clear gain (0.2452 -> 0.2403). The argument that settled it:
                                             # fit_seats_full.R ALREADY concentrates ONP for the live forecast
                                             # (AUSPOL_ONP_ORDER/AUSPOL_ONP_CV below), so without this the backtest
                                             # was scoring a different model than the one that ships.
                                             # "auto" and not a number ON PURPOSE. SD = a * statewide^k with k about
                                             # 0.5, so one frozen scalar is only right for the election it was fitted
                                             # against -- sa2026 wants 9.18, sa2022 wants 2.97. scripts/
                                             # estimate_onp_concentration.R writes output/onp-concentration-curve.csv
                                             # with each election held out of its own fit, so every row is
                                             # leakage-free for the election it describes. A pair whose ordering
                                             # signal does not exist (sa2022: ONP in 5 of 47 seats) is reported and
                                             # skipped, not silently zeroed and not fatal.
                                             # docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md
  AUSPOL_ONP_CV              = "0.365",     # One Nation seat-concentration target -- partially pooled 2026-09-09
                                             # (SA 2026's own 0.346, weight 0.83, vs corpus-typical 0.479 at
                                             # Victoria's ~21% level). Was unset (SA's raw 0.327). Moves ONP
                                             # median seats 9 -> 10 (90%: 3-18 -> 4-20). Pete's call: publish
                                             # the pooled estimate, not SA's point value alone.
                                             # docs/reviews/onp-concentration-validated-2026-09-09.md
  AUSPOL_FORECAST_MODE       = "1",          # harness-only: 1 = the statewide the seats swing toward is PREDICTED
                                             # from the poll trend plus leave-one-out fundamentals as at the day
                                             # before, instead of read off the election being scored (the oracle).
                                             # FLIPPED TO 1 ON 2026-09-19: Pete's ruling of 2026-09-11 is that a
                                             # forecast must be predictive throughout; the default stayed 0 only
                                             # while four harnesses could not honour it. All six now share one
                                             # block, R/forecast_statewide.R forecast_statewide_or_oracle(); a cycle
                                             # too thin to fit a trend (wa2021) is SKIPPED loudly, never scored
                                             # on the oracle. This matters in the production pipeline because
                                             # base_pred carries the statewide into the xgb layer via base_margin;
                                             # the old static-OOF override path hid it. The ledger rebuilt under
                                             # this flag is v39; expect it to read WORSE than v38 and be honest.
  # AUSPOL_NSW_THIN_WALK is deliberately NOT registered here. scripts/fit_nsw.R
  # does not source this file -- only fit_seats_full.R and the six backtest
  # harnesses (via harness_defaults.R) do -- so an entry here would be
  # documentation masquerading as behaviour, which is the exact drift this
  # registry exists to prevent and which CLAUDE.md records happening twice
  # before (AUSPOL_SEAT_SD_MULT never reaching fit_seats_full.R). Its shipped
  # default lives in fit_nsw.R itself, next to the code that reads it.
  AUSPOL_SALIENCE_PCTILE_NZ  = "1",         # 1 = jump_pctile is ranked among NON-ZERO jumps only
                                             # (R/salience_surge.R). `jump` is 51-81% exactly zero in
                                             # every governed field, so ranking over all of it put the tied
                                             # zero block mid-scale and handed any non-zero value a high
                                             # percentile: Tony Backhouse (Warringah 2016) has a jump of
                                             # EXACTLY 0.000 and scored the 41st percentile.
                                             #
                                             # This percentile feeds salience_expected(), whose top band
                                             # assigns ~14 points of expected primary, which flows into
                                             # pred_share, which the xgb primary tracks at r = 0.991. 34
                                             # fed2016 IND cells were predicted 16.3 against an actual 10.2.
                                             # Set to 0 only to reproduce pre-2026-09-12 numbers.
  AUSPOL_XGB_PRIMARY_SD      = "0",          # 1 = per-cell primary SD comes from the XGBoost spread model
                                             # (R/xgb_primary_sd_override.R, scripts/fit_xgb_primary_sd.R)
                                             # instead of only the salience-derived sd matrix. This is the
                                             # REPLACEMENT for the surge mechanism binned 2026-09-12: honest
                                             # width on cells that could emerge, rather than a coin-flip jump.
                                             # Gaussian log score on 13,352 held-out cells 1.8661 -> 1.2863,
                                             # with the gain on IND (1.50), OTH (0.95) and ONP (0.91) rather
                                             # than the majors (ALP 0.03, LNP 0.09).
  AUSPOL_XGB_PRIMARY_SD_SRC  = "output/xgb-primary-sd-oof.csv",
  AUSPOL_XGB_PRIMARY_SD_CLASSES = "IND,OTH,OTH_RIGHT,ONP",
                                             # which classes AUSPOL_XGB_PRIMARY_SD widens. NOT every class:
                                             # setting all 1,050 fed2022 cells replaced the tuned seat_sd
                                             # machinery for the majors and cost the 144 non-teal seats
                                             # 0.267 -> 0.278 of log loss, because the sd model has nothing
                                             # to offer them (Gaussian log-score gain ALP 0.03, LNP 0.09
                                             # against IND 1.50).
                                             #
                                             # REGISTERED HERE SO THE ARM FINGERPRINT SEES IT. The
                                             # fingerprint hashes every AUSPOL_* variable that is SET, and
                                             # harness_defaults.R only exports what this list names. A
                                             # Sys.getenv("AUSPOL_...", default) read inside a function is
                                             # invisible to it, so two runs differing only in that value
                                             # write the SAME filename and the second silently overwrites
                                             # the first. That happened on 2026-09-12 while measuring this
                                             # very switch.
  AUSPOL_SD_DEPARTED         = "0",          # 1 = extend the per-cell sd override to ALP/LNP cells in seats
                                             # whose previous GENERAL-election winner is not on the ballot.
                                             # UNDER TEST 2026-09-16, not adopted.
                                             # docs/plans/prereg-departed-member-width-2026-09-16.md
                                             #
                                             # Measured motivation: in NSW the held party's own primary error
                                             # spreads from sd 5.17 when their member stands to 8.81 when they
                                             # go (federal 1.06x, other states 1.22x), while
                                             # simulate_seat_contests() gives every seat in the chamber ONE
                                             # seat_sd. A NSW seat held by 5+ points whose member has gone is
                                             # called wrong 26.2% of the time against 1.8% otherwise.
                                             #
                                             # Requires AUSPOL_XGB_PRIMARY_SD=1 to have any effect, since it
                                             # widens the `keep` mask inside the same override. To test it
                                             # ALONE, set AUSPOL_XGB_PRIMARY_SD_CLASSES to a sentinel that
                                             # matches no class -- otherwise the minor classes switch on too
                                             # and the arm measures two changes at once.
                                             #
                                             # CANNOT REACH vic2026 THIS YEAR: nominations close 12 noon,
                                             # 9 Nov 2026, so which members are standing is unknown until
                                             # then and output/retirement-derived.csv has no vic2026 rows.
  AUSPOL_XGB_SURGE_SRC       = "output/xgb-emergence-v5-seat.csv",
                                             # which emergence model AUSPOL_XGB_SURGE reads. v5 is candidate-level
                                             # (scripts/fit_xgb_emergence_v5.R); v4 was party-class level and gave
                                             # Wentworth a 1.1% hazard because Allegra Spender's 0 -> 35.8 showed up
                                             # as the IND class moving 33.0 -> 35.8. Point this at
                                             # output/xgb-emergence-v4-oof.csv only to reproduce the old arm --
                                             # note v4 writes one row per (seat, class) and v5 one per seat, so the
                                             # override's duplicate-seat guard will reject the v4 file as-is.
  AUSPOL_XGB_SURGE           = "0",          # harness-only: 1 = surge_h/surge_party/surge_mu/surge_sd come from the
                                             # XGBoost emergence model (R/xgb_surge_override.R) instead of the
                                             # salience hazard. BUILT, NOT SHIPPED.
                                             #
                                             # The hazard itself is good -- out-of-fold AUC 0.936 against the
                                             # salience version's 0.751, and ONP goes from 0.201 (actively inverted)
                                             # to 0.862 -- and on sa2026 it moves seat log loss 0.6362 -> 0.5891.
                                             # It is not shipped because it FAILED its own pre-registered bar
                                             # (rms_z 3.93 -> 2.83 against 2.50) and because a calibration check
                                             # says it is now OVER-dispersed: it scores 2.83 on reality against
                                             # 3.48 on data generated from its own predicted distributions.
                                             # The deciding test is a seat COUNT -- 26 of 2,050 historical
                                             # seat-elections were won by an emerging non-major -- and that has not
                                             # been run. Wired into backtest_candidate_sa.R only; the live path is
                                             # an unimplemented stub. docs/plans/prereg-xgb-surge-parameters-2026-09-11.md
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
                                             # predictions from the file AUSPOL_XGB_PRIMARY_OOF names -- since
                                             # 2026-09-18 the POINT-IN-TIME ("as at") models, one per election,
                                             # trained only on earlier elections; before that, leave-one-pair-out.
                                             # This is the backtest counterpart of AUSPOL_XGB_PRIMARY_LIVE and is
                                             # leakage-free by construction; the live flag above is the one that ships.
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
                                             # THE COST, MEASURED, 22 pairs / 2,050 seat-elections, 3 seeds:
                                             # pooled seat log loss 0.3001 leaked -> 0.3117 honest, +0.0116
                                             # (seed sd 0.0015 either side, so the gap is ~8x the noise).
                                             # Concentrated where you would expect: sa2026, the One Nation surge
                                             # election, 0.4200 -> 0.5564. Every headline number quoted before
                                             # 2026-09-11 was the leaked one.
  AUSPOL_EDU_RESID           = "0",          # 1 = correct each seat's minor-party primary by what Year 12
                                             # completion explains about the model's RESIDUAL, one coefficient
                                             # per class fitted leave-one-pair-out (R/education_residual.R).
                                             # UNDER TEST, not adopted: pre-registered in
                                             # docs/plans/prereg-education-residual-correction-2026-09-15.md
                                             # against pooled SEAT LOG LOSS, which is not yet measured. What IS
                                             # measured is per-seat primary RMSE, where it improves all six arms
                                             # (ONP on the shipped arm 3.1000 -> 3.0086) but WORSENS the two
                                             # elections where One Nation is largest -- sa2026 +0.636 and
                                             # qld2020 +0.203 -- which is a named refusal condition.
  AUSPOL_EDU_RESID_FEATURE   = "yr12_pct",   # which census column. "born_aus_pct" was pre-registered as the
                                             # PLACEBO and was NOT one -- r(yr12_pct, born_aus_pct) = -0.706 over
                                             # 1,989 seats, so both read one class-and-urbanity axis from opposite
                                             # ends. It recovered 71% of the gain and refused the mechanism
                                             # (prereg-education-residual-correction-2026-09-15.md, RESULT).
  AUSPOL_STATE_DEV           = "1",          # "2" = v2 arm (plans/prereg-state-deviation-v2-2026-09-19.md), NOT shipped. ADOPTED 2026-09-15. Corrects a federal seat's primaries for how its STATE
                                             # is moving against the national swing. Pete's diagnosis: WA 2022 swung to
                                             # Labor far harder than the country, mean ALP per-seat primary error +6.43
                                             # over 15 seats, positive in 14 of them.
                                             # Federal pooled seat log loss 0.2584 -> 0.2539 over 1,052 seat-elections,
                                             # 0 of 10 permutation-control draws beating it, control mean landing on the
                                             # baseline (+0.0001). All five refusal conditions checked and none fired.
                                             # docs/plans/prereg-state-deviation-2026-09-15.md
                                             # FEDERAL ONLY by construction, and that is not a parity gap -- a state
                                             # election has no deviation-from-national to correct.
                                             # NO EFFECT ON THE PUBLISHED VICTORIAN FORECAST: fit_seats_full.R has no
                                             # call site, so this changes what the federal backtest measures and
                                             # nothing else. fed2019 REGRESSES (+0.0110) because state polls failed the
                                             # same way national polls did that year -- an inherent property.
  AUSPOL_STATE_POLL_EXTRA    = "0",          # TESTING 2026-10-02: every pollster's state crosstabs into the state-deviation features (scripts/build_state_deviation_features.R). plans/prereg-state-polls-extra-2026-10-02.md
  AUSPOL_NOM_ZERO            = "2",          # SHIPPED v61 2026-10-03 (mode 2, freed share by flows): zero every class with no candidate standing, after the xgb override, all six harnesses (R/nomination_zero.R). plans/prereg-nomination-zero-2026-10-03.md
  AUSPOL_NOM_ZERO_ORDER      = "late",       # SHIPPED 2026-10-04 (Pete, overriding the R2 refusal: ALP +0.0045 / GRN +0.0020 points of bias on a paired SE of ~0.002; all 22 pairs, every other clause passed; docs/reviews/zero-order-22pair-2026-10-04.md): where the six harnesses run the v61 zeroing. "early" (the v61 measurement order) = right after the xgb override; "late" = after the last step that can write a share back into a zeroed cell (seat-swing port, demographic, leader, salience blend), as fit_seats_full.R already does. Harnesses only. plans/prereg-zero-order-2026-10-03.md
  AUSPOL_NOM_LIVE            = "auto",       # v61 in the PUBLISHED Victorian forecast (fit_seats_full.R): zero non-standing parties ONLY when set to "1" by hand after the VEC final vic2026 list is loaded into candidacies.csv ("auto"/"0" stay shut; under "1" any failure to apply, or an unrecognised value, STOPS the run; needs >=85% of vic2022 candidacies; absent ALP/LNP seats are warned, not blocked). Runs after the last step that can add share to a cell. Logged as NZL. November procedure: docs/PIPELINE.md section D.
  AUSPOL_COUNCIL_EXTRA       = "0",          # TESTING 2026-10-02: NSW councils that ran their own elections + mayors chosen by councillors (scripts/build_council_history.py). plans/prereg-council-extra-2026-10-02.md
  AUSPOL_STATE_POLL_POOL     = "1",          # SHIPPED v60 2026-10-02 (Pete overrode the prereg clause): state signal pooled from seat polls, federal harness only, before the seat-poll blend (R/state_poll_pool.R). plans/prereg-state-poll-pool-2026-10-02.md
  AUSPOL_STATE_DEV_SHUFFLE   = "0",          # control: permutes which state each seat sits in, within its election.
  AUSPOL_DEMO_RESID          = "2",          # SHIPPED 2026-09-29 (rebuilds V/W passed). 2 = Labor + Greens on the current model's time-forward misses (2026-09-29, plans/prereg-demographic-labor-greens-2026-09-29.md); 1 = Arm A of docs/plans/prereg-demographic-axis-2026-09-15.md:
                                             # correct each seat's minor-party primary using ALL SEVEN census
                                             # columns under a leave-one-pair-out elastic net, instead of the one
                                             # hand-picked column the refused AUSPOL_EDU_RESID used. No intercept,
                                             # so corrections sum to zero within a pair and statewide class totals
                                             # are untouched. UNDER TEST -- do not turn on without the plan's
                                             # criterion being met.
  AUSPOL_DEMO_RESID_SHUFFLE  = "0",          # control for the above; same permutation as AUSPOL_EDU_RESID_SHUFFLE.
  AUSPOL_EDU_RESID_SHUFFLE   = "0",          # the real control. 0 = off; any other integer is an RNG seed that
                                             # PERMUTES each census column across seats WITHIN each election, at
                                             # fit and at apply both. Breaks the seat-to-demographics link while
                                             # leaving every marginal and the whole procedure intact, so whatever
                                             # still "improves" is the procedure's own flexibility. With seven
                                             # mutually correlated census columns there is no other-column
                                             # placebo that works, which is the lesson born_aus_pct cost.
  AUSPOL_HISTORIC_ELECTED_BACKFILL = "1",
                                             # build-time: 1 = derive historic_elected for STATE elections from our
                                             # own prior winners (scripts/build_candidacies.R, BC9). The AEC ships
                                             # HistoricElected only in federal files, so all 21 state elections
                                             # record ZERO returning members -- false about the world, and it makes
                                             # the column a federal/state label inside the model.
                                             # ON since 2026-09-15, when the Victorian candidate list arrived
                                             # (e8c5eab) and made the precondition true: Victoria now carries real
                                             # values like every other state, so the live path reads 62 returning
                                             # members instead of a default.
                                             #
                                             # SHIPPED AGAINST A SLIGHTLY WORSE BACKTEST, deliberately, and the
                                             # number is here so the trade is visible: isolated A/B, same code,
                                             # pooled primary RMSE 3.8078 -> 3.8219, worse in 5 of 6 jurisdictions;
                                             # on seat log loss sa2026 moved 0.3260 -> 0.3256, which is nothing.
                                             # The backtest CANNOT see the gain: vic2026 is the target, never a
                                             # training pair, so the 62 returning members can only move the live
                                             # forecast and never the RMSE. Turning it off now would mean holding
                                             # real information out of the only election being forecast in order to
                                             # protect a 0.014 number on elections already decided.
                                             # Was OFF from b2c5572 to e8c5eab, when the live path had no Victorian
                                             # candidate data and this would have made the 0-default a false claim.
  AUSPOL_XGB_PRIMARY_OOF     = "output/xgb-primary-asat-predictions.csv",
                                             # harness-only: which predictions file the line above reads.
                                             # REPOINTED 2026-09-18 to the POINT-IN-TIME models
                                             # (scripts/fit_xgb_primary_asat.R): one model per election, trained
                                             # only on pairs whose polling day precedes it, same recipe and
                                             # base_margin mode as the production model (fit_xgb_primary_v6_final.R,
                                             # cutoff = now). Pete's call: the AEF-7 ledger is the debugging surface
                                             # for PRODUCTION, so it must be produced by the production pipeline
                                             # frozen at an earlier date -- not by a leave-one-out cache that lets
                                             # fed2022's model learn from fed2025. The leave-one-out file
                                             # (xgb-primary-v6-oof-predictions.csv) is a diagnostic now, still
                                             # written by fit_xgb_primary_v6.R, never shipped. Rebuild everything
                                             # in the non-circular order with scripts/rebuild_forecasts.sh.
                                             # Previously REPOINTED
                                             # 2026-09-17 from v7's "v7f" arm straight to v6's own output -- v7
                                             # (fit_xgb_primary_v7.R) is BYPASSED for primary-vote shipping as of
                                             # this change, not because v7's own features (jump_pctile fix,
                                             # candidate-level features, the ret_exp IND-retention feature that
                                             # justified pointing here in the first place) stopped working, but
                                             # because v6 WITH base_margin (AUSPOL_XGB_BASE_MARGIN=2 above) measured
                                             # better than v7f, fresh, same day: pooled AEF7 primary RMSE 3.6082 vs
                                             # v7f's 3.6715, and 3.7603 vs 3.7914 pooled across all 23 pairs. v7's
                                             # own gains were real when measured (2026-09-13) but did not survive
                                             # being re-compared against a v6 that now also has base_margin -- v7
                                             # itself was never re-run WITH base_margin threaded through its own
                                             # separate training code (an "800+ line exploratory file" per its own
                                             # header, per Pete's call not attempted the same day). Re-integrating
                                             # v7's features on top of base_margin is the natural next arm, not
                                             # done here. docs/NEXT-STEPS.md carries the full trace.
                                             #
                                             # output/ is gitignored, so this filename is the ONLY durable record of
                                             # what ships -- regenerate it with:
                                             #   for y in 2010 2013 2016 2019 2022 2025; do  # prior is the election before
                                             #     AUSPOL_NB_TARGET=$y AUSPOL_NB_PRIOR=<prev> Rscript scripts/build_notional_baselines.R
                                             #   done
                                             #   Rscript scripts/fit_xgb_primary_v6.R
                                             # THE NOTIONAL-BASELINES STEP IS NOT OPTIONAL and was missing from this
                                             # recipe until 2026-09-14. build_notional_baselines.R does ONE pair per
                                             # invocation, and output/ is gitignored -- so on a fresh checkout the
                                             # file does not exist, v6 logs "XG6n! ... missing" and carries on, and
                                             # the "shipped" oof file comes out silently WITHOUT the notional prior
                                             # it is supposed to carry. v7 is NO LONGER PART OF THIS RECIPE -- do not
                                             # run fit_xgb_primary_v7.R to regenerate this file; that would silently
                                             # re-point at the mechanism this change moved away from.
                                             # v6 must run before v7: v7 loads its persisted feature matrix as its base,
                                             # including the notional-prior x_notional_adj column. Set to "" to fall
                                             # back to plain v6 (output/xgb-primary-v6-oof-predictions.csv).
  AUSPOL_FLOW_SHRINK_K       = "0",          # data-weighted flow-cell smoothing -- REFUSED 2026-09-10, worse pooled at every tested k (0.339-0.354 vs baseline 0.339); helps Ballarat's own cell exactly as designed but federal/WA dominate the aggregate. docs/reviews/flow-cell-shrinkage-REFUSED-2026-09-10.md
  AUSPOL_LIVE_LEVEL_ANCHOR   = "0",          # TURNED OFF 2026-09-30 with AUSPOL_LEVEL_RECIPE="live" (v56): over all 22 elections the un-anchored level scores better, and the live forecast must use the level the backtests score. Was: SHIPPED 2026-09-28 (Pete: "use the method that performs best"; anchored 0.2951 vs live 0.2966, plans/prereg-level-recipe-2026-09-28.md). Moves live ALP ~34.9 -> ~31.1 seats. PARITY FIX (plans/prereg-live-level-anchor-2026-09-28.md): live fit_seats_full.R shifts ALP/LNP in state_mean so the statewide LEVEL implies the projected two-party, as the backtests' anchored level always has. "0" = the old live behaviour (raw trend level; anchoring reached only the draws, whose mean the seat sim subtracts). Live-only: the backtests already do this.
  AUSPOL_LIVE_DRAW_BUCKET    = "1",          # PARITY FIX 2026-09-28 (same prereg, amendment 2): live statewide draws split the unpolled bucket (OTH/IND/OTH_RIGHT) by its 2022 ratio instead of taking the whole total for OTH and adding IND and OTH_RIGHT on top. "0" = the old double count. Live-only.
  AUSPOL_SHIP_TIME_FORWARD   = "1",          # LEAK FIX, ledger v51 2026-09-29 (0.2719 -> 0.2760, shipped as pre-registered; plans/prereg-ship-fallback-time-forward-2026-09-29.md): thin minor-slope cells fall back to the tier's pooled slope from earlier elections, not the SHIP_* constants fitted on every election. "0" = the old constants, comparison only.
  AUSPOL_SLOPE_SHRINK        = "0",          # ARM (plans/prereg-slope-shrinkage-2026-09-28.md): "1" shrinks the base_pred slopes toward 1 by cross-election precision (>= 3 elections) instead of the min_n cliff.
  AUSPOL_SEAT_CONTEXT_MARGIN = "0",          # ARM (plans/prereg-seat-context-complete-2026-09-28.md phase 2): "all" = our estimate everywhere incl. live (one source); "1" fills the seat file's missing two-party margin from our estimate (r 0.984 vs the seat file). Previous swing not filled (r 0.875).
  AUSPOL_SITTING_MEMBER_ADJ  = "0",          # ARM (plans/prereg-sitting-member-baseline-2026-09-28.md): "1" adds a time-forward, shrunk sitting-member shift to base_pred for the two majors (member stands / member gone / challenger where gone), training features and live.
  AUSPOL_FUND_TIME_FORWARD   = "1",          # LEAK FIX, ledger v51 2026-09-29 (0.2719 -> 0.2760, shipped as pre-registered; plans/prereg-statewide-time-forward-2026-09-29.md): backtest statewide fundamentals and trend mix fitted on earlier elections only; "0" = the old leave-one-out / all-elections tables.
  AUSPOL_SEAT_POLL_BLEND     = "1",          # SHIPPED 2026-09-29 as v50 ["3" TESTING 2026-09-30: primary and two-party seat-poll gaps with jointly fitted weights, plans/prereg-seat-poll-joint-fp-tpp-2026-09-30.md] (ledger 0.2812 -> 0.2719; "2" = separate partially pooled MRP and direct weights, plans/prereg-seat-poll-mrp-split-2026-09-29.md; plans/prereg-seat-poll-blend-2026-09-29.md): "1" pulls polled (seat, class) primaries toward seat polls by a time-forward shrunk weight, after the override and port; harnesses (xgb layer only) and live.
  AUSPOL_SEAT_POLL_SOURCES   = "all",        # TESTING 2026-09-29 (plans/prereg-seat-poll-public-only-2026-09-29.md): "public" = MRP releases plus direct polls by PUBLIC_SEAT_POLLSTERS with no recorded sponsor; read by seat_poll_shares(), so the weight fit and the blend see the same polls.
  AUSPOL_SEAT_POLL_MATCH     = "class",      # TESTING 2026-09-29 (plans/prereg-seat-poll-per-poll-match-2026-09-29.md): "perpoll" compares each poll only on the classes it names and its catch-all "Others" with the sum of ours (seat_poll_implied()); blend mode 1 only, backtests only until shipped.
  AUSPOL_SEAT_POLL_TPP_SOURCE = "all",        # TESTING 2026-09-30 (plans/prereg-seat-poll-tpp-direct-2026-09-30.md): "direct" = mode-3 two-party figures from direct polls only (no MRP releases).
  AUSPOL_SEAT_POLL_IND_MAP   = "0",          # PREREG PENDING (built 2026-10-06, docs/reviews/seat-polls-independents-2026-10-06.md): "1" moves a poll's catch-all OTH figure to class IND when that poll leaves IND blank, OTH >= 10 and the seat has an IND candidate (fed2022 YouGov MRP files Daniel, Scamps, Priestly etc. under OTH); read by seat_poll_shares(), so the weight fit and the blend see the same polls. Every remapped cell is printed (SPIM).
  AUSPOL_SEAT_POLL_IND_WEIGHT = "0",         # PREREG PENDING (built 2026-10-06): "1" gives IND cells that have a direct (non-MRP) poll and pred > 0 their own blend weight, fitted time-forward on earlier IND direct cells and partially pooled toward the class-blind weight; blend modes 1 and 2, class match only. Printed per target (SPIW).
  AUSPOL_SEAT_POLL_HANDKEYED = "0",          # PREREG PENDING (built 2026-10-06): "1" appends external/reference/polls/seat-polls/hand_keyed_primaries.csv (Mayo fed2016 ReachTEL, Wakehurst nsw2023: primaries the Wikipedia tables lack) to the seat-poll table in seat_poll_shares().
  AUSPOL_LEADER_SEAT         = "1",       # SHIPPED 2026-09-29 (rebuild X passed) (plans/prereg-leader-seat-2026-09-29.md): "1" adds the time-forward leader-seat bonus (per role: head of government, opposition, minor-party leader, partially pooled) to each party in its own leader's seat; harnesses and live.
  AUSPOL_DEPARTED_FED        = "0",          # REFUSED 2026-09-30, both "1" (full size) and "gap" (plans/prereg-departed-fed-gap-2026-09-30.md): qld2020 and sa2026 worse. "1" pulls a departed member's party toward the same booths' federal vote plus a learned share of their old premium; state harnesses and live.
  AUSPOL_SEAT_SWING_PORT     = "2",          # SHIPPED 2026-09-29 as v48 (ledger 0.2840 -> 0.2756; plans/prereg-seat-swing-port-v2-2026-09-29.md): "2" moves each state seat's Labor-v-Coalition primaries by a time-forward, shrunk coefficient times its transposed federal swing deviation, after the xgb override, harnesses and live. "1" is the retired August port (fixed 0.7452, applied before the override, which erases it).
  AUSPOL_SEAT_SWING_PORT_WA  = "2",          # SHIPPED 2026-10-06 (Pete override; WA-only, cliff kept; wa2025 -0.0064 log loss, 0.55 SE, nothing else moves). Was: PREREG PENDING (built 2026-10-05, Pete: "why is WA special?"): "1" runs the seat-swing port in the WA harness and adds the five WA cycles (transposed federal swing, fed-swing-transposed-wa.csv) to EVERY target's pooled fit; "2" runs it in the WA harness and pools WA cycles only for WA targets, so vic/nsw/qld/sa are untouched. "3" (Pete 2026-10-05) pools WA like "1" and gives each state its own coefficient partially pooled toward the all-state one (b* = mu + w (b_state - mu)), for every state harness and live. WA harness only; live Victoria never reads it at "0".
  AUSPOL_BREAKOUT_MIX        = "0",          # PREREG PENDING (built 2026-10-06, Pete approved working on it; docs/reviews/breakout-risk-design-2026-10-05.md, R/breakout_mix.R): "1" gives each non-major class predicted 0-15 in a seat a time-forward, calibrated probability p of breaking out (xgb classifier on 47 pre-election features, earlier elections only); in each draw, with probability p its share is drawn from earlier breakouts' shares and the rest of the seat scaled down. Inside simulate_seat_contests() (both engines); six harnesses and live via breakout_mix_args().
  AUSPOL_BREAKOUT_MIX_MIN_P  = "0",          # PREREG PENDING (prereg-breakout-mix-gated-2026-10-06.md): only cells with breakout p >= this carry the mixture; "0" = all eligible cells.
  AUSPOL_SEAT_SWING_PORT_NOCLIFF = "0",      # PREREG PENDING (built 2026-10-05): "1" replaces the port's "fewer than 3 earlier cycles gives 0" cliff with pure shrinkage (se doubled, SEAT_SWING_NOCLIFF_SE_INFLATE). Moves vic2018, nsw2019, qld2020 and the early WA cycles off zero.
  AUSPOL_SEAT_CONTEXT_FILL   = "1",         # SHIPPED 2026-09-28 as v46 (Pete, over a +0.0003 log-loss tie; plans/prereg-seat-context-complete-2026-09-28.md): "1" fills incumbent party and retiring member from output/seat-context.csv where the seat file has none (13 of 22 training pairs). Blanks only.
  AUSPOL_TIME_FORWARD_FITS   = "1",          # LEAK FIX 2026-09-28 (plans/prereg-time-forward-constants-2026-09-28.md): every constant fitted inside base_pred (slopes, discounts, htv flow, state deviation, flow-rate inputs) learns only from elections dated before the target. "0" = the old leave-target-out, comparison only.
  AUSPOL_XGB_DEPARTED_SIDE   = "0",          # ARM (plans/prereg-departed-member-sides-2026-09-28.md): "1" adds own_departed_i / opp_departed_i (which side lost its sitting member) to the xgb seat model, training and live.
  AUSPOL_BUCKET_TOTAL        = "poll",       # ARM (plans/prereg-bucket-total-candidates-2026-09-28.md): "cand" sets the unpolled bucket's total from the per-candidate model before the two-party anchoring.
  AUSPOL_BUCKET_SPLIT        = "cand_naive", # SHIPPED 2026-09-28 as ledger v44 (0.2963 -> 0.2881; plans/prereg-bucket-split-candidates-2026-09-28.md): "cand_resid"/"cand_naive" split the unpolled others bucket by the per-candidate model (scripts/fit_minor_candidates.R) instead of the previous election's mix. Backtests only until 9 Nov nominations.
  AUSPOL_LEVEL_RECIPE        = "live",       # SHIPPED 2026-09-30 as v56 WITH AUSPOL_LIVE_LEVEL_ANCHOR="0" (prereg-level-recipe-retest, RESULT ON v55): backtests and the live forecast both use the un-anchored level (trend endpoints rescaled to 100); 22 elections -0.0024, RMSE 4.2111 -> 4.1617, ledger 0.2761 -> 0.2741. Was "anchored". "unanchored" (TESTING 2026-09-30, plans/prereg-level-anchor-alone-2026-09-30.md) = anchor off, no rescale; "live" scores the live forecast's level recipe in the backtests (endpoints rescaled to 100, not anchored). plans/prereg-level-recipe-2026-09-28.md.
  AUSPOL_CLOSE_PROPORTIONAL  = "0",          # ARM (plans/prereg-close-proportional-2026-09-28.md): "1" closes the statewide total by rescaling every fitted class to 100 instead of making OTH the remainder. Both paths (R/forecast_mode.R; fit_seats_full.R LL1 when AUSPOL_LIVE_LEVEL_ANCHOR=1).
  AUSPOL_OTHERS_SCALE        = "0",        # ARM, REFUSED 2026-09-28 (plans/prereg-others-bucket-size-2026-09-27.md): "1" shrinks the unpolled others bucket by its time-forward poll bias (R/others_bucket.R). Backtest path only; live fit_seats_full.R not wired because it did not pass. Needs output/others-bucket-history.csv.
  AUSPOL_ANCHOR_EXHAUST      = "0",          # ARM, not shipped (plans/prereg-anchor-exhaust-2026-09-27.md): "1" computes the anchoring's implied two-party NET OF EXHAUSTED BALLOTS (derive_tpp()'s basis), so NSW's OPV target is compared like with like. No effect where flows carry no exhaust (every non-NSW election, and live Victoria).
  AUSPOL_ANCHOR_IMPLIED      = "0"        # ARM, not shipped (plans/prereg-anchor-implied-tpp-2026-09-20.md): "1" feeds the two-party mix the draws' OWN flow-implied two-party instead of the trend's published TPP series, so the anchoring applies only the fundamentals' pull; in the backtests it also zeroes unpolled classes (the phantom vote). Live Victoria gets the first half only -- its unpolled classes draw from their seat mean, not from 0 +/- 2.85.
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
