# Closes the last gap in aef7-final-two-and-tcp-reference.csv: vic2022's 78
# seats had no equivalent to the NSWEC/ECQ/WAEC archives used by
# build_aef7_tcp_official.R (no VEC distribution-of-preferences archive is on
# disk for 2022), so they stayed fsrc="derived"/"aef-cache" -- never checked
# against a real declared result.
#
# Cross-checking all 7 AEF7 pairs against scripts/fetch_abc_seat_guides.R's
# scrape (2026-09-18) found vic2022's mean |official - ABC| TCP gap is 0.49
# points, an order of magnitude worse than every commission-sourced pair
# (fed2022 0.000, fed2025 0.000, nsw2023 0.008, qld2024 0.005, wa2025 0.012)
# -- exactly what "never verified" should look like next to "verified".
# Worse: Bass had the WRONG WINNER (ours: LNP 52.8%, ABC: ALP 50.2%).
#
# ABC is a secondary source (not the VEC itself), but it is real per-seat
# declared data, independently scraped and already found accurate to <0.02
# points against three different primary sources (NSWEC/ECQ/WAEC) in this
# same session -- a materially better ground truth than a preference-flow
# reconstruction with no source at all. fsrc is set to "abc-scrape" rather
# than "official" so this provenance stays visible; replace with a real VEC
# fetch if that archive is ever built (see build_aef7_tcp_official.R's
# header for the pattern to follow).
#
# Emits VABC0-VABC3 log codes.

options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

OUT <- "output"
# na.strings: see build_aef7_tcp_official.R's note -- fwrite's default
# na="" makes a blank field indistinguishable from a real empty string on
# a plain fread(), which matters for the intra-coalition-excluded rows' NA
# f1/f2/f2cp.
ref <- fread(file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), na.strings = c("NA", ""), showProgress = FALSE)
tt <- fread(file.path(OUT, "aef7-tcp-truth-table.csv"), na.strings = c("NA", ""), showProgress = FALSE)

vic_abc <- tt[pair == "vic2022" & !is.na(abc_tcp_f1), .(pair, seat, f1 = abc_tcp_f1, f2 = abc_tcp_f2, f2cp = abc_tcp_pct)]
vic_abc[, fsrc := "abc-scrape"]

n_before <- ref[pair == "vic2022" & fsrc %in% c("derived", "aef-cache"), .N]
before_f1 <- ref[pair == "vic2022", .(pair, seat, f1_before = f1)]

ref[vic_abc, on = c("pair", "seat"), `:=`(f1 = i.f1, f2 = i.f2, f2cp = i.f2cp, fsrc = i.fsrc)]

n_after <- ref[pair == "vic2022" & fsrc %in% c("derived", "aef-cache"), .N]
changed_winner <- merge(before_f1, ref[pair == "vic2022", .(pair, seat, f1_after = f1)], by = c("pair","seat"))
changed_winner <- changed_winner[f1_before != f1_after]

cat(sprintf("VABC0 vic2022: %d seats resolved from ABC scrape\n", nrow(vic_abc)))
cat(sprintf("VABC1 vic2022 derived/aef-cache rows: %d before, %d after\n", n_before, n_after))
if (nrow(changed_winner)) {
  cat(sprintf("VABC2 winner changed for %d seat(s):\n", nrow(changed_winner)))
  print(changed_winner)
}
cat("VABC3 fsrc breakdown after merge:\n")
print(ref[, .N, by = .(pair, fsrc)][order(pair, fsrc)])

fwrite(ref, file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), na = "NA")
cat(sprintf("VABC4 wrote %s\n", file.path(OUT, "aef7-final-two-and-tcp-reference.csv")))
