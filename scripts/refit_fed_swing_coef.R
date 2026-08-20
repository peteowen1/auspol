# Which fed_swing measure, and which coefficient?
#
# Against docs/plans/prereg-fed-swing-coefficient.md, committed before this ran.
# The decision rule and refusals S1-S5 are there and are NOT restated.
#
# S1 is the one that shapes the code: a coefficient must be fitted on the SAME
# measure it is applied to. Fitting on the noisier transposed measure and
# applying to the cleaner published one would under-apply by exactly the
# attenuation, so no arm mixes them.
#
# Emits RF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
fs <- fread(file.path(P, "fed-swing-transposed.csv"), showProgress = FALSE)

# (state cycle being predicted, region, the seat file holding its actual swing)
# Queensland 2020 is new: its correspondence did not exist until
# scripts/build_correspondence.R built it from polling place coordinates. QLD
# 2024 is deliberately absent -- 2028qld.txt does not exist, so there is no
# recorded swing to score it against.
CYCLES <- list(list(2018, "vic", 2022), list(2019, "nsw", 2023),
               list(2020, "qld", 2024),
               list(2022, "vic", 2026), list(2023, "nsw", 2027))

d <- rbindlist(lapply(CYCLES, function(k) {
  yr <- k[[1]]; rg <- k[[2]]; nxt <- k[[3]]
  after <- as.data.table(load_seats(nxt, rg))[, .(seat, actual = prev_swing)]
  # There is no 2018vic.txt seat file, and no published fed_swing for the two
  # new cycles either -- which is the whole reason the transposed measure was
  # built. Absent is recorded as NA rather than allowed to abort the run.
  before <- tryCatch(
    as.data.table(load_seats(yr, rg))[, .(seat, published = fed_swing)],
    error = function(e) data.table(seat = character(0), published = numeric(0)))
  tra <- fs[region == rg & cycle == yr, .(seat, transposed = fed_swing)]
  m <- merge(merge(after[is.finite(actual)], before, by = "seat", all.x = TRUE),
             tra, by = "seat")
  m[, election := sprintf("%s%d", rg, yr)][]
}))
d[, dev := actual - mean(actual), by = election]
d[, tra_c := transposed - mean(transposed), by = election]
d[, pub_c := ifelse(is.finite(published), published - mean(published[is.finite(published)]),
                    NA_real_), by = election]

cat(sprintf("\nRF1  %d seats across %d elections\n", nrow(d), uniqueN(d$election)))
print(d[, .(seats = .N, has_published = sum(is.finite(published)),
            baseline_mae = round(mean(abs(dev)), 3)), by = election])

loo <- function(dat, col) {
  rbindlist(lapply(unique(dat$election), function(e) {
    tr <- dat[election != e]; te <- dat[election == e]
    f <- stats::lm(stats::as.formula(paste("dev ~", col)), data = tr)
    data.table(election = e, n = nrow(te),
               coef = unname(stats::coef(f)[2]),
               mae = mean(abs(te$dev - stats::predict(f, newdata = te))),
               uniform = mean(abs(te$dev)))
  }))
}

# ---- arm B: transposed, four elections -------------------------------------
B <- loo(d, "tra_c")
cat("\nRF2  arm B -- transposed measure, coefficient fitted leave-one-election-out\n")
print(B[, .(election, n, coef = round(coef, 3), mae = round(mae, 3),
            uniform = round(uniform, 3), gain = round(uniform - mae, 4))])
cat(sprintf("RF2  coefficient across folds: %.3f to %.3f  (S4: is it stable?)\n",
            min(B$coef), max(B$coef)))

# ---- arm A: published, the two elections that have it ----------------------
dp <- d[is.finite(published)]
A <- loo(dp, "pub_c")
cat(sprintf("\nRF3  arm A -- published measure, only %d seats across %d elections have it\n",
            nrow(dp), uniqueN(dp$election)))
print(A[, .(election, n, coef = round(coef, 3), mae = round(mae, 3),
            uniform = round(uniform, 3), gain = round(uniform - mae, 4))])

# ---- comparison on the SAME seats, so the arms are commensurable -----------
# Comparing a 4-election pooled MAE against a 2-election one would compare
# different seats, so both are also scored on the 180 seats that have both.
cat("\nRF4  head to head on the 180 seats that have BOTH measures\n")
both <- d[is.finite(published)]
res <- rbindlist(lapply(unique(both$election), function(e) {
  te <- both[election == e]
  # Arm A trains only on the other published election; arm B trains on the
  # other THREE, which is the whole point of the transposed measure.
  fa <- stats::lm(dev ~ pub_c, data = both[election != e])
  fb <- stats::lm(dev ~ tra_c, data = d[election != e])
  data.table(election = e, n = nrow(te),
             mae_A = mean(abs(te$dev - stats::predict(fa, newdata = te))),
             mae_B = mean(abs(te$dev - stats::predict(fb, newdata = te))),
             mae_C = mean(abs(te$dev)))
}))
print(res[, .(election, n, A = round(mae_A, 4), B = round(mae_B, 4),
              C_uniform = round(mae_C, 4))])
pa <- sum(res$mae_A * res$n) / sum(res$n)
pb <- sum(res$mae_B * res$n) / sum(res$n)
pc <- sum(res$mae_C * res$n) / sum(res$n)
cat(sprintf("RF4  pooled: A %.4f | B %.4f | C %.4f\n", pa, pb, pc))

# Paired per-seat difference, so the comparison carries a standard error.
pd <- rbindlist(lapply(unique(both$election), function(e) {
  te <- both[election == e]
  fa <- stats::lm(dev ~ pub_c, data = both[election != e])
  fb <- stats::lm(dev ~ tra_c, data = d[election != e])
  data.table(a = abs(te$dev - stats::predict(fa, newdata = te)),
             b = abs(te$dev - stats::predict(fb, newdata = te)))
}))
dif <- pd$b - pd$a; se <- stats::sd(dif) / sqrt(length(dif))
cat(sprintf("RF5  B minus A: %+.4f MAE, SE %.4f -> %+.2f SE (negative = B better)\n",
            mean(dif), se, mean(dif) / se))
verdict <- if (min(pa, pb) >= pc) {
  "REMOVE the adjustment -- neither measure beats uniform swing"
} else if (abs(mean(dif) / se) <= 1) {
  "KEEP A -- within 1 SE, and the status quo wins ties"
} else if (mean(dif) < 0) "ADOPT B -- the transposed measure is better" else
  "KEEP A -- the published measure is better"
cat(sprintf("\nRF6  verdict: %s\n", verdict))
fwrite(res, file.path("output", "fed-swing-coef-refit.csv"))
