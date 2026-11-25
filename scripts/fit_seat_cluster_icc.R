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
#
# --scheme=type (plans/prereg-seat-type-cor-2026-11-25.md) instead writes
# inst/extdata/seat-cluster-icc-type.csv: election, party, icc_type (one-way ICC within seat-type
# clusters, seat_cluster_type_map() on `ours` + <output>/census-features-vintage.csv), icc_r2 and
# icc_t2 (region and type variance shares from lme4::lmer(z ~ 1 + (1|region) + (1|type)), REML, on
# seats with both ids; NA / icc_type where the jurisdiction has no region), n_cells. The first
# file is not touched in this mode.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
scheme_type <- "--scheme=type" %in% a
a <- a[!grepl("^--", a)]
out_dir <- if (length(a)) a[1] else "output"
source("R/election_dates.R"); source("R/seat_cluster.R")

pp <- fread(file.path(out_dir, "published-predictions.csv"))
cat(sprintf("SKF0 published-predictions: %d rows, %d elections, classes %s\n", nrow(pp), uniqueN(pp$pair),
            paste(sort(unique(pp$party)), collapse = ",")))
if (scheme_type) {
  cen <- read.csv(file.path(out_dir, "census-features-vintage.csv"), stringsAsFactors = FALSE)
  lsd <- as.numeric(strsplit(Sys.getenv("AUSPOL_LEVEL_SD", "1.10,8.67"), ",")[[1]])
  pp <- pp[!(ours <= 0 & actual <= 0)]
  pp[, p := pmin(pmax(ours, 0), 100) / 100]
  pp[, z := (actual - ours) / (lsd[1] + lsd[2] * sqrt(p * (1 - p)))]
  crossed <- function(y, r, t) {
    ok <- is.finite(y) & !is.na(r) & !is.na(t); y <- y[ok]; r <- factor(r[ok]); t <- factor(t[ok])
    if (length(y) < 10L || nlevels(r) < 2L || nlevels(t) < 2L || stats::var(y) == 0) return(c(NA_real_, NA_real_))
    f <- tryCatch(suppressMessages(suppressWarnings(lme4::lmer(y ~ 1 + (1 | r) + (1 | t), REML = TRUE))), error = function(e) NULL)
    if (is.null(f)) return(c(NA_real_, NA_real_))
    vc <- as.data.frame(lme4::VarCorr(f)); v <- stats::setNames(vc$vcov, vc$grp)
    tot <- sum(v)
    c(unname(v["r"] / tot), unname(v["t"] / tot))
  }
  res <- list()
  for (el in sort(unique(pp$pair))) {
    d <- pp[pair == el]
    w <- dcast(d, seat ~ party, value.var = "ours", fill = 0)
    sh <- as.matrix(w[, -1]); rownames(sh) <- w$seat
    tid <- seat_cluster_type_map(el, w$seat, sh, census = cen)
    has_r <- seat_cluster_has_region(el)
    rid <- if (has_r) seat_cluster_map(el, w$seat, sh) else rep(NA_integer_, nrow(w))
    d <- merge(d, data.table(seat = w$seat, tc = as.integer(tid), rc = as.integer(rid)), by = "seat")
    for (k in sort(unique(d$party))) {
      u <- d[party == k]
      it <- seat_cluster_icc1(u$z, u$tc)
      cr <- if (has_r) crossed(u$z, u$rc, u$tc) else c(NA_real_, it)
      res[[length(res) + 1L]] <- data.table(election = el, party = k, icc_type = round(it, 5),
        icc_r2 = round(cr[1], 5), icc_t2 = round(cr[2], 5), n_cells = nrow(u),
        n_types = uniqueN(u$tc), scheme = attr(tid, "scheme"))
    }
  }
  R <- rbindlist(res)
  fwrite(R, "inst/extdata/seat-cluster-icc-type.csv")
  cat(sprintf("SKT3 seat-cluster-icc-type.csv: %d rows; cell-weighted mean by class (fed / state):\n", nrow(R)))
  R[, grp := ifelse(grepl("^fed", election), "fed", "state")]
  wm <- function(x, w) { ok <- is.finite(x); round(sum(x[ok] * w[ok]) / sum(w[ok]), 3) }
  print(R[, .(icc_type = wm(icc_type, n_cells), icc_r2 = wm(icc_r2, n_cells), icc_t2 = wm(icc_t2, n_cells),
              n_el = .N), by = .(grp, party)][order(grp, party)])
  quit(status = 0)
}
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
