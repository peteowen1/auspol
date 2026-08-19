# An EXTERNAL check on the Victorian seat model's One Nation seat count, against
# docs/reviews/onp-seats-vs-sa-2026-08-19.md.
#
# Every other check on this model is internal -- pre-registered thresholds,
# symmetry conditions, self-consistency. South Australia 2026 is the only
# completed election where One Nation contested at the level Victoria is
# forecasting, so it is the only place the share-to-seat relationship can be
# OBSERVED rather than assumed.
#
# Read the caveats in the write-up before quoting the number. The logistic fit
# is in-sample on 47 districts, the party landscapes differ, and it is one
# election.
#
# Emits SV* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
library(data.table)

PREF <- election_data_path()
fp <- fread(file.path(PREF, "ecsa-2026-sa-firstprefs.csv"))
tx <- fread(file.path(PREF, "ecsa-2026-sa-transfers.csv"))

seats <- sort(unique(fp$seat))
sa <- rbindlist(lapply(seats, function(s) {
  f <- fp[seat == s]
  t_in <- tx[seat == s, list(gain = sum(votes)), by = "to"]
  tot <- merge(f, t_in, by.x = "party", by.y = "to", all.x = TRUE)
  tot[is.na(gain), gain := 0]
  tot[, final := votes + gain]
  excluded <- unique(tx[seat == s, from])
  surv <- tot[!(party %in% excluded)]
  if (!nrow(surv)) return(NULL)
  data.table(seat = s,
             onp = 100 * sum(f[party == "ONP", votes]) / sum(f$votes),
             won = surv[which.max(final), party] == "ONP")
}))
cat(sprintf("SA: %d districts, ONP won %d\n", nrow(sa), sum(sa$won)))

cat("\nONP win rate by first-preference band (SA 2026):\n")
sa[, band := cut(onp, c(-Inf, 20, 25, 27.5, 30, 32.5, Inf),
                 labels = c("<20", "20-25", "25-27.5", "27.5-30", "30-32.5", ">32.5"))]
print(sa[, list(districts = .N, won = sum(won),
                rate = round(mean(won), 2)), by = band][order(band)])

# A logistic fit gives a smooth win probability as a function of share, which is
# what the Victorian projected shares can be run through.
m <- stats::glm(won ~ onp, data = sa, family = stats::binomial())
cat(sprintf("\nlogistic fit: P(win) = 0.5 at ONP first prefs = %.1f%%\n",
            -stats::coef(m)[1] / stats::coef(m)[2]))

# Victoria's projected One Nation shares, rebuilt exactly as fit_seats_full.R
# builds them.
vfp <- fread(file.path(PREF, "vec-2022-vic-firstprefs.csv"))
w <- dcast(vfp, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(w[, -1]); rownames(mat) <- w$seat
mat <- 100 * mat / rowSums(mat)
sa_ratio <- sort(sa$onp / mean(sa$onp))
idx <- -0.0968 * mat[, "GRN"]
ord <- order(idx)
ratio <- numeric(nrow(mat)); names(ratio) <- rownames(mat)
for (r in seq_along(ord)) {
  q <- (r - 1) / (length(ord) - 1)
  pos <- q * (length(sa_ratio) - 1)
  l <- floor(pos) + 1; h <- min(l + 1, length(sa_ratio))
  ratio[rownames(mat)[ord[r]]] <- sa_ratio[l] + (pos - (l - 1)) * (sa_ratio[h] - sa_ratio[l])
}
VIC_MEAN <- 20.2   # the model's statewide ONP projection
vic <- VIC_MEAN * ratio
cat(sprintf("\nVictoria projected ONP: mean %.1f, sd %.1f, max %.1f\n",
            mean(vic), stats::sd(vic), max(vic)))
cat(sprintf("Victorian seats projected above the SA 50%% threshold: %d of %d\n",
            sum(vic >= -stats::coef(m)[1] / stats::coef(m)[2]), length(vic)))

p_win <- stats::predict(m, newdata = data.frame(onp = vic), type = "response")
cat(sprintf("\nEXPECTED ONP SEATS applying SA's own share-to-win curve: %.1f\n",
            sum(p_win)))
cat(sprintf("The Victorian seat model currently expects:               2.96\n"))
cat(sprintf("\nSA at its own mean (%.1f%%) would give:                     %.1f\n",
            mean(sa$onp), sum(stats::predict(m, newdata = data.frame(onp = sa$onp),
                                             type = "response"))))
cat(sprintf("  (it actually won %d)\n", sum(sa$won)))
