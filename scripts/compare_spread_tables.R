# Did the seat-size spread table move between the copy stage 6 read and the one stage 7 just refitted?
#
# fit_spread_by_size.R fits on stage 6's OWN published shares, so it can only run after stage 6, and stage 6's
# seat probabilities used the table from the run before. The spread never moves a predicted share, so when the
# refit matches the table stage 6 read, stage 6 was already exact; when it does not, rebuild_forecasts.sh reruns
# stages 6-7 once (Pete, 2026-10-14). Compared on the widening factor a seat actually receives, at four seat
# sizes, for every target stage 7 pooled. A target missing from either table counts as moved.
#   Rscript scripts/compare_spread_tables.R <table stage 6 read> <refitted table>
# Exit 0: unchanged within AUSPOL_SPREAD_RERUN_TOL (default 0.02), or AUSPOL_SIZE_SD is off. Exit 3: moved.
suppressMessages(library(data.table))
source("scripts/published_flags.R"); invisible(apply_published_flags())
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: compare_spread_tables.R <old.csv> <new.csv>")
if (!identical(Sys.getenv("AUSPOL_SIZE_SD"), "1")) { cat("SPZ2  AUSPOL_SIZE_SD is off: stage 6 read no table\n"); quit(status = 0) }
tol <- as.numeric(Sys.getenv("AUSPOL_SPREAD_RERUN_TOL", "0.02"))
if (!is.finite(tol) || tol < 0) stop("AUSPOL_SPREAD_RERUN_TOL must be a non-negative number")
for (f in args) if (!file.exists(f)) stop("SPZ2! ", f, " is missing")
old <- fread(args[1], showProgress = FALSE); new <- fread(args[2], showProgress = FALSE)
scored <- fread("output/pooled-backtest.csv", showProgress = FALSE)$pair
if (!length(scored)) stop("SPZ2! output/pooled-backtest.csv lists no pairs")
# The factor R/size_sd.R gives a seat of `formal` votes; an unfitted row (slope 0, w 0 or no median) widens nothing.
fac <- function(tab, tg, formal) {
  r <- tab[tab$target %in% tg]
  if (nrow(r) != 1L) return(rep(NA_real_, length(formal)))
  if (!is.finite(r$slope) || r$slope == 0 || !is.finite(r$w) || r$w == 0 || !is.finite(r$f_median)) return(rep(1, length(formal)))
  pmax(1, exp(r$w * r$slope * (log(formal) - log(r$f_median))))
}
sizes <- c(2000, 5000, 10000, 20000)
D <- rbindlist(lapply(scored, function(tg) {
  d <- abs(fac(new, tg, sizes) - fac(old, tg, sizes))
  data.table(target = tg, max_change = if (anyNA(d)) Inf else max(d))
}))
setorder(D, -max_change)
moved <- D[max_change > tol]
cat(sprintf("SPZ2  spread table: %d of %d scored targets moved by more than %.3f in the widening factor (largest %s %.4f)\n",
            nrow(moved), nrow(D), tol, D$target[1], D$max_change[1]))
if (nrow(moved)) { print(moved, nrows = 60); quit(status = 3) }
quit(status = 0)
