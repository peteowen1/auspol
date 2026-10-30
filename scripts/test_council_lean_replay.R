# Does the upper-house booth lean fix the projection for a party new to a seat? Tested on the vic2022 replay by making
# one class "new" at a time: its 2018 lower-house booth votes are deleted, so the night model has to project it
# either from its counted share (today's rule) or from its 2018 upper-house booth lean (night_council_lean()).
# The real 2018 lower-house history is scored too, as the best case.
#   Rscript scripts/test_council_lean_replay.R
# Scores the RAW booth projection of the class's final seat share (before the afternoon prior is blended in), at
# several fractions of the night count, against the declared result. RMSE in points over seats, lower is better.
suppressPackageStartupMessages(library(data.table))
devtools::load_all(".", quiet = TRUE)
L <- fread("output/booths-vic2022.csv"); R <- fread("output/booths-vic2018.csv")
lean <- night_council_lean(fread("output/council-fp-2018.csv", showProgress = FALSE))
cat(sprintf("LEAN1 2018 upper-house lean: %d districts, %d units, classes %s\n", uniqueN(lean$district), uniqueN(paste(lean$district, lean$unit)),
            paste(sort(unique(lean$cls)), collapse = " ")))
prep <- function(X) { X <- as.data.table(X); X[is.na(votes), votes := 0]; X[, cls := classify_party(party)]
  X[, unit := ifelse(booth_type == "ordinary", booth, booth_type)]; X[, list(v = sum(votes)), by = c("district", "unit", "booth_type", "cls")] }
Lc <- prep(L)
final <- Lc[, .(v = sum(v)), by = .(district, cls)][, share := 100 * v / sum(v), by = district]
M <- match_booth_units(Lc, prep(R))
Mm <- M[, .(live_district = district, live_unit = unit, ref_district, ref_unit)]
Lk <- merge(lean, Mm, by.x = c("district", "unit"), by.y = c("ref_district", "ref_unit"))[, .(district = live_district, unit = live_unit, cls, share)]
cat(sprintf("LEAN2 lean mapped onto %d of %d 2022 lower-house units\n", uniqueN(paste(Lk$district, Lk$unit)), uniqueN(paste(Lc$district, Lc$unit))))
seats <- intersect(unique(Lc$district), unique(Lk$district))
# the report order the replay uses: night_booth_update() at each fraction, read back its counted units
sh0 <- matrix(10, length(seats), 1, dimnames = list(seats, "ALP"))
fracs <- c(0.05, 0.1, 0.25, 0.5)
res <- list()
for (fr in fracs) {
  nu <- night_booth_update(sh0, sh0 * 0 + 5, fr, L, R, gap_k = NULL, early = "interleaved")
  for (X in c("GRN", "ALP", "LNP", "OTH_RIGHT")) {
    Rx <- prep(R)[cls != X]
    Rk <- merge(Rx, M, by.x = c("district", "unit"), by.y = c("ref_district", "ref_unit"), suffixes = c(".ref", ".live"))
    Rk <- Rk[, .(district = district.live, unit = unit.live, booth_type = booth_type.live, cls, v)]
    Rfull <- merge(prep(R), M, by.x = c("district", "unit"), by.y = c("ref_district", "ref_unit"), suffixes = c(".ref", ".live"))
    Rfull <- Rfull[, .(district = district.live, unit = unit.live, booth_type = booth_type.live, cls, v)]
    for (s in seats) {
      u <- nu$units[[s]]; if (!length(u)) next
      ld <- Lc[district == s]; act <- final[district == s & cls == X]$share; if (!length(act)) next
      got <- function(p) { if (is.null(p) || !nrow(p)) return(NA_real_); 100 * sum(p[cls == X]$projected) / sum(p$projected) }
      cnt <- ld[unit %in% u]; counted_share <- 100 * sum(cnt[cls == X]$v) / sum(cnt$v)
      res[[length(res) + 1]] <- data.table(frac = fr, cls = X, seat = s, actual = act, counted_now = counted_share,
        today = got(project_seat_from_booths(ld, Rk[district == s], u)),
        lean = got(project_seat_from_booths(ld, Rk[district == s], u, lean = Lk[district == s])),
        best = got(project_seat_from_booths(ld, Rfull[district == s], u)))
    }
  }
}
D <- rbindlist(res)
cat(sprintf("LEAN3 %d seat x class x fraction rows; seats %d\n", nrow(D), uniqueN(D$seat)))
rm <- function(e) sqrt(mean(e^2, na.rm = TRUE))
S <- D[, .(n = sum(!is.na(today) & !is.na(lean)), today = rm(today - actual), lean = rm(lean - actual), best = rm(best - actual),
           lean_better_in = sum(abs(lean - actual) < abs(today - actual), na.rm = TRUE)), by = .(cls, frac)]
cat("\nLEAN4 RMSE of the projected final seat share, points (lower is better): today's rule vs upper-house lean vs real 2018 lower-house history\n")
print(S[order(cls, frac)], digits = 3)
cat("\nLEAN5 pooled over classes and fractions:\n")
print(D[, .(n = .N, today = rm(today - actual), lean = rm(lean - actual), best = rm(best - actual))], digits = 3)
fwrite(S, "docs/reviews/council-lean-replay-2026-10-30.csv")
