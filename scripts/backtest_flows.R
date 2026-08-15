# Which preference-flow estimator should we use? Re-run the comparison that
# chose the current one, and fail if it is no longer the winner.
#
# The choice of estimator is itself a modelling decision, and one made from
# data. Left as a one-off in a scratch file it becomes exactly the thing this
# project is trying not to have: a value someone picked once, now unfalsifiable
# from the repository and never revisited. Australian elections arrive every
# few months; the ranking below can change, and when it does someone should be
# told rather than left running yesterday's winner.
#
# Method: strict temporal backtest. Every election is predicted using ONLY
# elections held strictly earlier -- never leave-one-out, which lets a later
# election inform an earlier prediction and endorsed a linear trend that
# honest validation ranks fifth.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/backtest_flows.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# The estimator the package actually uses. If this changes, change it here too
# -- G3 compares the winner against this name and will say so.
ADOPTED <- "mean_last5"

flows <- as.data.table(load_preference_flows())
cycles <- load_election_cycles()
flows[, observed := is_observed_election(flows, cycles)]
obs <- flows[observed == TRUE][order(year)]

# First preferences, so "was this party a similar size then?" can be tested as
# a weighting rather than assumed to matter.
er <- as.data.table(read_anchor_csv("eventual-results.csv",
                                    c("year", "region", "party", "result")))
er[, result := suppressWarnings(as.numeric(result))]
er[, party := sub(" FP$", "", party)]
obs <- merge(obs, er[!is.na(result), .(year, region, party, fp = result)],
             by = c("year", "region", "party"), all.x = TRUE)
setorder(obs, year)

wmean <- function(v, w) sum(v * w) / sum(w)
decay <- function(pp, yr, hl) 0.5^((yr - pp$year) / hl)

METHODS <- list(
  last            = function(pp, rg, yr, tfp) pp[which.max(year), flow_alp],
  mean_last3      = function(pp, rg, yr, tfp) mean(utils::tail(pp[order(year), flow_alp], 3)),
  mean_last5      = function(pp, rg, yr, tfp) mean(utils::tail(pp[order(year), flow_alp], 5)),
  mean_last8      = function(pp, rg, yr, tfp) mean(utils::tail(pp[order(year), flow_alp], 8)),
  last_in_region  = function(pp, rg, yr, tfp) {
    s <- pp[region == rg]
    if (nrow(s)) s[which.max(year), flow_alp] else pp[which.max(year), flow_alp] },
  trend           = function(pp, rg, yr, tfp)
    unname(stats::predict(stats::lm(flow_alp ~ year, pp), data.frame(year = yr))),
  half_trend      = function(pp, rg, yr, tfp) {
    tr <- unname(stats::predict(stats::lm(flow_alp ~ year, pp), data.frame(year = yr)))
    0.5 * tr + 0.5 * pp[which.max(year), flow_alp] },
  exp_hl4         = function(pp, rg, yr, tfp) wmean(pp$flow_alp, decay(pp, yr, 4)),
  exp_hl8         = function(pp, rg, yr, tfp) wmean(pp$flow_alp, decay(pp, yr, 8)),
  exp_hl8_region  = function(pp, rg, yr, tfp)
    wmean(pp$flow_alp, decay(pp, yr, 8) * ifelse(pp$region == rg, 2, 1)),
  exp_hl8_size    = function(pp, rg, yr, tfp) {
    if (is.na(tfp) || all(is.na(pp$fp))) return(wmean(pp$flow_alp, decay(pp, yr, 8)))
    sim <- exp(-abs(pp$fp - tfp) / 8); sim[is.na(sim)] <- mean(sim, na.rm = TRUE)
    wmean(pp$flow_alp, decay(pp, yr, 8) * sim) }
)

rows <- rbindlist(lapply(which(obs$year >= 2004), function(i) {
  tg <- obs[i]
  pp <- obs[year < tg$year & party == tg$party]   # strictly earlier only
  if (nrow(pp) < 5) return(NULL)
  out <- data.table(year = tg$year, region = tg$region, party = tg$party,
                    actual = tg$flow_alp)
  for (nm in names(METHODS)) out[[nm]] <- METHODS[[nm]](pp, tg$region, tg$year, tg$fp)
  out
}), fill = TRUE)

stopifnot(nrow(rows) >= 50)
cat(sprintf("\n=== preference-flow estimators, %d elections %d-%d ===\n",
            nrow(rows), min(rows$year), max(rows$year)))

score <- rbindlist(lapply(names(METHODS), function(nm) {
  e <- rows$actual - rows[[nm]]
  data.table(method = nm, mae = mean(abs(e)), rmse = sqrt(mean(e^2)))
}))[order(mae)]
print(score[, .(method, mae = round(mae, 3), rmse = round(rmse, 3))])

winner <- score$method[1]
adopted_mae <- score[method == ADOPTED, mae]
gap <- adopted_mae - score$mae[1]

cat(sprintf("\nG3  flow estimator: adopted '%s' (MAE %.3f), best '%s' (MAE %.3f), gap %.3f  %s\n",
            ADOPTED, adopted_mae, winner, score$mae[1], gap,
            if (gap <= 0.15) "PASS" else "FAIL"))

# A small gap is tolerated deliberately. These are 100-odd elections and the
# ranking jitters; swapping estimator every time a new one nudges ahead by a
# hundredth of a point would be fitting the backtest rather than using it.
# A gap this size means the adopted method is no longer defensible.
if (gap > 0.15) {
  stop(sprintf("'%s' now beats the adopted '%s' by %.3f MAE. Re-examine the choice in R/flow_model.R before publishing.",
               winner, ADOPTED, gap))
}

cat("\n=== per party (reported, not enforced: too few elections each to choose on) ===\n")
for (p in sort(unique(rows$party))) {
  r <- rows[party == p]
  if (nrow(r) < 8) next
  s <- rbindlist(lapply(names(METHODS), function(nm)
    data.table(method = nm, mae = mean(abs(r$actual - r[[nm]])))))[order(mae)]
  cat(sprintf("  %-4s n=%2d  best %-16s %.3f   adopted %.3f\n",
              p, nrow(r), s$method[1], s$mae[1], s[method == ADOPTED, mae]))
}

cat("\n=== what the adopted estimator gives the live cycle ===\n")
for (p in c("GRN", "ONP", "OTH")) {
  e <- estimate_flow(flows, p, 2026, cycles)
  if (is.null(e)) next
  cat(sprintf("  %-4s %.2f  (%s: %s)\n", p, e$flow, e$model, e$years))
}
