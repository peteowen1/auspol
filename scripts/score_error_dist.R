# Score AUSPOL_ERROR_DIST against the shipped model on the prereg's own terms
# (docs/plans/prereg-error-distribution-2026-10-17.md): seat-winner log loss on EVERY seat (the change touches
# every cell), SE clustered on election, against A and against the parked benchmark C. Lower is better.
#
#   Rscript scripts/score_error_dist.R <base_dir> <arm_dir> <n_sims> [<benchmark_arm_dir>]
#
# Folders hold one subfolder per election with allprobs.csv (quick_arm / deciding-run caches). The benchmark is
# C's screen arm (same baseline byte for byte). Codes EZ0-EZ9.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 3) stop("usage: score_error_dist.R <base_dir> <arm_dir> <n_sims> [<benchmark_arm_dir>]")
base_dir <- a[1]; arm_dir <- a[2]; n_sims <- as.numeric(a[3]); bench_dir <- if (length(a) >= 4) a[4] else NA
eps <- if (n_sims >= 20000) 1e-6 else 0.5 / n_sims
els <- intersect(list.dirs(base_dir, full.names = FALSE, recursive = FALSE), list.dirs(arm_dir, full.names = FALSE, recursive = FALSE))
els <- els[file.exists(file.path(base_dir, els, "allprobs.csv")) & file.exists(file.path(arm_dir, els, "allprobs.csv"))]
cat(sprintf("EZ0 %d elections in both folders; floor eps %.1e; benchmark %s\n", length(els), eps, if (is.na(bench_dir)) "none" else bench_dir))
pw <- function(f) {
  x <- fread(f)
  w <- x[x$is_actual == TRUE, list(p = sum(get("prob"))), by = "seat"]
  w <- merge(data.table(seat = unique(x$seat)), w, by = "seat", all.x = TRUE)
  w[is.na(get("p")), "p" := 0]
  fav <- x[, list(fav_p = max(get("prob")), fav_won = get("is_actual")[which.max(get("prob"))]), by = "seat"]
  merge(w, fav, by = "seat")
}
rows <- rbindlist(lapply(els, function(e) {
  b <- pw(file.path(base_dir, e, "allprobs.csv")); s <- pw(file.path(arm_dir, e, "allprobs.csv"))
  m <- merge(b, s[, c("seat", "p"), with = FALSE], by = "seat", suffixes = c("_a", "_e"))
  if (!is.na(bench_dir) && file.exists(file.path(bench_dir, e, "allprobs.csv"))) {
    cc <- pw(file.path(bench_dir, e, "allprobs.csv"))
    m <- merge(m, cc[, list(seat, p_c = p)], by = "seat", all.x = TRUE)
  } else m[, "p_c" := NA_real_]
  m[, "election" := e]
  m
}))
L <- function(p) -log(pmax(p, eps))
rows[, `:=`(ll_a = L(p_a), ll_e = L(p_e), ll_c = L(p_c))]
cl <- function(x, d) {
  dbar <- mean(d); G <- uniqueN(x$election)
  sums <- x[, list(r = sum(d[.I] - dbar)), by = "election"]$r
  c(n = nrow(x), d = dbar, se = if (G > 1) sqrt(G / (G - 1) * sum(sums^2)) / nrow(x) else NA_real_)
}
pr <- function(lab, x, d) {
  r <- cl(x, d)
  cat(sprintf("  %-38s seats %4d | change %+.4f (SE %.4f)%s\n", lab, r["n"], r["d"], r["se"],
              if (is.finite(r["se"]) && r["d"] < -r["se"]) "  better by >1 SE" else if (is.finite(r["se"]) && r["d"] > r["se"]) "  WORSE by >1 SE" else "  within 1 SE"))
  invisible(r)
}
rows[, d_ea := ll_e - ll_a][, d_ca := ll_c - ll_a][, d_ec := ll_e - ll_c]
cat(sprintf("EZ1 seat-winner log loss (lower is better): A %.4f  E %.4f  C %s\n", mean(rows$ll_a), mean(rows$ll_e),
            if (all(is.na(rows$ll_c))) "n/a" else sprintf("%.4f", mean(rows$ll_c, na.rm = TRUE))))
cat("EZ2 changes, SE clustered on election:\n")
r1 <- pr("PRIMARY: E - A, every seat", rows, rows$d_ea)
hasc <- !all(is.na(rows$p_c))
rc <- if (hasc) pr("benchmark: C - A, every seat", rows, rows$d_ca) else NULL
if (hasc) pr("E - C, every seat", rows, rows$d_ec)
sub <- function(lab, i) pr(lab, rows[i], rows$d_ea[i])
sub("A gave the winner < 0.01", rows$p_a < 0.01)
sub("A gave the winner 0.01-0.5", rows$p_a >= 0.01 & rows$p_a < 0.5)
sub("A gave the winner 0.5+", rows$p_a >= 0.5)
sub("favourites A 0.90+ who won", rows$fav_p >= 0.90 & rows$fav_won == TRUE)
sub("NSW", grepl("^nsw", rows$election))
sub("AEF-7", rows$election %in% c("fed2022", "fed2025", "nsw2023", "qld2024", "sa2026", "vic2022", "wa2025"))
cat(sprintf("EZ3 winners A gave < 0.01: %d seats; E gives them mean %.4f (A %.4f)\n", sum(rows$p_a < 0.01),
            mean(rows$p_e[rows$p_a < 0.01]), mean(rows$p_a[rows$p_a < 0.01])))
pe <- rows[, list(seats = .N, sum_d = sum(d_ea)), by = "election"][order(sum_d)]
net <- sum(rows$d_ea)
pe[, share := if (net < 0) sum_d / net else NA_real_]
cat("EZ4 per election, summed E - A (negative = E better) and share of the net gain:\n")
print(pe[, list(election, seats, sum_d = round(sum_d, 3), share = round(share, 2))], nrows = 60)
top <- if (net < 0) max(pe$share) else NA
cat(sprintf("EZ5 REFUSAL one election > half the gain: largest share %s -> %s\n", format(round(top, 2)),
            if (is.na(top)) "no net gain" else if (top > 0.5) "REFUSED" else "passes"))
fl <- rows$p_a < 1e-4
cat(sprintf("EZ6 FLOOR: gain from seats A gave < 1e-4 (%d seats): %.3f of net %.3f -> %s; without them: ", sum(fl), -sum(rows$d_ea[fl]), -net,
            if (net < 0 && sum(rows$d_ea[fl]) / net > 0.5) "MORE THAN HALF, to Pete as a split result" else "under half"))
nf <- cl(rows[!fl], rows$d_ea[!fl]); cat(sprintf("%+.4f (SE %.4f)\n", nf["d"], nf["se"]))
beats_c <- if (hasc) r1["d"] <= rc["d"] else NA
cat(sprintf("EZ7 VERDICT: primary %s; point gain %s C's (%s)\n",
            if (is.finite(r1["se"]) && r1["d"] < -r1["se"]) "E better than A by more than 1 SE" else "E NOT better by more than 1 SE",
            if (isTRUE(beats_c)) "at least" else if (identical(beats_c, FALSE)) "SMALLER than" else "not compared with",
            if (hasc) sprintf("%+.4f vs %+.4f", r1["d"], rc["d"]) else "n/a"))
