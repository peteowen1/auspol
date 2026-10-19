# Score AUSPOL_XGB_CONTEST on docs/plans/prereg-contest-features-2026-10-20.md's terms: two isolated rebuilds from
# stage 3 (same inputs, switch off vs on), read from each copy's output/published-predictions.csv (the published
# path). Standard rule: targets are seats with any cell moved > 0.05 points; primary target-seat seat-winner log
# loss, guard all seats, leave-one-election-out, no election worse by > 2 SE of its own seats, not two seats.
# Lower is better everywhere. Codes SCF0-SCF8.
#   Rscript scripts/score_contest_feats.R <baseline repo copy> <arm repo copy> [eps=1e-6]
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (!length(a) %in% 2:3) stop("usage: score_contest_feats.R <baseline repo copy> <arm repo copy> [eps]")
EPS <- if (length(a) == 3) as.numeric(a[3]) else 1e-6
rd <- function(d) fread(file.path(d, "output", "published-predictions.csv"), showProgress = FALSE)
B <- rd(a[1]); A <- rd(a[2])
cat(sprintf("SCF0 baseline %d cells / %d elections; arm %d cells / %d elections; floor %g\n",
            nrow(B), uniqueN(B$pair), nrow(A), uniqueN(A$pair), EPS))
m <- merge(B[, .(pair, seat, party, n_cands, prev_share, actual, won, sb = ours, pb = p_win)],
           A[, .(pair, seat, party, sa = ours, pa = p_win)], by = c("pair", "seat", "party"))
if (nrow(m) != nrow(B) || nrow(m) != nrow(A)) stop("SCF0! cells do not match one-to-one: ", nrow(m), " matched")
if (!nrow(m)) stop("SCF0! nothing to score")

# seat-level: the actual winner's probability, base and arm
S <- m[won == TRUE, .(pair, seat, pb, pa)]
if (anyDuplicated(S[, .(pair, seat)])) stop("SCF0! more than one winner row in a seat")
S[, d := -log(pmax(pa, EPS)) + log(pmax(pb, EPS))]
moved <- m[, .(mv = max(abs(sa - sb), na.rm = TRUE)), by = .(pair, seat)]
S <- merge(S, moved, by = c("pair", "seat"))
S[, target := mv > 0.05]
cat(sprintf("SCF1 %d seats in %d elections; targets (a cell moved > 0.05 points): %d seats in %d elections\n",
            nrow(S), uniqueN(S$pair), sum(S$target), uniqueN(S[target == TRUE]$pair)))

cl_se <- function(x) {   # mean change and its SE clustered on election (per-election sums)
  g <- x[, .(s = sum(d), n = .N), by = pair]; G <- nrow(g); N <- sum(g$n); mu <- sum(g$s) / N
  r <- g$s - mu * g$n
  c(est = mu, se = sqrt(G / (G - 1) * sum(r^2)) / N)
}
verdict <- function(r) if (r["est"] < -r["se"]) "better by more than 1 SE" else if (r["est"] > r["se"]) "WORSE by more than 1 SE" else "within 1 SE"
T <- S[target == TRUE]
if (uniqueN(T$pair) < 2) { cat("SCF2 fewer than two elections have a target seat: nothing to decide (the arm moved nothing)\n"); quit(status = 0) }
p <- cl_se(T); g <- cl_se(S)
cat(sprintf("SCF2 PRIMARY (clause 1) target seats: %+.4f (SE %.4f) => %s\n", p["est"], p["se"], verdict(p)))
cat(sprintf("SCF3 GUARD (clause 2) all seats: %+.4f (SE %.4f) => %s\n", g["est"], g["se"],
            if (g["est"] > g["se"]) "FAIL" else "PASS"))
els <- unique(T$pair)
# a drop leaving one election has no clustered SE: that drop cannot hold, so it counts as failed (isTRUE)
loo <- vapply(els, function(e) { r <- cl_se(T[pair != e]); isTRUE(r["est"] < -r["se"]) }, logical(1))
cat(sprintf("SCF4 LEAVE-ONE-ELECTION-OUT (clause 3): primary better by more than 1 SE in %d of %d drops => %s\n",
            sum(loo), length(loo), if (all(loo)) "PASS" else "FAIL"))
pe <- S[, .(seats = .N, change = mean(d), se = sd(d) / sqrt(.N), share_of_gain = NA_real_), by = pair]
pe[, z := change / se]
tg <- T[, .(gain = sum(d)), by = pair]; pe <- merge(pe, tg, by = "pair", all.x = TRUE)
pe[, share_of_gain := round(gain / sum(T$d), 2)]
cat(sprintf("SCF5 NO ELECTION WORSE (clause 4): %d election(s) worse by more than 2 SE of their own seats => %s\n",
            sum(pe$z > 2, na.rm = TRUE), if (any(pe$z > 2, na.rm = TRUE)) "FAIL" else "PASS"))
print(pe[order(-z)][, .(pair, seats, change = round(change, 4), se = round(se, 4), z = round(z, 2), share_of_gain)], nrows = 40)
top2 <- T[order(d)][1:min(2, nrow(T))]
rest <- T[!(paste(pair, seat) %in% paste(top2$pair, top2$seat))]
cat(sprintf("SCF6 NOT TWO SEATS (clause 5): without %s the target change is %+.4f => %s\n",
            paste(top2$pair, top2$seat, collapse = "; "), mean(rest$d),
            if (sign(mean(rest$d)) == sign(p["est"])) "PASS (sign kept)" else "FAIL (sign lost)"))

# reported: share RMSE on contested minor cells, new-to-seat split, the motivating cases
MIN <- c("ONP", "IND", "OTH_RIGHT", "OTH", "GRN")
m[, new_to_seat := is.na(prev_share) | prev_share == 0]
rm_row <- function(x) x[, .(cells = .N, rmse_base = round(sqrt(mean((sb - actual)^2)), 3), rmse_arm = round(sqrt(mean((sa - actual)^2)), 3),
                            mean_base = round(mean(sb), 2), mean_arm = round(mean(sa), 2), mean_actual = round(mean(actual), 2))]
cat("SCF7 contested minor-class cells, seat share in points (RMSE lower is better):\n")
print(rbind(cbind(class = "all minor", new_to_seat = NA, rm_row(m[party %in% MIN & n_cands > 0])),
            m[party %in% MIN & n_cands > 0, rm_row(.SD), by = .(class = party, new_to_seat)][order(class, new_to_seat)]))
cat("SCF8 motivating cases, One Nation contested cells:\n")
print(m[party == "ONP" & n_cands > 0 & pair %in% c("nsw2023", "fed2016"), rm_row(.SD), by = .(pair, new_to_seat)])
cat("     largest seat moves (log loss change, lower is better; p of the actual winner):\n")
print(S[order(d)][c(1:5, (nrow(S) - 4):nrow(S))][, .(pair, seat, p_base = round(pb, 3), p_arm = round(pa, 3), change = round(d, 4), max_move = round(mv, 2))])
