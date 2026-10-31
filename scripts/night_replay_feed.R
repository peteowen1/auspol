# REAL-NIGHT REPLAY from the AEC's archived election-night feed (review 2026-10-30: the fraction replay's order and
# clock were simulated). At each clock time T, the night model sees exactly the polling places the AEC had published
# first preferences for by T (output/night-feed/booth-returns-fed<year>.csv, scripts/parse_aec_mediafeed.py), and the
# two-candidate counts of those places only where the pair on screen at T was the final pair and not withdrawn.
#
#   Rscript scripts/night_replay_feed.R --state=<state-fed2022.rds> [--out=<dir>] [--times=18:00,...] [--surge-fade=1]
#       [--tcp-center=median] [--tcp-flow-floor=0.065] [--label=base]
#
# Simplifications (say them in every result): a reported place carries its FINAL count, not its first-night figure;
# declaration votes (postal, absent, provisional, declaration pre-poll) are never counted on the night here (the AEC
# counted some postals on the night); the 11 fed2022 seats whose pair was withdrawn get no two-candidate count until
# the replacement appears; a two-candidate count is used only when the pair on screen equals the night's LAST pair
# (known only at the end of the night: it can withhold a count, never supply one, because the booth 2CP file holds
# the final pair's counts only -- review 2026-10-30). Times are Canberra time (AEST), the feed's own clock.
# Writes <out>/<label>-summary.csv (one row per time) and <out>/<label>-seats.csv (seat x time x party probability).
# Check codes NRF1-NRF4.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
st <- readRDS(flag("state")); yr <- st$to; pair_lbl <- sprintf("fed%d", yr)
out_dir <- flag("out", file.path("output", "night-feed", "replay")); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
label <- flag("label", "base")
# defaults = the live runner's since 2026-10-31; the as-shipped-before arm is --surge-fade=0 --tcp-center=mean --tcp-flow-floor=0.01
surge_fade <- !identical(flag("surge-fade", "1"), "0"); tcp_center <- flag("tcp-center", "median")
tcp_floor <- as.numeric(flag("tcp-flow-floor", "0.01"))
day <- as.Date(c(`2022` = "2022-05-21", `2025` = "2025-05-03")[[as.character(yr)]])
tm <- strsplit(flag("times", paste(c(sprintf("%02d:%02d", rep(18:23, each = 4), c(0, 15, 30, 45)), "24:00", "25:00", "26:00", "27:00"), collapse = ",")), ",")[[1]]
at <- vapply(tm, function(x) { p <- as.integer(strsplit(x, ":")[[1]]); as.numeric(as.POSIXct(day, tz = "UTC") + p[1] * 3600 + p[2] * 60) }, numeric(1))

L  <- fread(sprintf("output/booths-fed%d.csv", yr)); R <- fread(sprintf("output/booths-fed%d.csv", st$from))
Tc <- fread(sprintf("output/booths/fed%d-booth-tcp.csv", yr))
B  <- fread(sprintf("output/night-feed/booth-returns-fed%d.csv", yr))
D  <- fread(sprintf("output/night-feed/division-progress-fed%d.csv", yr))
P  <- fread("output/published-predictions.csv"); keep_p <- P$pair == pair_lbl; P <- P[keep_p]
win <- P[P$won == TRUE, list(seat, party)]
seats <- rownames(st$shares)
tsec <- function(x) as.numeric(as.POSIXct(x, tz = "UTC"))
B[, t_fp := tsec(ifelse(!is.na(fp_exact) & fp_exact_flag == 1, fp_exact, fp_first_seen))]
B[, t_tcp := tsec(tcp_first_seen)]
pp <- B[!grepl("^declaration", classification) & !is.na(t_fp)]
cat(sprintf("NRF1 %s: %d seats in state, %d places with a night return, %d places in the booth table; %d sims; label %s (surge-fade %s, tcp-center %s, tcp-flow-floor %s)\n",
            pair_lbl, length(seats), nrow(pp), nrow(L[L$booth_type == "ordinary", list(1), by = list(district, booth)]), nrow(st$swd),
            label, surge_fade, tcp_center, tcp_floor))
miss <- setdiff(unique(pp$division), seats); if (length(miss)) cat("NRF1 feed divisions not in the state:", paste(miss, collapse = ", "), "\n")

# the pair on screen per division per snapshot; usable when not withdrawn and equal to the final pair
D[, ts := tsec(snapshot_time)]
fin <- D[D$ts == max(D$ts), list(division, final_pair = tcp_pair_ids)]
D <- merge(D, fin, by = "division")
D[, pair_ok := !is.na(tcp_pair_ids) & nzchar(tcp_pair_ids) & tcp_pair_ids == final_pair & !(tolower(as.character(tcp_maverick)) %in% "true")]

summ <- list(); seat_rows <- list()
for (k in seq_along(at)) {
  T0 <- at[k]
  rep_pp <- pp[pp$t_fp <= T0, list(district = division, unit = polling_place)]
  if (!nrow(rep_pp)) { cat(sprintf("NRF2 %s: nothing reported yet\n", tm[k])); next }
  dk <- D[D$ts <= T0][order(ts)][, .SD[.N], by = division]
  ok_div <- dk$division[dk$pair_ok]
  tb <- pp[pp$t_tcp <= T0 & pp$division %in% ok_div, list(district = division, booth = polling_place)]
  tcp_rows <- merge(Tc, tb, by = c("district", "booth"))
  conv <- list(live = L, counted = rep_pp, tcp = tcp_rows)
  r <- night_run_update(st, conv, R, gap_k = 5, total = "projected", use_tcp = nrow(tcp_rows) > 0,
                        surge_fade = surge_fade, tcp_center = tcp_center, tcp_flow_floor = tcp_floor)
  tot <- r$sim$totals; alp <- tot[, "ALP"]
  oth <- tot[, setdiff(colnames(tot), "ALP"), drop = FALSE]
  wp <- as.data.table(r$sim$win_prob)
  sc <- merge(win, wp, by = c("seat", "party"), all.x = TRUE); sc[is.na(prob), prob := 0]
  cnt <- r$nu$counted[seats]; cnt[is.na(cnt)] <- 0
  summ[[length(summ) + 1]] <- data.table(time = tm[k], places = nrow(rep_pp), seats_reporting = uniqueN(rep_pp$district),
    mean_counted = round(100 * mean(cnt), 1), tcp_seats = r$n_tcp,
    alp_exp = round(mean(alp), 2), alp_lo = unname(quantile(alp, 0.05)), alp_hi = unname(quantile(alp, 0.95)),
    p_alp_majority = round(mean(alp >= 76), 4), p_alp_largest = round(mean(alp > apply(oth, 1, max)), 4),
    log_loss = round(mean(-log(pmax(sc$prob, 1e-6))), 4), right = sum(sc$prob > 0.5), n = nrow(sc),
    wentworth_ind = round(sum(wp$prob[wp$seat == "Wentworth" & wp$party == "IND"]), 4),
    wentworth_counted = round(100 * unname(cnt["Wentworth"]), 1))
  wp[, time := tm[k]]; seat_rows[[length(seat_rows) + 1]] <- wp
  s <- summ[[length(summ)]]
  cat(sprintf("NRF3 %s places %d (%d seats, mean counted %.1f%%, 2CP %d) | ALP %.1f (%g-%g) P(maj) %.3f | log loss %.4f, right %d/%d | Wentworth IND %.3f at %.1f%%\n",
              s$time, s$places, s$seats_reporting, s$mean_counted, s$tcp_seats, s$alp_exp, s$alp_lo, s$alp_hi, s$p_alp_majority,
              s$log_loss, s$right, s$n, s$wentworth_ind, s$wentworth_counted))
}
S <- rbindlist(summ); fwrite(S, file.path(out_dir, sprintf("%s-%s-summary.csv", pair_lbl, label)))
fwrite(rbindlist(seat_rows), file.path(out_dir, sprintf("%s-%s-seats.csv", pair_lbl, label)))
call_at <- function(p) { ok <- p >= 0.99; i <- which(vapply(seq_along(ok), function(j) all(ok[j:length(ok)]), logical(1))); if (length(i)) S$time[min(i)] else "never" }
cat(sprintf("NRF4 %s %s: Labor majority called (>= 0.99 and stays) at %s | Labor largest at %s | Wentworth IND at %s\n",
            pair_lbl, label, call_at(S$p_alp_majority), call_at(S$p_alp_largest), call_at(S$wentworth_ind)))
