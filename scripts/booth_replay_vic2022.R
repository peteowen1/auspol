# DRESS REHEARSAL, PROJECTION LAYER ONLY: replay Victoria 2022 booth by booth
# and ask how well the seat's FINAL first preferences and winner can be
# projected from the booths counted so far, with NO forecast prior.
# (docs/plans/election-night-booth-model.md; the prior/posterior combination
# and the chamber aggregation come next.)
#
# The 2022 files carry no report order, so an order is simulated: ordinary
# booths in ascending size with jitter (small rural booths report first),
# then the declaration types in the order VEC counted them on the night
# (early, postal); absent, provisional and marked-as-voted votes are NOT
# counted on the night and are projected throughout.
#
# Projection for a party in a seat at a given moment:
#   projected_final = counted votes
#                   + for each uncounted unit: its 2022-matched vote
#                     + (its 2022 total x the seat's counted swing for that
#                        party, pooled by booth type when that type has any
#                        counted units, else the seat's all-type swing)
# In a replay the "2022-matched" reference IS the 2022 result, so the
# projection error measures only what the ordering and the type-mixture do.
# That is deliberate: it is the correctness check the plan requires
# (at 100% counted the projection must equal the final in every seat), and
# it sizes the type-mixture problem (early votes lean differently from
# ordinary votes) before any prior is layered on.
#
# For the real thing the reference booth result is 2022's and the counted
# swing is against it; the code path is identical with `ref` = 2022 and
# `live` = tonight, which is why this is written as a function of two tables.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
FP <- fread("output/booths-vic2022.csv", showProgress = FALSE)
stopifnot(nrow(FP) > 10000, uniqueN(FP$district) >= 80)
FP[is.na(votes), votes := 0L]
# one "unit" = one ordinary booth, or one declaration type
FP[, unit := ifelse(booth_type == "ordinary", booth, booth_type)]
night_types <- c("ordinary", "early", "postal")

# ---- the projection ------------------------------------------------------
# ref: reference results per (district, unit, booth_type, party): votes_ref
# live: same keys, votes_live for counted units only
project_seat <- function(ref, live) {
  # ref and live for ONE district. Returns projected final votes per party.
  cnt <- merge(ref, live, by = c("unit", "booth_type", "party"), all.x = TRUE)
  cnt[, counted := !is.na(votes_live)]
  if (!any(cnt$counted)) return(cnt[, .(party, projected = votes_ref, counted_share = 0)])
  # swing per party, pooled by type where that type has counted units, else all types
  tot_type <- cnt[counted == TRUE, .(ref = sum(votes_ref), live = sum(votes_live)), by = .(booth_type, party)]
  tot_all  <- cnt[counted == TRUE, .(ref = sum(votes_ref), live = sum(votes_live)), by = party]
  ref_t <- cnt[counted == TRUE, .(nref = sum(votes_ref)), by = booth_type]
  ref_a <- sum(cnt[counted == TRUE]$votes_ref)
  sw_type <- merge(tot_type, ref_t, by = "booth_type")[, swing := live / pmax(nref, 1) - ref / pmax(nref, 1)]
  sw_all  <- tot_all[, swing := live / ref_a - ref / ref_a]
  unc <- cnt[counted == FALSE]
  unc <- merge(unc, sw_type[, .(booth_type, party, swing_t = swing)], by = c("booth_type", "party"), all.x = TRUE)
  unc <- merge(unc, sw_all[, .(party, swing_a = swing)], by = "party", all.x = TRUE)
  unc[, swing := fifelse(is.na(swing_t), swing_a, swing_t)]
  unc[, unit_total := sum(votes_ref), by = unit]
  unc[, proj := pmax(0, votes_ref + swing * unit_total)]
  out <- rbind(cnt[counted == TRUE, .(party, v = votes_live)], unc[, .(party, v = proj)])[, .(projected = sum(v)), by = party]
  out[, counted_share := sum(cnt[counted == TRUE]$votes_ref) / sum(cnt$votes_ref)]
  out[]
}

# ---- the replay ----------------------------------------------------------
set.seed(2022)
ref <- FP[, .(votes_ref = sum(votes)), by = .(district, unit, booth_type, party)]
final <- ref[, .(final = sum(votes_ref)), by = .(district, party)]
final[, share_final := 100 * final / sum(final), by = district]
winner_fp <- final[, .SD[which.max(final)], by = district][, .(district, top_final = party)]
# report order per district: ordinary booths by jittered size, then early, then postal
ord <- ref[booth_type == "ordinary", .(size = sum(votes_ref)), by = .(district, unit)]
ord[, key := log(size + 1) + rnorm(.N, 0, 0.5)]
ord <- ord[order(district, key)]
ord[, pos := seq_len(.N) / .N, by = district]
seq_units <- rbind(ord[, .(district, unit, pos)],
                   ref[booth_type == "early", .(district, unit, pos = 1.5)][!duplicated(paste(district, unit))],
                   ref[booth_type == "postal", .(district, unit, pos = 2.0)][!duplicated(paste(district, unit))])
# counted fractions to score at: as a share of the NIGHT-COUNTABLE vote
night_total <- ref[booth_type %in% night_types, .(nt = sum(votes_ref)), by = district]
res <- list()
for (frac in c(0.10, 0.25, 0.50, 0.75, 1.00)) {
  rows <- list()
  for (d in unique(ref$district)) {
    su <- seq_units[district == d][order(pos)]
    rd <- ref[district == d]
    su <- merge(su, rd[, .(uv = sum(votes_ref)), by = unit], by = "unit")[order(pos)]
    su[, cum := cumsum(uv) / night_total[district == d]$nt]
    counted_units <- su[cum <= frac + 1e-9]$unit
    if (frac >= 1) counted_units <- su$unit
    live <- rd[unit %in% counted_units, .(unit, booth_type, party, votes_live = votes_ref)]
    p <- project_seat(rd[, .(unit, booth_type, party, votes_ref)], live)
    p[, district := d]; rows[[d]] <- p
  }
  P <- rbindlist(rows)
  P[, share_proj := 100 * projected / sum(projected), by = district]
  P <- merge(P, final, by = c("district", "party"))
  top <- P[, .SD[which.max(projected)], by = district][, .(district, top_proj = party, counted_share = counted_share)]
  top <- merge(top, winner_fp, by = "district")
  err <- P[, .(mae = mean(abs(share_proj - share_final)), rmse = sqrt(mean((share_proj - share_final)^2)))]
  res[[as.character(frac)]] <- data.table(frac_of_night_vote = frac, mean_counted_share_of_all = round(mean(top$counted_share), 3),
    fp_leader_correct = sum(top$top_proj == top$top_final), n = nrow(top),
    primary_mae = round(err$mae, 3), primary_rmse = round(err$rmse, 3))
  if (frac >= 1) {
    exact <- P[, all(abs(projected - final) < 0.5)]
    cat(sprintf("BR2  at 100%%: projection equals the final count in every seat and party: %s\n", exact))
    if (!exact) print(P[abs(projected - final) >= 0.5][1:5])
  }
}
R <- rbindlist(res)
cat("BR1  replay of vic2022, projection layer only (no prior). frac = share of the night-countable vote\n")
cat("     (ordinary + early + postal) counted; primary error is on the party's final share, points, lower is better\n")
print(R)
fwrite(R, "output/booth-replay-vic2022.csv")
cat("BR3  wrote output/booth-replay-vic2022.csv\n")
