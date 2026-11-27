# LANE D1 (docs/plans/prereg-night-lane-d-2026-11-28.md): how far a seat's vote-type swing strays from its ordinary swing.
#
#   Rscript scripts/fit_night_type_sd.R [--root=C:/dev/auspol]
#
# For every reference election pair that ENDS BEFORE the earliest replayed night (fed2022, 21 May 2022), every
# district in both years, every class standing in both, and every non-ordinary vote type:
#   d = (type share now - type share then) - (ordinary share now - ordinary share then), in share points.
# sigma_type^2 = mean within-pair variance of d around that pair's (type, class) mean   (the seat-level spread)
#              + variance across pairs of those means                                  (the night's pooled gap is
#                rough or absent early, so an election-wide gap is uncertain too).
# Pooled per (type, class group): major = ALP, LNP; other = every other class. Printed, then pasted into
# .NIGHT_TYPE_SD in R/night_update.R by hand (it is a constant: refit with this script, do not hand-tune).
# Pairs used: vic2010->vic2014, vic2014->vic2018, wa2008->wa2013, wa2013->wa2017, wa2017->wa2021 (all before
# May 2022, so no screened night is in its own fit). NSW and QLD are left out: their declaration-vote labels changed
# between elections (nsw2011 "declaration" vs nsw2015 "postal"/"ivote"/...; qld2017 vs qld2020) and do not map one to one.
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
root <- flag("root", "C:/dev/auspol")
vt_map <- function(x) {
  x <- tolower(trimws(x))
  data.table::fcase(x == "ordinary", "ordinary",
                    x %in% c("early", "count centre: early votes (in person)"), "early",
                    x %in% c("postal", "count centre: early votes (by post)"), "postal",
                    x %in% c("absent", "count centre: absent votes"), "absent",
                    x %in% c("provisional", "count centre: provisional votes"), "provisional",
                    x == "marked as voted", "marked_as_voted",
                    default = NA_character_)
}
rd <- function(e) {
  f <- file.path(root, "output", "booths", paste0(e, "-booth-fp.csv"))
  X <- fread(f, encoding = "UTF-8")
  X[, vt := vt_map(vote_type)]
  X <- X[!is.na(vt)]
  X[is.na(votes), votes := 0]
  X[, cls := classify_party(party_raw)]
  S <- X[, list(v = sum(votes)), by = c("district", "vt", "cls")]
  S[, tv := sum(v), by = c("district", "vt")]
  S <- S[S$tv > 0]
  S[, sh := 100 * v / tv]
  cat(sprintf("TSD0 %s: %d rows, %d districts, types %s\n", e, nrow(X), uniqueN(X$district), paste(sort(unique(X$vt)), collapse = ",")))
  S
}
pairs <- list(c("vic2010", "vic2014"), c("vic2014", "vic2018"), c("wa2008", "wa2013"), c("wa2013", "wa2017"), c("wa2017", "wa2021"))
D <- rbindlist(lapply(pairs, function(p) {
  A <- rd(p[1]); B <- rd(p[2])
  M <- merge(B[, list(district, vt, cls, sh1 = sh, tv1 = tv)], A[, list(district, vt, cls, sh0 = sh)], by = c("district", "vt", "cls"))
  M[, swg := sh1 - sh0]
  O <- M[M$vt == "ordinary", list(district, cls, sw_o = swg)]
  G <- merge(M[M$vt != "ordinary"], O, by = c("district", "cls"))
  # scaled form: d / sqrt(p (1 - p)), p the class's type share at the later election (fraction, floored at 0.01), so one
  # number per type serves a 40% independent and a 5% minor alike (the "major"/"other" split is printed beside it)
  G[, pq := pmax(0.01, pmin(0.99, sh1 / 100))]
  G[, list(pair = paste(p, collapse = "-"), district, vt, cls, d = swg - sw_o, w = tv1, z = (swg - sw_o) / sqrt(pq * (1 - pq)))]
}))
stopifnot(nrow(D) > 0, all(is.finite(D$d)))
D[, grp := ifelse(cls %in% c("ALP", "LNP"), "major", "other")]
PZ <- D[, list(m = sum(w * z) / sum(w), wv = sum(w * (z - sum(w * z) / sum(w))^2) / sum(w), n = .N), by = c("pair", "vt", "cls")]
WZ <- PZ[n >= 3, list(within = sum(wv * n) / sum(n), between = if (.N >= 2) stats::var(m) else 0, n = sum(n), n_pairs = uniqueN(pair)), by = "vt"]
WZ[, k := sqrt(within + between)]
cat("TSD3 scaled form: sigma_type(class) = k * sqrt(p (1 - p)), p the projected share (fraction)\n"); print(WZ[order(vt)])
cat(sprintf("TSD4 k: %s\n", paste(sprintf("%s = %.3f", WZ[order(vt)]$vt, WZ[order(vt)]$k), collapse = ", ")))
cat(sprintf("TSD1 %d (pair, district, type, class) gaps over %d pairs, %d districts\n", nrow(D), uniqueN(D$pair), uniqueN(paste(D$pair, D$district))))
# Weighted by the type's votes in the later year: a 30-vote provisional block's share swings wildly but barely moves the
# seat, and the night term already scales by the unit's size; the sd here is for a unit of typical (vote-weighted) size.
PM <- D[, list(m = sum(w * d) / sum(w), wv = sum(w * (d - sum(w * d) / sum(w))^2) / sum(w), n = .N), by = c("pair", "vt", "grp", "cls")]
# within: pooled over pairs and classes in the group (weighted by n); between: variance of the per-pair class means
W <- PM[n >= 3, list(within = sum(wv * n) / sum(n), between = if (.N >= 2) stats::var(m) else 0, n = sum(n), n_pairs = uniqueN(pair)),
        by = c("vt", "grp")]
W[, sd := sqrt(within + between)]
print(W[order(vt, grp)])
cat("TSD2 paste into .NIGHT_TYPE_SD (R/night_update.R):\n")
cat(sprintf("  booth_type = c(%s),\n  grp = c(%s),\n  sd = c(%s)\n",
            paste0('"', W[order(vt, grp)]$vt, '"', collapse = ", "), paste0('"', W[order(vt, grp)]$grp, '"', collapse = ", "),
            paste(sprintf("%.3f", W[order(vt, grp)]$sd), collapse = ", ")))
