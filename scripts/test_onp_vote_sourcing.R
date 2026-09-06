# Does One Nation's primary gain come disproportionately from the Coalition?
# Against docs/plans/prereg-onp-vote-sourcing.md
#
# Our seat model adds each party's statewide swing and RENORMALISES, which
# takes One Nation's gain in proportion to each party's size. This tests one
# cell of the vote-sourcing matrix that assumption stands in for: does the
# Coalition lose MORE than proportional where One Nation gains more?
#
# The grid, criterion, decision rule and five refusal conditions are in the
# plan and are NOT restated here.
#
# Emits VS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

RISE <- 5          # ONP must rise by at least this to enter the test set
SE_BAR <- 2.45     # t(6) two-sided 95%; 7 clusters, computed in the plan
SIGN_MIN <- 5L     # of 7 cycle-pairs must share the pooled sign
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
  dcast(d, seat ~ party, value.var = "p", fill = 0)
}

# SANITY CHECK BEFORE ANY ESTIMATE. If a fetcher left the Coalition split as
# LIB/NAT rather than folded to LNP, the LNP column would be zeros and every
# number below would be computed against a party that is not there.
chk <- load1(meta$f[1])
cat("VS0  party columns in the first file:", paste(setdiff(names(chk), "seat"), collapse = ", "), "\n")

pairs <- list()
for (rg in unique(meta$region)) {
  yy <- meta[region == rg, year]
  if (length(yy) < 2) next
  for (i in seq_len(length(yy) - 1L)) {
    a <- load1(meta[region == rg & year == yy[i], f])
    b <- load1(meta[region == rg & year == yy[i + 1], f])
    if (is.null(a) || is.null(b)) next
    for (nm in c("ONP", "ALP", "LNP")) {
      if (!nm %in% names(a)) a[[nm]] <- 0
      if (!nm %in% names(b)) b[[nm]] <- 0
    }
    j <- merge(a[, .(seat, ONP_a = ONP, ALP_a = ALP, LNP_a = LNP)],
               b[, .(seat, ONP_b = ONP, ALP_b = ALP, LNP_b = LNP)], by = "seat")
    if (!nrow(j)) next
    j[, `:=`(cycle = paste(rg, yy[i], yy[i + 1]), region = rg)]
    pairs[[length(pairs) + 1L]] <- j
  }
}
P <- rbindlist(pairs, fill = TRUE)
P[, `:=`(d_ONP = ONP_b - ONP_a, d_ALP = ALP_b - ALP_a, d_LNP = LNP_b - LNP_a)]

D <- P[d_ONP >= RISE]
cat(sprintf("\nVS1  test set: %d districts across %d cycle-pairs (ONP rose >= %d pts)\n",
            nrow(D), uniqueN(D$cycle), RISE))
stopifnot(nrow(D) > 0, uniqueN(D$cycle) >= 2)

# ---- the PROPORTIONAL null -------------------------------------------------
# Renormalising after ONP gains dONP scales every other party by
# (100 - ONP_b)/(100 - ONP_a), so the predicted change for party p is
#   -p_a * dONP / (100 - ONP_a)
# This is what our model does today. `excess` is the departure from it.
D[, pred_ALP := -ALP_a * d_ONP / (100 - ONP_a)]
D[, pred_LNP := -LNP_a * d_ONP / (100 - ONP_a)]
D[, excess_ALP := d_ALP - pred_ALP]
D[, excess_LNP := d_LNP - pred_LNP]

# ---- within-cycle deviations, removing the election-wide swing --------------
# Raw changes measure who LOST THE ELECTION, not whose votes ONP took. WA
# 2021->2025 has Labor down 22 points reverting from a freak 2021 landslide.
dev <- function(x) x - mean(x)
D[, `:=`(dONP_dev = dev(d_ONP),
         exALP_dev = dev(excess_ALP),
         exLNP_dev = dev(excess_LNP)), by = cycle]

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

run_one <- function(dat, label) {
  fL <- cluster_se(exLNP_dev ~ dONP_dev, dat, dat$cycle)
  fA <- cluster_se(exALP_dev ~ dONP_dev, dat, dat$cycle)
  bL <- fL$coef[["dONP_dev"]]; sL <- fL$se[["dONP_dev"]]
  bA <- fA$coef[["dONP_dev"]]; sA <- fA$se[["dONP_dev"]]
  cat(sprintf("\n%s  (n=%d, clusters=%d)\n", label, nrow(dat), fL$G))
  cat(sprintf("     excess_LNP: coef %+7.4f  SE %6.4f  ratio %+6.2f\n", bL, sL, bL / sL))
  cat(sprintf("     excess_ALP: coef %+7.4f  SE %6.4f  ratio %+6.2f\n", bA, sA, bA / sA))
  list(bL = bL, rL = bL / sL, bA = bA, rA = bA / sA)
}

cat("\nVS2  CRITERION -- excess Coalition loss per point of ONP deviation\n")
cat("     (negative = Coalition loses MORE than proportional; that is the hypothesis)\n")
main <- run_one(D, "VS2  ALL")

cat("\nVS3  per cycle-pair, for the sign-consistency rule\n")
per <- D[, {
  if (.N >= 4 && var(dONP_dev) > 0) {
    cf <- stats::coef(stats::lm(exLNP_dev ~ dONP_dev))[["dONP_dev"]]
    .(n = .N, coef_LNP = round(cf, 4))
  } else .(n = .N, coef_LNP = NA_real_)
}, by = cycle][order(-n)]
print(per)
same <- sum(sign(per$coef_LNP) == sign(main$bL), na.rm = TRUE)
usable <- sum(!is.na(per$coef_LNP))
cat(sprintf("VS3  %d of %d usable cycle-pairs share the pooled sign (need >= %d of 7)\n",
            same, usable, SIGN_MIN))

cat("\nVS4  R2 -- SA excluded, since SA motivated this and is 46 of the districts\n")
noSA <- D[region != "sa"]
alt <- run_one(noSA, "VS4  NO SA")

cat("\nVS5  the raw (non-deviation) version, to show the confound's size\n")
rawL <- cluster_se(excess_LNP ~ d_ONP, D, D$cycle)
cat(sprintf("     raw excess_LNP coef %+.4f (SE %.4f) vs deviation version %+.4f\n",
            rawL$coef[["d_ONP"]], rawL$se[["d_ONP"]], main$bL))

cat("\nVS6  VERDICT against the pre-registered rule\n")
c1 <- abs(main$rL) >= SE_BAR
c2 <- same >= SIGN_MIN
r1 <- abs(main$bA) < abs(main$bL)      # R1: must not be Labor-symmetric
r2 <- sign(alt$bL) == sign(main$bL) && abs(alt$rL) >= 1
cat(sprintf("     criterion 1, |ratio| >= %.2f SE : %s (%.2f)\n", SE_BAR,
            if (c1) "PASS" else "FAIL", main$rL))
cat(sprintf("     criterion 2, sign in >= %d of 7  : %s (%d)\n", SIGN_MIN,
            if (c2) "PASS" else "FAIL", same))
cat(sprintf("     R1, not Labor-symmetric          : %s (|ALP| %.4f vs |LNP| %.4f)\n",
            if (r1) "PASS" else "REFUSE", abs(main$bA), abs(main$bL)))
cat(sprintf("     R2, survives dropping SA         : %s\n", if (r2) "PASS" else "REFUSE"))
cat(sprintf("\n     OVERALL: %s\n",
            if (c1 && c2 && r1 && r2) "criteria met -- proceed to sizing (criterion 3)"
            else "REFUSED / not established"))

fwrite(D, file.path("output", "onp-vote-sourcing.csv"))
cat("\nWrote output/onp-vote-sourcing.csv\n")
