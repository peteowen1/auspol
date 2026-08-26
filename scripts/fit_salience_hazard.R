# Turn salience into a per-seat surge hazard, against
# docs/plans/prereg-salience-surge-hazard.md.
#
# THE SCALE MISMATCH, HANDLED EXPLICITLY. The AUC of 0.841 was measured on a
# PAIRED RATIO -- one candidate's search volume divided by the incumbent's. The
# whole-seat fetch instead returns a SHARE, each candidate as a percentage of
# the seat's total. Those are different quantities and a model fitted on one
# cannot be applied to the other.
#
# They reconcile because the whole-seat data contains everything the paired
# ratio needs: with every candidate on one scale, the ratio of a challenger to
# the incumbent is simply their two shares divided. So the ratio is RECOVERED
# from the shares rather than refitted, the fitted slope stays applicable, and
# the whole-seat fetch subsumes the paired one instead of competing with it.
#
# WHICH DENOMINATOR. The re-contesting incumbent where one exists; otherwise the
# loudest MAJOR-party candidate in the seat, which is the closest available
# stand-in for "the person they are running against". Flagged either way, and
# never pooled without the flag.
#
# CASE-CONTROL. Group A was selected on winning, so the intercept from that fit
# reflects the sampling design and must NOT be shipped. The slope is unbiased.
# The intercept is recalibrated by the standard offset to the base rate OF THE
# ELECTION BEING PREDICTED -- not a pooled constant, because the non-major win
# rate rose twelvefold from 0.27% in 2007 to 3.43% in 2025, and a pooled value
# would understate the hazard in exactly the elections that matter.
#
# Emits FH* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

MAJ <- c("ALP", "LNP", "NAT")
CLIP <- 0.35            # pre-registered, not a knob

# ---- 1. the slope, from the case-control sample -----------------------------
E <- fread("output/emergence-trends.csv", showProgress = FALSE)
E <- E[is.finite(ratio)]
E[, lr := log1p(ratio)]
g <- glm(won ~ lr, data = E, family = binomial())
cs <- coef(summary(g))
SLOPE <- cs[2, 1]
cat(sprintf("FH1  slope %+.3f (SE %.3f, z %+.2f, p %.4f) from %d rows, %d wins\n",
            SLOPE, cs[2, 2], cs[2, 3], cs[2, 4], nrow(E), sum(E$won)))
cat(sprintf("FH1  raw intercept %+.3f -- NOT shipped, it encodes the sampling\n",
            cs[1, 1]))

# ---- 2. base rate per election, measured ------------------------------------
C <- fread("output/candidacies.csv", showProgress = FALSE)
BR <- C[region == "fed" & !party %in% MAJ & pcv >= 5,
        .(base = mean(elected, na.rm = TRUE), n = .N), by = year]
cat("FH2  base rate of a non-major (>=5%) winning, by election:\n")
print(BR[order(year)], row.names = FALSE)

# ---- 3. recover the paired ratio from the whole-seat shares ------------------
S <- fread("output/seat-salience.csv", showProgress = FALSE)
if (!nrow(S)) stop("output/seat-salience.csv is empty -- run fetch_seat_salience.R")
S[, year := as.integer(sub("^fed", "", election))]

# The incumbent, by name, from the previous election's winner.
W <- C[region == "fed" & elected == TRUE, .(year, seat, win_name = name)]
YRS <- sort(unique(C[region == "fed", year]))
nxt <- data.table(year = YRS[-length(YRS)], to = YRS[-1])
prev <- merge(W, nxt, by = "year")[, .(year = to, seat, inc_name = win_name)]
prev[, inc_kw := normalise_name(inc_name)]

S <- merge(S, prev[, .(year, seat, inc_kw)], by = c("year", "seat"), all.x = TRUE)
S[, is_inc := !is.na(inc_kw) & name == inc_kw]

# is_inc is NA where the seat has no prior-election winner (a new or renamed
# division). NA in an `if` is an error, not FALSE -- the trap CLAUDE.md records
# under "guards that cannot fail" -- so it is resolved to FALSE explicitly.
S[is.na(is_inc), is_inc := FALSE]
S[!is.finite(sal_share), sal_share := 0]
den <- S[, {
  i <- .SD[is_inc == TRUE]
  if (nrow(i) && isTRUE(i$sal_share[1] > 0)) {
    .(den = i$sal_share[1], den_src = "incumbent")
  } else {
    m <- .SD[party %in% MAJ][order(-sal_share)]
    if (nrow(m) && isTRUE(m$sal_share[1] > 0)) .(den = m$sal_share[1], den_src = "top major")
    else .(den = NA_real_, den_src = "none")
  }
}, by = .(election, seat)]
cat("\nFH3  denominator source across seats:\n")
print(den[, .N, by = den_src], row.names = FALSE)

S <- merge(S, den, by = c("election", "seat"))
S[, ratio := fifelse(is.finite(den) & den > 0, sal_share / den, NA_real_)]

# ---- 4. the hazard ----------------------------------------------------------
S <- merge(S, BR[, .(year, base)], by = "year", all.x = TRUE)
n1 <- sum(E$won); n0 <- nrow(E) - n1
S[, offset := log((n1 / n0) / (base / (1 - base)))]
S[, haz := plogis(coef(g)[1] - offset + SLOPE * log1p(ratio))]
S[!is.finite(haz), haz := 0]
S[, haz := pmin(pmax(haz, 0), CLIP)]

nm <- S[!party %in% MAJ]
cat(sprintf("\nFH4  %d non-major candidates in %d seats | hazard median %.4f, max %.4f\n",
            nrow(nm), uniqueN(nm$seat), median(nm$haz), max(nm$haz)))
cat(sprintf("FH4  at the %.2f clip: %d | above 0.10: %d | at zero: %d\n",
            CLIP, sum(nm$haz >= CLIP - 1e-9), sum(nm$haz > 0.10), sum(nm$haz == 0)))

# The seat-level hazard is the strongest non-major in that seat: the surge
# mechanism raises ONE candidate, so a seat's hazard is its best challenger's.
seat_haz <- nm[, .(surge_h = max(haz), who = name[which.max(haz)],
                   ratio = max(ratio, na.rm = TRUE)), by = .(election, seat)]
fwrite(seat_haz, "output/salience-hazard.csv")
cat(sprintf("FH9  wrote output/salience-hazard.csv: %d seats\n", nrow(seat_haz)))
cat("\nFH9  loudest 15 seats -- what the model would be told\n")
print(utils::head(seat_haz[order(-surge_h)], 15), row.names = FALSE)
