# Upper-house (Legislative Council) forecast for the daily run: the 24 Nov walk's simulation
# (docs/plans/upper-house-forecast-walk-2026-11-24/sim.R, which Pete approved) moved here unchanged in its model and
# seed, base preference rule only (the walk's sensitivity runs stay in the walk). Written for the ITG page
# /politics/vic2026/upper-house via R2 key auspol/upper-house-forecast-vic2026.json.
#
#   Rscript scripts/build_upper_house_forecast.R [--dir=output] [--out=output/upper-house-forecast-vic2026.json] [--sims=4000]
# In:  <dir>/night-state-vic-2026.rds (its swd), <dir>/seat-shares-vic-2026.csv,
#      external/reference/vec/vic-district-regions.csv, external/reference/vec/2026/enrolment/enrolment-2026.csv,
#      external/reference/vec/2026/upper-house-groups-2026.csv, external/reference/vec/2022/upper-house-group-totals-2022.csv
#      (2022 first preferences by region and group, summed from output/council-fp-2022.csv; 22 MB -> a few KB).
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default) { hit <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(hit)) sub("^[^=]*=", "", hit[1]) else default }
DIR <- arg("dir", "output"); OUT <- arg("out", file.path("output", "upper-house-forecast-vic2026.json"))
N <- as.integer(arg("sims", "4000"))
set.seed(20261128)
ns <- readRDS(file.path(DIR, "night-state-vic-2026.rds")); sh <- fread(file.path(DIR, "seat-shares-vic-2026.csv"))
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
g <- fread("external/reference/vec/2026/upper-house-groups-2026.csv")
stopifnot(setequal(g$region, regions))
LEFT <- "Labor|Greens|Socialist|Cannabis|Animal Justice"; RIGHT <- "Liberal|Nationals|One Nation|Family First|Libertarian|Shooters|DLP|Christian"
g[, bloc := fifelse(grepl(RIGHT, group), "R", fifelse(grepl(LEFT, group), "L", "C"))]
r22 <- fread("external/reference/vec/2022/upper-house-group-totals-2022.csv")
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
# Victorian Socialists' share of the minor pool from the polled regional VS vote (YouGov Megapoll 6-23 Nov 2026,
# n 3890, its upper-house-region crosstab; Pete 25 Nov), not their 2022 share. Each region's figure is shrunk toward
# the statewide 4%: w = tau^2 / (tau^2 + se^2), se from the region's sample (n ~ 3890 x enrolment share, design
# effect 1), tau^2 the between-region variance beyond sampling noise. Upper-house VS vote = polled vote (ratio 1).
# Every other minor group keeps its relative weight. AUSPOL_UPPER_HOUSE_VS_POLL=0 restores the 2022-share split.
if (Sys.getenv("AUSPOL_UPPER_HOUSE_VS_POLL", "1") == "1") {
  YG <- fread("external/reference/polls/yougov-megapoll-regions-2026-11.csv")
  vr <- YG[party == "VS"][match(regions, region)]$pct; vs_s <- YG[party == "VS" & region == "Statewide"]$pct
  stopifnot(length(vs_s) == 1L, !anyNA(vr))
  en_r <- x[, .(e = sum(enrolment)), by = region][match(regions, region)]$e
  se <- 100 * sqrt((vr / 100) * (1 - vr / 100) / (3890 * en_r / sum(en_r)))
  d <- vr - vs_s; tau2 <- max(0, mean(d^2) - mean(se^2))
  vs_hat <- setNames(vs_s + tau2 / (tau2 + se^2) * d, regions)
  for (r in regions) {
    pool_mean <- 100 - sum(unlist(A[region == r, ..cls]) * RATIO[cls])
    iv <- which(g$region == r & g$class == "MINOR" & g$group == "Victorian Socialists")
    io <- which(g$region == r & g$class == "MINOR" & g$group != "Victorian Socialists")
    stopifnot(length(iv) == 1L, length(io) >= 1L, pool_mean > vs_hat[[r]])   # else wv is negative or pinned at the cap
    old <- g$w[iv]; wv <- min(0.8, vs_hat[[r]] / pool_mean)
    g$w[io] <- g$w[io] * (1 - wv) / sum(g$w[io]); g$w[iv] <- wv
    cat(sprintf("UHF2  %s: Victorian Socialists %.1f%% polled -> %.1f%% after shrinkage; share of the minor pool %.2f -> %.2f\n",
                r, vr[match(r, regions)], vs_hat[[r]], old, wv))
  }
} else cat("UHF2  AUSPOL_UPPER_HOUSE_VS_POLL=0: Victorian Socialists split from their 2022 share\n")
cat(sprintf("UHF1  %d simulations, %d regions, %d groups (%d minor). Minor groups with a 2022 result in the same region: %d of %d.\n",
            N, length(regions), nrow(g), sum(g$class == "MINOR"), sum(!is.na(g$share22) & g$class == "MINOR"), sum(g$class == "MINOR")))
cat(sprintf("UHF1  One Nation ratio drawn per simulation: median %.2f, 80%% of draws %.2f to %.2f\n", median(onp_ratio), quantile(onp_ratio, .1), quantile(onp_ratio, .9)))
CONC <- 30

# ---- AUSPOL_UPPER_HOUSE_VOTE_MODEL=1: the fitted vote model (R/upper_house_vote.R) ---------------------------
# docs/plans/upper-house-vote-model-2026-11-26.md. Majors: a uniform statewide ratio per party fitted on Victoria
# 2010/2018/2022 (the pre-registered backtest found past region effects did not beat it), with statewide drift
# (common + party) and region drift drawn per simulation. One Nation: ratio pooled over federal, other-state,
# Victorian and DemosAU same-poll evidence. Minors: relative weights from DemosAU's named levels (DLP, Legalise
# Cannabis), Victorian Socialists at the YouGov regional figures above, the rest from 2022 with a shrunk regional
# pattern scaled to DemosAU's "others"; the pool the majors leave is shared in proportion. NOISE (lower-house
# regional error, not measured anywhere) is kept on top. "0" (default) draws nothing here: output unchanged.
# "2" = "1" with the majors' ratios from the ballot-crowding model (prereg addition 9): log ratio = a + b x + c
# ticket, x = log(groups per seat), fitted on Victoria 2010/2018/2022 and six other-state upper houses, each 2026
# region at its own group count, no tickets.
UVM <- Sys.getenv("AUSPOL_UPPER_HOUSE_VOTE_MODEL", "0")
if (!UVM %in% c("0", "1", "2")) stop("AUSPOL_UPPER_HOUSE_VOTE_MODEL must be 0, 1 or 2, got ", UVM)
VM <- UVM %in% c("1", "2"); VM2 <- UVM == "2"
if (VM) {
  if (!exists("uh_fit_majors")) { options(auspol.root = normalizePath(".")); suppressMessages(devtools::load_all(quiet = TRUE)) }
  uin <- fread("external/reference/vec/upper-house-ratio-inputs.csv"); urt <- uh_region_table(uin)
  # Settings of the shipped variant; the alternatives are the sensitivities in the plan's results section.
  UH_REGIONAL <- FALSE                       # TRUE: shrunk region effects (lost the backtest, 5.54 v 3.25 points)
  UH_REGIME <- FALSE                         # TRUE: add the ticket-experiment variance (results addition 8: double counts)
  UH_SHIFT <- c(ALP = 0, LNP = 0, GRN = 0)   # log shift to the statewide ratios (none applied; see addition 6)
  UH_POLL_BLEND <- FALSE                     # TRUE: arm C, blend the DemosAU 21-25 Nov relative ratios into each major's level
  ufm <- uh_fit_majors(urt, c("vic2010", "vic2018", "vic2022"), regional = UH_REGIONAL)
  unv <- uh_noticket_variance(fread("external/reference/vec/upper-house-noticket-experiments.csv"))
  if (UH_REGIME) ufm <- uh_add_regime_variance(ufm, unv)
  upl <- fread("external/reference/polls/demosau-upper-lower-2025-2026.csv")
  if (UH_POLL_BLEND) {
    upu <- uh_onp_poll_units(upl, urt); dd <- upu$disc[poll == "nov26"]
    wpoll <- ufm$drift_party_sd^2 / (ufm$drift_party_sd^2 + upu$disc_var + dd$samp)
    UH_SHIFT[dd$party] <- UH_SHIFT[dd$party] + wpoll * dd$disc
    cat(sprintf("UHV0  arm C poll blend: weight on the poll %s; shift %s\n", paste(sprintf("%.2f", wpoll), collapse = "/"),
                paste(sprintf("%s %+.3f", dd$party, wpoll * dd$disc), collapse = ", ")))
  }
  for (k in names(UH_SHIFT)) ufm$party[[k]]$mu <- ufm$party[[k]]$mu + UH_SHIFT[[k]]
  cat(sprintf("UHV0  majors: regional %s, ticket variance %s, level shift %s; drift log sd common %.3f, party %.3f\n", UH_REGIONAL, UH_REGIME,
              paste(sprintf("%s %+.3f", names(UH_SHIFT), UH_SHIFT), collapse = " "), ufm$drift_common_sd, ufm$drift_party_sd))
  if (VM2) {
    ucr <- fread("external/reference/vec/upper-house-crowding-inputs.csv"); uet <- uh_crowding_table(ucr, "per_seat")
    ucf <- uh_crowding_fit(uet, setdiff(unique(uet$election), "vic2026"))
    x26 <- unique(ucr[election == "vic2026", .(unit, xg = log(groups / seats))]); stopifnot(setequal(x26$unit, regions))
    upr <- uh_crowding_predict(ucf, setNames(x26$xg, x26$unit)[regions], 0)
    RAT1 <- uh_crowding_draws(ucf, upr, vapply(ufm$party, function(f) f$s2, 0), N)
    cat(sprintf("UHV4  crowding model (%d elections): slope %s, ticket %s; 2026 statewide ratio %s; residual log sd common %.3f, party %.3f\n",
                ucf$n, paste(sprintf("%s %.3f", ucf$coef$cls, ucf$coef$b), collapse = " "), paste(sprintf("%s %+.3f", ucf$coef$cls, ucf$coef$c), collapse = " "),
                paste(sprintf("%s %.3f", colnames(upr$point), exp(colMeans(upr$point))), collapse = " "), ucf$common_sd, ucf$party_sd))
  } else RAT1 <- uh_draw_major_ratios(ufm, uh_major_logratio(ufm, regions), N)
  uop <- uh_onp_pool(rbind(fread("external/reference/vec/upper-house-onp-sources.csv"), uh_onp_poll_units(upl, urt)$units, fill = TRUE))
  onp_sd_reg <- sqrt(mean(vapply(ufm$party, function(f) f$s2, 0)))      # region drift borrowed from the majors
  RAT1$ONP <- exp(uop$mu + rnorm(N, 0, uop$pred_sd) + matrix(rnorm(N * length(regions), 0, onp_sd_reg), N, dimnames = list(NULL, regions)))
  for (k in c(cls)) cat(sprintf("UHV1  %s upper/lower ratio: median %.3f, 80%% of draws %.2f to %.2f (pooled over regions and simulations)\n",
                                k, median(RAT1[[k]]), quantile(RAT1[[k]], .1), quantile(RAT1[[k]], .9)))
  cat(sprintf("UHV2  One Nation pooled ratio %.3f from %d units (federal %.0f%%, other states %.0f%%, Victoria 2022 %.0f%%, DemosAU %.0f%%)\n",
              exp(uop$mu), nrow(uop$units), 100 * sum(uop$units[kind == "federal Senate vs House"]$weight), 100 * sum(uop$units[grepl("^other state", kind)]$weight),
              100 * sum(uop$units[kind == "Victorian council vs assembly"]$weight), 100 * sum(uop$units[grepl("^DemosAU", kind)]$weight)))
  # minors: DemosAU's named groups (DLP, Legalise Cannabis) held at their polled level; Victorian Socialists at the
  # YouGov regional figures (vs_hat) when AUSPOL_UPPER_HOUSE_VS_POLL=1, else at DemosAU's statewide 3%.
  t18 <- fread("external/reference/vec/upper-house-group-totals-2018.csv"); t22 <- fread("external/reference/vec/2022/upper-house-group-totals-2022.csv")
  for (tt in list(t18, t22)) { tt[, reg := uh_map_region(region)]; tt[, key := uh_key_of(group_name)] }
  p18 <- uh_minor_pattern(t18[, .(reg, key, votes)]); p22 <- uh_minor_pattern(t22[, .(reg, key, votes)])
  bk <- intersect(p18$key, p22$key); ums <- uh_minor_shrink(p22[key %in% bk], p18[key %in% bk])
  vw <- setNames(x[, .(e = sum(enrolment)), by = region][match(regions, region)]$e, regions)
  dp <- upl[poll == "nov26" & house == "upper"]; dpn <- upl[poll == "nov26"]$n[1]
  pk <- c(DLP = "Labour DLP|Democratic Labour", LCV = "Cannabis", VS = "Victorian Socialists")
  polled <- setNames(dp$pct[match(names(pk), dp$party)], pk); stopifnot(!anyNA(polled))
  ulv <- uh_minor_region_levels(g[class == "MINOR", .(region, group)], fread("external/reference/vec/2022/upper-house-group-totals-2022.csv"),
                                ums$w, vw, polled)
  if (exists("vs_hat")) ulv[key == "Victorian Socialists", level := vs_hat[region]]
  # un-polled groups scaled together to DemosAU's "others" (10% statewide, vote-weighted over regions); the pool is
  # then shared in proportion to all levels (uh_minor_votes), so these are relative weights, not fixed votes.
  oth <- upl[poll == "nov26" & house == "upper" & party == "OTH"]$pct; stopifnot(length(oth) == 1L)
  sun <- ulv[polled == FALSE, .(s = sum(level)), by = region][match(regions, region)]$s
  ufac <- oth / (sum(sun * vw) / sum(vw)); ulv[polled == FALSE, level := level * ufac]
  cat(sprintf("UHV3  un-polled minor groups scaled x%.2f to DemosAU's others %.0f%%\n", ufac, oth))
  ZF <- sapply(pk, function(k) { p <- polled[[k]] / 100; nn <- if (k == "Victorian Socialists" && exists("vs_hat")) 3890 else dpn
    exp(rnorm(N, 0, sqrt((1 - p) / (nn * p)))) })
  colnames(ZF) <- unname(pk)
  cat(sprintf("UHV3  minor groups: regional pattern shrink w %.2f (%d group-region pairs); polled levels: %s; %d of %d 2026 minor groups matched to 2022\n",
              ums$w, ums$n_pairs, paste(sprintf("%s %.0f%%", names(pk), polled), collapse = ", "), sum(!is.na(ulv$key) & ulv$key %in% p22$key), nrow(ulv)))
}

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
# AUSPOL_UPPER_HOUSE_COUNT_MODEL = "1": count with preferences measured from the 2025 Victorian Senate ballots
# (R/upper_house_count.R; plan and validation docs/plans/upper-house-count-model-2026-11-26.md) instead of count()'s
# assumed bloc weighting and exhaustion. The aff / ex draws below still happen, so the vote draws are identical
# under both settings and only the count differs.
COUNT_MODEL <- Sys.getenv("AUSPOL_UPPER_HOUSE_COUNT_MODEL", "0")
stopifnot(COUNT_MODEL %in% c("0", "1"))
if (COUNT_MODEL == "1") {
  source("R/upper_house_count.R")
  UH_FLOWS_FILE <- "external/reference/aec/senate-flows/vic-senate-2025-flows.csv.gz"
  if (!file.exists(UH_FLOWS_FILE)) stop("AUSPOL_UPPER_HOUSE_COUNT_MODEL=1 needs ", UH_FLOWS_FILE, " (scripts/validate_upper_house_count.R writes it)")
  uh_flows <- uh_read_flows(UH_FLOWS_FILE)
  # A party a Senate voter numbered that is not standing in the region: "pool" = the region's same-bloc pool group
  # first (pre-registered), "bloc" = any same-bloc group, "skip" = drop the mark. It moves the chamber (validation note).
  UH_ABSENT <- Sys.getenv("AUSPOL_UPPER_HOUSE_ABSENT", "pool")
  stopifnot(UH_ABSENT %in% c("pool", "bloc", "skip"))
  cat(sprintf("UHF3  count model 1: preferences from %s (%.0f ballots, %d class sequences); parties not standing: %s\n",
              uh_flows$label, uh_flows$n_ballots, nrow(uh_flows$seq), UH_ABSENT))
}
run <- function(label, aff_fun, ex_fun, transfers = TRUE) {
  res <- vector("list", length(regions)); names(res) <- regions
  aff <- aff_fun(N); ex <- ex_fun(N)
  for (r in regions) {
    gr <- g[region == r]; mi <- gr[class == "MINOR"]
    maj <- sapply(cls, function(k) {
      rat <- if (VM) RAT1[[k]][, r] else if (k == "ONP") onp_ratio else RATIO[[k]]
      pmax(0.5, A[region == r][[k]] * swing[, k] * rat + rnorm(N, 0, NOISE[[k]]))
    })
    pool <- pmax(3, 100 - rowSums(maj))
    if (VM) { lv <- ulv[region == r][match(mi$group, group)]; minor <- uh_minor_votes(lv, pool, ZF, CONC) } else {
    gam <- matrix(rgamma(N * nrow(mi), shape = rep(CONC * mi$w, each = N)), N); minor <- gam / rowSums(gam) * pool }
    V <- cbind(maj, minor); colnames(V) <- c(gr$group[match(cls, gr$class)], mi$group)
    V <- V / rowSums(V) * 6                                              # quotas
    bl <- gr$bloc[match(colnames(V), gr$group)]
    W <- if (COUNT_MODEL == "1") {
      gi <- match(colnames(V), gr$group)
      pat <- uh_region_patterns(colnames(V), uh_flows, min_to = 5L, top = 150L, tail = 150L, seed = match(r, regions), absent = UH_ABSENT)
      d <- pat$diag
      cat(sprintf("UHF3  %s: %d ballot patterns; Senate ballots that stopped at the minimum number %.2f boxes here on average; groups on no Senate ballot (their bloc's voters stand in): %s\n",
                  r, nrow(pat$S), sum(d$len_at_min * d$n_own, na.rm = TRUE) / sum(d$n_own[!is.na(d$len_at_min)]),
                  paste(d$group[grepl("^POOL_", d$class)], collapse = ", ")))
      count_region(V, colnames(V), pat, seats = 5L, cands = gr$candidates[gi])
    } else t(vapply(seq_len(N), function(i) count(V[i, ], bl, aff[i], ex[i], transfers), integer(ncol(V))))
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
pname <- c(ALP = "Labor", LNP = "Coalition", ONP = "One Nation", GRN = "Greens", MINOR = "Minor groups")
jsonlite::write_json(list(
  election = "vic2026", chamber = "Legislative Council", status = "forecast", built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "UTC"), lower_house_run_saved_at = as.character(ns$saved_at),
  n_sims = N, seats_total = 40L, majority = 21L, seats_per_region = 5L, quota_pct = round(100 / 6, 2),
  chamber_seats = lapply(colnames(T0), function(k) list(class = k, party = pname[[k]], mean = round(mean(T0[, k]), 2),
    lo80 = unname(quantile(T0[, k], .1)), hi80 = unname(quantile(T0[, k], .9)), dist = as.list(table(factor(T0[, k], levels = 0:max(T0))) / N))),
  p_coalition_onp_21 = round(mean(T0[, "LNP"] + T0[, "ONP"] >= 21), 4), p_labor_greens_21 = round(mean(T0[, "ALP"] + T0[, "GRN"] >= 21), 4),
  regions = lapply(regions, function(r) list(region = r, groups = lapply(unname(split(tb[region == r][order(-quotas)], seq_len(sum(tb$region == r)))), function(z)
    list(group = z$group, class = z$class, vote_pct = round(z$quotas * 100 / 6, 2), quotas = round(z$quotas, 3), seats = round(z$seats, 3),
         p1 = round(z$p1, 4), p2 = round(z$p2, 4), p3 = round(z$p3, 4))))),
  assumptions = c(if (VM2) c(sprintf("Upper-house vote = lower-house forecast by region x a ratio per party from a ballot-crowding model (groups per seat, tickets) fitted on Victoria 2010-22 and six other states' upper houses (2026 statewide: Labor %.3f, Coalition %.3f, Greens %.3f).",
                                    exp(mean(upr$point[, "ALP"])), exp(mean(upr$point[, "LNP"])), exp(mean(upr$point[, "GRN"]))),
                            sprintf("One Nation ratio %.2f pooled from federal Senate, other states' upper houses, Victoria 2022 and DemosAU's same-poll figures.", exp(uop$mu)),
                            "Minor vote shared in proportion to DLP and Legalise Cannabis at DemosAU 21-25 Nov levels, Victorian Socialists at YouGov regional figures, and the other groups from 2022 with a shrunk regional pattern.")
                  else if (VM) c(sprintf("Upper-house vote = lower-house forecast by region x a ratio per party fitted on Victoria 2010, 2018 and 2022 (Labor %.3f, Coalition %.3f, Greens %.3f), with its election-to-election drift drawn as uncertainty.",
                                    exp(ufm$party$ALP$mu), exp(ufm$party$LNP$mu), exp(ufm$party$GRN$mu)),
                            sprintf("One Nation ratio %.2f pooled from federal Senate, other states' upper houses, Victoria 2022 and DemosAU's same-poll figures.", exp(uop$mu)),
                            "Minor vote shared in proportion to DLP and Legalise Cannabis at DemosAU 21-25 Nov levels, Victorian Socialists at YouGov regional figures, and the other groups from 2022 with a shrunk regional pattern.")
                  else c("Upper-house vote = lower-house forecast by region x a ratio per party (Labor 0.905, Coalition 0.845, Greens 0.883, One Nation median 0.85).",
                  if (Sys.getenv("AUSPOL_UPPER_HOUSE_VS_POLL", "1") == "1")
                    "Minor vote split across groups from 2022 shares pulled toward equal; Victorian Socialists from YouGov's regional polling (6-23 Nov)."
                  else "Minor vote split across groups from 2022 shares pulled toward equal."),
                  if (COUNT_MODEL == "1")
                    "Preferences measured from 4.1 million Victorian ballots at the 2025 Senate election (no group voting tickets since 2026), each group's voters following that party's Senate voters."
                  else "Preferences assumed, not measured: same-bloc groups favoured about 2.5 to 1, 5-30% of votes exhaust at each exclusion.")),
  OUT, auto_unbox = TRUE, digits = NA)
cat(sprintf("UHF9  wrote %s: %d simulations, %d regions, %d bytes
", OUT, N, length(regions), file.size(OUT)))
