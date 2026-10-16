# Score AUSPOL_COALITION_SPLIT against the shipped model on the prereg's own terms
# (docs/plans/prereg-lib-nat-two-candidates-2026-10-16.md): seat-winner log loss on
# the split seats, SE clustered on election, and every refusal clause.
#
#   Rscript scripts/score_coalition_split.R <base_dir> <arm_dir> <n_sims>
#
# base_dir / arm_dir hold one folder per election with allprobs.csv (quick_arm's
# cache folders, or a deciding run's). Lower log loss is better.
suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 3) stop("usage: score_coalition_split.R <base_dir> <arm_dir> <n_sims>")
base_dir <- a[1]; arm_dir <- a[2]; n_sims <- as.numeric(a[3])
eps <- if (n_sims >= 20000) 1e-6 else 0.5 / n_sims
els <- intersect(list.dirs(base_dir, full.names = FALSE, recursive = FALSE),
                 list.dirs(arm_dir, full.names = FALSE, recursive = FALSE))
els <- els[file.exists(file.path(base_dir, els, "allprobs.csv")) & file.exists(file.path(arm_dir, els, "allprobs.csv"))]
cat(sprintf("LX0 %d elections in both folders; floor eps %.1e\n", length(els), eps))
cd <- fread(out_path("candidacies.csv"))

ll <- function(f) {
  x <- fread(f)
  w <- x[x$is_actual == TRUE, list(p = sum(get("prob"))), by = "seat"]
  allseats <- unique(x$seat)
  w <- merge(data.table(seat = allseats), w, by = "seat", all.x = TRUE)
  w[is.na(get("p")), "p" := 0]
  w[, "ll" := -log(pmax(get("p"), eps))]
  act <- unique(x[x$is_actual == TRUE, c("seat", "actual"), with = FALSE])
  merge(w, act, by = "seat", all.x = TRUE)
}
rows <- rbindlist(lapply(els, function(e) {
  b <- ll(file.path(base_dir, e, "allprobs.csv")); s <- ll(file.path(arm_dir, e, "allprobs.csv"))
  m <- merge(b[, c("seat", "ll", "actual"), with = FALSE], s[, c("seat", "ll"), with = FALSE],
             by = "seat", suffixes = c("_a", "_s"))
  sp <- coalition_split_fit(e, cand = cd)$seats$seat
  m[, "split" := m$seat %in% sp]
  m[, "election" := e]
  m
}))
rows[, "d" := rows$ll_s - rows$ll_a]
rows[, "jur" := sub("[0-9]+$", "", rows$election)]
rows[, "coal_won" := rows$actual == "LNP"]

# Clustered SE of a mean difference, clusters = elections.
cl <- function(x) {
  if (!nrow(x)) return(c(n = 0, el = 0, a = NA, s = NA, d = NA, se = NA))
  dbar <- mean(x$d); G <- data.table::uniqueN(x$election)
  sums <- x[, list(r = sum(get("d") - dbar)), by = "election"]$r
  se <- if (G > 1) sqrt(G / (G - 1) * sum(sums^2)) / nrow(x) else NA_real_
  c(n = nrow(x), el = G, a = mean(x$ll_a), s = mean(x$ll_s), d = dbar, se = se)
}
pr <- function(lab, x) {
  r <- cl(x)
  cat(sprintf("  %-34s seats %4d in %2d el | A %.4f  S %.4f | S-A %+.4f (SE %.4f)%s\n", lab, r["n"], r["el"],
              r["a"], r["s"], r["d"], r["se"],
              if (is.finite(r["se"]) && r["d"] < -r["se"]) "  S better by >1 SE"
              else if (is.finite(r["se"]) && r["d"] > r["se"]) "  S WORSE by >1 SE" else "  within 1 SE"))
  invisible(r)
}
sp <- rows[rows$split == TRUE]
cat(sprintf("LX1 split seats scored: %d (Coalition won %d, lost %d)\n", nrow(sp), sum(sp$coal_won, na.rm = TRUE),
            sum(!sp$coal_won, na.rm = TRUE)))
moved_non <- rows[rows$split == FALSE & rows$d != 0]
cat(sprintf("LX2 non-split seats whose log loss moved: %d (must be 0)\n", nrow(moved_non)))
cat("LX3 seat-winner log loss (lower is better), S minus A, SE clustered on election:\n")
r1 <- pr("PRIMARY: split seats", sp)
pr("GUARD: every seat in these elections", rows)
pr("non-WA split seats", sp[sp$jur != "wa"])
pr("Coalition-WON split seats", sp[sp$coal_won %in% TRUE])
pr("Coalition-LOST split seats", sp[sp$coal_won %in% FALSE])
for (j in sort(unique(sp$jur))) pr(paste0("  ", j), sp[sp$jur == j])
aef7 <- c("fed2022", "fed2025", "nsw2023", "qld2024", "sa2026", "vic2022", "wa2025")
pr("AEF-7 elections, all seats", rows[rows$election %in% aef7])

cat("LX4 per election, split seats: summed S-A (negative = S better), and share of the net gain\n")
pe <- sp[, list(seats = .N, sum_d = sum(get("d"))), by = "election"][order(get("sum_d"))]
net <- sum(sp$d)
pe[, "share_of_gain" := if (net < 0) pe$sum_d / net else NA_real_]
print(pe[, list(election, seats, sum_d = round(sum_d, 3), share_of_gain = round(share_of_gain, 2))], nrows = 50)
top <- if (net < 0) max(pe$share_of_gain) else NA
cat(sprintf("LX5 REFUSAL one election > half the gain: largest share %.2f -> %s\n", top,
            if (is.na(top)) "no net gain" else if (top > 0.5) "REFUSED" else "passes"))
nw <- cl(sp[sp$jur != "wa"])
cat(sprintf("LX6 REFUSAL non-WA split seats worse by > 1 SE: %+.4f (SE %.4f) -> %s\n", nw["d"], nw["se"],
            if (is.finite(nw["se"]) && nw["d"] > nw["se"]) "REFUSED" else "passes"))
won <- sp[sp$coal_won %in% TRUE]; lost <- sp[sp$coal_won %in% FALSE]
cat(sprintf("LX7 won seats got worse by %.3f seat-units, lost seats improved by %.3f (reported)\n",
            sum(won$d), -sum(lost$d)))
cat(sprintf("LX8 VERDICT on the primary: %s\n",
            if (is.finite(r1["se"]) && r1["d"] < -r1["se"]) "S better than A by more than 1 SE" else "S NOT better by more than 1 SE"))
