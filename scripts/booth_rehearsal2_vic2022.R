# DRESS REHEARSAL 2: the afternoon prior meets the booth projection.
# (docs/plans/election-night-booth-model.md.) Reference 2018 booths, live
# 2022 booths, and the PRIOR is the shipped vic2022 backtest's predicted
# primaries (output/shipped/backtest-vic-sharedetail-*.csv, pair vic2022,
# the same forecast recipe run as-at the day before the 2022 election), with
# the backtest's residual sd by class as the prior sd. On the night the
# prior is the afternoon forecast's per-seat primary mean and sd instead.
#
# Scored on the final ALP/LNP/GRN first-preference share (points, lower is
# better) and on the first-preference leader, at each counted fraction, for
# three estimators: prior alone, projection alone, posterior.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
L <- fread("output/booths-vic2022.csv", showProgress = FALSE); R <- fread("output/booths-vic2018.csv", showProgress = FALSE)
for (X in list(L, R)) { X[is.na(votes), votes := 0L]; X[, cls := classify_party(party)]; X[, unit := ifelse(booth_type == "ordinary", booth, booth_type)] }
Lc <- L[, .(v = sum(votes)), by = .(district, unit, booth_type, cls)]
Rc <- R[, .(v = sum(votes)), by = .(district, unit, booth_type, cls)]
M <- match_booth_units(Lc, Rc)
Rk <- merge(Rc, M, by.x = c("district", "unit"), by.y = c("ref_district", "ref_unit"), suffixes = c(".ref", ".live"))
Rk <- Rk[, .(district = district.live, unit = unit.live, booth_type = booth_type.live, cls, v)]

# ---- the prior -------------------------------------------------------------
sf <- list.files("output/shipped", pattern = "^backtest-vic-sharedetail-.*[.]csv$", full.names = TRUE)
stopifnot(length(sf) == 1)
S <- fread(sf, showProgress = FALSE)
PRI <- S[pair == "vic2022", .(district = seat, cls = party, prior = pred_share)]
sd_cls <- S[, .(sd_prior = sd(actual_share - pred_share)), by = .(cls = party)]
PRI <- merge(PRI, sd_cls, by = "cls")
cat(sprintf("BQ0  prior: vic2022 backtest primaries for %d seats (of %d with booths); prior sd by class: %s\n",
            uniqueN(PRI$district), uniqueN(Lc$district),
            paste(sprintf("%s %.2f", sd_cls$cls, sd_cls$sd_prior), collapse = ", ")))
final <- Lc[, .(final = sum(v)), by = .(district, cls)]; final[, share_final := 100 * final / sum(final), by = district]
lead_final <- final[, .SD[which.max(final)], by = district][, .(district, top_final = cls)]

# ---- report order (as rehearsal 1) ----------------------------------------
set.seed(2022)
ord <- Lc[booth_type == "ordinary", .(size = sum(v)), by = .(district, unit)]
ord[, key := log(size + 1) + rnorm(.N, 0, 0.5)]; ord <- ord[order(district, key)]; ord[, pos := seq_len(.N) / .N, by = district]
seq_units <- rbind(ord[, .(district, unit, pos)],
                   unique(Lc[booth_type == "early", .(district, unit, pos = 1.5)]),
                   unique(Lc[booth_type == "postal", .(district, unit, pos = 2.0)]))
night_total <- Lc[booth_type %in% c("ordinary", "early", "postal"), .(nt = sum(v)), by = district]

score <- function(P, col) {
  P <- P[district %in% PRI$district]     # only seats with a prior, so the three estimators compare on the same seats
  top <- merge(P[, .SD[which.max(get(col))], by = district][, .(district, top = cls)], lead_final, by = "district")
  e <- P[cls %in% c("ALP", "LNP", "GRN")]
  list(leader = sum(top$top == top$top_final), n = nrow(top),
       mae = mean(abs(e[[col]] - e$share_final)), rmse = sqrt(mean((e[[col]] - e$share_final)^2)))
}
res <- list()
for (frac in c(0.0, 0.10, 0.25, 0.50, 1.00)) {
  rows <- list()
  for (d in unique(Lc$district)) {
    su <- seq_units[district == d][order(pos)]
    ld <- Lc[district == d]; rd <- Rk[district == d]
    su <- merge(su, ld[, .(uv = sum(v)), by = unit], by = "unit")[order(pos)]
    su[, cum := cumsum(uv) / night_total[district == d]$nt]
    counted <- if (frac >= 1) su$unit else su[cum <= frac + 1e-9]$unit
    p <- if (length(counted)) project_seat_from_booths(ld, rd, counted) else NULL
    if (is.null(p)) p <- data.table(cls = unique(ld$cls), projected = NA_real_, counted_share = 0)
    p[, district := d]; rows[[d]] <- p
  }
  P <- rbindlist(rows); P[, share_proj := 100 * projected / sum(projected), by = district]
  P <- merge(P, final, by = c("district", "cls"), all = TRUE)
  P <- merge(P, PRI, by = c("district", "cls"), all.x = TRUE)
  P[is.na(prior), prior := 0]; P[is.na(sd_prior), sd_prior := 5]
  P[, sd_proj := booth_projection_sd(counted_share)]
  P[, post := fifelse(is.na(share_proj), prior, combine_prior_projection(prior, share_proj, sd_prior, sd_proj)$mean)]
  P[is.na(share_proj), share_proj := prior]
  for (col in c("prior", "share_proj", "post")) {
    s <- score(P, col)
    res[[length(res) + 1]] <- data.table(frac_of_night_vote = frac, estimator = c(prior = "prior alone", share_proj = "projection alone", post = "posterior")[[col]],
      leader_correct = s$leader, n = s$n, major_mae = round(s$mae, 2), major_rmse = round(s$rmse, 2))
  }
}
Rt <- rbindlist(res)
cat("BQ1  rehearsal 2 (vic2022, reference 2018, prior = shipped vic2022 backtest). Error on the final ALP/LNP/GRN share,\n")
cat("     points, lower is better; leader = first-preference leader called correctly, of the seats with a prior\n")
print(dcast(Rt, frac_of_night_vote ~ estimator, value.var = c("leader_correct", "major_mae")))
fwrite(Rt, "output/booth-rehearsal2-vic2022.csv"); cat("BQ2  wrote output/booth-rehearsal2-vic2022.csv\n")
