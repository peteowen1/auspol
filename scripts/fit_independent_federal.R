# The three-mechanism independent model, refitted on 886 federal division-pairs.
#
# Against docs/plans/prereg-independent-federal.md, committed before this ran.
# The model is IDENTICAL to v3; only the corpus and the cross-validation change.
# Altering the structure here would make the comparison to v3 worthless.
#
# Emits FI* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
SITTING_CUT <- 15          # carried over from v3 unchanged, and NOT tuned
YRS <- c(2007, 2010, 2013, 2016, 2019, 2022, 2025)

fp <- fread(file.path(P, "aec-fed-firstprefs.csv"))
fp[, pct := 100 * votes / sum(votes), by = .(election, seat)]
wide <- dcast(fp, election + seat ~ party, value.var = "pct", fill = 0)
win <- fread(file.path(P, "aec-fed-winners.csv"))

pairs <- rbindlist(lapply(seq_len(length(YRS) - 1L), function(i) {
  a <- wide[election == sprintf("fed%d", YRS[i])]
  b <- wide[election == sprintf("fed%d", YRS[i + 1L])]
  wa <- win[election == sprintf("fed%d", YRS[i]), .(seat, prev_winner = winner)]
  m <- merge(a[, .(seat, IND_prev = IND, OTH_prev = OTH,
                   OTHR_prev = OTH_RIGHT, ALP_prev = ALP, LNP_prev = LNP)],
             b[, .(seat, IND_now = IND)], by = "seat")
  m <- merge(m, wa, by = "seat")
  m[, `:=`(pair = sprintf("%d->%d", YRS[i], YRS[i + 1L]),
           target = sprintf("fed%d", YRS[i + 1L]))]
  m[]
}))

# The four v3 features, built the same way. `abs_margin` is not available for
# every federal pair, so the two-candidate margin is derived from the previous
# election's own two-party split rather than from a seat file that does not
# exist for 2010 or 2013.
pairs[, other_nonmajor_prev := OTH_prev + OTHR_prev]
pairs[, ind_prev := IND_prev]
pairs[, abs_margin := abs(ALP_prev - LNP_prev)]
pairs[, coalition_held := as.integer(prev_winner == "LNP")]
pairs[, sitting := ind_prev >= SITTING_CUT]

cat(sprintf("\nFI1  %d matched division-pairs across %d pairs\n",
            nrow(pairs), uniqueN(pairs$pair)))
print(pairs[, .(divisions = .N, sitting_ind = sum(sitting),
                mean_ind_now = round(mean(IND_now), 2)), by = pair])
cat(sprintf("FI1  sitting-independent observations: %d  (NSW had 9)\n", sum(pairs$sitting)))

# ---- route 1: sitting independents -----------------------------------------
sit <- pairs[sitting == TRUE]
sit[, recontested := IND_now >= 5]
cat(sprintf("\nFI2  recontest: %d of %d = %.3f  (NSW had 8 of 9)\n",
            sum(sit$recontested), nrow(sit), mean(sit$recontested)))
cat(sprintf("FI2  Jeffreys 95%%: %.3f to %.3f\n",
            stats::qbeta(0.025, sum(sit$recontested) + 0.5,
                         sum(!sit$recontested) + 0.5),
            stats::qbeta(0.975, sum(sit$recontested) + 0.5,
                         sum(!sit$recontested) + 0.5)))
cat("FI2  by election, so one year cannot carry it (J2)\n")
print(sit[, .(n = .N, recontested = sum(recontested),
              rate = round(mean(recontested), 3)), by = pair])

re <- sit[recontested == TRUE]
m1 <- stats::lm(log1p(IND_now) ~ log1p(ind_prev), data = re)
c1 <- stats::coef(m1); se1 <- summary(m1)$coefficients[2, 2]
cat(sprintf("\nFI3  route 1 on %d recontesting divisions\n", nrow(re)))
cat(sprintf("FI3  log1p(next) = %.3f + %.3f * log1p(previous), slope SE %.3f\n",
            c1[1], c1[2], se1))
cat(sprintf("FI3  distance from 1: %.2f SE   (NSW gave 0.925 +/- 0.281)\n",
            abs(c1[2] - 1) / se1))
cat(sprintf("FI3  residual sd on the log1p scale: %.4f\n", summary(m1)$sigma))
cat("FI3  fitted per election (J1: report the spread, do not hide it)\n")
print(re[, {
  if (.N >= 5) {
    mm <- stats::lm(log1p(IND_now) ~ log1p(ind_prev), data = .SD)
    .(n = .N, slope = round(stats::coef(mm)[2], 3))
  } else .(n = .N, slope = NA_real_)
}, by = pair])

# ---- route 2: emergence -----------------------------------------------------
FEAT <- c("other_nonmajor_prev", "ind_prev", "abs_margin", "coalition_held")
FORM <- stats::as.formula(paste("y ~", paste(FEAT, collapse = " + ")))
em <- pairs[sitting == FALSE]
em[, y := log1p(IND_now)]
fit_t <- function(train) {
  X <- stats::model.matrix(FORM, data = train); yv <- train$y; k <- ncol(X)
  nll <- function(par) {
    b <- par[1:k]; g <- par[(k + 1):(2 * k)]; nu <- exp(par[2 * k + 1]) + 2.01
    mu <- as.vector(X %*% b); sg <- exp(pmin(as.vector(X %*% g), 5))
    if (any(!is.finite(sg)) || any(sg <= 0)) return(1e10)
    -sum(stats::dt((yv - mu) / sg, df = nu, log = TRUE) - log(sg))
  }
  st <- c(stats::coef(stats::lm(FORM, data = train)), rep(0, k), log(5))
  st[is.na(st)] <- 0
  o <- stats::optim(st, nll, method = "BFGS", control = list(maxit = 3000, reltol = 1e-10))
  list(b = o$par[1:k], g = o$par[(k + 1):(2 * k)], nu = exp(o$par[2 * k + 1]) + 2.01)
}
f2 <- fit_t(em)
cat(sprintf("\nFI4  route 2 on %d non-sitting divisions\n", nrow(em)))
print(data.table(term = colnames(stats::model.matrix(FORM, data = em)),
                 location = round(f2$b, 4), log_spread = round(f2$g, 4)))
cat(sprintf("FI4  estimated degrees of freedom %.1f  (NSW gave effectively normal)\n", f2$nu))

# ---- J2: hold 2022 out entirely --------------------------------------------
cat("\nFI5  J2 -- the same fits with the 2019->2022 pair removed\n")
sit22 <- sit[pair != "2019->2022"]; re22 <- re[pair != "2019->2022"]
cat(sprintf("FI5  recontest without 2022: %d of %d = %.3f\n",
            sum(sit22$recontested), nrow(sit22), mean(sit22$recontested)))
m1b <- stats::lm(log1p(IND_now) ~ log1p(ind_prev), data = re22)
cat(sprintf("FI5  route 1 slope without 2022: %.3f (with: %.3f)\n",
            stats::coef(m1b)[2], c1[2]))
f2b <- fit_t(em[pair != "2019->2022"])
cat(sprintf("FI5  route 2 ind_prev location without 2022: %.4f (with: %.4f)\n",
            f2b$b[3], f2$b[3]))

# ---- leave-one-election-out parameter sets ---------------------------------
loo <- list()
for (tg in unique(pairs$target)) {
  tr <- pairs[target != tg]
  st <- tr[sitting == TRUE]; rr <- st[IND_now >= 5]
  mm <- stats::lm(log1p(IND_now) ~ log1p(ind_prev), data = rr)
  e2 <- fit_t(tr[sitting == FALSE][, y := log1p(IND_now)][])
  loo[[tg]] <- list(cut = SITTING_CUT, recontest = mean(st$IND_now >= 5),
                    route1 = list(a = stats::coef(mm)[1], b = stats::coef(mm)[2],
                                  s = summary(mm)$sigma, n = nrow(rr)),
                    route2 = e2, form = FORM)
}
cat("\nFI6  leave-one-election-out parameter sets\n")
print(rbindlist(lapply(names(loo), function(k) data.table(
  held_out = k, recontest = round(loo[[k]]$recontest, 3),
  route1_slope = round(loo[[k]]$route1$b, 3),
  route2_ind = round(loo[[k]]$route2$b[3], 4)))))
saveRDS(list(loo = loo, full = list(cut = SITTING_CUT,
                                    recontest = mean(sit$recontested),
                                    route1 = list(a = c1[1], b = c1[2],
                                                  s = summary(m1)$sigma),
                                    route2 = f2, form = FORM)),
        "output/independent-federal-fit.rds")
fwrite(pairs, file.path("output", "federal-pairs.csv"))
cat("\nFI7  wrote output/independent-federal-fit.rds and federal-pairs.csv\n")
