# Per-seat detail of an election-night replay, for the explainer page (https://claude.ai/artifact/WtspQifwBERFokMxrkAsn9):
# at each update, the counted primaries, the model's new primaries and sd, the VEC two-candidate count so far and the forecast
# two-candidate share, against the afternoon forecast and the declared result. Same steps as scripts/night_replay_json.R.
#   Rscript scripts/night_replay_detail.R <state.rds from AUSPOL_NIGHT_DUMP> <out.json> [live booths] [previous booths] [booth 2CP]
# Booth paths default to output/booths-<region><to>.csv, output/booths-<region><from>.csv and
# output/booths/<region><to>-booth-tcp.csv, the region taken from the state's pair label ("nsw2023" -> "nsw").
a <- commandArgs(trailingOnly = TRUE); if (length(a) < 2) stop("usage: night_replay_detail.R <state.rds> <out.json> [live] [prev] [tcp]")
devtools::load_all(".", quiet = TRUE)
suppressPackageStartupMessages(library(data.table))
st <- readRDS(a[1]); sims <- as.integer(st$n_sims)
region <- sub("[0-9]+$", "", if (is.null(st$pair)) "vic" else st$pair); pair <- sprintf("%s%d", region, st$to)
pth <- function(i, d) if (length(a) >= i && nzchar(a[i])) a[i] else d
L <- fread(pth(3, sprintf("output/booths-%s%d.csv", region, st$to))); R <- fread(pth(4, sprintf("output/booths-%s%d.csv", region, st$from)))
Tc <- fread(pth(5, sprintf("output/booths/%s%d-booth-tcp.csv", region, st$to)))
fracs <- c(0, 0.05, 0.1, 0.25, 0.5, 0.75, 1)
surge_fade <- identical(Sys.getenv("AUSPOL_NIGHT_SURGE_FADE", "0"), "1"); tcp_center <- Sys.getenv("AUSPOL_NIGHT_TCP_CENTER", "mean")
cat(sprintf("night fixes: surge-fade=%s tcp-center=%s\n", surge_fade, tcp_center))
clock <- function(f) { m <- round(18 * 60 + 240 * f); sprintf("%d:%02dpm", (m %/% 60) - 12, m %% 60) }
# counted primaries by unit, same unit rule as night_booth_update()
Lc <- copy(L)[is.na(votes), votes := 0][, cls := classify_party(party)][, unit := ifelse(booth_type == "ordinary", booth, booth_type)]
Lc <- Lc[, .(v = sum(votes)), by = .(district, unit, cls)]
Tk <- copy(Tc)[is.na(votes), votes := 0][, cls := ifelse(nzchar(trimws(party_raw)), classify_party(party_raw), "IND")]
Tk[, unit := ifelse(vote_type == "ordinary", booth, vote_type)]
Tk <- Tk[, .(v = sum(votes)), by = .(district, unit, cls)]
P <- fread("output/published-predictions.csv"); keep_pair <- P$pair == pair; P <- P[keep_pair]   # mask built OUTSIDE the brackets: inside P[...] `pair` is the column (NSE trap)
final_fp <- P[, .(seat, party, actual)]
final_tcp <- Tk[, .(v = sum(v)), by = .(district, cls)]
seats <- rownames(st$shares); cls_all <- colnames(st$shares)
snap <- list()
for (fr in fracs) {
  shares <- st$shares; sdo <- st$sdo; swd <- st$swd; nu <- NULL
  if (fr > 0) {
    nu <- night_booth_update(shares, night_prior_sd(shares, st$level_sd, st$level_mult, sdo), fr, L, R, gap_k = 5, early = "interleaved")
    shares <- nu$shares; sdo <- nu$sd; swd <- night_shrink_draws(swd, 1 - nu$resolved)
  }
  sh <- if (surge_fade && !is.null(nu)) night_surge_fade(st$surge_h, nu$counted, seats) else st$surge_h
  sim <- simulate_seat_contests(level_sd = st$level_sd, sd_override = sdo, level_mult = st$level_mult, shares, st$fm,
                                party_sd = st$psd, statewide_draws = swd, seat_sd = st$seat_sd, n_sims = sims,
                                breakout_p = st$bo$p, breakout_q = st$bo$q, coalition_split = st$coalition_split, error_q = st$error_q,
                                smooth = st$smooth, seed = st$seed, party_cor = st$party_cor, shrink = st$shrink,
                                conditional_override = st$htv_ov, conditional_override_sd = attr(st$htv_ov, "sd"),
                                fallback_smooth = st$fb_smooth, shrink_k = st$shrink_k, flow_sd = st$flow_sd,
                                surge_h = sh, surge_party = st$surge_party, surge_from_zero = st$surge_from_zero,
                                surge_mu = st$surge_mu, surge_sd = st$surge_sd)
  if (!is.null(nu)) { obs <- night_tcp_obs(Tc, L, nu$units, shares); sim <- night_apply_tcp(sim, obs, center = tcp_center) }
  wp <- as.data.table(sim$win_prob)
  tw <- sim$tcp_winner; tr <- sim$tcp_runnerup; ts <- sim$tcp_share
  if (max(ts, na.rm = TRUE) > 1.5) ts <- ts / 100
  for (s in seats) {
    pr <- paste(pmin(tw[, s], tr[, s]), pmax(tw[, s], tr[, s]), sep = "|"); top <- names(sort(table(pr), decreasing = TRUE))[1]
    ab <- strsplit(top, "|", fixed = TRUE)[[1]]; hit <- pr == top
    a_share <- ifelse(tw[hit, s] == ab[1], ts[hit, s], 1 - ts[hit, s])
    u <- if (!is.null(nu) && s %in% names(nu$units)) nu$units[[s]] else character()
    cnt <- Lc[district == s & unit %in% u, .(v = sum(v)), by = cls]
    tc <- Tk[district == s & unit %in% u & cls %in% ab, .(v = sum(v)), by = cls]
    snap[[length(snap) + 1]] <- list(seat = s, frac = fr, clock = clock(fr),
      counted_pct = if (is.null(nu)) 0 else round(100 * unname(nu$counted[s]), 1), booths = length(u),
      fc = setNames(as.list(round(shares[s, ], 2)), cls_all), sd = setNames(as.list(round(sdo[s, ], 2)), cls_all),
      counted = if (nrow(cnt) && sum(cnt$v) > 0) setNames(as.list(round(100 * cnt$v / sum(cnt$v), 2)), cnt$cls) else NULL,
      counted_votes = if (nrow(cnt)) sum(cnt$v) else 0,
      win = setNames(as.list(round(wp[seat == s]$prob, 3)), wp[seat == s]$party),
      pair = ab, p_pair = round(mean(hit), 3), tcp_a = round(100 * mean(a_share), 2),
      tcp_a_lo = round(100 * unname(quantile(a_share, 0.05)), 1), tcp_a_hi = round(100 * unname(quantile(a_share, 0.95)), 1),
      tcp_counted_a = if (nrow(tc) == 2 && sum(tc$v) > 0) round(100 * tc$v[tc$cls == ab[1]] / sum(tc$v), 2) else NULL,
      tcp_counted_votes = if (nrow(tc)) sum(tc$v) else 0)
  }
  cat(sprintf("frac %.2f done\n", fr))
}
fin <- lapply(seats, function(s) {
  fp <- final_fp[seat == s]; tt <- final_tcp[district == s][order(-v)]
  list(seat = s, fp = setNames(as.list(round(fp$actual, 2)), fp$party), winner = P[seat == s & won == TRUE]$party,
       tcp = if (nrow(tt) >= 2) setNames(as.list(round(100 * tt$v[1:2] / sum(tt$v[1:2]), 2)), tt$cls[1:2]) else NULL)
})
out <- list(seats = seats, classes = cls_all, snaps = snap, final = fin)
jsonlite::write_json(out, a[2], auto_unbox = TRUE, null = "null", digits = NA)
cat("wrote", file.size(a[2]), "bytes\n")
# checks: the same numbers as the published replay documents
b <- Filter(function(x) x$seat == "Bass" && x$frac == 0.25, snap)[[1]]
cat("Bass 25%: ALP fc", b$fc$ALP, "win ALP", b$win$ALP, "pair", b$pair, "tcp_a", b$tcp_a, "counted", b$counted_pct, "\n")
f <- Filter(function(x) x$seat == "Bass", fin)[[1]]; cat("Bass final tcp:", unlist(f$tcp), "winner", f$winner, "\n")
