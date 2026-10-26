# Federal HOUSE One Nation share by STATE district, for every state election the
# booth files and booth maps on disk can serve. Written for the ordering key of
# AUSPOL_ONP_NEWSEAT_RULE (R/onp_newseat.R, onp_federal_key()), which reads
# external/elections/federal-transposed-to-state.csv first (the live forecast's
# source: nsw, sa, vic) and this table for an election that file lacks (qld).
# docs/plans/prereg-onp-newseat-rule-2026-10-25.md.
#
# Same build as scripts/onp_order_loo.R's house_onp(): the AEC House booth file
# (external/reference/aec/booths/fed<year>-<STATE>.csv), ordinary votes, through
# the booth maps the Senate table uses (fed-booth-map.csv, plus the 2017
# Queensland correspondence). Every row keeps its vote counts so the share can be
# recomputed; a district where One Nation stood no House candidate has
# house_pct 0 (onp_federal_key() treats that as "no ordering information").
#
# WA and NT: no AEC House booth vote files on disk (only polling-place lists),
# so no rows -- recorded in docs/reviews/onp-newseat-parity-2026-10-25.md.
#
# Run: powershell.exe -Command 'Rscript scripts/build_onp_house.R [data_root] [out_csv]'
#   data_root defaults to "."; out_csv to <data_root>/output/house-onp-by-district.csv
args <- commandArgs(trailingOnly = TRUE)
ROOT <- if (length(args) >= 1) args[1] else "."
OUTF <- if (length(args) >= 2) args[2] else file.path(ROOT, "output", "house-onp-by-district.csv")
suppressMessages(devtools::load_all(".", quiet = TRUE))
options(auspol.root = normalizePath(ROOT))
suppressMessages(library(data.table))

bm <- fread(election_data_path("fed-booth-map.csv"), showProgress = FALSE, colClasses = list(character = "place_id"))
q17f <- file.path(ROOT, "external", "reference", "correspondences", "booths-2017qld.csv")
bm <- bm[, .(region, cycle, fed, district, place_id)]
if (file.exists(q17f)) {
  q17 <- fread(q17f, showProgress = FALSE, colClasses = list(character = "place_id"))
  bm <- rbind(bm, q17[, .(region = "qld", cycle = 2017L, fed = 2016L, district, place_id)])
}
combos <- unique(bm[, .(region, cycle, fed)])
cat(sprintf("OH0  %d (region, cycle, fed) combinations in the booth maps\n", nrow(combos)))

out <- rbindlist(lapply(seq_len(nrow(combos)), function(i) {
  rg <- combos$region[i]; cy <- combos$cycle[i]; fy <- combos$fed[i]
  f <- file.path(ROOT, "external", "reference", "aec", "booths", sprintf("fed%d-%s.csv", fy, toupper(rg)))
  if (!file.exists(f)) { cat(sprintf("OH1! %s%d: no House booth file %s -- skipped\n", rg, cy, basename(f))); return(NULL) }
  x <- fread(f, skip = 1, showProgress = FALSE, colClasses = list(character = "PollingPlaceID"))
  stopifnot(nrow(x) > 0, all(c("PollingPlaceID", "PartyNm", "OrdinaryVotes") %in% names(x)))
  x[, onp := grepl("One Nation", PartyNm, ignore.case = TRUE)]
  b <- x[, .(onp_votes = sum(OrdinaryVotes[onp]), votes = sum(OrdinaryVotes)), by = .(place_id = PollingPlaceID)]
  .rg <- rg; .cy <- cy; .fy <- fy                     # not column names inside [ ] (CLAUDE.md, data.table NSE)
  msk <- bm$region == .rg & bm$cycle == .cy & bm$fed == .fy
  m <- merge(b, unique(bm[msk, .(district, place_id)]), by = "place_id")
  d <- m[, .(onp_votes = sum(onp_votes), votes = sum(votes)), by = .(district)]
  d[, house_pct := 100 * onp_votes / votes]
  cat(sprintf("OH1  %s%d from fed%d: %d districts, %d with a One Nation House vote, mapped booths %d of %d\n",
              rg, cy, fy, nrow(d), sum(d$onp_votes > 0), uniqueN(m$place_id), nrow(b)))
  data.table(region = rg, cycle = cy, fed = fy, d[, .(district, house_pct, onp_votes, votes)])
}))
stopifnot(nrow(out) > 0, !anyNA(out$house_pct), !anyDuplicated(out[, .(region, cycle, normalise_seat(district))]))

# Anchor against the committed transposition where both have the cycle.
ftr <- fread(election_data_path("federal-transposed-to-state.csv"), showProgress = FALSE)
for (k in unique(paste0(out$region, out$cycle))) {
  rg <- sub("[0-9]{4}$", "", k); cy <- as.integer(sub("^[a-z]+", "", k))
  tr <- ftr[ftr$region == rg & ftr$cycle == cy & ftr$party == "ONP", .(kk = normalise_seat(seat), tr = pct)]
  if (!nrow(tr)) next
  o <- out[out$region == rg & out$cycle == cy, .(kk = normalise_seat(district), house_pct)]
  j <- merge(o, tr, by = "kk")
  if (nrow(j) >= 3)
    cat(sprintf("OH2  %s: build v federal-transposed-to-state.csv over %d seats: r %.4f, max abs diff %.2f\n",
                k, nrow(j), stats::cor(j$house_pct, j$tr), max(abs(j$house_pct - j$tr))))
}
fwrite(out, OUTF)
cat(sprintf("OH3  wrote %s: %d rows, %d elections\n", OUTF, nrow(out), uniqueN(paste0(out$region, out$cycle))))
