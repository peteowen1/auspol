# Score docs/plans/prereg-night-candidate-ref-2026-11-11.md: night booth reference by candidate (cand_ref) against
# base, both ways on the same seeds.
#
#   Rscript scripts/score_night_cand_ref.R <job dir> [copy]   (copy: the known answers of the copy prereg)
#
# <job dir>/sim/<pair>-{base,cr}/night-f*.json   simulated replays (scripts/night_replay_json.R), 6 pairs + vic2022
# <job dir>/real/<night>-{base,cr}-seats.csv     real-night replays (night_replay_feed.R), fed2022 and fed2025
# Targets: candidates in the same seat at the previous election under a different class, from the night booth tables
# (output/booths-<pair>.csv, the same match night_booth_update() makes). Seat-winner log loss, eps 1e-6 (real) and
# 0.5 / n_sims (simulated, as the replays score), averaged over fractions >= 0.05 / counted times. Lower is better.
# Check codes NCR0-NCR4.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
d <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(d) || !dir.exists(d)) stop("NCR0! usage: score_night_cand_ref.R <job dir>")
P <- fread("output/published-predictions.csv", showProgress = FALSE); P <- P[P$won == TRUE, list(pair, seat, winner = party)]
nm <- function(x) gsub("[^a-z]", "", tolower(x))
prev_of <- c(fed2022 = "fed2019", fed2025 = "fed2022", nsw2023 = "nsw2019", qld2024 = "qld2020", sa2026 = "sa2022",
             wa2025 = "wa2021", vic2022 = "vic2018")
targets <- rbindlist(lapply(names(prev_of), function(p) {
  L <- fread(sprintf("output/booths-%s.csv", p), showProgress = FALSE); R <- fread(sprintf("output/booths-%s.csv", prev_of[[p]]), showProgress = FALSE)
  a <- unique(L[nzchar(L$candidate), list(seat = district, k = nm(candidate), candidate, now = classify_party(party))])
  b <- unique(R[nzchar(R$candidate), list(seat = district, k = nm(candidate), then = classify_party(party))])
  m <- merge(a, b, by = c("seat", "k")); m <- m[m$now != m$then]
  if (nrow(m)) m[, pair := p] else NULL
}))
cat(sprintf("NCR0 %d target candidates in %d seats over %d elections\n", nrow(targets), uniqueN(targets[, list(pair, seat)]), uniqueN(targets$pair)))
print(targets[, list(pair, seat, candidate, then, now)], nrows = 60)
tg <- unique(targets[, list(pair, seat)])[, target := TRUE]

# simulated
sim_ll <- function(dir, pr) {
  fs <- list.files(dir, pattern = "^night-f[0-9]+[.]json$", full.names = TRUE)
  if (!length(fs)) stop("NCR1! no replay json in ", dir)
  rbindlist(lapply(fs, function(f) { j <- jsonlite::fromJSON(f, simplifyVector = FALSE); fr <- as.numeric(j$night$fraction %||% NA)
    if (is.na(fr)) fr <- as.numeric(sub("^night-f([0-9]+)[.]json$", "\\1", basename(f))) / 1000
    rows <- rbindlist(lapply(j$seats, function(s) data.table(seat = s$seat, party = vapply(s$parties, function(p) p$party, ""),
                                                            prob = vapply(s$parties, function(p) as.numeric(p$win_prob), 0))))
    w <- merge(P[P$pair == pr], rows, by.x = c("seat", "winner"), by.y = c("seat", "party"), all.x = TRUE); w[is.na(prob), prob := 0]
    tot <- rows[, list(s = sum(prob)), by = seat]
    w[, list(seat, frac = fr, ll = -log(pmax(prob, 0.5 / as.numeric(j$n_sims))), max_sum = max(tot$s))] }))
}
`%||%` <- function(a, b) if (is.null(a)) b else a
S <- list(); missing <- character(0)
for (pr in names(prev_of)) {
  b <- file.path(d, "sim", sprintf("%s-base", pr)); r <- file.path(d, "sim", sprintf("%s-cr", pr))
  if (!dir.exists(b) || !dir.exists(r)) { cat(sprintf("NCR1 %s: simulated replay missing, skipped\n", pr)); missing <- c(missing, pr); next }
  x <- merge(sim_ll(b, pr)[, list(seat, frac, ll_base = ll)], sim_ll(r, pr)[, list(seat, frac, ll_cr = ll, max_sum)], by = c("seat", "frac"))
  S[[pr]] <- x[frac >= 0.05][, pair := pr]
}
S <- rbindlist(S)
seat_s <- S[, list(base = mean(ll_base), cr = mean(ll_cr), max_sum = max(max_sum)), by = list(pair, seat)]
seat_s <- merge(seat_s, tg, by = c("pair", "seat"), all.x = TRUE); seat_s[is.na(target), target := FALSE]; seat_s[, d := cr - base]

# real nights
R <- list()
for (nt in c("fed2022", "fed2025")) {   # vic2022 real night not run: prereg amendment (no candidate names in the VEC table)
  fb <- file.path(d, "real", sprintf("%s-base-seats.csv", nt)); fc <- file.path(d, "real", sprintf("%s-cr-seats.csv", nt))
  if (!file.exists(fb) || !file.exists(fc)) { cat(sprintf("NCR2 %s: real-night replay missing, skipped\n", nt)); missing <- c(missing, paste0(nt, "-real")); next }
  rd <- function(f) { W <- fread(f, showProgress = FALSE); W[, time := as.character(time)]
    sm <- fread(sub("-seats[.]csv$", "-summary.csv", f), showProgress = FALSE); tm <- as.character(sm$time[sm$mean_counted > 0])
    w <- CJ(seat = P$seat[P$pair == nt], time = tm); w <- merge(w, P[P$pair == nt, list(seat, winner)], by = "seat")
    w <- merge(w, W[, list(seat, party, time, prob)], by.x = c("seat", "winner", "time"), by.y = c("seat", "party", "time"), all.x = TRUE)
    w[is.na(prob), prob := 0]; tot <- W[, list(s = sum(prob)), by = list(seat, time)]
    w[, list(ll = mean(-log(pmax(prob, 1e-6)))), by = seat][, max_sum := max(tot$s)] }
  x <- merge(rd(fb)[, list(seat, base = ll)], rd(fc)[, list(seat, cr = ll, max_sum)], by = "seat")
  R[[nt]] <- x[, pair := nt]
}
R <- rbindlist(R)
if (nrow(R)) { R <- merge(R, tg, by = c("pair", "seat"), all.x = TRUE); R[is.na(target), target := FALSE]; R[, d := cr - base] }

rep_block <- function(X, what) {
  cat(sprintf("\n== %s: night-average seat-winner log loss, cand_ref minus base (lower is better) ==\n", what))
  if (!nrow(X)) { cat("nothing scored\n"); return(invisible(NULL)) }
  by_p <- X[, list(seats = .N, targets = sum(target), all_diff = mean(d), tgt_diff = if (any(target)) mean(d[target]) else NA_real_,
                   nontarget_max_abs = if (any(!target)) max(abs(d[!target])) else 0, max_sum = max(max_sum)), by = pair]
  print(by_p, digits = 4)
  t <- X[X$target]
  pr <- if (nrow(t)) c(diff = mean(t$d), se = if (nrow(t) > 1) sd(t$d) / sqrt(nrow(t)) else NA_real_, n = nrow(t)) else c(diff = NA, se = NA, n = 0)
  cat(sprintf("PRIMARY (%s, %d target seats): %+.5f (SE %.5f)\n", what, pr[["n"]], pr[["diff"]], pr[["se"]]))
  cat("per target seat:\n"); print(t[order(d), list(pair, seat, base, cr, d)], digits = 3)
  list(by_p = by_p, pr = pr)
}
a <- rep_block(seat_s, "SIMULATED replays")
b <- rep_block(R, "REAL-NIGHT replays")
# known answers. move prereg: Mirani qld2024 LNP above base at fraction 1. copy prereg
# (prereg-night-candidate-ref-copy-2026-11-11.md, second argument "copy"): Mirani at fraction 0.5, and Monash fed2025
# (simulated) not worse than base by more than 0.01.
copy_rule <- identical(commandArgs(trailingOnly = TRUE)[2], "copy")
mir_f <- if (copy_rule) "night-f500.json" else "night-f1000.json"
mir <- function(v) { f <- file.path(d, "sim", sprintf("qld2024-%s", v), mir_f); if (!file.exists(f)) return(NA_real_)
  j <- jsonlite::fromJSON(f, simplifyVector = FALSE); s <- Filter(function(x) x$seat == "Mirani", j$seats)[[1]]
  p <- Filter(function(x) x$party == "LNP", s$parties); if (length(p)) as.numeric(p[[1]]$win_prob) else 0 }
mb <- mir("base"); mc <- mir("cr")
cat(sprintf("\nNCR3 known answer (%s rule), Mirani qld2024 LNP at %s: base %.3f, cand_ref %.3f => %s\n", if (copy_rule) "copy" else "move",
            mir_f, mb, mc, if (isTRUE(mc > mb)) "HOLDS" else "FAILS"))
mon_ok <- TRUE
if (copy_rule) {
  md <- seat_s[pair == "fed2025" & seat == "Monash"]$d
  mon_ok <- length(md) == 1L && isTRUE(md <= 0.01)
  cat(sprintf("NCR3 known answer (copy rule), Monash fed2025 simulated, copy minus base %s (limit +0.01) => %s\n",
              if (length(md)) sprintf("%+.4f", md) else "MISSING", if (mon_ok) "HOLDS" else "FAILS"))
}
vic_same <- if (!is.null(a) && "vic2022" %in% a$by_p$pair) isTRUE(a$by_p[pair == "vic2022"]$nontarget_max_abs == 0) else NA
guard <- function(z) if (is.null(z)) TRUE else all(z$by_p$all_diff <= 0.002)
sums <- function(z) if (is.null(z)) TRUE else all(z$by_p$max_sum <= 1 + 1e-6)
prim <- c(if (!is.null(a)) a$pr[["diff"]], if (!is.null(b)) b$pr[["diff"]])
if (length(missing)) cat(sprintf("NCR4 INCOMPLETE: %d replay(s) missing (%s): the decision below cannot pass\n", length(missing), paste(missing, collapse = ", ")))
rule <- !length(missing) && all(prim < 0, na.rm = TRUE) && length(na.omit(prim)) > 0 && guard(a) && guard(b) && isTRUE(mc > mb) && mon_ok && sums(a) && sums(b) && !isFALSE(vic_same)
cat(sprintf("NCR4 DECISION: primary falls (simulated %+.5f, real %+.5f) %s; no election worse by > 0.002 %s; Mirani %s; no seat above 1 %s; vic2022 identical %s => %s\n",
            if (!is.null(a)) a$pr[["diff"]] else NA, if (!is.null(b)) b$pr[["diff"]] else NA, all(prim < 0, na.rm = TRUE),
            guard(a) && guard(b), isTRUE(mc > mb), sums(a) && sums(b), vic_same, if (rule) "PASS" else "FAIL"))
