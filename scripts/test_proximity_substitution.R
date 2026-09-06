# Are ideologically adjacent parties substitutes?
# Against docs/plans/prereg-proximity-substitution.md
#
# Our swing model knows only about SIZE. This tests whether the offsetting
# movement when a party's primary changes concentrates on ideologically
# ADJACENT parties -- using preference flows as a measured position scale.
#
# Criterion, bar, abort gate and four refusals are in the plan and are NOT
# restated here. This is the GRADIENT test; the levels version is computed as
# description with no criterion, exactly as the plan specifies.
#
# Emits PX* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

SE_BAR <- 2.20        # t(11) two-sided 95%, computed in the plan
SIGN_MIN <- 8L        # of 12 cycle-pairs
MIN_CYCLES <- 8L      # abort gate
MIN_PAIRS_PER_CYCLE <- 3L
PREF <- election_data_path()

# ---- position scale from measured preference flows -------------------------
fl <- as.data.table(load_preference_flows())
pos <- fl[, .(pos = mean(flow_alp, na.rm = TRUE)), by = party]
pos <- rbind(pos, data.table(party = c("ALP", "LNP"), pos = c(100, 0)))
pos <- pos[is.finite(pos)][!duplicated(party)]
cat("PX0  position scale (share of preferences to Labor; ALP=100, LNP=0)\n")
print(pos[order(pos)])

fs <- list.files(PREF, pattern = "firstprefs\\.csv$", full.names = TRUE)
meta <- data.table(f = fs, base = basename(fs))
meta[, region := tstrsplit(base, "-", keep = 3)[[1]]]
meta[, year := as.integer(tstrsplit(base, "-", keep = 2)[[1]])]
meta <- meta[!is.na(year)][order(region, year)]

load1 <- function(f) {
  d <- fread(f, showProgress = FALSE)
  if (!all(c("seat", "party", "votes") %in% names(d))) return(NULL)
  d[, tot := sum(votes), by = seat]
  d[, p := 100 * votes / tot]
  dcast(d, seat ~ party, value.var = "p", fill = 0)
}

rows <- list()
for (rg in unique(meta$region)) {
  yy <- meta[region == rg, year]
  if (length(yy) < 2) next
  for (i in seq_len(length(yy) - 1L)) {
    a <- load1(meta[region == rg & year == yy[i], f])
    b <- load1(meta[region == rg & year == yy[i + 1], f])
    if (is.null(a) || is.null(b)) next
    common <- intersect(setdiff(names(a), "seat"), setdiff(names(b), "seat"))
    common <- intersect(common, pos$party)
    j <- merge(a[, c("seat", common), with = FALSE],
               b[, c("seat", common), with = FALSE], by = "seat",
               suffixes = c("_a", "_b"))
    if (nrow(j) < 10L) next
    # a party must actually be present at both ends to have a "change"
    keep <- common[vapply(common, function(p)
      mean(j[[paste0(p, "_a")]]) >= 2 && mean(j[[paste0(p, "_b")]]) >= 2, TRUE)]
    if (length(keep) < 3L) next
    ch <- as.data.table(lapply(keep, function(p) j[[paste0(p, "_b")]] - j[[paste0(p, "_a")]]))
    setnames(ch, keep)
    shr <- vapply(keep, function(p) mean(j[[paste0(p, "_a")]]), 1)
    for (x in seq_along(keep)) for (y in seq_len(x - 1L)) {
      px <- keep[x]; py <- keep[y]
      if (stats::var(ch[[px]]) == 0 || stats::var(ch[[py]]) == 0) next
      rows[[length(rows) + 1L]] <- data.table(
        cycle = paste(rg, yy[i], yy[i + 1]), region = rg,
        p1 = px, p2 = py,
        r = stats::cor(ch[[px]], ch[[py]]),
        prox = -abs(pos$pos[match(px, pos$party)] - pos$pos[match(py, pos$party)]),
        size = shr[[px]] * shr[[py]] / 100,
        n_districts = nrow(j))
    }
  }
}
D <- rbindlist(rows)
stopifnot(nrow(D) > 0)

# ---- PX1: the abort gate, before any estimate ------------------------------
per_cycle <- D[, .(pairs = .N), by = cycle]
ok_cycles <- per_cycle[pairs >= MIN_PAIRS_PER_CYCLE, .N]
cat(sprintf("\nPX1  %d party-pair observations across %d cycle-pairs\n",
            nrow(D), uniqueN(D$cycle)))
cat(sprintf("PX1  cycle-pairs with >= %d usable pairs: %d (need >= %d)\n",
            MIN_PAIRS_PER_CYCLE, ok_cycles, MIN_CYCLES))
if (ok_cycles < MIN_CYCLES) {
  cat("\nPX1  ABORT: corpus cannot support the test.\n")
  quit(save = "no", status = 0)
}
cat("PX1  gate PASSED\n")

cluster_se <- function(form, data, cluster) {
  m <- stats::lm(form, data = data)
  X <- stats::model.matrix(m); u <- stats::residuals(m)
  bread <- solve(crossprod(X))
  g <- split(seq_len(nrow(X)), cluster)
  meat <- Reduce(`+`, lapply(g, function(i) tcrossprod(crossprod(X[i, , drop = FALSE], u[i]))))
  G <- length(g); N <- nrow(X); K <- ncol(X)
  V <- bread %*% meat %*% bread * (G / (G - 1)) * ((N - 1) / (N - K))
  list(coef = stats::coef(m), se = sqrt(diag(V)), G = G)
}
show <- function(f, term, lbl) {
  b <- f$coef[[term]]; s <- f$se[[term]]
  cat(sprintf("     %-34s coef %+8.5f  SE %7.5f  ratio %+6.2f  (G=%d)\n",
              lbl, b, s, b / s, f$G))
  b / s
}

cat("\nPX2  CRITERION -- r_pq on proximity (closer pairs should be MORE negative,\n")
cat("     so the predicted coefficient is POSITIVE: less negative as distance grows)\n")
f1 <- cluster_se(r ~ prox, D, D$cycle)
rat1 <- show(f1, "prox", "proximity alone")

cat("\nPX3  R1 -- size control. ALP and LNP are the LARGEST pair and the MOST\n")
cat("     DISTANT pair, which can manufacture the predicted sign from size alone.\n")
f2 <- cluster_se(r ~ prox + size, D, D$cycle)
rat2 <- show(f2, "prox", "proximity, controlling size")
show(f2, "size", "size itself")

cat("\nPX4  per cycle-pair sign, for the consistency rule\n")
per <- D[, {
  if (.N >= 3 && stats::var(prox) > 0)
    .(pairs = .N, coef = round(stats::coef(stats::lm(r ~ prox))[["prox"]], 5))
  else .(pairs = .N, coef = NA_real_)
}, by = cycle][order(-pairs)]
print(per)
main_sign <- sign(f2$coef[["prox"]])
same <- sum(sign(per$coef) == main_sign, na.rm = TRUE)
usable <- sum(!is.na(per$coef))
cat(sprintf("PX4  %d of %d usable cycle-pairs share the size-controlled sign (need >= %d of 12)\n",
            same, usable, SIGN_MIN))

cat("\nPX5  criterion 3 -- drop One Nation entirely (it motivated this)\n")
noONP <- D[p1 != "ONP" & p2 != "ONP"]
f3 <- cluster_se(r ~ prox + size, noONP, noONP$cycle)
rat3 <- show(f3, "prox", "proximity, no ONP pairs")

cat("\nPX6  R3 -- drop GRN/ALP, the most numerous and best-measured pair\n")
noGA <- D[!((p1 == "GRN" & p2 == "ALP") | (p1 == "ALP" & p2 == "GRN"))]
f4 <- cluster_se(r ~ prox + size, noGA, noGA$cycle)
rat4 <- show(f4, "prox", "proximity, no GRN-ALP pair")

cat("\nPX7  observed correlations for the pairs Pete named\n")
print(D[(p1 == "ONP" & p2 == "LNP") | (p1 == "LNP" & p2 == "ONP") |
        (p1 == "GRN" & p2 == "ALP") | (p1 == "ALP" & p2 == "GRN") |
        (p1 == "ONP" & p2 == "ALP") | (p1 == "ALP" & p2 == "ONP"),
        .(cycle, p1, p2, r = round(r, 3), prox = round(prox, 1))][order(p1, p2, cycle)])

cat("\nPX8  DESCRIPTION ONLY, no criterion -- the levels version (n=12, underpowered)\n")
cat("     mean r by proximity band:\n")
D[, band := cut(-prox, breaks = c(-1, 20, 40, 60, 101),
                labels = c("very close", "close", "far", "very far"))]
print(D[, .(pairs = .N, mean_r = round(mean(r), 3)), by = band][order(band)])

c1 <- rat2 >= SE_BAR
c2 <- same >= SIGN_MIN
c3 <- rat3 >= 1
cat("\nPX9  VERDICT against the pre-registered rule\n")
cat(sprintf("     criterion 1, size-controlled >= %.2f SE : %s (%.2f)\n", SE_BAR,
            if (c1) "PASS" else "FAIL", rat2))
cat(sprintf("     criterion 2, sign in >= %d of 12         : %s (%d)\n", SIGN_MIN,
            if (c2) "PASS" else "FAIL", same))
cat(sprintf("     criterion 3, survives dropping ONP      : %s (%.2f)\n",
            if (c3) "PASS" else "FAIL", rat3))
cat(sprintf("\n     OVERALL: %s\n",
            if (c1 && c2 && c3) "proximity substitution SUPPORTED (adoption NOT authorised -- see R4)"
            else "REFUSED / not established"))

fwrite(D, file.path("output", "proximity-substitution.csv"))
cat("\nWrote output/proximity-substitution.csv\n")
