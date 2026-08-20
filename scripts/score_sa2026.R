# Score sa2026, the one short-gap election that does not come from federal 2022.
#
# WHY IT MATTERS. Refusal G1 in docs/plans/prereg-gap-decay.md named the
# confound the gap test could not break: every short-gap election in the corpus
# (vic2022, nsw2023) follows federal 2022, so "short gap helps" and "federal
# 2022 was unusual" make identical predictions. sa2026 breaks it -- 21 March
# 2026, following federal 2025 by 10 months, a SHORT gap sharing its federal
# election with Victoria 2026 at 18 months.
#
# WHY IT IS PARTIAL, AND WHY THAT IS NOT A TECHNICALITY. A two-party-preferred
# swing needs a Labor-versus-Liberal count, and in 2026 the Liberals failed to
# make the final two in 26 of 47 South Australian districts -- One Nation did
# instead. ECSA computes a notional two-party figure for some of those and not
# others. So this is scored on a MINORITY of districts, selected by the Liberal
# Party surviving to the final two, which is the opposite of random.
#
# The direction of that selection is knowable: these are the districts where
# the Liberal vote held up best. Whether that flatters or hurts fed_swing is
# NOT knowable in advance, which is why the result is reported as one
# observation and not as a decision.
#
# Emits SS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

ECSA <- file.path("external", "reference", "ecsa", "sa2026-districts.csv")
if (!file.exists(ECSA)) {
  stop("Run scripts/fetch_sa2026.py first -- ", ECSA, " does not exist.")
}
e <- fread(ECSA, showProgress = FALSE)
sf <- as.data.table(load_seats(2026L, "sa"))

# NAME MATCH BEFORE ANYTHING ELSE. A silent partial join here would look like
# a smaller sample rather than an error, and the sample is already small.
miss_e <- setdiff(e$seat, sf$seat); miss_s <- setdiff(sf$seat, e$seat)
cat(sprintf("\nSS1  ECSA %d districts, 2026sa.txt %d seats\n", nrow(e), nrow(sf)))
if (length(miss_e) || length(miss_s)) {
  stop("Names do not match. ECSA only: ", paste(miss_e, collapse = ", "),
       " | seat file only: ", paste(miss_s, collapse = ", "))
}
cat("SS1  every district name matches.\n")

d <- merge(e[, .(seat, alp_2pp, winner, runner_up)], sf, by = "seat")
d[, alp_2pp := suppressWarnings(as.numeric(alp_2pp))]

# The seat file's `margin` is the NOTIONAL Labor two-party margin on the 2026
# boundaries going into the election, so the pre-election two-party share is
# 50 + margin/2 and the swing is the difference from it.
d[, notional_alp_2pp := 50 + margin / 2]
d[, swing := alp_2pp - notional_alp_2pp]

cat(sprintf("\nSS2  districts with a Labor-versus-Liberal count: %d of %d\n",
            sum(is.finite(d$swing)), nrow(d)))
cat("SS2  who made the final two, across all 47:\n")
print(d[, .N, by = .(winner, runner_up)][order(-N)])

# Does the seat file's own `classic` flag agree about which seats are two-party
# contests? It was set before the election; the outcome is what actually
# decided it, and the gap between the two is a result in itself.
cat(sprintf("\nSS3  the seat file expected %d classic contests; %d delivered one\n",
            sum(d$classic), sum(is.finite(d$swing))))
broke <- d[classic == TRUE & !is.finite(swing)]
cat(sprintf("SS3  %d seats were expected classic and were NOT (Liberal missed the final two):\n",
            nrow(broke)))
if (nrow(broke)) print(head(broke[, .(seat, margin, winner, runner_up)], 10))

sc <- d[is.finite(swing)]
cat(sprintf("\nSS4  on the %d scorable districts: mean swing %+.2f, sd %.2f\n",
            nrow(sc), mean(sc$swing), stats::sd(sc$swing)))
cat(sprintf("SS4  those districts' mean prior Labor margin %+.2f, against %+.2f for the other %d\n",
            mean(sc$margin), mean(d[!is.finite(swing), margin]),
            nrow(d) - nrow(sc)))

# ---- the gain, computed exactly as the other elections' gains were ----------
P <- election_data_path()
fs <- fread(file.path(P, "fed-swing-transposed.csv"), showProgress = FALSE)
tra <- fs[region == "sa" & cycle == 2026L, .(seat, transposed = fed_swing)]
sc <- merge(sc, tra, by = "seat")
sc[, dev := swing - mean(swing)]

# Trained on the seven elections already in the corpus, predicting sa2026.
CYCLES <- list(list(2022L, "vic", 2026L), list(2023L, "nsw", 2027L),
               list(2020L, "qld", 2024L), list(2018L, "sa", 2022L),
               list(2018L, "vic", 2022L), list(2019L, "nsw", 2023L),
               list(2022L, "sa", 2026L))
tr <- rbindlist(lapply(CYCLES, function(k) {
  after <- as.data.table(load_seats(k[[3]], k[[2]]))[, .(seat, actual = prev_swing)]
  f <- fs[region == k[[2]] & cycle == k[[1]], .(seat, fed_swing)]
  m <- merge(after[is.finite(actual)], f, by = "seat")
  m[, election := sprintf("%s%d", k[[2]], k[[1]])][]
}))
tr[, `:=`(dev = actual - mean(actual), fed_c = fed_swing - mean(fed_swing)), by = election]

for (meas in c("transposed", "published")) {
  x <- if (meas == "transposed") sc$transposed else sc$fed_swing
  if (!all(is.finite(x))) { cat(sprintf("SS5  %s: not available\n", meas)); next }
  te <- data.table(dev = sc$dev, fed_c = x - mean(x))
  fit <- stats::lm(dev ~ fed_c, data = tr)
  mae <- mean(abs(te$dev - stats::predict(fit, newdata = te)))
  uni <- mean(abs(te$dev))
  cat(sprintf("\nSS5  %-11s measure: uniform %.4f, with fed_swing %.4f, gain %+.4f\n",
              meas, uni, mae, uni - mae))
}

cat("\nSS6  G1 -- what this observation is for\n")
cat("SS6  sa2026 is a SHORT-gap election (10 months) drawing on federal 2025,\n")
cat("SS6  not federal 2022. If the short-gap advantage is real it should appear\n")
cat("SS6  here. If it was federal 2022 being unusual, it should not.\n")
fwrite(sc[, .(seat, margin, notional_alp_2pp, alp_2pp, swing, dev, transposed,
              published = fed_swing)],
       file.path("output", "sa2026-scored.csv"))
