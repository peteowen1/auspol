# Night class split (docs/plans/prereg-night-class-split-2026-11-14.md): the prereg's TARGETED set and the
# "no split, no move" guard, beside scripts/score_night_pair_replays.R's primary.
#   Rscript scripts/score_night_class_split.R <replay dir> [arm label, default split]
# Targeted = seats with 2+ candidates of one minor class (IND, OTH, OTH_RIGHT) holding votes in that night's booth
# table, i.e. where the split CAN act. Night-average seat-winner log loss over counted times (eps 1e-6), seats
# weighted equally, SE clustered on seat (lower is better). Check codes NCSS0-NCSS3.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
args <- commandArgs(trailingOnly = TRUE)
d <- args[1]; arm <- if (length(args) >= 2) args[2] else "split"
booth_file <- c(fed2022 = "output/booths-fed2022.csv", fed2025 = "output/booths-fed2025.csv", vic2022 = "output/booths-vic2022.csv")
P <- fread("output/published-predictions.csv"); P <- P[P$won == TRUE, list(pair, seat, winner = party)]
rows <- list(); guard <- list()
for (nt in names(booth_file)) {
  L <- fread(booth_file[[nt]]); L <- L[L$votes > 0 & !is.na(L$candidate) & nzchar(L$candidate)]
  L[, cls := classify_party(party)]
  x <- L[L$cls %in% c("IND", "OTH", "OTH_RIGHT"), list(n = uniqueN(candidate)), by = c("district", "cls")]
  elig <- unique(x$district[x$n >= 2L])
  ll <- list()
  for (a in c("base", arm)) {
    S <- fread(file.path(d, sprintf("%s-%s-summary.csv", nt, a))); W <- fread(file.path(d, sprintf("%s-%s-seats.csv", nt, a)))
    S[, time := as.character(time)]; W[, time := as.character(time)]
    tms <- S$time[S$mean_counted > 0]
    win <- P[P$pair == nt]
    g <- CJ(seat = win$seat, time = tms)
    g <- merge(g, win[, list(seat, winner)], by = "seat")
    g <- merge(g, W[, list(seat, party, time, prob)], by.x = c("seat", "winner", "time"), by.y = c("seat", "party", "time"), all.x = TRUE)
    g[is.na(prob), prob := 0]
    ll[[a]] <- g[, list(ll = mean(-log(pmax(prob, 1e-6)))), by = "seat"]
    W[, arm := a]; ll[[paste0(a, "_W")]] <- W
  }
  m <- merge(ll[["base"]], ll[[arm]], by = "seat", suffixes = c("_base", "_arm"))
  m[, `:=`(night = nt, targeted = m$seat %in% elig, d = ll_arm - ll_base)]
  rows[[nt]] <- m
  wb <- ll[["base_W"]]; wa <- ll[[paste0(arm, "_W")]]
  mm <- merge(wb[, list(seat, party, time, pb = prob)], wa[, list(seat, party, time, pa = prob)], by = c("seat", "party", "time"), all = TRUE)
  mm[is.na(pb), pb := 0]; mm[is.na(pa), pa := 0]
  mv <- unique(mm$seat[abs(mm$pa - mm$pb) > 0])
  guard[[nt]] <- data.table(night = nt, eligible = length(elig), moved = length(mv), moved_not_eligible = length(setdiff(mv, elig)),
                            max_sum = max(wa[, list(s = sum(prob)), by = c("seat", "time")]$s))
}
R <- rbindlist(rows)
cat(sprintf("NCSS0 arm '%s' against 'base' in %s; %d seat-nights\n", arm, d, nrow(R)))
summ <- function(x, lbl) data.table(set = lbl, seats = nrow(x), base = mean(x$ll_base), arm = mean(x$ll_arm),
                                    diff = mean(x$d), se = stats::sd(x$d) / sqrt(nrow(x)))
cat("NCSS1 night-average seat-winner log loss (lower is better); diff = arm - base; SE clustered on seat\n")
print(rbindlist(list(
  rbindlist(lapply(split(R, R$night), function(x) summ(x, unique(x$night)))),
  summ(R[R$targeted], "TARGETED (2+ same-class candidates), pooled"),
  summ(R[!R$targeted], "not targeted, pooled"),
  summ(R, "ALL, pooled"))), digits = 4)
cat("NCSS2 guard: seats that moved without 2+ same-class candidates must be 0; win probabilities must sum to 1\n")
print(rbindlist(guard))
cat("NCSS3 targeted seats, biggest changes (seat-winner log loss, lower is better):\n")
print(R[R$targeted][order(d)][c(1:min(8, .N), max(1, .N - 7):.N)][!duplicated(seat)][, list(night, seat, ll_base = round(ll_base, 3), ll_arm = round(ll_arm, 3), d = round(d, 3))])
