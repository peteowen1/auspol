# Score AUSPOL_COMPOSITION_SD against the shipped model on the prereg's own terms
# (docs/plans/prereg-composition-spread-2026-10-17.md): seat-winner log loss on the seats the arm widens by
# 1.10 or more (its own pre-election factor), SE clustered on election, the all-seat guard and every refusal
# clause. Lower log loss is better.
#
#   Rscript scripts/score_composition_spread.R <base_dir> <arm_dir> <n_sims>
#
# base_dir / arm_dir hold one folder per election with allprobs.csv and sharedetail.csv (quick_arm's cache
# folders, or a deciding run's). The factor is recomputed from the base's predicted shares and
# output/spread-by-composition.csv, exactly as R/size_sd.R applies it. Codes CQ0-CQ9.
suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 3) stop("usage: score_composition_spread.R <base_dir> <arm_dir> <n_sims>")
base_dir <- a[1]; arm_dir <- a[2]; n_sims <- as.numeric(a[3])
eps <- if (n_sims >= 20000) 1e-6 else 0.5 / n_sims
els <- intersect(list.dirs(base_dir, full.names = FALSE, recursive = FALSE),
                 list.dirs(arm_dir, full.names = FALSE, recursive = FALSE))
els <- els[file.exists(file.path(base_dir, els, "allprobs.csv")) & file.exists(file.path(arm_dir, els, "allprobs.csv")) &
           file.exists(file.path(base_dir, els, "sharedetail.csv"))]
tab <- fread(out_path("spread-by-composition.csv"))
cat(sprintf("CQ0 %d elections in both folders; floor eps %.1e; table %d targets\n", length(els), eps, uniqueN(tab$target)))

ll <- function(f) {
  x <- fread(f)
  w <- x[x$is_actual == TRUE, list(p = sum(get("prob"))), by = "seat"]
  w <- merge(data.table(seat = unique(x$seat)), w, by = "seat", all.x = TRUE)
  w[is.na(get("p")), "p" := 0]
  fav <- x[, list(fav_p = max(get("prob")), fav_won = get("is_actual")[which.max(get("prob"))]), by = "seat"]
  merge(w, fav, by = "seat")
}
rows <- rbindlist(lapply(els, function(e) {
  b <- ll(file.path(base_dir, e, "allprobs.csv")); s <- ll(file.path(arm_dir, e, "allprobs.csv"))
  m <- merge(b, s[, c("seat", "p"), with = FALSE], by = "seat", suffixes = c("_a", "_c"))
  sd <- fread(file.path(base_dir, e, "sharedetail.csv"))
  W <- dcast(sd, seat ~ party, value.var = "pred_share", fun.aggregate = sum, fill = 0)
  sh <- as.matrix(W[, -1, with = FALSE]); rownames(sh) <- W$seat
  e_label <- e
  co <- tab[tab$target %in% e_label]
  fac <- if (nrow(co)) composition_sd_factor(sh, co) else rep(1, nrow(sh))
  ind <- if ("IND" %in% colnames(sh)) sh[, "IND"] else rep(0, nrow(sh))
  m <- merge(m, data.table(seat = rownames(sh), factor = fac, ind_pred = ind), by = "seat", all.x = TRUE)
  m[, "election" := e]
  m
}))
rows[, "ll_a" := -log(pmax(rows$p_a, eps))][, "ll_c" := -log(pmax(rows$p_c, eps))][, "d" := rows$ll_c - rows$ll_a]
rows[, "at_floor" := rows$p_a < eps * 1.0001]

cl <- function(x) {
  if (!nrow(x)) return(c(n = 0, el = 0, a = NA, s = NA, d = NA, se = NA))
  dbar <- mean(x$d); G <- uniqueN(x$election)
  sums <- x[, list(r = sum(get("d") - dbar)), by = "election"]$r
  se <- if (G > 1) sqrt(G / (G - 1) * sum(sums^2)) / nrow(x) else NA_real_
  c(n = nrow(x), el = G, a = mean(x$ll_a), s = mean(x$ll_c), d = dbar, se = se)
}
pr <- function(lab, x) {
  r <- cl(x)
  cat(sprintf("  %-40s seats %4d in %2d el | A %.4f  C %.4f | C-A %+.4f (SE %.4f)%s\n", lab, r["n"], r["el"], r["a"], r["s"],
              r["d"], r["se"], if (is.finite(r["se"]) && r["d"] < -r["se"]) "  C better by >1 SE"
              else if (is.finite(r["se"]) && r["d"] > r["se"]) "  C WORSE by >1 SE" else "  within 1 SE"))
  invisible(r)
}
tg <- rows[rows$factor >= 1.10]
cat(sprintf("CQ1 seats widened by 1.10+: %d of %d (factor range %.2f-%.2f)\n", nrow(tg), nrow(rows),
            if (nrow(tg)) min(tg$factor) else NA, if (nrow(tg)) max(tg$factor) else NA))
moved_off <- rows[rows$factor <= 1 & rows$d != 0]
cat(sprintf("CQ2 unwidened seats whose log loss moved: %d (expected small: only the shared statewide draws couple seats)\n", nrow(moved_off)))
cat("CQ3 seat-winner log loss (lower is better), C minus A, SE clustered on election:\n")
r1 <- pr("PRIMARY: widened by 1.10+", tg)
rg <- pr("GUARD: every seat", rows)
pr("fixed set: IND predicted 15+", rows[rows$ind_pred >= 15])
pr("AEF-7 elections, all seats", rows[rows$election %in% c("fed2022", "fed2025", "nsw2023", "qld2024", "sa2026", "vic2022", "wa2025")])
for (j in sort(unique(sub("[0-9]+$", "", tg$election)))) pr(paste0("  primary, ", j), tg[sub("[0-9]+$", "", tg$election) == j])
cat("CQ4 the Victorian split seats:\n")
print(rows[rows$election == "vic2022" & rows$seat %in% c("Morwell", "Shepparton", "Mildura"),
           list(seat, factor = round(factor, 2), p_winner_A = round(p_a, 4), p_winner_C = round(p_c, 4), d = round(d, 3))])
cat("CQ5 per election, primary seats: summed C-A (negative = C better) and share of the net gain\n")
pe <- tg[, list(seats = .N, sum_d = sum(get("d"))), by = "election"][order(get("sum_d"))]
net <- sum(tg$d)
pe[, "share_of_gain" := if (net < 0) pe$sum_d / net else NA_real_]
print(pe[, list(election, seats, sum_d = round(sum_d, 3), share_of_gain = round(share_of_gain, 2))], nrows = 60)
top <- if (net < 0) max(pe$share_of_gain) else NA
cat(sprintf("CQ6 REFUSAL one election > half the gain: largest share %.2f -> %s\n", top,
            if (is.na(top)) "no net gain" else if (top > 0.5) "REFUSED" else "passes"))
fl <- sum(tg$d[tg$at_floor])
cat(sprintf("CQ7 FLOOR: gain from seats A put at the floor %.3f of net %.3f (%s); primary without them: ", -fl, -net,
            if (net < 0 && fl / net > 0.5) "MORE THAN HALF -> to Pete as a split result" else "under half"))
nf <- cl(tg[!tg$at_floor]); cat(sprintf("C-A %+.4f (SE %.4f)\n", nf["d"], nf["se"]))
fv <- rows[rows$fav_p >= 0.90 & rows$fav_won == TRUE]
fr <- cl(fv)
cat(sprintf("CQ8 FAVOURITES (A 0.90+, won; %d seats): C-A %+.4f (SE %.4f), summed %+.3f -> %s\n", nrow(fv), fr["d"], fr["se"],
            sum(fv$d), if (is.finite(fr["se"]) && fr["d"] > fr["se"]) "WORSE by >1 SE: report beside the primary" else "within 1 SE"))
cat(sprintf("CQ9 VERDICT: primary %s; guard %s\n",
            if (is.finite(r1["se"]) && r1["d"] < -r1["se"]) "C better than A by more than 1 SE" else "C NOT better by more than 1 SE",
            if (is.finite(rg["se"]) && rg["d"] > rg["se"]) "FAILS (C worse by >1 SE)" else "passes"))
