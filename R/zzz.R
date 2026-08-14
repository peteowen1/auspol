#' @importFrom data.table := .N data.table setnames setattr fread rbindlist as.data.table uniqueN fwrite
#' @importFrom stats setNames optim
#' @importFrom utils globalVariables
NULL

.datatable.aware <- TRUE

# Column names used in data.table NSE expressions, plus the ggplot aesthetics
# built by plot_trends(). Declared so R CMD check does not read them as
# undefined globals.
globalVariables(c(
  ".", ".SD", "N", "actual", "effect", "effect_pts", "end", "exhaust",
  "fed_aligned", "fed_govt", "fed_opp", "firm", "firm_eff", "fitted",
  "flow_alp", "hi95", "incumbent", "is_incumbent", "is_opposition", "j",
  "lo95", "n", "opposition", "party", "prev1", "prev_avg", "raw_ratio",
  "ref_party", "region", "resid", "sd", "sd_link", "series", "start",
  "value", "y", "year", "years", "z2"
))
