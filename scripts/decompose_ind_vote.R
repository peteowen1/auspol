# How much of the IND vote is PARTY (statewide movement, generic independent
# appeal in that seat) versus CANDIDATE (the specific person)?
#
# METHOD: three nested models predicting a seat's current IND share, in
# increasing order of information used, over the SAME 17-pair corpus used
# throughout this session.
#
#   M0  party level only    -- everyone gets the statewide IND mean. No seat
#                               information at all.
#   M1  + seat history      -- uniform swing off THIS SEAT's own prior IND
#                               share, regardless of who is running (this is
#                               what ships today: mat22 + statewide movement).
#   M2  + candidate identity -- same, but the slope depends on whether the
#                               SAME PERSON stood before (screened_slopes'
#                               "same" vs "new" split).
#
# R2(M1)-R2(M0) is what a prior independent PRESENCE in the seat buys, with no
# knowledge of who it was. R2(M2)-R2(M1) is what knowing the PERSON buys on
# top of that.
#
# Emits ID* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
C[, `:=`(sur = surname_of(surname, name), giv = given_of(given, name))]
E <- unique(C[, .(region, year)])[order(region, year)]
rows <- list()

for (k in seq_len(nrow(E))) {
  rg <- E$region[k]; yr <- E$year[k]
  py <- suppressWarnings(max(C[region == rg & year < yr, year]))
  if (!is.finite(py)) next
  NOWT <- C[region == rg & year == yr]; PREVT <- C[region == rg & year == py]
  sh <- intersect(unique(NOWT$seat), unique(PREVT$seat))
  if (length(sh) < 20) next

  a <- NOWT [seat %in% sh & party == "IND", .(now  = sum(pcv)), by = seat]
  b <- PREVT[seat %in% sh & party == "IND", .(prev = sum(pcv)), by = seat]
  D <- merge(data.table(seat = sh), merge(a, b, by = "seat", all = TRUE),
             by = "seat", all.x = TRUE)
  D[is.na(now), now := 0][is.na(prev), prev := 0]
  D[, same := vapply(seat, function(s) {
    x <- match_key(NOWT [seat == s & party == "IND", sur], NOWT [seat == s & party == "IND", giv], "initial")
    y <- match_key(PREVT[seat == s & party == "IND", sur], PREVT[seat == s & party == "IND", giv], "initial")
    any(nzchar(x) & x %in% y[nzchar(y)])
  }, TRUE)]
  D[, `:=`(pair = paste0(rg, yr), region = rg)]
  rows[[length(rows) + 1L]] <- D
}
A <- rbindlist(rows)
cat(sprintf("ID1  %d pairs | %d seat-observations of the IND class\n", uniqueN(A$pair), nrow(A)))

# M0: party level only -- the statewide IND mean for THAT election, no seat info.
A[, m0 := mean(now), by = pair]
# M1: uniform swing off the seat's own prior -- "arm U" for IND.
A[, sw := mean(now) - mean(prev), by = pair]
A[, m1 := pmax(0, prev + sw)]
# M2: candidate-conditional slope -- "arm C" for IND. Slope fitted on the
# DEVIATION from each election's own mean (matching how dev_slope() is used in
# the shipped model), and HELD OUT by pair so no election informs its own fit.
A[, m2 := NA_real_]
for (pr in unique(A$pair)) {
  fit <- A[pair != pr]
  fit[, `:=`(dn = now - mean(now), dp = prev - mean(prev)), by = pair]
  s_same <- coef(lm(dn ~ 0 + dp, fit[same == TRUE]))
  s_new  <- coef(lm(dn ~ 0 + dp, fit[same == FALSE]))
  ix <- which(A$pair == pr)
  m_now <- mean(A$now[ix]); m_prev <- mean(A$prev[ix])
  slope <- ifelse(A$same[ix], s_same, s_new)
  A[ix, m2 := pmax(0, m_now + slope * (prev - m_prev))]
}

cat("
ID2  R2 of each model, PARTY -> +SEAT HISTORY -> +CANDIDATE IDENTITY
")
r2 <- function(pred, actual) 1 - sum((actual - pred)^2) / sum((actual - mean(actual))^2)
cat(sprintf("  M0 party level only        R2 %.4f
", r2(A$m0, A$now)))
cat(sprintf("  M1 + seat history          R2 %.4f  (gain %+.4f)
",
            r2(A$m1, A$now), r2(A$m1, A$now) - r2(A$m0, A$now)))
cat(sprintf("  M2 + candidate identity    R2 %.4f  (gain %+.4f)
",
            r2(A$m2, A$now), r2(A$m2, A$now) - r2(A$m1, A$now)))

cat(sprintf("
ID3  RMSE, the practical version of the same question
"))
rmse <- function(pred, actual) sqrt(mean((actual - pred)^2))
cat(sprintf("  M0 party level only        RMSE %.2f
", rmse(A$m0, A$now)))
cat(sprintf("  M1 + seat history          RMSE %.2f
", rmse(A$m1, A$now)))
cat(sprintf("  M2 + candidate identity    RMSE %.2f
", rmse(A$m2, A$now)))

cat("
ID4  split by SAME vs NEW -- where does each component's value concentrate?
")
for (s in c(TRUE, FALSE)) {
  x <- A[same == s]
  cat(sprintf("  %-16s n=%4d | M0 R2 %.3f | M1 R2 %.3f | M2 R2 %.3f
",
      if (s) "same candidate" else "different/none", nrow(x),
      r2(x$m0, x$now), r2(x$m1, x$now), r2(x$m2, x$now)))
}

cat(sprintf("
ID5  answer, in plain terms
"))
cat(sprintf("  Knowing this was an independent seat AT ALL, with no ID:      R2 %.3f
", r2(A$m0,A$now)))
cat(sprintf("  + knowing this SEAT'S prior IND share (party+geography):      R2 %.3f
", r2(A$m1,A$now)))
cat(sprintf("  + knowing whether it is the SAME PERSON:                     R2 %.3f
", r2(A$m2,A$now)))
