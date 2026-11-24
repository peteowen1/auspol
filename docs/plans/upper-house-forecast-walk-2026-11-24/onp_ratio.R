# One Nation upper/lower ratio walk (2026-11-24). Run from repo root:
#   powershell.exe -Command 'Rscript "docs/plans/upper-house-forecast-walk-2026-11-24/onp_ratio.R"'
options(auspol.root = normalizePath(".")); suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({library(data.table); library(lme4)})
CL <- c("ALP","LNP","GRN","ONP","IND","OTH","OTH_RIGHT")
cand <- fread("output/candidacies.csv", showProgress = FALSE)
cat(sprintf("candidacies.csv: %d rows (elections %d)\n", nrow(cand), uniqueN(cand$election)))

## ---- lower shares, federal: ORDINARY votes only, to match the Senate file (ordinary votes) ----
fl <- cand[grepl("^fed", election)]
fl[, v := as.numeric(ordinary)]
cat(sprintf("fed House rows %d; NA ordinary %d\n", nrow(fl), sum(is.na(fl$v))))
fl <- fl[!is.na(v)][, .(lv = sum(v)), by = .(elec = election, unit = seat, cls = party)]
fl[, lower := 100 * lv / sum(lv), by = .(elec, unit)]
sen <- fread("output/senate-by-division-class.csv", showProgress = FALSE)
cat(sprintf("senate-by-division-class.csv: %d rows, %d fed elections, cols %s\n", nrow(sen), uniqueN(sen$fed), paste(names(sen), collapse = ",")))
sen[, elec := paste0("fed", fed)]
sen <- sen[, .(elec, unit = division, cls, upper = senate_pct)]
chk <- sen[, .(s = sum(upper)), by = .(elec, unit)]
cat(sprintf("Senate share sums per division: min %.2f max %.2f (n=%d divisions)\n", min(chk$s), max(chk$s), nrow(chk)))
fed <- merge(fl[, .(elec, unit, cls, lower)], sen, by = c("elec","unit","cls"), all = TRUE)
fed <- fed[elec %in% unique(sen$elec) & elec %in% unique(fl$elec)]
cat("\nFederal ONP one-sidedness (ONP in one file only cannot enter a ratio; this is selection):\n")
print(fed[cls == "ONP", .(both = sum(!is.na(lower) & !is.na(upper)), lower_only = sum(!is.na(lower) & is.na(upper)), upper_only = sum(is.na(lower) & !is.na(upper))), by = elec])
cat("Federal division-elections with no match between House and Senate names (lost to the join):\n")
print(fed[, .(has_l = any(!is.na(lower)), has_u = any(!is.na(upper))), by = .(elec, unit)][, .(only_house = sum(has_l & !has_u), only_senate = sum(!has_l & has_u)), by = elec])
fed[, jur := "FED"]

## ---- Victoria ----
vic <- list()
for (y in c(2018, 2022)) {
  g <- fread(sprintf("output/council-fp-%d.csv", y), showProgress = FALSE)
  d <- g[block_kind == "district_total" & row_kind %in% c("group","ungrouped")]
  d[, cls := ifelse(row_kind == "ungrouped", "IND", classify_party(group_name))]
  cat(sprintf("council-fp-%d: %d rows read, %d district_total group/ungrouped rows used\n", y, nrow(g), nrow(d)))
  d <- d[, .(up = sum(total)), by = .(unit = sub(" District$", "", district), cls)]
  d[, upper := 100 * up / sum(up), by = unit]
  lw <- cand[election == paste0("vic", y)][, .(lv = sum(votes)), by = .(unit = seat, cls = party)]
  lw[, lower := 100 * lv / sum(lv), by = unit]
  cat(sprintf("  vic%d: %d district-class cells upper, %d lower; upper districts with no lower result: %s\n", y, nrow(d), nrow(lw),
              paste(setdiff(unique(d$unit), unique(lw$unit)), collapse = ", ")))
  m <- merge(lw[, .(unit, cls, lower)], d[, .(unit, cls, upper)], by = c("unit","cls"), all = TRUE); m[, elec := paste0("vic", y)]
  vic[[length(vic)+1]] <- m[unit %in% intersect(d$unit, lw$unit)]
}
vic <- rbindlist(vic); vic[, jur := "VIC"]
cat("Vic upper-share sum per district (should be ~100):\n"); print(summary(vic[, .(s = sum(upper, na.rm = TRUE)), by = .(elec, unit)]$s))
cat("Vic ONP one-sidedness:\n")
print(vic[cls == "ONP", .(both = sum(!is.na(lower)&!is.na(upper)), lower_only = sum(!is.na(lower)&is.na(upper)), upper_only = sum(is.na(lower)&!is.na(upper))), by = elec])
cat("\nNSW/WA/SA upper-house results on disk: NONE found (external/reference/{nswec,waec,ecsa} hold lower-house raw files and LOCAL-government council folders only; output/council-results-* are local councils).\n")

## ---- 1. The table ----
tab <- rbind(fed, vic)
tab <- tab[!is.na(lower) & !is.na(upper) & lower > 0 & upper > 0 & cls %in% CL]
tab[, `:=`(llow = log(lower), lratio = log(upper / lower))]
cat(sprintf("\nPAIRED TABLE (both shares > 0): %d rows; counts by election x class\n", nrow(tab)))
print(dcast(tab, elec ~ cls, value.var = "unit", fun.aggregate = length))
cat("\nFive One Nation example rows (percent of that unit's votes):\n")
print(tab[cls == "ONP"][order(-lower)][c(1, 10, 50, 100, .N), .(elec, unit, lower = round(lower,2), upper = round(upper,2), ratio = round(upper/lower,3))])

## ---- 2. ratio by size ----
tab[, bin := cut(lower, c(0,5,10,20,35,100), labels = c("<5","5-10","10-20","20-35",">35"), right = FALSE)]
cat("\nBy lower-share bin and class: n and mean ratio (upper/lower)\n")
bt <- tab[, .(n = .N, mean_ratio = round(mean(upper/lower),3)), by = .(bin, cls)]
print(dcast(bt, bin ~ cls, value.var = c("n","mean_ratio")))

## ---- 3. model ----
tab[, cls := factor(cls, levels = c("ALP", CL[-1]))]
tab[, lc := llow - log(10)]       # centred at a 10% lower share
tab[, el := elec]
fit  <- lmer(lratio ~ cls + lc + (1 | el), data = tab, REML = TRUE)
fit2 <- lmer(lratio ~ cls * lc + (1 | el), data = tab, REML = TRUE)
cat("\nMODEL A: lratio ~ class + log(lower/10) + (1|election)  [slope shared across classes]\n"); print(round(summary(fit)$coefficients, 4))
vc <- as.data.frame(VarCorr(fit))
cat(sprintf("between-election sd tau = %.3f (log ratio), residual sd = %.3f; %d elections, n = %d\n", vc$sdcor[1], vc$sdcor[2], uniqueN(tab$el), nrow(tab)))
cat("\nMODEL B: class x slope; the ONP-related rows:\n")
cf <- summary(fit2)$coefficients; print(round(cf[grepl("ONP|^lc$", rownames(cf)), , drop = FALSE], 4))
cat("ML AIC, A then B (lower is better): ", round(AIC(update(fit, REML = FALSE)),1), round(AIC(update(fit2, REML = FALSE)),1), "\n")
pred <- function(f, share) {
  nd <- data.frame(cls = factor("ONP", levels = levels(tab$cls)), lc = log(share/10))
  X <- model.matrix(delete.response(terms(f)), nd)
  b <- fixef(f); V <- as.matrix(vcov(f)); mu <- sum(X * b); se <- sqrt(drop(X %*% V %*% t(X)))
  tau <- as.data.frame(VarCorr(f))$sdcor[1]; tot <- sqrt(se^2 + tau^2)
  data.frame(lower_share = share, ratio = exp(mu), se_log_fixed = se, tau = tau, se_log_incl_election = tot,
             lo80 = exp(mu - 1.2816*tot), hi80 = exp(mu + 1.2816*tot))
}
cat("\nONP predicted ratio (se on LOG scale; incl_election adds tau for a new election; 80% interval on ratio)\n")
cat("Model A (shared slope):\n"); print(do.call(rbind, lapply(c(15,21,30), function(s) pred(fit, s))), digits = 3)
cat("Model B (ONP-specific slope):\n"); print(do.call(rbind, lapply(c(15,21,30), function(s) pred(fit2, s))), digits = 3)
o <- tab[cls == "ONP"]; fo <- lmer(lratio ~ lc + (1|el), data = o)
cat("\nONP-only model lratio ~ log(lower/10) + (1|election):\n"); print(round(summary(fo)$coefficients, 4))
cat(sprintf("ONP-only tau = %.3f, resid sd = %.3f, n = %d, elections = %d\n", as.data.frame(VarCorr(fo))$sdcor[1], sigma(fo), nrow(o), uniqueN(o$el)))
cat("ONP mean ratio by election (n):\n"); print(o[, .(n = .N, mean_lower = round(mean(lower),2), mean_ratio = round(mean(upper/lower),3)), by = elec])

## ---- 4. time-forward ----
last <- max(tab[cls == "ONP" & jur == "FED", elec]); cat(sprintf("\nTIME-FORWARD: last federal election with ONP pairs = %s\n", last))
yr <- function(e) as.integer(sub("^[a-z]+", "", e))
trn <- tab[yr(elec) < yr(last)]; tst <- tab[elec == last & cls == "ONP"]
cat(sprintf("train: %d rows, %d elections (%s); test: ONP n=%d divisions, lower range %.2f-%.2f\n", nrow(trn), uniqueN(trn$el), paste(sort(unique(trn$el)), collapse=","), nrow(tst), min(tst$lower), max(tst$lower)))
tf  <- lmer(lratio ~ cls + lc + (1 | el), data = trn)
tf2 <- lmer(lratio ~ cls * lc + (1 | el), data = trn)
tst[, up_A := lower * exp(predict(tf,  newdata = tst, re.form = NA))]
tst[, up_B := lower * exp(predict(tf2, newdata = tst, re.form = NA))]
tro <- trn[cls == "ONP"]; fo2 <- lm(lratio ~ lc, tro)
tst[, up_C := lower * exp(predict(fo2, tst))]
tst[, `:=`(up_1 = lower, up_lab = lower * 0.905)]
sc <- function(h) c(RMSE_pts = sqrt(mean((h - tst$upper)^2)), mean_err_pts = mean(h - tst$upper), MAE_pts = mean(abs(h - tst$upper)))
cat(sprintf("Error in UPPER-share points (predicted minus actual), n=%d; mean actual upper %.2f, mean lower %.2f. ONP-only training n=%d (slope %.3f)\n",
            nrow(tst), mean(tst$upper), mean(tst$lower), nrow(tro), coef(fo2)[2]))
print(round(rbind(ratio_1.00 = sc(tst$up_1), labor_0.905 = sc(tst$up_lab), A_shared_slope = sc(tst$up_A),
                  B_class_slopes = sc(tst$up_B), C_ONP_only_regression = sc(tst$up_C)), 3))
cat("Implied mean ratio actual:", round(mean(tst$upper/tst$lower),3), "; model A mean ratio:", round(mean(tst$up_A/tst$lower),3), "\n")

## ---- 5. extrapolation ----
cat(sprintf("\nEXTRAPOLATION: largest ONP lower share observed %.1f%% (%s %s). ONP units n=%d; above 10%%: %d; above 15%%: %d; above 20%%: %d; above 21%%: %d.\n",
  max(o$lower), o[which.max(lower), elec], o[which.max(lower), unit], nrow(o), sum(o$lower > 10), sum(o$lower > 15), sum(o$lower > 20), sum(o$lower > 21)))
print(o[lower > 10, .(n = .N, max_lower = round(max(lower),1)), by = elec])
cat("Non-ONP units above 20% lower share: n =", nrow(tab[cls != "ONP" & lower > 20]), " (ALP/LNP/GRN above 15%:", nrow(tab[cls %in% c("ALP","LNP","GRN") & lower > 15]), ")\n")
