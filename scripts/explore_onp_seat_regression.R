# What predicts One Nation's primary vote in a seat? (Pete, 10 Nov 2026)
#
# Exploratory, read-only: writes nothing, changes no model. Run from the repo root (open auspol.Rproj in RStudio,
# then source this file), or: Rscript scripts/explore_onp_seat_regression.R
#
# Question: the live forecast orders seats by the 2025 Senate One Nation vote and gives them South Australia 2026's
# spread (AUSPOL_ONP_ORDER = "senate_rank"). Would demographics and the previous Greens / minor-right vote predict a
# seat's One Nation primary better than the Senate vote alone?
#
# Inputs (all already on disk):
#   output/onp-senate-district-panel.csv  one row per seat-election: actual One Nation primary %, Senate One Nation %
#                                         in the seat's booths, statewide One Nation level L (sa2026, qld2017/20/24, nsw2023)
#   output/census-features.csv            census by seat (sa2026 uses census 2016 re-cut to 2026 boundaries)
#   output/published-predictions.csv      per seat and party: our published forecast and the previous election's share
#
# Census has no ethnicity question, so "non-white" is proxied by born overseas (100 - born_aus_pct) and by speaking a
# language other than English at home (lang_other_pct). "Young" is under35_pct; "educated" is yr12_pct (finished
# Year 12) and edu_25plus_pct (the census file's degree-type column).
#
# Every fit is scored out of sample. Within one election, leave-one-seat-out. Pooled across elections,
# leave-one-ELECTION-out, the honest test for a new election. Lower RMSE is better. n is printed with every number.

suppressPackageStartupMessages(library(data.table))

panel <- fread("output/onp-senate-district-panel.csv")
cens  <- fread("output/census-features.csv")
pub   <- fread("output/published-predictions.csv")

cat(sprintf("panel: %d seat-elections (%s)\n", nrow(panel),
            paste(sprintf("%s %d", names(table(panel$el)), table(panel$el)), collapse = ", ")))

# ---- join -------------------------------------------------------------------------------------------------------
cens[, k := tolower(seat)]
cens_k <- cens[, .(el = pair, k, yr12_pct, edu_25plus_pct, under35_pct, over55_pct, born_os_pct = 100 - born_aus_pct,
                   lang_other_pct, indig_pct)]
pub[, k := tolower(seat)]
prev <- dcast(pub[party %in% c("GRN", "OTH_RIGHT", "ONP")], pair + k ~ party, value.var = "prev_share", fun.aggregate = sum)
setnames(prev, c("pair", "GRN", "OTH_RIGHT", "ONP"), c("el", "prev_grn", "prev_othright", "prev_onp"), skip_absent = TRUE)
ours <- pub[party == "ONP", .(el = pair, k, ours_onp = ours)]

d <- merge(panel, cens_k, by = c("el", "k"), all.x = TRUE)
d <- merge(d, prev, by = c("el", "k"), all.x = TRUE)
d <- merge(d, ours, by = c("el", "k"), all.x = TRUE)
for (v in c("prev_grn", "prev_othright", "prev_onp")) if (v %in% names(d)) d[is.na(get(v)), (v) := 0]

# Coverage, so a join that silently missed is visible (a column 0% populated is the classic way this goes wrong).
cov <- d[, lapply(.SD, function(x) round(100 * mean(is.finite(x)))), by = el,
         .SDcols = c("actual", "senate", "yr12_pct", "under35_pct", "born_os_pct", "prev_grn", "ours_onp")]
cat("\ncoverage, % of seats with the value (100 = every seat):\n"); print(cov)

# ---- specifications --------------------------------------------------------------------------------------------
# Everything is in points of One Nation primary. The statewide level L enters so a pooled fit can scale across
# elections; within one election it is a constant and drops out.
# L is the ACTUAL statewide One Nation level and Ls the statewide Senate One Nation %, so every fit here is handed the
# true level of the election it predicts: these RMSEs measure how well each input SPREADS the vote across seats, not
# how well anything forecasts the level. "sen_rel" = L * senate / Ls is the Senate share rescaled to the state level,
# the closest linear stand-in for what the live forecast does with the Senate vote.
d[, sen_rel := L * senate / Ls]
specs <- list(
  "0 Senate rescaled (L x senate/Ls)" = actual ~ sen_rel,
  "0b + demographics, votes"       = actual ~ sen_rel + under35_pct + yr12_pct + born_os_pct + prev_grn + prev_othright,
  "1 Senate only"                 = actual ~ senate,
  "2 Senate x level"              = actual ~ senate + L + I(senate * L),
  "3 + demographics"              = actual ~ senate + L + I(senate * L) + under35_pct + yr12_pct + born_os_pct,
  "4 + previous Greens, minor right" = actual ~ senate + L + I(senate * L) + under35_pct + yr12_pct + born_os_pct + prev_grn + prev_othright,
  "5 demographics + votes, no Senate" = actual ~ L + under35_pct + yr12_pct + born_os_pct + prev_grn + prev_othright
)
rmse <- function(e) sqrt(mean(e^2))
ALLV <- unique(unlist(lapply(specs, all.vars)))
cat(sprintf("\nseats with every input: %d of %d (census is missing for the rest; every RMSE below uses only these)\n",
            sum(complete.cases(d[, ..ALLV])), nrow(d)))

loo_seat <- function(f, dd) {
  e <- vapply(seq_len(nrow(dd)), function(i) {
    m <- lm(f, data = dd[-i]); dd$actual[i] - predict(m, newdata = dd[i])
  }, numeric(1))
  rmse(e)
}
loo_election <- function(f, dd) {
  els <- unique(dd$el)
  e <- unlist(lapply(els, function(x) {
    tr <- dd[dd$el != x]; te <- dd[dd$el == x]
    te$actual - predict(lm(f, data = tr), newdata = te)
  }))
  rmse(e)
}
vars_of <- function(f) all.vars(f)

# ---- 1. South Australia 2026 alone (the election whose spread the live forecast borrows) -------------------------
sa <- d[el == "sa2026"]
cat(sprintf("\n=== sa2026 alone: %d seats, leave-one-seat-out RMSE (points of One Nation primary; lower is better) ===\n", nrow(sa)))
for (nm in names(specs)) {
  f <- specs[[nm]]; vv <- setdiff(vars_of(f), c("L"))
  ok <- complete.cases(sa[, ..ALLV])   # the SAME seats for every spec, so the RMSEs are comparable
  ff <- update(f, . ~ . - L - I(senate * L))   # L is constant within one election
  if (nm == "5 demographics + votes, no Senate") ff <- update(f, . ~ . - L)
  cat(sprintf("  %-36s n %2d  RMSE %.2f\n", nm, sum(ok), loo_seat(ff, sa[ok])))
}
if (any(is.finite(sa$ours_onp)))
  { oe <- (sa$actual - sa$ours_onp)[is.finite(sa$ours_onp)]
    cat(sprintf("  %-36s n %2d  RMSE %.2f   (our published forecast: it had to predict the level too)\n", "ours (published)", length(oe), rmse(oe)))
    cat(sprintf("  %-36s n %2d  RMSE %.2f   (same, its average miss removed: the fair comparison with the fits above)\n",
                "ours, level miss removed", length(oe), rmse(oe - mean(oe)))) }
full <- lm(actual ~ senate + under35_pct + yr12_pct + born_os_pct + prev_grn + prev_othright, data = sa)
cat("\nsa2026 full fit, in-sample (coefficients: points of One Nation per point of each input):\n"); print(summary(full)$coefficients, digits = 3)

# ---- 2. Pooled across every election in the panel, leave-one-election-out ---------------------------------------
cat(sprintf("\n=== pooled, %d elections, leave-one-ELECTION-out RMSE (points; lower is better) ===\n", uniqueN(d$el)))
for (nm in names(specs)) {
  f <- specs[[nm]]; vv <- vars_of(f)
  ok <- complete.cases(d[, ..ALLV])
  cat(sprintf("  %-36s n %3d in %d elections  RMSE %.2f\n", nm, sum(ok), uniqueN(d$el[ok]), loo_election(f, d[ok])))
}
pooled <- lm(specs[["4 + previous Greens, minor right"]], data = d)
cat("\npooled spec 4, in-sample coefficients:\n"); print(summary(pooled)$coefficients, digits = 3)

cat("\nRead: compare each spec with spec 0 (the Senate vote rescaled to the state level, closest to what ships). The pooled leave-one-ELECTION-out block is the test that matters for a new election such as vic2026. In-sample",
    "coefficients are for direction only; the RMSEs above are the test.\n")
