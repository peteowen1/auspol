# AUSPOL_* environment switches that are read in code but are deliberately NOT in published_flags.R, because
# they do not change a forecast or backtest number at the value the pipeline runs (Pete, 2026-10-29).
#   RUN     which election or pair, paths, caches, suffixes, publish plumbing, run sizes
#   DIAG    read only by a diagnostic or analysis script, or only prints or dumps detail
#   BUILDER read only by a by-hand builder or fetcher whose output files the pipeline reads
#   RETIRED read only by a script the pipeline no longer runs, kept because diagnostics read its old output
# mr4_scan() below finds every AUSPOL_* name read in R/ or scripts/; tests/testthat/test-switch-registry.R FAILS CI on
# any name in neither list (and scripts/build_model_registry.R prints it as MR4!), so a new switch has to be registered
# or listed here. It sees only a literal Sys.getenv("AUSPOL_NAME" on one line: names built with sprintf (the
# AUSPOL_{QLD,WA,SA}_FLOWS / _CUTOFF reads in R/external_flows.R) and loop reads are registered by hand.
# Classification: docs/reviews/unregistered-switches-2026-10-29.tsv.
NON_MODEL_SWITCHES <- c(
  AUSPOL_AEF_RUNDIR              = "RUN",  # build_aef_comparison.R
  AUSPOL_AEF_WORST               = "DIAG",  # build_aef_comparison.R
  AUSPOL_ALLOW_INERT_ARM         = "RUN",  # pool_pf_arms.R, promote_arm.R
  AUSPOL_ALLOW_PARTIAL_PROMOTE   = "RUN",  # promote_arm.R, promote_rebuild.R
  AUSPOL_ANCHOR_SHA              = "RUN",  # build_forecast_json.R
  AUSPOL_ASAT_FORCE              = "RUN",  # fit_xgb_flows_asat.R, fit_xgb_primary_asat.R
  AUSPOL_AUDIT_TAG               = "BUILDER",  # audit_statewide_forecast.R, build_others_bucket_history.R
  AUSPOL_BOOTH_YEARS             = "BUILDER",  # fetch_booths_vic2022.R
  AUSPOL_BREAKOUT_CACHE_DIR      = "RUN",  # breakout_mix.R
  AUSPOL_BT_BASE                 = "BUILDER",  # build_bucket_total_history.R
  AUSPOL_BT_LOG                  = "BUILDER",  # build_bucket_total_history.R
  AUSPOL_BT_OUT                  = "RUN",  # build_bludgertrack_polls.R
  AUSPOL_BT_RAW                  = "RUN",  # build_bludgertrack_polls.R
  AUSPOL_CAND_ALLOW_OTHER_CHANGE = "BUILDER",  # build_candidacies.R
  AUSPOL_CAND_OUT                = "BUILDER",  # build_candidacies.R
  AUSPOL_VEC_CANDIDATES          = "BUILDER",  # build_candidacies.R: path of the VEC final list, for dry runs
  AUSPOL_TRACE_SEAT              = "DIAG",  # fit_seats_full.R: print one seat's row after every stage (TRS0/TRS1)
  AUSPOL_CHAMBER_SEATS           = "RUN",  # build_forecast_json.R
  AUSPOL_COUNCIL_LIB_ONLY        = "BUILDER",  # fetch_council_results.R
  AUSPOL_COUNCIL_YEARS           = "BUILDER",  # fetch_council_results.R
  AUSPOL_COV_JOIN                = "BUILDER",  # check_poll_coverage.R
  AUSPOL_CROSS_SEAT_CACHE_DIR    = "RUN",  # cross_seat_vote.R
  AUSPOL_CV_GRID                 = "BUILDER",  # score_class_variance.R
  AUSPOL_CV_V2                   = "BUILDER",  # score_class_variance.R
  AUSPOL_DATA_ROOT               = "BUILDER",  # build_wa_swing_correspondences.R, dry_run_seat_swing_port_wa.R, transpose_fed_swing.R
  AUSPOL_DEPARTED_HOLD_DUMP      = "DIAG",  # backtest_candidate_fed.R, backtest_candidate_nsw.R, backtest_candidate_qld.R, backtest_candidate_sa.R, backtest_candidate_vic.R, fit_seats_full.R
  AUSPOL_DIAG_PAIR               = "DIAG",  # diag_flow_one_seat.R
  AUSPOL_DIAG_PREV               = "DIAG",  # diag_flow_one_seat.R
  AUSPOL_DIAG_SEAT               = "DIAG",  # diag_flow_one_seat.R
  AUSPOL_DUMP_SHARES             = "DIAG",  # backtest_candidate_fed.R
  AUSPOL_EMERGE_HIGH             = "BUILDER",  # build_emergence_cases.R
  AUSPOL_EMERGE_LOW              = "BUILDER",  # build_emergence_cases.R
  AUSPOL_EMERGE_RISE             = "BUILDER",  # build_emergence_cases_v2.R, fit_xgb_emergence_v5.R
  AUSPOL_FED_PAIRS               = "RUN",  # backtest_candidate_fed.R
  AUSPOL_FLOW_ORACLE_CONFIGS     = "DIAG",  # score_flows_oracle.R
  AUSPOL_FLOW_WEIGHT             = "BUILDER",  # fit_xgb_flows_loo.R
  AUSPOL_FLOW_W_NROUNDS          = "BUILDER",  # fit_xgb_flows_weighted.R
  AUSPOL_FORECAST_ELECTION       = "RUN",  # build_forecast_json.R, build_trend_page_data.R
  AUSPOL_FUND_CACHE              = "RUN",  # fundamentals_tf.R
  AUSPOL_GATE_N                  = "BUILDER",  # gate_independent_salience.R
  AUSPOL_GATE_SLEEP              = "BUILDER",  # gate_independent_salience.R
  AUSPOL_HARNESS_RAW             = "RUN",  # harness_defaults.R
  AUSPOL_IND_COR                 = "DIAG",  # score_independent_federal.R
  AUSPOL_IND_SHRINK              = "DIAG",  # score_independent_federal.R
  AUSPOL_LEADER_KEEP             = "RUN",  # build_leader_ratings.R
  AUSPOL_LEADER_OUT              = "RUN",  # build_leader_ratings.R
  AUSPOL_LEADER_SRC              = "RUN",  # build_leader_ratings.R
  AUSPOL_LIVE_PAGES              = "RUN",  # merge_live_poll_pages.R
  AUSPOL_MAX_NEW                 = "BUILDER",  # fetch_emergence_trends.R
  AUSPOL_MC_ARM                  = "BUILDER",  # fit_minor_candidates.R
  AUSPOL_NB_PRIOR                = "BUILDER",  # build_notional_baselines.R
  AUSPOL_NB_TARGET               = "BUILDER",  # build_notional_baselines.R
  AUSPOL_NSW_PAIR                = "RUN",  # backtest_candidate_nsw.R
  AUSPOL_NSW_THIN_WALK           = "DIAG",  # fit_nsw.R
  AUSPOL_NT_DUMP_SHARES          = "DIAG",  # backtest_candidate_nt.R
  AUSPOL_NT_PAIR                 = "RUN",  # backtest_candidate_nt.R
  AUSPOL_OUT_SUFFIX              = "RUN",  # build_forecast_json.R, fit_seats_full.R
  AUSPOL_PB_LLM_DIR              = "BUILDER",  # build_pb_llm_polls.R, convert_pb_llm_wa.R, score_pb_llm_extraction.R
  AUSPOL_PB_LLM_OUT              = "BUILDER",  # build_pb_llm_polls.R
  AUSPOL_POLL_ARCHIVE_FILE       = "RUN",  # poll_source.R
  AUSPOL_POLL_BASE               = "RUN",  # check_poll_coverage.R, fetch_pollbludger_tracker_polls.R, fetch_statewide_poll_samples.R
  AUSPOL_POLL_BT_FILE            = "RUN",  # poll_source.R
  AUSPOL_POLL_MAX_AGE_H          = "RUN",  # fetch_statewide_poll_samples.R
  AUSPOL_POLL_ONLY               = "RUN",  # fetch_statewide_poll_samples.R
  AUSPOL_POLL_PB_FILE            = "RUN",  # poll_source.R
  AUSPOL_POLL_WIKI               = "RUN",  # poll_source.R
  AUSPOL_POOL_ALLOW_CONTAMINATED = "RUN",  # pool_sharedetail.R
  AUSPOL_POOL_MIN_SIMS           = "RUN",  # build_forecasts_table.R, pool_backtests.R, pool_sharedetail.R
  AUSPOL_PROMOTE_RUNDIR          = "RUN",  # promote_arm.R
  AUSPOL_QLD_PAIR                = "RUN",  # backtest_candidate_qld.R
  AUSPOL_QUICK_DIR               = "RUN",  # quick_arm.R
  AUSPOL_QUICK_SRC_OUTPUT        = "RUN",  # quick_arm.R
  AUSPOL_RELEASE_FORCE           = "RUN",  # publish_shipped_release.R
  AUSPOL_RELEASE_TAG             = "RUN",  # publish_shipped_release.R
  AUSPOL_RETIRE_REWRITE          = "BUILDER",  # fetch_retirements.R
  AUSPOL_SALIENCE_ANCHOR         = "BUILDER",  # build_vic2026_salience_jump.R, fetch_salience_vic2026_full.R
  AUSPOL_SALIENCE_CALIBRATE      = "BUILDER",  # fetch_seat_salience_v3.R
  AUSPOL_SALIENCE_CONTROLS       = "BUILDER",  # fetch_salience.R
  AUSPOL_SALIENCE_ELECTION       = "BUILDER",  # fetch_salience_v4.R, fetch_salience_v6.R, fetch_salience_v6_vic2010.R, fetch_seat_salience.R, fetch_seat_salience_v3.R, fit_salience_hazard_v4.R
  AUSPOL_SALIENCE_MAJORS         = "BUILDER",  # fetch_salience_v6.R, fetch_salience_v6_vic2010.R
  AUSPOL_SALIENCE_MAX            = "BUILDER",  # fetch_seat_salience.R, fetch_seat_salience_v3.R, fetch_seat_salience_vic2026_live.R, victoria_salience_dryrun.R
  AUSPOL_SALIENCE_MAXBATCH       = "BUILDER",  # fetch_salience_v4.R, fetch_salience_v5.R, fetch_salience_v6.R, fetch_salience_v6_vic2010.R
  AUSPOL_SALIENCE_MIN_YEAR       = "BUILDER",  # fetch_salience.R
  AUSPOL_SALIENCE_OUT            = "BUILDER",  # fetch_salience_v6.R
  AUSPOL_SALIENCE_SEATS          = "BUILDER",  # fetch_seat_salience_v3.R
  AUSPOL_SALIENCE_SLEEP          = "BUILDER",  # fetch_emergence_trends.R, fetch_salience.R, fetch_salience_v4.R, fetch_salience_v5.R, fetch_salience_v6.R, fetch_salience_v6_vic2010.R, fetch_salience_vic2026_full.R, fetch_seat_salience.R, fetch_seat_salience_v3.R, fetch_seat_salience_vic2026_live.R, victoria_salience_dryrun.R
  AUSPOL_SALIENCE_TO             = "BUILDER",  # build_vic2026_salience_jump.R, fetch_salience_vic2026_full.R
  AUSPOL_SA_PAIR                 = "RUN",  # backtest_candidate_sa.R
  AUSPOL_SCORE_SUFFIX            = "DIAG",  # score_wa_flows.R
  AUSPOL_SEAT_SWING_WA_FILE      = "RUN",  # seat_predictions.R, seat_swing_port.R
  AUSPOL_SHAP_PAIR               = "DIAG",  # shap_from_cached_model.R
  AUSPOL_SHAP_PARTY              = "DIAG",  # shap_from_cached_model.R
  AUSPOL_SHAP_SEAT               = "DIAG",  # shap_from_cached_model.R
  AUSPOL_SKIP_PAIRS              = "RUN",  # audit_statewide_forecast.R, build_forecasts_table.R, pool_backtests.R, pool_sharedetail.R, promote_rebuild.R
  AUSPOL_SMOKE_SIMS              = "DIAG",  # smoke_diff.R
  AUSPOL_SPREAD_RERUN_TOL        = "DIAG",  # compare_spread_tables.R
  AUSPOL_STAGE6_START            = "RUN",  # apply_upset_floor.R
  AUSPOL_SUCCESSOR_FLAGS         = "BUILDER",  # fit_departed_successor_rates.R
  AUSPOL_TARGET                  = "RUN",  # build_scenarios.R, fit_seats_full.R
  AUSPOL_TIDY_KEEP_DAYS          = "BUILDER",  # tidy_output.R
  AUSPOL_VIC_PAIR                = "RUN",  # backtest_candidate_vic.R
  AUSPOL_WA_DUMP_SHARES          = "DIAG",  # backtest_candidate_wa.R
  AUSPOL_WA_ELECTIONS            = "BUILDER",  # fetch_preferences_wa.R
  AUSPOL_WA_PAIR                 = "RUN",  # backtest_candidate_wa.R
  AUSPOL_XGB_SAVE_OOF_MODELS     = "DIAG",  # fit_xgb_primary_v6.R
  AUSPOL_XGB_SKIP_TRAIN          = "DIAG",  # fit_xgb_primary_v6.R
  # builder whose output the pipeline reads: output/state-deviation-features.csv (R/state_deviation.R, R/state_poll_pool.R).
  # The 29 Oct review filed it DEAD; its builder is run by hand, not dead.
  AUSPOL_STATE_POLL_NATL         = "BUILDER",  # build_state_deviation_features.R
  # RETIRED: read only by scripts/fit_xgb_primary_v7.R, bypassed for shipping since 2026-09-17 (fit_xgb_primary_v6.R,
  # the v7f note). Not deleted: diagnostics still read its output files (diagnose_primary_by_class.R, shap_ind_model.R).
  AUSPOL_SAL_CURVE_NZ            = "RETIRED",  # fit_xgb_primary_v7.R
  AUSPOL_V7_ARMS                 = "RETIRED",  # fit_xgb_primary_v7.R
  AUSPOL_V7_IND_FEAT             = "RETIRED",  # fit_xgb_primary_v7.R
  AUSPOL_V7_ONP                  = "RETIRED",  # fit_xgb_primary_v7.R
  AUSPOL_V7_SHIP                 = "RETIRED",  # fit_xgb_primary_v7.R
  AUSPOL_V7_SPLIT_BASE           = "RETIRED"   # fit_xgb_primary_v7.R
)

# MR4: every AUSPOL_* name read with Sys.getenv("...") in R/ or scripts/ (comment lines skipped) against the names
# registered in published_flags.R and the names listed above. `root` is the repository root.
mr4_scan <- function(root = ".") {
  pf <- readLines(file.path(root, "scripts", "published_flags.R"), warn = FALSE)
  registered <- sub("^\\s*(AUSPOL_[A-Z0-9_]+)\\s*=.*$", "\\1", grep("^\\s*AUSPOL_[A-Z0-9_]+\\s*=", pf, value = TRUE))
  files <- c(list.files(file.path(root, "R"), "\\.R$", full.names = TRUE),
             list.files(file.path(root, "scripts"), "\\.R$", full.names = TRUE))
  files <- files[!basename(files) %in% c("build_model_registry.R", "non_model_switches.R")]
  read <- unique(unlist(lapply(files, function(f) {
    x <- readLines(f, warn = FALSE)
    x <- x[!grepl("^\\s*#", x)]
    m <- regmatches(x, gregexpr("Sys\\.getenv\\(\\s*\"AUSPOL_[A-Z0-9_]+\"", x))
    sub("^.*\"(AUSPOL_[A-Z0-9_]+)\"$", "\\1", unlist(m))
  })))
  listed <- names(NON_MODEL_SWITCHES)
  list(read = read, registered = registered, n_files = length(files),
       unlisted = sort(setdiff(read, c(registered, listed))),
       stale_listed = sort(setdiff(listed, read)),
       both = sort(intersect(registered, listed)))
}
