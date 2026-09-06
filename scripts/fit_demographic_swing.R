# Do seat demographics predict the SWING, leave-one-election-out?
# Against docs/plans/prereg-demographic-seat-model.md
#
# This is the step that decides whether the harness work is worth doing. The
# feasibility review found strong association with the LEVEL of the vote -- but
# our model already knows the level from the baseline result, so only the SWING
# is new information.
#
# Fitted LEAVE-ONE-ELECTION-OUT: coefficients for a pair come from the other
# pairs only.
#
# Emits DS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
P <- election_data_path()

PAIRS <- list(
  list(id = "vic2022", state = "Victoria",
       a = "vec-2018-vic-firstprefs.csv", b = "vec-2022-vic-firstprefs.csv"),
  list(id = "nsw2023", state = "New South Wales",
       a = "nswec-2019-nsw-firstprefs.csv", b = "nswec-2023-nsw-firstprefs.csv"),
  list(id = "sa2026", state = "South Australia",
       a = "ecsa-2022-sa-firstprefs.csv", b = "ecsa-2026-sa-firstprefs.csv"))

DEMOG <- c("Median_age_persons", "Median_tot_prsnl_inc_weekly",
           "Median_rent_weekly", "Average_household_size",
           "Average_num_psns_per_bedroom", "Median_mortgage_repay_monthly")
PARTIES <- c("ALP", "LNP", "GRN", "OTH_RIGHT")

cen <- fread("external/reference/census/census-sed-2021.csv", showProgress = FALSE)

shares_of <- function(f) {
  d <- fread(file.path(P, f), showProgress = FALSE)
  d[, tot := sum(votes), by = seat]
  d[, p := 100 * votes / tot]
  dcast(d, seat ~ party, value.var = "p", fill = 0)
}

rows <- list()
for (K in PAIRS) {
  fa <- file.path(P, K$a); fb <- file.path(P, K$b)
  if (!file.exists(fa) || !file.exists(fb)) {
    cat(sprintf("DS0  SKIP %s -- missing %s\n", K$id,
                paste(basename(c(fa, fb))[!file.exists(c(fa, fb))], collapse = ", ")))
    next
  }
  wa <- shares_of(K$a); wb <- shares_of(K$b)
  for (p in PARTIES) {
    if (!p %in% names(wa)) wa[[p]] <- 0
    if (!p %in% names(wb)) wb[[p]] <- 0
  }
  j <- merge(wa[, c("seat", PARTIES), with = FALSE],
             wb[, c("seat", PARTIES), with = FALSE],
             by = "seat", suffixes = c("_a", "_b"))
  cs <- cen[ste == K$state, c("seat", DEMOG), with = FALSE]
  j <- merge(j, cs, by = "seat")
  if (!nrow(j)) { cat(sprintf("DS0  SKIP %s -- no census join\n", K$id)); next }
  for (p in PARTIES) {
    a <- j[[paste0(p, "_a")]]; b <- j[[paste0(p, "_b")]]
    # the swing DEVIATION: how much this seat moved beyond the statewide move
    dev <- (b - a) - (mean(b) - mean(a))
    rows[[length(rows) + 1L]] <- data.table(
      pair = K$id, seat = j$seat, party = p, dev = dev,
      j[, DEMOG, with = FALSE])
  }
  cat(sprintf("DS0  %s: %d seats joined to census\n", K$id, nrow(j)))
}
D <- rbindlist(rows)
stopifnot(nrow(D) > 0)
cat(sprintf("\nDS1  %d (seat, party) rows across %d pairs\n",
            nrow(D), uniqueN(D$pair)))

# standardise demographics WITHIN pair, so a coefficient means the same thing
# across elections with different Census vintages or state compositions
for (v in DEMOG) {
  D[, (v) := {
    x <- suppressWarnings(as.numeric(get(v)))
    if (all(!is.finite(x)) || stats::sd(x, na.rm = TRUE) == 0) 0
    else (x - mean(x, na.rm = TRUE)) / stats::sd(x, na.rm = TRUE)
  }, by = .(pair, party)]
}

fml <- stats::as.formula(paste("dev ~", paste(DEMOG, collapse = " + ")))

cat("\nDS2  IN-SAMPLE fit per party (upper bound; not the criterion)\n")
for (p in PARTIES) {
  d <- D[party == p]
  if (nrow(d) < 30) next
  m <- stats::lm(fml, data = d)
  cat(sprintf("     %-9s n %3d  adj R2 %+.4f  residual sd %.2f (dev sd %.2f)\n",
              p, nrow(d), summary(m)$adj.r.squared,
              stats::sd(stats::residuals(m)), stats::sd(d$dev)))
}

cat("\nDS3  LEAVE-ONE-ELECTION-OUT -- the honest number\n")
cat("     Does predicting a pair's swing deviation from the OTHER pairs beat\n")
cat("     predicting zero (which is what uniform swing does)?\n\n")
res <- list()
for (p in PARTIES) {
  for (k in unique(D$pair)) {
    tr <- D[party == p & pair != k]; te <- D[party == p & pair == k]
    if (nrow(tr) < 30 || nrow(te) < 10) next
    m <- stats::lm(fml, data = tr)
    pr <- stats::predict(m, newdata = te)
    res[[length(res) + 1L]] <- data.table(
      party = p, pair = k, n = nrow(te),
      mae_uniform = mean(abs(te$dev)),        # predict 0
      mae_demog = mean(abs(te$dev - pr)))
  }
}
R <- rbindlist(res)
R[, improvement := mae_uniform - mae_demog]
print(R[, .(party, pair, n, mae_uniform = round(mae_uniform, 3),
            mae_demog = round(mae_demog, 3), improvement = round(improvement, 3))])

cat(sprintf("\nDS4  pooled: uniform %.4f | demographic %.4f | improvement %+.4f\n",
            mean(R$mae_uniform), mean(R$mae_demog),
            mean(R$mae_uniform) - mean(R$mae_demog)))
cat(sprintf("DS4  demographic model beats predicting zero in %d of %d (party, pair) cells\n",
            sum(R$improvement > 0), nrow(R)))

# ---- DS4b: the pre-registered subgroup, which IS the argument ---------------
# The plan names "baseline-broken" seats -- the winning party's first-preference
# share moving more than 15 points -- as the entire case for demographics. A
# demographic term that loses overall could still win there, and that subgroup
# was defined before any result was seen.
BROKEN <- 15
D[, broken := abs(dev) > BROKEN]
sub <- list()
for (p in PARTIES) {
  for (k in unique(D$pair)) {
    tr <- D[party == p & pair != k]; te <- D[party == p & pair == k & broken == TRUE]
    if (nrow(tr) < 30 || nrow(te) < 3) next
    m <- stats::lm(fml, data = tr)
    pr <- stats::predict(m, newdata = te)
    sub[[length(sub) + 1L]] <- data.table(
      party = p, pair = k, n = nrow(te),
      mae_uniform = mean(abs(te$dev)), mae_demog = mean(abs(te$dev - pr)))
  }
}
cat(sprintf("\nDS4b PRE-REGISTERED SUBGROUP: seats whose swing deviation exceeds %d points\n",
            BROKEN))
if (!length(sub)) {
  cat("     No (party, pair) cell has 3+ such seats -- the subgroup cannot be scored.\n")
  sub_improve <- NA_real_
} else {
  S <- rbindlist(sub)
  S[, improvement := mae_uniform - mae_demog]
  print(S[, .(party, pair, n, mae_uniform = round(mae_uniform, 2),
              mae_demog = round(mae_demog, 2), improvement = round(improvement, 2))])
  sub_improve <- mean(S$improvement)
  cat(sprintf("     subgroup pooled improvement %+.3f, better in %d of %d cells\n",
              sub_improve, sum(S$improvement > 0), nrow(S)))
}

cat("\nDS5  VERDICT ON WHETHER TO PROCEED\n")
if (mean(R$improvement) <= 0) {
  cat("     Demographics do NOT predict the swing deviation out of sample.\n")
  cat("     Wiring a demographic term into the seat harnesses cannot help,\n")
  cat("     because the term it would add is worse than adding nothing.\n")
  cat("     STOP -- do not build the harness arms.\n")
  if (is.finite(sub_improve) && sub_improve > 0) {
    cat("\n     BUT NOTE, and do not act on it without a proper test: the\n")
    cat(sprintf("     pre-registered baseline-broken subgroup improves (%+.3f), in\n",
                sub_improve))
    cat("     every cell that could be scored. The plan named that subgroup as\n")
    cat("     the entire argument for demographics -- and did NOT anticipate it\n")
    cat("     winning while the overall test loses.\n")
    cat("     Adopting on a subgroup after losing overall is cherry-picking.\n")
    cat("     Report both; adopt neither; test properly with more data.\n")
  }
} else {
  cat(sprintf("     Positive out-of-sample improvement (%+.4f points of swing MAE).\n",
              mean(R$improvement)))
  cat("     Proceed to the harness arms, where the criterion is seat log score\n")
  cat("     through the full count, per the plan.\n")
}
fwrite(R, file.path("output", "demographic-swing-loo.csv"))
cat("\nWrote output/demographic-swing-loo.csv\n")
