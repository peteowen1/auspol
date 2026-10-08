# One Nation's SENATE vote by state district, and the curve that turns it into
# a state One Nation vote -- the input to AUSPOL_ONP_ORDER = "senate".
#
# Why (Pete, 2026-10-01, from his own chart): a district's One Nation vote at
# the 2026 SA state election tracks its 2025 Senate One Nation vote closely
# (r 0.92, concave). One Nation is on every Senate ballot, so the Senate gives
# a clean geography where the House vote only exists where it fielded a
# candidate. Out of sample, leave-one-election-out over SA 2026, Qld 2017,
# 2020, 2024 and NSW 2023 (11 methods): the log curve from the most
# One-Nation-heavy earlier election, applied to the Senate share and scaled to
# the statewide level, was best at a Victoria-like level -- RMSE 3.25 points on
# SA 2026 + Qld 2017 against 5.28 for the House-rank rule it replaces (which
# was worse than uniform on Qld 2017). The curve extrapolates upward well (Qld
# 2017 Senate reached 26.4%); below the fit's lowest Senate share it is floored.
#
# Reads the AEC's Senate first preferences by polling place (external/reference/
# aec/booths/senate/fed<year>-<STATE>-*.csv, downloaded raw) and the booth ->
# district map (external/elections/fed-booth-map.csv, plus
# external/reference/correspondences/booths-2017qld.csv).
#
# Writes:
#   output/senate-onp-by-district.csv -- region, cycle, fed, district, senate_pct
#     for every cycle with Senate booths on disk (also for the backtests).
#   output/onp-senate-vic2026.csv     -- seat, senate_pct, and the curve
#     (curve_a + curve_b * log(max(senate_pct, floor_pct))), its source election
#     and fit. Ships with the models; fit_seats_full.R reads it.
#
# Run from repo root: powershell.exe -Command 'Rscript scripts/build_onp_senate.R'
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

B <- file.path("external", "reference", "aec", "booths")
bm <- fread(election_data_path("fed-booth-map.csv"), showProgress = FALSE)
q17f <- file.path("external", "reference", "correspondences", "booths-2017qld.csv")
if (file.exists(q17f)) {
  q17 <- fread(q17f, showProgress = FALSE)
  bm <- rbind(bm, q17[, .(region = "qld", cycle = 2017L, fed = 2016L, district, place_id)], fill = TRUE)
}
CYCLES <- unique(bm[, .(region, cycle, fed)])
rows <- list()
for (i in seq_len(nrow(CYCLES))) {
  rg <- CYCLES$region[i]; cy <- CYCLES$cycle[i]; fy <- CYCLES$fed[i]
  files <- list.files(file.path(B, "senate"), pattern = sprintf("^fed%d-%s-.*csv$", fy, toupper(rg)), full.names = TRUE)
  if (!length(files)) next
  x <- rbindlist(lapply(files, fread, skip = 1, showProgress = FALSE), fill = TRUE)
  x[, onp := grepl("One Nation", PartyNm, ignore.case = TRUE)]
  b <- x[, .(onp = sum(OrdinaryVotes[onp]), tot = sum(OrdinaryVotes)), by = .(place_id = PollingPlaceID)]
  keep <- bm$region == rg & bm$cycle == cy & bm$fed == fy
  m <- merge(b, unique(bm[keep, .(district, place_id)]), by = "place_id")
  d <- m[, .(senate_pct = 100 * sum(onp) / sum(tot), votes = sum(tot)), by = district]
  cat(sprintf("BOS1  %s %d (fed %d): %d Senate booths, %d mapped, %d districts, Senate One Nation %.2f%%\n",
              rg, cy, fy, nrow(b), nrow(m), nrow(d), 100 * sum(m$onp) / sum(m$tot)))
  rows[[length(rows) + 1L]] <- d[, `:=`(region = rg, cycle = cy, fed = fy)]
}
S <- rbindlist(rows)
setcolorder(S, c("region", "cycle", "fed", "district", "senate_pct", "votes"))
fwrite(S, file.path("output", "senate-onp-by-district.csv"))

# ---- the curve: from the most One-Nation-heavy election before the target ----
cand <- fread(out_path("candidacies.csv"), showProgress = FALSE)
nm <- function(z) gsub("[^a-z]", "", tolower(z))
TARGET <- "vic2026"
fit_on <- c("sa2026", "qld2017", "qld2020", "qld2024", "nsw2023")
fit_on <- fit_on[elections_before(fit_on, TARGET)]
lev <- vapply(fit_on, function(e) { k <- cand$election == e & cand$party == "ONP"; mean(cand$pcv[k]) }, numeric(1))
src <- names(which.max(lev))
src_rg <- sub("[0-9]{4}$", "", src); src_cy <- as.integer(sub("^[a-z]+", "", src))
ks <- cand$election == src & cand$party == "ONP"
act <- cand[ks, .(actual = sum(pcv)), by = .(k = nm(seat))]
ss <- S[S$region == src_rg & S$cycle == src_cy, .(k = nm(district), senate_pct)]
J <- merge(act, ss, by = "k")
stopifnot(nrow(J) >= 20L)
f <- lm(actual ~ log(senate_pct), J)
cat(sprintf("BOS2  curve from %s (One Nation mean %.1f, the highest of %s): actual = %.3f + %.3f * log(senate), R2 %.3f, %d districts, Senate %.1f-%.1f\n",
            src, lev[src], paste(fit_on, collapse = ", "), coef(f)[1], coef(f)[2], summary(f)$r.squared, nrow(J), min(J$senate_pct), max(J$senate_pct)))
V <- S[S$region == "vic" & S$cycle == 2026, .(seat = district, senate_pct)]
stopifnot(nrow(V) == 88L)
V[, `:=`(curve_a = unname(coef(f)[1]), curve_b = unname(coef(f)[2]), floor_pct = min(J$senate_pct),
         source = src, n_fit = nrow(J), r2 = summary(f)$r.squared)]
fwrite(V, file.path("output", "onp-senate-vic2026.csv"))
cat(sprintf("BOS3  wrote output/onp-senate-vic2026.csv: 88 districts, Senate One Nation %.1f-%.1f\n", min(V$senate_pct), max(V$senate_pct)))
