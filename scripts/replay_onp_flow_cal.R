# LIVE EFFECT of AUSPOL_ONP_FLOW_CAL by REPLAY: re-runs the simulation saved in a night state
# (output/night-state-vic-2026.rds, everything fit_seats_full.R handed simulate_seat_contests()) with the
# per-seat flow override as saved (switch 0) and with the One Nation calibration applied to it (switch 1).
# A replay, not a fresh forecast: the primaries, spreads and draws are the saved ones.
#
# Usage (from the worktree): Rscript scripts/replay_onp_flow_cal.R <root-with-output-and-external> <out_dir> [sims]
args <- commandArgs(TRUE)
root <- normalizePath(args[1]); out_dir <- args[2]; sims <- if (length(args) >= 3) as.integer(args[3]) else 20000L
options(auspol.root = root)
suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
st <- readRDS(file.path(root, "output", "night-state-vic-2026.rds"))
cat(sprintf("RPL0 state %s saved %s | %d seats | state sims %d | replay sims %d\n", st$pair, st$saved_at, nrow(st$shares), st$n_sims, sims))
stopifnot(is.null(st$htv_card) || !is.finite(st$htv_card$p))
swd <- st$swd; if (nrow(swd) < sims) stop("state holds ", nrow(swd), " statewide draws, fewer than ", sims)
swd <- swd[seq_len(sims), , drop = FALSE]
run <- function(ov) simulate_seat_contests(seat_cluster = st[["seat_cluster"]], cluster_rho = st[["cluster_rho"]],
  level_sd = st$level_sd, sd_override = st$sdo, level_mult = st$level_mult, st$shares, st$fm,
  party_sd = st$psd, statewide_draws = swd, seat_sd = st$seat_sd, n_sims = sims,
  breakout_p = st$bo$p, breakout_q = st$bo$q, coalition_split = st$coalition_split, error_q = st$error_q,
  smooth = st$smooth, seed = st$seed, party_cor = st$party_cor, shrink = st$shrink,
  conditional_override = ov, conditional_override_sd = attr(ov, "sd"),
  fallback_smooth = st$fb_smooth, shrink_k = st$shrink_k, flow_sd = st$flow_sd,
  surge_h = st$surge_h, surge_party = st$surge_party, surge_from_zero = st$surge_from_zero,
  surge_mu = st$surge_mu, surge_sd = st$surge_sd, keep_fp = FALSE)
ov0 <- st$htv_ov
TR <- fread(file.path(root, "output", "xgb-flows-v1-features.csv"), showProgress = FALSE)
hist <- TR[elections_before(TR$election, "vic2026")]
Sys.setenv(AUSPOL_ONP_FLOW_CAL = "1")
ov1 <- onp_flow_cal(ov0, hist, "vic2026")
Sys.setenv(AUSPOL_ONP_FLOW_CAL = "0")
attr(ov1, "sd") <- attr(ov0, "sd")
seats <- rownames(st$shares)
show <- c("Ripon", "Eildon", "Shepparton", "Morwell", "Lowan", "Ovens Valley", "Evelyn", "Melton", "Bass")
names(ov0) <- seats; names(ov1) <- seats
for (s in intersect(show, seats)) for (k in c("ALP|LNP+ONP", "GRN|ALP+LNP+ONP", "LNP|ALP+ONP", "GRN|ALP+ONP")) {
  a <- ov0[[s]][[k]]; b <- ov1[[s]][[k]]
  if (!is.null(a)) cat(sprintf("RPL1 %-13s %-16s off: %s | on: %s\n", s, k, paste(sprintf("%s %.1f", names(a), a), collapse = " "),
                               paste(sprintf("%s %.1f", names(b), b), collapse = " ")))
}
names(ov0) <- NULL; names(ov1) <- NULL
summ <- function(sim, lab) {
  tt <- sim$totals
  maj <- 45
  ex <- colMeans(tt)
  tc <- rbindlist(lapply(seq_len(ncol(sim$tcp_winner)), function(j) {
    w <- sim$tcp_winner[, j]; r <- sim$tcp_runnerup[, j]; sh2 <- sim$tcp_share[, j]
    k <- !is.na(w) & !is.na(r) & ((w == "ONP" & r == "LNP") | (w == "LNP" & r == "ONP"))
    k2 <- !is.na(w) & !is.na(r) & ((w == "ONP" & r == "ALP") | (w == "ALP" & r == "ONP"))
    data.table(seat = colnames(sim$tcp_winner)[j],
               p_onp_lnp = mean(k), onp_tcp_v_lnp = if (any(k)) stats::median(100 * ifelse(w[k] == "ONP", sh2[k], 1 - sh2[k])) else NA_real_,
               p_onp_alp = mean(k2), onp_tcp_v_alp = if (any(k2)) stats::median(100 * ifelse(w[k2] == "ONP", sh2[k2], 1 - sh2[k2])) else NA_real_,
               p_onp_win = mean(w == "ONP", na.rm = TRUE))
  }))
  tc[, arm := lab]
  list(head = data.table(arm = lab, ONP = ex[["ONP"]], LNP = ex[["LNP"]], ALP = ex[["ALP"]], GRN = if ("GRN" %in% names(ex)) ex[["GRN"]] else NA,
                         IND = if ("IND" %in% names(ex)) ex[["IND"]] else NA,
                         p_coal_maj = mean(tt[, "LNP"] >= maj), p_alp_maj = mean(tt[, "ALP"] >= maj),
                         p_hung = mean(apply(tt, 1, max) < maj)), seats = tc)
}
t0 <- Sys.time()
s0 <- summ(run(ov0), "switch 0 (as published)")
cat(sprintf("RPL2 switch 0 replay %.0fs\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
s1 <- summ(run(ov1), "switch 1 (calibrated)")
H <- rbind(s0$head, s1$head); print(H, digits = 3)
S <- merge(s0$seats, s1$seats, by = "seat", suffixes = c("_off", "_on"))
print(S[seat %in% show, .(seat, p_onp_lnp_off = round(p_onp_lnp_off, 2), onp_v_lnp_off = round(onp_tcp_v_lnp_off, 1),
                          onp_v_lnp_on = round(onp_tcp_v_lnp_on, 1), onp_v_alp_off = round(onp_tcp_v_alp_off, 1),
                          onp_v_alp_on = round(onp_tcp_v_alp_on, 1),
                          p_onp_win_off = round(p_onp_win_off, 3), p_onp_win_on = round(p_onp_win_on, 3))])
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
fwrite(H, file.path(out_dir, "replay-head.csv")); fwrite(S, file.path(out_dir, "replay-seats.csv"))
cat("RPL9 wrote", out_dir, "\n")
