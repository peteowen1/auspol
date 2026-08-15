# Build the public Victoria 2026 forecast page.
#
# Emits output/vic-page-data.json (every figure the page shows) and splices it
# into scripts/page-template.html to produce output/victoria-2026.html. The
# page carries no external requests, so it works offline and inside a strict
# content-security policy.
#
# Requires fit_projection.R to have run (it reads output/projection-mix.csv).
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/build_page.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(jsonlite))

stopifnot(file.exists("scripts/page-template.html"))

# The page is assembled from files earlier stages wrote. Checking only that
# they EXIST lets a leftover from a previous run be published under today's
# date: the header stamp is computed live, so it would read as current while
# the trend chart, the mix table and the scorecard came from old numbers.
# Requiring each input to be newer than the poll data it was derived from
# catches that without needing a run-id system.
INPUTS <- c("output/projection-mix.csv", "output/trend-vic-2026.csv",
            "output/pollster-scorecard.csv")
missing <- INPUTS[!file.exists(INPUTS)]
if (length(missing)) {
  stop("Missing pipeline output: ", paste(missing, collapse = ", "),
       ". Run scripts/run_all.R (fit_projection.R must precede this).")
}
poll_mtime <- file.info(anchor_data_path("poll-data-vic.csv"))$mtime
stale_inputs <- INPUTS[file.info(INPUTS)$mtime < poll_mtime]
if (length(stale_inputs)) {
  stop("These outputs predate the poll data and would publish old numbers under today's date: ",
       paste(stale_inputs, collapse = ", "), ". Re-run scripts/run_all.R.")
}

cycles <- load_election_cycles()
end_date <- cycles[region == "vic" & year == 2026, end]
days_out <- as.integer(end_date - Sys.Date())

# --- most recent change of government leader, and how much polling has seen it
#
# The model has no leader term: a change reaches the forecast only through the
# polls taken after it. That is defensible — a leader-change indicator was
# tested as a fundamentals predictor on 56 elections and came back at p = 0.52
# (see docs/NEXT-STEPS.md) — but it means a change days before the forecast is
# essentially invisible to it, and a reader who knows the premier just changed
# deserves to be told that rather than left to assume it was modelled.
#
# Computed rather than hardcoded so the caveat cannot go stale: it names
# whoever the anchor's file last recorded and counts the polls itself.
leaders <- read_anchor_csv("government-leaders.csv",
                           c("region", "date", "party", "leader"))
setDT(leaders)
leaders[, date := as.Date(date)]
vl <- leaders[region == "vic" & date <= Sys.Date()][order(date)]
if (!nrow(vl)) {
  stop("government-leaders.csv has no Victorian leader on or before today. ",
       "The leadership caveat cannot be built, and silently dropping it would ",
       "publish a page that looks complete.")
}
leader_last <- vl[.N]
leader_days <- as.integer(Sys.Date() - leader_last$date)
# n_polls is filled in below, once the cycle's polls are loaded.

# --- trend series (weekly) + polls ---
tr <- fread("output/trend-vic-2026.csv")
tr[, date := as.Date(date)]
wk <- tr[format(date, "%w") == "0" | date == max(date)]
series <- lapply(split(wk, wk$party), function(d)
  list(party = d$party[1],
       d = as.character(d$date), m = round(d$mean, 2),
       lo = round(d$lo95, 2), hi = round(d$hi95, 2)))
names(series) <- NULL

polls <- load_polls("vic")
cp <- cycle_polls(polls, 2026, cycles)
pl <- rbindlist(lapply(c("ALP", "LNP", "GRN", "ONP", "OTH"), function(p) {
  v <- cp[!is.na(get(p)), .(date, firm, v = get(p))]
  if (!nrow(v)) return(NULL)
  data.table(party = p, date = as.character(v$date), firm = v$firm,
             v = round(v$v, 1))
}))

# --- projection + seats ---
mix <- fread("output/projection-mix.csv")
fdat <- build_fundamentals_data()
m_tpp <- fit_fundamentals(fdat, "@TPP")
live <- build_fundamentals_data(polled_only = FALSE, require_actual = FALSE)
kf <- live$region == "vic" & live$year == 2026 & live$party == "@TPP"
fund <- predict_fundamentals(m_tpp, live[which(kf), ])
pri <- load_prior_results(); kp <- pri$region == "vic" & pri$year == 2026
priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
fl <- flows_for(load_preference_flows(), 2026, "vic", quiet = TRUE)
now <- trend_as_at(polls, 2026, cycles, Sys.Date(), priors, fl)
# Every headline figure on the page descends from these three. A non-finite
# value here propagates to NA, serialises to null, and JS then coerces null to
# 0 in arithmetic — so a broken fundamentals prediction would publish "0%
# chance of a Labor majority" rather than failing. Stop here instead.
stopifnot(is.finite(fund), !is.null(now), is.finite(now$tpp))
pj <- project_result(now$tpp, fund, mix, days_out)
stopifnot(is.finite(pj$mean), is.finite(pj$sd),
          is.finite(pj$lo95), is.finite(pj$hi95))

# --- One Nation preference sensitivity ------------------------------------
#
# The largest single lever on the two-party figure: ONP polls ~21%, so every
# point of assumed flow moves the trend TPP by ~0.21, and the published number
# by about half that once mixed with flow-independent fundamentals. It was
# previously invisible -- an assumed value in an input file, described by a
# caveat that named the wrong source. Recomputed here rather than hardcoded so
# the page cannot drift from the model. Evidence:
# docs/reviews/onp-preference-flows-2026-08-15.md
onp_flow <- fl[fl$party == "ONP", ]$flow_alp[1]
onp_fp <- tr[party == "ONP"][which.max(date)]$mean
flows_all <- load_preference_flows()
onp_all <- flows_all[which(flows_all$party == "ONP"), ]
# South Australia, March 2026: the closest comparator available -- same year,
# ONP on a comparable share, and an observed flow rather than an assumption.
sa <- onp_all[which(onp_all$region == "sa" & onp_all$year == 2026), ]
er_all <- read_anchor_csv("eventual-results.csv",
                          c("year", "region", "party", "result"))
sa_fp <- suppressWarnings(as.numeric(
  er_all$result[er_all$year == 2026 & er_all$region == "sa" &
                grepl("^ONP", er_all$party)]))[1]
stopifnot(nrow(sa) == 1, is.finite(sa$flow_alp[1]), is.finite(sa_fp),
          is.finite(onp_flow), is.finite(onp_fp))
fl_cmp <- copy(fl)
fl_cmp[party == "ONP", flow_alp := sa$flow_alp[1]]
now_cmp <- trend_as_at(polls, 2026, cycles, Sys.Date(), priors, fl_cmp)
pj_cmp <- project_result(now_cmp$tpp, fund, mix, days_out)
stopifnot(is.finite(pj_cmp$mean))

# G2: the assumed flow against the trend in the 21 observed estimates. At 2.3
# residual sds it is already an outlying assumption; this stops it drifting
# further unnoticed, and would fire if the anchor's file changed underneath us.
onp_obs <- onp_all[which(!(onp_all$year == 2026 & onp_all$region == "vic") &
                         onp_all$year <= as.integer(format(Sys.Date(), "%Y"))), ]
m_flow <- stats::lm(flow_alp ~ year, onp_obs)
flow_hat <- unname(stats::predict(m_flow, data.frame(year = 2026)))
flow_z <- (onp_flow - flow_hat) / stats::sd(stats::resid(m_flow))
cat(sprintf("G2  ONP flow %.1f vs %.1f fitted from %d observed elections = %.2f sd  %s\n",
            onp_flow, flow_hat, nrow(onp_obs), flow_z,
            if (abs(flow_z) < 2.5) "PASS" else "FAIL"))
if (!is.finite(flow_z) || abs(flow_z) >= 2.5) {
  stop(sprintf("The assumed ONP preference flow (%.1f) is %.2f residual sds from the trend in observed elections (%.1f). It moves the two-party figure ~%.1f points per 10 points of flow; do not publish without checking it.",
               onp_flow, flow_z, flow_hat, 10 * onp_fp / 100 * pj$w))
}

seats26 <- load_seats(2026, "vic")
sp22 <- seat_swing_spread(seats26, 55.00 - 57.60)
sp18 <- seat_swing_spread(load_seats(2022, "vic"), 57.60 - 51.99)
region_sd <- mean(c(sp22$sd_between, sp18$sd_between))
within_sd <- mean(c(sp22$sd_within, sp18$sd_within))
sim <- simulate_seats(seats26, pj$mean, pj$sd, 55.00, within_sd,
                      region_sd = region_sd, n_sims = 50000, seed = 42)
tot <- sim$seats_won
h <- as.data.table(table(tot))
setnames(h, c("seats", "n"))
h[, seats := as.integer(as.character(seats))]
h[, p := n / sum(n)]

bs <- sim$by_seat[order(-alp_tpp_now)]
seat_rows <- bs[, .(seat, region = seat_region, tpp = round(alp_tpp_now, 1),
                    p = round(alp_win_prob, 3))]

card <- fread("output/pollster-scorecard.csv")
card <- card[order(-n_polls)][1:12]

out <- list(
  # The freshness verdict travels WITH the page. A run told to proceed on old
  # data must not produce something indistinguishable from a clean run.
  data_status = {
    fr <- suppressWarnings(tryCatch(
      check_poll_freshness("vic", strict = FALSE), error = function(e) NULL))
    if (is.null(fr)) "unknown" else as.character(fr$status[1])
  },
  meta = list(as_of = as.character(Sys.Date()),
              election = as.character(end_date), days_out = days_out,
              latest_poll = as.character(max(cp$date)),
              n_polls_cycle = nrow(cp),
              # How much polling has actually seen the current leader. The
              # model has no leader term, so this is the whole of what it
              # knows about a change, and the page says so.
              leader = leader_last$leader,
              leader_since = as.character(leader_last$date),
              leader_days = leader_days,
              leader_polls = sum(cp$date >= leader_last$date)),
  onp = list(fp = round(onp_fp, 1), flow = round(onp_flow, 1),
             n_est = nrow(onp_all),
             cmp_fp = round(sa_fp, 1), cmp_flow = round(sa$flow_alp[1], 1),
             cmp_tpp = round(pj_cmp$mean, 1), base_tpp = round(pj$mean, 1),
             trend_fit = round(flow_hat, 1), z = round(flow_z, 2)),
  trend = series, polls = pl,
  fp_now = lapply(c("LNP", "ALP", "ONP", "GRN", "OTH"), function(p) {
    d <- tr[party == p][which.max(date)]
    list(party = p, m = round(d$mean, 1), lo = round(d$lo95, 1),
         hi = round(d$hi95, 1))
  }),
  proj = list(trend = round(now$tpp, 2), fund = round(fund, 2),
              mean = round(pj$mean, 2), lo = round(pj$lo95, 2),
              hi = round(pj$hi95, 2), w = round(pj$w, 2),
              sd = round(pj$sd, 2), prev = 55.0),
  seats = list(median = as.integer(median(tot)),
               q25 = as.integer(quantile(tot, .25)),
               q75 = as.integer(quantile(tot, .75)),
               q05 = as.integer(quantile(tot, .05)),
               q95 = as.integer(quantile(tot, .95)),
               p_majority = round(mean(tot >= 45), 3),
               prev = 56, total = 88, majority = 45,
               hist = h[, .(seats, p = round(p, 5))]),
  seat_rows = seat_rows,
  mix = mix[, .(horizon, w = round(w, 2), mae_mix = round(mae_mix_loo, 2),
                mae_trend = round(mae_trend, 2), mae_fund = round(mae_fund, 2),
                sd = round(sd_err_loo, 2))],
  scorecard = card[, .(firm, polls = n_polls, lean = round(lean_pts, 2),
                       noise = round(noise_factor, 2), elections,
                       mae = round(final_mae, 2))]
)
json <- toJSON(out, auto_unbox = TRUE, digits = 6, na = "null")
write(json, "output/vic-page-data.json")

tpl <- paste(readLines("scripts/page-template.html", warn = FALSE),
             collapse = "\n")
stopifnot(grepl("/*__DATA__*/", tpl, fixed = TRUE))
html <- sub("/*__DATA__*/", json, tpl, fixed = TRUE)
writeLines(html, "output/victoria-2026.html", useBytes = TRUE)

# The page is inert without its data, and a template edit that breaks the
# script tag would publish a blank page rather than erroring. Cheap guards.
stopifnot(!grepl("__DATA__", html, fixed = TRUE),
          grepl("<title>", html, fixed = TRUE),
          nchar(html) > nchar(tpl))

cat(sprintf("wrote output/victoria-2026.html (%.0f KB)\n",
            file.size("output/victoria-2026.html") / 1024))

# Run the page's own JavaScript against a stub DOM and fail if any block did
# not draw. The guards in the template stop one bad block taking out the
# others, which also means a single missing chart no longer looks like
# anything — so the only way to know the page actually rendered is to run it.
# This is the check that would have caught the three-charts-missing release.
if (nzchar(Sys.which("node"))) {
  res <- system2("node", c("tools/check-page.js", "output/victoria-2026.html"),
                 stdout = TRUE, stderr = TRUE)
  st <- attr(res, "status")
  if (!is.null(st) && !identical(as.integer(st), 0L)) {
    cat(paste(res, collapse = "\n"), "\n")
    stop("The published page did not draw correctly (tools/check-page.js ",
         "exited ", st, "). Output above names the blocks that failed.")
  }
  # Report as a numbered check like every other stage, so it appears in
  # run_all.R's summary and the scheduled run's step summary. run_all.R keeps
  # only lines starting with a check code and discards the rest, so without
  # this the one test of the published page is invisible when it passes.
  drew <- sub(".*written: ([0-9]+).*", "\\1",
              grep("written:", res, value = TRUE)[1])
  addr <- sub(".*addressed: ([0-9]+).*", "\\1",
              grep("addressed:", res, value = TRUE)[1])
  # grep(...)[1] gives NA when nothing matches, and sub() on NA returns NA, so
  # a reworded harness log would print "G1 ... NA of NA ... PASS" — a line that
  # still starts with a check code and still says PASS, and would sail through
  # run_all.R's filter. The whole point of G1 is that the page test is visible
  # when it passes; a fabricated pass is worse than no line at all.
  if (is.na(drew) || is.na(addr) || !grepl("^[0-9]+$", drew) ||
      !grepl("^[0-9]+$", addr)) {
    cat(paste(res, collapse = "\n"), "\n")
    stop("Could not read the element counts out of tools/check-page.js output. ",
         "Its log format changed and G1 would otherwise report a fabricated pass.")
  }
  cat(sprintf("G1  page blocks drawn: %s of %s addressed elements (rest are conditional)  PASS\n",
              drew, addr))
} else {
  # Not fatal — node is not an R dependency and a machine without it should
  # still be able to produce the page. But it IS the only check on the page's
  # JavaScript, so its absence must be noisy rather than a silent pass.
  warning("node not found: the page's JavaScript was NOT checked. ",
          "output/victoria-2026.html may contain blocks that do not draw.",
          call. = FALSE)
}
cat(sprintf("proj %.2f [%.2f-%.2f]; seats median %d; P(maj) %.1f%%\n",
            pj$mean, pj$lo95, pj$hi95, median(tot), 100 * mean(tot >= 45)))
