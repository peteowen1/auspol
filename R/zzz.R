#' @importFrom data.table := .N data.table setnames setattr fread rbindlist as.data.table uniqueN fwrite
#' @importFrom stats setNames optim
#' @importFrom utils globalVariables
NULL

.datatable.aware <- TRUE

# Column names used in data.table NSE expressions, plus the ggplot aesthetics
# built by plot_trends(). Declared so R CMD check does not read them as
# undefined globals.
globalVariables(c(
  ".", "N", "effect", "effect_pts", "end", "exhaust", "firm", "firm_eff",
  "fitted", "flow_alp", "hi95", "j", "lo95", "n", "raw_ratio", "resid", "sd",
  "sd_link", "series", "start", "value", "y", "year", "z2"
))
