# Does the SAME PERSON standing again change how a seat's vote carries forward?
#
# The forecast is entirely party-class based: mat22 is a seat x class matrix and
# simulate_seat_contests() never sees a person. So a seat that returned a 35%
# independent is projected identically whether that independent re-stands or has
# retired and been replaced by a stranger.
#
# An earlier pass measured this on 4 election pairs and reported that as a data
# limit. It was a BUG: it filtered on the `surname` field, which is NA for every
# state row because commissions supply one `name` field instead of two.
# surname_of() reads both layouts, and all 17 consecutive pairs have names on
# both sides -- 100% coverage across 24 elections.
#
# Emits CP* codes.
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
  # NOT `now`/`prev`: those are COLUMN names on D below, and a bare symbol
  # inside dt[...] binds to the column. Five instances of this in CLAUDE.md and
  # this script was the sixth before it was renamed.
  NOWT  <- C[region == rg & year == yr]
  PREVT <- C[region == rg & year == py]
  sh <- intersect(unique(NOWT$seat), unique(PREVT$seat))
  if (length(sh) < 30) next
  for (cls in c("IND", "GRN", "ONP", "OTH_RIGHT")) {
    a <- NOWT [seat %in% sh & party == cls, .(now  = sum(pcv)), by = seat]
    b <- PREVT[seat %in% sh & party == cls, .(prev = sum(pcv)), by = seat]
    D <- merge(data.table(seat = sh), merge(a, b, by = "seat", all = TRUE),
               by = "seat", all.x = TRUE)
    D[is.na(now), now := 0][is.na(prev), prev := 0]
    if (nrow(D) < 30 || sum(D$prev > 0) < 10) next
    # SAME PERSON: a surname standing for this class in this seat at both.
    # Surname only, exactly -- a six-character full-name prefix once matched
    # Daniel POLLOCK to Zoe DANIEL and recorded her debut as a re-run.
    for (rl in c("surname", "initial", "full")) {
      set(D, j = paste0("same_", rl), value = vapply(D$seat, function(s) {
        a <- match_key(NOWT [seat == s & party == cls, sur],
                       NOWT [seat == s & party == cls, giv], rl)
        b <- match_key(PREVT[seat == s & party == cls, sur],
                       PREVT[seat == s & party == cls, giv], rl)
        any(nzchar(a) & a %in% b[nzchar(b)])
      }, TRUE))
    }
    D[, `:=`(dn = now - mean(now), dp = prev - mean(prev),
             pair = paste0(rg, yr), class = cls)]
    rows[[length(rows) + 1L]] <- D
  }
}
A <- rbindlist(rows)
cat(sprintf("CP1  %d pairs | %d classes | %d seat-observations\n",
            uniqueN(A$pair), uniqueN(A$class), nrow(A)))

# WHICH MATCHING RULE? An empirical question, so all three are reported rather
# than argued. No rule is safe both ways: surname-only wrongly JOINS two people
# who share a surname in one seat, and the stricter rules wrongly SPLIT one
# person recorded under two first names -- Bob/Robert changes even the initial.
# Splitting is the worse error here, because it turns a returning member into a
# fabricated emergence, which is exactly what four NSW seats did.
fit_by <- function(col) {
  t <- A[, {
    m <- stats::lm(dn ~ 0 + dp, .SD); s <- coef(summary(m))
    .(seats = .N, slope = round(s[1, 1], 3), se = round(s[1, 2], 3),
      R2 = round(summary(m)$r.squared, 3))
  }, by = c("class", col)]
  setnames(t, col, "same")[]
}
cat("\nCP2  deviation slope by MATCHING RULE, split on whether the same person stood\n")
for (rl in c("surname", "initial", "full")) {
  col <- paste0("same_", rl)
  cat(sprintf("\n   --- %-7s | matched 'same' in %d of %d seat-observations\n",
              rl, sum(A[[col]]), nrow(A)))
  print(dcast(fit_by(col), class ~ same, value.var = c("seats", "slope", "R2")),
        row.names = FALSE)
}
# The rest reports the INITIAL rule, the electoral-research default.
T <- fit_by("same_initial")
A[, same := same_initial]

cat("\nCP3  is the difference real? per class, slope(same) - slope(new)\n")
for (cls in unique(T$class)) {
  a <- T[class == cls & same == TRUE]; b <- T[class == cls & same == FALSE]
  if (!nrow(a) || !nrow(b)) next
  d <- a$slope - b$slope; se <- sqrt(a$se^2 + b$se^2)
  cat(sprintf("   %-10s %+.3f (SE %.3f, t %+.2f) %s\n", cls, d, se, d/se,
              if (abs(d/se) >= 2) "**" else ""))
}

cat("\nCP4  what it does to a seat that polled 30%% for this class last time\n")
for (cls in unique(T$class)) {
  for (s in c(TRUE, FALSE)) {
    r <- T[class == cls & same == s]; if (!nrow(r)) next
    mn <- A[class == cls & same == s, mean(now)]; mp <- A[class == cls & same == s, mean(prev)]
    cat(sprintf("   %-10s %-14s -> %5.1f%%\n", cls,
        if (s) "same person" else "person gone", mn + r$slope * (30 - mp)))
  }
}
