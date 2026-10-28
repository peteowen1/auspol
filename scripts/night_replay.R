# ELECTION-NIGHT REPLAY FROM A SAVED STATE (issue #160, map #148).
#
#   1. Save the vic harness's pre-simulation state once (through quick_arm, so nothing lands in output/):
#        Rscript scripts/quick_arm.R "AUSPOL_NIGHT_DUMP=C:/path/night-state.rds" --pairs=vic2022
#      -> C:/path/night-state-vic2022.rds
#   2. Sweep fractions and settings in seconds each:
#        Rscript scripts/night_replay.R --state=C:/path/night-state-vic2022.rds --fracs=0.1,0.25,0.5 [--tcp=1] [--gap_k=5] [--early=interleaved] [--new_sd=1.5] [--sims=1000]
#
# For each fraction: the afternoon state is updated with the booths counted (R/night_update.R), simulated with
# the same arguments the harness passes, optionally conditioned on the VEC's 2CP flow, and scored: seat-winner
# log loss over the harness's scored seats (floor 0.5/n_sims, as quick_arm scores), and the chamber's 90% range.
# The same code path as the harness hook, so a fraction here must reproduce quick_arm's arm at that fraction.
#
# Check codes: NRP1 (inputs), NRP2 (per-fraction result).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")

a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
state_f <- flag("state"); if (is.null(state_f) || !file.exists(state_f)) stop("NRP1! --state=<file.rds> from AUSPOL_NIGHT_DUMP is required")
fracs <- as.numeric(strsplit(flag("fracs", "0,0.1,0.25,0.5,0.75,1"), ",")[[1]])
use_tcp <- identical(flag("tcp", "0"), "1")
early <- flag("early", "last"); new_sd <- as.numeric(flag("new_sd", "1"))
gap_k <- flag("gap_k", NULL); if (!is.null(gap_k)) gap_k <- as.numeric(gap_k)   # NULL = vote-type gap off
st <- readRDS(state_f)
sims <- as.integer(flag("sims", st$n_sims))
bl <- file.path("output", sprintf("booths-vic%d.csv", st$to)); br <- file.path("output", sprintf("booths-vic%d.csv", st$from))
bt <- file.path("output", "booths", sprintf("vic%d-booth-tcp.csv", st$to))
for (f in c(bl, br, if (use_tcp) bt)) if (!file.exists(f)) stop("NRP1! missing ", f)
L <- fread(bl, showProgress = FALSE); R <- fread(br, showProgress = FALSE); Tc <- if (use_tcp) fread(bt, showProgress = FALSE) else NULL
cat(sprintf("NRP1  %s: %d seats (%d scored), %d sims, 2CP %s, fractions %s\n", st$pair, nrow(st$shares), length(st$keep), sims,
            if (use_tcp) "ON" else "off", paste(fracs, collapse = ",")))

run_one <- function(fr) {
  shares <- st$shares; sdo <- st$sdo; swd <- st$swd; nu <- NULL
  if (fr > 0) {
    nu <- night_booth_update(shares, night_prior_sd(shares, st$level_sd, st$level_mult, sdo), fr, L, R, gap_k = gap_k, early = early, new_sd_mult = new_sd)
    shares <- nu$shares; sdo <- nu$sd; swd <- night_shrink_draws(swd, 1 - nu$resolved)
  }
  sim <- simulate_seat_contests(level_sd = st$level_sd, sd_override = sdo, level_mult = st$level_mult, shares, st$fm,
                                party_sd = st$psd, statewide_draws = swd, seat_sd = st$seat_sd, n_sims = sims,
                                breakout_p = st$bo$p, breakout_q = st$bo$q, coalition_split = st$coalition_split, error_q = st$error_q,
                                smooth = st$smooth, seed = st$seed, party_cor = st$party_cor, shrink = st$shrink,
                                conditional_override = st$htv_ov, conditional_override_sd = attr(st$htv_ov, "sd"),
                                fallback_smooth = st$fb_smooth, shrink_k = st$shrink_k, flow_sd = st$flow_sd,
                                surge_h = st$surge_h, surge_party = st$surge_party, surge_from_zero = st$surge_from_zero,
                                surge_mu = st$surge_mu, surge_sd = st$surge_sd)
  if (use_tcp && !is.null(nu)) sim <- night_apply_tcp(sim, night_tcp_obs(Tc, L, nu$units, shares))
  wp <- as.data.table(sim$win_prob)
  eps <- 0.5 / sims
  pa <- merge(data.table(seat = st$keep, actual = unname(st$truth[st$keep])), wp, by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]
  tot <- sim$totals
  rng <- function(p) if (p %in% colnames(tot)) { q <- stats::quantile(tot[, p], c(.05, .5, .95), type = 1); sprintf("%s %d-%d (%d)", p, q[1], q[3], q[2]) } else ""
  gp <- if (!is.null(nu) && !is.null(nu$type_gap)) paste(sprintf("%s/%s %+.1f (%d seats)", nu$type_gap$booth_type, nu$type_gap$cls, 100 * nu$type_gap$gap, nu$type_gap$n_seats)[nu$type_gap$cls %in% c("ALP", "LNP", "GRN")], collapse = ", ") else "none measured"
  list(frac = fr, logloss = mean(-log(pmax(pa$prob, eps))), n = nrow(pa), wp = wp, gaps = gp,
       chamber = paste(vapply(c("ALP", "LNP", "GRN", "IND"), rng, ""), collapse = "; "))
}
res <- lapply(fracs, run_one)
for (r in res) cat(sprintf("NRP2  %.2f counted: seat log loss %.4f over %d seats | 90%% seats %s\n", r$frac, r$logloss, r$n, r$chamber))
out <- sub("[.]rds$", sprintf("-replay%s.csv", if (use_tcp) "-tcp" else ""), state_f)
fwrite(rbindlist(lapply(res, function(r) cbind(frac = r$frac, r$wp))), out)
cat(sprintf("NRP2  win probabilities per fraction -> %s\n", out))
