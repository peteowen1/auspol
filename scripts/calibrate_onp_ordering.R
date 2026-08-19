# ONP_ORDER_SD, per docs/plans/prereg-onp-ordering-uncertainty.md
#
# One Nation's seat shares are assigned by ranking seats on Greens share and
# quantile-mapping onto an observed spread. Scored against South Australia 2026
# that ranking correlates +0.779 with the truth -- so the ordering is roughly
# four-fifths right, and the model currently treats it as exactly right.
#
# This finds the noise on the ordering INDEX whose perturbed ranking correlates
# 0.779 with the central one. Not a grid and not tuned: the target is measured,
# and the sd is whatever reproduces it.
#
# Emits OO* codes.

suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)

TARGET <- 0.779    # measured on SA 2026 by scripts/calibrate_onp_seat_sd.R
TOL <- 0.005
ONP_B1 <- -0.0968
N_REP <- 400       # replicates per candidate sd
FLOOR_R <- 0.3     # refusal: below this the ordering carries no usable signal

PREF <- election_data_path()
fp <- fread(file.path(PREF, "vec-2022-vic-firstprefs.csv"))
w <- dcast(fp, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(w[, -1]); rownames(mat) <- w$seat
mat <- 100 * mat / rowSums(mat)
idx <- ONP_B1 * mat[, "GRN"]
n <- length(idx)
cat(sprintf("\nOO1  seats: %d;  ordering index sd = %.4f\n", n, stats::sd(idx)))

# Mean rank correlation between the perturbed ordering and the central one.
mean_rho <- function(sd_noise, reps = N_REP, seed = 11) {
  set.seed(seed)
  vapply(seq_len(reps), function(i) {
    stats::cor(rank(idx + stats::rnorm(n, 0, sd_noise)), rank(idx),
               method = "spearman")
  }, numeric(1))
}

# Bisect on the noise sd. rho falls monotonically as noise grows, so the bracket
# is [0, hi] with hi expanded until rho drops below the target.
lo <- 0
hi <- stats::sd(idx)
while (mean(mean_rho(hi)) > TARGET && hi < 1000 * stats::sd(idx)) hi <- hi * 2
cat(sprintf("OO2  bracket: rho(%.4f) = %.3f, rho(%.4f) = %.3f\n",
            lo, 1, hi, mean(mean_rho(hi))))

for (it in seq_len(60)) {
  mid <- (lo + hi) / 2
  r <- mean(mean_rho(mid))
  if (abs(r - TARGET) < TOL) break
  if (r > TARGET) lo <- mid else hi <- mid
}
SD <- mid
r_final <- mean(mean_rho(SD))
cat(sprintf("OO3  ONP_ORDER_SD = %.4f  ->  mean rank correlation %.3f (target %.3f)\n",
            SD, r_final, TARGET))

spread <- mean_rho(SD)
cat(sprintf("OO3  across %d replicates: %.3f to %.3f\n",
            N_REP, min(spread), max(spread)))

cat(sprintf("\nOO4  refusal check (correlation below %.2f means the ordering\n",
            FLOOR_R))
cat(sprintf("     carries no usable signal): %s\n",
            if (r_final < FLOOR_R) "REFUSE" else "ok"))
if (abs(r_final - TARGET) >= TOL) {
  cat("OO4  REFUSE: bisection did not reach the target within tolerance\n")
}

# What it does to the allocation, so the effect is visible before adoption.
sa <- fread(file.path(PREF, "ecsa-2026-sa-onp-shares.csv"), showProgress = FALSE)
sa_ratio <- sort(sa$pct / mean(sa$pct))
map_to <- function(index) {
  ord <- order(index)
  out <- numeric(n); names(out) <- names(index)
  for (r in seq_along(ord)) {
    q <- (r - 1) / (length(ord) - 1)
    pos <- q * (length(sa_ratio) - 1)
    l <- floor(pos) + 1; h <- min(l + 1, length(sa_ratio))
    out[names(index)[ord[r]]] <- sa_ratio[l] + (pos - (l - 1)) * (sa_ratio[h] - sa_ratio[l])
  }
  out
}
central <- map_to(idx)
set.seed(99)
draws <- replicate(200, map_to(idx + stats::rnorm(n, 0, SD)))
# UNNAMED. sort() keeps names, and the whole point is that the same values land
# on DIFFERENT seats -- so comparing named vectors reports FALSE for a design
# working exactly as intended. Compare the values.
same <- vapply(seq_len(ncol(draws)), function(j)
  isTRUE(all.equal(unname(sort(draws[, j])), unname(sort(central)))), logical(1))
cat(sprintf("\nOO5  multiset of ratios identical in %d of %d draws: %s\n",
            sum(same), length(same), if (all(same)) "yes" else "NO -- design broken"))
cat(sprintf("OO5  statewide mean ratio: central %.6f, draws %.6f to %.6f\n",
            mean(central), min(colMeans(draws)), max(colMeans(draws))))
per_seat <- data.table(seat = names(central), central = round(central, 3),
                       sd = round(apply(draws, 1, stats::sd), 3))
cat("OO5  per-seat ratio spread introduced (top 6 and bottom 3):\n")
print(rbind(head(per_seat[order(-sd)], 6), tail(per_seat[order(-sd)], 3)))

fwrite(data.table(onp_order_sd = SD, rho = r_final, target = TARGET),
       file.path("output", "onp-ordering-calibration.csv"))
cat(sprintf("\nWrote output/onp-ordering-calibration.csv (ONP_ORDER_SD = %.4f)\n", SD))
