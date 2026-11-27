# The seats named in advance for docs/plans/prereg-night-lane-b-2026-11-27.md: per night, seats whose final two has
# a SAME-CLASS candidate beside a finalist (another candidate of a finalist's class on 3%+ of the seat's first
# preferences) or THREE+ candidates of consequence (the third-placed candidate on 15%+). From the final booth tables
# (output/booths-<night>.csv, candidate-level) and the declared pair (output/booths/<night>-booth-tcp.csv).
#   Rscript scripts/night_lane_b_seats.R      writes output-free: prints NLB1 lines and the lists
suppressMessages({ library(data.table); devtools::load_all(Sys.getenv("AUSPOL_CODE_DIR", "."), quiet = TRUE) })
for (el in c("vic2022", "fed2022", "fed2025")) {
  B <- fread(sprintf("output/booths-%s.csv", el), showProgress = FALSE)
  Tc <- fread(sprintf("output/booths/%s-booth-tcp.csv", el), showProgress = FALSE)
  B <- B[!is.na(B$votes) & !is.na(B$candidate) & nzchar(B$candidate)]
  cv <- B[, list(v = sum(votes)), by = list(seat = district, candidate, party)]
  cv[, cls := classify_party(party)]
  cv[, pct := 100 * v / sum(v), by = seat]
  fin <- unique(Tc[, list(seat = district, candidate, cls = classify_party(party_raw))])
  fin_key <- paste(fin$seat, toupper(trimws(fin$candidate)))
  cv[, finalist := paste(seat, toupper(trimws(candidate))) %in% fin_key]
  fcls <- fin[, list(fc = paste(sort(unique(cls)), collapse = "|")), by = seat]
  cv <- merge(cv, fcls, by = "seat")
  same <- cv[!cv$finalist & mapply(function(k, f) k %in% strsplit(f, "|", fixed = TRUE)[[1]], cv$cls, cv$fc) & cv$pct >= 3, unique(seat)]
  third <- cv[order(seat, -pct)][, list(p3 = pct[3]), by = seat][p3 >= 15, seat]
  named <- sort(union(same, third))
  cat(sprintf("NLB1 %s: %d seats with a declared pair; %d same-class, %d with a third candidate on 15%%+, %d named\n",
              el, uniqueN(fin$seat), length(same), length(third), length(named)))
  cat(sprintf("NLB2 %s named: %s\n", el, paste(named, collapse = ", ")))
}
