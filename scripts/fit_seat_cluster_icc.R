# Per-election cluster correlation of seat misses, for AUSPOL_SEAT_CLUSTER_COR
# (R/seat_cluster.R; docs/plans/prereg-seat-cluster-cor-2026-11-25.md).
#
#   Rscript scripts/fit_seat_cluster_icc.R [path/to/output]
#
# Reads <output>/published-predictions.csv (the published-path prediction of every
# (election, seat, class): `ours`, `actual`) and <output>/candidacies.csv (division -> state for
# federal), and writes two small committed files:
#   inst/extdata/fed-division-state.csv   seat, state  (every federal division in the corpus)
#   inst/extdata/seat-cluster-icc.csv     election, party, icc, n_cells, n_clusters, scheme
# One row per (election, class) is a MEASUREMENT of that election; seat_cluster_rho() pools
# only elections dated before a target, so the table itself holds no future information for any
# target. Each prediction in published-predictions.csv is itself time-forward (as-at models).
#
# The miss is standardised by the published level sd, a + b*sqrt(p(1-p)) (AUSPOL_LEVEL_SD
# 1.10,8.67), because the simulator's cluster loading is a share of each cell's own sd: what is
# estimated is the correlation of standardised misses between seats of one cluster, net of the
# election-wide miss (the one-way ANOVA removes the election mean).
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(a)) a[1] else "output"
source("R/election_dates.R"); source("R/seat_cluster.R")

pp <- fread(file.path(out_dir, "published-predictions.csv"))
cat(sprintf("SKF0 published-predictions: %d rows, %d elections, classes %s\n", nrow(pp), uniqueN(pp$pair),
            paste(sort(unique(pp$party)), collapse = ",")))
cand <- fread(file.path(out_dir, "candidacies.csv"), select = c("election", "seat", "state"))
fds <- unique(cand[grepl("^fed", election) & state %in% c("NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"), .(seat, state)])
fds <- fds[, .(state = names(sort(table(state), decreasing = TRUE))[1]), by = seat][order(seat)]
fwrite(fds, "inst/extdata/fed-division-state.csv")
cat(sprintf("SKF1 fed-division-state.csv: %d divisions, %s\n", nrow(fds), paste(names(table(fds$state)), table(fds$state), sep = "=", collapse = " ")))

lsd <- as.numeric(strsplit(Sys.getenv("AUSPOL_LEVEL_SD", "1.10,8.67"), ",")[[1]])
pp <- pp[!(ours <= 0 & actual <= 0)]
pp[, p := pmin(pmax(ours, 0), 100) / 100]
pp[, z := (actual - ours) / (lsd[1] + lsd[2] * sqrt(p * (1 - p)))]
res <- list()
for (el in sort(unique(pp$pair))) {
  d <- pp[pair == el]
  w <- dcast(d, seat ~ party, value.var = "ours", fill = 0)
  sh <- as.matrix(w[, -1]); rownames(sh) <- w$seat
  id <- seat_cluster_map(el, w$seat, sh)
  cl <- data.table(seat = w$seat, cl = as.integer(id))
  d <- merge(d, cl, by = "seat")
  cat(sprintf("SKF2 %-8s %-45s %2d clusters, %3d of %3d seats matched\n", el, attr(id, "scheme"),
              length(attr(id, "labels")), sum(!is.na(id)), length(id)))
  for (k in sort(unique(d$party))) {
    u <- d[party == k & !is.na(cl)]
    res[[length(res) + 1L]] <- data.table(election = el, party = k,
      icc = round(seat_cluster_icc1(u$z, u$cl), 5), n_cells = nrow(u), n_clusters = uniqueN(u$cl),
      scheme = attr(id, "scheme"))
  }
}
R <- rbindlist(res)
fwrite(R, "inst/extdata/seat-cluster-icc.csv")
cat(sprintf("SKF3 seat-cluster-icc.csv: %d rows; mean icc by class (fed / state):\n", nrow(R)))
R[, grp := ifelse(grepl("^fed", election), "fed", "state")]
print(dcast(R[is.finite(icc), .(icc = round(weighted.mean(icc, n_cells), 3)), by = .(grp, party)], party ~ grp, value.var = "icc"))
