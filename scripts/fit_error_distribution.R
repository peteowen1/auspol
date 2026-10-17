# Empirical error distribution for AUSPOL_ERROR_DIST (default "0" = off;
# docs/plans/prereg-error-distribution-2026-10-17.md). The simulator draws each cell's noise as rnorm, but the
# errors we make are heavy-tailed everywhere (0.57% of cells miss by 4+ sds; a bell curve gives 0.006%) and
# skewed for independents (most come in a little under, a few surge). This replaces the SHAPE, not the width.
#
# For each target, from EARLIER elections' published cells predicted 2+:
#   z = (actual - pred) / (sdm x the size factor that pair applied),  sdm = 1.10 + 8.67 sqrt(p(1-p))
# 201 quantiles (0.5% steps) per class, shrunk toward the pooled quantiles by w = n / (n + 200), then rescaled
# so each class's distribution has RMS 1 (the rnorm it replaces). Fewer than 3 earlier elections or 2,000
# cells: no row (the simulator keeps rnorm).
# Writes output/error-quantiles.csv: target, class, n, w, then q000..q200.
#   Rscript scripts/fit_error_distribution.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
OUT <- "output"; source("scripts/ledger_inputs.R")
pb <- fread(file.path(OUT, "pooled-backtest.csv"))
S <- rbindlist(lapply(pb$pair, function(pr) { d <- tryCatch(run_table(pr, "sharedetail"), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL); if (!"pair" %in% names(d)) d[, pair := pr]; d[pair == pr] }), fill = TRUE)
S <- S[is.finite(pred_share) & is.finite(actual_share)]
cat(sprintf("ERF0  %d cells, %d elections (published path)\n", nrow(S), uniqueN(S$pair)))

# The size factor each pair's own run applied (R/size_sd.R), per seat; 1 where the size spread is off/unfitted.
withr::local_envvar(AUSPOL_SIZE_SD = Sys.getenv("AUSPOL_SIZE_SD", "1"))
sf <- rbindlist(lapply(unique(S$pair), function(pr) {
  seats <- unique(S$seat[S$pair == pr])
  m <- matrix(0, length(seats), 1, dimnames = list(seats, "ALP"))
  f <- if (identical(Sys.getenv("AUSPOL_SIZE_SD"), "1")) {
    invisible(utils::capture.output(v <- auspol:::.size_factor(m, pr, pr, NULL))); v
  } else NULL
  data.table(pair = pr, seat = seats, size_f = if (is.null(f)) 1 else f)
}))
S <- merge(S, sf, by = c("pair", "seat"))
S <- S[S$pred_share >= 2]
S[, p := pred_share / 100][, z := (actual_share - pred_share) / ((1.10 + 8.67 * sqrt(p * (1 - p))) * size_f)]
ed <- election_dates()
S[, day := as.Date(unname(ed[pair]))]
if (anyNA(S$day)) stop("ERF0! no election date for: ", paste(unique(S$pair[is.na(S$day)]), collapse = ", "))
cat(sprintf("ERF1  %d cells predicted 2+; pooled z: RMS %.2f, robust sd %.2f, %.2f%% beyond 4, median %.2f\n",
            nrow(S), sqrt(mean(S$z^2)), 1.4826 * stats::median(abs(S$z)), 100 * mean(abs(S$z) > 4), stats::median(S$z)))

PR <- seq(0, 1, by = 0.005); QN <- sprintf("q%03d", seq_along(PR) - 1L)
K_SHRINK <- 200
# Exact RMS of the distribution the simulator draws (linear interpolation between quantiles, u uniform): on each
# 0.5% segment from a to b the mean of the square is (a^2 + ab + b^2) / 3. A plain mean of the 201 points would
# give the min and max a full 0.5% each instead of half that.
rms1 <- function(q) {
  a <- q[-length(q)]; b <- q[-1L]
  r <- sqrt(mean((a^2 + a * b + b^2) / 3))
  if (r > 0) q / r else q
}
targets <- unique(c(pb$pair, "vic2026", "nsw2027", "fed2028"))
CLASSES <- sort(unique(S$party))
res <- rbindlist(lapply(targets, function(tg) {
  tday <- as.Date(unname(ed[tg])); if (is.na(tday)) return(NULL)
  tr <- S[S$day < tday]
  if (uniqueN(tr$pair) < 3L || nrow(tr) < 2000L) return(NULL)
  qp <- stats::quantile(tr$z, PR, names = FALSE, type = 7)
  rbindlist(lapply(CLASSES, function(k) {
    zk <- tr$z[tr$party == k]; n <- length(zk); w <- n / (n + K_SHRINK)
    qk <- if (n >= 2L) stats::quantile(zk, PR, names = FALSE, type = 7) else qp
    q <- rms1(w * qk + (1 - w) * qp)
    as.data.table(c(list(target = tg, class = k, n = n, w = round(w, 4), n_pairs = uniqueN(tr$pair)), stats::setNames(as.list(q), QN)))
  }))
}))
fwrite(res, file.path(OUT, "error-quantiles.csv"))
show <- res[res$target %in% c("fed2016", "vic2022", "vic2026"),
            list(target, class, n, w, median = round(q100, 2), p01 = round(q002, 2), p99 = round(q198, 2),
                 p0.5 = round(q001, 2), p99.5 = round(q199, 2))]
cat("ERF2  per class after shrinkage and RMS-1 rescaling (a bell curve: median 0, p01 -2.33, p99 +2.33):\n")
print(show, nrows = 40)
cat(sprintf("ERF3  wrote output/error-quantiles.csv (%d targets x %d classes, %d quantiles)\n", uniqueN(res$target), length(CLASSES), length(PR)))
