options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
set.seed(11)

# Ngadjuri, our projected primaries, and the per-seat spread the SA harness uses
v0   <- c(ONP = 31.3, LNP = 29.7, ALP = 23.1, GRN = 1.3)
v0   <- 100 * v0 / sum(v0)
SD   <- 3.333          # sp$sd_within in backtest_candidate_sa.R
N    <- 20000
ACT  <- c(ONP = 34.9, ALP = 29.5, LNP = 25.3, GRN = 4.7)
ACT  <- 100 * ACT / sum(ACT)

cat("=== THREE-PARTY PRIMARIES: ours (central) vs actual ===\n")
cat(sprintf("        %8s %8s %8s\n", "ONP", "LNP", "ALP"))
cat(sprintf("ours    %8.1f %8.1f %8.1f\n", v0["ONP"], v0["LNP"], v0["ALP"]))
cat(sprintf("actual  %8.1f %8.1f %8.1f\n", ACT["ONP"], ACT["LNP"], ACT["ALP"]))
cat(sprintf("error   %+8.1f %+8.1f %+8.1f\n",
            v0["ONP"]-ACT["ONP"], v0["LNP"]-ACT["LNP"], v0["ALP"]-ACT["ALP"]))

cat(sprintf("\nour LNP-minus-ALP gap: %+.1f    actual: %+.1f    error: %+.1f points\n",
            v0["LNP"]-v0["ALP"], ACT["LNP"]-ACT["ALP"],
            (v0["LNP"]-v0["ALP"])-(ACT["LNP"]-ACT["ALP"])))

# simulate the primaries with the model's own per-seat noise
P <- c("ONP","LNP","ALP")
draws <- sapply(P, function(p) pmax(0, v0[[p]] + rnorm(N, 0, SD)))
third <- P[apply(draws[, P], 1, which.min)]
cat(sprintf("\n=== WHO FINISHES THIRD, across %d draws (seat_sd = %.2f) ===\n", N, SD))
tb <- table(third)
for (p in P) {
  n <- if (p %in% names(tb)) tb[[p]] else 0
  cat(sprintf("  %-4s third in %6.2f%% of draws\n", p, 100*n/N))
}
cat("\nreality: LNP finished third, and its preferences went 72.4% to ONP.\n")

cat("\n=== HOW BIG A GAP ARE WE ASKING THE NOISE TO CROSS? ===\n")
g <- unname(v0["LNP"] - v0["ALP"])
cat(sprintf("  our central LNP-ALP gap    : %+.1f points\n", g))
cat(sprintf("  per-seat sd                : %.2f points\n", SD))
cat(sprintf("  gap in sd units            : %.2f\n", g/SD))
cat(sprintf("  implied P(LNP third)       : %.2f%%\n", 100*pnorm(-g/(SD*sqrt(2)))))
cat("  (sqrt(2) because BOTH parties carry independent noise)\n")

cat("\n=== WHAT SEAT_SD WOULD BE NEEDED FOR LNP TO BE THIRD 40% OF THE TIME? ===\n")
for (target in c(0.20, 0.30, 0.40)) {
  need <- g / (qnorm(1-target) * sqrt(2))
  cat(sprintf("  P(LNP third) = %2.0f%%  needs seat_sd = %.2f  (we use %.2f)\n",
              100*target, need, SD))
}
