# backtest_hare_clark.R -- time-forward party-seat backtest for the Hare-Clark elections (Tas, ACT).
#
#   Rscript scripts/backtest_hare_clark.R --region=tas --year=2025 [--sims=5000] [--flows=data|prior|neutral]
#   Rscript scripts/backtest_hare_clark.R --region=all --year=all          (every election with a predecessor)
#
# A SEPARATE scored path: not in all_election_pairs() or the six single-member harnesses.
# Needs output/hare-clark-units.csv, -act-flows.csv, -act-booths.csv (scripts/build_hare_clark_data.R).
#
# What it uses for election Y (polling day D), all knowable by D - 1:
#   * statewide: polls via the existing trend if load_polls(region) works, else the PREVIOUS result with a
#     time-forward spread, announced as FALLBACK (HCS1). Never election Y's own result.
#   * electorate base: election Y-1's class shares there (ACT 2016: notional from 2012 polling places).
#   * the nominated tickets of Y (who stood, how many candidates): public before polling day.
#   * noise SDs, minor-unit priors, naive hit rate: fitted on election pairs dated before D only.
#   * transfer rates: the latest ACT ballot file dated before D (ACT: the previous ACT election; Tasmania has
#     no ballot files, so it borrows the latest ACT one -- see the review doc). --flows=prior is the
#     uninformed sensitivity arm (30% exhaust, rest equal); --flows=neutral sets exhaust to 0.
# What it reads from Y itself: only the actual votes, for the ORACLE check (does the count reproduce the real
# seats from the real votes?) and the actual seats, for scoring.
#
# Output: output/hare-clark-backtest-<region><year>[-<flows>].csv (one row per electorate x class) and, for
# --year=all, output/hare-clark-backtest-summary[-<flows>].csv.
# CHECK CODES: HCB1 inputs, HCB2 base covers every electorate, HCB3 probabilities sum to 1, HCS1 statewide source.

suppressPackageStartupMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
# PUBLISHED DEFAULTS (2026-10-15), as in the seven single-member harnesses: every switch the caller left unset
# takes its published_flags.R value, including the ones read inside R/ by the poll and trend code this harness
# calls. Until then only AUSPOL_HC_DEFECTOR read its published value and everything else ran at inline defaults.
source("scripts/harness_defaults.R")

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default) {
  a <- grep(sprintf("^--%s=", name), args, value = TRUE)
  if (length(a)) sub(sprintf("^--%s=", name), "", a[1]) else default
}
region_arg <- arg("region", "all"); year_arg <- arg("year", "all")
n_sims <- as.integer(arg("sims", "5000")); flow_arm <- arg("flows", "data"); seed <- as.integer(arg("seed", "20261013"))
fine <- identical(arg("flowclass", "4"), "6"); use_leak <- identical(arg("leak", "0"), "1")
count_arm <- arg("count", "block"); tas_src <- arg("tasflows", "tec")
stopifnot(flow_arm %in% c("data", "prior", "neutral"), n_sims >= 100, count_arm %in% c("block", "candidate"),
          tas_src %in% c("tec", "act"))
arm_tag <- paste0(if (flow_arm == "data") "" else paste0("-", flow_arm), if (fine) "-fc6" else "", if (use_leak) "-leak" else "",
                  if (count_arm == "candidate") "-cand" else "", if (tas_src == "act") "-tasact" else "")

units <- fread("output/hare-clark-units.csv")
flows_all <- fread("output/hare-clark-act-flows.csv")
booths <- fread("output/hare-clark-act-booths.csv")
cat(sprintf("HCB1  units %d rows, %d elections; ACT flow rows %d; booth rows %d\n", nrow(units),
            uniqueN(units[, .(region, year)]), nrow(flows_all), nrow(booths)))
stopifnot(nrow(units) > 400, nrow(flows_all) > 1000)
units[, cls := hc_score_class(class)]
units[, fcls := hc_flow_class(class, fine)]
leak_all <- fread("output/hare-clark-act-leak.csv")
cands_all <- fread("output/hare-clark-candidates.csv")
tas_fl <- if (file.exists("output/hare-clark-tas-flows.csv")) fread("output/hare-clark-tas-flows.csv") else NULL
ballots_all <- if (count_arm == "candidate") fread("output/hare-clark-act-ballots.csv") else NULL
el <- hare_clark_elections()
todo <- el[!is.na(el$prev) & (region_arg == "all" | el$region == region_arg) &
             (year_arg == "all" | el$year == as.integer(year_arg)) & !(el$region == "tas" & el$year == 2006L), ]
if (!nrow(todo)) stop("nothing to run for --region=", region_arg, " --year=", year_arg)

# time-forward hit rate of "same seats as last time", shrunk toward 0.6 with 20 pseudo-cells
naive_hit_rate <- function(before) {
  pr <- el[!is.na(el$prev) & el$date < before, ]
  hits <- 0; n <- 0
  for (i in seq_len(nrow(pr))) {
    a <- units[region == pr$region[i] & year == pr$prev[i], .(s = sum(seats_won), N = seats[1]), by = .(electorate, cls)]
    b <- units[region == pr$region[i] & year == pr$year[i], .(s = sum(seats_won), N = seats[1]), by = .(electorate, cls)]
    m <- merge(a, b, by = c("electorate", "cls"))
    m <- m[N.x == N.y]
    hits <- hits + sum(m$s.x == m$s.y); n <- n + nrow(m)
  }
  c(rate = (20 * 0.6 + hits) / (20 + n), n = n)
}

run_one <- function(rg, yr) {
  e_row <- el[el$region == rg & el$year == yr, ]
  py <- e_row$prev; ed <- e_row$date
  cat(sprintf("\n================ %s%d (polling day %s; swings from %s%d) ================\n", rg, yr,
              as.character(ed), rg, py))
  tg <- units[region == rg & year == yr]
  pv <- units[region == rg & year == py]
  sh_prev <- hc_class_shares(pv)
  prev_state <- setNames(sh_prev$state$share, sh_prev$state$cls)[c("ALP", "LNP", "GRN", "OTH")]
  # electorate base
  if (rg == "act" && yr == 2016L) {
    base <- hc_notional_from_booths(booths, units, 2012L, 2016L)
    cat(sprintf("HCB2  act2016 base is NOTIONAL from 2012 ordinary polling places (%.1f%% of 2012 booth votes mapped)\n",
                100 * attr(base, "coverage")))
  } else {
    base <- sh_prev$elec[, c("electorate", "cls", "share")]
  }
  miss <- setdiff(unique(tg$electorate), base$electorate)
  if (length(miss)) stop("HCB2 FAIL no base for electorate(s) ", paste(miss, collapse = ", "))
  cat(sprintf("HCB2  PASS base covers all %d electorates\n", uniqueN(tg$electorate)))
  # minor-unit previous shares
  pv[, share := 100 * votes / sum(votes), by = electorate]
  unit_prev <- as.data.frame(pv[cls == "OTH", .(electorate, unit, share)])
  # time-forward constants
  nsd <- hc_noise_sd(units, ed); ssd <- hc_state_sd(units, ed); upri <- hc_unit_priors(units, ed)
  cat(sprintf("HCB1  electorate noise SD (pts, time-forward, n deviations): %s; pooled %.2f\n",
              paste(sprintf("%s %.2f (n=%d)", names(nsd), nsd, attr(nsd, "n")), collapse = ", "), attr(nsd, "pooled")))
  cat(sprintf("HCB1  statewide fallback SD: %s\n", paste(sprintf("%s %.2f (n=%d)", names(ssd), ssd, attr(ssd, "n")), collapse = ", ")))
  cat(sprintf("HCB1  minor units: new-entrant prior %.2f pts (n=%d), log-share SD %.2f (n=%d)\n",
              upri$p_new, upri$n_new, upri$sd_log, upri$n_ret))
  # transfer rates
  act_before <- el[el$region == "act" & el$date < ed, ]
  fy <- if (nrow(act_before)) max(act_before$year) else NA_integer_
  if (flow_arm == "prior" || is.na(fy)) {
    fl <- hc_flows_prior(0.3); fsrc <- "uninformed prior (30% exhaust, rest equal)"
  } else {
    fl <- hc_flows_from_ballots(as.data.frame(flows_all[year == fy]), fine = fine); fsrc <- sprintf("ACT %d ballots", fy)
    if (flow_arm == "neutral") { fl[, 1:4] <- fl[, 1:4] / rowSums(fl[, 1:4]); fl[, "EXH"] <- 0; fsrc <- paste(fsrc, "with exhaust set to 0") }
  }
  lk_all <- if (!is.na(fy)) hc_leak_from_ballots(as.data.frame(leak_all[year == fy]), fine = fine) else
    stats::setNames(rep(0.2, 6), c("ALP", "LNP", "GRN", "RGT", "IND", "OTH"))
  # Tasmania: its own count exports where one is dated before this election (2024 -> tas2025)
  if (rg == "tas" && tas_src == "tec" && flow_arm == "data" && !is.null(tas_fl) && any(tas_fl$year < yr)) {
    ty <- max(tas_fl$year[tas_fl$year < yr])
    fl <- hc_flows_from_counts(as.data.frame(tas_fl[year == ty]), fine = fine)
    lk_all <- attr(fl, "leak")
    fsrc <- sprintf("Tasmanian TEC %d distribution of preferences", ty)
  }
  lk <- if (use_leak) lk_all else NULL
  if (fine) fsrc <- paste(fsrc, "(six transfer classes)")
  if (!is.null(lk)) fsrc <- paste(fsrc, "+ ticket leakage")
  cat(sprintf("HCB1  transfer rates: %s\n", fsrc)); print(round(fl, 3))
  if (!is.null(lk)) { cat("HCB1  ticket leakage:\n"); print(round(lk, 3)) }
  # statewide
  sw <- hc_statewide_draws(rg, yr, ed, prev_state, ssd, n_sims = n_sims, seed = seed)
  target <- as.data.frame(tg[, .(electorate, unit, cls, fcls, ncand, seats)])
  # candidate-level count inputs, per electorate
  cand <- NULL; slot_actual <- NULL
  if (count_arm == "candidate") {
    spri <- hc_split_priors(cands_all, ed)
    cat(sprintf("HCB1  within-ticket split: lambda %.2f, log-share SD %.2f (%d ticket pairs, time-forward)\n",
                spri$lambda, spri$sdlog, spri$n_pairs))
    pc <- cands_all[region == rg & year == py]
    prev_class <- setNames(pv$class, pv$unit); prev_class <- prev_class[!duplicated(names(prev_class))]
    cand <- list()
    for (e in unique(target$electorate)) {
      tu <- target[target$electorate == e, ]
      sp <- hc_split_expected(tu, as.data.frame(pc[electorate == e, .(unit, votes)]),
                              as.data.frame(pc[, .(unit, electorate, votes)]), spri)
      if (rg == "act") {
        b <- if (yr == 2016L) ballots_all[year == py] else ballots_all[year == py & electorate == e]
        bl <- hc_prepare_ballots(b$seq, b$n, tu, prev_class)
      } else {
        bb <- base[base$electorate == e, ]
        ush <- setNames(bb$share[match(tu$cls, bb$cls)], tu$unit)
        oth <- tu$cls == "OTH"
        ush[oth] <- vapply(tu$unit[oth], function(un) {
          h <- unit_prev$share[unit_prev$electorate == e & unit_prev$unit == un]
          if (length(h) == 1L) h else upri$p_new }, numeric(1))
        bl <- hc_synthetic_ballots(tu, ush, fl, lk_all)
      }
      cand[[e]] <- list(ballots = bl, split = sp, sdlog = spri$sdlog)
    }
  }
  # AUSPOL_HC_DEFECTOR (published "1" since 2026-10-14): a sitting member standing for another party takes
  # rate x previous personal vote with them. The cases are listed either way (HCM2) so "0" shows what "1" would do.
  # harness_defaults.R (sourced at the top) has already set it to the published value when the caller did not.
  dfx <- hc_defector_moves(cands_all, rg, yr, py)
  .hcd <- Sys.getenv("AUSPOL_HC_DEFECTOR", "0")
  if (!identical(.hcd, "1")) dfx <- NULL
  cat(sprintf("HCM2  %s%d AUSPOL_HC_DEFECTOR = %s\n", rg, yr, .hcd))
  pr <- hc_simulate(target, base, unit_prev, sw$draws, prev_state, nsd, upri, fl, leak = lk, seed = seed + 1L, cand = cand, defect = dfx)
  ps <- aggregate(pr$prob, pr[, c("electorate", "cls")], sum)
  stopifnot(all(abs(ps$x - 1) < 1e-9))
  cat("HCB3  PASS every electorate x class distribution sums to 1\n")
  actual <- tg[, .(seats_won = sum(seats_won)), by = .(electorate, cls)]
  full <- CJ(electorate = unique(tg$electorate), cls = c("ALP", "LNP", "GRN", "OTH"))
  actual <- merge(full, actual, all.x = TRUE); actual[is.na(seats_won), seats_won := 0L]
  sc <- as.data.table(hc_log_loss(pr, actual))
  # naive baseline
  hr <- naive_hit_rate(ed)
  prev_seats <- pv[, .(s = sum(seats_won)), by = .(electorate, cls)]
  nv <- rbindlist(lapply(unique(tg$electorate), function(e) {
    N <- tg[electorate == e, seats[1]]
    if (e %in% prev_seats$electorate) {
      ps_e <- setNames(prev_seats[electorate == e]$s, prev_seats[electorate == e]$cls)
      d <- hc_naive(ps_e, N, hit = hr[["rate"]], prev_total = pv[electorate == e, seats[1]])
    } else {          # new electorate: territory-wide seat shares
      tot <- prev_seats[, .(s = sum(s)), by = cls]
      d <- hc_naive(setNames(tot$s, tot$cls), N, hit = hr[["rate"]])
    }
    data.table(electorate = e, d)
  }))
  ns <- as.data.table(hc_log_loss(as.data.frame(nv), actual))
  sc[ns, `:=`(naive_logloss = i.logloss, naive_mode = i.mode), on = c("electorate", "cls")]
  # oracle: the actual votes through the same count
  if (count_arm == "candidate") {
    ct <- cands_all[region == rg & year == yr]
    ct[, rank := frank(-votes, ties.method = "first"), by = .(electorate, unit)]
    oc <- list(); oo <- list()
    for (e in unique(target$electorate)) {
      tu <- target[target$electorate == e, ]
      bl <- cand[[e]]$ballots
      if (rg == "tas") bl <- hc_synthetic_ballots(tu, setNames(tg[electorate == e]$votes, tg[electorate == e]$unit), fl, lk_all)
      sv <- ct[electorate == e]$votes[match(paste(bl$slots$unit, bl$slots$rank), paste(ct[electorate == e]$unit, ct[electorate == e]$rank))]
      el1 <- hc_candidate_count(bl, sv, tu$seats[1])
      oc[[e]] <- data.table(electorate = e, cls = bl$slots$cls, won = el1)
      if (rg == "act") {
        b <- ballots_all[year == yr & electorate == e]
        pc_own <- setNames(tg$class, tg$unit); pc_own <- pc_own[!duplicated(names(pc_own))]
        bo <- hc_prepare_ballots(b$seq, b$n, tu, pc_own)
        oo[[e]] <- data.table(electorate = e, cls = bo$slots$cls, won = hc_candidate_count(bo, bo$B, tu$seats[1]))
      }
    }
    orc <- rbindlist(oc)[, .(oracle = sum(won)), by = .(electorate, cls)]
    sc[orc, oracle := i.oracle, on = c("electorate", "cls")]; sc[is.na(oracle), oracle := 0]
    if (rg == "act") {
      orc2 <- rbindlist(oo)[, .(oracle_own = sum(won)), by = .(electorate, cls)]
      sc[orc2, oracle_own := i.oracle_own, on = c("electorate", "cls")]; sc[is.na(oracle_own), oracle_own := 0]
    } else sc[, oracle_own := NA_real_]
  } else {
  orc <- tg[, {
    w1 <- hc_party_count(votes, seats[1], fcls, fl, ncand = ncand, leak = lk)
    .(cls = cls, won = w1)
  }, by = electorate][, .(oracle = sum(won)), by = .(electorate, cls)]
  sc[orc, oracle := i.oracle, on = c("electorate", "cls")]; sc[is.na(oracle), oracle := 0]
  if (rg == "act") {
    fl_in <- hc_flows_from_ballots(as.data.frame(flows_all[year == yr]), fine = fine)
    orc2 <- tg[, .(cls = cls, won = hc_party_count(votes, seats[1], fcls, fl_in, ncand = ncand, leak = lk)), by = electorate][
      , .(oracle_own = sum(won)), by = .(electorate, cls)]
    sc[orc2, oracle_own := i.oracle_own, on = c("electorate", "cls")]; sc[is.na(oracle_own), oracle_own := 0]
  } else sc[, oracle_own := NA_real_]
  }
  # statewide totals
  dr <- attr(pr, "draws")
  tot_draw <- Reduce(`+`, dr)
  tot_act <- actual[, .(s = sum(seats_won)), by = cls]
  st_ll <- vapply(c("ALP", "LNP", "GRN", "OTH"), function(k)
    -log(max(mean(tot_draw[, k] == tot_act[cls == k]$s), 1e-6)), numeric(1))
  sc[, `:=`(region = rg, year = yr, seats = tg$seats[match(electorate, tg$electorate)],
            statewide_source = sw$source, flows = fsrc, naive_hit = hr[["rate"]])]
  setcolorder(sc, c("region", "year", "electorate", "seats", "cls", "seats_won", "mode", "p_actual", "logloss",
                    "naive_mode", "naive_logloss", "oracle", "oracle_own"))
  fwrite(sc, sprintf("output/hare-clark-backtest-%s%d%s.csv", rg, yr, arm_tag))
  # per-electorate table
  cat("\nPer electorate -- seats won by class (actual / model's most likely / naive / oracle). Log loss: lower is better.\n")
  pe <- sc[, .(seats = seats[1],
               actual = paste(sprintf("%s%d", substr(cls, 1, 1), seats_won), collapse = " "),
               model = paste(sprintf("%s%d", substr(cls, 1, 1), mode), collapse = " "),
               naive = paste(sprintf("%s%d", substr(cls, 1, 1), naive_mode), collapse = " "),
               oracle = paste(sprintf("%s%d", substr(cls, 1, 1), oracle), collapse = " "),
               oracle_hit = all(oracle == seats_won),
               ll_model = round(mean(logloss), 3), ll_naive = round(mean(naive_logloss), 3)), by = electorate]
  print(pe)
  cat(sprintf("Statewide seat totals: actual %s; P(actual total) %s\n",
              paste(sprintf("%s %d", tot_act$cls, tot_act$s), collapse = ", "),
              paste(sprintf("%s %.2f", names(st_ll), exp(-st_ll)), collapse = ", ")))
  data.table(region = rg, year = yr, electorates = uniqueN(sc$electorate), seats = sum(pe$seats),
             statewide = sw$source, flows = fsrc,
             ll_model = mean(sc$logloss), ll_naive = mean(sc$naive_logloss),
             seats_right_model = sum(pmin(sc$mode, sc$seats_won)), seats_right_naive = sum(pmin(sc$naive_mode, sc$seats_won)),
             cells_exact_model = sum(sc$mode == sc$seats_won), cells_exact_naive = sum(sc$naive_mode == sc$seats_won),
             cells = nrow(sc),
             oracle_elec_hits = sum(pe$oracle_hit), oracle_seats_right = sum(pmin(sc$oracle, sc$seats_won)),
             oracle_own_elec_hits = if (rg == "act") sum(sc[, all(oracle_own == seats_won), by = electorate]$V1) else NA_integer_,
             ll_statewide_model = mean(st_ll))
}

out <- rbindlist(lapply(seq_len(nrow(todo)), function(i) run_one(todo$region[i], todo$year[i])))
cat("\n================ SUMMARY ================\n")
cat("Mean log loss of the probability given to each (electorate, class) actual seat count; lower is better.\n")
cat("seats_right = seats whose party the most likely allocation got right (of 'seats'); cells_exact = electorate x class\n")
cat("counts called exactly (of 'cells'); oracle = the count run on the ACTUAL votes (electorates fully reproduced).\n")
print(out[, .(region, year, electorates, seats, statewide = sub(":.*", "", statewide), ll_model = round(ll_model, 3),
              ll_naive = round(ll_naive, 3), seats_right_model, seats_right_naive, cells_exact_model, cells_exact_naive,
              cells, oracle_elec_hits, oracle_seats_right, oracle_own_elec_hits)])
if (nrow(out) > 1L) {
  cat(sprintf("POOLED  %d elections, %d cells: model %.3f vs naive %.3f (mean per-election difference %+.3f, SE %.3f clustered on election)\n",
              nrow(out), sum(out$cells), weighted.mean(out$ll_model, out$cells), weighted.mean(out$ll_naive, out$cells),
              mean(out$ll_model - out$ll_naive), sd(out$ll_model - out$ll_naive) / sqrt(nrow(out))))
  fwrite(out, sprintf("output/hare-clark-backtest-summary%s.csv", arm_tag))
}
