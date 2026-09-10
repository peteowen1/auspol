#' @importFrom data.table := .N data.table setnames setattr fread rbindlist as.data.table uniqueN fwrite
#' @importFrom stats setNames optim predict
#' @importFrom utils globalVariables
NULL

.datatable.aware <- TRUE

# Column names used in data.table NSE expressions, plus the ggplot aesthetics
# built by plot_trends(). Declared so R CMD check does not read them as
# undefined globals.
globalVariables(c(
  ".", ".SD", "N", "actual", "age_days", "alp_win_prob", "asserted",
  "base_sd_pts", "breach", "dev", "dropped", "fitted_ok", "n_distinct",
  "n_rows", "poll_mean", "refolded_in",
  "mae", "value",
  "binomial_floor", "cause", "file_age_days", "status",
  "challenger", "classic", "detail", "effect", "effect_pts", "end", "err_use",
  "error",
  "exhaust", "implied_sd_pts", "lean_pts", "margin", "ratio",
  "fed_aligned", "fed_govt", "fed_opp", "firm", "firm_eff", "fitted",
  "flow_alp", "hi95", "incumbent", "is_incumbent", "is_opposition", "j",
  "lo95", "n", "opposition", "party", "prev1", "prev_avg", "raw_ratio",
  "ref_party", "region", "resid", "sd", "sd_link", "series", "start",
  "three_cornered",
  "value", "y", "year", "years", "z2"
))

# Added 2026-09-10: data.table NSE column names from this session's new/
# changed functions (xgb_primary_predict_live(), fit_dispersion_slopes(),
# trend_flow_matrix() -- the last pre-existing but not previously declared).
# Same reason as the block above: R CMD check reads these as undefined
# globals without this.
globalVariables(c(
  "..feat_cols", ".b", ".k", ".k_prev", ".mu", ".r2", ".rate", ".s",
  ".s_renamed", ".tl", "ALP", "LNP", "actual_now", "ballot_pos_min",
  "ballot_position", "breadth", "came_back", "cls_pcv", "def_party",
  "def_pcv", "def_was_mp", "departed_vote", "dev_after", "dev_before",
  "dev_dep", "dev_prev", "dev_ret", "elected", "election", "exp_pcv",
  "exp_sd", "fed_swing", "flow_lean", "flow_safe", "governed",
  "historic_elected", "historic_elected_i", "historic_elected_l", "hit",
  "incumbent_class", "is_incumbent_party_i", "is_major_i", "is_new",
  "is_recipient", "jump", "jump_pctile", "keyword", "lean", "lean_gap",
  "lean_mid", "level", "level_now", "level_prev", "lvl_after", "mp_hit",
  "n_cand_now", "n_cand_prev", "n_prior", "n_returning", "name",
  "name_after", "name_before", "nonmajor_defended", "nonmajor_prev",
  "nonmajor_vacant", "now", "own_pcv", "own_prev_pcv", "p_hat", "pair",
  "pct", "pcv", "pcv_after", "pcv_before", "permit", "permit_v", "pkey",
  "pred_share", "prev", "prev_ind", "prev_party", "prev_swing",
  "prior_leader_returns", "prior_pcv", "ret_frac", "retirement",
  "retirement_i", "returner_vote", "safe", "safe_gap", "safe_mid", "same",
  "same_i", "same_mp", "same_mp_i", "seat", "shape", "soph_cand",
  "soph_cand_i", "soph_party", "soph_party_i", "state_pcv", "surge_h",
  "swing", "target_pcv", "to", "tot", "tot_prior", "transfer", "v",
  "votes", "was_mp", "x", "xgb_pred", "yy"
))
