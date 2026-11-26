# Backtest and source weights for the upper-house vote model (docs/plans/upper-house-vote-model-2026-11-26.md).
#   Rscript scripts/backtest_upper_house_vote.R > docs/plans/upper-house-vote-model-2026-11-26-output.txt
# Reads only the small committed inputs (scripts/build_upper_house_ratio_inputs.R builds them).
options(auspol.root = normalizePath(".")); suppressMessages(devtools::load_all(quiet = TRUE))
suppressPackageStartupMessages(library(data.table))
inp <- fread("external/reference/vec/upper-house-ratio-inputs.csv")
rt <- uh_region_table(inp)
cat(sprintf("UHB0  inputs: %d district-class rows; region table %d rows (%s)\n", nrow(inp), nrow(rt),
            paste(rt[, .N, by = election][, paste0(election, " ", N)], collapse = ", ")))
cat("\nStatewide upper/lower ratio by election (exp of m):\n")
print(dcast(unique(rt[, .(election, party, ratio = round(exp(m), 3))]), party ~ election, value.var = "ratio"), row.names = FALSE)

## ---- 1. majors backtest ----
CUR <- c(ALP = 0.905, LNP = 0.845, GRN = 0.883)
score <- function(tg, hist) {
  T <- rt[election == tg]; regs <- sort(unique(T$reg)); ps <- c("ALP", "LNP", "GRN")
  lr <- lapply(ps, function(k) setNames(T[party == k][match(regs, reg)]$ls, regs)); names(lr) <- ps
  lst <- setNames(T[, .(v = lstate[1]), by = party][match(ps, party)]$v, ps)
  mact <- setNames(T[, .(v = m[1]), by = party][match(ps, party)]$v, ps)
  last <- hist[which.max(as.integer(sub("vic", "", hist)))]
  arms <- list()
  arms$uniform_prev <- matrix(rep(sapply(ps, function(k) rt[election == last & party == k]$m[1]), each = length(regs)), length(regs), dimnames = list(regs, ps))
  arms$current_constants_LEAKY <- matrix(rep(log(CUR[ps]), each = length(regs)), length(regs), dimnames = list(regs, ps))
  fr <- uh_fit_majors(rt, hist, shrink = FALSE); arms$raw_region <- uh_major_logratio(fr, regs)
  fa <- uh_fit_majors(rt, hist); arms$A_shrunk <- uh_major_logratio(fa, regs)
  sl <- uh_level_slope(inp, hist); fb <- uh_fit_majors(rt, hist, slope = sl)
  arms$B_slope <- uh_major_logratio(fb, regs, lr, lst)
  act <- sapply(ps, function(k) T[party == k][match(regs, reg)]$us)
  low <- sapply(ps, function(k) lr[[k]])
  out <- rbindlist(lapply(names(arms), function(a) {
    P <- arms[[a]]; hat <- low * exp(P)
    # oracle level: shift each party's log ratios so the statewide level matches the actual (ADDITION, labelled)
    Po <- sweep(P, 2, (colMeans(P) - colMeans(log(act / low))), "-")   # mean region log ratio set to the actual one
    ho <- low * exp(Po)
    data.table(target = tg, history = paste(hist, collapse = "+"), arm = a, n = length(act),
               rmse = sqrt(mean((hat - act)^2)), rmse_ALP = sqrt(mean((hat[, "ALP"] - act[, "ALP"])^2)),
               rmse_LNP = sqrt(mean((hat[, "LNP"] - act[, "LNP"])^2)), rmse_GRN = sqrt(mean((hat[, "GRN"] - act[, "GRN"])^2)),
               rmse_oracle_level = sqrt(mean((ho - act)^2)))
  }))
  attr(out, "fits") <- list(A = fa, B = fb, slope = sl)
  out
}
bt <- list(score("vic2018", "vic2010"), score("vic2022", "vic2018"), score("vic2022", c("vic2010", "vic2018")))
B <- rbindlist(bt)
cat("\n1. MAJORS BACKTEST. Error in predicted UPPER-house region share, percentage points (lower is better).\n",
    "   Each cell = one party in one region (n = 8 regions x 3 parties = 24). Input: that election's ACTUAL lower-house\n",
    "   region shares (oracle), so this scores the ratio model alone. rmse_oracle_level (ADDITION) also sets each\n",
    "   party's level to the one that fits the target exactly, so it scores only the REGIONAL pattern.\n",
    "   current_constants_LEAKY were fitted on 2018 and 2022 themselves: shown for reference, not a fair score.\n", sep = "")
print(B[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)], row.names = FALSE)
cat("\nPre-registered decision, pooled over the 2018 (from 2010) and 2022 (from 2010+2018) backtests, 48 cells:\n")
pool <- rbind(B[target == "vic2018"], B[target == "vic2022" & history == "vic2010+vic2018"])
pd <- pool[, .(n = sum(n), rmse = sqrt(sum(rmse^2 * n) / sum(n)), rmse_oracle_level = sqrt(sum(rmse_oracle_level^2 * n) / sum(n))), by = arm]
print(pd[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)], row.names = FALSE)

fa <- attr(bt[[3]], "fits")$A; fb <- attr(bt[[3]], "fits")$B
cat(sprintf("\nShrinkage on 2010+2018 (the 2022 backtest's fit): w ALP %.2f LNP %.2f GRN %.2f; level slopes ALP %.2f LNP %.2f GRN %.2f\n",
            fa$party$ALP$w, fa$party$LNP$w, fa$party$GRN$w, fb$party$ALP$b, fb$party$LNP$b, fb$party$GRN$b))

## ---- 1b. ADDITIONS after the results (labelled): do region effects repeat between 2018 and 2022? ----
cat("\n1b. ADDITION. Correlation of each region's deviation from the statewide ratio, between elections (8 regions):\n")
dv <- dcast(rt, reg + party ~ election, value.var = "d")
print(dv[, .(n = .N, r_2010_2018 = round(cor(vic2010, vic2018, use = "complete"), 2), r_2018_2022 = round(cor(vic2018, vic2022), 2),
             sd_2010 = round(sd(vic2010, na.rm = TRUE), 3), sd_2018 = round(sd(vic2018), 3), sd_2022 = round(sd(vic2022), 3)), by = party], row.names = FALSE)
f3 <- uh_fit_majors(rt, c("vic2010", "vic2018", "vic2022"))
T22 <- rt[election == "vic2022"]; T18 <- rt[election == "vic2018"]
ins <- rbindlist(lapply(c("ALP", "LNP", "GRN"), function(k) { pk <- k
  a <- T22[party == pk]; o <- T18[party == pk][match(a$reg, reg)]
  data.table(party = k, act = a$us, uni = a$ls * exp(o$m), shr = a$ls * exp(o$m + f3$party[[k]]$w * o$d)) }))
cat("   2022 from 2018 with region effects shrunk by the three-election weights (IN-SAMPLE: the weights use 2022), RMSE points, n = 24:\n")
print(ins[, .(n = .N, uniform = round(sqrt(mean((uni - act)^2)), 3), shrunk_2018_effects = round(sqrt(mean((shr - act)^2)), 3)), by = party][
  , rbind(.SD, data.table(party = "all", n = sum(n), uniform = round(sqrt(sum(uniform^2 * n) / sum(n)), 3), shrunk_2018_effects = round(sqrt(sum(shrunk_2018_effects^2 * n) / sum(n)), 3)))], row.names = FALSE)

## ---- 2. the live fit: all three elections ----
fl <- uh_fit_majors(rt, c("vic2010", "vic2018", "vic2022"))
sl <- uh_level_slope(inp, c("vic2010", "vic2018", "vic2022")); flb <- uh_fit_majors(rt, c("vic2010", "vic2018", "vic2022"), slope = sl)
cat("\n2. LIVE FIT on 2010, 2018, 2022. Level = mean of the 2018 and 2022 statewide log ratios.\n")
for (k in c("ALP", "LNP", "GRN")) { f <- fl$party[[k]]
  cat(sprintf("   %s: statewide ratio %.3f; region drift sd %.3f (log); between-region sd %.3f; shrink w %.2f; slope (arm B) %.2f\n",
              k, exp(f$mu), sqrt(f$s2), sqrt(f$tau2), f$w, flb$party[[k]]$b))
  print(round(exp(f$mu + f$eff), 3)) }
cat(sprintf("   Statewide drift for a new election (log sd), Victorian history only: common %.3f, party %.3f.\n", fl$drift_common_sd, fl$drift_party_sd))
nv <- uh_noticket_variance(fread("external/reference/vec/upper-house-noticket-experiments.csv"))
cat("   Ticket-abolition experiments, change in log ratio (after minus before):\n")
print(dcast(nv$changes[, .(case, cls, change = round(change, 3))], case ~ cls, value.var = "change"), row.names = FALSE)
cat(sprintf("   Regime variance added: common sd %.3f, party sd %.3f. Mean shift NOT applied (cases disagree in sign): %s\n", nv$common_sd, nv$party_sd,
            paste(sprintf("%s %+.3f", nv$mean_shift$cls, nv$mean_shift$shift), collapse = ", ")))
fl2 <- uh_add_regime_variance(fl, nv)
cat(sprintf("   2026 drift (log sd): common %.3f, party %.3f -> a party's statewide ratio 80%% range about x%.2f to x%.2f of its centre.\n",
            fl2$drift_common_sd, fl2$drift_party_sd, exp(-1.2816 * sqrt(fl2$drift_common_sd^2 + fl2$drift_party_sd^2)), exp(1.2816 * sqrt(fl2$drift_common_sd^2 + fl2$drift_party_sd^2))))
cat("   ADDITION, calibration check: every statewide major ratio on disk (Victoria 2010-22, NSW/SA/WA, Victorian Senate 2004-25), log sd and range:\n")
oth <- "C:/dev/auspol/output/other-upper-house-fp.csv"
obs <- unique(rt[, .(src = election, party, lr = m)])
if (file.exists(oth)) { o <- fread(oth)[geo_level == "state"]; o <- o[, .(v = sum(votes)), by = .(election, house, party = party_class)][, sh := v / sum(v), by = .(election, house)]
  o <- dcast(o[party %in% c("ALP", "LNP", "GRN")], election + party ~ house, value.var = "sh")[, .(src = election, party, lr = log(upper / lower))]; obs <- rbind(obs, o) }
cnd <- fread("C:/dev/auspol/output/candidacies.csv", select = c("election", "seat", "party", "ordinary"))[grepl("^fed", election) & !is.na(ordinary)]
sen <- fread("C:/dev/auspol/output/senate-by-division-class.csv")[state == "VIC"]
for (e in unique(paste0("fed", sen$fed))) { ee <- e; ss <- sen[paste0("fed", fed) == ee]; hh <- cnd[election == ee & seat %in% ss$division]
  if (!nrow(hh)) next
  h <- hh[, .(v = sum(as.numeric(ordinary))), by = party][, sh := v / sum(v)]; s0 <- ss[, .(v = sum(v)), by = .(party = cls)][, sh := v / sum(v)]
  mm <- merge(h, s0, by = "party")[party %in% c("ALP", "LNP", "GRN")]; obs <- rbind(obs, mm[, .(src = paste(ee, "VIC Senate"), party, lr = log(sh.y / sh.x))]) }
print(obs[, .(n = .N, log_sd = round(sd(lr), 3), min = round(exp(min(lr)), 3), max = round(exp(max(lr)), 3)), by = party], row.names = FALSE)
cat(sprintf("   Drawn statewide log sd (common and party combined): %.3f without the ticket variance, %.3f with it.\n",
            sqrt(fl$drift_common_sd^2 + fl$drift_party_sd^2), sqrt(fl2$drift_common_sd^2 + fl2$drift_party_sd^2)))
cat("   For scale: the current script's NOISE (points of region vote, ALP 3.0, LNP 2.5, GRN 1.0, ONP 2.0) is independent per region and has no statewide part.\n")

## ---- 3. One Nation ----
src <- fread("external/reference/vec/upper-house-onp-sources.csv")
pp <- uh_onp_poll_units(fread("external/reference/polls/demosau-upper-lower-2025-2026.csv"), rt)
disc <- pp$disc; disc_var <- pp$disc_var; hist_geo <- pp$hist_geo
cat(sprintf("\n3. ONE NATION. Poll check on the majors: each poll's relative ratios against Victoria 2018-22 (log points):\n"))
print(dcast(disc[, .(poll, party, disc = round(disc, 3))], poll ~ party, value.var = "disc"), row.names = FALSE)
cat(sprintf("   Poll discrepancy variance beyond sampling %.4f (sd %.3f) from %d polls x 3 majors. Historical majors' geometric mean ratio %.3f.\n",
            disc_var, sqrt(disc_var), uniqueN(disc$poll), hist_geo))
pu <- pp$units
allsrc <- rbind(src, pu, fill = TRUE)
op <- uh_onp_pool(allsrc)
cat(sprintf("   Federal state rows dropped by the n >= 5 rule (or no se): %d of %d (%s)\n", nrow(op$dropped), sum(src$kind == "federal Senate vs House"), paste(op$dropped$source, collapse = ", ")))
cat("   Units (federal states pooled within each election first). ratio = exp(log_ratio); weight = share of the pooled estimate.\n")
print(op$units[, .(unit, kind, states, n, ratio = round(exp(log_ratio), 3), se = round(se, 3), weight = round(weight, 3))], row.names = FALSE)
cat(sprintf("   POOLED One Nation ratio %.3f; se of the mean %.3f, between-unit sd %.3f, predictive log sd %.3f -> 80%% of draws %.2f to %.2f\n",
            exp(op$mu), op$se, sqrt(op$tau2), op$pred_sd, exp(op$mu - 1.2816 * op$pred_sd), exp(op$mu + 1.2816 * op$pred_sd)))
fam <- op$units[, .(weight = round(sum(weight), 3)), by = kind]; cat("   Weight by source family:\n"); print(fam, row.names = FALSE)
s1 <- uh_onp_pool(allsrc[!(kind == "federal Senate vs House" & as.integer(sub("^fed(\\d+).*", "\\1", source)) < 2019)])
s2 <- uh_onp_pool(allsrc[kind != "federal Senate vs House" | grepl(" VIC$", source)])
cat(sprintf("   Sensitivity: federal 2019+ only -> %.3f (pred sd %.3f); Victorian federal rows only -> %.3f (pred sd %.3f)\n",
            exp(s1$mu), s1$pred_sd, exp(s2$mu), s2$pred_sd))

## ---- 4. minor groups: regional pattern ----
t18 <- fread("external/reference/vec/upper-house-group-totals-2018.csv"); t22 <- fread("external/reference/vec/2022/upper-house-group-totals-2022.csv")
for (t in list(t18, t22)) { t[, reg := uh_map_region(region)]; t[, key := uh_key_of(group_name)] }
p18 <- uh_minor_pattern(t18[, .(reg, key, votes)]); p22 <- uh_minor_pattern(t22[, .(reg, key, votes)])
both <- intersect(unique(p18$key), unique(p22$key))
ms <- uh_minor_shrink(p22[key %in% both], p18[key %in% both])
vw22 <- t22[, .(v = sum(votes)), by = reg]; vw22 <- setNames(vw22$v, vw22$reg)
mt <- rbindlist(lapply(both, function(k) { a <- p22[key == k]; o <- p18[key == k]; pat <- setNames(o$pat, o$reg)
  st <- a$state[1]; data.table(grp = k, reg = a$reg, act = a$share, flat = st,
    raw = uh_level_by_region(st, pat, 1, vw22)[a$reg], shrunk = uh_level_by_region(st, pat, ms$w, vw22)[a$reg]) }))
cat(sprintf("\n4. MINOR GROUPS' REGIONAL PATTERN, 2022 from 2018 (statewide 2022 level given as an oracle). %d groups in both, n = %d group-regions.\n",
            length(both), nrow(mt)))
cat(sprintf("   Shrink weight w %.2f (pattern instability sd %.3f, between-region sd %.3f, from %d pairs; IN-SAMPLE: uses 2022, flagged).\n",
            ms$w, sqrt(ms$s2), sqrt(ms$tau2), ms$n_pairs))
cat("   RMSE of region share, points (lower is better):\n")
print(mt[, .(n = .N, flat = round(sqrt(mean((flat - act)^2)), 3), raw_2018_pattern = round(sqrt(mean((raw - act)^2)), 3), shrunk = round(sqrt(mean((shrunk - act)^2)), 3))], row.names = FALSE)
print(mt[, .(n = .N, flat = round(sqrt(mean((flat - act)^2)), 3), raw = round(sqrt(mean((raw - act)^2)), 3), shrunk = round(sqrt(mean((shrunk - act)^2)), 3)), by = grp], row.names = FALSE)
