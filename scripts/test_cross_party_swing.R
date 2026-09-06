# Does a major's seat swing depend on the OTHER major's base?
# Against docs/plans/prereg-cross-party-swing.md
#
# Aimed at the RUNNER-UP. In Hammond and Ngadjuri our One Nation projection is
# right and the seats are lost because we put Labor third when reality put the
# Coalition third, which inverts the exclusion order and the preference flows.
#
# Criterion, bar, decision rule and five refusals are in the plan.
#
# Emits CP* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

SE_BAR <- 2.20
SIGN_MIN <- 8L
PREF <- election_data_path()

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
  d[, .(seat, party, p, votes)]
}

rows <- list()
for (rg in unique(meta$region)) {
  yy <- meta[region == rg, year]
  if (length(yy) < 2) next
  for (i in seq_len(length(yy) - 1L)) {
    a <- load1(meta[region == rg & year == yy[i], f])
    b <- load1(meta[region == rg & year == yy[i + 1], f])
    if (is.null(a) || is.null(b)) next
    wa <- dcast(a, seat ~ party, value.var = "p", fill = 0)
    wb <- dcast(b, seat ~ party, value.var = "p", fill = 0)
    if (!all(c("ALP", "LNP") %in% names(wa)) || !all(c("ALP", "LNP") %in% names(wb))) next
    sw <- function(d, p) 100 * sum(d[party == p, votes]) / sum(d[, sum(votes), by = seat]$V1)
    swa <- c(ALP = sw(a, "ALP"), LNP = sw(a, "LNP"))
    swb <- c(ALP = sw(b, "ALP"), LNP = sw(b, "LNP"))
    j <- merge(wa[, .(seat, ALP_a = ALP, LNP_a = LNP)],
               wb[, .(seat, ALP_b = ALP, LNP_b = LNP)], by = "seat")
    if (nrow(j) < 10) next
    for (p in c("ALP", "LNP")) {
      o <- setdiff(c("ALP", "LNP"), p)
      rows[[length(rows) + 1L]] <- data.table(
        cycle = paste(rg, yy[i], yy[i + 1]), region = rg, seat = j$seat, party = p,
        # y: how much this seat's swing beat the statewide swing
        y = (j[[paste0(p, "_b")]] - j[[paste0(p, "_a")]]) - (swb[[p]] - swa[[p]]),
        # x: how much the OTHER major over-indexes here
        x = j[[paste0(o, "_a")]] - swa[[o]],
        own_base = j[[paste0(p, "_a")]] - swa[[p]])
    }
  }
}
D <- rbindlist(rows)
D <- D[is.finite(y) & is.finite(x) & is.finite(own_base)]
cat(sprintf("CP1  %d (district, major) observations, %d cycle-pairs, %d regions\n",
            nrow(D), uniqueN(D$cycle), uniqueN(D$region)))
stopifnot(nrow(D) > 100, uniqueN(D$cycle) >= 8)

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
  cat(sprintf("     %-40s coef %+8.5f  SE %7.5f  ratio %+6.2f\n", lbl, b, s, b / s))
  b / s
}

cat("\nCP2  CRITERION -- swing-vs-statewide on the OTHER major's over-index\n")
f1 <- cluster_se(y ~ x, D, D$cycle)
r1 <- show(f1, "x", "other major's base")

cat("\nCP3  R2 -- control for the party's OWN base. The two majors' bases are\n")
cat("     near mirror images within a seat, so x partly proxies for own_base.\n")
f2 <- cluster_se(y ~ x + own_base, D, D$cycle)
r2 <- show(f2, "x", "other major's base, controlled")
show(f2, "own_base", "own base")

cat("\nCP4  R1 -- drop South Australia\n")
noSA <- D[region != "sa"]
f3 <- cluster_se(y ~ x + own_base, noSA, noSA$cycle)
r3 <- show(f3, "x", "other major's base, no SA")

cat("\nCP5  per cycle-pair sign (controlled spec)\n")
per <- D[, {
  if (.N >= 20 && stats::var(x) > 0)
    .(n = .N, coef = round(stats::coef(stats::lm(y ~ x + own_base))[["x"]], 5))
  else .(n = .N, coef = NA_real_)
}, by = cycle][order(-n)]
print(per)
same <- sum(sign(per$coef) == sign(f2$coef[["x"]]), na.rm = TRUE)
usable <- sum(!is.na(per$coef))
cat(sprintf("CP5  %d of %d usable cycle-pairs share the sign (need >= %d of 12)\n",
            same, usable, SIGN_MIN))

cat("\nCP6  criterion 3 -- does applying it degrade pooled MAE?\n")
b <- f2$coef[["x"]]
D[, pred_uniform := 0]                 # y is already the deviation from uniform
D[, pred_cross := b * x]
cat(sprintf("     MAE of the deviation, uniform (predict 0) : %.4f\n", mean(abs(D$y))))
cat(sprintf("     MAE of the deviation, cross-party term    : %.4f\n",
            mean(abs(D$y - D$pred_cross))))
better <- mean(abs(D$y - D$pred_cross)) <= mean(abs(D$y))
cat(sprintf("     criterion 3 (must not degrade): %s\n", if (better) "PASS" else "FAIL"))

cat("\nCP7  R4 DIAGNOSTIC ONLY -- what it would do to the two SA seats\n")
sa <- D[region == "sa" & seat %in% c("Hammond", "Ngadjuri", "Frome")]
if (nrow(sa)) {
  sa[, adj := b * x]
  print(sa[, .(seat, party, other_over_index = round(x,1),
               actual_dev = round(y,1), model_adj = round(adj,1))][order(seat, party)])
  cat("     (positive adj for ALP = model would lift Labor in these seats,\n")
  cat("      which is the direction that fixes the exclusion order)\n")
}

c1 <- r2 >= SE_BAR
c2 <- same >= SIGN_MIN
cat("\nCP8  VERDICT\n")
cat(sprintf("     criterion 1, controlled >= %.2f SE : %s (%.2f)\n", SE_BAR,
            if (c1) "PASS" else "FAIL", r2))
cat(sprintf("     criterion 2, sign in >= %d of 12    : %s (%d)\n", SIGN_MIN,
            if (c2) "PASS" else "FAIL", same))
cat(sprintf("     criterion 3, no MAE degradation    : %s\n", if (better) "PASS" else "FAIL"))
cat(sprintf("     R1, survives dropping SA           : %s (%.2f)\n",
            if (r3 >= 1) "PASS" else "REFUSE", r3))
cat(sprintf("\n     OVERALL: %s\n",
            if (c1 && c2 && better && r3 >= 1) "SUPPORTED -- proceed to a seat-model arm"
            else "REFUSED / not established"))

fwrite(D, file.path("output", "cross-party-swing.csv"))
cat("\nWrote output/cross-party-swing.csv\n")
