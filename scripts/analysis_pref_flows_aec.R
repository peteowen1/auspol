# AEC preference data: flow stability, final-two prediction, booth flows.
# Read-only analysis; writes CSVs to the scratch dir and prints tables.
# Run: powershell.exe -Command 'Rscript "scripts/analysis_pref_flows_aec.R"'   (from C:/dev/auspol)
suppressMessages(library(data.table))
source("R/parties.R")                       # classify_party() only
ROOT <- "C:/dev/auspol"
SCR  <- "C:/Users/peteo/AppData/Local/Temp/claude/C--dev-auspol/d9620856-015e-4f5d-8963-ed4e84fea399/scratchpad/prefs"
dir.create(SCR, showWarnings = FALSE, recursive = TRUE)
YEARS <- c(2004, 2007, 2010, 2013, 2016, 2019, 2022, 2025)
wsd <- function(x, w) sqrt(sum(w * (x - sum(w * x) / sum(w))^2) / sum(w))
pr <- function(...) cat(..., "\n", sep = "")

## ---------------------------------------------------------------- load DOP
load_dop <- function(y) {
  f <- file.path(ROOT, "external/reference/aec", sprintf("fed%d-dop.csv", y))
  d <- fread(f, skip = 1, showProgress = FALSE)
  d[, year := y]
  d[, cls := classify_party(PartyNm, PartyAb)]
  d[, div := trimws(DivisionNm)]
  d[, ct := CalculationType]
  d
}
dops <- lapply(YEARS, load_dop)
names(dops) <- YEARS
pr("DOP rows by year: ", paste(YEARS, vapply(dops, nrow, 1L), sep = "=", collapse = " "))
pr("DOP divisions by year: ", paste(YEARS, vapply(dops, function(d) uniqueN(d$div), 1L), sep = "=", collapse = " "))
pr("NA class rows: ", sum(vapply(dops, function(d) sum(is.na(d$cls)), 1L)))

## per election: candidate table (fp, final), exclusion-step flows
cand_tab <- list(); flow_rows <- list(); skipped <- list()
for (y in YEARS) {
  d <- dops[[as.character(y)]]
  P <- d[ct == "Preference Count", .(StateAb, div, CountNumber, CandidateID, cls, pc = CalculationValue)]
  Tr <- d[ct == "Transfer Count", .(div, CountNumber, CandidateID, tr = CalculationValue)]
  maxc <- P[, .(maxc = max(CountNumber)), by = div]
  c0 <- P[CountNumber == 0, .(StateAb, div, CandidateID, cls, fp = pc)]
  cl <- merge(P, maxc, by = "div")[CountNumber == maxc, .(div, CandidateID, final = pc)]
  ct0 <- merge(c0, cl, by = c("div", "CandidateID"))
  ct0[, year := y]
  cand_tab[[as.character(y)]] <- ct0
  ## steps
  Pp <- P[, .(div, CountNumber = CountNumber + 1L, CandidateID, prevP = pc)]
  S <- merge(merge(P, Tr, by = c("div", "CountNumber", "CandidateID")), Pp, by = c("div", "CountNumber", "CandidateID"))
  S <- S[CountNumber >= 1]
  nex <- S[tr < 0, .(n_ex = .N), by = .(div, CountNumber)]
  S <- merge(S, nex, by = c("div", "CountNumber"))
  ex <- S[tr < 0, .(div, CountNumber, ex_cls = cls[1], ex_votes = -tr[1]), by = .(div, CountNumber)][, .(div, CountNumber, ex_cls, ex_votes)]
  agg <- S[, .(tA = sum(tr[cls == "ALP" & tr > 0]), tC = sum(tr[cls == "LNP" & tr > 0]),
               hasA = any(cls == "ALP" & prevP > 0), hasC = any(cls == "LNP" & prevP > 0),
               n_ex = n_ex[1], st = StateAb[1]), by = .(div, CountNumber)]
  agg <- merge(agg, ex, by = c("div", "CountNumber"))
  skipped[[as.character(y)]] <- data.table(year = y, bulk_votes = agg[n_ex > 1, sum(ex_votes)], single_votes = agg[n_ex == 1, sum(ex_votes)])
  a1 <- agg[n_ex == 1 & hasA & hasC & !(ex_cls %in% c("ALP", "LNP"))]
  fl <- a1[, .(tA = sum(tA), tC = sum(tC), ex_votes = sum(ex_votes), st = st[1]), by = .(div, cls = ex_cls)]
  fl[, `:=`(year = y, N = tA + tC)]
  flow_rows[[as.character(y)]] <- fl[N > 0]
}
cand <- rbindlist(cand_tab)
FL <- rbindlist(flow_rows)
FL[, f := tA / N * 100]
pr("\nBulk-exclusion votes skipped vs single-exclusion votes used (by year):")
print(rbindlist(skipped))

## final pairs
fin <- cand[final > 0, .(pair = paste(sort(cls), collapse = "-"), n = .N,
                         cands = paste(cls[order(cls)], collapse = "/")), by = .(year, div)]
pr("\nFinal-count candidates per division (should be 2): ", paste(table(fin$n), collapse = " "))

## ---------------------------------------------------------------- aggregate flow ("ALL")
agg_all <- cand[, {
  fi <- fp[final > 0]; ci <- cls[final > 0]; fi_all <- fp
  if (length(fi) == 2 && setequal(ci, c("ALP", "LNP"))) {
    tot <- sum(fp); fa <- fp[final > 0 & cls == "ALP"]; fc <- fp[final > 0 & cls == "LNP"]
    la <- final[final > 0 & cls == "ALP"]
    list(N = tot - fa - fc, f = (la - fa) / (tot - fa - fc) * 100, st = StateAb[1])
  } else list(N = NA_real_, f = NA_real_, st = StateAb[1])
}, by = .(year, div)]
ALLF <- agg_all[!is.na(f)][, cls := "ALL"]
pr("ALP-v-LNP final-pair divisions by year: ", paste(ALLF[, .N, by = year][order(year), paste0(year, "=", N)], collapse = " "))

FLX <- rbind(FL[, .(year, div, st, cls, N, f)], ALLF[, .(year, div, st, cls, N, f)])
FLX <- FLX[is.finite(f) & N > 0]
FLX[, f := pmin(100, pmax(0, f))]

## ---------------------------------------------------------------- Q1a: variation table
nat <- FLX[, .(nat = sum(N * f) / sum(N), nseat = .N, votes = sum(N),
               sd_w = wsd(f, N / sum(N)), sd_u = sd(f),
               samp_sd = sqrt(sum(N * (f / 100 * (1 - f / 100) * 1e4 / N)) / sum(N))), by = .(cls, year)]
nat[, excess_sd := sqrt(pmax(sd_w^2 - samp_sd^2, 0))]
setorder(nat, cls, year)
fwrite(nat, file.path(SCR, "q1a_between_seat_spread.csv"))
pr("\n=== Q1a between-seat spread of flow to ALP (pct points), per class x election ===")
print(nat[, .(cls, year, nseat, votes = round(votes), nat = round(nat, 1), sd_w = round(sd_w, 1), sd_u = round(sd_u, 1),
              samp_sd = round(samp_sd, 2), excess_sd = round(excess_sd, 1))], nrows = 200)
pool <- nat[year >= 2010, .(nat_mean = round(mean(nat), 1), nat_range = paste(round(range(nat), 0), collapse = "-"),
                          sd_w = round(sqrt(weighted.mean(sd_w^2, votes)), 1),
                          sd_u = round(sqrt(mean(sd_u^2)), 1), samp = round(sqrt(weighted.mean(samp_sd^2, votes)), 2),
                          seats_per_elec = round(mean(nseat))), by = cls]
pr("\nPooled 2010-2025 (rms over elections):")
print(pool)

## ---------------------------------------------------------------- Q1b: time-forward
setkey(FLX, cls, year, div)
prevy <- setNames(c(NA, YEARS[-length(YEARS)]), YEARS)
pairs <- list()
for (y in YEARS[-1]) {
  py <- prevy[[as.character(y)]]
  cur <- FLX[year == y]
  pv <- FLX[year == py, .(cls, div, f_prev = f, N_prev = N)]
  cur <- merge(cur, pv, by = c("cls", "div"), all.x = TRUE)
  natp <- nat[year == py, .(cls, nat_prev = nat)]
  natc <- nat[year == y, .(cls, nat_t = nat)]
  cur <- merge(merge(cur, natp, by = "cls"), natc, by = "cls")
  stp <- FLX[year == py, .(st_prev = sum(N * f) / sum(N)), by = .(cls, st)]
  cur <- merge(cur, stp, by = c("cls", "st"), all.x = TRUE)
  cur[, `:=`(x1 = ifelse(is.na(f_prev), 0, f_prev - nat_prev), x2 = ifelse(is.na(st_prev), 0, st_prev - nat_prev),
             has_prev = !is.na(f_prev))]
  pairs[[as.character(y)]] <- cur
}
PR <- rbindlist(pairs)
pr("\nCoverage: share of rows with a previous-election seat value (same class, same division name), by year")
print(PR[cls != "ALL", .(rows = .N, with_prev = sum(has_prev), pct = round(100 * mean(has_prev))), by = year][order(year)])

fit_w <- function(tr, base_col, terms) {
  tr <- tr[has_prev == TRUE]
  if (nrow(tr) < 30) return(setNames(rep(0, length(terms)), terms))
  y <- tr$f - tr[[base_col]]
  X <- as.matrix(tr[, ..terms])
  co <- coef(lm.wfit(X, y, w = tr$N))
  co[is.na(co)] <- 0
  co
}
specs <- list(
  A_lag_nat       = list(base = "nat_prev", terms = character(0)),
  B_lag_nat_seat  = list(base = "nat_prev", terms = "x1"),
  C_this_nat      = list(base = "nat_t",    terms = character(0)),
  D_nat_seat      = list(base = "nat_t",    terms = "x1"),
  E_nat_state     = list(base = "nat_t",    terms = "x2"),
  F_nat_seat_st   = list(base = "nat_t",    terms = c("x1", "x2")))
res <- list(); coefs <- list()
for (y in YEARS[YEARS >= 2010]) {
  tr <- PR[year < y]; te <- PR[year == y]
  for (nm in names(specs)) {
    sp <- specs[[nm]]
    # pooled across classes (classes with few rows would be unstable); ALL fitted on its own
    pred <- numeric(nrow(te)); w <- NULL
    for (grp in c("ALL", "classes")) {
      itr <- if (grp == "ALL") tr$cls == "ALL" else tr$cls != "ALL"
      ite <- if (grp == "ALL") te$cls == "ALL" else te$cls != "ALL"
      co <- if (length(sp$terms)) fit_w(tr[itr], sp$base, sp$terms) else numeric(0)
      p <- te[[sp$base]][ite]
      if (length(sp$terms)) { tcols <- sp$terms; p <- p + as.numeric(as.matrix(te[ite, ..tcols]) %*% co) }
      pred[ite] <- p
      if (length(co)) coefs[[length(coefs) + 1]] <- data.table(year = y, spec = nm, grp = grp, term = names(co), coef = as.numeric(co))
    }
    te2 <- copy(te); te2[, `:=`(pred = pred, spec = nm)]
    res[[length(res) + 1]] <- te2
  }
}
RES <- rbindlist(res); COEF <- rbindlist(coefs)
RES[, err := f - pred]
fwrite(RES[, .(year, div, cls, N, f, pred, spec, err, has_prev)], file.path(SCR, "q1b_predictions.csv"))
score <- function(d) d[, .(n = .N, rmse_w = sqrt(sum(N * err^2) / sum(N)), rmse_u = sqrt(mean(err^2)), bias_w = sum(N * err) / sum(N)), by = spec]
pr("\n=== Q1b time-forward RMSE of seat flow to ALP, 2010-2025 pooled (pct points; lower is better) ===")
pr("A/B use last election's national; C-F are told this election's national (what a count in progress learns).")
pr("-- minor-party classes (GRN, ONP, IND, OTH_RIGHT, OTH), votes-weighted and unweighted")
print(score(RES[cls != "ALL"])[order(spec)])
pr("-- same, seats with a previous-election value only")
print(score(RES[cls != "ALL" & has_prev == TRUE])[order(spec)])
pr("-- by class (spec C vs F), weighted RMSE")
bycls <- RES[cls != "ALL" & spec %in% c("A_lag_nat", "C_this_nat", "D_nat_seat", "F_nat_seat_st"),
             .(n = .N, rmse_w = round(sqrt(sum(N * err^2) / sum(N)), 1), rmse_u = round(sqrt(mean(err^2)), 1)), by = .(cls, spec)]
print(dcast(bycls, cls ~ spec, value.var = c("rmse_w", "n"))[order(cls)])
pr("-- aggregate flow ('ALL': ALP v LNP seats, all other voters pooled)")
print(score(RES[cls == "ALL"])[order(spec)])
pr("-- ALL, seats with a previous ALP-v-LNP value only")
print(score(RES[cls == "ALL" & has_prev == TRUE])[order(spec)])
pr("-- ALL by election, spec C (this national only) and F, unweighted RMSE")
print(dcast(RES[cls == "ALL" & spec %in% c("C_this_nat", "F_nat_seat_st", "A_lag_nat")][, .(rmse_u = round(sqrt(mean(err^2)), 1), n = .N), by = .(year, spec)],
            year ~ spec, value.var = "rmse_u"))
pr("-- coefficients fitted on elections BEFORE each year (x1 = seat's last flow minus last national; x2 = state's), ALL / pooled classes")
print(dcast(COEF[spec == "F_nat_seat_st"], year + grp ~ term, value.var = "coef")[order(grp, year)])
pr("Final fit on all pairs <=2025, spec F, by class slope on x1 (descriptive only):")
for (cc in c("ALL", "GRN", "ONP", "IND", "OTH_RIGHT", "OTH")) {
  tr <- PR[cls == cc & has_prev == TRUE]
  if (nrow(tr) > 30) { co <- coef(lm.wfit(as.matrix(tr[, .(x1, x2)]), tr$f - tr$nat_t, w = tr$N)); pr(sprintf("  %-10s n=%4d  w_seat=%.2f  w_state=%.2f", cc, nrow(tr), co[1], co[2])) }
}
sdsum <- RES[cls == "ALL" & spec == "F_nat_seat_st" & year >= 2010, .(sd_err = sd(err), sd_err_w = sqrt(sum(N * err^2) / sum(N)), n = .N), by = year]
pr("\nALL, spec F residual by year:"); print(sdsum)

## ---------------------------------------------------------------- Q2 final pair
pr("\n=== Q2 final pair ===")
pub <- fread(file.path(ROOT, "output/published-predictions.csv"))
pub[, seat := trimws(seat)]
pp <- pub[grepl("^fed", pair)][, year := as.integer(sub("fed", "", pair))]
top2 <- pp[order(pair, seat, -ours), .(pred_pair = paste(sort(party[1:2]), collapse = "-"),
                                       pred_cls1 = party[1], pred_cls2 = party[2], s1 = ours[1], s2 = ours[2], s3 = ours[3]), by = .(year, seat)]
top2p <- pp[order(pair, seat, -p_win), .(pwin_pair = paste(sort(party[1:2]), collapse = "-")), by = .(year, seat)]
fin[, seat := div]
setnames(fin, "pair", "act_pair")
prevfin <- copy(fin)[, .(year = year + 3L, seat, prev_pair = act_pair)]
# election gaps: 2004->2007 (3), 2007->2010 (3), 2010->2013 (3), 2013->2016 (3), 2016->2019 (3), 2019->2022 (3), 2022->2025 (3)
cmp <- merge(fin[, .(year, seat, act_pair)], top2, by = c("year", "seat"), all.x = TRUE)
cmp <- merge(cmp, top2p, by = c("year", "seat"), all.x = TRUE)
cmp <- merge(cmp, prevfin, by = c("year", "seat"), all.x = TRUE)
# previous first-preference top two
fpt <- cand[order(year, div, -fp), .(fp_pair = paste(sort(cls[1:2]), collapse = "-")), by = .(year, seat = div)]
fpt_prev <- copy(fpt)[, .(year = year + 3L, seat, prev_fp_pair = fp_pair)]
cmp <- merge(cmp, fpt_prev, by = c("year", "seat"), all.x = TRUE)
cmp <- merge(cmp, setnames(copy(fpt), "fp_pair", "act_fp_top2"), by = c("year", "seat"), all.x = TRUE)
cmp[, `:=`(hit_model = pred_pair == act_pair, hit_pwin = pwin_pair == act_pair, hit_prev = prev_pair == act_pair,
           hit_prevfp = prev_fp_pair == act_pair, hit_actfp = act_fp_top2 == act_pair)]
q2 <- cmp[year >= 2007, .(seats = .N, model_n = sum(!is.na(hit_model)), model_hit = round(100 * mean(hit_model, na.rm = TRUE), 1),
                          pwin_hit = round(100 * mean(hit_pwin, na.rm = TRUE), 1),
                          prev_n = sum(!is.na(hit_prev)), prev_pair_hit = round(100 * mean(hit_prev, na.rm = TRUE), 1),
                          prevfp_hit = round(100 * mean(hit_prevfp, na.rm = TRUE), 1),
                          actfp_hit = round(100 * mean(hit_actfp, na.rm = TRUE), 1)), by = year][order(year)]
pr("Share of divisions where the guessed final pair equals the AEC's (pct; higher is better).")
print(q2)
both <- cmp[year >= 2010 & !is.na(hit_model) & !is.na(hit_prev), .(n = .N, model = round(100 * mean(hit_model), 1), prev_pair = round(100 * mean(hit_prev), 1))]
pr("Same seats, 2010-2025 pooled (model and previous-pair both defined):"); print(both)
pr("Actual final pairs by year (class pair, count):")
print(dcast(fin[year >= 2010, .N, by = .(year, act_pair)][N >= 1], act_pair ~ year, value.var = "N", fill = 0)[order(-`2025`)][1:12])
# model's own probability of the actual pair
tca <- fread(file.path(ROOT, "output/aef7-tcp-actual.csv"))
tca[, year := as.integer(sub("fed", "", pair))]
tca <- tca[grepl("^fed", pair)]
miss <- merge(cmp[year %in% c(2022, 2025) & hit_model == FALSE],
              tca[, .(year, seat, model_p_actual_pair = our_tcp_actual_freq)], by = c("year", "seat"), all.x = TRUE)
setorder(miss, year, seat)
fwrite(miss[, .(year, seat, pred_pair, act_pair, prev_pair, model_p_actual_pair, s1, s2, s3)], file.path(SCR, "q2_misses.csv"))
pr("\nMisses 2022 and 2025 (model top-two on predicted share vs AEC final pair):")
print(miss[, .(year, seat, pred_pair, act_pair, prev_pair, p_act = round(model_p_actual_pair, 3), s1 = round(s1, 1), s2 = round(s2, 1), s3 = round(s3, 1))], nrows = 200)
pr("\nActual pairs the model gave under 5% (aef7-tcp-actual freq) by year:")
print(tca[, .(n = .N, lt5 = sum(our_tcp_actual_freq < 0.05, na.rm = TRUE), lt50 = sum(our_tcp_actual_freq < 0.5, na.rm = TRUE),
              mean_p = round(mean(our_tcp_actual_freq, na.rm = TRUE), 3)), by = year][order(year)])
fwrite(cmp, file.path(SCR, "q2_all.csv"))

## model-implied flow error (fed2022, fed2025): uses model first prefs, so includes primary error
mf <- merge(tca[our_tcp_pick %in% c(f1, f2)][, .(year, seat, f1, f2, f2cp, pred = our_tcp_pred_pct, pick = our_tcp_pick, f1c = f1, f2c = f2)],
            pp[, .(year, seat, party, ours)], by = c("year", "seat"), allow.cartesian = TRUE)
mfw <- dcast(mf[party == f1c | party == f2c], year + seat + f1 + f2 + f2cp + pred + pick ~ ifelse(party == f1c, "o1", "o2"), value.var = "ours")
mfw <- mfw[f1 == "ALP" & f2 == "LNP" | f1 == "LNP" & f2 == "ALP"]
mfw[, `:=`(act_alp_2cp = ifelse(f1 == "ALP", f2cp, 100 - f2cp), o_alp = ifelse(f1 == "ALP", o1, o2), o_lnp = ifelse(f1 == "ALP", o2, o1))]
mfw[, pred_alp_2cp := ifelse(pick == "ALP", pred, 100 - pred)]
mfw[, model_flow := (pred_alp_2cp - o_alp) / (100 - o_alp - o_lnp) * 100]
ac <- merge(ALLF[year %in% c(2022, 2025), .(year, seat = div, act_flow = f, Nflow = N)], mfw[, .(year, seat, model_flow, pred_alp_2cp, act_alp_2cp)], by = c("year", "seat"))
ac[, d := act_flow - model_flow]
pr("\nModel-implied aggregate flow to ALP (from its predicted 2CP and predicted first prefs) vs actual flow, ALP-v-LNP seats:")
print(ac[, .(n = .N, rmse = round(sqrt(mean(d^2)), 1), sd = round(sd(d), 1), bias = round(mean(d), 1),
             rmse_2cp = round(sqrt(mean((act_alp_2cp - pred_alp_2cp)^2)), 1)), by = year])
## model flow vs persistence on exactly the same seats
cmpf <- merge(ac, RES[cls == "ALL" & spec == "F_nat_seat_st", .(year, seat = div, pred_F = pred)], by = c("year", "seat"))
cmpf[, `:=`(dF = act_flow - pred_F)]
print(cmpf[, .(n = .N, model_rmse = round(sqrt(mean(d^2)), 1), spec_F_rmse = round(sqrt(mean(dF^2)), 1)), by = year])
fwrite(ac, file.path(SCR, "q1_model_flow_vs_actual.csv"))

## the shipped flow noise
fu <- file.path(ROOT, "output/flow-uncertainty-sd.rds")
if (file.exists(fu)) { pr("\nflow-uncertainty-sd.rds:"); print(utils::str(readRDS(fu), max.level = 2)) }

## ---------------------------------------------------------------- Q3 booths
pr("\n=== Q3 booths (fed2022 and fed2025; other years lack booth-level 2CP on disk) ===")
booth_flow <- function(y) {
  fp <- fread(file.path(ROOT, sprintf("output/booths-fed%d.csv", y)))
  fp <- fp[booth_type == "ordinary"]
  fp[, cls := classify_party(party)]
  tc <- fread(file.path(ROOT, sprintf("output/booths/fed%d-booth-tcp.csv", y)))
  tc <- tc[vote_type == "ordinary"]
  tc[, cls := classify_party(party_raw)]
  pr(y, ": fp rows ", nrow(fp), " NA cls ", sum(is.na(fp$cls)), "; tcp rows ", nrow(tc), " NA cls ", sum(is.na(tc$cls)))
  ft <- fp[, .(tot = sum(votes), fa = sum(votes[cls == "ALP"]), fc = sum(votes[cls == "LNP"]),
               g = sum(votes[cls == "GRN"]), o = sum(votes[cls == "ONP"]), i = sum(votes[cls == "IND"]),
               r = sum(votes[cls == "OTH_RIGHT"]), x = sum(votes[cls == "OTH"])), by = .(district, booth)]
  tt <- tc[, .(ncls = uniqueN(cls), has = all(c("ALP", "LNP") %in% cls), ta = sum(votes[cls == "ALP"]), ttot = sum(votes)), by = .(district, booth)]
  tt <- tt[ncls == 2 & has == TRUE]
  b <- merge(ft, tt, by = c("district", "booth"))
  b[, rest := tot - fa - fc]
  b <- b[rest > 0]
  b[, f := (ta - fa) / rest * 100]
  b[, year := y]
  pr(y, ": ALP-v-LNP ordinary booths ", nrow(b), " in ", uniqueN(b$district), " seats; tcp total vs fp total diff ", sum(abs(b$ttot - b$tot)))
  b
}
B <- rbindlist(lapply(c(2022, 2025), booth_flow))
B[, f := pmin(100, pmax(0, f))]
B[, sf := sum(rest * f) / sum(rest), by = .(year, district)]
B[, nb := .N, by = .(year, district)]
B[, d := f - sf]
Bs <- B[nb >= 5]
samp <- Bs[, sum(rest * (f / 100 * (1 - f / 100) * 1e4 / rest)) / sum(rest)]
Q3a <- Bs[, .(booths = .N, seats = uniqueN(district), within_sd_w = round(sqrt(sum(rest * d^2) / sum(rest)), 1),
              sampling_sd = round(sqrt(sum(rest * (f / 100 * (1 - f / 100) * 1e4 / rest)) / sum(rest)), 1)), by = year]
Q3a[, excess_sd := round(sqrt(pmax(within_sd_w^2 - sampling_sd^2, 0)), 1)]
pr("\nWithin-seat spread of booth flow (pct points; booths of seats with 5+ ordinary booths, weighted by other-party votes):")
print(Q3a)
## stability across elections
w <- merge(B[year == 2022, .(district, booth, d22 = d, r22 = rest, f22 = f, nb22 = nb)],
           B[year == 2025, .(district, booth, d25 = d, r25 = rest, f25 = f, nb25 = nb, sf25 = sf)], by = c("district", "booth"))
w <- w[nb22 >= 5 & nb25 >= 5]
ww <- pmin(w$r22, w$r25)
wcor <- function(x, y, w) { mx <- sum(w * x) / sum(w); my <- sum(w * y) / sum(w); sum(w * (x - mx) * (y - my)) / sqrt(sum(w * (x - mx)^2) * sum(w * (y - my)^2)) }
slope <- sum(ww * w$d22 * w$d25) / sum(ww * w$d22^2)
pr(sprintf("\nBooths in both elections (same seat+booth name, 5+ booths): n=%d in %d seats. Weighted correlation of within-seat flow deviation 2022 vs 2025: %.2f; slope %.2f.",
           nrow(w), uniqueN(w$district), wcor(w$d22, w$d25, ww), slope))
big <- w[ww >= quantile(ww, 0.5)]; bw <- pmin(big$r22, big$r25)
pr(sprintf("  larger half of booths (n=%d): correlation %.2f, slope %.2f", nrow(big), wcor(big$d22, big$d25, bw), sum(bw * big$d22 * big$d25) / sum(bw * big$d22^2)))
## composition prediction: class national flows from the previous election (time-forward)
natc <- list("2022" = nat[year == 2019, setNames(nat, cls)], "2025" = nat[year == 2022, setNames(nat, cls)])
Bc <- copy(B)
Bc[, comp_pred := {
  nn <- natc[[as.character(year[1])]]
  (g * nn[["GRN"]] + o * nn[["ONP"]] + i * nn[["IND"]] + r * nn[["OTH_RIGHT"]] + x * nn[["OTH"]]) / rest
}, by = year]
Bc[, comp_dev := comp_pred - sum(rest * comp_pred) / sum(rest), by = .(year, district)]
pr("\nComposition model: booth flow predicted as sum over other-party first-pref shares x last election's national flow for that party.")
cm <- Bc[nb >= 5, {
  bt <- sum(rest * d * comp_dev) / sum(rest * comp_dev^2)
  r2 <- 1 - sum(rest * (d - bt * comp_dev)^2) / sum(rest * d^2)
  .(booths = .N, slope_on_comp_dev = round(bt, 2), r2_within_seat = round(r2, 3), wcor = round(wcor(d, comp_dev, rest), 2),
    raw_rmse = round(sqrt(sum(rest * d^2) / sum(rest)), 1), resid_rmse = round(sqrt(sum(rest * (d - bt * comp_dev)^2) / sum(rest)), 1))
}, by = year]
print(cm)
## seat-level: composition predicted seat flow vs actual seat flow
seatc <- Bc[nb >= 5, .(act = sf[1], comp_seat = sum(rest * comp_pred) / sum(rest), N = sum(rest)), by = .(year, district)]
pr("Seat flow (ordinary booths) vs the composition-only seat prediction (lower RMSE is better; pct points):")
print(seatc[, .(seats = .N, rmse = round(sqrt(mean((act - comp_seat)^2)), 1), rmse_demeaned = round(sd(act - comp_seat), 1), bias = round(mean(act - comp_seat), 1)), by = year])
fwrite(seatc, file.path(SCR, "q3_seat_comp.csv"))
## early-booth estimate error, small booths first
nightse <- function(fj, rst) {
  if (length(fj) < 3) return(0.25)
  wv <- rst / sum(rst)
  sqrt(sum(wv * (fj - sum(wv * fj))^2) * sum(wv^2) / max(1 - sum(wv^2), 1e-6))
}
early <- function(dd, q) {
  dd <- dd[order(tot)]
  cs <- cumsum(dd$rest) / sum(dd$rest)
  k <- which(cs >= q)[1]
  e <- dd[1:k]
  est <- sum(e$rest * e$f) / sum(e$rest)
  se <- max(nightse(e$f / 100, e$rest), 0.02) * 100
  data.table(k = k, est = est, se = se, truth = sum(dd$rest * dd$f) / sum(dd$rest))
}
er <- list()
for (q in c(0.1, 0.25, 0.5)) {
  r <- Bs[, early(.SD, q), by = .(year, district)]
  r[, `:=`(q = q, err = est - truth, z = (est - truth) / se)]
  er[[as.character(q)]] <- r
}
ER <- rbindlist(er)
pr("\nEarly-count error of the seat's aggregate flow: counted = smallest booths first until the share of other-party votes shown.")
pr("rmse/bias in pct points (lower is better); nominal_se = what night_tcp_obs reports (mean); z_sd should be 1.0 if the SE is right, above 1 = SE too small.")
print(ER[k >= 3, .(seats = .N, bias = round(mean(err), 2), rmse = round(sqrt(mean(err^2)), 2), nominal_se = round(mean(se), 2), z_sd = round(sd(z), 2),
                   z_sd_trim = round(sd(z[abs(z) < 5]), 2)), by = .(year, q)][order(year, q)])
pr("Same, all seats pooled by q, with booth counts: median booths counted")
print(ER[, .(seats = .N, med_booths = median(k), rmse = round(sqrt(mean(err^2)), 2), nominal_se = round(mean(se), 2), z_sd = round(sd(z), 2)), by = q])
fwrite(ER, file.path(SCR, "q3_early.csv"))
## small booth bias
sb <- Bs[, .(small = sum(rest[tot <= median(tot)] * d[tot <= median(tot)]) / sum(rest[tot <= median(tot)]),
             large = sum(rest[tot > median(tot)] * d[tot > median(tot)]) / sum(rest[tot > median(tot)])), by = .(year, district)]
pr("\nWeighted mean deviation of flow from the seat's flow, by booth size half (pct points):")
print(sb[, .(seats = .N, small_booths_mean_dev = round(mean(small, na.rm = TRUE), 2), large_booths_mean_dev = round(mean(large, na.rm = TRUE), 2),
             sd_small = round(sd(small, na.rm = TRUE), 2)), by = year])
## how often would the night model discard the count (pair seen in < pair_min = 0.2 of draws)?
pr("\nSeats where the model gave the AEC's final pair under 20% of draws (night_apply_tcp discards the count):")
print(tca[, .(n = .N, under20 = sum(our_tcp_actual_freq < 0.2, na.rm = TRUE), under50 = sum(our_tcp_actual_freq < 0.5, na.rm = TRUE)), by = year][order(year)])
print(tca[our_tcp_actual_freq < 0.2, .(year, seat, f1, f2, p = round(our_tcp_actual_freq, 3))][order(year, p)])
## composition-adjusted early estimate (oracle composition of uncounted booths, and prior-election booth composition)
Bp22 <- Bc[year == 2022, .(district, booth, comp22 = comp_pred)]
adj <- function(dd, q, usepri) {
  dd <- dd[order(tot)]
  cs <- cumsum(dd$rest) / sum(dd$rest)
  k <- which(cs >= q)[1]
  idx <- seq_len(nrow(dd)) <= k
  est <- sum(dd$rest[idx] * dd$f[idx]) / sum(dd$rest[idx])
  cc <- sum(dd$rest[idx] * dd$comp_pred[idx]) / sum(dd$rest[idx])
  cu_vec <- if (usepri) ifelse(is.na(dd$comp22), cc, dd$comp22) else dd$comp_pred
  wc <- dd$rest
  call <- (sum(wc[idx] * dd$comp_pred[idx]) + sum(wc[!idx] * cu_vec[!idx])) / sum(wc)
  data.table(est = est, est_adj = est + (call - cc), truth = sum(dd$rest * dd$f) / sum(dd$rest))
}
Bc2 <- merge(Bc[nb >= 5], Bp22, by = c("district", "booth"), all.x = TRUE)
ad <- list()
for (q in c(0.1, 0.25, 0.5)) {
  a1 <- Bc2[, adj(.SD, q, FALSE), by = .(year, district)][, `:=`(q = q, mode = "oracle_comp")]
  a2 <- Bc2[year == 2025, adj(.SD, q, TRUE), by = .(year, district)][, `:=`(q = q, mode = "prior_booth_comp")]
  ad[[length(ad) + 1]] <- a1; ad[[length(ad) + 1]] <- a2
}
AD <- rbindlist(ad)
pr("\nEarly seat-flow estimate, plain pooled counted flow vs composition-adjusted. RMSE pct points; lower is better.")
print(AD[, .(seats = .N, rmse_plain = round(sqrt(mean((est - truth)^2)), 2), rmse_adj = round(sqrt(mean((est_adj - truth)^2)), 2),
             bias_plain = round(mean(est - truth), 2), bias_adj = round(mean(est_adj - truth), 2)), by = .(mode, year, q)][order(mode, year, q)])
## ---------------------------------------------------------------- Q3b per-party booth flows from the AEC's flow-by-polling-place files (2004, 2007, 2010)
pr("\n=== Q3b per-party booth flows (AEC HouseTcpFlowByPP; events 12246=2004, 13745=2007, 15508=2010) ===")
ppdir <- file.path(SCR, "pp")
read_pp <- function(ev, yr) {
  zs <- list.files(file.path(ROOT, "external/reference/aec/tallyroom", ev), pattern = "^HouseTcpFlowByPPDownload.*\\.zip$", full.names = TRUE)
  ed <- file.path(ppdir, ev); dir.create(ed, showWarnings = FALSE, recursive = TRUE)
  for (z in zs) utils::unzip(z, exdir = ed)
  fs <- list.files(ed, pattern = "\\.csv$", full.names = TRUE)
  x <- rbindlist(lapply(fs, function(f) fread(f, skip = 1, showProgress = FALSE, colClasses = "character")), fill = TRUE)
  setnames(x, tolower(names(x)))
  x[, `:=`(year = yr, tcount = as.numeric(transfercount), ppid = as.integer(ppid))]
  x[, from_cls := classify_party(fromcandidatepartynm, fromcandidatepartyab)]
  x[, to_cls := classify_party(tocandidatepartynm, tocandidatepartyab)]
  x[fromcandidateid != "0" & ppid > 0]
}
pp <- rbindlist(lapply(list(c("12246", 2004), c("13745", 2007), c("15508", 2010)), function(a) read_pp(a[1], as.integer(a[2]))))
pr("flow-by-PP rows: ", nrow(pp), "; years ", paste(sort(unique(pp$year)), collapse = ","), "; NA from/to cls ", sum(is.na(pp$from_cls)), "/", sum(is.na(pp$to_cls)))
bf <- pp[to_cls %in% c("ALP", "LNP"), .(tA = sum(tcount[to_cls == "ALP"]), tC = sum(tcount[to_cls == "LNP"])), by = .(year, div = divisionnm, pp = ppnm, from_cls)]
bf[, `:=`(N = tA + tC, f = tA / (tA + tC) * 100)]
bf <- bf[from_cls %in% c("GRN", "ONP", "OTH_RIGHT", "IND", "OTH") & N > 0]
bf[, sf := sum(tA) / sum(N) * 100, by = .(year, div, from_cls)]
bf[, `:=`(d = f - sf, nb = .N), by = .(year, div, from_cls)]
bfs <- bf[N >= 20 & nb >= 5]
pr("Within-seat spread of booth flow to ALP by excluded-party class (booths with 20+ transfers; pct points):")
print(bfs[, .(booths = .N, within_sd_w = round(sqrt(sum(N * d^2) / sum(N)), 1),
              sampling_sd = round(sqrt(sum(N * (f / 100 * (1 - f / 100) * 1e4 / N)) / sum(N)), 1)), by = .(from_cls, year)][order(from_cls, year)])
st <- list()
for (cc in c("GRN", "ONP", "OTH_RIGHT")) for (pr_ in list(c(2004, 2007), c(2007, 2010))) {
  a <- bfs[from_cls == cc & year == pr_[1], .(div, pp, d1 = d, N1 = N)]
  b <- bfs[from_cls == cc & year == pr_[2], .(div, pp, d2 = d, N2 = N)]
  m <- merge(a, b, by = c("div", "pp"))
  if (nrow(m) < 50) next
  ww <- pmin(m$N1, m$N2)
  st[[length(st) + 1]] <- data.table(cls = cc, pair = paste(pr_, collapse = "->"), booths = nrow(m),
                                     wcor = round(wcor(m$d1, m$d2, ww), 2), slope = round(sum(ww * m$d1 * m$d2) / sum(ww * m$d1^2), 2))
}
pr("Do booths with a flow above their seat's flow last election stay above next election? (weighted correlation and slope of within-seat deviation)")
print(rbindlist(st))
pr("(Sampling noise in a booth's flow lowers both numbers: a booth with 40 Green votes has about 5 pct points of pure sampling spread.)")

pr("\nTallyroom dir contents (other agent's fetch): ", paste(list.files(file.path(ROOT, "external/reference/aec/tallyroom")), collapse = ", "))
pr("DONE")
