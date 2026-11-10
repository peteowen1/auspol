# Score night pair replays: v1 pair_r (prereg-night-pair-trust-2026-11-11) and v2 pair_cal (prereg-night-pair-cal-2026-11-11).
# Per night and arm: night-average seat-winner log loss over replay times with anything counted (eps 1e-6),
# seats weighted equally; pooled over the three nights; the same without Monash; Monash's Liberal chance;
# seats wrong at the last time. Usage: Rscript scripts/score_night_pair_replays.R <replay dir> [arm label, default pair]
# [Monash known-answer times, default the last time; v2 uses 19:00,20:00, when the AEC showed the pair].
suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
d <- args[1]; arm <- if (length(args) >= 2) args[2] else "pair"
mon_times <- if (length(args) >= 3) strsplit(args[3], ",")[[1]] else NULL
P <- fread("output/published-predictions.csv"); P <- P[P$won == TRUE, .(pair, seat, winner = party)]
nights <- c("fed2022", "fed2025", "vic2022"); arms <- c("base", arm)
cat(sprintf("SC0 scoring arm '%s' against 'base' in %s\n", arm, d))
per_seat <- rbindlist(lapply(nights, function(nt) rbindlist(lapply(arms, function(a) {
  S <- fread(file.path(d, sprintf("%s-%s-summary.csv", nt, a))); W <- fread(file.path(d, sprintf("%s-%s-seats.csv", nt, a)))
  S[, time := as.character(time)]; W[, time := as.character(time)]
  tms <- S$time[S$mean_counted > 0]
  if (!length(tms)) stop("SC1! no counted times in ", nt, " ", a)
  win <- P[P$pair == nt]
  if (!nrow(win)) stop("SC1! no winners for ", nt)
  g <- CJ(seat = win$seat, time = tms)
  g <- merge(g, win[, .(seat, winner)], by = "seat")
  g <- merge(g, W[, .(seat, party, time, prob)], by.x = c("seat", "winner", "time"), by.y = c("seat", "party", "time"), all.x = TRUE)
  g[is.na(prob), prob := 0]
  last <- tms[length(tms)]
  g[, .(ll = mean(-log(pmax(prob, 1e-6))), p_last = prob[time == last]), by = seat][, `:=`(night = nt, arm = if (a == "base") "base" else "pair")]
}))))
# Monash fed2025, the Liberal (actual winner) at the known-answer times, read straight from the seat files
mon <- rbindlist(lapply(arms, function(a) { W <- fread(file.path(d, sprintf("fed2025-%s-seats.csv", a)))
  W[, time := as.character(time)]; W[seat == "Monash" & party == "LNP", .(time, prob, arm = if (a == "base") "base" else "pair")] }))
if (is.null(mon_times)) mon_times <- max(mon$time)
mon <- dcast(mon[time %in% mon_times], time ~ arm, value.var = "prob", fill = 0)
for (cc in c("base", "pair")) if (!cc %in% names(mon)) mon[, (cc) := 0]
if (nrow(mon) != length(mon_times)) stop("SC3! Monash known-answer times not all in the seat files: ", paste(mon_times, collapse = ","))
cat("\nMONASH fed2025 Liberal (actual winner) at the known-answer times:\n"); print(mon)
cat(sprintf("SC2 seats per night and arm:\n")); print(per_seat[, .N, by = .(night, arm)])
w <- dcast(per_seat, night + seat ~ arm, value.var = c("ll", "p_last"))
w[, d := ll_pair - ll_base]
by_n <- w[, .(seats = .N, base = mean(ll_base), pair = mean(ll_pair), diff = mean(d), se = sd(d) / sqrt(.N),
              wrong_base = sum(p_last_base <= 0.5), wrong_pair = sum(p_last_pair <= 0.5), changed = sum(abs(d) > 1e-9)), by = night]
cat("\nNight-average seat-winner log loss (lower is better), arm 'pair' minus 'base':\n"); print(by_n, digits = 4)
pool <- w[, .(seats = .N, diff = mean(d), se = sd(d) / sqrt(.N))]
pool_nm <- w[seat != "Monash" | night != "fed2025", .(seats = .N, diff = mean(d), se = sd(d) / sqrt(.N))]
cat(sprintf("\nPOOLED diff %+.5f (SE %.5f, %d seats); without Monash fed2025 %+.5f (SE %.5f)\n",
            pool$diff, pool$se, pool$seats, pool_nm$diff, pool_nm$se))
mon_up <- all(mon$pair > mon$base)
cat("\nLargest moves (night-average log loss, pair minus base):\n"); print(w[order(-abs(d))][1:15, .(night, seat, ll_base, ll_pair, d, p_last_base, p_last_pair)], digits = 3)
cat("\nReported, not decisive: vic2022 Albert Park and Hawthorn (v1's two worst seats):\n"); print(w[night == "vic2022" & seat %in% c("Albert Park", "Hawthorn"), .(seat, ll_base, ll_pair, d)], digits = 3)
rule <- pool$diff < 0 && all(by_n$diff <= 0.005) && mon_up && pool_nm$diff <= 0.002
cat(sprintf("\nDECISION RULE ('%s' vs base): pooled falls %s; no night worse by > 0.005 %s; Monash rises at %s %s; without-Monash not worse by > 0.002 %s => %s\n",
            arm, pool$diff < 0, all(by_n$diff <= 0.005), paste(mon_times, collapse = ","), mon_up, pool_nm$diff <= 0.002, if (rule) "PASS" else "FAIL"))
