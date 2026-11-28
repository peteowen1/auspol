options(auspol.root = normalizePath(".")); suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
vt <- function(x) gsub("[^a-z]+", "_", tolower(x))
TT <- fread("output/booths/vic2022-booth-tcp.csv"); FF <- fread("output/booths-vic2022.csv")
cat("tcp rows", nrow(TT), "fp rows", nrow(FF), "| tcp vote types:", paste(unique(TT$vote_type), collapse = ", "), "\n")
TT[is.na(votes), votes := 0]; FF[is.na(votes), votes := 0]
TT[, kls := classify_party(party_raw)]; FF[, kls := classify_party(party)]
TT[, ty := vt(vote_type)]; FF[, ty := vt(booth_type)]
tt <- TT[, .(v = sum(votes)), by = .(district, ty, kls)]; ff <- FF[, .(v = sum(votes)), by = .(district, ty, kls)]
res <- list()
for (d in unique(tt$district)) { pr <- sort(unique(tt[district == d & v > 0]$kls)); if (length(pr) != 2) next
  for (y in unique(tt[district == d]$ty)) { t2 <- tt[district == d & ty == y]; f2 <- ff[district == d & ty == y]; if (sum(t2$v) < 300 || sum(f2$v) < 300) next
    a <- pr[1]; fa <- sum(f2$v[f2$kls == a]); fb <- sum(f2$v[f2$kls == pr[2]]); rest <- sum(f2$v) - fa - fb; if (rest <= 0) next
    sa <- sum(t2$v[t2$kls == a]) / sum(t2$v)
    res[[length(res) + 1]] <- data.table(district = d, pair = paste(pr, collapse = " v "), ty = y, votes = sum(t2$v), rest_share = rest / sum(f2$v), flow_a = (sa - fa / sum(f2$v)) / (rest / sum(f2$v))) } }
R <- rbindlist(res); cat("seat-type cells", nrow(R), "seats", uniqueN(R$district), "\n")
R[, ord := flow_a[ty == "ordinary"][1], by = district]; R <- R[is.finite(ord)]; R[, gap := flow_a - ord]
cat("\nvic2022: share of other votes reaching the FIRST-named party, by vote type; gap = that type minus booths on the day, in points of flow\n")
print(R[, .(seats = .N, votes = sum(votes), flow = round(100 * weighted.mean(flow_a, votes), 1), gap_vs_booths = round(100 * weighted.mean(gap, votes), 1), gap_sd_across_seats = round(100 * sd(gap), 1), rest_share = round(100 * weighted.mean(rest_share, votes), 1)), by = .(pair, ty)][seats >= 5][order(pair, -votes)])
