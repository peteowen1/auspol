# REAL-NIGHT REPLAY of Victoria 2022 from the VEC's archived hourly feed snapshots (the 2022 sample pack,
# external/reference/vec/2026/feed-docs/inner22/). Each snapshot goes through the live runner's own conversion
# (vec_feed_read_lh -> night_booth_table, expected votes from the previous election's turnout) and
# night_run_update(), so this measures the live path, not a simulated count.
#
#   Rscript scripts/night_replay_vec.R --state=<night-state-vic2022.rds> --setup=<folder holding the 2022
#       Candidates and PollingLocations XML, flat> [--feed=external/reference/vec/2026/feed-docs/inner22]
#       [--out=<dir>] [--label=fixes] [--surge-fade=1] [--tcp-center=median] [--tcp-flow-floor=0.065] [--last-day=20221127]
#       [--stamps=<comma list of snapshot stamps to run, default all>]
#
# Defaults are the live runner's (since 2026-10-31); the before-fixes arm is
# --surge-fade=0 --tcp-center=mean --tcp-flow-floor=0.01. Snapshots are HOURLY (6:03pm, then 7pm to 2am), so a call
# time here is "by this hour". Times are the snapshot stamps, Melbourne time (AEDT, same as Sydney).
# Writes <out>/vic2022-<label>-summary.csv and -seats.csv. Check codes NRV1-NRV4.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
need <- function(n) { v <- flag(n); if (is.null(v)) stop("NRV1! --", n, "= is required"); v }
st <- readRDS(need("state")); setup <- need("setup")
feed_dir <- flag("feed", "external/reference/vec/2026/feed-docs/inner22")
out_dir <- flag("out", file.path("output", "night-feed", "replay")); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
label <- flag("label", "fixes"); last_day <- flag("last-day", "20221127")
surge_fade <- !identical(flag("surge-fade", "1"), "0"); tcp_center <- flag("tcp-center", "median")
tcp_floor <- as.numeric(flag("tcp-flow-floor", "0.065"))
pair_lbl <- sprintf("vic%d", st$to)
ref <- fread(sprintf("output/booths-vic%d.csv", st$from), showProgress = FALSE)
turn <- fread(sprintf("output/council-district-stats-%d.csv", st$from), showProgress = FALSE)

files <- list.files(feed_dir, pattern = "verboselh_[0-9]{8}_[0-9]{6}\\.xml$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
stamp <- sub(".*verboselh_([0-9]{8}_[0-9]{6})\\.xml$", "\\1", basename(files), ignore.case = TRUE)
keep <- substr(stamp, 1, 8) <= last_day
only <- flag("stamps"); if (!is.null(only)) keep <- keep & stamp %in% strsplit(only, ",")[[1]]   # e.g. --stamps=20221126_200005,20221126_220008
files <- files[keep][order(stamp[keep])]; stamp <- sort(stamp[keep])
if (!length(files)) stop("NRV1! no verboselh snapshots in ", feed_dir)
pl <- night_polling_places(setup); lk <- night_party_lookup(setup)
if (is.null(lk)) stop("NRV1! no Candidates XML in ", setup, " (the folder must hold it directly, not in a subfolder)")
P <- fread("output/published-predictions.csv"); keep_p <- P$pair == pair_lbl; P <- P[keep_p]
win <- P[P$won == TRUE, list(seat, party)]
seats <- rownames(st$shares)
cat(sprintf("NRV1 %s: %d seats in state, %d snapshots %s to %s, %d sims; label %s (surge-fade %s, tcp-center %s, tcp-flow-floor %s); %d winners to score\n",
            pair_lbl, length(seats), length(files), stamp[1], stamp[length(stamp)], nrow(st$swd), label, surge_fade, tcp_center, tcp_floor, nrow(win)))

summ <- list(); seat_rows <- list()
for (k in seq_along(files)) {
  feed <- vec_feed_read_lh(files[k])
  conv <- suppressMessages(night_booth_table(feed, lk, pl))
  enr <- stats::setNames(feed$contests$enrolment, sub(" District$", "", feed$contests$district))
  expected <- night_expected_votes(enr, night_turnout_table(turn, ref), "night")
  r <- night_run_update(st, conv, ref, gap_k = 5, total = "expected", expected = expected, use_tcp = TRUE,
                        surge_fade = surge_fade, tcp_center = tcp_center, tcp_flow_floor = tcp_floor)
  tot <- r$sim$totals; alp <- tot[, "ALP"]; oth <- tot[, setdiff(colnames(tot), "ALP"), drop = FALSE]
  wp <- as.data.table(r$sim$win_prob)
  sc <- merge(win, wp, by = c("seat", "party"), all.x = TRUE); sc[is.na(prob), prob := 0]
  cnt <- r$nu$counted[seats]; cnt[is.na(cnt)] <- 0
  tm <- sprintf("%s:%s", substr(stamp[k], 10, 11), substr(stamp[k], 12, 13))
  if (substr(stamp[k], 1, 8) > "20221126") tm <- sprintf("%d:%s", 24L + as.integer(substr(stamp[k], 10, 11)), substr(stamp[k], 12, 13))
  s <- data.table(time = tm, stamp = stamp[k], seats_updated = r$n_updated, mean_counted = round(100 * mean(cnt), 1), tcp_seats = r$n_tcp,
                  alp_exp = round(mean(alp), 2), alp_lo = unname(quantile(alp, 0.05)), alp_hi = unname(quantile(alp, 0.95)),
                  p_alp_majority = round(mean(alp >= 45), 4), p_alp_largest = round(mean(alp > apply(oth, 1, max)), 4),
                  log_loss = round(mean(-log(pmax(sc$prob, 1e-6))), 4), right = sum(sc$prob > 0.5), n = nrow(sc))
  summ[[k]] <- s; wp[, time := tm]; seat_rows[[k]] <- wp
  cat(sprintf("NRV2 %s seats updated %d (mean counted %.1f%%, 2CP %d) | ALP %.1f (%g-%g) P(maj) %.3f P(largest) %.3f | log loss %.4f, right %d/%d\n",
              s$time, s$seats_updated, s$mean_counted, s$tcp_seats, s$alp_exp, s$alp_lo, s$alp_hi, s$p_alp_majority, s$p_alp_largest,
              s$log_loss, s$right, s$n))
}
S <- rbindlist(summ); fwrite(S, file.path(out_dir, sprintf("%s-%s-summary.csv", pair_lbl, label)))
W <- rbindlist(seat_rows); fwrite(W, file.path(out_dir, sprintf("%s-%s-seats.csv", pair_lbl, label)))
if (nrow(S) && all(S$n == 0)) stop("NRV3! no winners scored: vic2022 rows missing from output/published-predictions.csv")
call_at <- function(p) { i <- which(vapply(seq_along(p), function(j) all(p[j:length(p)] >= 0.99), logical(1))); if (length(i)) S$time[min(i)] else "never" }
last <- W[W$time == S$time[nrow(S)]]; sc <- merge(win, last, by = c("seat", "party"), all.x = TRUE); sc[is.na(prob), prob := 0]
wrong <- sc[sc$prob <= 0.5]
cat(sprintf("NRV4 %s %s: Labor majority called (>= 0.99 and stays) at %s | Labor largest at %s | wrong at %s: %s\n",
            pair_lbl, label, call_at(S$p_alp_majority), call_at(S$p_alp_largest), S$time[nrow(S)],
            if (nrow(wrong)) paste(sprintf("%s %s %.2f", wrong$seat, wrong$party, wrong$prob), collapse = "; ") else "none"))
