setwd("C:/dev/auspol")
suppressMessages(library(data.table))

# Pairs in the deterministic order each harness prints them.
ORDER <- list(
  fed   = c("fed2007","fed2010","fed2013","fed2016","fed2019","fed2022","fed2025"),
  nsw19 = "nsw2019", nsw23 = "nsw2023",
  qld20 = "qld2020", qld24 = "qld2024",
  sa26  = "sa2026",
  vic   = c("vic2014","vic2018","vic2022"),
  wa    = c("wa2001","wa2005","wa2008","wa2013","wa2017","wa2021","wa2025")
)
SEATS <- c(fed2007=149, fed2010=147, fed2013=150, fed2016=147, fed2019=143,
           fed2022=150, fed2025=150, nsw2019=93, nsw2023=88, qld2020=93,
           qld2024=93, sa2026=47, vic2014=73, vic2018=88, vic2022=78,
           wa2001=57, wa2005=46, wa2008=38, wa2013=55, wa2017=54, wa2021=58, wa2025=53)

grab <- function(f) {
  if (!file.exists(f)) return(numeric(0))
  L <- readLines(f, warn = FALSE)
  hit <- grep("\\| log (score )?[0-9]", L, value = TRUE)
  as.numeric(sub(".*\\| log (score )?([0-9.]+).*", "\\2", hit))
}

collect <- function(dir) {
  out <- list()
  for (lab in names(ORDER)) {
    v <- grab(file.path(dir, paste0(lab, ".log")))
    pr <- ORDER[[lab]]
    if (!length(v)) next
    n <- min(length(v), length(pr))
    out[[lab]] <- data.table(pair = pr[seq_len(n)], log_loss = v[seq_len(n)])
  }
  if (!length(out)) return(NULL)
  rbindlist(out)
}

res <- list()
for (d in list.dirs("output/_flowrun", recursive = FALSE)) {
  x <- collect(d)
  if (is.null(x)) next
  b <- basename(d)                       # "<arm>_s<seed>"
  x[, arm := sub("_s[0-9]+$", "", b)]
  x[, seed := as.integer(sub(".*_s", "", b))]
  res[[b]] <- x
}
if (!length(res)) { cat("no results yet\n"); quit(save = "no") }
R <- rbindlist(res)
R[, seats := SEATS[pair]]

pooled <- function(ll, sw) sum(ll * sw) / sum(sw)

cat("=== completeness: pairs done per arm/seed (22 = full) ===\n")
print(dcast(R, arm ~ seed, value.var = "log_loss", fun.aggregate = length),
      row.names = FALSE)

cat("\n=== pooled seat-weighted log loss per arm/seed (LOWER IS BETTER) ===\n")
P <- R[, .(pairs = .N, seats = sum(seats), pooled = pooled(log_loss, seats)),
       by = .(arm, seed)]
print(P[order(arm, seed)], row.names = FALSE, digits = 4)

# Only pairs BOTH arms have finished, at every seed, are comparable.
full <- R[, .(n = .N), by = .(pair, arm)][, .(arms = .N, n = sum(n)), by = pair]
ok_pairs <- full[arms == uniqueN(R$arm) & n == uniqueN(R$arm) * uniqueN(R$seed), pair]
cat(sprintf("\ncomparable pairs (every arm, every seed): %d of %d\n",
            length(ok_pairs), uniqueN(R$pair)))
if (!length(ok_pairs)) quit(save = "no")
C <- R[pair %chin% ok_pairs]

# Seed-average within arm, then compare. Averaging the SEEDS (not pooling the
# raw runs) is what makes the delta an estimate of the model effect rather than
# of one seed's luck.
A <- C[, .(mean_ll = mean(log_loss), sd_ll = sd(log_loss),
           rng = max(log_loss) - min(log_loss)), by = .(pair, arm, seats)]
W <- dcast(A, pair + seats ~ arm, value.var = "mean_ll")
if (!all(c("ship", "xgb") %in% names(W))) { print(W, row.names = FALSE); quit(save = "no") }
W[, delta := xgb - ship]
cat("\n=== per pair, seed-averaged over 3 seeds (LOWER IS BETTER; delta < 0 means xgb wins) ===\n")
print(W[order(delta)], row.names = FALSE, digits = 4)

p_ship <- pooled(W$ship, W$seats); p_xgb <- pooled(W$xgb, W$seats)
cat(sprintf("\n=== POOLED, %d pairs, %d seat-elections ===\n", nrow(W), sum(W$seats)))
cat(sprintf("  shipped        %.4f\n  xgb-flows      %.4f\n  delta          %+.4f  (%+.2f%%)\n",
            p_ship, p_xgb, p_xgb - p_ship, 100 * (p_xgb - p_ship) / p_ship))
cat(sprintf("  pairs better %d | worse %d\n", sum(W$delta < 0), sum(W$delta > 0)))

cat("\n=== seed noise: per-pair range across the 3 seeds, by arm ===\n")
S <- A[, .(median_range = median(rng), max_range = max(rng),
           median_sd = median(sd_ll)), by = arm]
print(S, row.names = FALSE, digits = 4)

# The decisive question: is the pooled edge bigger than what seeds alone move?
# Recomputed over the COMPARABLE pairs only, so this spread and the delta above
# are built from the same seat-elections.
PS <- C[, .(pooled_seed = pooled(log_loss, seats)), by = .(arm, seed)][
  , .(lo = min(pooled_seed), hi = max(pooled_seed),
      spread = max(pooled_seed) - min(pooled_seed)), by = arm]
cat("\n=== pooled figure's own spread across seeds (the noise floor for the delta) ===\n")
print(PS, row.names = FALSE, digits = 4)
cat(sprintf("\n  |pooled delta| = %.4f vs worst-arm pooled seed spread = %.4f -> %s\n",
            abs(p_xgb - p_ship), max(PS$spread),
            if (abs(p_xgb - p_ship) > max(PS$spread)) "OUTSIDE seed noise" else "INSIDE seed noise"))

cat("\n=== vic2022 across seeds (live target jurisdiction) ===\n")
V <- C[pair == "vic2022", .(arm, seed, log_loss)]
print(dcast(V, seed ~ arm, value.var = "log_loss"), row.names = FALSE, digits = 4)
if (nrow(V)) {
  vs <- V[arm == "ship", mean(log_loss)]; vx <- V[arm == "xgb", mean(log_loss)]
  vr <- A[pair == "vic2022", .(arm, rng)]
  cat(sprintf("  ship mean %.4f | xgb mean %.4f | delta %+.4f\n", vs, vx, vx - vs))
  print(vr, row.names = FALSE, digits = 4)
  cat(sprintf("  -> delta is %s the per-seed range on this pair\n",
              if (abs(vx - vs) > max(vr$rng)) "LARGER than" else "WITHIN"))
}

cat("\n=== worst regressions, seed-averaged ===\n")
print(head(W[order(-delta), .(pair, seats, ship, xgb, delta)], 5), row.names = FALSE, digits = 4)
