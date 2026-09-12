# PREDICTED statewide vote per party, per election -- the honest replacement
# for `level_now`.
#
# WHY. fit_xgb_primary_v6.R's `level_now` is state_level(pr$election): the
# party's ACTUAL statewide share at the election being predicted. Pete's ruling
# on 2026-09-11: "everything for an election forecast shold be predictive".
#
# And DELETING it is not the fix, which the evidence is blunt about. On sa2026
# the xgb primary scores 0.4200 with level_now and 0.6309 without it, because
# level_now was the model's ONLY route to knowing what was happening
# nationally. Pete's instruction was to substitute a PREDICTION, not to remove
# the information -- and the prediction is good: One Nation comes out at 19.83
# against an actual 22.50 on the very election where it surged.
#
# So this writes, for every pair, what the poll trend plus leave-one-out
# fundamentals would have said the day before polling day, using the same
# R/forecast_statewide.R the harnesses use. Nothing here sees the result.
#
# Emits LP* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
CAND <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
st_of <- function(el) {
  d <- CAND[CAND$election == el, list(v = sum(votes, na.rm = TRUE)), by = party]
  if (!nrow(d)) return(NULL)
  stats::setNames(100 * d$v / sum(d$v), d$party)
}

# Election dates. Sourced from the harnesses' own tables rather than retyped --
# a date that disagrees with the harness would silently fit the trend to the
# wrong window, and "one day before polling day" is the whole contract.
DATES <- c(
  fed2007 = "2007-11-24", fed2010 = "2010-08-21", fed2013 = "2013-09-07",
  fed2016 = "2016-07-02", fed2019 = "2019-05-18", fed2022 = "2022-05-21",
  fed2025 = "2025-05-03",
  nsw2019 = "2019-03-23", nsw2023 = "2023-03-25",
  qld2020 = "2020-10-31", qld2024 = "2024-10-26",
  sa2022  = "2022-03-19", sa2026 = "2026-03-21",
  vic2014 = "2014-11-29", vic2018 = "2018-11-24", vic2022 = "2022-11-26",
  wa2001  = "2001-02-10", wa2005 = "2005-02-26", wa2008 = "2008-09-06",
  wa2013  = "2013-03-09", wa2017 = "2017-03-11", wa2021 = "2021-03-13",
  wa2025  = "2025-03-08")
PREV <- c(
  fed2007 = "fed2004", fed2010 = "fed2007", fed2013 = "fed2010",
  fed2016 = "fed2013", fed2019 = "fed2016", fed2022 = "fed2019",
  fed2025 = "fed2022",
  nsw2019 = "nsw2015", nsw2023 = "nsw2019",
  qld2020 = "qld2017", qld2024 = "qld2020",
  sa2022  = "sa2018", sa2026 = "sa2022",
  vic2014 = "vic2010", vic2018 = "vic2014", vic2022 = "vic2018",
  wa2001  = "wa1996", wa2005 = "wa2001", wa2008 = "wa2005",
  wa2013  = "wa2008", wa2017 = "wa2013", wa2021 = "wa2017", wa2025 = "wa2021")

CLASSES <- c("ALP", "LNP", "GRN", "IND", "ONP", "OTH", "OTH_RIGHT")
mix <- fread(file.path(OUT, "projection-mix.csv"), showProgress = FALSE)
fl <- fundamentals_loo_table()

rows <- list(); failed <- character(0)
for (pr in names(DATES)) {
  reg <- sub("[0-9]{4}$", "", pr); yr <- as.integer(sub("^[a-z]+", "", pr))
  st_a <- st_of(PREV[[pr]])
  if (is.null(st_a)) { cat(sprintf("LP0! %s: no prior statewide for %s -- skipped\n", pr, PREV[[pr]])); failed <- c(failed, pr); next }
  r <- tryCatch(
    forecast_statewide_for(reg, yr, DATES[[pr]], CLASSES, st_a, fl, mix,
                           n_sims = 2000L, seed = 42L),
    error = function(e) { cat(sprintf("LP0! %s: %s\n", pr, conditionMessage(e))); NULL })
  if (is.null(r)) { failed <- c(failed, pr); next }
  rows[[pr]] <- data.table(pair = pr, party = names(r$st_fc),
                           level_pred = unname(r$st_fc))
}
LP <- rbindlist(rows, fill = TRUE)
if (!nrow(LP)) stop("no pair produced a predicted statewide")
LP[, from_polls := 1L]

# A PAIR WITH NO POLL-BASED PREDICTION FALLS BACK TO THE PRIOR ELECTION, not to
# NA. wa2021 has too thin a polling cycle to fit a trend at all, and leaving it
# NA would be worse than useless: xgboost treats NA as a value it can split on,
# so the model would quietly learn "NA means wa2021" and fit that election's
# residual pattern -- a leak created by a gap rather than by a feature.
#
# The honest no-information forecast is "no statewide swing", i.e. last
# election's result carried forward. `from_polls` records which is which, so a
# model can discount the fallback rows and a reader can see them.
for (pr in failed) {
  a <- st_of(PREV[[pr]])
  if (is.null(a)) next
  keep <- intersect(names(a), CLASSES)
  LP <- rbind(LP, data.table(pair = pr, party = keep,
                             level_pred = unname(a[keep]), from_polls = 0L), fill = TRUE)
  cat(sprintf("LP0  %s: no usable polls -- falling back to %s's result as the no-swing prediction\n",
              pr, PREV[[pr]]))
}

# COVERAGE, asserted rather than assumed. A pair silently missing here becomes
# a pair whose level_pred is NA, which xgboost treats as a value rather than an
# error -- the model would quietly learn "NA means this election".
cat(sprintf("\nLP1  %d of %d pairs have a predicted statewide%s\n",
            uniqueN(LP$pair), length(DATES),
            if (length(failed)) sprintf("; FAILED: %s", paste(failed, collapse = ", ")) else ""))

# Score it against the truth, because a predictor nobody checked is a feature
# nobody should trust. This is the only place the actual result is read, and it
# is read for REPORTING, never fed back into the prediction.
ACT <- rbindlist(lapply(names(DATES), function(pr) {
  a <- st_of(pr); if (is.null(a)) return(NULL)
  data.table(pair = pr, party = names(a), actual = unname(a))
}), fill = TRUE)
CMP <- merge(LP, ACT, by = c("pair", "party"), all.x = TRUE)
CMP[, err := level_pred - actual]
# SPLIT THE FALLBACK ROWS OUT OF THE ACCURACY CLAIM. LP2-LP4 pool every row,
# including the pairs whose cycle was too thin to fit and which carry last
# election's result unchanged. Those are a naive baseline, not a forecast, and
# mixing them into "how good is the prediction" overstates or understates it
# depending on how that election moved. Found by the review gate 2026-09-11.
cat(sprintf("\nLP2a headline accuracy on POLL-BASED rows only (%d of %d cells): mean absolute error %.2f points\n",
            sum(CMP$from_polls == 1L), nrow(CMP),
            mean(abs(CMP[from_polls == 1L]$err), na.rm = TRUE)))
if (any(CMP$from_polls == 0L))
  cat(sprintf("LP2a the %d no-swing fallback cell(s) score %.2f -- reported separately, never folded in\n",
              sum(CMP$from_polls == 0L), mean(abs(CMP[from_polls == 0L]$err), na.rm = TRUE)))
cat("\nLP2  how good is the prediction? mean absolute error in points, per pair\n")
print(CMP[, .(classes = .N, poll_based = sum(from_polls == 1L),
              mae = round(mean(abs(err), na.rm = TRUE), 2)), by = pair][order(-mae)])
cat("\nLP3  by class, pooled over pairs. bias = predicted minus actual\n")
print(CMP[, .(n = .N, bias = round(mean(err, na.rm = TRUE), 2),
              mae = round(mean(abs(err), na.rm = TRUE), 2)), by = party][order(-mae)])
cat(sprintf("\nLP4  overall mean absolute error %.2f points over %d (pair, class) cells\n",
            mean(abs(CMP$err), na.rm = TRUE), nrow(CMP)))

fwrite(LP, file.path(OUT, "level-pred.csv"))
cat(sprintf("LP5  wrote %s/level-pred.csv\n", OUT))
