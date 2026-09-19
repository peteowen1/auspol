# DRESS REHEARSAL 1, PROJECTION LAYER: replay Victoria 2022 booth by booth
# with the 2018 booth results as the reference, and ask how well each seat's
# FINAL 2022 first preferences and first-preference leader can be projected
# from the booths counted so far. No forecast prior yet
# (docs/plans/election-night-booth-model.md); the prior/posterior combination
# and the chamber aggregation come next.
#
# Why 2018 as the reference and not 2022 itself: with 2022 as its own
# reference the counted swing is zero and the projection is exact by
# construction (that identity is still asserted at 100% below, as the
# parser/matching correctness check). 2018 -> 2022 is HARDER than the real
# 2022 -> 2026 case because a redistribution sits between them, so booths
# are matched by name within the district first and by unique name
# statewide second; the real thing has no redistribution.
#
# Report order is simulated (the 2022 files carry none): ordinary booths in
# ascending size with jitter, then early votes, then postals. Absent,
# provisional and marked-as-voted votes are not counted on the night and are
# projected throughout.
#
# Projection for a party class in a seat at a given moment:
#   projected_final = counted 2022 votes
#     + for each uncounted 2022 unit with a 2018 match: its 2018 class share
#       x its 2018 total x (1 + growth), shifted by the seat's counted swing
#       (share-point change on matched counted units, pooled by booth type
#       when that type has counted units, else all types)
#     + for each uncounted unit with no match: the seat's counted share
#       applied to the unit's 2018 size proxy (the seat's mean matched unit)
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
L <- fread("output/booths-vic2022.csv", showProgress = FALSE)   # live (the night)
R <- fread("output/booths-vic2018.csv", showProgress = FALSE)   # reference
for (X in list(L, R)) { X[is.na(votes), votes := 0L]; X[, cls := classify_party(party)]; X[, unit := ifelse(booth_type == "ordinary", booth, booth_type)] }
cat(sprintf("BR0  live 2022: %d districts, %d ordinary booths; reference 2018: %d districts, %d ordinary booths\n",
            uniqueN(L$district), uniqueN(L[booth_type == "ordinary", .(district, booth)]),
            uniqueN(R$district), uniqueN(R[booth_type == "ordinary", .(district, booth)])))
Lc <- L[, .(v = sum(votes)), by = .(district, unit, booth_type, cls)]
Rc <- R[, .(v = sum(votes)), by = .(district, unit, booth_type, cls)]

# ---- matching 2022 units to 2018 units --------------------------------------
Lu <- unique(Lc[, .(district, unit, booth_type)]); Ru <- unique(Rc[, .(district, unit, booth_type)])
m1 <- merge(Lu, Ru[, .(district, unit, ref_district = district, ref_unit = unit)], by = c("district", "unit"))
Ru_ord <- Ru[booth_type == "ordinary"]; Ru_ord[, n := .N, by = unit]
uniq <- Ru_ord[n == 1, .(unit, ref_district2 = district, ref_unit2 = unit)]
rest <- Lu[!m1, on = c("district", "unit")][booth_type == "ordinary"]
m2 <- merge(rest, uniq, by = "unit")[, .(district, unit, booth_type, ref_district = ref_district2, ref_unit = ref_unit2)]
M <- rbind(m1[, .(district, unit, booth_type, ref_district, ref_unit)], m2)
lv <- Lc[, .(lv = sum(v)), by = .(district, unit)]
cov <- merge(lv, M[, .(district, unit, matched = TRUE)], by = c("district", "unit"), all.x = TRUE)
cat(sprintf("BR0  matched %d of %d 2022 units (%.1f%% of the 2022 vote): %d in-district by name, %d by unique name across the redistribution\n",
            nrow(M), nrow(Lu), 100 * sum(cov[matched == TRUE]$lv) / sum(cov$lv), nrow(m1), nrow(m2)))

# ---- the projection for one seat ------------------------------------------
project_seat <- function(live, ref, counted_units) {
  # live: 2022 rows of the seat (district, unit, booth_type, cls, v); ref: 2018 rows for matched units, re-keyed to 2022 unit names
  classes <- unique(live$cls)
  units <- unique(live[, .(unit, booth_type)])
  units[, counted := unit %in% counted_units]
  ref_tot <- ref[, .(rt = sum(v)), by = unit]
  live_tot <- live[, .(lt = sum(v)), by = unit]
  # swing per class on matched counted units, by type then all types
  mc <- merge(live[unit %in% counted_units], ref[, .(unit, cls, rv = v)], by = c("unit", "cls"))
  if (!nrow(mc)) return(NULL)
  mc <- merge(mc, ref_tot, by = "unit"); mc <- merge(mc, live_tot, by = "unit")
  sw_t <- mc[, .(sw = sum(v) / sum(lt) - sum(rv) / sum(rt)), by = .(booth_type, cls)]
  sw_a <- mc[, .(sw_all = sum(v) / sum(lt) - sum(rv) / sum(rt)), by = cls]
  growth <- sum(mc[, .(lt = lt[1]), by = unit]$lt) / sum(mc[, .(rt = rt[1]), by = unit]$rt)
  counted_share <- live[unit %in% counted_units, .(cs = sum(v) / sum(live$v))]$cs
  # uncounted units
  unc <- units[counted == FALSE]
  if (!nrow(unc)) return(live[, .(projected = sum(v)), by = cls][, counted_share := 1][])
  grid <- CJ(unit = unc$unit, cls = classes); grid <- merge(grid, unc, by = "unit")
  grid <- merge(grid, ref[, .(unit, cls, rv = v)], by = c("unit", "cls"), all.x = TRUE)
  grid <- merge(grid, ref_tot, by = "unit", all.x = TRUE)
  grid <- merge(grid, sw_t, by = c("booth_type", "cls"), all.x = TRUE); grid <- merge(grid, sw_a, by = "cls", all.x = TRUE)
  grid[is.na(sw), sw := sw_all]; grid[is.na(sw), sw := 0]
  grid[is.na(rv), rv := 0]
  has_ref <- grid$unit %in% ref_tot$unit
  mean_unit <- mean(ref_tot$rt)
  grid[, size := fifelse(has_ref, rt * growth, mean_unit * growth)]
  cs_seat <- live[unit %in% counted_units, .(sh = sum(v)), by = cls][, sh := sh / sum(sh)]
  grid <- merge(grid, cs_seat, by = "cls", all.x = TRUE); grid[is.na(sh), sh := 0]
  # a class with no 2018 presence anywhere in the seat (Richmond's Liberals stood in 2022, not 2018)
  # has no swing to apply: it takes the seat's counted share, like an unmatched unit
  ref_cls <- unique(ref$cls)
  grid[, proj := fifelse(has_ref & cls %in% ref_cls, pmax(0, (rv / pmax(rt, 1) + sw) * size), sh * size)]
  out <- rbind(live[unit %in% counted_units, .(v), by = cls], grid[, .(v = proj), by = cls])[, .(projected = sum(v)), by = cls]
  out[, counted_share := counted_share][]
}

# ---- the replay ------------------------------------------------------------
set.seed(2022)
final <- Lc[, .(final = sum(v)), by = .(district, cls)]; final[, share_final := 100 * final / sum(final), by = district]
lead_final <- final[, .SD[which.max(final)], by = district][, .(district, top_final = cls)]
ord <- Lc[booth_type == "ordinary", .(size = sum(v)), by = .(district, unit)]
ord[, key := log(size + 1) + rnorm(.N, 0, 0.5)]; ord <- ord[order(district, key)]; ord[, pos := seq_len(.N) / .N, by = district]
seq_units <- rbind(ord[, .(district, unit, pos)],
                   unique(Lc[booth_type == "early", .(district, unit, pos = 1.5)]),
                   unique(Lc[booth_type == "postal", .(district, unit, pos = 2.0)]))
night_total <- Lc[booth_type %in% c("ordinary", "early", "postal"), .(nt = sum(v)), by = district]
Rk <- merge(Rc, M, by.x = c("district", "unit"), by.y = c("ref_district", "ref_unit"), suffixes = c(".ref", ".live"))
Rk <- Rk[, .(district = district.live, unit = unit.live, booth_type = booth_type.live, cls, v)]
# ^ 2018 rows re-keyed to the 2022 district/unit they match
res <- list(); worst <- NULL
for (frac in c(0.10, 0.25, 0.50, 0.75, 1.00, 9)) {   # 9 = every unit incl. absent/provisional: the identity check
  rows <- list()
  for (d in unique(Lc$district)) {
    su <- seq_units[district == d][order(pos)]
    ld <- Lc[district == d]; rd <- Rk[district == d]
    su <- merge(su, ld[, .(uv = sum(v)), by = unit], by = "unit")[order(pos)]
    su[, cum := cumsum(uv) / night_total[district == d]$nt]
    counted <- if (frac >= 9) unique(ld$unit) else if (frac >= 1) su$unit else su[cum <= frac + 1e-9]$unit
    p <- project_seat(ld, rd, counted); if (is.null(p)) next
    p[, district := d]; rows[[d]] <- p
  }
  P <- rbindlist(rows); P[, share_proj := 100 * projected / sum(projected), by = district]
  P <- merge(P, final, by = c("district", "cls"), all = TRUE); P[is.na(share_proj), share_proj := 0]
  top <- merge(P[, .SD[which.max(share_proj)], by = district][, .(district, top_proj = cls, counted_share)], lead_final, by = "district")
  err <- P[cls %in% c("ALP", "LNP", "GRN"), .(mae = mean(abs(share_proj - share_final)), rmse = sqrt(mean((share_proj - share_final)^2)))]
  res[[as.character(frac)]] <- data.table(frac_of_night_vote = frac, mean_counted_share_of_all = round(mean(top$counted_share), 3),
    fp_leader_correct = sum(top$top_proj == top$top_final), n = nrow(top), major_share_mae = round(err$mae, 2), major_share_rmse = round(err$rmse, 2))
  if (frac == 0.5) worst <- P[cls %in% c("ALP", "LNP", "GRN")][order(-abs(share_proj - share_final))][1:8, .(district, cls, projected = round(share_proj, 1), final = round(share_final, 1))]
  if (frac >= 9) { cat(sprintf("BR2  with every unit counted: projection equals the final count in every seat and class: %s\n", P[, all(abs(projected - final) < 0.5)])); next }
}
Rt <- rbindlist(res)[frac_of_night_vote < 9]
cat("BR1  replay of vic2022 with 2018 booths as the reference, projection layer only (no prior).\n")
cat("     frac = share of the night-countable vote (ordinary + early + postal) counted;\n")
cat("     major_share_* = error on ALP/LNP/GRN final first-preference share, points, lower is better\n")
print(Rt)
cat("BR4  worst projected major shares at 50% counted:\n"); print(worst)
fwrite(Rt, "output/booth-replay-vic2022.csv"); cat("BR3  wrote output/booth-replay-vic2022.csv\n")
