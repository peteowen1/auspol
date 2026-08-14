# NSW poll trends: 2023 (validation) and 2027 (the live forecast cycle).
# NSW uses optional preferential voting, so TPP accounts for exhausted
# preferences via the flow file's exhaust rates.
#
# Pre-registered anchor checks (chosen before fitting):
#   N1: 2023 cycle endpoint ALP TPP in [51.5, 57]  (actual result 54.3)
#   N2: 2023 cycle endpoint ALP FP in [33, 40]     (actual 37.0)
#   N3: max |house effect| < 5 for firms with >= 5 polls (2027 cycle)
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_nsw.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

dir.create("output", showWarnings = FALSE)

polls <- load_polls("nsw")
cycles <- load_election_cycles()
priors_all <- load_prior_results()
flows_all <- load_preference_flows()

fit_cycle <- function(year) {
  cp <- cycle_polls(polls, year, cycles)
  message(sprintf("\n=== NSW %d cycle: %d polls, %s to %s ===",
                  year, nrow(cp), min(cp$date), max(cp$date)))
  keep <- priors_all$year == year & priors_all$region == "nsw"
  pr <- priors_all[which(keep), ]
  priors <- setNames(pr$prev1, pr$party)
  # State polling is thin - accept parties with >= 8 polls in the cycle.
  # ONP gets a faster random walk (populist volatility - its 2025-26 rise
  # from ~2% to ~25% is real movement the default walk would suppress).
  counts <- vapply(attr(cp, "parties"), function(p) sum(!is.na(cp[[p]])), 1L)
  fits <- fit_cycle_trends(
    cp, parties = names(counts)[counts >= 8], priors = priors,
    overrides = list(ONP = list(sigma_rw = 0.25))
  )
  fkeep <- flows_all$year == year & flows_all$region == "nsw"
  tpp <- derive_tpp(fits, flows_all[which(fkeep), ])
  list(polls = cp, fits = fits, tpp = tpp)
}

res2023 <- fit_cycle(2023)
res2027 <- fit_cycle(2027)

end_val <- function(trend) trend$mean[which.max(trend$date)]

n1 <- end_val(res2023$tpp)
n2 <- end_val(res2023$fits$ALP$trend)
he27 <- rbindlist(lapply(names(res2027$fits), function(p)
  data.table(party = p, res2027$fits[[p]]$house_effects)))
n3 <- he27[n_polls >= 5, max(abs(effect))]

cat(sprintf("
ANCHOR CHECKS (NSW)
N1  2023 endpoint ALP TPP = %.2f  (require 51.5-57; actual 54.3)
N2  2023 endpoint ALP FP  = %.2f  (require 33-40; actual 37.0)
N3  max |house effect| 2027 cycle (>=5 polls) = %.2f  (require < 5)
", n1, n2, n3))
stopifnot(n1 >= 51.5, n1 <= 57, n2 >= 33, n2 <= 40, n3 < 5)
cat("All NSW anchor checks passed.\n\n")

cat("=== NSW 2027 cycle trend endpoints ===\n")
for (p in names(res2027$fits)) {
  tr <- res2027$fits[[p]]$trend
  cat(sprintf("%-4s FP: %5.1f  (95%%: %.1f-%.1f)\n",
              p, end_val(tr), tr$lo95[which.max(tr$date)], tr$hi95[which.max(tr$date)]))
}
cat(sprintf("ALP TPP: %5.1f (95%%: %.1f-%.1f)   [exhaust-adjusted]\n",
            end_val(res2027$tpp),
            res2027$tpp$lo95[which.max(res2027$tpp$date)],
            res2027$tpp$hi95[which.max(res2027$tpp$date)]))

for (yr in c(2023, 2027)) {
  res <- get(paste0("res", yr))
  all_tr <- rbindlist(lapply(names(res$fits), function(p)
    data.table(party = p, res$fits[[p]]$trend)))
  all_tr <- rbind(all_tr, data.table(party = "TPP_ALP", res$tpp))
  fwrite(all_tr, sprintf("output/trend-nsw-%d.csv", yr))
  p <- plot_trends(res$fits, res$polls, tpp = res$tpp,
                   title = sprintf("NSW %d cycle - poll trend (auspol skeleton)", yr))
  ggplot2::ggsave(sprintf("output/trend-nsw-%d.png", yr), p,
                  width = 11, height = 6.5, dpi = 130)
}
cat("\nWrote output/trend-nsw-{2023,2027}.{csv,png}\n")
