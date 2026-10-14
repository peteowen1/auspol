# Time-forward blend of the results-based flow estimate and the nearest earlier published flows,
# for state elections with no published distribution of preferences.
#
# Decision (Pete, 2026-10-13, docs/plans/flow-estimation-from-results-2026-10-13.md "Decision"):
# blend (a) the estimate from the election's own results (output/flows-estimated.csv) with
# (b) the nearest earlier published flows ("borrow"), the blend weight LEARNED ONLY FROM EARLIER
# ELECTIONS WITH OFFICIAL FLOWS. Federal flows use the AEC's tables directly and are not blended.
#
# Output: output/flows-state-blend.csv (percent units, same shape as load_preference_flows()),
#         output/flows-key-table.csv (cache of the answer keys; delete it to rebuild),
#         a section "Time-forward blend (2026-10-13)" appended to the validation review.
# Check codes ZB1-ZB6 ("ZB" is unused elsewhere).
#
# Run: powershell.exe -Command 'Rscript "scripts/build_state_flow_blend.R"'
#
# THE RULE (fixed before looking at the backtest):
#   cell        = one election x one party class, percent of the class's first preferences to Labor.
#   u = est - borrow,  v = key - borrow.  Blend = borrow + w * u, so the error of the blend is w*u - v.
#   w_T         = argmin over cells of elections dated STRICTLY EARLIER (by year) than T of
#                 sum omega (w u - v)^2, omega = sqrt(key first preferences), shrunk toward W0 = 0.5
#                 by a ridge of N0 pseudo-cells:  w = (sum omega u v + lam * W0) / (sum omega u^2 + lam),
#                 lam = N0 * mean(omega u^2) over those prior cells; clipped to [0, 1]. No earlier key: w = W0.
#   per class   = the same fit within a class, shrunk toward the pooled w with NC0 pseudo-cells.
#   Cells enter the fit only if the class holds >= 5 key seats and >= 20,000 key first preferences.
#   Used for exhaust as well: the same w (exhaust is zero for compulsory-preferential elections).
N0 <- 10; NC0 <- 5; W0 <- 0.5; MIN_SEATS_CELL <- 5L; MIN_VOTES_CELL <- 20000
PERCLASS_MARGIN <- 0.25   # per-class weights are used only if they beat the pooled weight by this many points out of sample

options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
say <- function(...) cat(sprintf(...), "\n", sep = "")
BLEND_OUT <- "output/flows-state-blend.csv"; KEYCACHE <- "output/flows-key-table.csv"
ZB_REVIEW <- "docs/reviews/flow-estimation-validation-2026-10-13.md"
MINORS <- c("GRN", "ONP", "OTH", "OTH_RIGHT", "IND")

# ---- 1. answer keys ------------------------------------------------------------------------
if (file.exists(KEYCACHE)) {
  KT <- fread(KEYCACHE); say("ZB1  keys read from cache %s (%d rows)", KEYCACHE, nrow(KT))
} else {
  say("ZB1  rebuilding keys with the validation script's own loaders (no edits to it)")
  src <- readLines("scripts/estimate_flows_from_results.R")
  mark <- grep("^# ---- run: seat tables, keys", src)
  stopifnot(length(mark) == 1)
  # eval is intentional and safe: it runs this repo's own validation script header (function definitions) unedited
  eval(parse(text = src[seq_len(mark - 1)]), envir = globalenv())
  KEYS <- list()
  for (i in seq_len(nrow(ELS))) {
    el <- ELS$election[i]; rg <- ELS$region[i]; yr <- ELS$year[i]; op <- ELS$optional[i]
    tr_el <- TX[TX$election == el]
    if (!((rg == "fed" && yr >= 2004) || nrow(tr_el))) next
    L <- load_election(rg, yr, el, op); S <- build_seats(L, el)$S
    k <- if (rg == "fed" && yr >= 2004) fed_key_object(yr) else key_for_election(S, tr_el, L$fp, op)
    if (!is.null(k)) { KEYS[[el]] <- k$key[, .(party, a, e, n_seats, F_votes)]
                       KEYS[[el]][, `:=`(election = el, region = rg, year = yr)]; say("     key %s", el) }
  }
  KT <- rbindlist(KEYS); fwrite(KT, KEYCACHE)
}
# federal 2007+: the AEC's official national class flows replace the reconstruction
AEC <- fread("output/aec-tpp-flows.csv")[row_type == "national_class"]
EST <- fread(Sys.getenv("ZB_EST", "output/flows-estimated.csv"))   # ZB_EST: read the estimates from another path
FO <- AEC[, .(election = paste0("fed", year), region = "fed", year = as.integer(year), party = party_class,
              a = flow_alp / 100, e = 0, F_votes = alp_votes + lnp_votes)]
FO <- merge(FO, EST[region == "fed", .(election, party, n_seats)], by = c("election", "party"), all.x = TRUE)
FO[is.na(n_seats), n_seats := 0L]
KT <- rbind(KT[!(region == "fed" & year >= 2007)], FO[, names(KT), with = FALSE])
KT <- KT[party %in% MINORS]
stopifnot(!anyDuplicated(KT[, .(election, party)]))
say("ZB1  keys: %d cells, %d elections (%s)", nrow(KT), uniqueN(KT$election), paste(sort(unique(KT$election)), collapse = " "))
KEYED <- unique(KT$election)

# ---- 2. borrow: nearest earlier keyed same-region election, else strictly earlier federal ------
borrow_for <- function(rg, yr) {
  have <- unique(KT[, .(election, region, year)])
  cand <- have[region == rg & year < yr][order(-year)]
  if (!nrow(cand) && rg != "fed") cand <- have[region == "fed" & year < yr][order(-year)]
  if (!nrow(cand)) return(NULL)
  k <- KT[election == cand$election[1]]
  a <- setNames(rep(NA_real_, 5), MINORS); e <- a; a[k$party] <- k$a; e[k$party] <- k$e
  thin <- !(MINORS %in% k[n_seats >= 3 & is.finite(a)]$party) | is.na(a)   # class missing or thin: class mean
  if (any(thin)) { kk <- k[is.finite(a) & is.finite(e)]
    a[thin] <- weighted.mean(kk$a, kk$F_votes); e[thin] <- weighted.mean(kk$e, kk$F_votes) }
  list(a = a, e = e, source = cand$election[1])
}

# ---- 3. cells: estimate, borrow, key -----------------------------------------------------------
CELL <- rbindlist(lapply(unique(EST$election), function(el) {
  d <- EST[election == el]; b <- borrow_for(d$region[1], d$year[1])
  d[, `:=`(est_a = flow_alp, est_e = exhaust,
           borrow_a = if (is.null(b)) NA_real_ else 100 * b$a[party],
           borrow_e = if (is.null(b)) NA_real_ else 100 * b$e[party],
           borrow_src = if (is.null(b)) NA_character_ else b$source)]
  d }))
CELL <- merge(CELL, KT[, .(election, party, key_a = 100 * a, key_e = 100 * e, key_votes = F_votes, key_seats = n_seats)],
              by = c("election", "party"), all.x = TRUE)
CELL[, keyed := election %in% KEYED]
CELL[, usable := keyed & !is.na(key_a) & !is.na(borrow_a) & key_votes >= MIN_VOTES_CELL & key_seats >= MIN_SEATS_CELL]
CELL[, `:=`(u = est_a - borrow_a, v = key_a - borrow_a, om = sqrt(key_votes))]
say("ZB2  cells: %d total, %d usable for fitting/backtest, %d elections keyed, %d unkeyed",
    nrow(CELL), sum(CELL$usable), length(KEYED), uniqueN(CELL[keyed == FALSE]$election))

# ---- 4. time-forward weight --------------------------------------------------------------------
fit_pool <- function(P) {          # P = prior usable cells
  if (!nrow(P)) return(W0)
  lam <- N0 * mean(P$om * P$u^2)
  if (!is.finite(lam) || lam <= 0) return(W0)
  min(1, max(0, (sum(P$om * P$u * P$v) + lam * W0) / (sum(P$om * P$u^2) + lam)))
}
fit_class <- function(P, cls, wpool) {
  if (!nrow(P)) return(wpool)
  lam <- NC0 * mean(P$om * P$u^2); Pc <- P[party == cls]
  if (!is.finite(lam) || lam <= 0 || !nrow(Pc)) return(wpool)
  min(1, max(0, (sum(Pc$om * Pc$u * Pc$v) + lam * wpool) / (sum(Pc$om * Pc$u^2) + lam)))
}
weights_for <- function(yr) {      # weights for a target election dated `yr`
  P <- CELL[usable == TRUE & year < yr]
  wp <- fit_pool(P)
  list(pooled = wp, cls = setNames(sapply(MINORS, function(c) fit_class(P, c, wp)), MINORS),
       n_keys = uniqueN(P$election), n_cells = nrow(P), P = P)
}

# ---- 5. out-of-sample backtest -----------------------------------------------------------------
BT <- CELL[usable == TRUE]
BT[, c("w_pool", "w_cls", "n_keys") := {
  r <- weights_for(year[1]); .(r$pooled, r$cls[party], r$n_keys) }, by = election]
BT[, `:=`(err_est = est_a - key_a, err_bor = borrow_a - key_a,
          err_blend = borrow_a + w_pool * (est_a - borrow_a) - key_a,
          err_blendc = borrow_a + w_cls * (est_a - borrow_a) - key_a,
          err_50 = borrow_a + 0.5 * (est_a - borrow_a) - key_a)]
# a false-pass guard: the same rule on a deliberately wrong key (labels shuffled across classes within an election)
set.seed(20261013)
BT[, key_shuf := sample(key_a), by = election]
bad <- BT[, mean(abs(borrow_a + w_pool * (est_a - borrow_a) - key_shuf))]
good <- BT[, mean(abs(err_blend))]
say("ZB3  guard: blend MAE %.2f on the real key vs %.2f on a key shuffled across classes within each election (must be much worse)", good, bad)
stopifnot(bad > good)

sm <- function(d, nm) d[, .(set = nm, cells = .N, elections = uniqueN(election),
                            est_MAE = mean(abs(err_est)), borrow_MAE = mean(abs(err_bor)),
                            blend50_MAE = mean(abs(err_50)), blend_tf_MAE = mean(abs(err_blend)),
                            blend_tf_class_MAE = mean(abs(err_blendc)), mean_w = mean(w_pool))]
BTM <- rbind(sm(BT, "all keyed elections"),
             sm(BT[n_keys > 0], "... with >= 1 earlier key"),
             sm(BT[region == "fed"], "federal (AEC official key 2007+)"),
             sm(BT[region != "fed"], "states (reconstructed key)"),
             sm(BT[region != "fed" & n_keys > 0], "states, >= 1 earlier key"),
             sm(BT[party %in% c("GRN", "ONP")], "Greens and One Nation only"),
             sm(BT[party %in% c("GRN", "ONP") & region != "fed"], "Greens and One Nation, states"))
BTM[, (setdiff(names(BTM), c("set", "cells", "elections"))) := lapply(.SD, round, 2),
    .SDcols = setdiff(names(BTM), c("set", "cells", "elections"))]
cat("\nZB4  Out-of-sample backtest. Mean absolute error of the Labor-flow share, points (lower is better).\n")
cat("     est = results-only estimate; borrow = nearest earlier published flows; blend50 = fixed 50/50;\n")
cat("     blend_tf = pooled weight fitted on strictly earlier keys; blend_tf_class = per-class weights likewise.\n")
print(BTM, nrows = 50)
# exhaust, optional-preferential elections only
EXH <- BT[(region == "nsw") | (region == "qld" & year < 2017)]
EXH[, `:=`(ee_est = est_e - key_e, ee_bor = borrow_e - key_e, ee_bl = borrow_e + w_pool * (est_e - borrow_e) - key_e)]
EXM <- EXH[, .(cells = .N, est_MAE = round(mean(abs(ee_est)), 2), borrow_MAE = round(mean(abs(ee_bor)), 2),
               blend_tf_MAE = round(mean(abs(ee_bl)), 2))]
cat("\nZB4  Exhaust on optional-preferential elections (NSW, Qld before 2017), points of the class's ballots, lower is better\n")
print(EXM)
# per election, to show where it wins and loses
PE <- BT[, .(cells = .N, n_keys = n_keys[1], w = round(w_pool[1], 2), est = round(mean(abs(err_est)), 2),
             borrow = round(mean(abs(err_bor)), 2), blend_tf = round(mean(abs(err_blend)), 2)), by = election][order(election)]
cat("\nZB4  Per election: MAE points (lower is better); w = estimate share fitted on earlier keys.\n"); print(PE, nrows = 100)
# paired election-level comparison (clustered on the election, the independent unit)
PD <- BT[, .(d_bor = mean(abs(err_blend)) - mean(abs(err_bor)), d_est = mean(abs(err_blend)) - mean(abs(err_est))), by = election]
pd <- function(x) sprintf("mean %.2f, se %.2f, blend better in %d of %d elections", mean(x), sd(x) / sqrt(length(x)), sum(x < 0), length(x))
say("ZB4  election-level difference in MAE, blend_tf minus borrow: %s", pd(PD$d_bor))
say("ZB4  election-level difference in MAE, blend_tf minus estimate: %s", pd(PD$d_est))
use_class <- BTM[set == "all keyed elections", blend_tf_class_MAE] <= BTM[set == "all keyed elections", blend_tf_MAE] - PERCLASS_MARGIN
say("ZB4  per-class weights beat pooled by >= %.2f points out of sample: %s -> using %s weights", PERCLASS_MARGIN,
    use_class, if (use_class) "per-class" else "pooled")

# ---- 6. apply to every state election without a published distribution --------------------------
TG <- CELL[keyed == FALSE & region != "fed"]
SB <- unique(TG[, .(election, region, year)])
WT <- rbindlist(lapply(seq_len(nrow(SB)), function(i) {
  r <- weights_for(SB$year[i]); data.table(election = SB$election[i], w_pool = r$pooled,
    n_prior_keys = r$n_keys, n_prior_cells = r$n_cells, t(r$cls)) }))
sdb <- function(P, col) if (nrow(P) > 5) sqrt(mean(P[[col]]^2)) else 5   # borrow RMSE on earlier keys, points
OUTL <- rbindlist(lapply(seq_len(nrow(SB)), function(i) {
  el <- SB$election[i]; d <- TG[election == el]; wt <- WT[election == el]
  P <- BT[year < SB$year[i]]; s_b <- sdb(P, "err_bor")
  w <- if (use_class) as.numeric(wt[, ..MINORS][, d$party, with = FALSE]) else rep(wt$w_pool, nrow(d))
  nob <- is.na(d$borrow_a); w[nob] <- 1                                      # nothing earlier to borrow: estimate only
  ba <- ifelse(nob, 0, d$borrow_a); be <- ifelse(nob, 0, d$borrow_e)
  se_e <- d$se_flow; se_e[is.na(se_e)] <- 5
  se_x <- d$se_exhaust; se_x[is.na(se_x)] <- 5
  data.table(election = el, region = d$region, year = d$year, party = d$party,
             flow_alp = round(w * d$est_a + (1 - w) * ba, 2), exhaust = round(w * d$est_e + (1 - w) * be, 2),
             se_flow = round(sqrt((w * se_e)^2 + ((1 - w) * s_b)^2), 2),
             se_exhaust = round(sqrt((w * se_x)^2 + ((1 - w) * s_b)^2), 2),
             w = round(w, 3), n_prior_keys = wt$n_prior_keys, borrow_source = d$borrow_src,
             source = ifelse(nob, "estimate_only_no_earlier_flows", "blend"))
}))
stopifnot(!anyNA(OUTL$flow_alp), all(OUTL$flow_alp >= 0 & OUTL$flow_alp <= 100), !anyDuplicated(OUTL[, .(election, party)]),
          all(OUTL$exhaust >= -1e-6 & OUTL$exhaust <= 100))
fwrite(OUTL, BLEND_OUT)
say("ZB5  wrote %s: %d rows, %d elections (%s)", BLEND_OUT, nrow(OUTL), uniqueN(OUTL$election), paste(unique(OUTL$election), collapse = " "))
# coverage assertion: every column populated
for (cl in names(OUTL)) if (cl != "borrow_source") stopifnot(!anyNA(OUTL[[cl]]))
say("ZB5  NA borrow_source rows (estimate only, no earlier flows to borrow): %d", sum(is.na(OUTL$borrow_source)))

WTT <- merge(unique(OUTL[, .(region, year, n_prior_keys, borrow_source, estimate_only = any(source != "blend")), by = election]),
             WT[, .(election, w = round(w_pool, 3))], by = "election")[, .(election, region, year, w, n_prior_keys, borrow_source, estimate_only)]
setorder(WTT, year, region)
cat("\nZB6  Blend weight on the estimate (pooled) by target election, fitted on strictly earlier keyed elections.\n"); print(WTT, nrows = 100)
PER <- WTT[, .(elections = .N, mean_w = round(mean(w), 2), min_w = min(w), max_w = max(w)),
           by = .(period = cut(year, c(2000, 2008, 2014, 2030), c("2001-2008", "2009-2014", "2015-2026")))][order(period)]
cat("\nZB6  Weight by period (mean over target elections)\n"); print(PER)
WCL <- weights_for(2027)
cat("\nZB6  Latest fit (all keys to date): pooled w =", round(WCL$pooled, 3), "; per class:",
    paste(MINORS, round(WCL$cls, 2), collapse = " "), "; cells =", WCL$n_cells, "\n")

# ---- 7. review section ----------------------------------------------------------------------------
tbl <- function(d) { d <- as.data.frame(d); c(paste0("| ", paste(names(d), collapse = " | "), " |"),
                     paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
                     apply(d, 1, function(r) paste0("| ", paste(trimws(r), collapse = " | "), " |"))) }
fmt <- function(d) { d <- copy(d); for (cl in names(d)) if (is.numeric(d[[cl]]) && !is.integer(d[[cl]])) d[[cl]] <- formatC(d[[cl]], format = "f", digits = 2); d }
md <- c("## Time-forward blend (2026-10-13)", "",
  "Script: `scripts/build_state_flow_blend.R` (check codes ZB1-ZB6). Output: `output/flows-state-blend.csv`; answer keys cached in `output/flows-key-table.csv`. Federal elections 2007 onward use the AEC's official table as the key (and are not blended); every other key is the corrected reconstruction.", "",
  sprintf("Rule, fixed before the backtest was looked at: blend = borrow + w * (estimate - borrow). For a target election dated year T, w minimises sqrt(key first preferences)-weighted squared error over cells (election x party class, at least 5 key seats and 20,000 key first preferences) from elections dated STRICTLY EARLIER than T, ridge-shrunk toward 0.5 with a prior strength of %d pseudo-cells (a pseudo-cell is one average cell's worth of evidence), clipped to 0..1; with no earlier key, w = 0.5. Borrow is the nearest earlier published flows in the same state, else the nearest strictly earlier federal election. The same w is applied to exhaust.", N0), "",
  sprintf("Pooled or per class: %s. Per-class weights (shrunk toward the pooled weight with %d pseudo-cells) were compared out of sample on the same backtest; they were adopted only if they beat the pooled weight by %.2f points of mean error. Result: per-class %.2f vs pooled %.2f, so %s weights are used (the evidence for class-specific weights is thin: a few dozen cells per class, few elections).",
          if (use_class) "per class" else "pooled", NC0, PERCLASS_MARGIN,
          BTM[set == "all keyed elections", blend_tf_class_MAE], BTM[set == "all keyed elections", blend_tf_MAE],
          if (use_class) "per-class" else "pooled"), "",
  "### Out-of-sample backtest", "",
  "What the numbers are: mean absolute error of the Labor-flow share in points (lower is better) on keyed elections, each scored with a weight fitted only on strictly earlier keys. est = results-only estimate, borrow = nearest earlier published flows, blend50 = fixed 50/50, blend_tf = pooled time-forward blend, blend_tf_class = per-class time-forward blend, mean_w = average weight on the estimate.", "",
  tbl(fmt(BTM)), "",
  sprintf("Election-level difference in mean error (blend_tf minus borrow): %s. Blend_tf minus estimate: %s. The election is the independent unit.", pd(PD$d_bor), pd(PD$d_est)), "",
  "What the numbers are: exhaust (share of the class's ballots reaching neither major party) on optional-preferential elections, mean absolute error in points, lower is better.", "",
  tbl(fmt(EXM)), "",
  "Per election: mean absolute error in points over the bar-sized cells (lower is better); w = weight on the estimate fitted from earlier keys; n_keys = earlier keyed elections.", "",
  tbl(fmt(PE)), "",
  "### Weights for the unkeyed state elections", "",
  "What the numbers are: w = share of the estimate in the blend (1 = estimate only, 0 = borrow only), fitted on keyed elections dated strictly earlier; n_prior_keys = number of those elections; borrow_source = the election whose flows are borrowed.", "",
  tbl(fmt(WTT)), "",
  tbl(fmt(PER)), "",
  sprintf("Latest fit on all keys to date (for elections after 2026): pooled w = %.2f from %d cells.", WCL$pooled, WCL$n_cells), "",
  "Limits: (1) the state keys are reconstructions, calibrated only on the federal Greens and One Nation, so for state targets the weight is fitted to a key whose bias is unmeasured; (2) the estimate already shrinks toward the same borrow (its own pool weight), so the blend weight is a second layer on the same prior; (3) early weights rest on few keys (see n_prior_keys), and the first keyed years have w = 0.5 by default; (4) Qld 2001 and any election with no earlier flows get the estimate alone (source column); (5) the standard errors combine the estimate's own bootstrap se with the borrow's out-of-sample error from earlier keys (5 points where fewer than 6 earlier cells) and assume the two errors are independent, which they are not (both lean on the same prior).", "")
rv <- readLines(ZB_REVIEW); st <- grep("^## Time-forward blend \\(2026-10-13\\)", rv)
if (length(st)) rv <- rv[seq_len(st[1] - 1)]
writeLines(c(rv, "", md), ZB_REVIEW)
say("ZB6  appended section to %s", ZB_REVIEW)
