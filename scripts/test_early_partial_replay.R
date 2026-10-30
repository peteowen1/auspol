# A partly counted early unit on the vic2022 replay: the main early voting centre in, the rest of the district's early
# vote not yet. 2022's lower-house file has early votes only as one block per district, so the split is APPROXIMATED
# from the 2022 upper-house count by voting centre: the main centre's share of the district's early vote (p_main),
# and its party mix relative to the whole early block, applied to the lower-house block.
#   Rscript scripts/test_early_partial_replay.R
# Scores the projected final NIGHT vote (ordinary + early + postal) per class against the actual, at several
# fractions of ordinary booths counted, three ways: TODAY (the partial early unit treated as complete), FIX-TRUE (told
# the true share of early counted, p_main) and FIX-EST (the runner's estimate: counted early / (actual night total x
# the seat's 2018 early share), i.e. a perfect turnout estimate but last election's early share).
suppressPackageStartupMessages(library(data.table))
devtools::load_all(".", quiet = TRUE)
L <- fread("output/booths-vic2022.csv"); R <- fread("output/booths-vic2018.csv")
prep <- function(X) { X <- as.data.table(X); X[is.na(votes), votes := 0]; X[, cls := classify_party(party)]
  X[, unit := ifelse(booth_type == "ordinary", booth, booth_type)]; X[, list(v = sum(votes)), by = c("district", "unit", "booth_type", "cls")] }
Lc <- prep(L)[booth_type %in% c("ordinary", "early", "postal")]
Rc <- prep(R)
M <- match_booth_units(Lc, Rc)
Rk <- merge(Rc, M, by.x = c("district", "unit"), by.y = c("ref_district", "ref_unit"), suffixes = c(".ref", ".live"))
Rk <- Rk[, .(district = district.live, unit = unit.live, booth_type = booth_type.live, cls, v)]
# upper-house 2022 early votes by centre: the main centre's share and its party mix relative to the district's early block
C <- fread("output/council-fp-2022.csv", showProgress = FALSE)
E <- C[block_kind == "voting_centre" & row_kind %in% c("group", "ungrouped") & vote_type == "early"]
E[, `:=`(d = sub(" District$", "", district), cls = ifelse(row_kind == "ungrouped", "IND", classify_party(group_name)), v = as.numeric(total))]
E <- E[is.finite(v), .(v = sum(v)), by = .(d, vc_name, cls)]
ct <- E[, .(cv = sum(v)), by = .(d, vc_name)]
main <- ct[ct[, .I[which.max(cv)], by = d]$V1]
pm <- merge(main[, .(d, vc_name, main_v = cv)], ct[, .(dist_v = sum(cv)), by = d], by = "d")[, p_main := main_v / dist_v]
mix <- merge(E[, .(m = sum(v[vc_name %in% main$vc_name[main$d == d[1]]])), by = .(d, cls)], E[, .(a = sum(v)), by = .(d, cls)], by = c("d", "cls"))
mix[, ratio := (m / sum(m)) / (a / sum(a)), by = d]; mix[!is.finite(ratio), ratio := 1]
cat(sprintf("EP1 main early centre's share of the district's early vote (2022 upper house): median %.0f%%, range %.0f-%.0f%% over %d districts\n",
            100 * median(pm$p_main), 100 * min(pm$p_main), 100 * max(pm$p_main), nrow(pm)))
truth <- Lc[, .(v = sum(v)), by = .(district, cls)][, share := 100 * v / sum(v), by = district]
r_early <- Rc[booth_type %in% c("ordinary", "early", "postal"), .(e = sum(v[booth_type == "early"]), n = sum(v)), by = district][, sh18 := e / n]
seats <- intersect(intersect(unique(Lc$district), pm$d), unique(Rk$district))
sh0 <- matrix(10, length(seats), 1, dimnames = list(seats, "ALP"))
res <- list()
for (fr in c(0.25, 0.5, 0.75, 1)) {
  nu <- night_booth_update(sh0, sh0 * 0 + 5, fr, L[L$booth_type %in% c("ordinary", "early", "postal")], R, gap_k = NULL, early = "last")
  for (s in seats) {
    ld <- copy(Lc[district == s])[, v := as.numeric(v)]; f <- pm[d == s]$p_main
    mx <- mix[d == s]; ratio <- setNames(mx$ratio, mx$cls)
    e <- ld[unit == "early"]; etot <- sum(e$v)
    w <- e$v * ifelse(is.na(ratio[e$cls]), 1, ratio[e$cls]); part <- etot * f * w / sum(w)
    ld[unit == "early", v := part]                                      # only the main centre's early votes are in
    cu <- c(setdiff(nu$units[[s]], c("early", "postal")), "early")      # ordinary booths so far + the (partial) early unit
    if (!length(setdiff(cu, "early"))) next
    proj <- function(ef) { p <- project_seat_from_booths(ld, Rk[district == s], cu, early_frac = ef)
      if (is.null(p)) return(NULL); p[, .(cls, pr = 100 * projected / sum(projected))] }
    est <- sum(part) / (sum(Lc[district == s]$v) * r_early[district == s]$sh18)
    for (k in c("today", "fix_true", "fix_est")) {
      p <- proj(switch(k, today = NA_real_, fix_true = f, fix_est = min(1, est)))
      if (is.null(p)) next
      m <- merge(p, truth[district == s, .(cls, share)], by = "cls", all = TRUE); m[is.na(pr), pr := 0]; m[is.na(share), share := 0]
      res[[length(res) + 1]] <- data.table(frac = fr, seat = s, way = k, f_true = f, f_est = min(1, est), cls = m$cls, err = m$pr - m$share)
    }
  }
}
D <- rbindlist(res)
cat(sprintf("EP2 %d seats; the runner's estimate of early counted: median %.0f%% against the true %.0f%% (it reads 2018's early share; early grew 37%% -> 50%% of the vote by 2022)\n",
            uniqueN(D$seat), 100 * median(unique(D[, .(seat, f_est)])$f_est), 100 * median(unique(D[, .(seat, f_true)])$f_true)))
S <- D[cls %in% c("ALP", "LNP", "GRN"), .(rmse = sqrt(mean(err^2))), by = .(frac, way)]
cat("\nEP3 RMSE of the projected night share, ALP/LNP/GRN pooled, points (lower is better), by ordinary booths counted:\n")
print(dcast(S, frac ~ way, value.var = "rmse"), digits = 3)
B <- D[cls %in% c("ALP", "LNP", "GRN"), .(bias = mean(err)), by = .(way, cls)]
cat("\nEP4 mean error by class (projected minus actual, points):\n"); print(dcast(B, cls ~ way, value.var = "bias"), digits = 3)
fwrite(S, "docs/reviews/early-partial-replay-2026-10-30.csv")
