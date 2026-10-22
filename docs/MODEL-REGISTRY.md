# Model registry

**Generated 2026-10-23 by `scripts/build_model_registry.R`. Do not hand-edit** --
rerun the script instead. Regenerate whenever a switch is added to
`published_flags.R` or a harness's wiring changes.

This exists because "now works in every harness" has been claimed and been
wrong twice (AUSPOL_SEED hardcoded in WA; AUSPOL_SEAT_SD_MULT never reaching
`fit_seats_full.R` at all), both found 2026-09-09 by checking every switch by
hand instead of trusting the prior claim. The table below is regenerated from
the actual scripts, not remembered.

`yes*` means the switch's NAME is present in the file (often only in a
disclosure comment explaining that it is NOT wired) but is not functional
wiring -- see the explained section below for which ones and why.

## What each entry point is

| entry point | what it is | jurisdiction |
|---|---|---|
| `fit_seats_full.R` | **the published forecast** -- the only script whose output is real | Victoria (live target) |
| `backtest_candidate_fed.R` | backtest harness | Federal |
| `backtest_candidate_nsw.R` | backtest harness | New South Wales |
| `backtest_candidate_qld.R` | backtest harness | Queensland |
| `backtest_candidate_sa.R` | backtest harness | South Australia |
| `backtest_candidate_vic.R` | backtest harness | Victoria |
| `backtest_candidate_wa.R` | backtest harness | Western Australia |

All seven share one `R/` package core (`simulate_seat_contests()`,
`reentry_prior.R`, `salience_surge.R`, etc.) -- differences between them are
in which switches each one WIRES and which data source each reads, not in
separate model code.

## Switch parity (234 switches from `published_flags.R`, 7 entry points)

The last column lists the `R/` files whose code (not comments) reads the switch. A row of `NO`s with a file there is shared-function wiring: every entry point that calls that function honours it. Presence is still not value: a hardcoded constant beside the read (audit F3) or a swapped table (F10) scores "yes" here.

| switch | fit_seats (published) | fed | nsw | qld | sa | vic | wa | read in `R/` |
|---|---|---|---|---|---|---|---|---|
| `AUSPOL_ANCHOR_EXHAUST` | yes | NO | NO | NO | NO | NO | NO | forecast_mode.R |
| `AUSPOL_ANCHOR_IMPLIED` | yes | NO | NO | NO | NO | NO | NO | forecast_mode.R |
| `AUSPOL_ASAT_MIN_PAIRS` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_BREAKOUT_MIX` | NO | NO | NO | NO | NO | NO | NO | breakout_mix.R |
| `AUSPOL_BREAKOUT_MIX_MIN_P` | NO | NO | NO | NO | NO | NO | NO | breakout_mix.R |
| `AUSPOL_BUCKET_SPLIT` | yes | NO | NO | NO | NO | NO | NO | forecast_statewide.R |
| `AUSPOL_BUCKET_TOTAL` | NO | NO | NO | NO | NO | NO | NO | forecast_mode.R, forecast_statewide.R |
| `AUSPOL_BYELEC_DEPARTED` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_BYELEC_LEVEL` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_BYELECTION_FILL` | NO | NO | NO | NO | NO | NO | NO | byelection_prior.R |
| `AUSPOL_BYELECTION_MP` | NO | NO | NO | NO | NO | NO | NO | byelection_prior.R, candidate_returns.R |
| `AUSPOL_BYELECTION_PRIOR` | yes | yes | yes | yes | yes | yes | yes | byelection_prior.R |
| `AUSPOL_CENSUS_FILE` | NO | NO | NO | NO | NO | NO | NO | demographic_residual.R |
| `AUSPOL_CLASS_CONSERVE` | NO | NO | NO | NO | NO | NO | NO | nomination_zero.R |
| `AUSPOL_CLOSE_PROPORTIONAL` | yes | NO | NO | NO | NO | NO | NO | forecast_mode.R |
| `AUSPOL_COALITION_SPLIT` | NO | NO | NO | NO | NO | NO | NO | coalition_split.R |
| `AUSPOL_COALITION_SPLIT_F` | NO | NO | NO | NO | NO | NO | NO | coalition_split.R |
| `AUSPOL_COMPOSITION_SD` | NO | NO | NO | NO | NO | NO | NO | size_sd.R |
| `AUSPOL_CONSERVE_SHRINK_K` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_CONSERVE_TF` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_CONTEST_BASE` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_COUNCIL_EXTRA` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_COV_LOO` | NO | NO | NO | NO | NO | NO | NO | statewide_cor.R |
| `AUSPOL_COV_TF` | NO | NO | NO | NO | NO | NO | NO | statewide_cor.R |
| `AUSPOL_CROSS_SEAT_VOTE` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_DEFECT_BY_LEVEL` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_DEFECT_CONSERVE` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_DEFECT_DISCOUNT` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_DEFECT_POOLED` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_DEFECT_SIZE` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_DEFECTOR_STATE` | NO | NO | NO | NO | NO | NO | NO | defector_state.R |
| `AUSPOL_DEMO_RESID` | yes | yes | yes | yes | yes | yes | yes | demographic_residual.R |
| `AUSPOL_DEMO_RESID_FULL` | NO | NO | NO | NO | NO | NO | NO | demographic_residual.R |
| `AUSPOL_DEMO_RESID_SHUFFLE` | NO | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_DEPARTED_FED` | yes | NO | NO | NO | NO | NO | NO | departed_fed.R |
| `AUSPOL_DEPARTED_HOLD` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_DEPARTED_HOLD_MIN_PRIOR` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_DEPARTED_ORIGIN` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_DEPARTED_SUCCESSOR` | yes | yes | yes | yes | yes | yes | yes | departed_successor.R, new_ind_shrink.R |
| `AUSPOL_DEV_SLOPE` | NO | NO | NO | NO | NO | NO | NO | dev_slope.R |
| `AUSPOL_DEV_SLOPE_MODE` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_DISPERSION_SLOPE` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_EDU_RESID` | NO | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_EDU_RESID_FEATURE` | NO | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_EDU_RESID_SHUFFLE` | NO | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_ERROR_DIST` | NO | NO | NO | NO | NO | NO | NO | error_dist.R |
| `AUSPOL_ERROR_DIST_COMP` | NO | NO | NO | NO | NO | NO | NO | error_dist.R |
| `AUSPOL_FALLBACK_SMOOTH` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_FIT_SLOPES` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_FLOW_ASAT` | NO | NO | NO | NO | NO | NO | NO | xgb_flow_override.R |
| `AUSPOL_FLOW_CELL_SD` | NO | yes | yes | yes | yes | yes | yes | xgb_flow_override.R |
| `AUSPOL_FLOW_FRAG` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_FLOW_MODEL_TAG` | NO | yes | yes | yes | yes | yes | yes | xgb_flow_override.R |
| `AUSPOL_FLOW_RATE_HL` | NO | NO | NO | NO | NO | NO | NO | xgb_flow_override.R |
| `AUSPOL_FLOW_SD` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_FLOW_SHIFT` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_FLOW_SHRINK_K` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_FLOW_TF` | NO | NO | NO | NO | NO | NO | NO | xgb_flow_override.R |
| `AUSPOL_FORCE_FP` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_FORCE_FP_RULE` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_FORECAST_MODE` | NO | yes | NO | NO | NO | NO | NO | forecast_statewide.R |
| `AUSPOL_FP_EXTRA_SD` | NO | NO | NO | NO | NO | NO | NO | forecast_statewide.R |
| `AUSPOL_FP_SD_MODE` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_FUND_TIME_FORWARD` | NO | yes | NO | NO | NO | NO | NO | forecast_statewide.R |
| `AUSPOL_HARNESS_SW_DRAWS` | NO | NO | NO | NO | NO | NO | NO | forecast_statewide.R |
| `AUSPOL_HC_DEFECTOR` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_HISTORIC_ELECTED_BACKFILL` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_HONOUR_DEPARTED` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_HTV_EXCLUDE` | NO | NO | NO | NO | NO | NO | NO | htv_flow.R |
| `AUSPOL_HTV_FLOW` | yes | yes | yes | yes | yes | yes | yes | htv_flow.R |
| `AUSPOL_IND_MIXTURE` | NO | NO | NO | NO | NO | NO | NO | ind_mixture.R, new_ind_shrink.R |
| `AUSPOL_IND_PERSON` | NO | NO | NO | NO | NO | NO | NO | ind_person.R, new_ind_shrink.R |
| `AUSPOL_IND_PERSON_CARRY` | NO | NO | NO | NO | NO | NO | NO | ind_person.R |
| `AUSPOL_IND_PERSON_DIR` | NO | NO | NO | NO | NO | NO | NO | ind_person.R |
| `AUSPOL_IND_SALIENCE` | NO | yes | NO | NO | NO | NO | NO |  |
| `AUSPOL_IND_TYPICAL` | NO | NO | NO | NO | NO | NO | NO | ind_mixture.R, ind_typical.R, new_ind_shrink.R |
| `AUSPOL_IND_TYPICAL_STAT` | NO | NO | NO | NO | NO | NO | NO | ind_typical.R |
| `AUSPOL_INSURGENCY_SHRINK` | NO | yes | NO | NO | NO | NO | NO |  |
| `AUSPOL_LEADER_SEAT` | yes | NO | NO | NO | NO | NO | NO | leader_seat.R |
| `AUSPOL_LEADERS_SUPPLEMENT` | NO | NO | NO | NO | NO | NO | NO | leader_seat.R |
| `AUSPOL_LEVEL_FED_GAP_HL` | NO | NO | NO | NO | NO | NO | NO | level_recent.R |
| `AUSPOL_LEVEL_FED_R` | NO | NO | NO | NO | NO | NO | NO | level_recent.R |
| `AUSPOL_LEVEL_MODE` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_LEVEL_MULT_IND` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_LEVEL_MULT_OTH` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_LEVEL_RECENT` | NO | NO | NO | NO | NO | NO | NO | level_recent.R |
| `AUSPOL_LEVEL_RECENT_HALFLIFE` | NO | NO | NO | NO | NO | NO | NO | level_recent.R |
| `AUSPOL_LEVEL_RECIPE` | NO | NO | NO | NO | NO | NO | NO | forecast_mode.R |
| `AUSPOL_LEVEL_SD` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_LIVE_DEFECT_FIT` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_LIVE_DRAW_BUCKET` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_LIVE_LEVEL_ANCHOR` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_LIVE_LEVEL_SPLIT` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_LIVE_SEATPREV_RAW` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_MAJOR_DEPARTED` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_MAJOR_SLOPE` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_MINOR_DEFECT` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_MINOR_DEFECT_BASE_PRED` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_MINOR_DEFECT_CONSERVE` | NO | NO | NO | NO | NO | NO | NO | candidate_returns.R |
| `AUSPOL_MP_SLOPE` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_MP_SLOPE_FILE` | NO | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_MP_SLOPE_TF` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_N_SIMS` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_NB_TARGET` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_NEW_IND_SHRINK` | NO | NO | NO | NO | NO | NO | NO | ind_mixture.R, ind_typical.R, new_ind_shrink.R |
| `AUSPOL_NEW_IND_SHRINK_CAP` | NO | NO | NO | NO | NO | NO | NO | new_ind_shrink.R |
| `AUSPOL_NOM_LIVE` | NO | NO | NO | NO | NO | NO | NO | nomination_zero.R, xgb_primary_override.R |
| `AUSPOL_NOM_ZERO` | NO | NO | NO | NO | NO | NO | NO | nomination_zero.R |
| `AUSPOL_NOM_ZERO_ORDER` | NO | NO | NO | NO | NO | NO | NO | nomination_zero.R |
| `AUSPOL_NOTIONAL` | NO | yes | NO | NO | NO | NO | NO |  |
| `AUSPOL_NSW_THIN_WALK` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_ONP_CONC_SD` | NO | NO | NO | yes | yes | NO | NO |  |
| `AUSPOL_ONP_CV` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_ONP_FIX` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_ONP_ORDER` | yes | NO | yes | yes | yes | NO | NO |  |
| `AUSPOL_OTHERS_SCALE` | NO | NO | NO | NO | NO | NO | NO | forecast_mode.R, others_bucket.R |
| `AUSPOL_PARTY_COR` | yes | yes | yes | yes | yes | yes | NO | forecast_statewide.R |
| `AUSPOL_PB_COALITION_COMBINED` | NO | NO | NO | NO | NO | NO | NO | poll_source.R |
| `AUSPOL_POLL_ARCHIVE` | NO | NO | NO | NO | NO | NO | NO | poll_source.R |
| `AUSPOL_POLL_BT` | NO | NO | NO | NO | NO | NO | NO | poll_source.R |
| `AUSPOL_POLL_PB` | NO | NO | NO | NO | NO | NO | NO | poll_source.R |
| `AUSPOL_POLL_SOURCE` | NO | NO | NO | NO | NO | NO | NO | poll_source.R |
| `AUSPOL_POOL_BY_JURISDICTION` | NO | NO | NO | NO | NO | NO | NO | pool_hierarchical.R |
| `AUSPOL_PUBLISH_NSW2027` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_QLD_CUTOFF` | NO | yes | NO | yes | yes | yes | NO |  |
| `AUSPOL_QLD_FLOWS` | yes | yes | NO | yes | yes | yes | NO |  |
| `AUSPOL_REENTRY` | yes | NO | NO | NO | NO | NO | NO | new_ind_shrink.R, reentry_prior.R |
| `AUSPOL_REENTRY_GAP` | NO | NO | NO | NO | NO | NO | NO | reentry_prior.R |
| `AUSPOL_REENTRY_LINK` | NO | NO | NO | NO | NO | NO | NO | reentry_prior.R |
| `AUSPOL_REENTRY_SPLIT` | NO | NO | NO | NO | NO | NO | NO | reentry_prior.R |
| `AUSPOL_REENTRY_WINSOR` | NO | NO | NO | NO | NO | NO | NO | reentry_prior.R |
| `AUSPOL_SA_CUTOFF` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_SA_FLOWS` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_SALIENCE_BLEND` | NO | NO | NO | NO | NO | NO | NO | salience_surge.R |
| `AUSPOL_SALIENCE_BLEND_ONCE` | yes | NO | NO | NO | NO | NO | NO | salience_surge.R |
| `AUSPOL_SALIENCE_EXP_SD` | NO | yes | yes | yes | yes | yes | NO |  |
| `AUSPOL_SALIENCE_EXPECTED` | yes | yes | yes | yes | yes | yes | NO |  |
| `AUSPOL_SALIENCE_PCTILE_NZ` | NO | NO | NO | NO | NO | NO | NO | salience_surge.R |
| `AUSPOL_SALIENCE_SMOOTH` | NO | NO | NO | NO | NO | NO | NO | salience_surge.R |
| `AUSPOL_SALIENCE_SURGE_V2` | yes | yes | yes | yes | yes | yes | yes* |  |
| `AUSPOL_SD_DEPARTED` | NO | yes | yes | yes | yes | yes | yes | xgb_primary_sd_override.R |
| `AUSPOL_SEAT_CONTEXT_FILL` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_SEAT_CONTEXT_MARGIN` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_SEAT_CONTEXT_SOPH` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_SEAT_POLL_ALLPOLLS` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_BLEND` | yes | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_COALITION_DEDUP` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_CORRECTIONS` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_DECAY` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_ELECTION_ERR` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_FIRM_FLOOR` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_FIRM_SHARED` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_GROUPS` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_HANDKEYED` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_HEAVY_TAIL` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_IND_DIRECT` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_IND_MAP` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_IND_WEIGHT` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_MATCH` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_MODELVAR_ALL` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_MRP_NAME` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_NAMED_ONLY` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_PRECISION_BLEND` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_PRIOR` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_PRIOR_SD` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_SALIENCE_VAR` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_SIZEVAR` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_SOURCES` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_SPLIT_ALL` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_POLL_TPP_SOURCE` | NO | NO | NO | NO | NO | NO | NO | seat_poll_joint.R |
| `AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER` | NO | NO | NO | NO | NO | NO | NO | seat_poll_blend.R |
| `AUSPOL_SEAT_SD_MULT` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_SEAT_SPREAD_SRC` | NO | NO | NO | NO | NO | NO | NO | prev_seat_swing.R |
| `AUSPOL_SEAT_SWING_PORT` | yes | yes | yes | yes | yes | yes | NO | seat_swing_port.R |
| `AUSPOL_SEAT_SWING_PORT_NOCLIFF` | NO | NO | NO | NO | NO | NO | yes | seat_swing_port.R |
| `AUSPOL_SEAT_SWING_PORT_WA` | NO | NO | NO | NO | NO | NO | yes | seat_swing_port.R |
| `AUSPOL_SEED` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_SHIP_TIME_FORWARD` | NO | NO | NO | NO | NO | NO | NO | split_slope.R |
| `AUSPOL_SHRINK` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_SIM_ENGINE` | NO | NO | NO | NO | NO | NO | NO | seat_sim.R |
| `AUSPOL_SITTING_MEMBER_ADJ` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_SIZE_SD` | NO | NO | NO | NO | NO | NO | NO | size_sd.R |
| `AUSPOL_SLOPE_SHRINK` | NO | NO | NO | NO | NO | NO | NO | split_slope.R |
| `AUSPOL_SPLIT_SLOPE` | NO | NO | NO | NO | NO | NO | NO | split_slope.R |
| `AUSPOL_STATE_DEV` | NO | yes | NO | NO | NO | NO | NO |  |
| `AUSPOL_STATE_DEV_SHUFFLE` | NO | yes | NO | NO | NO | NO | NO |  |
| `AUSPOL_STATE_NOTIONAL` | NO | NO | NO | NO | NO | NO | NO | state_notional.R |
| `AUSPOL_STATE_POLL_EXTRA` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_STATE_POLL_POOL` | NO | NO | NO | NO | NO | NO | NO | state_poll_pool.R |
| `AUSPOL_SURGE_FROM_ZERO` | yes | yes | yes | yes | yes | yes | NO |  |
| `AUSPOL_SURGE_H` | yes | yes | yes | yes | yes | yes | yes |  |
| `AUSPOL_SURGE_H_TF` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_SURGE_RECIPIENT` | yes | yes | yes | yes | yes | yes | NO |  |
| `AUSPOL_SURGE_SCALE` | yes | yes | yes | yes | yes | yes | NO |  |
| `AUSPOL_SURGE_SOURCE` | NO | NO | NO | NO | NO | NO | NO | party_surge.R, salience_screen.R |
| `AUSPOL_SW_NET_LIVE` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_THIN_CYCLE` | NO | NO | NO | NO | NO | NO | NO | forecast_statewide.R, hare_clark.R |
| `AUSPOL_TIME_FORWARD_FITS` | NO | NO | NO | NO | NO | NO | NO | fundamentals_tf.R, time_forward.R |
| `AUSPOL_TRAIN_COMPLETENESS` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_TRAIN_DECAY_H` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_TRAIN_DEMEAN` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_TRAIN_SKIP_PAIRS` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_TREND_RW_MULT` | NO | NO | NO | NO | NO | NO | NO | forecast_mode.R |
| `AUSPOL_TREND_SIGMAS` | NO | NO | NO | NO | NO | NO | NO | forecast_mode.R |
| `AUSPOL_TREND_SZC` | NO | NO | NO | NO | NO | NO | NO | trend.R |
| `AUSPOL_UPSET_FLOOR` | yes | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_WA_CUTOFF` | NO | yes | NO | yes | yes | yes | NO |  |
| `AUSPOL_WA_DROP_3C` | NO | yes | NO | yes | yes | yes | NO | external_flows.R |
| `AUSPOL_WA_DROP_LNP` | NO | yes | NO | yes | yes | yes | NO | external_flows.R |
| `AUSPOL_WA_FLOWS` | yes | yes | NO | yes | yes | yes | NO |  |
| `AUSPOL_XGB_BASE_DELTA` | NO | NO | NO | NO | NO | NO | NO | xgb_base_delta.R, xgb_primary_override.R |
| `AUSPOL_XGB_BASE_DELTA_TOL` | NO | NO | NO | NO | NO | NO | NO | xgb_base_delta.R |
| `AUSPOL_XGB_BASE_MARGIN` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_XGB_BASE_RECORD` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_XGB_BOOTH` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_XGB_CONTEST` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_XGB_COUNCIL` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_XGB_DEPARTED_SIDE` | NO | NO | NO | NO | NO | NO | NO | departed_side.R |
| `AUSPOL_XGB_ENDORSE` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_XGB_ENSEMBLE` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_XGB_FLOWS` | yes | yes | yes | yes | yes | yes | yes | xgb_flow_override.R |
| `AUSPOL_XGB_PRIMARY` | NO | yes | yes | yes | yes | yes | yes | nomination_zero.R, salience_surge.R, xgb_primary_override.R |
| `AUSPOL_XGB_PRIMARY_LIVE` | yes | NO | NO | NO | NO | NO | NO | breakout_mix.R, xgb_primary_override.R |
| `AUSPOL_XGB_PRIMARY_OOF` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_XGB_PRIMARY_SD` | NO | yes | yes | yes | yes | yes | yes | xgb_primary_sd_override.R |
| `AUSPOL_XGB_PRIMARY_SD_CLASSES` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_sd_override.R |
| `AUSPOL_XGB_PRIMARY_SD_SRC` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_sd_override.R |
| `AUSPOL_XGB_RATIO_FEATS` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_XGB_SEATPREV_NAFILL` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_XGB_SEED` | NO | NO | NO | NO | NO | NO | NO |  |
| `AUSPOL_XGB_SENATE` | NO | NO | NO | NO | NO | NO | NO | xgb_primary_override.R |
| `AUSPOL_XGB_SURGE` | NO | yes | yes | yes | yes | yes | yes | xgb_surge_override.R |
| `AUSPOL_XGB_SURGE_SRC` | NO | NO | NO | NO | NO | NO | NO | xgb_surge_override.R |
| `AUSPOL_ZERO_ABSENT` | NO | NO | NO | NO | NO | NO | NO | zero_absent.R |

## Every non-universal switch, explained

- **`AUSPOL_ANCHOR_EXHAUST`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-anchor-exhaust-2026-09-27.md). Wired everywhere:  read in R/forecast_mode.R (statewide_draws_as_at()), which every harness and fit_seats_full.R reach: the five state harnesses and fit_seats_full.R through forecast_statewide_or_oracle() -> forecast_statewide_for() (R/forecast_statewide.R:81), the federal harness directly. "No" cells are the harness grep missing the R/ read, not drift (corrected 2026-10-09 after review).  No effect where flows carry no exhaust (every non-NSW election, live Victoria).
- **`AUSPOL_ANCHOR_IMPLIED`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-anchor-implied-tpp-2026-09-20.md). Wired everywhere:  read in R/forecast_mode.R (statewide_draws_as_at()), which every harness and fit_seats_full.R reach: the five state harnesses and fit_seats_full.R through forecast_statewide_or_oracle() -> forecast_statewide_for() (R/forecast_statewide.R:81), the federal harness directly. "No" cells are the harness grep missing the R/ read, not drift (corrected 2026-10-09 after review).  scripts/audit_statewide_forecast.R only prints it.
- **`AUSPOL_ASAT_MIN_PAIRS`** (intentional / dead experiment): Training-time switch for scripts/fit_xgb_primary_asat.R only: the minimum number of earlier election pairs a target must have before it gets its own point-in-time model (default 4). Below it the target gets no model and no row in the predictions file, so the harness keeps base_pred for it and says so. Not a harness or forecast switch.
- **`AUSPOL_BREAKOUT_MIX`** (intentional / dead experiment): ARM (0), UNIVERSAL via R/: read by breakout_mix_args() (R/breakout_mix.R), which all seven entry points reach. The old 'yes' cells were comments.
- **`AUSPOL_BREAKOUT_MIX_MIN_P`** (intentional / dead experiment): PREREG PENDING, default 0 (= every eligible cell, i.e. no gate). Read inside breakout_mix_args() in R/breakout_mix.R, which all six harnesses and fit_seats_full.R call, so the harness grep cannot see it; it reaches all of them when set.
- **`AUSPOL_BUCKET_SPLIT`** (**adopted, shared-function wiring**): SHIPPED 2026-09-28 (ledger v44, 'cand_naive'). Read inside candidate_bucket_ratio() in R/forecast_statewide.R, which every harness and fit_seats_full.R reach through forecast_statewide_for(); only the federal harness names it in a comment. published_flags.R notes the split is backtests-only until the 9 Nov nominations.
- **`AUSPOL_BUCKET_TOTAL`** (intentional / dead experiment): ARM, not shipped (default 'poll'; plans/prereg-bucket-total-candidates-2026-09-28.md). Read in R/forecast_statewide.R (candidate_bucket_total()) and R/forecast_mode.R, both below the harness grep; scripts/build_bucket_total_history.R reads the audit log it produces.
- **`AUSPOL_BYELEC_DEPARTED`** (**adopted, shared-function wiring**): SHIPPED 2026-10-05. Read inside R/candidate_returns.R (the 'member departed' flag after a by-election loss), which every harness and fit_seats_full.R reach through candidate_returns(); the harness grep cannot see it.
- **`AUSPOL_BYELEC_LEVEL`** (**adopted, shared-function wiring**): SHIPPED 2026-10-05 (Pete override of the 2-SE clause). Read in R/candidate_returns.R (a non-major by-election winner is credited the median next-election share); R/cross_seat_vote.R carries a comment that this switch owns those rows. Reaches every harness and fit_seats_full.R through candidate_returns().
- **`AUSPOL_BYELECTION_FILL`** (intentional / dead experiment): REFUSED 2026-09-30 (docs/plans/prereg-byelection-fill-2026-09-30.md): only Lyne improved, xgb error +0.01. Default 0, read only as an argument default in R/byelection_prior.R, so a refused experiment with no reason to be wired anywhere.
- **`AUSPOL_BYELECTION_MP`** (**adopted, shared-function wiring**): SHIPPED 2026-09-19 (plans/prereg-byelection-mp-2026-09-19.md). Read inside R/candidate_returns.R at the top of candidate_returns(): a by-election winner (external/reference/byelections/byelection-winners.csv) is the sitting member for every identity test. Reaches all six harnesses and fit_seats_full.R through that function.
- **`AUSPOL_CENSUS_FILE`** (intentional / dead experiment): DIAGNOSTIC 2026-10-13: alternative census-features table via census_features_path() (R/demographic_residual.R), read by every demographic correction -- universal in practice; published empty.
- **`AUSPOL_CLASS_CONSERVE`** (intentional / dead experiment): ARM (0), UNIVERSAL via R/: read by class_conserve_on() inside zero_unnominated() (R/nomination_zero.R), which every harness and fit_seats_full.R (zero_unnominated_live) reach. plans/prereg-partial-contest-2026-10-19.md
- **`AUSPOL_CLOSE_PROPORTIONAL`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-close-proportional-2026-09-28.md). Read in R/forecast_mode.R (federal harness path) and fit_seats_full.R (the live LL1 step). Off, so the four state harnesses not reaching it changes nothing.
- **`AUSPOL_COALITION_SPLIT`** (intentional / dead experiment): UNIVERSAL via R/: read inside coalition_split_args() (R/coalition_split.R), which every harness (six + NT) and fit_seats_full.R call at their simulate_seat_contests() site, so the per-harness greps cannot see it. SHIPPED (1) 2026-10-17 on Pete's call; 20k deciding run passed every clause (reviews/lib-nat-plumbing-2026-10-16.md).
- **`AUSPOL_COALITION_SPLIT_F`** (intentional / dead experiment): UNIVERSAL via R/: read inside coalition_f() (R/coalition_split.R) through coalition_split_args(), which every harness (six + NT) and fit_seats_full.R call; inert unless AUSPOL_COALITION_SPLIT=1. Prereg amendment 2. SHIPPED (state) 2026-10-17.
- **`AUSPOL_COMPOSITION_SD`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-17 on Pete's override (with AUSPOL_ERROR_DIST), wired EVERYWHERE through R/size_sd.R like AUSPOL_SIZE_SD: size_sd_apply() multiplies in the composition factor, so all seven harnesses and fit_seats_full.R honour it. plans/prereg-composition-spread-2026-10-17.md
- **`AUSPOL_CONSERVE_SHRINK_K`** (**adopted, shared-function wiring**): SHIPPED (3) 2026-10-16, UNIVERSAL via R/: read inside fit_minor_defector_conserve() (R/candidate_returns.R), which every harness and fit_seats_full.R reach through candidate_returns(), so the per-harness greps cannot see it.
- **`AUSPOL_CONSERVE_TF`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-14, UNIVERSAL via R/: read inside fit_minor_defector_conserve() (R/candidate_returns.R); trains on elections before the target. Same reach as AUSPOL_CONSERVE_SHRINK_K.
- **`AUSPOL_CONTEST_BASE`** (intentional / dead experiment): ARM (0), FIT-TIME + LIVE: read by fit_xgb_primary_v6.R (moves base_pred for new-to-seat One Nation cells; writes output/contest-base-weight.csv) and R/xgb_primary_override.R (live, from the confirmed nomination list). Harnesses read the as-at predictions file. plans/prereg-contest-base-2026-10-20.md
- **`AUSPOL_COUNCIL_EXTRA`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, default 0, TESTING (plans/prereg-council-extra-2026-10-02.md). Read only by scripts/build_council_history.py, which builds the council-history input that the xgb council features (AUSPOL_XGB_COUNCIL) read; no R/ or harness call site.
- **`AUSPOL_COV_LOO`** (intentional / dead experiment): Read inside R/statewide_cor.R, not per-harness -- universal in practice, absent from every harness script by design.
- **`AUSPOL_COV_TF`** (intentional / dead experiment): Read inside R/statewide_cor.R, not per-harness -- same as AUSPOL_COV_LOO; default 0 (OFF).
- **`AUSPOL_CROSS_SEAT_VOTE`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-06, UNIVERSAL via R/: read inside personal_prior_vote() (R/candidate_returns.R), which all seven entry points reach. The old 'yes' cells were comments.
- **`AUSPOL_DEFECT_BY_LEVEL`** (**adopted, shared-function wiring**): SHIPPED 2026-10-05 (mode 2: federal targets get their own shrunk sitting-member defector carry). Read inside R/candidate_returns.R (line ~1240), so every harness and fit_seats_full.R get it through that function; the grep cannot see it.
- **`AUSPOL_DEFECT_CONSERVE`** (**adopted, shared-function wiring**): SHIPPED (default 1) and read inside R/candidate_returns.R's personal_prior_vote(), not by any harness directly, so the registry's grep sees it nowhere: a major-party defector's unclaimed vote stays with the origin class instead of vanishing. Reaches every harness and fit_seats_full.R through that one function. scripts/prereg_major_defector_verify.R proves =0 is byte-identical to the pre-switch behaviour.
- **`AUSPOL_DEFECT_POOLED`** (**adopted, shared-function wiring**): ADOPTED 2026-09-09 at "2" (docs/plans/prereg-defector-two-rate- 2026-09-09.md), by Pete on mechanism -- the arm missed its own primary bar (t -2.04 vs 2.08) but every directional indicator was favourable and R4 confirmed the published Victorian forecast is byte-identical (Victoria fields no major-party defector standing as a minor this cycle, so the mechanism does not fire there). Reaches fit_seats_full.R correctly: personal_prior_vote() self-resolves both rates from Sys.getenv() when the caller passes NULL, exactly so this did not need a seventh call site wired by hand -- the mistake that made the first pooled-arm run VOID earlier the same day.
- **`AUSPOL_DEFECT_SIZE`** (intentional / dead experiment): OFF, REFUSED 2026-10-14 (nt2016 +0.19 on screen). Read inside R/candidate_returns.R (fit_defector_discount() and personal_prior_vote()), so it reaches every harness's base_pred when on; 'NO' in the harness columns is the grep, not a gap. reviews/defector-overcarry-2026-10-14.md
- **`AUSPOL_DEFECTOR_STATE`** (intentional / dead experiment): PREREG PENDING, OFF (built 2026-10-06; docs/reviews/state-defectors-2026-10-06.md). Gate is .defstate_on() in R/defector_state.R, called from R/candidate_returns.R, so it would reach every harness and fit_seats_full.R if turned on; not a gap.
- **`AUSPOL_DEMO_RESID_FULL`** (intentional / dead experiment): ARM (0), UNIVERSAL via R/: read inside R/demographic_residual.R (the demographic correction every harness and fit_seats_full.R reach). plans/prereg-demo-resid-full-2026-10-19.md
- **`AUSPOL_DEMO_RESID_SHUFFLE`** (intentional / dead experiment): Control, not an arm. Permutes which seat gets which seat's demographics within each election, at fit and at apply both, so every marginal and the whole procedure survive and only the seat-to-demographics link dies. Absent from fit_seats_full.R for the same reason its arm is: a control has no business in the published forecast. Calibrated on sa2026 -- 8 draws give mean 0.3576 against a 0.3577 baseline, sd 0.0013, so the null manufactures nothing and the real effect sits 8.9 sds out.
- **`AUSPOL_DEPARTED_FED`** (intentional / dead experiment): REFUSED 2026-09-30 (both '1' and 'gap': qld2020 and sa2026 worse; plans/prereg-departed-fed-gap-2026-09-30.md). Wired into the nsw/qld/sa/vic harnesses and fit_seats_full.R. The fed and wa 'NO' cells are by design: commit 2ff6bf8 says fed and wa have no booth map (the booth-to-federal-district join only exists for state elections with transposed federal swing).
- **`AUSPOL_DEV_SLOPE`** (intentional / dead experiment): UNIVERSAL via R/: read by dev_slopes_for() (R/dev_slope.R), which all seven entry points reach. The old 'yes' cells matched AUSPOL_DEV_SLOPE_MODE and comments.
- **`AUSPOL_EDU_RESID`** (intentional / dead experiment): REFUSED 2026-09-15 and left wired so the result stays reproducible. docs/plans/prereg-education-residual-correction-2026-09-15.md: the criterion passed (pooled seat log loss 0.2702 -> 0.2689 over the AEF-7) and the placebo condition fired, so the answer is no. Superseded by AUSPOL_DEMO_RESID. Default 0 and it should stay 0.
- **`AUSPOL_EDU_RESID_FEATURE`** (intentional / dead experiment): Which census column AUSPOL_EDU_RESID uses. born_aus_pct was pre-registered as the PLACEBO and was not one: r(yr12_pct, born_aus_pct) = -0.706 over 1,989 seats, so both columns read a single class-and-urbanity axis from opposite ends. It recovered 71% of the pooled gain and 100% of it on qld2024, which is what refused the mechanism. The lesson is in AUSPOL_DEMO_RESID_SHUFFLE: with correlated features the control must break the link, not swap the variable.
- **`AUSPOL_EDU_RESID_SHUFFLE`** (intentional / dead experiment): The permutation control retrofitted to the refused single-feature arm, and the instrument that showed its signal was REAL (8.9 sds) even though the arm was refused. Same mechanism as AUSPOL_DEMO_RESID_SHUFFLE; absent from fit_seats_full.R because a control does not belong in the published forecast.
- **`AUSPOL_ERROR_DIST`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-17 on Pete's override (with AUSPOL_COMPOSITION_SD), UNIVERSAL via R/: error_dist_args() (R/error_dist.R) is called at every simulate_seat_contests() site (six harnesses, NT, fit_seats_full.R) and reads the switch inside R/. plans/prereg-error-distribution-2026-10-17.md
- **`AUSPOL_ERROR_DIST_COMP`** (intentional / dead experiment): ARM (0), UNIVERSAL via R/: read by error_dist_file() in R/error_dist.R, which error_dist_args() (every harness and fit_seats_full.R) calls; also read by scripts/fit_error_distribution.R. plans/prereg-error-dist-composition-2026-10-19.md
- **`AUSPOL_FLOW_ASAT`** (**adopted, shared-function wiring**): SHIPPED 2026-09-18 and read inside R/xgb_flow_override.R (.flow_asat_model()), never by a harness directly: the per-election flow model is the as-at file output/xgb-flows-v1-asat-<election>.model when one exists, the all-data model for a future election (vic2026), and skipped only if a LATER election's as-at model exists. Reaches all six harnesses and fit_seats_full.R through that function.
- **`AUSPOL_FLOW_CELL_SD`** (intentional / dead experiment): Read inside R/xgb_flow_override.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_FLOW_FRAG`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): SHIPPED 2026-09-15 and reads NO everywhere by construction: it is a FITTING-TIME switch, not a runtime one. Only scripts/fit_xgb_flows_v1.R reads it, where it decides whether lead_primary (the seat's leading first-preference share) enters feat_cols and so whether the column is baked into output/xgb-flows-v1-final-cols.json. Every harness and fit_seats_full.R then reads that JSON, never the environment, so the feature reaches them through the ARTIFACT. The parity question for this switch is therefore not 'does each harness honour it' but 'was the artifact refit with it', which the cols JSON answers: 40 features, lead_primary present. scripts/fit_xgb_flows_loo.R inherits the same list, so the 25 leave-one-election-out models must be refit in the same breath or a harness loads a 39-feature model against a 40-column matrix. Both were refit 2026-09-15. docs/plans/prereg-flow-fragmentation-2026-09-15.md
- **`AUSPOL_FLOW_MODEL_TAG`** (**adopted, shared-function wiring**): SHIPPED "tf2" 2026-10-12 with AUSPOL_FLOW_TF. Read inside R/xgb_flow_override.R, not per-harness -- universal in practice.
- **`AUSPOL_FLOW_RATE_HL`** (**adopted, shared-function wiring**): SHIPPED "2" 2026-10-12 with AUSPOL_FLOW_TF. Read inside R/xgb_flow_override.R; must equal the tagged models' trained half-life.
- **`AUSPOL_FLOW_SHIFT`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R shifts the statewide TPP fundamentals blend for the live Victorian projection); backtests inject real historical first preferences directly and have no fundamentals blend to shift. NOT federal-specific -- fit_seats_full.R is the Victorian forecast; corrected 2026-09-09, this comment previously said "federal" for every switch fit_seats_full.R alone reads, which is wrong for all six in this group.
- **`AUSPOL_FLOW_TF`** (**adopted, shared-function wiring**): SHIPPED "1" 2026-10-12 (Pete). Read inside R/xgb_flow_override.R (every harness and fit_seats_full.R reach it through the flow override); validated at startup by validate_flow_arm() in published_flags.R.
- **`AUSPOL_FORCE_FP`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- forces a first-preference override for the live Victorian forecast); no analogue in a backtest scored against real historical results.
- **`AUSPOL_FORCE_FP_RULE`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- how the other parties give way under AUSPOL_FORCE_FP); a what-if switch with no analogue in a backtest.
- **`AUSPOL_FORECAST_MODE`** (**OPEN GAP**): OPEN GAP, and the most consequential one in this table. 1 = the statewide the seats swing toward is PREDICTED from polls rather than read off the election being scored. Implemented in backtest_candidate_fed.R and _sa.R ONLY; nsw/qld/vic/wa still use the actual result, so their numbers answer a different question from federal's and are not comparable to a forecast. Default 0 because flipping it today would mean two different things across the six harnesses, NOT because the oracle statewide is endorsed -- Pete's ruling 2026-09-11 is that a forecast must be predictive throughout. Cost where measured: federal +0.0047 pooled seat log loss.
- **`AUSPOL_FP_EXTRA_SD`** (intentional / dead experiment): UNIVERSAL via R/: read by fp_extra_sd_env() in R/forecast_statewide.R, which forecast_statewide_for() (the five state harnesses and nt), backtest_candidate_fed.R and fit_seats_full.R all call. Default 2.419 is the adopted value.
- **`AUSPOL_FP_SD_MODE`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- first-preference spread mode for the live Victorian projection); backtests use realised historical first preferences, not a projected spread.
- **`AUSPOL_FUND_TIME_FORWARD`** (**adopted, shared-function wiring**): SHIPPED as a leak fix (ledger v51, 2026-09-29). Read in R/forecast_statewide.R (reached by every harness and fit_seats_full.R), scripts/backtest_candidate_fed.R and scripts/build_level_pred.R. 'No' in the other harness columns is the grep missing the R/ read.
- **`AUSPOL_HARNESS_SW_DRAWS`** (**adopted, shared-function wiring**): SHIPPED 2026-10-19 as net (Pete override). HARNESS-ONLY by design: the six state harnesses read it via harness_sw_draws() in R/forecast_statewide.R. fit_seats_full.R and the federal harness already pass statewide draws. plans/prereg-harness-sw-draws-2026-10-19.md
- **`AUSPOL_HC_DEFECTOR`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-14, Hare-Clark ONLY: read in scripts/backtest_hare_clark.R (Tasmania, ACT). The six single-member harnesses and Victoria's live forecast are not Hare-Clark, so the gaps are intentional.
- **`AUSPOL_HISTORIC_ELECTED_BACKFILL`** (**adopted, shared-function wiring**): SHIPPED 2026-09-15 on judgement (costs 0.0141 pooled RMSE in the backtest, but vic2026 is never a training pair so the 62 returning members can only move the live forecast, which the backtest cannot see). Read ONCE at build time by scripts/build_candidacies.R and baked into output/candidacies.csv, so no harness reads it at runtime; reversible by rebuilding candidacies with the flag off.
- **`AUSPOL_HTV_EXCLUDE`** (intentional / dead experiment): DIAGNOSTIC 2026-10-13: leaves named transfer files out of the how-to-vote fit (R/htv_flow.R) to attribute a new file's effect; published empty. Read inside R/ via htv_flow_override() -- universal in practice.
- **`AUSPOL_IND_MIXTURE`** (intentional / dead experiment): ARM, REFUSED 2026-10-09 (seat log loss +0.0332 over 22 pairs), off. In all six harnesses; NOT in fit_seats_full.R by design: a refused arm is not wired into the published forecast.
- **`AUSPOL_IND_PERSON`** (**adopted, shared-function wiring**): SHIPPED (final), UNIVERSAL via R/: read by ind_person_mode() (R/ind_person.R); every entry point calls ind_person_apply(). The old 'yes' cells were trailing comments on those calls.
- **`AUSPOL_IND_PERSON_CARRY`** (**adopted, shared-function wiring**): SHIPPED 'linear' 2026-10-10 with AUSPOL_IND_PERSON (Pete's override, plans/prereg-ind-person-2026-10-10.md). Read inside R/ind_person.R, which all six harnesses and fit_seats_full.R call, so the harness grep cannot see it.
- **`AUSPOL_IND_PERSON_DIR`** (**adopted, shared-function wiring**): SHIPPED 'lower' 2026-10-10 with AUSPOL_IND_PERSON. Read inside R/ind_person.R (all six harnesses and fit_seats_full.R).
- **`AUSPOL_IND_SALIENCE`** (intentional / dead experiment): Deprecated experimental arm (the v1 national IND multiplier), superseded by the newer salience mechanisms; fed-only because that is the only harness it was ever tested in. Not adopted.
- **`AUSPOL_IND_TYPICAL`** (intentional / dead experiment): ARM, REFUSED 2026-10-09 (plans/prereg-ind-typical-2026-10-09.md), off. In all six harnesses; NOT in fit_seats_full.R by design: a refused arm is not wired into the published forecast.
- **`AUSPOL_IND_TYPICAL_STAT`** (intentional / dead experiment): Sub-setting of the refused AUSPOL_IND_TYPICAL, read inside R/ind_typical.R; harness-only like its parent.
- **`AUSPOL_INSURGENCY_SHRINK`** (intentional / dead experiment): Per-seat shrink experiment, REFUSED 2026-09-06 (worse than the scalar shrink on 5 of 6 federal pairs) -- see docs/NEXT-STEPS.md. Fed/fit_seats-only because that is as far as the experiment got before being set aside. Not adopted.
- **`AUSPOL_LEADER_SEAT`** (**adopted, shared-function wiring**): SHIPPED (1), UNIVERSAL via R/: read inside leader_seat_apply() (R/leader_seat.R); fit_seats_full.R also reads it directly. The harness 'yes' cells were comments.
- **`AUSPOL_LEADERS_SUPPLEMENT`** (intentional / dead experiment): DIAGNOSTIC 2026-10-13: 0 drops leaders-supplement.csv in read_leaders() (R/leader_seat.R) -- universal in practice; published 1.
- **`AUSPOL_LEVEL_FED_GAP_HL`** (intentional / dead experiment): Same prereg; only read when AUSPOL_LEVEL_FED_R > 0. Read inside R/level_recent.R -- universal in practice.
- **`AUSPOL_LEVEL_FED_R`** (**adopted, shared-function wiring**): SHIPPED 0.15 2026-10-12 (Pete; plans/prereg-federal-breakdowns-in-blend-2026-10-12.md). Read inside R/level_recent.R, which every harness and fit_seats_full.R reach through the level blend -- universal in practice.
- **`AUSPOL_LEVEL_MODE`** (intentional / dead experiment): Read by scripts/fit_xgb_primary_v6.R when the model is FITTED, not by any harness or by fit_seats_full.R at run time -- the choice is baked into the oof file and the saved model, so it shows as absent everywhere while governing every row of both. 'pred' (default) trains on a poll-based statewide projection; 'now' trains on the target election's actual result and is LEAKAGE, kept only so the cost stays measurable. The live path has always used a prediction (R/xgb_primary_override.R fills level_now from state_mean), so this made training match serving.
- **`AUSPOL_LEVEL_RECENT`** (**adopted, shared-function wiring**): SHIPPED 2026-10-11 on Pete's override (plans/prereg-level-recent-blend-2026-10-10.md). Read inside R/level_recent.R, called from forecast_statewide_or_oracle() (five harnesses), the federal harness (BF0r) and fit_seats_full.R (FSLR).
- **`AUSPOL_LEVEL_RECENT_HALFLIFE`** (**adopted, shared-function wiring**): SHIPPED "20" 2026-10-11 with AUSPOL_LEVEL_RECENT=decay (Pete's override). Read inside R/level_recent.R, called from the five state harnesses, the federal harness (BF0r) and fit_seats_full.R (FSLR).
- **`AUSPOL_LEVEL_RECIPE`** (**adopted, shared-function wiring**): SHIPPED 2026-09-30 as v56 ('live'). Wired everywhere:  read in R/forecast_mode.R (statewide_draws_as_at()), which every harness and fit_seats_full.R reach: the five state harnesses and fit_seats_full.R through forecast_statewide_or_oracle() -> forecast_statewide_for() (R/forecast_statewide.R:81), the federal harness directly. "No" cells are the harness grep missing the R/ read, not drift (corrected 2026-10-09 after review).
- **`AUSPOL_LIVE_DEFECT_FIT`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as a train/serve fix, LIVE-ONLY by design: read only in fit_seats_full.R, which now fits the major-defector discount as every harness does (fit_defector_discount) instead of the frozen 0.282.
- **`AUSPOL_LIVE_DRAW_BUCKET`** (**adopted, shared-function wiring**): SHIPPED 2026-09-28 as a parity fix, LIVE-ONLY by design: read only in fit_seats_full.R, where the live statewide draws split the unpolled bucket by its 2022 ratio. The harnesses use candidate_bucket_ratio() (AUSPOL_BUCKET_SPLIT) instead.
- **`AUSPOL_LIVE_LEVEL_ANCHOR`** (intentional / dead experiment): OFF since 2026-09-30 (v56), LIVE-ONLY by design: read only in fit_seats_full.R. The un-anchored level scored better over all 22 elections, and published_flags.R says backtests and live now both use the un-anchored recipe (AUSPOL_LEVEL_RECIPE='live').
- **`AUSPOL_LIVE_LEVEL_SPLIT`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as a train/serve fix, LIVE-ONLY by design: read only in fit_seats_full.R, which serves the xgb layer a level_pred split by bucket_split_ratio(). The harnesses read level_pred from output/level-pred.csv, built by the same function.
- **`AUSPOL_LIVE_SEATPREV_RAW`** (**adopted, shared-function wiring**): SHIPPED 2026-10-19 as a train/serve fix, LIVE-ONLY by design: read only in fit_seats_full.R, which serves the xgb layer seat_prev_pcv from the raw prior-election matrix, as fit_xgb_primary_v6.R trains it.
- **`AUSPOL_MINOR_DEFECT_CONSERVE`** (**adopted, shared-function wiring**): SHIPPED 2026-09-19 (plans/prereg-minor-defector-conserve-2026-09-19.md). Read inside personal_prior_vote() in R/candidate_returns.R: a minor-to-minor defector's origin class keeps a fitted share (~0.38) of the vote. Reaches every harness and fit_seats_full.R through that function, not by a direct harness read.
- **`AUSPOL_MP_SLOPE_FILE`** (intentional / dead experiment): DIAGNOSTIC 2026-10-13: path of the sitting-member slope table; read in all six harnesses (published default output/mp-slope-by-target.csv).
- **`AUSPOL_MP_SLOPE_TF`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-14, FIT-TIME: read by scripts/fit_mp_slope.R, which writes output/mp-slope-by-target.csv (rebuild stage 0); harnesses and live read the table, not the switch.
- **`AUSPOL_NB_TARGET`** (intentional / dead experiment): NOT A MODEL SWITCH: an argument to scripts/build_notional_baselines.R (which federal election year to build notional post-redistribution baselines for). Reads NO everywhere by construction; listed in published_flags.R only as documentation of how to rebuild the notional table.
- **`AUSPOL_NEW_IND_SHRINK`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-06, UNIVERSAL via R/: read by new_ind_mode() (R/new_ind_shrink.R, also ind_mixture.R/ind_typical.R), which all seven entry points reach. The old 'yes' cells were comments.
- **`AUSPOL_NEW_IND_SHRINK_CAP`** (**adopted, shared-function wiring**): SHIPPED (default 1 = cap the new-independent factor at 1); the '0' arm is pending. Read inside R/new_ind_shrink.R, which all six harnesses and fit_seats_full.R call, so the harness grep cannot see it.
- **`AUSPOL_NOM_LIVE`** (**adopted, shared-function wiring**): SHIPPED v61, LIVE-ONLY by design: the published Victorian forecast zeroes non-standing parties only when set to '1' by hand once the VEC final list is loaded (R/nomination_zero.R, fit_seats_full.R). The six harnesses use AUSPOL_NOM_ZERO instead.
- **`AUSPOL_NOM_ZERO`** (**adopted, shared-function wiring**): SHIPPED v61 2026-10-03 (mode 2). All six harnesses read it. fit_seats_full.R does not name it, by design: the published run uses AUSPOL_NOM_LIVE for the same zeroing (R/nomination_zero.R) once the real nomination list exists.
- **`AUSPOL_NOM_ZERO_ORDER`** (**adopted, shared-function wiring**): SHIPPED 2026-10-04 ('late', Pete overriding the R2 refusal). Read in R/nomination_zero.R and named by all six harnesses; per published_flags.R, fit_seats_full.R already zeroes after the last step that can write a share back, so the switch does not apply to it.
- **`AUSPOL_NOTIONAL`** (**adopted, shared-function wiring**): SHIPPED (2) and FEDERAL-BACKTEST-ONLY by design: the redistribution-adjusted (notional) prior only exists where build_notional_baselines.R has a table (federal). State harnesses have no notional table to read, so 'no' there is a data fact, not a parity gap. docs/reviews/notional-prior-redistribution-2026-09-13.md
- **`AUSPOL_NSW_THIN_WALK`** (intentional / dead experiment): NOT A PUBLISHED-CONFIG SWITCH: read by scripts/fit_nsw.R (the NSW poll-trend validation stage), which does not source published_flags.R. The comment block in published_flags.R says why it is deliberately unregistered.
- **`AUSPOL_ONP_CONC_SD`** (**adopted, shared-function wiring**): SHIPPED 2026-09-14 ('auto') for the harnesses that model a One Nation seat concentration from federal booth-transposed votes: qld and sa (where One Nation contests every seat). fed/nsw/vic/wa have no ONP concentration mechanism, and fit_seats_full.R has its own live ONP path; a gap only if One Nation's Victorian seat spread is ever driven from this switch (the VIC2022 IND-coupling regression is the reason it is not: docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md).
- **`AUSPOL_ONP_CV`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R). ADOPTED 2026-09-09 at 0.365, partially pooled (docs/reviews/onp-concentration-validated-2026-09-09.md) -- moves the live Victorian One Nation median seat count 9 -> 10. The highest-stakes switch this registry tracks; was previously mislabelled "federal" here, which is wrong -- fit_seats_full.R is the Victorian forecast, not a federal one.
- **`AUSPOL_ONP_FIX`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- One Nation allocation fix for the live Victorian projection).
- **`AUSPOL_ONP_ORDER`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- One Nation allocation ordering for the live Victorian projection).
- **`AUSPOL_OTHERS_SCALE`** (intentional / dead experiment): ARM, REFUSED 2026-09-28 (plans/prereg-others-bucket-size-2026-09-27.md). Backtest path only (R/forecast_mode.R, R/others_bucket.R); published_flags.R says the live script is deliberately not wired because it did not pass.
- **`AUSPOL_PARTY_COR`** (intentional / dead experiment): WA deliberately excluded from the statewide party-correlation matrix -- cor(ALP, IND) flips sign there (docs/reviews/statewide-cov-loo-2026-09-07.md). Intentional, not a gap.
- **`AUSPOL_PB_COALITION_COMBINED`** (intentional / dead experiment): OFF (0), UNIVERSAL via R/: read inside R/poll_source.R's WA Poll Bludger merge; off is today's behaviour exactly. Only WA polls carry combined-only Coalition rows.
- **`AUSPOL_POLL_ARCHIVE`** (intentional / dead experiment): 2026-10-14 (not shipped): pollster-archive polls (Morgan, Newspoll; fed 2004-2007) join the layered source. Read inside poll_layer() (R/poll_source.R) via load_polls() -- universal in practice.
- **`AUSPOL_POLL_BT`** (intentional / dead experiment): 2026-10-13 (Pete: go): BludgerTrack poll tables join the layered source. Read inside poll_layer() (R/poll_source.R) via load_polls() -- universal in practice.
- **`AUSPOL_POLL_PB`** (intentional / dead experiment): 2026-10-13 (Pete: go): Poll Bludger posts (model-read, stated figures) replace AE's numbers where they agree. Read inside poll_layer() (R/poll_source.R) via load_polls() -- universal in practice.
- **`AUSPOL_POLL_SOURCE`** (**adopted, shared-function wiring**): SHIPPED layered 2026-10-13 (Pete; plans/prereg-own-poll-source-step2-2026-10-12.md). Read inside load_polls() (R/load_polls.R), which every harness and fit_seats_full.R call -- universal in practice.
- **`AUSPOL_POOL_BY_JURISDICTION`** (intentional / dead experiment): BUILT 2026-10-13, OFF, not measured across all pairs (docs/reviews/pooled-fits-inventory-2026-10-13.md). Gate is pool_by_jurisdiction_on() in R/pool_hierarchical.R, called from fit_defector_discount(), fit_minor_defector_discount() and fit_sitting_minor_level() in R/candidate_returns.R, so it reaches every harness and fit_seats_full.R; not a gap.
- **`AUSPOL_PUBLISH_NSW2027`** (intentional / dead experiment): PUBLISH-TIME (1): read by scripts/promote_rebuild.R to ship the nsw2027 tables, matching the repository variable the daily job gates on. Not a model switch, so no harness reads it.
- **`AUSPOL_QLD_CUTOFF`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_QLD_FLOWS`** (intentional / dead experiment): Self-referential no-op in the QLD harness itself ("use Queensland's own flows" is trivially true there) -- disclosed via its own `.inert` list. Genuinely absent from WA (uses AUSPOL_WA_FLOWS instead).
- **`AUSPOL_REENTRY`** (**adopted, shared-function wiring**): SHIPPED (majors) 2026-10-06, UNIVERSAL via R/: read by reentry_mode() (R/reentry_prior.R), which all seven entry points reach. fit_seats_full.R names it only inside a printed message; the harness 'yes' cells matched AUSPOL_REENTRY_* switches.
- **`AUSPOL_REENTRY_GAP`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_REENTRY_LINK`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_REENTRY_SPLIT`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_REENTRY_WINSOR`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_SA_CUTOFF`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_SA_FLOWS`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_SALIENCE_BLEND`** (intentional / dead experiment): Read inside R/salience_surge.R's blend_salience_shares(), not per-harness -- universal in practice, and gated there deliberately so all five harnesses and the published forecast get the switch from one change. Exists to make a suspected DOUBLE COUNT measurable: the same hazard drives both a shift of the point estimate and an additive jump in the draw. Measured 2026-09-11 -- the double count is real (surge_h is the per-seat max of p_hat, correlation 0.984) and turning the blend OFF makes things WORSE, because the under-prediction of emergences is larger than the over-counting. Stays at 1 until the per-cell variance is fixed.
- **`AUSPOL_SALIENCE_BLEND_ONCE`** (intentional / dead experiment): ARM (0), UNIVERSAL via R/: read by salience_blend_once() in R/salience_surge.R, through blend_salience_post_xgb() in the fed/nsw/qld/sa/vic harnesses and directly in fit_seats_full.R. WA and NT have no salience blend. plans/prereg-salience-blend-once-2026-10-19.md
- **`AUSPOL_SALIENCE_EXP_SD`** (**OPEN GAP**): WA: same salience-corpus exclusion as AUSPOL_SALIENCE_EXPECTED, intentional. fit_seats_full.R: OPEN GAP, not fixed -- registered as published but sd_override is never wired into the forecast script at all (docs/reviews/pre-main-review-gate-2026-09-08.md). Currently harmless: this whole salience-variance arm is still pre-registered and undecided (docs/plans/prereg-salience-expected-and-variance-2026-09-07.md), so the switch is off everywhere. Wire it in the same commit that ships the arm, not before.
- **`AUSPOL_SALIENCE_EXPECTED`** (intentional / dead experiment): WA has no candidate-level salience corpus at all (the WA commission files carry surnames only, no salience-v6.csv rows) -- documented, intentional exclusion.
- **`AUSPOL_SALIENCE_PCTILE_NZ`** (**adopted, shared-function wiring**): SHIPPED 2026-09-12 (b7b5839): R/salience_surge.R ranks the salience percentile among NON-ZERO values only (docs/reviews/salience-percentile-fix-2026-09-12.md). Read in R/, reaches every caller of the surge model.
- **`AUSPOL_SALIENCE_SMOOTH`** (intentional / dead experiment): Read inside R/salience_surge.R, not per-harness -- universal in practice.
- **`AUSPOL_SALIENCE_SURGE_V2`** (**OPEN GAP**): WA: OPEN GAP, not fixed. Marked `yes*` above because the switch's name appears only in a disclosure comment explaining that it is NOT wired -- WA has no surge-v2 hazard at all where every other harness does (docs/NEXT-STEPS.md's own "Open" item 3, still unaddressed). A plain grep of the file would otherwise call this cell a clean "yes" and hide the gap.
- **`AUSPOL_SD_DEPARTED`** (intentional / dead experiment): UNDER TEST, default 0, not adopted: widens the per-cell sd for major-party cells whose previous winner is off the ballot. Read inside R/xgb_primary_sd_override.R, reached by the fed and nsw harnesses that call it; the other four never call the sd override at all (see AUSPOL_XGB_PRIMARY_SD). plans/prereg-departed-member-width-2026-09-16.md
- **`AUSPOL_SEAT_CONTEXT_FILL`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED 2026-09-28 as v46: fills incumbent party / retiring member from output/seat-context.csv when the xgb training table is built (scripts/fit_xgb_primary_v6.R); baked into the trained model, no harness or live read.
- **`AUSPOL_SEAT_CONTEXT_MARGIN`** (intentional / dead experiment): ARM, not shipped (default 0; phase 2 of plans/prereg-seat-context-complete-2026-09-28.md). Read in scripts/fit_xgb_primary_v6.R (training) and R/xgb_primary_override.R (the 'all' mode, live). Off, so nothing differs by entry point.
- **`AUSPOL_SEAT_CONTEXT_SOPH`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME ARM (0): fills the first-term-member flag (soph_cand) from output/seat-context.csv where the seat file has none, in scripts/fit_xgb_primary_v6.R; baked into the trained model. Live reads the vic2026 seat file, which has the flag. plans/prereg-first-term-fill-2026-10-20.md
- **`AUSPOL_SEAT_POLL_ALLPOLLS`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md amendment 2
- **`AUSPOL_SEAT_POLL_BLEND`** (**adopted, shared-function wiring**): SHIPPED (1), UNIVERSAL via R/: read inside seat_poll_blend_apply() (R/seat_poll_blend.R); fit_seats_full.R also reads it directly. The harness 'yes' cells were comments.
- **`AUSPOL_SEAT_POLL_COALITION_DEDUP`** (**adopted, shared-function wiring**): SHIPPED 2026-10-07 (data fix). Read in .read_seat_polls_file() in R/seat_poll_blend.R, which all six harnesses and fit_seats_full.R reach through the seat-poll blend; the weight fit and the blend see the same polls.
- **`AUSPOL_SEAT_POLL_CORRECTIONS`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 (data fix), UNIVERSAL via R/: read inside R/seat_poll_blend.R's seat-poll reader, which every harness and fit_seats_full.R reach.
- **`AUSPOL_SEAT_POLL_DECAY`** (**adopted, shared-function wiring**): SHIPPED 2026-10-09 (full 20k run with PRIOR and MRP_NAME: 0.2705 -> 0.2675 on the 6 polled elections). Read in seat_poll_shares() in R/seat_poll_blend.R (.seat_poll_decay_on()), which every entry point reaches through the blend; the harness grep cannot see it.
- **`AUSPOL_SEAT_POLL_ELECTION_ERR`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md amendment 8
- **`AUSPOL_SEAT_POLL_FIRM_FLOOR`** (intentional / dead experiment): ARM, off: did not clear 2026-10-09 (moves 1 cell alone). Read in .seat_poll_cell_weights() and seat_poll_decay_params() in R/seat_poll_blend.R; reaches every entry point through the blend.
- **`AUSPOL_SEAT_POLL_FIRM_SHARED`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md amendment 7
- **`AUSPOL_SEAT_POLL_GROUPS`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside seat_poll_shares() and seat_poll_decay_params() (R/seat_poll_blend.R), which every harness and fit_seats_full.R reach through the seat-poll blend. plans/prereg-seat-poll-method-weights-2026-10-18.md
- **`AUSPOL_SEAT_POLL_HANDKEYED`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override). Read in .read_seat_polls_file() in R/seat_poll_blend.R; reaches every entry point through the blend.
- **`AUSPOL_SEAT_POLL_HEAVY_TAIL`** (intentional / dead experiment): ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-heavy-tail-2026-10-18.md
- **`AUSPOL_SEAT_POLL_IND_DIRECT`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md amendment 6
- **`AUSPOL_SEAT_POLL_IND_MAP`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override). Read in seat_poll_shares() in R/seat_poll_blend.R; reaches every entry point through the blend.
- **`AUSPOL_SEAT_POLL_IND_WEIGHT`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override). Read in R/seat_poll_blend.R (.ind_weight_on(), seat_poll_blend_apply()); reaches every entry point through the blend. It errors if combined with AUSPOL_SEAT_POLL_MATCH=perpoll.
- **`AUSPOL_SEAT_POLL_MATCH`** (intentional / dead experiment): TESTING, default 'class' (plans/prereg-seat-poll-per-poll-match-2026-09-29.md). Read in R/seat_poll_blend.R; 'perpoll' is built for blend mode 1 only and backtests only until shipped, so no live wiring is expected.
- **`AUSPOL_SEAT_POLL_MODELVAR_ALL`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md
- **`AUSPOL_SEAT_POLL_MRP_NAME`** (**adopted, shared-function wiring**): SHIPPED 2026-10-09 with DECAY and PRIOR (data fix: an MRP release under 20 seats named MRP). Read in seat_poll_shares() in R/seat_poll_blend.R; reaches every entry point through the blend.
- **`AUSPOL_SEAT_POLL_NAMED_ONLY`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md
- **`AUSPOL_SEAT_POLL_PRECISION_BLEND`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM, off: did not clear 2026-10-09 (+0.0000, SE 0.0037). Read in seat_poll_blend_apply() and seat_poll_blend_table() in R/seat_poll_blend.R; needs AUSPOL_SEAT_POLL_DECAY=1.
- **`AUSPOL_SEAT_POLL_PRIOR`** (**adopted, shared-function wiring**): SHIPPED 2026-10-09 at 0.75 (Pete's prior, same full run). Read in seat_poll_weight() via .seat_poll_prior() in R/seat_poll_blend.R, which every entry point reaches through the blend.
- **`AUSPOL_SEAT_POLL_PRIOR_SD`** (**adopted, shared-function wiring**): SHIPPED 2026-10-09 at 0.25, the prior's sd; read with AUSPOL_SEAT_POLL_PRIOR in .seat_poll_prior().
- **`AUSPOL_SEAT_POLL_SALIENCE_VAR`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md
- **`AUSPOL_SEAT_POLL_SIZEVAR`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md amendment 2
- **`AUSPOL_SEAT_POLL_SOURCES`** (intentional / dead experiment): TESTING, default 'all' (plans/prereg-seat-poll-public-only-2026-09-29.md). Read in seat_poll_shares() in R/seat_poll_blend.R, which every entry point reaches; the harness grep cannot see it.
- **`AUSPOL_SEAT_POLL_SPLIT_ALL`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as arm H (deciding-runs/20261018-2009-seatpoll-H). ARM (0), UNIVERSAL via R/: read inside R/seat_poll_blend.R (the seat-poll blend every harness and fit_seats_full.R reach). plans/prereg-seat-poll-method-weights-2026-10-18.md amendment 2
- **`AUSPOL_SEAT_POLL_TPP_SOURCE`** (intentional / dead experiment): TESTING, default 'all' (plans/prereg-seat-poll-tpp-direct-2026-09-30.md). Read in R/seat_poll_joint.R, which implements blend mode 3 (joint primary and two-party weights); it only matters under that mode.
- **`AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER`** (**adopted, shared-function wiring**): SHIPPED 2026-10-07 (bug fix: a weight fitted on one cluster gets SE Inf, not ~0). 'legacy' restores the old factor for screening only. Read at R/seat_poll_blend.R line ~393 inside all three weight fits, so every entry point gets it.
- **`AUSPOL_SEAT_SPREAD_SRC`** (**adopted, shared-function wiring**): SHIPPED (derived), UNIVERSAL via R/: read inside R/prev_seat_swing.R, which the harnesses call for seat_sd; harness-only by its own comment (live seat_sd comes from the fitted spread).
- **`AUSPOL_SEAT_SWING_PORT`** (**adopted, shared-function wiring**): SHIPPED (2), UNIVERSAL via R/: read inside seat_swing_port_apply() (R/seat_swing_port.R), which WA reaches too; WA's own scoping switch is AUSPOL_SEAT_SWING_PORT_WA, whose name made the old WA cell 'yes'.
- **`AUSPOL_SEAT_SWING_PORT_NOCLIFF`** (intentional / dead experiment): PREREG PENDING, default 0 (built 2026-10-05). Read inside R/seat_swing_port.R, which the nsw/qld/sa/vic/wa harnesses and fit_seats_full.R all call; only the wa harness also names it (an output-filename tag), and scripts/dry_run_seat_swing_port_wa.R sets it. So the matrix's wa-only 'yes' is a naming artefact, not wiring.
- **`AUSPOL_SEAT_SWING_PORT_WA`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override; mode 2). WA-ONLY by design (Pete: 'why is WA special?'; wa2025 -0.0064 log loss, nothing else moves): read in R/seat_swing_port.R and the wa harness only. Mode 2 pools WA cycles for WA targets alone, so the other harnesses and the live Victoria run are intentionally untouched.
- **`AUSPOL_SHIP_TIME_FORWARD`** (**adopted, shared-function wiring**): SHIPPED as a leak fix (ledger v51, 2026-09-29). Read in R/split_slope.R, which the six harnesses use for the minor-slope tiers; fit_seats_full.R does not name split_slope (function-name grep), so the published path is not shown to read it. Not traced further.
- **`AUSPOL_SIM_ENGINE`** (intentional / dead experiment): Read inside R/seat_sim.R's simulate_seat_contests(), not per-harness -- universal in practice.
- **`AUSPOL_SITTING_MEMBER_ADJ`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-sitting-member-baseline-2026-09-28.md). Read in R/xgb_primary_override.R and scripts/fit_xgb_primary_v6.R, i.e. at xgb training and in the override, not in a harness.
- **`AUSPOL_SIZE_SD`** (**adopted, shared-function wiring**): SHIPPED 2026-10-14 (1), wired EVERYWHERE through R/size_sd.R: all seven harnesses and fit_seats_full.R pass sd_override = size_sd_apply(...) to simulate_seat_contests(), which reads the switch inside R/. The 'NO' cells are this generator only grepping the harness files. reviews/seat-size-spread-2026-10-14.md
- **`AUSPOL_SLOPE_SHRINK`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-slope-shrinkage-2026-09-28.md). Read through .slope_shrink_on() in R/split_slope.R, which the six harnesses call; if adopted it needs a published-forecast check since fit_seats_full.R does not name split_slope.
- **`AUSPOL_SPLIT_SLOPE`** (intentional / dead experiment): REFUSED 2026-09-09, and harmfully so (docs/plans/ prereg-partial-return-split-slope-2026-09-09.md): it discarded the existing conditional-slope system instead of refining it. Harness-only by design, same reasoning as AUSPOL_FIT_SLOPES.
- **`AUSPOL_STATE_DEV`** (**adopted, shared-function wiring**): ADOPTED 2026-09-15 and FEDERAL ONLY, which is a design fact rather than the all-harnesses rule outstanding: a state election has no deviation from a national swing to correct, so the other five harnesses have nothing to honour. Corrects a federal seat's primaries for how its STATE moves against the national swing -- WA 2022 swung to Labor far harder than the country (mean ALP per-seat primary error +6.43 over 15 seats, positive in 14). Federal pooled seat log loss 0.2584 -> 0.2539 over 1,052 seat-elections, 0 of 10 permutation-control draws beating it. fit_seats_full.R reads NO for the same reason the state harnesses do; the published Victorian forecast is unaffected. docs/plans/prereg-state-deviation-2026-09-15.md
- **`AUSPOL_STATE_DEV_SHUFFLE`** (intentional / dead experiment): Control for the above, not an arm: permutes which state each seat sits in, within its election, at fit and apply both. Absent from fit_seats_full.R because a control has no business in the published forecast. Calibrated -- the null lands on the baseline to within 0.0001 pooled.
- **`AUSPOL_STATE_NOTIONAL`** (**adopted, shared-function wiring**): SHIPPED v57 and STATE-BACKTEST-ONLY by design: the state notional prior replaces the prior only on state pairs preceded by a redistribution (STATE_REDISTRIBUTIONS, R/state_notional.R). The federal harness has its own (AUSPOL_NOTIONAL), and the published Victoria forecast needs none: 2026 is fought on the 2022 boundaries. plans/prereg-state-notional-2026-10-01.md
- **`AUSPOL_STATE_POLL_EXTRA`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, TESTING (default 0; plans/prereg-state-polls-extra-2026-10-02.md). Read only in scripts/build_state_deviation_features.R, which builds the state-deviation features the xgb model trains on.
- **`AUSPOL_STATE_POLL_POOL`** (**adopted, shared-function wiring**): SHIPPED v60 2026-10-02 (Pete overrode the prereg clause). FEDERAL-HARNESS-ONLY by design: pools a state signal from seat polls before the seat-poll blend (R/state_poll_pool.R); published_flags.R states 'federal harness only'. Only backtest_candidate_fed.R calls it.
- **`AUSPOL_SURGE_FROM_ZERO`** (intentional / dead experiment): WA has no candidate-level salience corpus -- same exclusion as AUSPOL_SALIENCE_EXPECTED, intentional.
- **`AUSPOL_SURGE_H_TF`** (**adopted, shared-function wiring**): SHIPPED 2026-10-18 as a leak fix, TRAINING-ONLY by design: read in scripts/fit_xgb_primary_v6.R, which builds the xgb training features (stage 3). Harnesses and fit_seats_full.R were already time-forward.
- **`AUSPOL_SURGE_RECIPIENT`** (**OPEN GAP**): OPEN GAP in WA, part of the AUSPOL_SALIENCE_SURGE_V2 gap below: WA has no surge-v2 hazard, so it has no recipient step to switch. Read directly in fit_seats_full.R and the other five harnesses; no R/ function reads it. The old WA 'yes' was a comment.
- **`AUSPOL_SURGE_SCALE`** (**OPEN GAP**): OPEN GAP in WA, part of the AUSPOL_SALIENCE_SURGE_V2 gap below: no surge-v2 hazard in WA, so nothing to scale. Read directly in fit_seats_full.R and the other five harnesses; no R/ function reads it. The old WA 'yes' was a comment.
- **`AUSPOL_SURGE_SOURCE`** (intentional / dead experiment): UNIVERSAL via R/: read inside surging_parties() (R/party_surge.R), which every harness reaches through salience_permit_for() and fit_xgb_primary_v4/v6.R reach directly, so the per-harness greps cannot see it. Published "actual" LEAKS and is being replaced (plans/prereg-surge-flag-time-forward-2026-10-15.md); fit_seats_full.R already behaves as "none" because vic2026 has no votes.
- **`AUSPOL_SW_NET_LIVE`** (**adopted, shared-function wiring**): SHIPPED 2026-10-19 (Pete override). PUBLISHED-ONLY by design: the live counterpart of AUSPOL_HARNESS_SW_DRAWS=net, read in fit_seats_full.R; the harnesses are measured with the harness switch. plans/prereg-harness-sw-draws-2026-10-19.md amendment 1
- **`AUSPOL_THIN_CYCLE`** (intentional / dead experiment): CONFIRMED (1) 2026-10-14, UNIVERSAL via R/: read inside R/forecast_statewide.R and R/hare_clark.R (thin_cycle_statewide() for cycles the trend cannot fit).
- **`AUSPOL_TIME_FORWARD_FITS`** (**adopted, shared-function wiring**): SHIPPED as a leak fix (2026-09-28): every constant fitted inside base_pred learns only from earlier elections. Read in R/time_forward.R and R/fundamentals_tf.R (also part of cache keys), below the harness grep; reaches every entry point.
- **`AUSPOL_TRAIN_COMPLETENESS`** (intentional / dead experiment): ARM (0), FIT-TIME: read by fit_xgb_primary_asat.R and fit_xgb_primary_v6_final.R (rebuild stages 4-5); harnesses and live load the trained models. plans/prereg-training-weights-2026-10-13.md
- **`AUSPOL_TRAIN_DECAY_H`** (**adopted, shared-function wiring**): SHIPPED (8) 2026-10-13, FIT-TIME: read by fit_xgb_primary_asat.R and fit_xgb_primary_v6_final.R (rebuild stages 4-5); harnesses and live load the trained models. plans/prereg-training-weights-2026-10-13.md
- **`AUSPOL_TRAIN_DEMEAN`** (**adopted, shared-function wiring**): SHIPPED (1) 2026-10-13, FIT-TIME: read by fit_xgb_primary_asat.R and fit_xgb_primary_v6_final.R (rebuild stages 4-5); harnesses and live load the trained models. plans/prereg-training-weights-2026-10-13.md
- **`AUSPOL_TRAIN_SKIP_PAIRS`** (intentional / dead experiment): 2026-10-13 (Pete): pairs scored but kept out of the vote-share models' training rows; read by fit_xgb_primary_asat.R and fit_xgb_primary_v6_final.R (rebuild stages 4 and 5), not by the harnesses or fit_seats_full.R directly. Published vic2010.
- **`AUSPOL_TREND_RW_MULT`** (intentional / dead experiment): REFUSED ARM 2026-10-12, same prereg, off at "1". Read inside R/forecast_mode.R -- universal in practice.
- **`AUSPOL_TREND_SIGMAS`** (intentional / dead experiment): REFUSED ARM 2026-10-12 (plans/prereg-responsive-trend-2026-10-12.md), off at "default". Read inside R/forecast_mode.R (the statewide forecast every harness and fit_seats_full.R call), not per-harness -- universal in practice.
- **`AUSPOL_TREND_SZC`** (intentional / dead experiment): REFUSED ARM 2026-10-12, same prereg (T3), off at "polls". Read inside R/trend.R, so it reaches every trend fit -- universal in practice.
- **`AUSPOL_UPSET_FLOOR`** (intentional / dead experiment): REFUSED 2026-10-02 (Brier guard: 0.0894 -> 0.0904 against a 0.0005 limit; plans/prereg-upset-floor-2026-10-02.md,  DECISIONS.md 2026-10-02), default 0, code kept. Not a per-harness switch by design: it is stage 6b, applied by  scripts/rebuild_forecasts.sh (scripts/apply_upset_floor.R) to the pooled harness output, and read live by  fit_seats_full.R and scripts/promote_rebuild.R; so no harness reads it.
- **`AUSPOL_WA_CUTOFF`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_WA_DROP_3C`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_WA_DROP_LNP`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_WA_FLOWS`** (intentional / dead experiment): Self-referential no-op in the WA harness itself, same shape as AUSPOL_QLD_FLOWS above but not disclosed via an `.inert` list there. Genuinely absent from QLD (uses AUSPOL_QLD_FLOWS instead).
- **`AUSPOL_XGB_BASE_DELTA`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 with AUSPOL_REENTRY='majors'. HARNESS-ONLY by design: read inside xgb_primary_override() (R/xgb_primary_override.R, R/xgb_base_delta.R); the live forecast gets the same effect through base_margin (xgb_primary_predict_live()).
- **`AUSPOL_XGB_BASE_DELTA_TOL`** (**adopted, shared-function wiring**): SHIPPED companion of AUSPOL_XGB_BASE_DELTA (tolerance in percentage points); read only in R/xgb_base_delta.R, so inert unless that switch is '1'. Harness-only for the same reason.
- **`AUSPOL_XGB_BASE_MARGIN`** (intentional / dead experiment): Training-time switch for the XGBoost primary models (fit_xgb_primary_v6.R, _v6_final.R, _asat.R), not a harness or forecast switch -- which is why no harness row reads it. 2 (shipped 2026-09-17) = base_pred set as the training DMatrix's base_margin AND kept as a feature, so every tree boosts on the residual to the shipped model's own prediction; 1 = offset only; 0 = plain feature. xgb_primary_predict_live() must set the same base_margin at predict time, and does. Classified 2026-09-18; it had sat UNEXPLAINED in this table since it shipped.
- **`AUSPOL_XGB_BASE_RECORD`** (intentional / dead experiment): Measurement plumbing, not a model change (default 0): scripts/rebuild_forecasts.sh sets it for stage 1 so the disabled override writes the reference shares AUSPOL_XGB_BASE_DELTA compares against. Read in R/xgb_primary_override.R only.
- **`AUSPOL_XGB_BOOTH`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, TESTING (default 0; plans/prereg-booth-features-2026-10-02.md). Booth spread / early-vote gap xgb features; read in scripts/fit_xgb_primary_v6.R and scripts/promote_rebuild.R, baked into the trained model.
- **`AUSPOL_XGB_CONTEST`** (intentional / dead experiment): ARM (0), FIT-TIME + LIVE: read by fit_xgb_primary_v6.R (training features stands_i, level_contested; the as-at and final models inherit them) and R/xgb_primary_override.R (live, from the confirmed nomination list). Harnesses read the as-at predictions file. plans/prereg-contest-features-2026-10-20.md
- **`AUSPOL_XGB_COUNCIL`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED v58 2026-10-02: council-history xgb features, read in scripts/fit_xgb_primary_v6.R and scripts/promote_rebuild.R; baked into the trained model artifact, so no harness reads it.
- **`AUSPOL_XGB_DEPARTED_SIDE`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, ARM (default 0; plans/prereg-departed-member-sides-2026-09-28.md). Adds own_departed_i / opp_departed_i xgb features via add_departed_side() (R/departed_side.R), called from fit_xgb_primary_v6.R and _v6_final.R; baked into the trained model.
- **`AUSPOL_XGB_ENDORSE`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED v59 2026-10-02: Climate 200 / Voices endorsement xgb features, read in scripts/fit_xgb_primary_v6.R and scripts/promote_rebuild.R; baked into the trained model.
- **`AUSPOL_XGB_ENSEMBLE`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED v58 2026-10-02: K=3 seed-varied xgb fits averaged. Read in fit_xgb_primary_asat.R and fit_xgb_primary_v6_final.R (training only), so no harness or live read exists.
- **`AUSPOL_XGB_PRIMARY`** (intentional / dead experiment): Harness-only BY DESIGN, and the split is the point: a backtest must predict a pair with a model that never saw it, so the harnesses read the POINT-IN-TIME predictions (output/xgb-primary-asat-predictions.csv, scripts/fit_xgb_primary_asat.R: one model per election, trained only on elections whose polling day precedes it, since 2026-09-18; leave-one-pair-out before that) while the published forecast reads the all-data model via AUSPOL_XGB_PRIMARY_LIVE. Same recipe, same base_margin mode, different cutoff date -- that is the whole difference, by design. Absent from fit_seats_full.R deliberately -- a predictions file has no row for an election that has not happened.
- **`AUSPOL_XGB_PRIMARY_LIVE`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R), the live counterpart of AUSPOL_XGB_PRIMARY above. Loads output/xgb-primary-v6-final.model, trained on all 22 historical pairs -- correct here and leakage in a backtest, which is exactly why the two switches exist separately.
- **`AUSPOL_XGB_PRIMARY_OOF`** (intentional / dead experiment): Harness-only escape hatch naming which out-of-fold file AUSPOL_XGB_PRIMARY reads; empty means the v6 default. Exists because the unversioned filename is v1's, and until 2026-09-11 the backtest arm measured v1 while the live forecast shipped v6 -- the two were never describing the same model. Not a modelling switch; no published-forecast analogue.
- **`AUSPOL_XGB_PRIMARY_SD`** (intentional / dead experiment): OFF (0). The xgb spread model's per-cell sd, read in R/xgb_primary_sd_override.R and wired into fed and nsw only. With the switch off nothing reaches any output, so the four unwired harnesses are not a live parity gap; if it is ever adopted the wiring must be ported to all six in the same commit (CLAUDE.md rule).
- **`AUSPOL_XGB_PRIMARY_SD_CLASSES`** (intentional / dead experiment): Companion of AUSPOL_XGB_PRIMARY_SD (which classes it widens); read only inside R/xgb_primary_sd_override.R, so inert wherever that switch is off. Same wiring status as its parent.
- **`AUSPOL_XGB_PRIMARY_SD_SRC`** (intentional / dead experiment): Companion of AUSPOL_XGB_PRIMARY_SD (the OOF file it reads); read only inside R/xgb_primary_sd_override.R. Same wiring status as its parent.
- **`AUSPOL_XGB_RATIO_FEATS`** (intentional / dead experiment): ARM (0), FIT-TIME + LIVE: read by fit_xgb_primary_v6.R (training features; the as-at and final models inherit them) and R/xgb_primary_override.R (live). Harnesses read the as-at predictions file. plans/prereg-growth-ratio-features-2026-10-18.md
- **`AUSPOL_XGB_SEATPREV_NAFILL`** (**adopted, shared-function wiring**): SHIPPED 2026-09-13/18: seat_outperf and seat_prev_pcv NA cells are filled with 0 at feature-build time (scripts/fit_xgb_primary_v6.R), so the switch is baked into the trained model artifact; no harness reads it.
- **`AUSPOL_XGB_SEED`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME: the xgb training seed (fit_xgb_primary_*, fit_xgb_flows_asat.R). Varied only to measure how much an equally valid refit moves the metrics (plans/noise-floor-2026-10-02.md); no harness or live read.
- **`AUSPOL_XGB_SENATE`** (intentional / dead experiment): OFF, REFUSED 2026-10-01 (three arms: all parties, minor only, geography only) -- each cost Victorian Labor or lost the gains. Read only in fit_xgb_primary_v6.R and xgb_primary_override.R, so 'no' in the harness columns is by design. plans/prereg-xgb-senate-2026-10-01.md
- **`AUSPOL_XGB_SURGE`** (intentional / dead experiment): Harness-only and wired into backtest_candidate_sa.R ALONE, which is this file's own 'a fix to one harness is a fix to all of them' rule outstanding rather than satisfied. Built, measured, NOT shipped: the hazard is much better than the salience one it would replace (out-of-fold AUC 0.936 against 0.751) but it failed its pre-registered bar and a calibration check says it is now over-dispersed. Its live path is an unimplemented stub, so fit_seats_full.R cannot honour it even if asked. docs/plans/prereg-xgb-surge-parameters-2026-09-11.md
- **`AUSPOL_XGB_SURGE_SRC`** (intentional / dead experiment): Companion of AUSPOL_XGB_SURGE (which emergence model file to read: v5 candidate-level); read only inside R/xgb_surge_override.R, so it reaches exactly the harnesses that honour AUSPOL_XGB_SURGE.
- **`AUSPOL_ZERO_ABSENT`** (intentional / dead experiment): ARM (0), UNIVERSAL via R/: the default of simulate_seat_contests(zero_absent = zero_absent_on()), so every harness, NT and fit_seats_full.R honour it with no call-site argument. plans/prereg-zero-absent-2026-10-17.md

## Gaps the switch-presence matrix cannot see

A grep for a switch's name proves the name is mentioned, not that the
VALUE it's set to is fully honoured. Hand-maintained because there is no
mechanical test for "is this harness doing the whole thing the switch
asks for":

- **`AUSPOL_DEV_SLOPE_MODE=screened` was only half-honoured in WA and NT**
  until 2026-10-15: conditional slopes only, no `salience_permit_for()`/
  `screened_slopes()`. Now wired as in Victoria (`BW1s`/`BNT1s` print the
  path taken). One difference kept: WA/NT zero IND before the hold-aware
  renormalisation, so a hold survives IND zeroing there; Victoria's plain
  renormalisation after zeroing undoes it.

## Fixed this session (2026-09-08/09), for history

- WA's `SEED` was a hardcoded literal (`20260825L`), ignoring
  `AUSPOL_SEED` entirely -- every WA run before 2026-09-09 used one fixed
  seed regardless of the env var. Fixed; WA's *default* seed (20260825)
  still differs from the other five harnesses' (42), unchanged on
  purpose so nothing already published moved silently.
- `AUSPOL_SEAT_SD_MULT`, `AUSPOL_FALLBACK_SMOOTH` and `AUSPOL_FLOW_SD`
  were registered in `published_flags.R` and honoured by all six
  backtest harnesses, but never wired into `fit_seats_full.R` at all.
  Fixed 2026-09-09; harmless while shipped at their no-op defaults.

## Switches a harness FORCES away from its published value

Honouring a switch and running at its published value are different questions, and this table asked only the first until 2026-09-14. A harness that reads a switch and then `Sys.setenv()`s it scores a clean "yes" above while measuring a configuration the forecast does not ship. Detected mechanically below, so it cannot go stale.

**MR3! 1 harness/switch pair(s) run at a non-published value.** Any figure that pools these harnesses with the others compares two configurations.

| switch | harness | forced to | published |
|---|---|---|---|
| `AUSPOL_BUCKET_SPLIT` | `fit_seats (published)` | **prior** | cand_naive |

A forced value is not automatically a bug, but it must be recorded in `published_flags.R` and weighed whenever figures from these harnesses are pooled. (History: until 2026-10-03 `fed` and `nsw` forced `AUSPOL_SALIENCE_EXPECTED` and `AUSPOL_SALIENCE_EXP_SD` to 1 on purpose, commit `01c8e1c`; that was removed, see `docs/reviews/fed-nsw-snapshot-gap-2026-10-03.md`.)

## Coverage check

MR2  every non-universal switch (205 of 234) has a recorded classification.
