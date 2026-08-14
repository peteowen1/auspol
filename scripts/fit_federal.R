# Fit federal poll trends for the 2022, 2025 and 2028 cycles and run the
# pre-registered anchor checks (see docs/ANCHOR-MODEL.md and session notes).
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_federal.R"'
# (arrow/parquet must not run under Git Bash R - segfaults.)

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

dir.create("output", showWarnings = FALSE)

polls <- load_polls("fed")
cycles <- load_election_cycles()
priors_all <- load_prior_results()
flows_all <- load_preference_flows()

fit_cycle <- function(year) {
  cp <- cycle_polls(polls, year, cycles)
  message(sprintf("\n=== %d cycle: %d polls, %s to %s ===",
                  year, nrow(cp), min(cp$date), max(cp$date)))
  pr <- priors_all[priors_all$year == year & priors_all$region == "fed", ]
  priors <- setNames(pr$prev1, pr$party)
  fits <- fit_cycle_trends(cp, priors = priors)
  flows <- flows_all[flows_all$year == year & flows_all$region == "fed", ]
  tpp <- derive_tpp(fits, flows)
  list(polls = cp, fits = fits, tpp = tpp)
}

res2022 <- fit_cycle(2022)
res2025 <- fit_cycle(2025)
res2028 <- fit_cycle(2028)

end_val <- function(trend) trend$mean[which.max(trend$date)]

# ---- Pre-registered anchor checks (chosen before fitting) ----
a1 <- end_val(res2022$tpp)
a2_tpp <- end_val(res2025$tpp)
a2_fp <- end_val(res2025$fits$ALP$trend)
he <- rbindlist(lapply(names(res2022$fits), function(p)
  data.table(party = p, res2022$fits[[p]]$house_effects)))
he_big <- he[n_polls >= 5]
a3_max <- he_big[, max(abs(effect))]
a3_sum <- he[, sum(effect * n_polls) / sum(n_polls), by = party][, max(abs(V1))]
tr22 <- res2022$tpp
a4_rise <- tr22$mean[match(as.Date("2022-05-01"), tr22$date)] -
  tr22$mean[match(as.Date("2021-06-01"), tr22$date)]

cat(sprintf("
ANCHOR CHECKS
A1  2022 endpoint ALP TPP = %.2f   (require 51-56; actual result 52.13, final polls ~53)
A2  2025 endpoint ALP TPP = %.2f   (require 51-56; actual 55.2, polls underestimated ALP)
A2b 2025 endpoint ALP FP  = %.2f   (require 30-36; actual 34.6)
A3  max |house effect| (firms w/ >=5 polls, 2022) = %.2f  (require < 5)
A3b max |weighted mean house effect| per party    = %.2f  (require < 1, soft sum-to-zero)
A4  ALP TPP trend 2021-06-01 -> 2022-05-01 rise   = %+.2f (require > 0, Morrison decline)
", a1, a2_tpp, a2_fp, a3_max, a3_sum, a4_rise))

stopifnot(
  a1 >= 51, a1 <= 56,
  a2_tpp >= 51, a2_tpp <= 56,
  a2_fp >= 30, a2_fp <= 36,
  a3_max < 5,
  a3_sum < 1,
  a4_rise > 0
)
cat("All anchor checks passed.\n\n")

# ---- Current cycle summary ----
cat("=== Current (2028) cycle trend endpoints ===\n")
for (p in names(res2028$fits)) {
  tr <- res2028$fits[[p]]$trend
  cat(sprintf("%-4s FP: %5.1f  (95%%: %.1f-%.1f)\n",
              p, end_val(tr), tr$lo95[which.max(tr$date)], tr$hi95[which.max(tr$date)]))
}
cat(sprintf("ALP TPP: %5.1f (95%%: %.1f-%.1f)\n",
            end_val(res2028$tpp),
            res2028$tpp$lo95[which.max(res2028$tpp$date)],
            res2028$tpp$hi95[which.max(res2028$tpp$date)]))

cat("\n=== 2028 cycle house effects (ALP FP) ===\n")
print(res2028$fits$ALP$house_effects[order(-abs(effect))])

# ---- Outputs ----
for (yr in c(2022, 2025, 2028)) {
  res <- get(paste0("res", yr))
  all_tr <- rbindlist(lapply(names(res$fits), function(p)
    data.table(party = p, res$fits[[p]]$trend)))
  all_tr <- rbind(all_tr, data.table(party = "TPP_ALP", res$tpp))
  fwrite(all_tr, sprintf("output/trend-fed-%d.csv", yr))
  p <- plot_trends(res$fits, res$polls, tpp = res$tpp,
                   title = sprintf("Federal %d cycle - poll trend (auspol skeleton)", yr))
  ggplot2::ggsave(sprintf("output/trend-fed-%d.png", yr), p,
                  width = 11, height = 6.5, dpi = 130)
}
cat("\nWrote output/trend-fed-{2022,2025,2028}.{csv,png}\n")
