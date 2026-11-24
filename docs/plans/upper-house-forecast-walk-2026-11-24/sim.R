# Upper-house (Legislative Council) simulation, second walk: the 2026 groups, draws instead of point estimates, and a
# count with preferences. NOT a published forecast: the preference step rests on assumptions, printed below and varied.
#
#   Rscript docs/plans/upper-house-forecast-walk-2026-11-24/sim.R <night-state rds> <seat-shares csv> [n_sims]
# In:  the forecast's own statewide vote draws (night-state `swd`) and mean seat shares, the VEC's 2026 group list
#      (scripts/build_council_groups_2026.R), 2022 upper-house first preferences (output/council-fp-2022.csv).
# Steps per simulation and region:
#  1. lower-house share by region = region mean x (this draw's statewide vote / mean statewide vote), per party
#  2. upper-house share = lower x ratio (Labor 0.905, Coalition 0.845, Greens 0.883: Victoria 2018 and 2022;
#     One Nation: median 0.85, drawn once per simulation, log sd 0.08 = spread between elections) + region noise
#  3. the rest is the minor pool, split across that region's minor groups (Dirichlet around prior weights)
#  4. count: a group with a quota (1/6) elects a member and keeps the surplus; otherwise the smallest group is
#     excluded and its votes move to the groups still in, by bloc affinity and size, with some exhausting.
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 2) stop("usage: sim.R <night-state rds> <seat-shares csv> [n_sims]")
N <- if (length(a) >= 3) as.integer(a[3]) else 4000L
set.seed(20261128)
ns <- readRDS(a[1]); sh <- fread(a[2])
rg <- fread("external/reference/vec/vic-district-regions.csv"); en <- fread("external/reference/vec/2026/enrolment/enrolment-2026.csv")
x <- merge(merge(sh, rg, by.x = "seat", by.y = "district"), en, by.x = "seat", by.y = "district")
stopifnot(nrow(x) == 88, all(x[, .N, by = region]$N == 11))
cls <- c("ALP", "LNP", "ONP", "GRN")
A <- x[, lapply(.SD, function(v) sum(v * enrolment) / sum(enrolment)), by = region, .SDcols = cls][order(region)]
regions <- A$region
swd <- as.matrix(ns$swd); stopifnot(all(cls %in% colnames(swd)), nrow(swd) >= N)
swing <- sweep(swd[seq_len(N), cls], 2, colMeans(swd[, cls]), "/")           # N x 4, mean 1
RATIO <- c(ALP = 0.905, LNP = 0.845, GRN = 0.883, ONP = 0.85); ONP_LOGSD <- 0.08
NOISE <- c(ALP = 3.0, LNP = 2.5, GRN = 1.0, ONP = 2.0)                        # region noise, points of the region's vote
onp_ratio <- RATIO[["ONP"]] * exp(rnorm(N, 0, ONP_LOGSD))

# ---- groups and the prior split of the minor pool -------------------------------------------------------------
g <- fread("external/reference/vec/2026/council-groups-2026.csv")
stopifnot(setequal(g$region, regions))
LEFT <- "Labor|Greens|Socialist|Cannabis|Animal Justice"; RIGHT <- "Liberal|Nationals|One Nation|Family First|Libertarian|Shooters|DLP|Christian"
g[, bloc := fifelse(grepl(RIGHT, group), "R", fifelse(grepl(LEFT, group), "L", "C"))]
fp <- fread("output/council-fp-2022.csv")[block_kind == "district_total" & row_kind == "group"]
fp[, region := sub(" Region$", "", region)]
r22 <- fp[, .(votes = sum(total, na.rm = TRUE)), by = .(region, group_name)]
r22 <- r22[!grepl("LABOR|LIBERAL|NATIONALS|GREENS|ONE NATION", toupper(group_name))]
r22[, pool_share := votes / sum(votes), by = region]
KEYS <- c("Cannabis", "Labour DLP|Democratic Labour", "Victorian Socialists", "Sustainable Australia", "Animal Justice", "Shooters", "Libertarian|Liberal Democrats", "Family First")
key_of <- function(nm) { k <- NA_character_; for (p in KEYS) if (grepl(p, nm, ignore.case = TRUE)) k <- p; k }
r22[, key := vapply(group_name, key_of, "")]; g[, key := vapply(group, key_of, "")]
med22 <- r22[, .(med = median(pool_share)), by = region]
g <- merge(g, r22[!is.na(key), .(share22 = sum(pool_share)), by = .(region, key)], by = c("region", "key"), all.x = TRUE)
g <- merge(g, med22, by = "region")
g[class == "MINOR", raw := fifelse(!is.na(share22), share22, fifelse(grepl("Ungrouped|no name|Unnamed", group), 0.3 * med, med))]
g[class == "MINOR", w := { r <- raw / sum(raw); 0.67 * r + 0.33 / .N }, by = region]
cat(sprintf("UH1  %d simulations, %d regions, %d groups (%d minor). Minor groups with a 2022 result in the same region: %d of %d.\n",
            N, length(regions), nrow(g), sum(g$class == "MINOR"), sum(!is.na(g$share22) & g$class == "MINOR"), sum(g$class == "MINOR")))
cat(sprintf("UH1  One Nation ratio drawn per simulation: median %.2f, 80%% of draws %.2f to %.2f\n", median(onp_ratio), quantile(onp_ratio, .1), quantile(onp_ratio, .9)))
CONC <- 30

# ---- the count ----------------------------------------------------------------------------------------------
# v: named votes in quotas by group. bloc: L / R / C per group. aff: same-bloc multiplier. ex: share exhausting at
# each exclusion. transfers = FALSE gives whole quotas then largest remainders (the first walk's rule).
count <- function(v, bloc, aff, ex, transfers = TRUE, seats = 5L) {
  won <- setNames(integer(length(v)), names(v)); alive <- v > 0
  if (!transfers) { won[] <- as.integer(pmin(floor(v), seats)); left <- seats - sum(won); if (left > 0) { o <- order(-(v - floor(v)))[seq_len(left)]; won[o] <- won[o] + 1L }; return(won) }
  repeat {
    left <- seats - sum(won); if (left == 0L) break
    hit <- which(alive & v >= 1)
    if (length(hit)) { i <- hit[which.max(v[hit])]; won[i] <- won[i] + 1L; v[i] <- v[i] - 1; next }
    if (sum(alive) <= left) { won[alive] <- won[alive] + 1L; break }
    idx <- which(alive); lo <- idx[which.min(v[idx])]; alive[lo] <- FALSE
    rest <- which(alive)
    wt <- sqrt(pmax(v[rest], 1e-6)) * ifelse(bloc[rest] == bloc[lo] & bloc[lo] != "C", aff, ifelse(bloc[rest] == "C" | bloc[lo] == "C", 1, 1 / aff))
    v[rest] <- v[rest] + (1 - ex) * v[lo] * wt / sum(wt); v[lo] <- 0
  }
  won
}
run <- function(label, aff_fun, ex_fun, transfers = TRUE) {
  res <- vector("list", length(regions)); names(res) <- regions
  aff <- aff_fun(N); ex <- ex_fun(N)
  for (r in regions) {
    gr <- g[region == r]; mi <- gr[class == "MINOR"]
    maj <- sapply(cls, function(k) {
      rat <- if (k == "ONP") onp_ratio else RATIO[[k]]
      pmax(0.5, A[region == r][[k]] * swing[, k] * rat + rnorm(N, 0, NOISE[[k]]))
    })
    pool <- pmax(3, 100 - rowSums(maj))
    gam <- matrix(rgamma(N * nrow(mi), shape = rep(CONC * mi$w, each = N)), N); minor <- gam / rowSums(gam) * pool
    V <- cbind(maj, minor); colnames(V) <- c(gr$group[match(cls, gr$class)], mi$group)
    V <- V / rowSums(V) * 6                                              # quotas
    bl <- gr$bloc[match(colnames(V), gr$group)]
    W <- t(vapply(seq_len(N), function(i) count(V[i, ], bl, aff[i], ex[i], transfers), integer(ncol(V))))
    colnames(W) <- colnames(V)
    res[[r]] <- list(V = V, W = W)
  }
  res
}
base <- run("base", function(n) exp(rnorm(n, log(2.5), 0.4)), function(n) runif(n, 0.05, 0.30))
tab <- function(res) rbindlist(lapply(regions, function(r) data.table(region = r, group = colnames(res[[r]]$W), quotas = colMeans(res[[r]]$V),
  seats = colMeans(res[[r]]$W), p1 = colMeans(res[[r]]$W >= 1), p2 = colMeans(res[[r]]$W >= 2), p3 = colMeans(res[[r]]$W >= 3))))
tb <- merge(tab(base), g[, .(region, group, class)], by = c("region", "group"))
short <- function(s) sub("Affordable Housing Now - ", "", sub(" Victoria$| \\(formerly.*$| Party Victoria$", "", s))
cat("\n2. EVERY GROUP WITH A REAL CHANCE, by region. quotas = mean first-preference vote in quotas (1 quota = 16.7% wins a seat);\n",
    "   seats = mean seats won of 5; p1/p2/p3 = chance of at least 1, 2, 3 seats. Groups under a 3% chance of a seat are left out.\n", sep = "")
for (r in regions) { cat("\n", r, "\n", sep = ""); print(tb[region == r & p1 >= 0.03][order(-quotas), .(group = short(group), quotas = round(quotas, 2), seats = round(seats, 2), p1 = round(p1, 2), p2 = round(p2, 2), p3 = round(p3, 2))], row.names = FALSE) }
tot <- function(res) { m <- Reduce(`+`, lapply(regions, function(r) { W <- res[[r]]$W; k <- g[region == r][match(colnames(W), group)]$class
  sapply(c(cls, "MINOR"), function(c0) rowSums(W[, k == c0, drop = FALSE])) })); m }
T0 <- tot(base)
cat("\n3. THE CHAMBER, 40 seats (21 for a majority). mean = average seats; lo and hi = the middle 80% of simulations.\n")
print(data.table(party = c("Labor", "Coalition", "One Nation", "Greens", "All minor groups"), mean = round(colMeans(T0), 1),
                 lo = apply(T0, 2, quantile, .1), hi = apply(T0, 2, quantile, .9)), row.names = FALSE)
cat(sprintf("   Chance Labor + Greens reach 21: %.0f%%. Coalition + One Nation reach 21: %.0f%%. Neither: %.0f%%.\n",
            100 * mean(T0[, "ALP"] + T0[, "GRN"] >= 21), 100 * mean(T0[, "LNP"] + T0[, "ONP"] >= 21),
            100 * mean(T0[, "ALP"] + T0[, "GRN"] < 21 & T0[, "LNP"] + T0[, "ONP"] < 21)))
mn <- rbindlist(lapply(regions, function(r) { W <- base[[r]]$W; k <- g[region == r][match(colnames(W), group)]$class
  data.table(group = colnames(W)[k == "MINOR"], seats = colMeans(W[, k == "MINOR", drop = FALSE])) }))[, .(seats = round(sum(seats), 2)), by = group][order(-seats)]
cat("\n   Minor groups, mean seats statewide (top 6):\n"); print(head(mn[, .(group = short(group), seats)], 6), row.names = FALSE)
# The same numbers as one JSON file, the shape a site page would read. Written beside this script, not to output/.
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
pname <- c(ALP = "Labor", LNP = "Coalition", ONP = "One Nation", GRN = "Greens", MINOR = "Minor groups")
jsonlite::write_json(list(
  election = "vic2026", chamber = "Legislative Council", status = "walk, not a published forecast", lower_house_run_saved_at = as.character(ns$saved_at),
  n_sims = N, seats_total = 40L, majority = 21L, seats_per_region = 5L, quota_pct = round(100 / 6, 2),
  chamber_seats = lapply(colnames(T0), function(k) list(class = k, party = pname[[k]], mean = round(mean(T0[, k]), 2),
    lo80 = unname(quantile(T0[, k], .1)), hi80 = unname(quantile(T0[, k], .9)), dist = as.list(table(factor(T0[, k], levels = 0:max(T0))) / N))),
  p_coalition_onp_21 = round(mean(T0[, "LNP"] + T0[, "ONP"] >= 21), 4), p_labor_greens_21 = round(mean(T0[, "ALP"] + T0[, "GRN"] >= 21), 4),
  regions = lapply(regions, function(r) list(region = r, groups = lapply(unname(split(tb[region == r][order(-quotas)], seq_len(sum(tb$region == r)))), function(z)
    list(group = z$group, class = z$class, vote_pct = round(z$quotas * 100 / 6, 2), quotas = round(z$quotas, 3), seats = round(z$seats, 3),
         p1 = round(z$p1, 4), p2 = round(z$p2, 4), p3 = round(z$p3, 4))))),
  assumptions = c("Upper-house vote = lower-house forecast by region x a ratio per party (Labor 0.905, Coalition 0.845, Greens 0.883, One Nation median 0.85).",
                  "Minor vote split across groups from 2022 shares pulled toward equal.",
                  "Preferences assumed, not measured: same-bloc groups favoured about 2.5 to 1, 5-30% of votes exhaust at each exclusion.")),
  file.path(here, "council-forecast-vic2026.json"), auto_unbox = TRUE, digits = NA)
cat("\n4. HOW MUCH THE PREFERENCE ASSUMPTION MATTERS. Same vote model (fresh draws each), four preference rules; mean seats of 40.\n",
    "   none = whole quotas then largest remainders (the first walk). base = same-bloc groups favoured about 2.5 to 1, 5-30% exhaust.\n",
    "   tight = blocs favoured 5 to 1, 5% exhaust. loose = no bloc preference, 30% exhaust.\n", sep = "")
set.seed(20261128); onp_ratio <- RATIO[["ONP"]] * exp(rnorm(N, 0, ONP_LOGSD))
sens <- list(none = run("none", function(n) rep(1, n), function(n) rep(0, n), FALSE), base = base,
             tight = run("tight", function(n) rep(5, n), function(n) rep(0.05, n)), loose = run("loose", function(n) rep(1, n), function(n) rep(0.30, n)))
S <- sapply(sens, function(z) colMeans(tot(z))); rownames(S) <- c("Labor", "Coalition", "One Nation", "Greens", "Minor groups")
print(round(S, 1))
fwrite(tb[order(region, -quotas)], file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "sim-group-odds.csv"))
