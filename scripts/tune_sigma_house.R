# Choose the house-effect prior by held-out error.
#
# sigma_house_pts is the prior sd on ONE pollster's house effect, where
# szc_sd_pts governs how far they may all sit from the truth together.
# Hand-set at 3 and never estimated.
#
# Grid, criterion and decision rule are fixed in
# docs/plans/prereg-sigma-house.md, committed BEFORE this ran. Do not edit them
# to fit a result.
#
# V5 is a live constraint here in a way it was not for szc: it requires
# max |house effect| < 5 and currently reads 3.98, and this prior pushes
# directly on it. A value that wins on held-out error but breaches V5 is
# rejected by rule 3 -- run scripts/run_all.R before adopting anything.
#
# Slow: refits the whole backtest once per grid value, ~1 min each.
#
# Run from repo root:
#   powershell.exe -Command 'Rscript "scripts/tune_sigma_house.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

res <- tune_prior("sigma_house_pts",
                  grid      = c(1, 2, 3, 5, 8),   # pre-registered
                  incumbent = 3,
                  material  = 0.02)
report_tuning(res, code = "G5")
