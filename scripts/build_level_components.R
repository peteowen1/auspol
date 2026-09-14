# Trend and fundamentals, kept SEPARATE -- the raw ingredients for a
# statewide primary-vote prediction, instead of `build_level_pred.R`'s single
# pre-blended `level_pred`.
#
# WHY. `build_level_pred.R` blends them with a hand-fitted weight `w(horizon)`
# from `R/projection.R`'s `projection_params()`. That weight is fitted on a
# grid starting at 30 days out and `approx(..., rule = 2)` CLAMPS rather than
# extrapolates -- so a forecast built "the day before polling day" (horizon =
# 1, every backtest's convention) uses the SAME weight as one built a month
# out. Found 2026-09-13 chasing nsw2023's 5.7-point statewide miss: the raw
# trend alone (35.4) was close to the actual result (37.0); the blend (31.3,
# 40% fundamentals at w=0.6) dragged it toward a badly wrong fundamentals
# figure (46.5 TPP, implying an ALP loss the fundamentals model got badly
# wrong). Sized across all 22 pairs: pure trend beats the current blend on
# average (MAE 2.14 vs 2.47) but not universally (fed2007/2010/2013/2019 are
# genuinely helped by some fundamentals weight) -- so neither "always trust
# trend" nor the current frozen blend is right.
#
# Pete's call, 2026-09-13: don't hand-fit a better w(horizon) curve -- expose
# BOTH raw components as separate features and let xgboost learn how much to
# trust each, conditioned on everything else it already knows about a seat
# (dev_prev, salience, MP status, ...), the same way ret_exp and sal_exp
# already work. This is a strict generalisation of the current blend: a tree
# CAN learn "trust_weight * trend + (1-trust_weight) * fund" for some
# trust_weight function of its other features, which the fixed global
# w(horizon) curve cannot express at all.
#
# fund_level is per-PARTY (fit_fundamentals(dat, party)), not the TPP-only
# fundamentals_loo_table() build_level_pred.R uses -- ALP/LNP/GRN/OTH all
# have their own fundamentals fit; ONP is thin (16 elections) but usable.
# Classes with no fundamentals fit (IND, OTH_RIGHT) fall back to OTH's LOO
# prediction, the same convention used elsewhere in this package for an
# unlisted minor party.
#
# NO LEAKAGE: trend is fitted as-at the day before polling day using only
# polls published by then (statewide_draws_as_at()); fundamentals is the
# LEAVE-ONE-OUT prediction (ridge_loo()'s hat-matrix LOO), so neither ever
# sees the election it is predicting.
#
# Emits LC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
CAND <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
st_of <- function(el) {
  d <- CAND[CAND$election == el, list(v = sum(votes, na.rm = TRUE)), by = party]
  if (!nrow(d)) return(NULL)
  stats::setNames(100 * d$v / sum(d$v), d$party)
}

# Same election-date and prior-pair tables as build_level_pred.R -- sourced
# from the harnesses' own conventions, not retyped, so the two files cannot
# silently disagree about which window "the day before polling day" means.
DATES <- c(
  fed2007 = "2007-11-24", fed2010 = "2010-08-21", fed2013 = "2013-09-07",
  fed2016 = "2016-07-02", fed2019 = "2019-05-18", fed2022 = "2022-05-21",
  fed2025 = "2025-05-03",
  nsw2019 = "2019-03-23", nsw2023 = "2023-03-25",
  qld2020 = "2020-10-31", qld2024 = "2024-10-26",
  sa2022  = "2022-03-19", sa2026 = "2026-03-21",
  vic2014 = "2014-11-29", vic2018 = "2018-11-24", vic2022 = "2022-11-26",
  wa2001  = "2001-02-10", wa2005 = "2005-02-26", wa2008 = "2008-09-06",
  wa2013  = "2013-03-09", wa2017 = "2017-03-11", wa2021 = "2021-03-13",
  wa2025  = "2025-03-08")
PREV <- c(
  fed2007 = "fed2004", fed2010 = "fed2007", fed2013 = "fed2010",
  fed2016 = "fed2013", fed2019 = "fed2016", fed2022 = "fed2019",
  fed2025 = "fed2022",
  nsw2019 = "nsw2015", nsw2023 = "nsw2019",
  qld2020 = "qld2017", qld2024 = "qld2020",
  sa2022  = "sa2018", sa2026 = "sa2022",
  vic2014 = "vic2010", vic2018 = "vic2014", vic2022 = "vic2018",
  wa2001  = "wa1996", wa2005 = "wa2001", wa2008 = "wa2005",
  wa2013  = "wa2008", wa2017 = "wa2013", wa2021 = "wa2017", wa2025 = "wa2021")
CLASSES <- c("ALP", "LNP", "GRN", "IND", "ONP", "OTH", "OTH_RIGHT")

# ---- fundamentals, per party, LOO -- fit ONCE, not once per pair ----------
FUND_DATA <- build_fundamentals_data()
FUND_PARTIES <- c("ALP", "LNP", "GRN", "ONP", "OTH")
fund_loo_by_party <- list()
for (p in FUND_PARTIES) {
  m <- tryCatch(fit_fundamentals(FUND_DATA, p), error = function(e) {
    cat(sprintf("LC0! fundamentals fit failed for %s: %s\n", p, conditionMessage(e))); NULL })
  if (!is.null(m)) {
    fund_loo_by_party[[p]] <- data.table(year = m$data$year, region = m$data$region,
                                         fund = m$data$actual - m$loo_errors)
    cat(sprintf("LC1  %s: %d elections, LOO MAE %.3f\n", p, nrow(m$data), m$loo_mae))
  }
}

rows <- list(); failed <- character(0)
for (pr in names(DATES)) {
  reg <- sub("[0-9]{4}$", "", pr); yr <- as.integer(sub("^[a-z]+", "", pr))
  ed <- as.Date(DATES[[pr]])
  FCt <- tryCatch(statewide_draws_as_at(reg, yr, as_at = ed - 1, election_date = ed,
                                        parties = CLASSES, n_sims = 2000L, seed = 42L,
                                        tpp_target = NULL),
                  error = function(e) { cat(sprintf("LC2! %s trend: %s\n", pr, conditionMessage(e))); NULL })
  if (is.null(FCt)) { failed <- c(failed, pr); next }
  trend_vals <- colMeans(FCt$draws)

  fund_oth <- if (!is.null(fund_loo_by_party[["OTH"]])) {
    r <- fund_loo_by_party[["OTH"]][region == reg & year == yr]$fund
    if (length(r)) r[1] else NA_real_
  } else NA_real_

  for (cls in CLASSES) {
    fv <- if (cls %in% names(fund_loo_by_party)) {
      r <- fund_loo_by_party[[cls]][region == reg & year == yr]$fund
      if (length(r)) r[1] else fund_oth
    } else fund_oth # IND, OTH_RIGHT: no dedicated fit, fall back to OTH's
    rows[[length(rows) + 1L]] <- data.table(
      pair = pr, party = cls,
      trend_level = unname(trend_vals[[cls]]),
      fund_level = fv)
  }
}
LC <- rbindlist(rows, fill = TRUE)

# A PAIR WHOSE TREND COULDN'T BE FIT falls back to the prior election's
# result for trend_level (the honest no-information forecast, same
# convention build_level_pred.R already uses), and to the fundamentals value
# alone where that exists.
for (pr in failed) {
  a <- st_of(PREV[[pr]])
  if (is.null(a)) next
  for (cls in CLASSES) {
    if (cls %in% names(a)) {
      LC <- rbind(LC, data.table(pair = pr, party = cls,
                                 trend_level = unname(a[[cls]]), fund_level = NA_real_),
                  fill = TRUE)
    }
  }
  cat(sprintf("LC2  %s: no usable trend -- trend_level falls back to %s's result\n", pr, PREV[[pr]]))
}
# SAY HOW MANY. This fallback makes fund_level an exact copy of trend_level,
# which is harder to spot downstream than an empty column -- a region/year
# label mismatch in the lookup above would silently collapse EVERY row this
# way and the file would still look well-formed. Print the count so a mass
# fallback is visible in the log rather than inferred later.
.n_fb <- sum(is.na(LC$fund_level))
cat(sprintf("LC3  %d of %d rows have no fundamentals fit -- fund_level falls back to trend_level (%.0f%%)\n",
            .n_fb, nrow(LC), 100 * .n_fb / nrow(LC)))
if (.n_fb == nrow(LC)) stop("every row fell back -- the fundamentals lookup matched nothing, check region/year labels")
LC[is.na(fund_level), fund_level := trend_level] # no fundamentals fit at all: trend is the only signal

cat(sprintf("\nLC9  %d rows, %d pairs, %d classes\n", nrow(LC), uniqueN(LC$pair), uniqueN(LC$party)))
fwrite(LC, file.path(OUT, "level-components.csv"))
cat(sprintf("LC9  wrote %s/level-components.csv\n", OUT))
