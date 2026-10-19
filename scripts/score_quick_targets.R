# Targeted scorer for a quick_arm / deciding-run pair of caches, implementing the standard decision rule
# (docs/PRE-REGISTRATION-RULES.md) for a fix that acts on some seats only. Committed with its prereg BEFORE the arm runs.
#
# Usage: Rscript scripts/score_quick_targets.R <baseline_cache_dir> <arm_cache_dir> <n_sims> [threshold=0.05]
#   each cache dir holds <election>/{sharedetail,allprobs}.csv (quick_arm's cache/<key>/).
# Targets: seats where any cell's pred_share moved by more than `threshold` points between the two runs -- chosen from
# predictions only, never from the outcome. Seat-winner log loss floored at 0.5/n_sims (quick_arm's floor), and again
# at 1e-4 as the floor-robustness report.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 3L) stop("usage: score_quick_targets.R <baseline_cache_dir> <arm_cache_dir> <n_sims> [threshold]")
dir_a <- a[1]; dir_b <- a[2]; nsims <- as.numeric(a[3]); thr <- if (length(a) >= 4L) as.numeric(a[4]) else 0.05
if (!is.finite(nsims) || nsims < 100) stop("n_sims must be a number >= 100, got ", a[3])
EPS <- 0.5 / nsims
els <- intersect(list.dirs(dir_a, full.names = FALSE, recursive = FALSE), list.dirs(dir_b, full.names = FALSE, recursive = FALSE))
if (!length(els)) stop("no election folders in common between ", dir_a, " and ", dir_b)
rd <- function(d, e, f) { p <- file.path(d, e, f); if (!file.exists(p)) stop("missing ", p); fread(p, showProgress = FALSE) }

seat_rows <- rbindlist(lapply(els, function(e) {
  SA <- rd(dir_a, e, "sharedetail.csv"); SB <- rd(dir_b, e, "sharedetail.csv")
  M <- merge(SA[, list(seat, party, pa = pred_share, actual_share)], SB[, list(seat, party, pb = pred_share)],
             by = c("seat", "party"), all = TRUE)
  if (anyNA(M$pa) || anyNA(M$pb)) stop(e, ": the two runs do not have the same cells (", sum(is.na(M$pa) | is.na(M$pb)), " unmatched)")
  M[, mv := abs(pb - pa)]
  tg <- M[, list(target = any(mv > thr), max_move = max(mv), n_down = sum(pb < pa - thr), n_up = sum(pb > pa + thr),
                 sq_change = sum(((actual_share - pb)^2 - (actual_share - pa)^2)[mv > thr])), by = seat]
  PA <- rd(dir_a, e, "allprobs.csv"); PB <- rd(dir_b, e, "allprobs.csv")
  # as quick_winner_prob() (R/quick_arm.R): the winner's probability, 0 when that party has no row (never drawn)
  wp <- function(P) { hit <- P$party == P$actual; hit[is.na(hit)] <- FALSE
    s <- tapply(P$prob[hit], P$seat[hit], sum); u <- unique(P$seat); p <- as.numeric(s[u]); p[is.na(p)] <- 0
    data.table(seat = u, p = p) }
  wa <- wp(PA); wb <- wp(PB); setnames(wa, "p", "p_a"); setnames(wb, "p", "p_b")
  W <- merge(wa, wb, by = "seat")
  if (nrow(W) != nrow(wa) || nrow(W) != nrow(wb)) stop(e, ": seat sets differ (baseline ", nrow(wa), ", arm ", nrow(wb), ")")
  out <- merge(W, tg, by = "seat", all.x = TRUE)
  out[is.na(target), `:=`(target = FALSE, max_move = 0, n_down = 0L, n_up = 0L, sq_change = 0)]
  out[, election := e]
  out
}))
ll <- function(p, eps) -log(pmax(p, eps))
seat_rows[, d := ll(p_b, EPS) - ll(p_a, EPS)][, d4 := ll(p_b, 1e-4) - ll(p_a, 1e-4)]
cat(sprintf("ST0 %d seats in %d elections; floor %.1e (0.5/%g); target threshold %.2f points\n",
            nrow(seat_rows), length(els), EPS, nsims, thr))

# mean paired change with SE clustered on election
csum <- function(dt, col) {
  v <- dt[[col]]; g <- dt$election; n <- length(v)
  if (n < 2L) return(c(mean = NA_real_, se = NA_real_, n = n, g = length(unique(g))))
  m <- mean(v); r <- tapply(v - m, g, sum); G <- length(r)
  c(mean = m, se = if (G > 1L) sqrt(G / (G - 1)) * sqrt(sum(r^2)) / n else NA_real_, n = n, g = G)
}
verdict <- function(s) if (!is.finite(s["se"])) "NOT ASSESSABLE" else if (s["mean"] < -s["se"]) "BETTER by more than 1 SE" else if (s["mean"] > s["se"]) "WORSE by more than 1 SE" else "within 1 SE"
T <- seat_rows[seat_rows$target]
cat(sprintf("ST1 targets: %d seats in %d elections; cells moved down %d, up %d (direction); squared share error on moved cells %+.1f\n",
            nrow(T), uniqueN(T$election), sum(T$n_down), sum(T$n_up), sum(T$sq_change)))
if (nrow(T) < 5L) { cat("ST2 PRIMARY => NOT ASSESSABLE (fewer than 5 target seats): counts as FAIL\n"); quit(save = "no") }
p <- csum(T, "d"); p4 <- csum(T, "d4")
cat(sprintf("ST2 PRIMARY (clause 1) target-seat log loss change %+.4f (SE %.4f, %d seats, %d elections) => %s\n",
            p["mean"], p["se"], p["n"], p["g"], verdict(p)))
cat(sprintf("    at a 1e-4 floor: %+.4f (SE %.4f) => %s\n", p4["mean"], p4["se"], verdict(p4)))
g <- csum(seat_rows, "d")
cat(sprintf("ST3 GUARD (clause 2) all-seat log loss change %+.4f (SE %.4f, %d seats) => %s\n", g["mean"], g["se"], g["n"],
            if (g["mean"] > g["se"]) "FAIL (worse by more than 1 SE)" else "PASS"))
loo <- rbindlist(lapply(unique(T$election), function(e) { s <- csum(T[T$election != e], "d")
  data.table(dropped = e, change = s["mean"], se = s["se"], holds = isTRUE(s["mean"] < -s["se"])) }))
cat(sprintf("ST4 LEAVE-ONE-ELECTION-OUT (clause 3): primary better by more than 1 SE in %d of %d drops => %s\n",
            sum(loo$holds), nrow(loo), if (all(loo$holds)) "PASS" else "FAIL"))
share <- T[, list(seats = .N, sum_change = sum(d)), by = election][, share_of_gain := round(sum_change / sum(T$d), 2)][order(sum_change)]
print(share, row.names = FALSE)
pe <- seat_rows[, list(seats = .N, change = mean(d), se_own = if (.N > 1L) sd(d) / sqrt(.N) else NA_real_), by = election]
pe[, worse_2se := is.finite(se_own) & se_own > 0 & change > 2 * se_own]
cat(sprintf("ST5 NO ELECTION WORSE (clause 4): %d election(s) worse by more than 2 SE of their own seats => %s\n",
            sum(pe$worse_2se), if (any(pe$worse_2se)) paste("FAIL:", paste(pe$election[pe$worse_2se], collapse = ", ")) else "PASS"))
print(pe[order(-change)][1:min(6, .N), list(election, seats, change = round(change, 4), se_own = round(se_own, 4), worse_2se)], row.names = FALSE)
top2 <- T[order(d)][seq_len(min(2L, .N))]
rest <- T[!(paste(T$election, T$seat) %in% paste(top2$election, top2$seat))]
nt <- csum(seat_rows[!seat_rows$target], "d")
cat(sprintf("ST6 NOT ONE SEAT (clause 5): without the two largest gains (%s) the target change is %+.4f => %s; non-target seats %+.4f (SE %.4f) => %s\n",
            paste(top2$election, top2$seat, collapse = "; "), mean(rest$d), if (mean(rest$d) < 0) "sign kept" else "FAIL (sign lost)",
            nt["mean"], nt["se"], if (is.finite(nt["se"]) && nt["mean"] > nt["se"]) "FAIL (worse by more than 1 SE)" else "PASS"))
cat("ST7 largest seat moves (log loss change, lower is better; p_win of the actual winner):\n")
print(T[order(d)][unique(c(seq_len(min(5L, .N)), max(1L, .N - 4L):.N)),
        list(election, seat, p_base = round(p_a, 3), p_arm = round(p_b, 3), change = round(d, 4), max_move = round(max_move, 2))], row.names = FALSE)
