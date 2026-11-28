# LIVE upper-house forecast inputs, version 2 (Pete, 10:20pm 28 Nov: "read the upper-house count; fit the narrowing").
#   Rscript mk_live2.R base  <night json> <pre dir> <out dir>
#   Rscript mk_live2.R blend <night json> <pre dir> <out dir> <pass-1 forecast json> <raw lower json> <raw upper json>
# base : the live lower-house first preferences as the model's input, and the statewide swing draws narrowed by k =
#        (mean posterior sd of the live seat first preferences) / (mean pre-election sd), measured tonight, not chosen.
# blend: for each region and each of Labor, Coalition, Greens, One Nation, a target upper-house share that blends
#        (a) the model's own share from pass 1 with (b) the upper-house COUNT, de-biased by the lower house in the same
#        region (count share x live projected lower share / raw counted lower share: the same booths are in for both
#        houses, and the lower-house model knows how unrepresentative they are). Weight on the count
#        w = sd_model^2 / (sd_model^2 + sd_count^2): sd_model = 8% of the share (the model's ratio spread), sd_count =
#        the night model's projection error at the upper-house counted share (booth_projection_sd table). The seat
#        inputs are then scaled within the region so the unchanged model lands on the target. Minor groups stay as modelled.
suppressMessages(library(data.table)); a <- commandArgs(TRUE); mode <- a[1]
n <- jsonlite::fromJSON(a[2], simplifyVector = FALSE); pre <- fread(file.path(a[3], "seat-shares-vic-2026.csv")); cls <- setdiff(names(pre), "seat"); four <- c("ALP", "LNP", "GRN", "ONP")
L <- rbindlist(lapply(n$seats, function(s) { v <- setNames(rep(0, length(cls)), cls); for (p in s$parties) if (p$party %in% cls && !is.null(p$primary)) v[[p$party]] <- p$primary
  as.data.table(c(list(seat = s$seat), as.list(v))) }))
stopifnot(nrow(L) == 88, setequal(L$seat, pre$seat)); L <- L[match(pre$seat, seat)]
ns <- readRDS(file.path(a[3], "night-state-vic-2026.rds"))
post_sd <- mean(unlist(lapply(n$seats, function(s) vapply(s$parties, function(p) if (p$party %in% four && !is.null(p$primary_sd)) p$primary_sd else NA_real_, 0))), na.rm = TRUE)
prior_sd <- mean(as.matrix(ns$sdo)[, intersect(four, colnames(ns$sdo))], na.rm = TRUE); k <- min(1, post_sd / prior_sd)
sw <- as.matrix(ns$swd); m <- colMeans(sw); ns$swd <- sweep(sweep(sw, 2, m) * k, 2, m, "+"); saveRDS(ns, file.path(a[4], "night-state-vic-2026.rds"))
cat(sprintf("night file %s; narrowing k = %.3f (live sd %.2f / pre-election sd %.2f)\n", n$night$snapshot_stamp, k, post_sd, prior_sd))
if (mode == "blend") {
  rg <- fread("external/reference/vec/vic-district-regions.csv"); en <- fread("external/reference/vec/2026/enrolment/enrolment-2026.csv")
  lk <- function(x) gsub("[^a-z]", "", tolower(x)); X <- data.table(seat = L$seat, region = rg$region[match(lk(L$seat), lk(rg$district))], e = en$enrolment[match(lk(L$seat), lk(en$district))])
  stopifnot(!anyNA(X$region), !anyNA(X$e))
  p1 <- jsonlite::fromJSON(a[5], simplifyVector = FALSE); rl <- jsonlite::fromJSON(a[6], simplifyVector = FALSE); ru <- jsonlite::fromJSON(a[7], simplifyVector = FALSE)
  sdtab <- function(f) stats::approx(c(0, .05, .086, .224, .346, .95, 1), c(3.5, 3.5, 2.63, 1.93, 1.77, .26, .26), xout = pmin(pmax(f, 0), 1), rule = 2)$y
  # raw lower-house counted votes by region and class
  RL <- rbindlist(lapply(rl$seats, function(s) rbindlist(lapply(s$primary, function(p) data.table(seat = s$seat, cls = p$party_class, v = p$votes)))))
  RL[, region := X$region[match(lk(seat), lk(X$seat))]]; RLt <- RL[, .(v = sum(v)), by = .(region, cls)]; RLt[, tot := sum(v), by = region]
  out <- list()
  for (r in sort(unique(X$region))) {
    i <- X$region == r; U <- NULL; for (z in ru$regions) if (z$region == r) U <- z
    M <- NULL; for (z in p1$regions) if (z$region == r) M <- z
    if (is.null(U) || is.null(M) || U$formal_votes < 2000) next
    fu <- U$formal_votes / (0.9 * sum(X$e[i]))
    for (g in four) {
      mg <- sum(vapply(M$groups, function(q) if (identical(q$class, g)) q$vote_pct else 0, 0)); ug <- 100 * sum(vapply(U$groups, function(q) if (identical(q$party_class, g)) q$votes else 0, 0)) / U$formal_votes
      Llive <- sum(X$e[i] * L[[g]][i]) / sum(X$e[i]); cr <- RLt[region == r & cls == g]; craw <- if (nrow(cr) && cr$tot[1] > 0) 100 * cr$v[1] / cr$tot[1] else NA
      if (!is.finite(craw) || craw <= 0 || mg <= 0) next
      ucount <- ug * Llive / craw; sdm <- 0.08 * mg; sdc <- sdtab(fu); w <- sdm^2 / (sdm^2 + sdc^2); tgt <- (1 - w) * mg + w * ucount
      L[i, (g) := get(g) * tgt / mg]
      out[[length(out) + 1]] <- data.table(region = r, cls = g, counted_pct = round(100 * fu, 1), count_raw = round(ug, 1), count_debiased = round(ucount, 1), model = round(mg, 1), weight_on_count = round(w, 2), target = round(tgt, 1))
    }
  }
  if (length(out)) { O <- rbindlist(out); print(O); fwrite(O, file.path(a[4], "blend-table.csv")) } else cat("no region had enough upper-house votes to blend\n")
}
fwrite(L, file.path(a[4], "seat-shares-vic-2026.csv"))
