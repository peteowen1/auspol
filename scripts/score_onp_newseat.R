# Primary metric of docs/plans/prereg-onp-newseat-rule-2026-10-25.md, scored from two quick_arm.R
# cache keys (the baseline and the arm; quick_arm prints both as "baseline cache <key>" / "arm cache
# <key>"). Restricted to the pre-registered target seats
# (docs/plans/onp-newseat-target-seats-2026-10-25.csv: One Nation stood now, had no candidate last time).
#
# Per target seat:
#   seat log loss  -log(max(p_winner, 1e-6)), p_winner from allprobs (0 when the winner's class has no row)
#   ONP error      ONP pred_share - actual, pred 0 where the run has no ONP row (a harness with no ONP
#                  column predicts nothing), actual from the target list
# Arm minus baseline, pooled over every target seat present in both runs; SE clustered on election
# (cluster-robust, small-sample factor G/(G-1)). Lower is better for both. Also the guard: seat log loss
# over ALL seats of the same elections, same SE.
#
# Run: powershell.exe -Command 'Rscript scripts/score_onp_newseat.R <base_key> <arm_key> [quickarm_dir] [targets_csv]'
#   quickarm_dir defaults to $TEMP/auspol-quickarm.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: score_onp_newseat.R <base_key> <arm_key> [quickarm_dir] [targets_csv]")
KB <- args[1]; KA <- args[2]
QD <- if (length(args) >= 3) args[3] else file.path(Sys.getenv("TEMP"), "auspol-quickarm")
TF <- if (length(args) >= 4) args[4] else file.path("docs", "plans", "onp-newseat-target-seats-2026-10-25.csv")
suppressMessages(library(data.table))
EPS <- 1e-6
tg <- fread(TF)
stopifnot(nrow(tg) > 0, !anyDuplicated(tg[, .(election, seat)]))
els <- intersect(list.dirs(file.path(QD, "cache", KB), full.names = FALSE, recursive = FALSE),
                 list.dirs(file.path(QD, "cache", KA), full.names = FALSE, recursive = FALSE))
cat(sprintf("SNS0  base %s | arm %s | %d election(s) cached in both: %s\n", KB, KA, length(els), paste(sort(els), collapse = " ")))
stopifnot(length(els) > 0)

score_run <- function(key, el) {
  d <- file.path(QD, "cache", key, el)
  ap <- fread(file.path(d, "allprobs.csv")); sd <- fread(file.path(d, "sharedetail.csv"))
  stopifnot(nrow(ap) > 0, nrow(sd) > 0, all(c("seat", "prob", "is_actual") %in% names(ap)))
  if ("pair" %in% names(ap)) { .el <- el; ap <- ap[ap$pair == .el] }
  if ("pair" %in% names(sd)) { .el <- el; sd <- sd[sd$pair == .el] }
  wl <- ap[, list(p = sum(prob[is_actual %in% TRUE])), by = "seat"]
  wl[, ll := -log(pmax(p, EPS))]
  on <- sd[sd$party == "ONP", list(seat, onp_pred = pred_share)]
  list(ll = wl[, list(seat, ll)], onp = on)
}

rows <- list(); allr <- list()
for (el in els) {
  B <- score_run(KB, el); A <- score_run(KA, el)
  m <- merge(B$ll, A$ll, by = "seat", suffixes = c("_b", "_a"))
  allr[[el]] <- data.table(election = el, d = m$ll_a - m$ll_b)
  .el <- el
  t <- tg[tg$election == .el]
  if (!nrow(t)) next
  t <- merge(t, m, by = "seat")
  t[, onp_b := B$onp$onp_pred[match(seat, B$onp$seat)]]; t[is.na(onp_b), onp_b := 0]
  t[, onp_a := A$onp$onp_pred[match(seat, A$onp$seat)]]; t[is.na(onp_a), onp_a := 0]
  rows[[el]] <- t[, list(election = .el, seat, ll_b, ll_a, se_b = (onp_b - onp_actual)^2, se_a = (onp_a - onp_actual)^2,
                         onp_b, onp_a, onp_actual)]
}
S <- rbindlist(rows)
cat(sprintf("SNS1  %d target seats scored over %d election(s) (of %d target seats listed)\n", nrow(S), uniqueN(S$election), nrow(tg)))
stopifnot(nrow(S) > 0)
.um <- tg[tg$election %in% els & !paste(tg$election, tg$seat) %in% paste(S$election, S$seat)]
if (nrow(.um)) cat(sprintf("SNS1! %d listed target seat(s) not in the runs' seat names (not scored): %s\n", nrow(.um),
                           paste(sprintf("%s/%s", .um$election, .um$seat), collapse = ", ")))

clustered <- function(d, g) {
  N <- length(d); D <- sum(d) / N
  s <- tapply(d, g, sum); n <- tapply(d, g, length); G <- length(s)
  se <- if (G > 1) sqrt(sum((s - D * n)^2)) / N * sqrt(G / (G - 1)) else NA_real_
  c(diff = D, se = se, G = G, N = N)
}
per <- S[, list(n = .N, ll_b = mean(ll_b), ll_a = mean(ll_a), rmse_b = sqrt(mean(se_b)), rmse_a = sqrt(mean(se_a)),
                onp_b = mean(onp_b), onp_a = mean(onp_a), onp_actual = mean(onp_actual)), by = "election"]
cat("SNS2  per election, target seats (seat log loss and ONP share RMSE in points; lower is better):\n")
print(per[order(election)], digits = 4)
p1 <- clustered(S$ll_a - S$ll_b, S$election)
p2 <- clustered(S$se_a - S$se_b, S$election)
cat(sprintf("SNS3  PRIMARY target-seat log loss, arm - base: %+.4f (SE %.4f, clustered on %d elections, %d seats)\n", p1[["diff"]], p1[["se"]], p1[["G"]], p1[["N"]]))
cat(sprintf("SNS3  PRIMARY target-seat ONP share RMSE: base %.3f, arm %.3f; squared error arm - base %+.3f (SE %.3f)\n",
            sqrt(mean(S$se_b)), sqrt(mean(S$se_a)), p2[["diff"]], p2[["se"]]))
AL <- rbindlist(allr)
g1 <- clustered(AL$d, AL$election)
cat(sprintf("SNS4  GUARD all-seat log loss over these elections, arm - base: %+.4f (SE %.4f, %d elections, %d seats)\n",
            g1[["diff"]], g1[["se"]], g1[["G"]], g1[["N"]]))
for (drop in unique(S$election)) {
  .k <- S$election != drop
  if (uniqueN(S$election[.k]) < 2) next
  q <- clustered(S$ll_a[.k] - S$ll_b[.k], S$election[.k])
  cat(sprintf("SNS5  leave out %-8s target-seat log loss %+.4f (SE %.4f)\n", drop, q[["diff"]], q[["se"]]))
}
