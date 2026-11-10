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

# ---- 3. The strongest version: gradient-boosted trees, every census column, leave-one-ELECTION-out ----------------
# Target is the seat's One Nation vote RELATIVE to the statewide level (actual / L), and the Senate input is relative
# too (senate / Ls). Raw L and Ls are left out on purpose: they are constant within an election, so a tree would use
# them as a label for which election a row came from (CLAUDE.md, "a column constant within a subgroup").
# The prediction in points is then (predicted ratio) x L. Rounds are chosen inside each training set by xgb.cv with
# one fold per training election and early stopping, so the held-out election never picks its own settings.
# xgboost handles missing census, so this block uses all 308 seats as well as the 264 with every input.
suppressPackageStartupMessages(library(xgboost))
d[, `:=`(r = actual / L, sen_r = senate / Ls)]
feat_all <- c("sen_r", "yr12_pct", "edu_25plus_pct", "under35_pct", "over55_pct", "born_os_pct", "lang_other_pct",
              "indig_pct", "prev_grn", "prev_othright", "prev_onp")
pars <- list(objective = "reg:squarederror", max_depth = 3, eta = 0.03, min_child_weight = 5, subsample = 0.8,
             colsample_bynode = 0.8, nthread = 2, seed = 42)
xgb_loeo <- function(dd, feats) {
  out <- numeric(nrow(dd)); els <- unique(dd$el); rounds <- integer(0)
  for (x in els) {
    tr <- which(dd$el != x); te <- which(dd$el == x)
    dtr <- xgb.DMatrix(as.matrix(dd[tr, ..feats]), label = dd$r[tr])
    tr_el <- dd$el[tr]
    folds <- lapply(unique(tr_el), function(e) which(tr_el == e))
    cv <- xgb.cv(params = pars, data = dtr, nrounds = 2000, folds = folds, early_stopping_rounds = 50, verbose = 0)
    nr <- cv$early_stop$best_iteration; rounds <- c(rounds, nr)
    m <- xgb.train(params = pars, data = dtr, nrounds = nr, verbose = 0)
    out[te] <- predict(m, xgb.DMatrix(as.matrix(dd[te, ..feats]))) * dd$L[te]
  }
  list(pred = out, rounds = rounds)
}
lin_loeo <- function(dd, f) {
  out <- numeric(nrow(dd))
  for (x in unique(dd$el)) { tr <- dd$el != x; out[!tr] <- predict(lm(f, data = dd[tr]), newdata = dd[!tr]) * dd$L[!tr] }
  out
}
set.seed(42)
cat("\n=== gradient-boosted trees vs linear, leave-one-ELECTION-out RMSE (points of One Nation primary; lower is better) ===\n")
for (subset in c("all seats", "seats with every census input")) {
  dd <- if (subset == "all seats") copy(d) else d[complete.cases(d[, ..feat_all])]
  lin <- lin_loeo(dd, r ~ sen_r)
  xs  <- xgb_loeo(dd, "sen_r")
  xa  <- xgb_loeo(dd, feat_all)
  cat(sprintf("\n  %s: n %d seat-elections in %d elections\n", subset, nrow(dd), uniqueN(dd$el)))
  cat(sprintf("    %-44s RMSE %.2f\n", "linear, Senate only (ratio form)", rmse(dd$actual - lin)))
  cat(sprintf("    %-44s RMSE %.2f   (rounds per held-out election: %s)\n", "trees, Senate only",
              rmse(dd$actual - xs$pred), paste(xs$rounds, collapse = " ")))
  cat(sprintf("    %-44s RMSE %.2f   (rounds: %s)\n", sprintf("trees, all %d inputs", length(feat_all)),
              rmse(dd$actual - xa$pred), paste(xa$rounds, collapse = " ")))
  per <- dd[, .(n = .N, lin = rmse(actual - lin[.I]), trees_all = rmse(actual - xa$pred[.I])), by = el]
  cat("    per held-out election (RMSE, points):\n"); print(per[, .(el, n, lin = round(lin, 2), trees_all = round(trees_all, 2))])
}
dfull <- copy(d)
mfull <- xgb.train(params = pars, data = xgb.DMatrix(as.matrix(dfull[, ..feat_all]), label = dfull$r), nrounds = 300, verbose = 0)
imp <- xgb.importance(model = mfull)
cat("\nfeature importance, trees on all 308 rows, 300 rounds (gain share; descriptive only, not a test):\n")
print(imp[, .(Feature, gain = round(Gain, 3))])

# ---- 4. Surge elections only: qld2017 <-> sa2026, then what Victoria 2026 would get ------------------------------
# Victoria is a One Nation surge (statewide 21.5 in the live forecast). The two past surges in the panel are qld2017
# (L 20.8) and sa2026 (L 22.5). Each is predicted from a model fitted on the other alone, so n is 61 or 47 rows per fit:
# trees are fragile at that size, so a ridge regression (shrunk toward zero, penalty chosen by 10-fold CV inside the
# training election) is the main contender, beside plain Senate-only.
suppressPackageStartupMessages(library(glmnet))
surge <- c("qld2017", "sa2026")
feat_lin <- c("sen_r", "yr12_pct", "under35_pct", "born_os_pct", "lang_other_pct", "prev_grn", "prev_othright")
ds <- d[el %in% surge & complete.cases(d[, c("r", feat_lin), with = FALSE])]
cat(sprintf("\n=== surge elections only, each predicted from the other (RMSE, points of One Nation primary; lower is better) ===\n"))
fit_ridge <- function(tr) {
  set.seed(42)
  cv.glmnet(as.matrix(tr[, feat_lin, with = FALSE]), tr$r, alpha = 0, nfolds = 10, standardize = TRUE)
}
for (x in surge) {
  tr <- ds[el != x]; te <- ds[el == x]
  p_sen <- predict(lm(r ~ sen_r, data = tr), newdata = te) * te$L
  p_all <- predict(lm(as.formula(paste("r ~", paste(feat_lin, collapse = " + "))), data = tr), newdata = te) * te$L
  rg <- fit_ridge(tr)
  p_rdg <- as.numeric(predict(rg, as.matrix(te[, feat_lin, with = FALSE]), s = "lambda.min")) * te$L
  cat(sprintf("  predict %s from %s (train n %d, test n %d): Senate only %.2f | linear all %d inputs %.2f | ridge %.2f\n",
              x, setdiff(surge, x), nrow(tr), nrow(te), rmse(te$actual - p_sen), length(feat_lin),
              rmse(te$actual - p_all), rmse(te$actual - p_rdg)))
}

# Victoria 2026: the same inputs, fitted on BOTH surge elections, applied to the 88 districts at the live level.
vs <- fread("output/senate-onp-vic2026.csv")
Ls_vic <- sum(vs$senate * vs$votes) / sum(vs$votes)
sas <- fread("output/senate-onp-sa2026.csv")
cat(sprintf("\nstatewide Senate One Nation %%, vote-weighted over seats: Vic 2025 %.2f; SA check %.2f (panel says %.2f)\n",
            Ls_vic, sum(sas$senate * sas$votes) / sum(sas$votes), d[el == "sa2026", Ls[1]]))
pv <- pub[pair == "vic2022" & party %in% c("GRN", "OTH_RIGHT", "ONP"), .(v = sum(actual)), by = .(seat, party)]
pv <- dcast(pv, seat ~ party, value.var = "v", fill = 0)
setnames(pv, c("GRN", "OTH_RIGHT", "ONP"), c("prev_grn", "prev_othright", "prev_onp"), skip_absent = TRUE)
cv26 <- cens[pair == "vic2026", .(seat, yr12_pct, under35_pct, born_os_pct = 100 - born_aus_pct, lang_other_pct)]
v <- merge(merge(vs[, .(seat, senate)], cv26, by = "seat"), pv, by = "seat", all.x = TRUE)
v[is.na(prev_grn), prev_grn := 0][is.na(prev_othright), prev_othright := 0]
v[, sen_r := senate / Ls_vic]
L_vic <- 21.5343056750065   # live statewide One Nation level, output/statewide-level-vic-2026*.csv, 10 Nov
ours26 <- fread(Sys.getenv("AUSPOL_SHARES_FILE", "output/seat-shares-vic-2026.csv"))[, .(seat, ours = ONP)]
v <- merge(v, ours26, by = "seat", all.x = TRUE)
cat(sprintf("Victorian districts with every input: %d of 88\n", sum(complete.cases(v[, feat_lin, with = FALSE]))))
rg_all  <- fit_ridge(ds)
sen_all <- lm(r ~ sen_r, data = ds)
v[, `:=`(senate_only = predict(sen_all, newdata = v) * L_vic,
         ridge = as.numeric(predict(rg_all, as.matrix(v[, feat_lin, with = FALSE]), s = "lambda.min")) * L_vic)]
# Hold the statewide level fixed, as the forecast does: rescale each column so its seat mean is L_vic.
for (cc in c("senate_only", "ridge")) v[, (cc) := get(cc) * L_vic / mean(get(cc))]
cat("ridge coefficients (per point of input, on the ratio scale actual/L):\n"); print(round(as.matrix(coef(rg_all, s = "lambda.min")), 4))
show <- c("Box Hill", "Ashwood", "Glen Waverley", "Hastings", "Cranbourne", "Morwell", "Kew", "Richmond")
cat("\nVictoria 2026, One Nation primary % by seat (ours = published forecast; the other two hold the same statewide level):\n")
print(v[seat %in% show, .(seat, senate_pct = round(senate, 2), ours = round(ours, 1), senate_only = round(senate_only, 1),
                          ridge = round(ridge, 1), ridge_minus_ours = round(ridge - ours, 1))][order(-ours)])
cat(sprintf("\nacross all 88: ridge minus ours, mean %.2f, sd %.2f, biggest +%.1f (%s), biggest -%.1f (%s)\n",
            mean(v$ridge - v$ours), sd(v$ridge - v$ours), max(v$ridge - v$ours), v$seat[which.max(v$ridge - v$ours)],
            -min(v$ridge - v$ours), v$seat[which.min(v$ridge - v$ours)]))
