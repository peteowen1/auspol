# THE DAY-BEFORE STATEWIDE FORECAST, AUDITED FOR EVERY SCORED PAIR.
# Model item (0) in docs/NEXT-STEPS.md: since the backtests became predictive
# throughout, the statewide level the seats swing toward is the biggest lever
# in the ledger. This prints, per pair, exactly what forecast_statewide_for()
# produced the day before -- trend two-party, leave-one-out fundamentals, the
# mix weight, the anchored two-party, and each class's forecast first
# preference against the counted result -- so the worst cycles can be walked
# with Pete before anything is fitted. Writes output/statewide-forecast-audit.csv.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
P <- all_election_pairs()
dates <- election_dates()
fund <- fundamentals_loo_table()
mix <- fread("output/projection-mix.csv", showProgress = FALSE)
CAND <- fread("output/candidacies.csv", showProgress = FALSE)[is.finite(votes)]
skip <- trimws(strsplit(Sys.getenv("AUSPOL_SKIP_PAIRS", "wa2021"), ",")[[1]])
rows <- list()
for (pr in P) {
  el <- pr$election; if (el %in% skip) next
  reg <- sub("[0-9]{4}$", "", el); yr <- as.integer(sub("^[a-z]+", "", el))
  ed <- dates[[el]]
  # actual statewide first preferences by class, from the candidate corpus
  # (output/candidacies.csv carries votes per candidate for every scored election)
  ab <- CAND[election == el]; aa <- CAND[election == pr$prev]
  if (!nrow(ab)) { cat("SA0! no candidacies for ", el, "
"); next }
  act <- ab[, .(v = sum(votes, na.rm = TRUE)), by = party][, setNames(100 * v / sum(v), party)]
  st_a <- if (nrow(aa)) aa[, .(v = sum(votes, na.rm = TRUE)), by = party][, setNames(100 * v / sum(v), party)] else act
  parties <- union(names(act), c("ALP", "LNP", "GRN", "OTH"))
  fc <- tryCatch(suppressWarnings(forecast_statewide_for(reg, yr, ed, parties, st_a, fund, mix, n_sims = 20000, seed = 42)),
                 error = function(e) { cat(sprintf("SA0! %s: %s\n", el, conditionMessage(e))); NULL })
  if (is.null(fc)) next
  w <- project_result(fc$tpp, fc$fund, mix, horizon = 1L)$w
  for (cl in intersect(names(fc$st_fc), names(act)))
    rows[[length(rows) + 1]] <- data.table(pair = el, region = reg, n_polls = fc$n_polls, trend_tpp = round(fc$tpp, 2),
      fund_tpp = round(fc$fund, 2), w_trend = round(w, 2), anchored_tpp = round(fc$implied_tpp, 2),
      cls = cl, forecast = round(fc$st_fc[[cl]], 2), actual = round(act[[cl]], 2), miss = round(fc$st_fc[[cl]] - act[[cl]], 2))
}
A <- rbindlist(rows)
fwrite(A, "output/statewide-forecast-audit.csv")
cat("SA1  day-before statewide forecast miss (forecast - actual, first-preference points) by pair and class; lower |miss| is better\n")
W <- dcast(A[cls %in% c("ALP", "LNP", "GRN", "ONP")], pair + n_polls + trend_tpp + fund_tpp + w_trend ~ cls, value.var = "miss")
print(W[order(pair)])
cat("SA2  mean |miss| over ALP/LNP/GRN by pair, worst first:\n")
print(A[cls %in% c("ALP", "LNP", "GRN"), .(mean_abs_miss = round(mean(abs(miss)), 2), alp_miss = round(miss[cls == "ALP"], 2)), by = pair][order(-mean_abs_miss)])
cat("SA3  wrote output/statewide-forecast-audit.csv\n")
