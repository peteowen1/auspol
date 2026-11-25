# SEAT-TOTAL SCORES for a quick_arm baseline/arm pair (AUSPOL_SEAT_CLUSTER_COR prereg,
# docs/plans/prereg-seat-cluster-cor-2026-11-25.md).
#
#   Rscript scripts/score_seat_totals.R <base_cache_dir> [<arm_cache_dir>] [--pairs=a,b]
#
# Each cache dir is a quick_arm cache key folder (%LOCALAPPDATA%/Temp/auspol-quickarm/cache/<key>)
# holding one sub-folder per election with totals.csv (seats won per party per simulation, the
# harness's own sim$totals) and allprobs.csv (per seat: the actual winner).
#
# Per election and party: the ACTUAL number of seats won (counted from allprobs over the same
# seats the simulation ran) scored under the simulated seat-count distribution:
#   ls   = -log(P(total == actual)), P floored at 0.5/N (N = simulations)   lower is better
#   rps  = ranked probability score over counts 0..n_seats, / n_seats        lower is better
#   c80, c90 = actual inside the central 80% / 90% interval (quantile type 1)  target 0.80 / 0.90
# A party is scored in an election only if the simulation or the result gives it a seat
# (a class that can never win anything carries no information about the spread).
# Pooled = mean over elections of the per-election mean over scored parties; SE clustered on
# election (sd of per-election arm-minus-base differences / sqrt(n elections)).
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
pos <- a[!grepl("^--", a)]
pf <- grep("^--pairs=", a, value = TRUE)
want <- if (length(pf)) strsplit(sub("^--pairs=", "", pf), ",")[[1]] else NULL
stopifnot(length(pos) >= 1L)

score_dir <- function(dir) {
  els <- basename(list.dirs(dir, recursive = FALSE))
  if (!is.null(want)) els <- intersect(els, want)
  out <- list()
  for (el in els) {
    tf <- file.path(dir, el, "totals.csv"); af <- file.path(dir, el, "allprobs.csv")
    if (!file.exists(tf) || !file.exists(af)) { cat(sprintf("STT0 %s: no totals.csv -- not scored\n", el)); next }
    tot <- fread(tf); ap <- fread(af)
    tot[, pair := NULL]
    seats <- unique(ap[, .(seat, actual)])
    if (anyDuplicated(seats$seat)) stop("STT: ", el, " has a seat with two actual winners")
    nseat <- nrow(seats); N <- nrow(tot)
    rs <- rowSums(tot)
    if (any(rs != nseat)) stop(sprintf("STT: %s totals rows sum to %s, allprobs has %d seats", el,
                                       paste(range(rs), collapse = "-"), nseat))
    act <- table(factor(seats$actual, levels = names(tot)))
    if (sum(act) != nseat) stop("STT: ", el, " actual winner not a totals column: ",
                                paste(setdiff(seats$actual, names(tot)), collapse = ","))
    for (p in names(tot)) {
      x <- tot[[p]]; y <- as.integer(act[[p]])
      if (max(x) == 0L && y == 0L) next
      pr <- mean(x == y)
      F <- vapply(0:nseat, function(j) mean(x <= j), 0)
      O <- as.numeric(0:nseat >= y)
      q <- quantile(x, c(0.05, 0.10, 0.90, 0.95), type = 1, names = FALSE)
      out[[length(out) + 1L]] <- data.table(pair = el, party = p, n_sims = N, n_seats = nseat,
        actual = y, mean_sim = mean(x), sd_sim = sd(x), p_actual = pr,
        ls = -log(max(pr, 0.5 / N)), floor_hit = pr == 0,
        rps = sum((F - O)^2) / nseat,
        c80 = y >= q[2] & y <= q[3], c90 = y >= q[1] & y <= q[4],
        lo90 = q[1], hi90 = q[4])
    }
  }
  rbindlist(out)
}

B <- score_dir(pos[1])
cat(sprintf("STT1 baseline %s: %d elections, %d (election, party) cells, %d floor hits\n",
            pos[1], uniqueN(B$pair), nrow(B), sum(B$floor_hit)))
per_el <- function(D) D[, .(n_party = .N, ls = mean(ls), rps = mean(rps), c80 = mean(c80), c90 = mean(c90),
                            floor = sum(floor_hit)), by = pair]
if (length(pos) == 1L) {
  print(per_el(B)[order(pair)], digits = 4)
  cat(sprintf("STT2 pooled over %d elections: log score %.4f, RPS %.5f, 80%% coverage %.3f (%d/%d), 90%% coverage %.3f (%d/%d)\n",
              uniqueN(B$pair), mean(per_el(B)$ls), mean(per_el(B)$rps), mean(B$c80), sum(B$c80), nrow(B),
              mean(B$c90), sum(B$c90), nrow(B)))
  fwrite(B, file.path(tempdir(), "seat-totals-base.csv"))
  quit(save = "no")
}
A <- score_dir(pos[2])
J <- merge(B, A, by = c("pair", "party"), suffixes = c("_b", "_a"))
if (nrow(J) != nrow(B) || nrow(J) != nrow(A))
  cat(sprintf("STT3 WARNING cells differ: base %d, arm %d, joined %d\n", nrow(B), nrow(A), nrow(J)))
E <- J[, .(n_party = .N, n_seats = n_seats_b[1],
           ls_b = mean(ls_b), ls_a = mean(ls_a), rps_b = mean(rps_b), rps_a = mean(rps_a),
           c80_b = mean(c80_b), c80_a = mean(c80_a), c90_b = mean(c90_b), c90_a = mean(c90_a),
           sd_b = mean(sd_sim_b), sd_a = mean(sd_sim_a),
           floor_b = sum(floor_hit_b), floor_a = sum(floor_hit_a)), by = pair][order(pair)]
E[, d_ls := ls_a - ls_b][, d_rps := rps_a - rps_b]
cat("STT4 per election: mean over scored parties. ls = -log P(actual seat total), rps = ranked probability score / seats\n",
    "     (both lower is better); c80/c90 = share of parties whose actual total is inside the 80/90% interval\n",
    "     (target 0.80/0.90); sd = mean simulated sd of a party's seat total; floor = parties with P(actual) = 0\n")
print(E[, .(pair, n_party, ls_b = round(ls_b, 3), ls_a = round(ls_a, 3), d_ls = round(d_ls, 3),
            rps_b = round(rps_b, 4), rps_a = round(rps_a, 4), c90_b = round(c90_b, 2), c90_a = round(c90_a, 2),
            sd_b = round(sd_b, 2), sd_a = round(sd_a, 2), floor_b, floor_a)])
n <- nrow(E); se <- function(d) sd(d) / sqrt(length(d))
cat(sprintf("STT5 pooled over %d elections (%d party cells): log score %.4f -> %.4f (diff %+.4f, SE %.4f); RPS %.5f -> %.5f (diff %+.5f, SE %.5f)\n",
            n, nrow(J), mean(E$ls_b), mean(E$ls_a), mean(E$d_ls), se(E$d_ls),
            mean(E$rps_b), mean(E$rps_a), mean(E$d_rps), se(E$d_rps)))
cat(sprintf("STT6 coverage over %d cells: 80%% %d -> %d (%.3f -> %.3f); 90%% %d -> %d (%.3f -> %.3f); floor hits %d -> %d; elections better on ls %d of %d\n",
            nrow(J), sum(J$c80_b), sum(J$c80_a), mean(J$c80_b), mean(J$c80_a),
            sum(J$c90_b), sum(J$c90_a), mean(J$c90_b), mean(J$c90_a),
            sum(J$floor_hit_b), sum(J$floor_hit_a), sum(E$d_ls < 0), n))
fwrite(J, file.path(tempdir(), "seat-totals-joined.csv"))
cat("STT7 cell table:", file.path(tempdir(), "seat-totals-joined.csv"), "\n")
cat("STT8 by class (mean over elections where scored): ls = -log P(actual total), lower is better; c90 = 90% coverage\n")
print(J[, .(n_el = .N, ls_b = round(mean(ls_b), 3), ls_a = round(mean(ls_a), 3), d_ls = round(mean(ls_a - ls_b), 3),
            se = round(sd(ls_a - ls_b) / sqrt(.N), 3), c90_b = round(mean(c90_b), 2), c90_a = round(mean(c90_a), 2),
            floor_b = sum(floor_hit_b), floor_a = sum(floor_hit_a)), by = party][order(-n_el)])
loo <- vapply(seq_len(n), function(i) mean(E$d_ls[-i]), 0)
cat(sprintf("STT9 leave-one-election-out pooled log-score diff: range %+.4f to %+.4f (sign holds in %d of %d)\n",
            min(loo), max(loo), sum(sign(loo) == sign(mean(E$d_ls))), n))
