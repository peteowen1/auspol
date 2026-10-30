# CALL POINTS FROM A FEDERAL ELECTION-NIGHT REPLAY (docs/reviews/night-replay-fed-2026-10-30.md).
#
#   Rscript scripts/night_calls_fed.R <replay dir from scripts/night_replay_json.R> <pair, e.g. fed2022> [seat=Wentworth] [party=IND]
#
# Reads every night-f<NNN>.json in the directory and prints, per counted fraction: the share of the vote counted, the
# replay's indicative clock (6pm + 4 hours x fraction, scripts/night_replay_json.R's convention, NOT real reporting
# times), Labor's expected seats with its 5-95% range, P(Labor majority), P(Labor most seats outright), the Coalition's
# expected seats, P(<party> wins <seat>), seats called right and seat log loss against output/published-predictions.csv.
# Then the call points: the first fraction from which a probability stays >= 0.99 at every later fraction.
# And the five seats whose probability for their actual winner moved most between the pre-count forecast and the end.
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
a <- commandArgs(trailingOnly = TRUE)
dir <- a[1]; pr <- a[2]; seat_q <- if (length(a) > 2) a[3] else "Wentworth"; party_q <- if (length(a) > 3) a[4] else "IND"
if (is.na(dir) || !dir.exists(dir) || is.na(pr)) stop("usage: night_calls_fed.R <replay dir> <pair> [seat] [party]")
PP <- fread("output/published-predictions.csv"); keep_pair <- PP$pair == pr & PP$won == TRUE
W <- PP[keep_pair, list(seat, winner = party)]
fr <- sub("^night-f([0-9]+)[.]json$", "\\1", list.files(dir, "^night-f[0-9]+[.]json$")); fr <- fr[order(as.numeric(fr))]
clock <- function(f) { m <- round(18 * 60 + 240 * f); sprintf("%d:%02dpm", (m %/% 60) - 12, m %% 60) }
eps <- 5e-4; rows <- list(); seats <- list()
for (k in fr) {
  d <- fromJSON(file.path(dir, sprintf("night-f%s.json", k)), simplifyVector = FALSE); f <- as.numeric(k) / 1000
  sp <- rbindlist(lapply(d$seats, function(s) rbindlist(lapply(s$parties, function(p)
    data.table(seat = s$seat, party = p$party, win_prob = p$win_prob, counted = s$counted_pct, fav = s$favourite)))))
  pw <- merge(sp, W, by.x = c("seat", "party"), by.y = c("seat", "winner"))
  if (nrow(pw) != nrow(W)) stop("matched ", nrow(pw), " of ", nrow(W), " winners at ", f)
  ch <- d$chamber$parties; al <- ch$ALP; ln <- ch$LNP
  hit_s <- sp$seat == seat_q & sp$party == party_q
  rows[[k]] <- data.table(frac = f, clock = clock(f), counted_pct = d$night$mean_counted_pct,
    right = sum(pw$fav == pw$party), n = nrow(pw), log_loss = round(mean(-log(pmax(pw$win_prob, eps))), 4),
    alp_exp = al$expected, alp_lo = al$quantiles[[1]], alp_hi = al$quantiles[[5]], p_alp_maj = al$p_majority,
    p_alp_most = al$p_most_seats_strict, lnp_exp = ln$expected, p_lnp_maj = ln$p_majority,
    seat_p = if (any(hit_s)) sp$win_prob[hit_s] else 0, seat_counted = sp$counted[sp$seat == seat_q][1], majority = d$majority)
  seats[[k]] <- pw[, list(seat, winner = party, p = win_prob, frac = f, counted)]
}
R <- rbindlist(rows)
setnames(R, "seat_p", sprintf("p_%s_%s", party_q, seat_q))
print(R)
call_at <- function(p) { ok <- p >= 0.99; i <- which(vapply(seq_along(ok), function(j) all(ok[j:length(ok)]), logical(1))); if (length(i)) min(i) else NA_integer_ }
for (v in c("p_alp_maj", "p_alp_most", sprintf("p_%s_%s", party_q, seat_q))) {
  i <- call_at(R[[v]])
  cat(sprintf("CALL %-22s %s\n", v, if (is.na(i)) "never stays >= 0.99" else
    sprintf("from fraction %.2f (%.1f%% of the vote counted, indicative %s): %.4f", R$frac[i], R$counted_pct[i], R$clock[i], R[[v]][i])))
}
S <- rbindlist(seats)
mv <- dcast(S, seat + winner ~ frac, value.var = "p")
f0 <- as.character(min(S$frac)); f1 <- as.character(max(S$frac))
mv[, move := get(f1) - get(f0)]
cat("\nfive seats whose probability for the actual winner moved most, pre-count to the end:\n")
print(mv[order(-abs(move))][1:5])
cat("\nwrong at the end:\n"); last_f <- max(S$frac); fin <- S[S$frac == last_f]
print(merge(fin, rbindlist(lapply(fromJSON(file.path(dir, sprintf("night-f%s.json", fr[length(fr)])), simplifyVector = FALSE)$seats,
  function(s) data.table(seat = s$seat, fav = s$favourite, fav_p = s$favourite_prob))), by = "seat")[fav != winner])
fwrite(R, file.path(dir, "calls-summary.csv")); fwrite(mv, file.path(dir, "calls-seats.csv"))
