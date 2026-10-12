# Prereg step 0 (docs/plans/prereg-poll-level-centring-2026-10-12.md): clustered SE of day-before level-RMSE differences,
# all scored elections, from output/level-recent.csv. Read-only. Run: Rscript scripts/diag_level_mde.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
suppressMessages(library(data.table))
tab <- fread(out_path("level-recent.csv"), showProgress = FALSE)
eds <- election_dates()
Sys.setenv(AUSPOL_LEVEL_RECENT = "decay", AUSPOL_LEVEL_RECENT_HALFLIFE = "20")
cat("MDE0 applies AUSPOL_LEVEL_RECENT=", Sys.getenv("AUSPOL_LEVEL_RECENT"), " HL=", Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE"), "\n")
rows <- list()
for (e in setdiff(unique(tab$election), c("vic2026", "nsw2027"))) {
  d <- tab[tab$election == e]
  lv <- setNames(d$trend, d$cls)
  if (any(!is.finite(lv[c("ALP","LNP","GRN")]))) { cat("skip", e, "(no trend)\n"); next }
  lv <- c(lv[c("ALP","LNP","GRN")], OTH = 100 - sum(lv[c("ALP","LNP","GRN")]))
  lg <- capture.output(res <- suppressWarnings(level_recent_apply(lv, e, d$region[1], as.Date(unname(eds[e])), code = "M", tab = tab)))
  w <- suppressWarnings(as.numeric(sub(".*, w ([0-9.]+):.*", "\\1", lg[grepl(", w ", lg)])))
  for (k in c("ALP","LNP","GRN")) {
    dk <- d[d$cls == k]
    rows[[length(rows)+1]] <- data.table(e = e, k = k, trend = dk$trend, raw = dk$avg28, inc = unname(res[k]),
                                         actual = dk$actual, w = if (length(w)) w[1] else NA_real_)
  }
}
R <- rbindlist(rows)[is.finite(actual) & is.finite(inc)]
R[!is.finite(raw), raw := inc]   # no polls in 28 days: raw undefined, use incumbent (zero difference)
cat(sprintf("MDE1 %d cells, %d elections; w (share on recent polls) median %.2f, range %.2f-%.2f\n",
            nrow(R), uniqueN(R$e), median(R$w, na.rm=TRUE), min(R$w, na.rm=TRUE), max(R$w, na.rm=TRUE)))
rmse <- function(x, a) sqrt(mean((x - a)^2))
jk <- function(col_a, col_b) {   # RMSE(a) - RMSE(b), SE by delete-one-election jackknife
  full <- rmse(R[[col_a]], R$actual) - rmse(R[[col_b]], R$actual)
  els <- unique(R$e); G <- length(els)
  th <- vapply(els, function(x) { m <- R$e != x; rmse(R[[col_a]][m], R$actual[m]) - rmse(R[[col_b]][m], R$actual[m]) }, 0)
  c(diff = full, se = sqrt((G - 1) / G * sum((th - mean(th))^2)))
}
cat(sprintf("MDE2 RMSE vs actual (points, lower better): trend %.3f | raw 28-day mean %.3f | shipped (decay 20) %.3f\n",
            rmse(R$trend, R$actual), rmse(R$raw, R$actual), rmse(R$inc, R$actual)))
for (p in list(c("inc","raw"), c("inc","trend"), c("trend","raw"))) {
  r <- jk(p[1], p[2]); cat(sprintf("MDE3 %s - %s: %+.3f (clustered SE %.3f, 22-ish clusters)\n", p[1], p[2], r["diff"], r["se"]))
}
# How much can a trend-only arm move the shipped level? (1 - w) x trend change
R[, gap_trend_inc := abs(trend - inc)]
cat(sprintf("MDE4 |trend - shipped level|: median %.2f, max %.2f points; (1-w) median %.3f\n",
            median(R$gap_trend_inc), max(R$gap_trend_inc), median(1 - R$w, na.rm=TRUE)))
print(R[, .(e, k, trend = round(trend,1), raw = round(raw,1), inc = round(inc,1), actual = round(actual,1), w = round(w,2))][order(e,k)][1:12])
