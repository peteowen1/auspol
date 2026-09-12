# Where does the per-cell SD model help, where does it hurt, and is there a rule?
# Pete, 2026-09-12: "how does the SD model work? where does it work well? where
# does it make things worse, which seats, is there a pattern? can that help us
# improve things"
#
# HOW IT WORKS. The simulator draws every (seat, class) primary vote from a
# distribution: the centre is the primary model's prediction, the spread is
# sd_override. The SD model replaces that spread with a per-cell prediction
# trained on |actual - predicted|, leave-one-pair-out, converted to a standard
# deviation. It moves no forecast -- it changes how far each vote is allowed to
# wander, which changes win probabilities.
#
# THE MECHANICAL PREDICTION, which this tests: widening should HELP where the
# real winner was an underdog (their tail reaches the win) and HURT where the
# winner was already a strong favourite (probability leaks away to nobody).
# If that holds, the fix is to widen asymmetrically rather than everywhere.
#
# Pooled it is worth -0.98% over 2,050 seat-elections, but three pairs (wa2001,
# nsw2019, sa2026) contribute -11.31 of a -6.33 total, so the other nineteen are
# collectively worse. This looks for what separates them.
#
# Emits XS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
OUT <- "output"

# ON and OFF must differ ONLY in the SD switch. Both are v6 primary, surge off,
# same SHA -- a2dc0c7 carries the v7 primary and is deliberately NOT used here.
PAIRSETS <- list(
  fed = list(on  = "backtest-fed-lv110_867-n5000-cor-qld-sh01-a331ff8-gd0f2ba3x.csv",
             off = "backtest-fed-lv110_867-n5000-cor-qld-sh01-a27ba0d-gc2e8ee6x.csv"),
  wa  = list(on  = "backtest-wa-n5000-lv110_867-sh01-a331faa-gd0f2ba3x.csv",
             off = "backtest-wa-n5000-lv110_867-sh01-a331f67-gd0f2ba3x.csv"))
ll <- function(p) -log(pmax(p, 1e-6))

D <- rbindlist(lapply(names(PAIRSETS), function(k) {
  f <- PAIRSETS[[k]]
  pon <- file.path(OUT, f$on); pof <- file.path(OUT, f$off)
  if (!file.exists(pon) || !file.exists(pof)) {
    cat(sprintf("XS0! %s: missing %s\n", k,
                paste(basename(c(pon, pof)[!file.exists(c(pon, pof))]), collapse = ", ")))
    return(NULL)
  }
  a <- fread(pof, showProgress = FALSE); b <- fread(pon, showProgress = FALSE)
  m <- merge(a[, .(pair, seat, actual, p_off = prob)],
             b[, .(pair, seat, p_on = prob)], by = c("pair", "seat"))
  m[, harness := k]; m
}), fill = TRUE)
stopifnot(nrow(D) > 0)
D[, `:=`(ll_off = ll(p_off), ll_on = ll(p_on))]
D[, d := ll_on - ll_off]          # negative = the SD model helped this seat
cat(sprintf("XS1  %d seats across %d pairs (%s)\n",
            nrow(D), uniqueN(D$pair), paste(unique(D$harness), collapse = "/")))
cat(sprintf("XS1  helped %d | unchanged %d | hurt %d | net %+.2f log-loss units\n",
            sum(D$d < -1e-9), sum(abs(D$d) <= 1e-9), sum(D$d > 1e-9), sum(D$d)))

cat("\nXS2  THE MECHANICAL TEST. Seats bucketed by the probability the BASELINE\n")
cat("XS2  gave the eventual winner. If widening helps underdogs and hurts\n")
cat("XS2  favourites, net should be negative on the left and positive on the right.\n")
D[, band := cut(p_off, c(-.01, .02, .05, .10, .25, .50, .75, 1.01),
                labels = c("0-2%", "2-5%", "5-10%", "10-25%", "25-50%", "50-75%", "75-100%"))]
print(D[, .(seats = .N,
            mean_p_off = round(mean(p_off), 3),
            mean_p_on = round(mean(p_on), 3),
            net_logloss = round(sum(d), 2),
            per_seat = round(mean(d), 4)), by = band][order(band)])

cat("\nXS3  and the same split by whether a MAJOR or a non-major won the seat --\n")
cat("XS3  the SD model only widens IND/OTH/OTH_RIGHT/ONP, so it should do nothing\n")
cat("XS3  where a major won unopposed by any serious minor.\n")
D[, maj := actual %in% c("ALP", "LNP", "NAT")]
print(D[, .(seats = .N, net_logloss = round(sum(d), 2),
            per_seat = round(mean(d), 4),
            mean_p_off = round(mean(p_off), 3)), by = .(winner = ifelse(maj, "major", "non-major"))])

cat("\nXS4  BY PAIR, sorted by how much the SD model helped:\n")
print(D[, .(seats = .N, net = round(sum(d), 2), per_seat = round(mean(d), 4),
            base_ll = round(mean(ll_off), 3)), by = pair][order(net)])

cat("\nXS5  THE 12 SEATS IT HELPED MOST, and the 12 it hurt most.\n")
cat("XS5  p_off/p_on are the probability given to the actual winner.\n")
cat("-- helped --\n")
print(head(D[order(d), .(pair, seat, winner = actual, p_off = round(p_off, 3),
                         p_on = round(p_on, 3), gain = round(d, 2))], 12))
cat("-- hurt --\n")
print(head(D[order(-d), .(pair, seat, winner = actual, p_off = round(p_off, 3),
                          p_on = round(p_on, 3), cost = round(d, 2))], 12))

cat("\nXS6  IS THERE A RULE? net effect by (who won) x (baseline confidence).\n")
cat("XS6  A cell that is strongly negative is where widening should be ALLOWED;\n")
cat("XS6  strongly positive is where it should be suppressed.\n")
print(dcast(D[, .(net = round(sum(d), 1)), by = .(winner = ifelse(maj, "major", "non-major"), band)],
            winner ~ band, value.var = "net"))
fwrite(D[, .(pair, seat, actual, p_off, p_on, d)], file.path(OUT, "sd-model-seat-effects.csv"))
cat(sprintf("\nXS7  wrote %s/sd-model-seat-effects.csv\n", OUT))
