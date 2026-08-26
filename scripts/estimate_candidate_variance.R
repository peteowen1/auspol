# How much MORE uncertain is a candidate who has no record in this seat?
#
# The persistence split is usually quoted as a mean effect -- slope 0.907 when
# the same person stands again against 0.326 when they do not. The variance side
# is larger and is not modelled at all: R-squared 0.79 against 0.09. The seat
# simulation uses ONE party_sd for both, which is the most likely cause of
# calibration slopes of 0.18-0.38 (heavily overconfident) seen on every federal
# pair.
#
# This estimates the multiplier rather than choosing it. Residual sd is taken
# around each group's OWN fitted line, so it measures unexplained spread and not
# the difference in slope.
#
# Emits CV* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
C[, `:=`(sur = surname_of(surname, name), giv = given_of(given, name))]
MAJ <- c("ALP", "LNP", "NAT")
E <- unique(C[, .(region, year)])[order(region, year)]

rows <- list()
for (k in seq_len(nrow(E))) {
  rg <- E$region[k]; yr <- E$year[k]
  py <- suppressWarnings(max(C[region == rg & year < yr, year]))
  if (!is.finite(py)) next
  NOWT <- C[region == rg & year == yr]; PREVT <- C[region == rg & year == py]
  sh <- intersect(unique(NOWT$seat), unique(PREVT$seat))
  if (length(sh) < 30) next
  for (cls in c("IND", "GRN", "ONP", "OTH_RIGHT", "ALP", "LNP")) {
    a <- NOWT [seat %in% sh & party == cls, .(now  = sum(pcv)), by = seat]
    b <- PREVT[seat %in% sh & party == cls, .(prev = sum(pcv)), by = seat]
    D <- merge(data.table(seat = sh), merge(a, b, by = "seat", all = TRUE),
               by = "seat", all.x = TRUE)
    D[is.na(now), now := 0][is.na(prev), prev := 0]
    if (nrow(D) < 30 || sum(D$prev > 0) < 10) next
    D[, same := vapply(seat, function(s) {
      x <- match_key(NOWT [seat == s & party == cls, sur], NOWT [seat == s & party == cls, giv], "initial")
      y <- match_key(PREVT[seat == s & party == cls, sur], PREVT[seat == s & party == cls, giv], "initial")
      any(nzchar(x) & x %in% y[nzchar(y)])
    }, TRUE)]
    D[, `:=`(pair = paste0(rg, yr), class = cls)]
    rows[[length(rows) + 1L]] <- D
  }
}
A <- rbindlist(rows)
cat(sprintf("CV1  %d pairs | %d seat-observations | same-candidate in %d\n",
            uniqueN(A$pair), nrow(A), sum(A$same)))

# Residual around each group's OWN line: unexplained spread, not slope.
cat("\nCV2  residual sd around each group's own fitted line\n")
T <- A[, {
  m <- stats::lm(now ~ prev, .SD)
  .(seats = .N, resid_sd = round(stats::sd(stats::residuals(m)), 2),
    R2 = round(summary(m)$r.squared, 3))
}, by = .(class, same)]
W <- dcast(T, class ~ same, value.var = c("seats", "resid_sd", "R2"))
W[, multiplier := round(resid_sd_FALSE / resid_sd_TRUE, 2)]
print(W, row.names = FALSE)

cat("\nCV3  pooled across the minor classes, which is where it bites\n")
M <- A[class %in% c("IND", "GRN", "ONP", "OTH_RIGHT")]
for (s in c(TRUE, FALSE)) {
  m <- stats::lm(now ~ prev, M[same == s])
  cat(sprintf("   %-12s n %4d | residual sd %.2f | R2 %.3f\n",
              if (s) "same person" else "person gone", nrow(M[same == s]),
              stats::sd(stats::residuals(m)), summary(m)$r.squared))
}
mm <- stats::sd(stats::residuals(stats::lm(now ~ prev, M[same == FALSE]))) /
      stats::sd(stats::residuals(stats::lm(now ~ prev, M[same == TRUE])))
cat(sprintf("   POOLED MULTIPLIER %.2f  (a new candidate is this many times as uncertain)\n", mm))

cat("\nCV4  the majors, as a control -- a party always fields someone, so the\n")
cat("     multiplier there should be near 1 and this checks the measure itself\n")
J <- A[class %in% c("ALP", "LNP")]
for (s in c(TRUE, FALSE)) {
  if (!nrow(J[same == s])) next
  m <- stats::lm(now ~ prev, J[same == s])
  cat(sprintf("   %-12s n %4d | residual sd %.2f\n",
              if (s) "same person" else "person gone", nrow(J[same == s]),
              stats::sd(stats::residuals(m))))
}

# ---- SEAT-LEVEL component, which is what simulate_seat_contests() draws ------
# The fit above is TOTAL residual sd: it contains the statewide party movement
# AND the seat's own deviation. simulate_seat_contests() adds those separately --
# party_sd at the statewide level, seat_sd per seat -- so feeding the total into
# the seat draw would count the statewide part twice.
#
# Subtract it in variance: seat_sd(p) = sqrt(total(p)^2 - party_sd^2).
PARTY_SD <- 1.5   # the published value in fit_seats_full.R
cat("\nCV5  decomposing total residual sd into its seat-level part\n")
B <- rbindlist(rows)
B[, sw := mean(now) - mean(prev), by = .(pair, class)]
B[, pred := pmax(0, prev + sw)][, resid := now - pred]
B[, s := sqrt(pmin(pmax(pred, 0), 100) / 100 * (1 - pmin(pmax(pred, 0), 100) / 100))]
K <- sqrt(pi / 2)
tot <- stats::lm(abs(resid) ~ s, B)
ta <- coef(tot)[1] * K; tb <- coef(tot)[2] * K
cat(sprintf("     TOTAL      sd = %.2f + %.2f * sqrt(p(1-p))\n", ta, tb))
grid <- seq(0, 0.5, by = 0.01)
tot_sd <- ta + tb * sqrt(grid * (1 - grid))
seat_sd <- sqrt(pmax(tot_sd^2 - PARTY_SD^2, 0.01))
fit2 <- stats::lm(seat_sd ~ sqrt(grid * (1 - grid)))
cat(sprintf("     SEAT-LEVEL sd = %.2f + %.2f * sqrt(p(1-p))   (after removing party_sd %.1f)\n",
            coef(fit2)[1], coef(fit2)[2], PARTY_SD))
cat(sprintf("     check: at p=0.50 total %.2f -> seat %.2f | at p=0.02 total %.2f -> seat %.2f\n",
            ta + tb * 0.5, sqrt((ta + tb * 0.5)^2 - PARTY_SD^2),
            ta + tb * sqrt(.02 * .98), sqrt((ta + tb * sqrt(.02 * .98))^2 - PARTY_SD^2)))
cat(sprintf("     today's flat seat_sd is 3.50 for every level\n"))
