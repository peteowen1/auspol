# Fit pair_cal = c(alpha, beta) for night_apply_tcp() from EARLIER nights' base replays, time-forward
# (docs/plans/prereg-night-pair-cal-2026-11-11.md).
#
#   Rscript scripts/fit_night_pair_cal.R --dir=<replay out dir> --nights=fed2022[,vic2022] --r=<r for the target night>
#       [--label=base] [--n=20000] [--out=<csv to append the fit to>]
#
# Data: every seat where the commission showed a pair, at the FIRST replay time it shows. x = qlogis(p_s),
# p_s = (h + 0.5)/(n + 1) from the base replay's draws; y = 1 if that pair is the declared final pair.
#   federal: <night>-<label>-tcp.csv rows are declared pairs (y = 1) unless wrong_pair is TRUE (y = 0)
#   vic:     y from the declared pair in output/booths/<night>-booth-tcp.csv (party classes, classify_party())
# MAP logistic: alpha ~ N(qlogis(r), 1), beta ~ N(1, 0.5). With no earlier night, run nothing: the prior means are the fit.
# Check codes NPC1-NPC3.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
dir <- flag("dir"); nights <- strsplit(flag("nights", ""), ",")[[1]]; r <- as.numeric(flag("r"))
label <- flag("label", "base"); n <- as.numeric(flag("n", "20000")); out <- flag("out")
if (is.null(dir) || !length(nights) || !is.finite(r)) stop("NPC1! need --dir, --nights and --r")
tmin <- function(x) vapply(strsplit(x, ":", fixed = TRUE), function(z) as.numeric(z[1]) * 60 + as.numeric(z[2]), 0)

rows <- list()
for (nt in nights) {
  f <- file.path(dir, sprintf("%s-%s-tcp.csv", nt, label))
  if (!file.exists(f)) stop("NPC1! missing ", f)
  d <- fread(f)
  if (!"wrong_pair" %in% names(d)) d[, wrong_pair := FALSE]
  d[is.na(wrong_pair), wrong_pair := FALSE]
  d[, tm := tmin(time)]
  d <- d[order(seat, tm)][, .SD[1L], by = seat]
  if (startsWith(nt, "fed")) {
    d[, y := as.integer(!wrong_pair)]
  } else {
    bt <- fread(sprintf("output/booths/%s-booth-tcp.csv", nt), select = c("district", "party_raw"))
    dec <- unique(bt)[, list(dec = paste(sort(unique(classify_party(party_raw))), collapse = "|")), by = district]
    d <- merge(d, dec, by.x = "seat", by.y = "district", all.x = TRUE)
    nodec <- sum(is.na(d$dec)); if (nodec) cat(sprintf("NPC2 %s: %d seat(s) with no declared pair, dropped: %s\n", nt, nodec, paste(d$seat[is.na(d$dec)], collapse = ", ")))
    d <- d[!is.na(dec)]
    d[, y := as.integer(paste(pmin(a, b), pmax(a, b), sep = "|") == dec)]
  }
  d[, night := nt]
  cat(sprintf("NPC2 %s: %d seats with a shown pair, %d declared (y=1), %d wrong (y=0); median pair share right %.3f, wrong %.3f\n",
              nt, nrow(d), sum(d$y), sum(1 - d$y), median(d$pair_share[d$y == 1]), if (any(d$y == 0)) median(d$pair_share[d$y == 0]) else NA))
  rows[[nt]] <- d[, list(night, seat, a, b, pair_share, y, time)]
}
D <- rbindlist(rows)
D[, x := qlogis((pair_share * n + 0.5) / (n + 1))]
a0 <- qlogis(r)
nll <- function(th) { q <- plogis(th[1] + th[2] * D$x); q <- pmin(pmax(q, 1e-12), 1 - 1e-12)
  -sum(D$y * log(q) + (1 - D$y) * log(1 - q)) + (th[1] - a0)^2 / 2 + (th[2] - 1)^2 / (2 * 0.5^2) }
fit <- optim(c(a0, 1), nll, method = "BFGS")
if (fit$convergence != 0) stop("NPC3! optim did not converge (code ", fit$convergence, ")")
al <- fit$par[1]; be <- fit$par[2]
cat(sprintf("NPC3 pair_cal fitted on %s: alpha %.4f, beta %.4f (prior alpha %.4f = qlogis(r %.3f), beta 1); %d seats, %d wrong pairs\n",
            paste(nights, collapse = "+"), al, be, a0, r, nrow(D), sum(1 - D$y)))
for (p in c(0.001, 0.01, 0.1, 0.5, 0.9)) cat(sprintf("NPC3   p %.3f -> q %.3f (v1 rule %.3f)\n", p, plogis(al + be * qlogis(p)), plogis(a0 + qlogis(p))))
if (!is.null(out)) fwrite(data.table(fitted_on = paste(nights, collapse = "+"), r = r, alpha = al, beta = be, n_seats = nrow(D), n_wrong = sum(1 - D$y)),
                          out, append = file.exists(out))
cat(sprintf("PAIRCAL %.6f,%.6f\n", al, be))
