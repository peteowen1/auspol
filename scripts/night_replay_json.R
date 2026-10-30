# NIGHT JSON SERIES FROM A SAVED STATE (issue #162, map #148): the files the live page reads, for a replayed night.
#
#   Rscript scripts/night_replay_json.R --state=output/nightstate/state-vic2022.rds [--fracs=0,0.05,0.1,0.25,0.5,0.75,1]
#       [--out=output/night-replay] [--tcp=1] [--gap_k=5] [--early=interleaved] [--sims=<state's>] [--base=<forecast json>] [--live=<booth table> --prev=<previous booth table> --tcp-file=<booth 2CP>]
#
# Same update and simulation as scripts/night_replay.R (booth update at each fraction, then the VEC 2CP conditioning), but each
# fraction is turned into a document by night_build_json(), the function the runner uses, so the page is tested on the real shape.
# Writes <out>/night-f<NNN>.json (NNN = fraction x 1000) and <out>/night-index.json:
#   {"election","kind":"replay","files":[{"frac","file","built_at","mean_counted_pct"}]}.
# Differences from a live document (only these): `built_at` is a synthetic Sydney clock time (6pm + 4 hours x fraction, on
# polling day) so the page's "last updated" reads like a night; `night.snapshot` is "replay-f<NNN>"; `night.counted_denominator`
# is "table" (the replay counts a fraction of the 2022 booth table, not an enrolment-based share).
# Needs output/booths-vic<to>.csv, output/booths-vic<from>.csv and, with --tcp=1, output/booths/vic<to>-booth-tcp.csv
# (gitignored; copy them from the main checkout).
# Check codes: NJ1 (inputs), NJ2 (a fraction updated no seat), NJ3 (written).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")

a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
state_f <- flag("state"); if (is.null(state_f) || !file.exists(state_f)) stop("NJ1! --state=<file.rds> from AUSPOL_NIGHT_DUMP is required")
fracs <- as.numeric(strsplit(flag("fracs", "0,0.05,0.1,0.25,0.5,0.75,1"), ",")[[1]])
out_dir <- flag("out", "output/night-replay"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
use_tcp <- !identical(flag("tcp", "1"), "0")
early <- flag("early", "interleaved"); gap_k <- as.numeric(flag("gap_k", "5"))
base <- if (!is.null(flag("base"))) jsonlite::fromJSON(flag("base"), simplifyVector = FALSE) else NULL
st <- readRDS(state_f); sims <- as.integer(flag("sims", st$n_sims))
# Any election: the region comes from the state's pair label ("nsw2023" -> "nsw"); --live, --prev and --tcp-file
# override the default paths (booth tables in the night schema: district, booth, booth_type, party, votes).
region <- sub("[0-9]+$", "", if (is.null(st$pair)) "vic" else st$pair)
bl <- flag("live", file.path("output", sprintf("booths-%s%d.csv", region, st$to)))
br <- flag("prev", file.path("output", sprintf("booths-%s%d.csv", region, st$from)))
bt <- flag("tcp-file", file.path("output", "booths", sprintf("%s%d-booth-tcp.csv", region, st$to)))
for (f in c(bl, br, if (use_tcp) bt)) if (!file.exists(f)) stop("NJ1! missing ", f)
L <- fread(bl, showProgress = FALSE); R <- fread(br, showProgress = FALSE); Tc <- if (use_tcp) fread(bt, showProgress = FALSE) else NULL
cat(sprintf("NJ1  %s: %d seats, %d sims, 2CP %s, early=%s, gap_k=%s, fractions %s\n", st$pair, nrow(st$shares), sims,
            if (use_tcp) "ON" else "off", early, gap_k, paste(fracs, collapse = ",")))

index <- list()
for (fr in fracs) {
  shares <- st$shares; sdo <- st$sdo; swd <- st$swd; nu <- NULL
  if (fr > 0) {
    nu <- night_booth_update(shares, night_prior_sd(shares, st$level_sd, st$level_mult, sdo), fr, L, R, gap_k = gap_k, early = early)
    if (nu$n_updated == 0L) stop("NJ2! replay at ", fr, " updated no seat: booth districts do not match the saved state's seats")
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
  n_tcp <- 0L
  if (use_tcp && !is.null(nu)) { obs <- night_tcp_obs(Tc, L, nu$units, shares); n_tcp <- nrow(obs); sim <- night_apply_tcp(sim, obs) }
  if (is.null(nu)) nu <- list(counted = setNames(rep(0, nrow(st$shares)), rownames(st$shares)), fallback_projected = character())
  res <- list(sim = sim, nu = nu, shares = shares, sd = sdo, matched = rownames(shares), n_updated = if (is.null(nu$n_updated)) 0L else nu$n_updated,
              n_tcp = n_tcp, denominator = "table", n_placeholder = 0L, n_unlisted = 0L)
  tag <- sprintf("f%03d", round(fr * 1000))
  doc <- night_build_json(st, res, list(file = paste0("replay-", tag), stamp = tag, archived = FALSE), base = base,
                          election = sprintf("%s%d-replay", region, st$to))
  doc$built_at <- format(as.POSIXct("2026-11-28 18:00:00", tz = "Australia/Melbourne") + 4 * 3600 * fr, "%Y-%m-%dT%H:%M:%S%z", tz = "Australia/Melbourne")
  f <- night_publish_json(doc, file.path(out_dir, sprintf("night-%s.json", tag)), min_seats = nrow(st$shares))
  index[[length(index) + 1]] <- list(frac = fr, file = basename(f), built_at = doc$built_at, mean_counted_pct = doc$night$mean_counted_pct)
  cat(sprintf("NJ3  %.3f -> %s (%.0f KB) | mean counted %.1f%% | ALP %.1f LNP %.1f | 2CP seats %d\n", fr, f, file.size(f) / 1024,
              doc$night$mean_counted_pct, doc$chamber$parties$ALP$expected, doc$chamber$parties$LNP$expected, n_tcp))
}
writeLines(jsonlite::toJSON(list(election = sprintf("%s%d-replay", region, st$to), kind = "replay", files = index), auto_unbox = TRUE, digits = 4),
           file.path(out_dir, "night-index.json"))
cat(sprintf("NJ3  index -> %s\n", file.path(out_dir, "night-index.json")))
