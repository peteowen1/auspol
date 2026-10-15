# compare_seat_spread_sources.R
#
# Prints, WITHOUT running any harness, the seat-swing spread (`sd_within`, the
# number that becomes `seat_sd`) each backtest pair used before and after the
# 2026-10-16 leak fix (R/prev_seat_swing.R), and validates the derived swing
# against the anchor's own seat files where those are the right vintage.
#
#   Rscript scripts/compare_seat_spread_sources.R
#
# Writes nothing. Needs external/aus-polling-analyser and
# external/elections/archive.
#
# THE LEAK. Old behaviour (AUSPOL_SEAT_SPREAD_SRC=anchor): the harnesses read the
# anchor seat file for the target election, or a LATER one where none exists,
# and took `sd_within` of its `fPreviousTppSwing`. For the fallbacks that is a
# swing from after the target; for vic2022 and sa2018 it is the target's own
# result. New (derived): the seat swing AT the previous election, from our
# archived results.

options(width = 250)
suppressMessages({
  library(data.table)
  devtools::load_all(".", quiet = TRUE)
})

# pairs[[region]]: to-year, from-year. Mirrors each harness's pair list
# (nsw/sa/qld/vic/fed `*_PAIRS` / `PAIRS`); keep in step if a pair is added.
pairs <- list(
  fed = list(to = c(2007, 2010, 2013, 2016, 2019, 2022, 2025), from = c(2004, 2007, 2010, 2013, 2016, 2019, 2022)),
  nsw = list(to = c(2011, 2015, 2019, 2023), from = c(2007, 2011, 2015, 2019)),
  sa  = list(to = c(2010, 2014, 2018, 2022, 2026), from = c(2006, 2010, 2014, 2018, 2022)),
  qld = list(to = c(2012, 2015, 2017, 2020, 2024), from = c(2009, 2012, 2015, 2017, 2020)),
  vic = list(to = c(2010, 2014, 2018, 2022), from = c(2006, 2010, 2014, 2018)))

anchor_spread <- function(year, region) {
  s <- tryCatch(as.data.table(load_seats(year, region)), error = function(e) NULL)
  if (is.null(s)) return(NULL)
  seat_swing_spread(s, 0)
}
anchor_years <- function(region) {
  root <- file.path(pkg_root(), "external", "aus-polling-analyser", "analysis", "seats")
  as.integer(substr(list.files(root, pattern = sprintf("^[0-9]{4}%s\\.txt$", region)), 1, 4))
}

# ---- (A) old vs new sd_within per pair -------------------------------------
# Old file choice, per harness (copied from the code this replaces):
#   nsw: TO file else 2023 | sa: TO file else 2022 | qld: TO file else 2024
#   vic: 2026 file for every pair | fed: TO file else median of every pair's file spread
old_file_year <- function(region, to) {
  have <- anchor_years(region)
  switch(region,
    nsw = if (to %in% have) to else 2023L,
    sa  = if (to %in% have) to else 2022L,
    qld = if (to %in% have) to else 2024L,
    vic = 2026L,
    fed = if (to %in% have) to else NA_integer_)
}
rows <- list()
for (r in names(pairs)) {
  fed_fb <- NA_real_
  if (r == "fed") {
    fed_fb <- stats::median(vapply(pairs$fed$to, function(y) {
      s <- anchor_spread(y, "fed"); if (is.null(s)) NA_real_ else s$sd_within }, numeric(1)), na.rm = TRUE)
  }
  for (i in seq_along(pairs[[r]]$to)) {
    to <- pairs[[r]]$to[i]; from <- pairs[[r]]$from[i]
    fy <- old_file_year(r, to)
    old <- if (is.na(fy)) fed_fb else anchor_spread(fy, r)$sd_within
    old_src <- if (is.na(fy)) "median of 2019/22/25 files" else sprintf("%d%s.txt", fy, r)
    nw <- derived_seat_spread(r, from, 0, label_year = to)
    rows[[length(rows) + 1L]] <- data.table(
      harness = r, pair_to = to, old_file = old_src,
      sd_within_old = round(old, 2), new_src = nw$src, n_seats = nw$n_swing,
      n_used = nw$n, sd_within_new = round(nw$sd_within, 2))
  }
}
A <- rbindlist(rows)
# A file for the target election itself carries the swing at the election BEFORE
# it (the right vintage); only a file for a LATER election, or none, is a leak.
A[, old_leaks := fcase(old_file == "median of 2019/22/25 files", TRUE,
                       suppressWarnings(as.integer(substr(old_file, 1, 4))) > pair_to, TRUE,
                       default = FALSE)]
A[, ratio_new_over_old := round(sd_within_new / sd_within_old, 2)]
cat("\n(A) sd_within per backtest pair: OLD (anchor seat file) vs NEW (derived from our results at the previous election)\n")
cat("    sd_within = within-region SD of per-seat prev swing, points; becomes seat_sd. old_leaks = old file is for a LATER election than the target.\n\n")
print(A, row.names = FALSE)

# ---- (B) validation where an anchor file IS the right vintage ---------------
# File for year Y has prev_swing = the swing at the election before Y, so it
# should match prev_seat_swing(region, P) where P is that election.
val <- list(c("nsw", 2019, 2015), c("nsw", 2023, 2019), c("sa", 2022, 2018), c("sa", 2026, 2022),
            c("qld", 2024, 2020), c("vic", 2022, 2018), c("vic", 2026, 2022),
            c("fed", 2019, 2016), c("fed", 2022, 2019), c("fed", 2025, 2022))
vrows <- lapply(val, function(v) {
  r <- v[1]; Y <- as.integer(v[2]); P <- as.integer(v[3])
  an <- as.data.table(load_seats(Y, r))
  dv <- prev_seat_swing(r, P, label_year = Y)
  an$k <- .seat_key(an$seat); dv$k <- .seat_key(dv$seat)
  m <- merge(an[is.finite(prev_swing), .(k, seat_region, prev_swing)], dv[, .(k, derived = prev_swing)], by = "k")
  m <- m[!is.na(seat_region)]
  an_all <- seat_swing_spread(an, 0)$sd_within
  an_same <- seat_swing_spread(data.frame(seat_region = m$seat_region, prev_swing = m$prev_swing), 0)$sd_within
  dv_same <- seat_swing_spread(data.frame(seat_region = m$seat_region, prev_swing = m$derived), 0)$sd_within
  dv_all <- derived_seat_spread(r, P, 0, label_year = Y)$sd_within
  data.table(file = sprintf("%d%s", Y, r), derived_from = sprintf("%d%s-tcp", P, r),
             n_anchor_seats = nrow(an), n_matched = nrow(m),
             corr = round(cor(m$prev_swing, m$derived), 3),
             mean_abs_diff = round(mean(abs(m$prev_swing - m$derived)), 2),
             sd_within_anchor_all = round(an_all, 2), sd_within_anchor_matched = round(an_same, 2),
             sd_within_derived_matched = round(dv_same, 2), sd_within_derived_all = round(dv_all, 2),
             pct_diff_matched = round(100 * (dv_same / an_same - 1), 1))
})
V <- rbindlist(vrows)
cat("\n(B) Validation: derived seat swing vs anchor fPreviousTppSwing, right-vintage files only\n")
cat("    corr = per-seat correlation over matched labelled seats (want >= 0.9); pct_diff_matched = derived vs anchor sd_within on the SAME seats (want within 15%).\n\n")
print(V, row.names = FALSE)
