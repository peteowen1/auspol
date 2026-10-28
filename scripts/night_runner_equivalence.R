# Does the runner's live-feed path (counted-unit table) reproduce scripts/night_replay.R at the same fraction?
#
#   Rscript scripts/night_runner_equivalence.R --state=<state-vic2022.rds> [--frac=0.5] [--replay-csv=<night_replay.R output with --tcp=1 --gap_k=5>]
#
# (A) EXACT: the whole 2022 booth table plus the list of units counted at `frac`, denominator "table": must equal
#     the replay (win probabilities and every posterior share) to numerical identity.
# (B) LIVE-LIKE: the votes of every uncounted unit set to 0 (what a real feed shows) and the "projected" denominator:
#     not expected to be identical (the final total is unknown live); the gap is reported.
# Check codes: NEQ1 (inputs), NEQ2 (verdict).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")   # the published configuration, as night_replay.R and the harnesses apply it
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
st <- readRDS(flag("state")); fr <- as.numeric(flag("frac", "0.5"))
L <- fread(sprintf("output/booths-vic%d.csv", st$to), showProgress = FALSE); R <- fread(sprintf("output/booths-vic%d.csv", st$from), showProgress = FALSE)
Tc <- fread(sprintf("output/booths/vic%d-booth-tcp.csv", st$to), showProgress = FALSE)
cat(sprintf("NEQ1  %s: %d seats, live rows %d, reference rows %d, 2CP rows %d, frac %.2f\n", st$pair, nrow(st$shares), nrow(L), nrow(R), nrow(Tc), fr))

# which units the replay counts at this fraction (the same function night_replay.R calls)
nu0 <- night_booth_update(st$shares, night_prior_sd(st$shares, st$level_sd, st$level_mult, st$sdo), fr, L, R, gap_k = 5, early = "last")
cnt <- rbindlist(lapply(names(nu0$units), function(s) data.table(district = s, unit = nu0$units[[s]])))
cat(sprintf("NEQ1  replay counts %d units in %d seats\n", nrow(cnt), nrow(cnt[, .N, by = "district"])))

full <- copy(L)[, list(district, booth, booth_type, party, votes)]
conv_a <- list(live = full, counted = cnt, tcp = Tc[, list(district, booth, vote_type, party_raw, votes)], unmapped = character())
ra <- night_run_update(st, conv_a, R, gap_k = 5, total = "table")

un <- ifelse(L$booth_type == "ordinary", L$booth, L$booth_type)
is_c <- paste(L$district, un) %in% paste(cnt$district, cnt$unit)
zer <- copy(full); zer[!is_c, votes := 0]
conv_b <- list(live = zer, counted = cnt, tcp = conv_a$tcp, unmapped = character())
rb <- night_run_update(st, conv_b, R, gap_k = 5, total = "projected")

csv <- flag("replay-csv")
if (is.null(csv)) stop("NEQ1! --replay-csv= is required (run night_replay.R --fracs=<frac> --tcp=1 --gap_k=5 first)")
rp <- fread(csv); rp <- rp[abs(frac - fr) < 1e-9]
if (!nrow(rp)) stop("NEQ1! replay csv has no rows at frac ", fr)
cmp <- function(res, label) {
  w <- as.data.table(res$sim$win_prob)
  m <- merge(rp[, list(seat, party, p_replay = prob)], w[, list(seat, party, p_run = prob)], by = c("seat", "party"), all = TRUE)
  m[is.na(p_replay), p_replay := 0]; m[is.na(p_run), p_run := 0]
  d <- max(abs(m$p_replay - m$p_run))
  sd_diff <- max(abs(res$shares - ra$shares))
  cat(sprintf("NEQ2  %s: %d (seat, party) pairs, max |win prob difference| %.6f, max |posterior share difference vs A| %.6f, mean counted %.3f\n",
              label, nrow(m), d, sd_diff, mean(res$nu$counted)))
  invisible(d)
}
da <- cmp(ra, "A exact (full table + counted list, table denominator)")
db <- cmp(rb, "B live-like (uncounted votes zeroed, projected denominator)")
cat(sprintf("NEQ2  replay mean counted %.3f\n", mean(nu0$counted)))
cat(sprintf("NEQ2  VERDICT A: %s\n", if (da < 1e-9) "EQUAL to night_replay.R" else "DIFFERENT"))
quit(status = if (da < 1e-9) 0L else 1L)
