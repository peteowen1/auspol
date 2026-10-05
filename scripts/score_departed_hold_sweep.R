# Scores the departed-hold sweep. Usage: ARM=on|onB S=<scratchpad dir containing sweep/> Rscript scripts/score_departed_hold_sweep.R  (see docs/reviews/departed-hold-sweep-2026-10-05.md)
# Scores the prereg docs/plans/prereg-departed-hold-fixed-2026-10-04.md from the sweep directories.
S <- Sys.getenv("S"); sw <- file.path(S, "sweep")
ARM <- Sys.getenv("ARM", "on")
dirs <- list.dirs(sw, recursive = FALSE); dirs <- dirs[grepl(paste0("_(base|off|", ARM, ")$"), dirs)]
key <- sub("_(base|off|on|onB)$", "", basename(dirs)); arms <- sub(".*_", "", basename(dirs))
rd <- function(d, pat) { f <- list.files(d, pattern = pat, full.names = TRUE); if (length(f) != 1) return(NULL); read.csv(f, stringsAsFactors = FALSE) }
k <- function(d) paste(d$seat, d$party)
EPS <- 1e-6
seat_ll <- function(ap) { a <- ap[ap$is_actual %in% TRUE, ]; mean(-log(pmax(a$prob, EPS))) }
rows <- list(); cells <- list(); winloss <- list()
for (kk in unique(key)) {
  get <- function(arm) { d <- dirs[key == kk & arms == arm]; if (!length(d)) return(NULL)
    list(sd = rd(d, "sharedetail"), ap = rd(d, "allprobs"), held = if (file.exists(file.path(d, "held.csv"))) read.csv(file.path(d, "held.csv")) else NULL) }
  b <- get("base"); o <- get("off"); n <- get(ARM)
  if (is.null(b$sd) || is.null(o$sd) || is.null(n$sd)) { cat("MISSING arm for", kk, "\n"); next }
  m1 <- match(k(o$sd), k(b$sd)); diff_bo <- sum(abs(o$sd$pred_share - b$sd$pred_share[m1]) > 0 | is.na(m1), na.rm = TRUE)
  m2 <- match(k(o$sd), k(n$sd))
  nn <- n$sd[m2, ]; held <- n$held; hk <- if (!is.null(held) && nrow(held)) paste(held$seat, held$party) else character(0)
  is_held <- k(o$sd) %in% hk
  held_rows <- o$sd$seat %in% unique(held$seat)
  chg <- abs(nn$pred_share - o$sd$pred_share) > 1e-9
  leak <- sum(chg & !held_rows)   # changed cell in a row with no held cell: must be 0
  ae_off <- abs(o$sd$pred_share - o$sd$actual_share); ae_on <- abs(nn$pred_share - o$sd$actual_share)
  rmse_w <- function(p) sqrt(sum(o$sd$actual_share * (p - o$sd$actual_share)^2) / sum(o$sd$actual_share))
  ll_off <- if (!is.null(o$ap)) seat_ll(o$ap) else NA; ll_on <- if (!is.null(n$ap)) seat_ll(n$ap) else NA
  rows[[kk]] <- data.frame(pair = kk, n_cells = nrow(o$sd), held = sum(is_held), held_seats = length(unique(held$seat)),
    base_vs_off_diff = diff_bo, unheld_row_leak = leak,
    held_ae_off = mean(ae_off[is_held]), held_ae_on = mean(ae_on[is_held]),
    rows_ae_off = mean(ae_off[held_rows]), rows_ae_on = mean(ae_on[held_rows]),
    rmse_w_off = rmse_w(o$sd$pred_share), rmse_w_on = rmse_w(nn$pred_share), ll_off = ll_off, ll_on = ll_on)
  cc <- o$sd[is_held, c("seat", "party", "pred_share", "actual_share")]; if (nrow(cc)) { cc$on <- nn$pred_share[is_held]; cc$pair <- kk; cells[[kk]] <- cc }
  # independent win probability in seats where an independent actually won
  if (!is.null(o$ap) && !is.null(n$ap)) {
    w <- function(ap) { a <- ap[ap$party == "IND" & ap$actual == "IND", ]; setNames(a$prob, a$seat) }
    wo <- w(o$ap); wn <- w(n$ap); common <- intersect(names(wo), names(wn))
    if (length(common)) winloss[[kk]] <- data.frame(pair = kk, seat = common, p_off = wo[common], p_on = wn[common])
  }
}
R <- do.call(rbind, rows); rownames(R) <- NULL
num <- sapply(R, is.numeric); R[num] <- lapply(R[num], function(x) round(x, 3))
cat("\n== Per pair (points; lower error is better; ll = mean seat log loss, lower is better)\n"); print(R[, c("pair","n_cells","held","held_seats","base_vs_off_diff","unheld_row_leak","held_ae_off","held_ae_on","rows_ae_off","rows_ae_on","ll_off","ll_on")], row.names = FALSE)
cat("\nCriterion 4 (byte-identical): base vs off cells differing, total =", sum(R$base_vs_off_diff), "; changed cells in rows with no held cell, total =", sum(R$unheld_row_leak), "(both must be 0)\n")
cl <- function(x) { x <- x[is.finite(x)]; c(mean = mean(x), se = sd(x) / sqrt(length(x)), n = length(x)) }
d1 <- R$held_ae_on - R$held_ae_off; d2 <- R$rows_ae_on - R$rows_ae_off; d3 <- R$ll_on - R$ll_off; d4 <- R$rmse_w_on - R$rmse_w_off
cat("\n== Pair-clustered (each pair is one observation); negative change = better\n")
for (nm in c("1 primary: held-cell mean abs error change", "2 all cells in held rows: mean abs error change", "3a pooled seat log loss change", "3b actual-weighted share RMSE change")) {
  v <- switch(substr(nm, 1, 2), "1 " = d1, "2 " = d2, "3a" = d3, "3b" = d4); s <- cl(v)
  cat(sprintf("%-52s mean %+.4f  SE %.4f  n_pairs %d  (mean/SE = %+.2f)\n", nm, s["mean"], s["se"], s["n"], s["mean"] / s["se"]))
}
C <- do.call(rbind, cells)
cat("\n== Held cells pooled: n =", nrow(C), " mean abs error off", round(mean(abs(C$pred_share - C$actual_share)), 3), " on", round(mean(abs(C$on - C$actual_share)), 3), "\n")
cat("by party (n, off, on):\n"); for (p in sort(unique(C$party))) { x <- C[C$party == p, ]; cat(sprintf("  %-10s %4d  %.2f  %.2f\n", p, nrow(x), mean(abs(x$pred_share - x$actual_share)), mean(abs(x$on - x$actual_share)))) }
C$gain <- abs(C$pred_share - C$actual_share) - abs(C$on - C$actual_share)
cat("\nNamed flagships (abs error off -> on):\n"); for (s in c("New England", "Lyne", "Morwell", "Churchlands")) { x <- C[C$seat == s & C$party == "IND", ]; if (nrow(x)) print(x[, c("pair","seat","pred_share","on","actual_share")], row.names = FALSE) }
cat("\nBiggest 6 gains and 6 losses among held cells:\n"); o <- C[order(-C$gain), ]; print(rbind(head(o, 6), tail(o, 6))[, c("pair","seat","party","pred_share","on","actual_share","gain")], row.names = FALSE, digits = 3)
if (length(winloss)) { W <- do.call(rbind, winloss); cat(sprintf("\nIND win probability where an independent won (n seats = %d): mean off %.3f, on %.3f; seats where it FELL: %d, ROSE: %d\n", nrow(W), mean(W$p_off), mean(W$p_on), sum(W$p_on < W$p_off - 1e-9), sum(W$p_on > W$p_off + 1e-9)))
  W$d <- W$p_on - W$p_off; print(head(W[order(W$d), ], 6), row.names = FALSE, digits = 3) }

cat("\n===== EXTRA: where do the failures come from =====\n")
tot_gain <- sum(C$gain); two <- C$seat %in% c("New England","Lyne") & C$pair == "fed_2013"
cat(sprintf("held cells: total gain %.1f points over %d cells; New England+Lyne fed2013 = %.1f (%.0f%%); mean gain per cell excluding those two: %+.4f (off %.3f -> on %.3f)\n",
  tot_gain, nrow(C), sum(C$gain[two]), 100*sum(C$gain[two])/tot_gain, mean(C$gain[!two]), mean(abs(C$pred_share[!two]-C$actual_share[!two])), mean(abs(C$on[!two]-C$actual_share[!two]))))
# actual-weighted squared-error contribution change per held cell, per pair
C$dsq <- C$actual_share * ((C$on - C$actual_share)^2 - (C$pred_share - C$actual_share)^2)
cat("\nweighted squared-error change, summed over held cells (positive = worse): total", round(sum(C$dsq)), "\n")
o <- C[order(-C$dsq), ]; cat("worst 6 contributors to the RMSE rise:\n"); print(head(o, 6)[, c("pair","seat","party","pred_share","on","actual_share","dsq")], row.names=FALSE, digits=3)
cat("\nbest 4:\n"); print(tail(o, 4)[, c("pair","seat","party","pred_share","on","actual_share","dsq")], row.names=FALSE, digits=3)
cat("\nRMSE change per pair (on - off, weighted):\n"); print(round(setNames(R$rmse_w_on - R$rmse_w_off, R$pair), 3))
cat("\nwithout the single worst pair, mean RMSE change:", round(mean((R$rmse_w_on - R$rmse_w_off)[-which.max(R$rmse_w_on - R$rmse_w_off)]), 4), "\n")
cat("pairs where held-cell error improved:", sum(d1 < 0), "of", length(d1), "; log loss improved:", sum(d3 < 0), "of", length(d3), "\n")
Wd <- W[order(W$d), ]; cat(sprintf("IND win prob where IND won: sum of falls %.3f, sum of rises %.3f; excluding Mount Gambier & Kavel sa2026, mean change %+.4f\n", sum(Wd$d[Wd$d<0]), sum(Wd$d[Wd$d>0]), mean(W$d[!(W$seat %in% c("Mount Gambier","Kavel") & W$pair=="sa_2026")])))
