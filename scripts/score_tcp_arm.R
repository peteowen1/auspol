# Score a quick_arm arm against its baseline on two-candidate-preferred (TCP) error, per
# docs/plans/prereg-nsw-exhaust-tcp-2026-11-07.md. Reads the ourtcp.csv and sharedetail.csv
# that quick_arm.R copies into each cache unit; writes nothing.
#   Rscript scripts/score_tcp_arm.R <base_cache_dir> <arm_cache_dir> [pair ...]
# (cache dirs are %TEMP%/auspol-quickarm/cache/<key>; pairs default nsw2019 nsw2023)
#
# Our final two per seat = the most frequent simulated pair; our TCP = that pair's
# f1_tcp_pct, turned to the real winner's side. Scored only where that pair equals the
# real final two (class level). Real final twos: aef7-final-two-and-tcp-reference.csv
# (AEF-7 pairs, f1 = winner, f2cp = winner's TCP) and nsw2019-tcp-official.csv.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
stopifnot(length(a) >= 2)
BASE <- a[1]; ARM <- a[2]
PAIRS <- if (length(a) > 2) a[-(1:2)] else c("nsw2019", "nsw2023")

ref <- fread("output/aef7-final-two-and-tcp-reference.csv", na.strings = c("NA", ""))
ref <- ref[!is.na(f1) & !is.na(f2) & f1 != f2,
           .(pair, seat, w = f1, l = f2, act = f2cp, aef_w = aef_tcp_f1, aef_l = aef_tcp_f2)]
n19 <- fread("output/nsw2019-tcp-official.csv")
n19 <- n19[, .(w = cls[rank == 1], l = cls[rank == 2], act = pct[rank == 1]), by = .(pair, seat)][w != l]
n19[, `:=`(aef_w = NA_character_, aef_l = NA_character_)]
ref <- rbind(ref, n19)

ours <- function(dir, p) {
  f <- file.path(dir, p, "ourtcp.csv")
  if (!file.exists(f)) stop("no ourtcp.csv in ", file.path(dir, p),
                            " (baseline cached before quick_arm kept it: rebuild that unit)")
  d <- fread(f)
  d <- d[d[, .I[which.max(freq)], by = seat]$V1]
  d[, .(seat, o1 = f1, o2 = f2, o1_tcp = f1_tcp_pct, ofreq = freq)]
}

for (p in PAIRS) {
  r <- ref[pair == p]
  stopifnot(nrow(r) > 0)
  b <- ours(BASE, p); m <- ours(ARM, p)
  x <- merge(r, b, by = "seat")
  x <- merge(x, m, by = "seat", suffixes = c("_b", "_a"))
  setnames(x, c("o1", "o2", "o1_tcp", "ofreq"), c("o1_b", "o2_b", "o1_tcp_b", "ofreq_b"), skip_absent = TRUE)
  match_pair <- function(o1, o2) (o1 == x$w & o2 == x$l) | (o1 == x$l & o2 == x$w)
  x[, `:=`(ok_b = match_pair(o1_b, o2_b), ok_a = match_pair(o1_a, o2_a),
           ok_aef = !is.na(aef_w) & ((aef_w == w & aef_l == l) | (aef_w == l & aef_l == w)))]
  x[, `:=`(t_b = fifelse(o1_b == w, o1_tcp_b, 100 - o1_tcp_b),
           t_a = fifelse(o1_a == w, o1_tcp_a, 100 - o1_tcp_a))]
  x[, `:=`(e_b = abs(t_b - act), e_a = abs(t_a - act), marg_b = abs(t_b - 50) < 6)]
  cat(sprintf("\n== %s: %d seats with a real final two; ours matches it: base %d, arm %d; AEF %d\n",
              p, nrow(x), sum(x$ok_b), sum(x$ok_a), sum(x$ok_aef)))
  .drop <- setdiff(b$seat, x$seat)
  if (length(.drop)) cat(sprintf("   %d of our seats have no real final two in the reference, not scored: %s\n",
                                 length(.drop), paste(.drop, collapse = ", ")))
  chg <- x[ok_b != ok_a, .(seat, real = paste(w, l), base = paste(o1_b, o2_b), arm = paste(o1_a, o2_a))]
  if (nrow(chg)) { cat("final-two set changes:\n"); print(chg) }
  sets <- list(both = x[ok_b & ok_a])
  if (any(x$ok_aef)) sets$`both+AEF` <- x[ok_b & ok_a & ok_aef]
  sets$`ALP v LNP` <- x[ok_b & ok_a & ((w == "ALP" & l == "LNP") | (w == "LNP" & l == "ALP"))]
  sets$marginal <- x[ok_b & ok_a & marg_b]
  cat("TCP mean absolute error, points (lower is better); diff = arm - base, SE over seats\n")
  out <- rbindlist(lapply(names(sets), function(s) {
    y <- sets[[s]]
    if (!nrow(y)) return(NULL)
    d <- y$e_a - y$e_b
    data.table(set = s, n = nrow(y), base = round(mean(y$e_b), 3), arm = round(mean(y$e_a), 3),
               diff = round(mean(d), 3), se = round(sd(d) / sqrt(nrow(y)), 3))
  }))
  print(out)
  y <- sets$`ALP v LNP`
  if (nrow(y) > 2) {
    alp <- function(t) fifelse(y$w == "ALP", t, 100 - t)
    act_alp <- alp(y$act)
    cat(sprintf("slope of actual on predicted ALP TCP (1 = right width): base %.3f, arm %.3f\n",
                coef(lm(act_alp ~ alp(y$t_b)))[2], coef(lm(act_alp ~ alp(y$t_a)))[2]))
  }
  fav <- x[ok_b & ok_a & ((t_b > 50) != (t_a > 50)), .N]
  cat(sprintf("favourite flips (on matched seats): %d\n", fav))
  sb <- fread(file.path(BASE, p, "sharedetail.csv")); sa <- fread(file.path(ARM, p, "sharedetail.csv"))
  cat(sprintf("per-SEAT mean |ALP primary miss| (not the statewide guard-4 figure): base %.3f, arm %.3f\n",
              sb[party == "ALP", mean(abs(pred_share - actual_share), na.rm = TRUE)],
              sa[party == "ALP", mean(abs(pred_share - actual_share), na.rm = TRUE)]))
}
