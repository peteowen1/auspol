# ONE ROW, END TO END: the nsw2023 day-before statewide forecast.
options(auspol.root = normalizePath("C:/dev/auspol"), width = 160)
suppressMessages({ library(data.table); devtools::load_all("C:/dev/auspol", quiet = TRUE) })
region <- "nsw"; year <- 2023L
ed <- as.Date(election_dates()[["nsw2023"]]); as_at <- ed - 1
cat("W0  election", as.character(ed), " forecast as at", as.character(as_at), "\n\n")

# 1. THE POLLS THE TREND SAW: last 60 days
polls <- load_polls(region); cycles <- load_election_cycles()
cp <- cycle_polls(polls, year, cycles)
cp <- cp[date <= as_at]
cat("W1  polls in the cycle on or before the cutoff:", nrow(cp), " (first", as.character(min(cp$date)), ")\n")
cat("W1  last 60 days (MidDate, firm, published TPP for Labor, first preferences):\n")
print(cp[date >= as_at - 60, c("date", "firm", "tpp_published", intersect(c("ALP", "LNP", "GRN", "ONP", "OTH"), names(cp))), with = FALSE][order(date)])

# 2. THE TREND at the cutoff, per party
fund <- fundamentals_loo_table(); mix <- fread(file.path(pkg_root(), "output/projection-mix.csv"))
parties <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH", "OTH_RIGHT")
pri <- load_prior_results(); kp <- pri$region == region & pri$year == year
priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
cat("\nW2  prior election (2019) first preferences the trend is anchored to:\n"); print(round(priors, 1))
fl <- flows_for(load_preference_flows(), year, region, as_of = min(cycles[cycles$region == region & cycles$year == year, ]$start), cycles = cycles, quiet = TRUE)
tr <- trend_as_at(polls, year, cycles, as_at, priors, fl, with_series = TRUE)
s <- as.data.table(tr$series); last <- s[date == max(date)]
cat("W2  trend at", as.character(max(s$date)), ": per-party level (mean, 95% band)\n")
print(last[, .(party, mean = round(mean, 1), lo95 = round(lo95, 1), hi95 = round(hi95, 1))])
cat("W2  trend two-party (Labor):", round(tr$tpp, 2), "  from", tr$n_polls, "polls\n")
# how the trend moved over the last 8 weeks
wk <- s[party == "ALP" & date >= as_at - 56 & (as.integer(as_at - date) %% 7 == 0), .(date, alp_trend = round(mean, 1))]
cat("W2  Labor first-preference trend, weekly, last 8 weeks:\n"); print(wk)

# 3. THE FUNDAMENTALS: the row and each feature's contribution
m <- fit_fundamentals(build_fundamentals_data(), "@TPP")
row <- m$data[year == 2023 & region == "nsw"]
cat("\nW3  fundamentals row (nsw2023, Labor two-party):\n"); print(row)
X <- as.matrix(row[, m$features, with = FALSE])
z <- (X - m$centre[m$features]) / m$scale[m$features]
contrib <- as.numeric(z) * m$beta
cat("W3  ridge fit: n =", m$n, " lambda =", signif(m$lambda, 3), " intercept (mean actual) =", round(m$intercept, 2), "\n")
cat("W3  contribution of each feature (standardised value x beta), points of Labor two-party:\n")
print(data.table(feature = m$features, value = as.numeric(X), z = round(as.numeric(z), 2), beta = round(m$beta, 2), points = round(contrib, 2)))
fr <- fund[year == 2023 & region == "nsw"]$fund
cat("W3  fundamentals prediction (leave-one-out) =", round(fr, 2), "  in-sample would be", round(m$intercept + sum(contrib), 2), "\n")
# the comparable rows: long incumbencies in the corpus
cat("W3  every state election in the corpus where the government had 8+ years (govt_years is Labor's; opp_years the Coalition's):\n")
print(m$data[region != "fed" & (govt_years >= 8 | opp_years >= 8), .(year, region, prev1, actual, swing = round(actual - prev1, 1), govt_years, opp_years)][order(region, year)])

# 4. THE MIX at horizon 1
pj <- project_result(tr$tpp, fr, mix, horizon = 1L)
cat("\nW4  mix at 1 day: w(trend) =", round(pj$w, 3), " -> projection", round(pj$mean, 2), " sd", round(pj$sd, 2), "\n")

# 5. THE ANCHORED FORECAST vs the count
CAND <- fread(file.path(pkg_root(), "output/candidacies.csv"))[is.finite(votes)]
act <- CAND[election == "nsw2023", .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
st_a <- CAND[election == "nsw2019", .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
fc <- forecast_statewide_for(region, year, ed, union(names(act), parties), st_a, fund, mix, n_sims = 20000, seed = 42)
cat("\nW5  forecast vs actual first preferences (points):\n")
cls <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH_RIGHT", "OTH")
print(data.table(class = cls, trend = round(sapply(cls, function(p) if (p %in% last$party) last[party == p]$mean else NA), 1),
                 forecast = round(fc$st_fc[cls], 1), actual = round(act[cls], 1), miss = round(fc$st_fc[cls] - act[cls], 1)))
cat("W5  two-party: trend", round(fc$tpp, 2), " fundamentals", round(fc$fund, 2), " anchor", round(fc$anchor_mean, 2), " draws realise", round(fc$implied_tpp, 2), " actual 54.3\n")
