# Score AUSPOL_CLASS_SPLIT against the shipped model on the prereg's own terms
# (docs/plans/prereg-class-split-2026-11-06.md): seat-winner log loss (lower is
# better) on the 84 seats with two or more candidates of one minor class at 5%+,
# SE clustered on election, then the guards and the unacceptable-win line.
#
#   Rscript scripts/score_class_split.R <base_dir> <arm_dir> <n_sims>
#
# base_dir / arm_dir hold one folder per election with allprobs.csv (quick_arm's
# cache folders, or a deciding run's).
suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 3) stop("usage: score_class_split.R <base_dir> <arm_dir> <n_sims>")
base_dir <- a[1]; arm_dir <- a[2]; n_sims <- as.numeric(a[3])
eps <- if (n_sims >= 20000) 1e-6 else 0.5 / n_sims
els <- intersect(list.dirs(base_dir, full.names = FALSE, recursive = FALSE),
                 list.dirs(arm_dir, full.names = FALSE, recursive = FALSE))
els <- els[file.exists(file.path(base_dir, els, "allprobs.csv")) & file.exists(file.path(arm_dir, els, "allprobs.csv"))]
cat(sprintf("CX0 %d elections in both folders; floor eps %.1e\n", length(els), eps))
classes <- c("IND", "OTH", "OTH_RIGHT")

# Primary set: defined by ACTUAL shares (stated in the prereg as favouring the arm).
cd <- fread(out_path("candidacies.csv"))
mc <- cd[cd$party %in% classes, list(n5 = sum(get("pcv") >= 5, na.rm = TRUE)), by = c("election", "seat", "party")]
prim <- unique(mc[mc$n5 >= 2L, c("election", "seat"), with = FALSE])
prim_key <- paste(prim$election, prim$seat)
cat(sprintf("CX1 primary set: %d seat-elections with 2+ of one minor class at 5%%+\n", length(prim_key)))

# Junior (by prediction) actual share per split seat, for the unacceptable-win line.
oof <- fread(out_path(class_split_src()))   # the file the arm split by (AUSPOL_CLASS_SPLIT_SRC)
cat(sprintf("CX2 junior shares from %s\n", class_split_src()))
oof <- oof[oof$cls %in% classes & is.finite(oof$pred_xgb)]
oof[, "p" := pmax(get("pred_xgb"), 0.01)]
setorderv(oof, c("election", "seat", "cls", "p"), c(1L, 1L, 1L, -1L))
jun <- oof[, list(n = .N, p2 = get("p")[2], j_share = get("share")[2]), by = c("election", "seat", "cls")][get("n") >= 2L]

ll <- function(f) {
  x <- fread(f)
  w <- x[x$is_actual == TRUE, list(p = sum(get("prob"))), by = "seat"]
  w <- merge(data.table(seat = unique(x$seat)), w, by = "seat", all.x = TRUE)
  w[is.na(get("p")), "p" := 0]
  w[, "ll" := -log(pmax(get("p"), eps))]
  merge(w, unique(x[x$is_actual == TRUE, c("seat", "actual"), with = FALSE]), by = "seat", all.x = TRUE)
}
probs <- list()
rows <- rbindlist(lapply(els, function(e) {
  b <- ll(file.path(base_dir, e, "allprobs.csv")); s <- ll(file.path(arm_dir, e, "allprobs.csv"))
  m <- merge(b[, c("seat", "ll", "actual"), with = FALSE], s[, c("seat", "ll"), with = FALSE],
             by = "seat", suffixes = c("_a", "_s"))
  cs <- class_split_fit(e)$seats
  coal <- coalition_split_fit(e, cand = cd)$seats$seat
  act <- cs[!cs$seat %in% coal, ]
  m[, "split" := m$seat %in% act$seat]
  m[, "cls" := act$cls[match(m$seat, act$seat)]]
  m[, "election" := e]
  m[, "primary" := paste(e, m$seat) %in% prim_key]
  jj <- jun[jun$election == e]
  m[, "j_share" := jj$j_share[match(paste(m$seat, m$cls), paste(jj$seat, jj$cls))]]
  probs[[e]] <<- list(a = fread(file.path(base_dir, e, "allprobs.csv")), s = fread(file.path(arm_dir, e, "allprobs.csv")))
  m
}))
rows[, "d" := rows$ll_s - rows$ll_a]

cl <- function(x) {
  if (!nrow(x)) return(c(n = 0, el = 0, a = NA, s = NA, d = NA, se = NA))
  dbar <- mean(x$d); G <- uniqueN(x$election)
  sums <- x[, list(r = sum(get("d") - dbar)), by = "election"]$r
  se <- if (G > 1) sqrt(G / (G - 1) * sum(sums^2)) / nrow(x) else NA_real_
  c(n = nrow(x), el = G, a = mean(x$ll_a), s = mean(x$ll_s), d = dbar, se = se)
}
pr <- function(lab, x) {
  r <- cl(x)
  cat(sprintf("  %-40s seats %4d in %2d el | base %.4f  arm %.4f | arm-base %+.4f (SE %.4f)%s\n", lab, r["n"], r["el"],
              r["a"], r["s"], r["d"], r["se"],
              if (is.finite(r["se"]) && r["d"] < -r["se"]) "  arm better by >1 SE"
              else if (is.finite(r["se"]) && r["d"] > r["se"]) "  arm WORSE by >1 SE" else "  within 1 SE"))
  invisible(r)
}
cat("Seat-winner log loss, lower is better; arm-base below zero means the split helps.\n")
pp <- pr("PRIMARY: 84-seat set (scored here)", rows[rows$primary == TRUE])
cat(sprintf("  primary seats not in any scored file: %d\n", length(prim_key) - sum(rows$primary)))
pr("primary, split actually active", rows[rows$primary == TRUE & rows$split == TRUE])
g1 <- pr("GUARD 1: every split-active seat", rows[rows$split == TRUE])
g2 <- pr("GUARD 2: all seats, all elections", rows)
cat("  per election (arm-base, own-seat SE; flag if worse by > 2 SE):\n")
pe <- rows[, list(n = .N, d = mean(get("d")), se = stats::sd(get("d")) / sqrt(.N), n_split = sum(get("split"))), by = "election"]
pe[, "flag" := ifelse(is.finite(pe$se) & pe$d > 2 * pe$se & pe$d > 0, "WORSE >2SE", "")]
setorderv(pe, "d", -1L)
for (i in seq_len(nrow(pe))) cat(sprintf("    %-8s %4d seats (%3d split) %+.4f (SE %.4f) %s\n", pe$election[i], pe$n[i],
                                         pe$n_split[i], pe$d[i], pe$se[i], pe$flag[i]))
cat("UNACCEPTABLE-WIN LINE: split-active seats where the junior's actual share was under 2%\n")
pr("  junior actual < 2%", rows[rows$split == TRUE & is.finite(rows$j_share) & rows$j_share < 2])
pr("  junior actual >= 2%", rows[rows$split == TRUE & is.finite(rows$j_share) & rows$j_share >= 2])
cat(sprintf("  sum of arm-base: junior < 2%% %+.3f, junior >= 2%% %+.3f, all split-active %+.3f\n",
            sum(rows$d[rows$split & is.finite(rows$j_share) & rows$j_share < 2]),
            sum(rows$d[rows$split & is.finite(rows$j_share) & rows$j_share >= 2]), sum(rows$d[rows$split])))
cat("Leave one election out, primary (arm-base mean):\n")
pe2 <- unique(rows$election[rows$primary])
lo <- vapply(pe2, function(e) mean(rows$d[rows$primary & rows$election != e]), 0)
cat(sprintf("  range %+.4f to %+.4f; worst when dropping %s\n", min(lo), max(lo), names(lo)[which.max(lo)]))
cat("Walkthrough seats, IND win probability (base -> arm):\n")
for (k in list(c("sa2018", "Morphett"), c("sa2022", "Waite"), c("fed2025", "Monash"), c("fed2025", "Calwell"))) {
  if (is.null(probs[[k[1]]])) { cat(sprintf("  %s %s: election not scored\n", k[2], k[1])); next }
  g <- function(x) sum(x$prob[x$seat == k[2] & x$party == "IND"])
  cat(sprintf("  %-9s %s  %.3f -> %.3f  (winner %s)\n", k[2], k[1], g(probs[[k[1]]]$a), g(probs[[k[1]]]$s),
              unique(probs[[k[1]]]$a$actual[probs[[k[1]]]$a$seat == k[2]])))
}
cat("Biggest movers, primary set:\n")
top <- rows[rows$primary == TRUE][order(get("d"))]
print(rbind(utils::head(top, 6), utils::tail(top, 4))[, c("election", "seat", "actual", "cls", "ll_a", "ll_s", "d"), with = FALSE])
cat("By split class (split-active seats):\n")
for (k in classes) pr(paste0("  class ", k), rows[rows$split == TRUE & rows$cls %in% k])
cat("By who won (split-active seats):\n")
pr("  the split class won", rows[rows$split == TRUE & rows$actual == rows$cls])
pr("  someone else won", rows[rows$split == TRUE & rows$actual != rows$cls])
