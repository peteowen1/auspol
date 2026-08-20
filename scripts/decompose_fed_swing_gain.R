# Why does fed_swing gain 15% on two elections and 1% on five?
#
# scripts/test_seat_type_441.R found the transposed measure beating uniform
# swing by 1.2% across five elections, where the published measure gained ~15%
# on the two that have it. That review recorded two candidate causes and refused
# to attribute the gap to either. This separates them.
#
# The separation is arithmetic, not a new model. Three quantities scored on the
# SAME seats wherever the comparison requires it:
#
#   published on 180   vs  transposed on 180   -> how much the MEASURE costs
#   transposed on 180  vs  transposed on 441   -> how much the SAMPLE costs
#
# NOTHING here is a hypothesis test. Five elections cannot support one. It is a
# decomposition of a number already computed, plus a description of which
# elections behave which way.
#
# Emits DC* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
fs <- fread(file.path(P, "fed-swing-transposed.csv"), showProgress = FALSE)

# (state cycle, region, seat file with its actual swing, the federal election
#  before it, and the months between the two polling days)
CYCLES <- list(
  list(2018L, "vic", 2022L, 2016L, 24L),
  list(2019L, "nsw", 2023L, 2016L, 34L),
  list(2020L, "qld", 2024L, 2019L, 17L),
  list(2022L, "vic", 2026L, 2022L,  6L),
  list(2023L, "nsw", 2027L, 2022L, 10L))

d <- rbindlist(lapply(CYCLES, function(k) {
  after <- as.data.table(load_seats(k[[3]], k[[2]]))[, .(seat, actual = prev_swing)]
  tra <- fs[region == k[[2]] & cycle == k[[1]], .(seat, transposed = fed_swing)]
  pub <- tryCatch(
    as.data.table(load_seats(k[[1]], k[[2]]))[, .(seat, published = fed_swing)],
    error = function(e) data.table(seat = character(0), published = numeric(0)))
  m <- merge(merge(after[is.finite(actual)], tra, by = "seat"),
             pub, by = "seat", all.x = TRUE)
  m[, `:=`(election = sprintf("%s%d", k[[2]], k[[1]]), gap_months = k[[5]],
           fed = k[[4]])][]
}))
d[, dev := actual - mean(actual), by = election]
d[, tra_c := transposed - mean(transposed), by = election]
d[, pub_c := published - mean(published[is.finite(published)]), by = election]

loo <- function(dat, col) {
  rbindlist(lapply(unique(dat$election), function(e) {
    f <- stats::lm(stats::as.formula(paste("dev ~", col)), data = dat[election != e])
    te <- dat[election == e]
    data.table(election = e, n = nrow(te),
               mae = mean(abs(te$dev - stats::predict(f, newdata = te))),
               uniform = mean(abs(te$dev)))
  }))
}
pool <- function(x) sum(x$mae * x$n) / sum(x$n)
poolu <- function(x) sum(x$uniform * x$n) / sum(x$n)

both <- d[is.finite(published)]          # the 180 seats with both measures
A180 <- loo(both, "pub_c")
B180 <- loo(both, "tra_c")
B441 <- loo(d, "tra_c")

cat("\nDC1  the three numbers, each against its own sample's uniform swing\n")
res <- data.table(
  what = c("published, 180 seats", "transposed, 180 seats", "transposed, 441 seats"),
  seats = c(sum(A180$n), sum(B180$n), sum(B441$n)),
  uniform = c(poolu(A180), poolu(B180), poolu(B441)),
  mae = c(pool(A180), pool(B180), pool(B441)))
res[, gain_pct := 100 * (uniform - mae) / uniform]
print(res[, .(what, seats, uniform = round(uniform, 4), mae = round(mae, 4),
              gain_pct = round(gain_pct, 1))])

cat(sprintf("\nDC2  MEASURE costs %.1f points of gain (%.1f%% -> %.1f%%, same 180 seats)\n",
            res$gain_pct[1] - res$gain_pct[2], res$gain_pct[1], res$gain_pct[2]))
cat(sprintf("DC2  SAMPLE  costs %.1f points of gain (%.1f%% -> %.1f%%, same measure)\n",
            res$gain_pct[2] - res$gain_pct[3], res$gain_pct[2], res$gain_pct[3]))

# ---- which elections behave which way --------------------------------------
per <- merge(B441[, .(election, n, mae, uniform)],
             unique(d[, .(election, gap_months, fed)]), by = "election")
per[, gain := uniform - mae]
setorder(per, gap_months)
cat("\nDC3  per election, ordered by months between the federal poll and the state one\n")
print(per[, .(election, fed, gap_months, seats = n,
              dispersion = round(uniform, 3), gain = round(gain, 4))])

cat("\nDC4  READ THIS AS A DESCRIPTION, NOT A TEST.\n")
cat("DC4  The ordering below was noticed AFTER the results were seen, so it\n")
cat("DC4  cannot be tested on the same five elections that suggested it. It is\n")
cat("DC4  recorded because of what it implies for the live forecast, not\n")
cat("DC4  because it is established.\n")
sh <- per[gap_months <= 12]; lo <- per[gap_months > 12]
cat(sprintf("DC4  gap <= 12 months (%s): mean gain %+.4f\n",
            paste(sh$election, collapse = ", "), mean(sh$gain)))
cat(sprintf("DC4  gap >  12 months (%s): mean gain %+.4f\n",
            paste(lo$election, collapse = ", "), mean(lo$gain)))
cat(sprintf("DC4  Spearman correlation between gap and gain: %+.2f (n = %d)\n",
            stats::cor(per$gap_months, per$gain, method = "spearman"), nrow(per)))

cat("\nDC5  what this means for the seat the model is actually forecasting\n")
cat("DC5  SEAT_SWING_COEF was fitted on vic2022 and nsw2023 -- gaps of 6 and 10\n")
cat("DC5  months, the two SHORTEST in the set. Victoria 2026 follows federal\n")
cat("DC5  2025 by 18 months, which is longer than either and sits with the\n")
cat("DC5  three elections where the adjustment did not help.\n")
fwrite(per, file.path("output", "fed-swing-gain-by-gap.csv"))
