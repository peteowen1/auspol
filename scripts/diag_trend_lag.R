# Why does the day-before trend lag the late polls? (2026-10-12, docs/reviews/poll-weighting-inventory-2026-10-12.md)
# Per election and class: trend end, raw 28-day poll mean, the trend re-centred on the house effects of the firms
# that polled in the last 28 days, and the actual. Run: Rscript scripts/diag_trend_lag.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
cycles <- load_election_cycles(); pri <- load_prior_results(); eds <- election_dates()
C <- fread(out_path("candidacies.csv"), select = c("election","party","votes"))
act <- function(e, k) { x <- C[C$election == e & is.finite(C$votes), .(v = sum(votes)), by = party]; 100 * sum(x$v[x$party %in% k]) / sum(x$v) }
res <- list()
for (e in c("vic2018","vic2022","nsw2019","nsw2023","qld2020","qld2024","sa2022","sa2026","wa2021","wa2025","fed2019","fed2022","fed2025")) {
  region <- sub("[0-9]{4}$","",e); year <- as.integer(sub("^[a-z]+","",e)); ed <- as.Date(eds[[e]])
  polls <- suppressMessages(load_polls(region)); kp <- pri$region == region & pri$year == year
  priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
  fl <- tryCatch(flows_for(load_preference_flows(), year, region, as_of = min(cycles$start[cycles$region==region & cycles$year==year]), cycles = cycles, quiet = TRUE), error=function(z) NULL)
  tr <- tryCatch(suppressMessages(trend_as_at(polls, year, cycles, ed - 1, priors, fl, with_series = TRUE)), error = function(z) NULL)
  if (is.null(tr)) { cat(e, "no trend\n"); next }
  for (k in intersect(c("ALP","LNP","GRN"), names(tr$fits))) {
    f <- tr$fits[[k]]; T <- f$trend; he <- f$house_effects; rs <- f$residuals
    rec <- rs[rs$date >= ed - 28]
    hp <- setNames(he$effect_pts, he$firm)
    rf <- ifelse(rec$firm %in% names(hp), rec$firm, "(other firms)")
    raw <- polls[polls$date < ed & polls$date >= ed - 28][[k]]
    res[[length(res)+1]] <- data.table(e, k, trend = tail(T$mean, 1), raw28 = mean(raw, na.rm = TRUE),
      firm_ctr = tail(T$mean, 1) + mean(unique(hp[rf])), poll_ctr = tail(T$mean, 1) + mean(hp[rf]),
      actual = act(e, if (k == "LNP") c("LNP","NAT","LIB") else k), n28 = nrow(rec))
  }
}
R <- rbindlist(res); R <- R[is.finite(actual) & actual > 0]
print(R[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 1) else x)])
r <- function(x) sqrt(mean((x - R$actual)^2, na.rm = TRUE))
cat(sprintf("
RMSE vs actual over %d cells: trend %.2f | raw 28-day mean %.2f | trend + mean house effect of late firms (each firm once) %.2f | (each late poll) %.2f
",
  nrow(R), r(R$trend), r(R$raw28), r(R$firm_ctr), r(R$poll_ctr)))
