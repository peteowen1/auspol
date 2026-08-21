# If a party leads on first preferences, how often does it actually win the seat?
#
# WHY THIS NUMBER. Our Victorian forecast gives One Nation far fewer seats than
# YouGov's MRP. docs/reviews/vic-onp-primary-2026-08-21.md showed the primary
# gap is a date rather than a disagreement -- we and YouGov both had One Nation
# near 24 when they were in field. What remains is a difference in how a given
# primary vote converts into seats:
#
#   YouGov  leads in about 30 of 88, converts 17          -> about 57%
#   ours    at the same 24% primary, converts 8-9         -> about 45%
#
# Neither of us gets to assert that rate. SOUTH AUSTRALIA MEASURED IT. One
# Nation polled 22.9% there in March 2026, we hold every district's first
# preferences and the declared winners, and the conversion rate is a fact.
#
# Preferential voting is the whole reason the number is not 100%: leading on
# primaries with 30% against two majors who both preference against you is a
# losing position, and how often that happens is exactly what a seat model has
# to get right.
#
# Emits CR* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
fp <- fread(file.path(P, "ecsa-2026-sa-firstprefs.csv"), showProgress = FALSE)
win <- fread(file.path(P, "ecsa-sa-winners.csv"),
             showProgress = FALSE)[election == "sa2026", .(seat, winner)]

fp[, pct := 100 * votes / sum(votes), by = seat]
lead <- fp[, .SD[which.max(pct)], by = seat][, .(seat, leader = party, lead_pct = pct)]
d <- merge(lead, win, by = "seat")
stopifnot(nrow(d) == 47L)
d[, converted := leader == winner]

cat("\nCR1  South Australia 2026: who led on first preferences, and did they win?\n")
tab <- d[, .(led = .N, won = sum(converted)), by = leader][order(-led)]
tab[, rate := round(100 * won / led, 1)]
print(tab)
cat(sprintf("\nCR1  overall: %d of %d primary leads converted (%.1f%%)\n",
            sum(d$converted), nrow(d), 100 * mean(d$converted)))

onp <- tab[leader == "ONP"]
if (nrow(onp)) {
  cat(sprintf("\nCR2  ONE NATION: led on primaries in %d of 47 seats, won %d -> %.1f%%\n",
              onp$led, onp$won, onp$rate))
} else {
  cat("\nCR2  One Nation led on primaries in NO South Australian seat.\n")
}
cat("CR2  for comparison, on the SAME statistic:\n")
cat("CR2    YouGov's Victorian MRP: leads in ~30 of 88, converts 17 -> ~57%\n")
cat("CR2    ours at a 24% One Nation primary:            converts 8-9 -> ~45%\n")

# Where One Nation's leads went instead. The mechanism is the point: a party
# can lead on primaries in a third of the state and win almost nothing, and
# that is not the model being timid, it is preferential voting.
lost <- d[leader == "ONP" & !converted]
if (nrow(lost)) {
  cat(sprintf("\nCR3  the %d seats One Nation led and LOST, and who took them\n", nrow(lost)))
  print(lost[, .N, by = winner][order(-N)])
  cat(sprintf("CR3  its leads there averaged %.1f%% of the primary vote\n",
              mean(lost$lead_pct)))
}
won <- d[leader == "ONP" & converted]
if (nrow(won)) {
  cat(sprintf("CR3  the %d it led and WON averaged %.1f%%\n",
              nrow(won), mean(won$lead_pct)))
}

# How high does a One Nation primary have to be before the seat is safe?
cat("\nCR4  conversion by the size of One Nation's primary lead\n")
o <- d[leader == "ONP"]
if (nrow(o)) {
  o[, band := cut(lead_pct, breaks = c(0, 28, 32, 36, 100),
                  labels = c("under 28%", "28-32%", "32-36%", "36%+"))]
  print(o[, .(seats = .N, won = sum(converted),
              rate = round(100 * mean(converted))), by = band][order(band)])
  cat("CR4  a third of the vote is not a seat. That is the whole finding.\n")
}
fwrite(d, file.path("output", "sa2026-conversion.csv"))
