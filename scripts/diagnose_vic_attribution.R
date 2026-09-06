options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

polls <- load_polls("vic")
cycles <- load_election_cycles()
cp <- as.data.table(cycle_polls(polls, 2026, cycles))

cat("=== Victoria 2026 cycle: every poll, ALP / LNP / GRN / ONP ===\n")
print(cp[order(date), .(date, firm, ALP, LNP, GRN, ONP, OTH)])

cat("\n=== 2022 RESULT (the baseline the trend swings from) ===\n")
cat("ALP 36.66   LNP 34.48   GRN 11.50   ONP ~0.2\n")

cat("\n=== poll averages by period ===\n")
cp[, period := cut(date, breaks = as.Date(c("2023-01-01","2025-01-01",
                                            "2025-12-01","2026-04-01","2026-12-31")),
                   labels = c("2023-24","2025","early 2026","recent"))]
print(cp[, .(polls = .N,
             ALP = round(mean(ALP, na.rm=TRUE),1),
             LNP = round(mean(LNP, na.rm=TRUE),1),
             GRN = round(mean(GRN, na.rm=TRUE),1),
             ONP = round(mean(ONP, na.rm=TRUE),1)), by = period][order(period)])

cat("\n=== THE QUESTION: among polls that NAME One Nation, who is lower? ===\n")
has <- cp[!is.na(ONP)]
non <- cp[is.na(ONP)]
cat(sprintf("polls naming ONP: %d (%s to %s)\n", nrow(has), min(has$date), max(has$date)))
cat(sprintf("polls not naming ONP: %d (%s to %s)\n", nrow(non), min(non$date), max(non$date)))
cat(sprintf("\n  ONP-naming polls   : ALP %.1f  LNP %.1f  ONP %.1f\n",
            mean(has$ALP,na.rm=TRUE), mean(has$LNP,na.rm=TRUE), mean(has$ONP,na.rm=TRUE)))
cat(sprintf("  non-naming polls   : ALP %.1f  LNP %.1f\n",
            mean(non$ALP,na.rm=TRUE), mean(non$LNP,na.rm=TRUE)))
cat("  (a crude but direct read: where ONP is offered, whose number is lower?)\n")

cat("\n=== within ONP-naming polls: correlation of ONP with ALP and LNP ===\n")
if (nrow(has) >= 6) {
  cat(sprintf("  cor(ONP, ALP) = %+.3f\n", cor(has$ONP, has$ALP, use="complete.obs")))
  cat(sprintf("  cor(ONP, LNP) = %+.3f\n", cor(has$ONP, has$LNP, use="complete.obs")))
  cat("  (contaminated by house effects and the sum-to-100 constraint; read as a hint)\n")
}

cat("\n=== change from the 2022 RESULT to the most recent polls ===\n")
recent <- cp[date >= max(cp$date) - 90]
cat(sprintf("recent window: %d polls from %s\n", nrow(recent), min(recent$date)))
base <- c(ALP = 36.66, LNP = 34.48, GRN = 11.50, ONP = 0.2)
for (p in names(base)) {
  now <- mean(recent[[p]], na.rm = TRUE)
  if (is.finite(now)) cat(sprintf("  %-4s 2022 %5.2f -> polls %5.1f   change %+6.1f\n",
                                  p, base[[p]], now, now - base[[p]]))
}

cat("\n=== what the MODEL fits, for comparison ===\n")
cat("  ALP 25.3  LNP 29.3  GRN 13.0  ONP 20.7\n")
cat("  i.e. ALP -11.4, LNP -5.2, ONP +20.5\n")
cat("\n=== SA 2026 actual, for reference ===\n")
cat("  ONP +20, LNP -17, ALP -2.5\n")
