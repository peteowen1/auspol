# Screen (2026-10-10): day-before statewide level, shipped trend vs a plain
# average of the last 28 days of polls, on ALP/LNP/GRN, all 22 pairs.
# Time-forward: only polls fielded before polling day. No outcome is used to
# build either forecast; the actual is read only to score them.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
library(data.table)
C <- fread("output/candidacies.csv", select = c("election", "party", "votes"), showProgress = FALSE)
share <- function(e) { x <- C[C$election == e & is.finite(C$votes), list(v = sum(votes)), by = party]; setNames(100 * x$v / sum(x$v), x$party) }
prs <- all_election_pairs()
prs <- prs[vapply(prs, function(p) p$election != "wa2021", NA)]
cls <- c("ALP", "LNP", "GRN")
rows <- list()
for (p in prs) {
  e <- p$election; reg <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e))
  ed <- as.Date(unname(election_dates()[e]))
  sa <- share(p$prev); sb <- share(e)
  fc <- NULL
  utils::capture.output(fc <- tryCatch(forecast_statewide_or_oracle(reg, yr, ed, names(sb), sa, sb, code = "TV0", n_sims = 20000L, seed = 42L, on_fail = "skip"),
                                       error = function(err) NULL))
  pl <- as.data.table(suppressMessages(load_polls(reg)))
  w <- pl[pl$date < ed & pl$date >= ed - 28]
  for (k in cls) {
    avg <- if (nrow(w) && k %in% names(w)) mean(w[[k]], na.rm = TRUE) else NA_real_
    rows[[length(rows) + 1L]] <- data.table(pair = e, cls = k, actual = unname(sb[k]),
                                            trend = if (is.null(fc)) NA_real_ else unname(fc[k]), avg28 = avg, n28 = nrow(w))
  }
}
R <- rbindlist(rows)
R[, `:=`(err_trend = trend - actual, err_avg = avg28 - actual)]
fwrite(R, file.path(Sys.getenv("TEMP"), "trend_vs_avg.csv"))
ok <- R[is.finite(err_trend) & is.finite(err_avg)]
cat(sprintf("TV1  %d class-elections scored (%d elections) of %d; polls in the last 28 days per election: %s\n",
            nrow(ok), uniqueN(ok$pair), nrow(R), paste(sprintf("%s %d", unique(R$pair), R[, n28[1], by = pair]$V1), collapse = ", ")))
cat("TV2  mean absolute error, points (lower is better):\n")
print(ok[, list(n = .N, trend = round(mean(abs(err_trend)), 2), avg28 = round(mean(abs(err_avg)), 2),
                trend_bias = round(mean(err_trend), 2), avg_bias = round(mean(err_avg), 2)), by = cls])
pe <- ok[, list(d = mean(abs(err_avg)) - mean(abs(err_trend))), by = pair]
cat(sprintf("TV3  overall MAE trend %.2f vs 28-day average %.2f; average better in %d of %d elections; paired mean diff (avg - trend) %+.2f, SE %.2f (clustered on election)\n",
            mean(abs(ok$err_trend)), mean(abs(ok$err_avg)), sum(pe$d < 0), nrow(pe), mean(pe$d), sd(pe$d) / sqrt(nrow(pe))))
print(ok[cls == "LNP" | pair == "vic2022", list(pair, cls, actual = round(actual, 1), trend = round(trend, 1), avg28 = round(avg28, 1), n28)][order(pair)], nrows = 80)
