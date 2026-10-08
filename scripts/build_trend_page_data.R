# The poll-trend data an ITG forecast page draws its "The polls" chart from,
# for elections other than Victoria (Victoria's comes from build_page.R, which
# carries a whole Victorian page with it).
#
# Writes output/<election>-page-data.json, e.g. output/nsw2027-page-data.json.
# The blog (inthegame-blog politics/_forecast-body.qmd) reads exactly these
# keys, in the same shapes as vic-page-data.json: trend, polls, fp_now,
# meta$latest_poll, meta$n_polls_cycle, scorecard. Nothing else is written, so
# nothing else can drift.
#
# ONE fit: the trend is trend_as_at() with the same inputs fit_seats_full.R
# gives it for this election (polls, the cycle table, today, prior results,
# flows_for()), so the chart is the trend the published seat forecast was
# drawn from, not a second model (the trap build_page.R's header records).
#
# Run from repo root:
#   AUSPOL_FORECAST_ELECTION=nsw2027 Rscript scripts/build_trend_page_data.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({ library(data.table); library(jsonlite) })

ELECTION <- Sys.getenv("AUSPOL_FORECAST_ELECTION", "nsw2027")
if (ELECTION == "vic2026") stop("TP0! vic2026's page data comes from scripts/build_page.R")
REGION <- sub("[0-9]+$", "", ELECTION); YEAR <- as.integer(sub("^[a-z]+", "", ELECTION))
POLL_DAY <- election_dates(ELECTION)[[1]]
OUT_F <- file.path("output", sprintf("%s-page-data.json", ELECTION))

cycles <- load_election_cycles()
polls <- load_polls(REGION)
pri <- load_prior_results(); kp <- pri$region == REGION & pri$year == YEAR
priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
if (!length(priors)) stop("TP0! no prior results for ", ELECTION)
fl <- flows_for(load_preference_flows(), YEAR, REGION, quiet = TRUE)
now <- trend_as_at(polls, YEAR, cycles, Sys.Date(), priors, fl, with_series = TRUE)
if (is.null(now) || is.null(now$series) || !nrow(now$series))
  stop("TP0! trend_as_at() returned no series for ", ELECTION)
tr <- copy(now$series); tr[, date := as.Date(date)]

# Same structural guard as build_page.R's G7, on this fit: bands present and
# inside (0, 100), first preferences summing to 100 +/- 5 at the last date.
fp_parties <- setdiff(unique(tr$party), "TPP_ALP")
bands_ok <- tr[, all(is.finite(mean)) && all(is.finite(lo95)) &&
                 all(is.finite(hi95)) && all(lo95 > 0) && all(hi95 < 100)]
fp_sum <- tr[party %in% fp_parties, sum(mean[which.max(date)]), by = party][, sum(V1)]
cat(sprintf("TP1  %s trend: %d parties, %s to %s; bands inside (0,100) %s; endpoint FP sum %.1f  %s\n",
            ELECTION, length(fp_parties), min(tr$date), max(tr$date),
            if (bands_ok) "OK" else "BREACHED", fp_sum,
            if (bands_ok && abs(fp_sum - 100) <= 5) "PASS" else "FAIL"))
if (!bands_ok || abs(fp_sum - 100) > 5)
  stop(sprintf("TP1! the %s trend is structurally invalid (bands %s, FP sum %.1f); not publishing it",
               ELECTION, if (bands_ok) "OK" else "outside (0,100)", fp_sum))

# Weekly points (Sundays) plus the last date, as build_page.R does.
wk <- tr[format(date, "%w") == "0" | date == max(date)]
series <- lapply(split(wk, wk$party), function(d)
  list(party = d$party[1], d = as.character(d$date), m = round(d$mean, 2),
       lo = round(d$lo95, 2), hi = round(d$hi95, 2)))
names(series) <- NULL

cp <- cycle_polls(polls, YEAR, cycles)
if (!nrow(cp)) stop("TP2! no polls in the ", ELECTION, " cycle")
poll_cols <- intersect(fp_parties, names(cp))
pl <- rbindlist(lapply(poll_cols, function(p) {
  val <- cp[[p]]; ok <- which(!is.na(val))   # mask outside the brackets (CLAUDE.md NSE rule)
  if (!length(ok)) return(NULL)
  data.table(party = p, date = as.character(cp$date[ok]), firm = cp$firm[ok], v = round(val[ok], 1))
}))
cat(sprintf("TP2  %d polls this cycle (latest %s); %d poll points across %s\n",
            nrow(cp), max(cp$date), nrow(pl), paste(poll_cols, collapse = ", ")))

fp_now <- lapply(fp_parties, function(p) {
  d <- tr[party == p][which.max(date)]
  list(party = p, m = round(d$mean, 1), lo = round(d$lo95, 1), hi = round(d$hi95, 1))
})

card_f <- file.path("output", "pollster-scorecard.csv")
scorecard <- if (file.exists(card_f)) {
  card <- fread(card_f, showProgress = FALSE)[order(-n_polls)][seq_len(min(12L, .N))]
  card[, .(firm, polls = n_polls, lean = round(lean_pts, 2), noise = round(noise_factor, 2),
           elections, mae = round(final_mae, 2))]
} else { cat("TP3  no output/pollster-scorecard.csv: scorecard omitted (the page hides that table)\n"); NULL }

fr <- suppressWarnings(tryCatch(check_poll_freshness(REGION, strict = FALSE), error = function(e) NULL))
out <- list(
  data_status = if (is.null(fr)) "unknown" else as.character(fr$status[1]),
  meta = list(as_of = as.character(Sys.Date()), election = as.character(POLL_DAY),
              days_out = as.integer(POLL_DAY - Sys.Date()),
              latest_poll = as.character(max(cp$date)), n_polls_cycle = nrow(cp)),
  trend = series, polls = pl, fp_now = fp_now, scorecard = scorecard)
writeLines(toJSON(out, auto_unbox = TRUE, digits = 6, na = "null", null = "null"), OUT_F)
cat(sprintf("TP4  wrote %s (%.0f KB): fp_now %s\n", OUT_F, file.size(OUT_F) / 1024,
            paste(sprintf("%s %.1f", vapply(fp_now, `[[`, "", "party"),
                          vapply(fp_now, `[[`, 0, "m")), collapse = ", ")))
