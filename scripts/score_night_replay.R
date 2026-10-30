# Score an election-night replay against the declared winners: seats called right, seat log loss and chamber totals
# at each counted fraction, and each seat's probability for its actual winner as the count came in.
#   Rscript scripts/score_night_replay.R <dir holding night-f*.json from scripts/night_replay_json.R> [pair, default vic2022]
# Writes docs/reviews/night-replay-<pair>-summary-<date>.csv and -seats-<date>.csv. Built 2026-10-30 for the replay
# explainer (https://claude.ai/artifact/WtspQifwBERFokMxrkAsn9). The clock is the replay's own convention:
# 6pm + 4 hours x fraction (scripts/night_replay_json.R), not real reporting times.
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
a <- commandArgs(trailingOnly = TRUE)
dir <- a[1]; pr <- if (length(a) > 1) a[2] else "vic2022"
if (is.na(dir) || !dir.exists(dir)) stop("usage: score_night_replay.R <replay dir> [pair]")
P <- fread("output/published-predictions.csv")[pair == pr & won == TRUE, .(seat, winner = party)]
cat("actual winners:", nrow(P), "seats;", paste(names(table(P$winner)), table(P$winner), collapse = " "), "\n")
fr <- sub("^night-f([0-9]+)[.]json$", "\\1", list.files(dir, "^night-f[0-9]+[.]json$"))
fr <- fr[order(as.numeric(fr))]
clock <- function(f) { m <- round(18 * 60 + 240 * f); sprintf("%d:%02dpm", (m %/% 60) - 12, m %% 60) }
eps <- 5e-4; rows <- list(); seats <- list()
for (k in fr) {
  d <- fromJSON(file.path(dir, sprintf("night-f%s.json", k)), simplifyVector = FALSE)
  f <- as.numeric(k) / 1000
  sp <- rbindlist(lapply(d$seats, function(s) rbindlist(lapply(s$parties, function(p)
    data.table(seat = s$seat, party = p$party, win_prob = p$win_prob)))))
  cnt <- rbindlist(lapply(d$seats, function(s) data.table(seat = s$seat, counted_pct = s$counted_pct, favourite = s$favourite)))
  m <- merge(cnt, P, by = "seat")
  pw <- merge(sp, P, by.x = c("seat", "party"), by.y = c("seat", "winner"))
  if (nrow(pw) != nrow(P)) stop("winner rows matched ", nrow(pw), " of ", nrow(P), " at fraction ", f)
  ch <- d$chamber$parties
  q <- function(p) if (is.null(ch[[p]])) c(NA, NA, NA) else c(ch[[p]]$expected, ch[[p]]$quantiles[[1]], ch[[p]]$quantiles[[5]])
  rows[[k]] <- data.table(frac = f, clock = clock(f), counted = d$night$mean_counted_pct,
    log_loss = mean(-log(pmax(pw$win_prob, eps))), right = sum(m$favourite == m$winner), n = nrow(m),
    ALP = q("ALP")[1], ALP_lo = q("ALP")[2], ALP_hi = q("ALP")[3], LNP = q("LNP")[1], LNP_lo = q("LNP")[2], LNP_hi = q("LNP")[3],
    GRN = q("GRN")[1], IND = q("IND")[1])
  seats[[k]] <- merge(pw[, .(seat, winner = party, p_winner = win_prob)], cnt, by = "seat")[, frac := f]
}
R <- rbindlist(rows); print(R)
A <- rbindlist(seats)
w <- dcast(A, seat + winner ~ frac, value.var = "p_winner")
cat("\nstill wrong at the last fraction:\n"); print(A[frac == max(frac) & favourite != winner])
stamp <- format(Sys.Date())
fwrite(R, sprintf("docs/reviews/night-replay-%s-summary-%s.csv", pr, stamp))
fwrite(w, sprintf("docs/reviews/night-replay-%s-seats-%s.csv", pr, stamp))
