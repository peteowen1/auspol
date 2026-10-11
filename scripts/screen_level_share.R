# Seconds-fast screen for ideas that change the statewide level (and so the primaries).
# Fast-iteration plan 2026-10-11, Phase 1 item 4; docs/reviews/fast-iter-share-screen-2026-10-11.md.
#
# Why: the earlier 4-second share screen reported only the MEAN level error, and the mean hid the
# per-election variance that refused the 1-day decay (wa2013 +0.061). This reports, per arm PAIR:
#   1. paired per-election change in day-before level error (ALP/LNP/GRN mean absolute error)
#   2. paired per-election change in seat primary squared error (ALP/LNP/GRN cells, seat-level)
#   3. paired per-election change in a PROXY for seat-winner log loss, its worst election, the pooled
#      change with an election-clustered SE, and the same on the AEF-7 ledger seats
#
# How the proxy works (an approximation, NOT the simulation):
#   - The baseline is output/published-predictions.csv, which holds the run that is on disk. Its level
#     arm is REF_ARM below; every other arm is expressed as a level DELTA against it.
#   - A level arm's blended ALP/LNP/GRN level is recomputed by the real R/level_recent.R code
#     (level_recent_apply) from output/level-recent.csv, so the fitted k and half-life are the shipped ones.
#   - The level delta is added to every seat's primary in that class (pass-through 1), the other classes
#     absorb it pro rata (as level_recent_apply does), and each class's seat-win probability is moved by
#     log p' = log p + BETA * (primary change), renormalised over the seat. BETA is read off the
#     baseline itself (within-seat slope of log p_win on primary share), then also run at 0.5x and 2x.
#   - A class with p_win exactly 0 stays at 0 (the screen is blind to the far tail, as quick_arm is).
#
# Run (from the repo root):  powershell.exe -Command 'Rscript "scripts/screen_level_share.R"'
#   no arguments: the three 2026-10-11 validation comparisons.
#   --pairs=A|B,C|D   compare arm A against arm B (arm = none | window | decay:H | decay:fit)
#   --ref=decay:10    the level arm the published-predictions file was produced under
# Data.table NSE: no local variable shares a name with a column used inside [...]; masks are built outside.

t0 <- Sys.time()
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
suppressMessages(library(data.table))
args <- commandArgs(TRUE)
getarg <- function(nm, dflt) { a <- grep(paste0("^--", nm, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nm, "="), "", a[1]) else dflt }
REF_ARM <- getarg("ref", "decay:10")
# arm specs contain ":" so a pair is written "A|B"
PAIRS <- strsplit(getarg("pairs", "window|none,decay:10|window,decay:fit|window"), ",")[[1]]

tab <- fread(out_path("level-recent.csv"), showProgress = FALSE)
pp  <- fread(out_path("published-predictions.csv"), showProgress = FALSE)
stopifnot(nrow(pp) > 0, all(c("pair", "seat", "party", "ours", "actual", "p_win", "won") %in% names(pp)))
cat(sprintf("LS0  level table %d rows / %d elections; published predictions %d rows / %d elections / %d seats\n",
            nrow(tab), uniqueN(tab$election), nrow(pp), uniqueN(pp$pair), uniqueN(paste(pp$pair, pp$seat))))

# ---- level of an arm, per election -----------------------------------------------------------------
eds <- election_dates()
arm_env <- function(spec) {                       # sets the env switches the shipped code reads
  p <- strsplit(spec, ":", fixed = TRUE)[[1]]
  if (p[1] == "none")        { Sys.setenv(AUSPOL_LEVEL_RECENT = "0") }
  else if (p[1] == "window") { Sys.setenv(AUSPOL_LEVEL_RECENT = "1") }
  else if (p[1] == "decay")  { Sys.setenv(AUSPOL_LEVEL_RECENT = "decay", AUSPOL_LEVEL_RECENT_HALFLIFE = p[2]) }
  else stop("unknown arm ", spec)
}
arm_levels <- function(spec, verbose = FALSE) {    # list: election -> named c(ALP, LNP, GRN, OTH) after the blend
  arm_env(spec)
  cat(sprintf("LS1  ARM %s applies AUSPOL_LEVEL_RECENT=%s AUSPOL_LEVEL_RECENT_HALFLIFE=%s\n", spec,
              Sys.getenv("AUSPOL_LEVEL_RECENT"), if (startsWith(spec, "decay")) Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE") else "(unused)"))
  out <- list(); logs <- character(0)
  for (e in unique(tab$election)) {
    d <- tab[tab$election == e]
    lv <- setNames(d$trend, d$cls)
    if (any(!is.finite(lv)) || !e %in% pp$pair) next
    lv <- c(lv[c("ALP", "LNP", "GRN")], OTH = 100 - sum(lv[c("ALP", "LNP", "GRN")]))
    lg <- capture.output(res <- suppressWarnings(level_recent_apply(lv, e, d$region[1], as.Date(unname(eds[e])), code = "LS", tab = tab)))
    if (verbose) cat(lg, sep = "\n")
    logs <- c(logs, lg)
    out[[e]] <- res
  }
  hl <- unique(sub(".*half-life ([0-9.]+) days.*", "\\1", grep("half-life [0-9]", logs, value = TRUE)))
  kk <- suppressWarnings(as.numeric(sub(".*, k ([0-9.]+|Inf) .*", "\\1", logs)))
  ww <- as.numeric(sub(".*, w ([0-9.]+):.*", "\\1", logs)); kk <- kk[is.finite(kk)]
  if (!length(logs)) { cat(sprintf("     applied to %d elections: no blend (the unblended trend level)\n", length(out))); return(out) }
  cat(sprintf("     applied to %d elections: %sfitted k %.2f-%.2f; blend weight w %.2f-%.2f (median %.2f)\n", length(out),
              if (length(hl)) paste0("half-lives {", paste(hl, collapse = ", "), "} days; ") else "",
              if (length(kk)) min(kk) else NA, if (length(kk)) max(kk) else NA, min(ww), max(ww), median(ww)))
  out
}

# ---- seat table ------------------------------------------------------------------------------------
# winner class per seat and a within-seat slope of log p_win on primary share (the proxy's BETA)
pp[, sid := paste(pair, seat)]
nwin <- pp[won == TRUE, .N, by = sid]
stopifnot(all(nwin$N == 1L), nrow(nwin) == uniqueN(pp$sid))
LOSS_EPS <- 1e-6
seat_loss <- function(P) {                        # P: pp-shaped with column pw (win prob per class)
  w <- P[won == TRUE]
  data.table(sid = w$sid, pair = w$pair, ledger = !is.na(w$aef), ll = -log(pmax(w$pw, LOSS_EPS)))
}
base <- copy(pp); base[, pw := p_win]
bl <- seat_loss(base)
cat(sprintf("LS2  baseline pooled seat log loss %.4f over %d seats / %d elections (docs say 0.3181 for the 10-day run); ledger-flag seats %d\n",
            mean(bl$ll), nrow(bl), uniqueN(bl$pair), sum(bl$ledger)))

cand <- pp[p_win > 0.001 & ours > 0]
cand[, lp := log(p_win)]
cand[, `:=`(lp_c = lp - mean(lp), o_c = ours - mean(ours)), by = sid]
cand <- cand[, .SD, .SDcols = c("lp_c", "o_c", "sid")][, n := .N, by = sid][n >= 2]
BETA <- sum(cand$lp_c * cand$o_c) / sum(cand$o_c^2)
cat(sprintf("LS3  BETA (log-odds per primary point, within-seat slope over %d candidates in %d seats, p_win>0.001) = %.3f; R2 = %.2f\n",
            nrow(cand), uniqueN(cand$sid), BETA, 1 - sum((cand$lp_c - BETA * cand$o_c)^2) / sum(cand$lp_c^2)))

# ---- shifted predictions for a level arm relative to the reference ----------------------------------
shift_seats <- function(lev_arm, lev_ref, beta) {
  P <- copy(pp)
  P[, dprim := 0]
  P[, lvl_err_flag := 0]
  for (e in names(lev_arm)) {
    if (is.null(lev_ref[[e]])) next
    da <- lev_arm[[e]]; dr <- lev_ref[[e]]
    delta <- da[c("ALP", "LNP", "GRN")] - dr[c("ALP", "LNP", "GRN")]
    fo <- if (dr["OTH"] > 0) da["OTH"] / dr["OTH"] else 1
    rowsel <- which(P$pair == e)                  # indices computed outside [ ]
    pty <- P$party[rowsel]; o <- P$ours[rowsel]
    P$dprim[rowsel] <- ifelse(pty %in% names(delta), delta[pty], o * (fo - 1))
  }
  P[, ours_new := pmax(0, ours + dprim)]
  P[, pw_raw := p_win * exp(beta * (ours_new - ours))]
  P[, pw := pw_raw / sum(pw_raw), by = sid]
  P[, dsq := (ours_new - actual)^2 - (ours - actual)^2]
  P
}

lvl_err <- function(lev) rbindlist(lapply(names(lev), function(e) {
  d <- tab[tab$election == e]
  data.table(election = e, err = mean(abs(lev[[e]][d$cls] - d$actual)))
}))

# ---- compare two arms ---------------------------------------------------------------------------------
cluster_se <- function(dt, valcol) {              # seat-pooled mean difference, SE clustered on election
  g <- dt[, list(n = .N, m = mean(get(valcol))), by = "pair"]
  D <- sum(g$n * g$m) / sum(g$n); G <- nrow(g)
  se <- sqrt(G / (G - 1)) * sqrt(sum((g$n * (g$m - D))^2)) / sum(g$n)
  c(D = D, se = se)
}
compare <- function(a, b, beta, lev, show_elections = TRUE) {
  Sa <- shift_seats(lev[[a]], lev[[REF_ARM]], beta); Sb <- shift_seats(lev[[b]], lev[[REF_ARM]], beta)
  la <- seat_loss(Sa); lb <- seat_loss(Sb)
  stopifnot(identical(la$sid, lb$sid))
  la[, d := ll - lb$ll]                           # arm a minus arm b; negative = a better
  ea <- lvl_err(lev[[a]]); eb <- lvl_err(lev[[b]])
  lv <- merge(ea, eb, by = "election"); lv[, dlvl := err.x - err.y]
  sq <- merge(Sa[, list(a = mean(dsq)), by = list(election = pair)], Sb[, list(b = mean(dsq)), by = list(election = pair)], by = "election")
  sq[, dsq := a - b]
  pe <- la[, list(n = .N, d = mean(d)), by = list(election = pair)]
  pe <- merge(pe, lv[, list(election, dlvl)], by = "election"); pe <- merge(pe, sq[, list(election, dsq)], by = "election")
  setorder(pe, d)
  pooled <- cluster_se(la, "d"); led <- cluster_se(la[ledger == TRUE], "d")
  list(pe = pe, pooled = pooled, led = led, nled = sum(la$ledger),
       worst = pe[which.max(pe$d)], best = pe[which.min(pe$d)], nbetter = sum(pe$d < 0), G = nrow(pe), nseat = nrow(la),
       dlvl_mean = mean(pe$dlvl), dlvl_worst = max(pe$dlvl), dsq_mean = mean(pe$dsq))
}

arms <- unique(c(REF_ARM, unlist(strsplit(PAIRS, "|", fixed = TRUE))))
lev <- setNames(lapply(arms, arm_levels), arms)

report <- function(r, a, b, tag) {
  cat(sprintf("\nLS4  %s: arm %s MINUS arm %s  (negative = %s better; %d elections, %d seats, %d ledger-flag seats)\n", tag, a, b, a, r$G, r$nseat, r$nled))
  cat(sprintf("     seat log loss proxy, pooled change %+.4f (SE %.4f, clustered on election); better in %d of %d elections\n",
              r$pooled["D"], r$pooled["se"], r$nbetter, r$G))
  cat(sprintf("     worst single election %s %+.4f; best %s %+.4f\n", r$worst$election, r$worst$d, r$best$election, r$best$d))
  cat(sprintf("     ledger-flag seats: pooled change %+.4f (SE %.4f)\n", r$led["D"], r$led["se"]))
  cat(sprintf("     day-before level MAE (ALP/LNP/GRN), mean per-election change %+.3f pts, worst election %+.3f\n", r$dlvl_mean, r$dlvl_worst))
  cat(sprintf("     seat primary squared error (ALP/LNP/GRN/other cells), mean per-election change %+.3f pts^2\n", r$dsq_mean))
}
results <- list()
for (pr in PAIRS) {
  ab <- strsplit(pr, "|", fixed = TRUE)[[1]]
  r <- compare(ab[1], ab[2], BETA, lev); results[[pr]] <- r
  report(r, ab[1], ab[2], "proxy at fitted BETA")
  cat("     per election (seat log loss change | level MAE change | primary sq-err change):\n")
  print(r$pe[, list(election, n, d = round(d, 4), dlvl = round(dlvl, 3), dsq = round(dsq, 3))], row.names = FALSE)
  for (m in c(0.5, 2)) {
    rm <- compare(ab[1], ab[2], BETA * m, lev)
    cat(sprintf("     BETA x%.1f: pooled %+.4f (SE %.4f), worst %s %+.4f\n", m, rm$pooled["D"], rm$pooled["se"], rm$worst$election, rm$worst$d))
  }
}

# ---- controls: the screen must read ZERO where nothing changed and respond where something did --------
rc <- compare(REF_ARM, REF_ARM, BETA, lev)
cat(sprintf("\nLS5  control 1, reference vs itself: pooled %+.6f, worst %+.6f (must be exactly 0)\n", rc$pooled["D"], rc$worst$d))
r0 <- compare(arms[min(2, length(arms))], REF_ARM, 0, lev)
cat(sprintf("LS5  control 2, BETA = 0 (no seat response): pooled %+.6f (must be exactly 0)\n", r0$pooled["D"]))
bad <- lev[[REF_ARM]]; for (e in names(bad)) bad[[e]] <- bad[[e]] + c(ALP = -3, LNP = 3, GRN = 0, OTH = 0)
lev$broken <- bad
rb <- compare("broken", REF_ARM, BETA, lev)
cat(sprintf("LS5  control 3, deliberately broken arm (LNP +3, ALP -3 everywhere): pooled %+.4f, worst %s %+.4f (must be clearly non-zero)\n",
            rb$pooled["D"], rb$worst$election, rb$worst$d))
cat(sprintf("\nLS6  runtime %.1f s for %d arms and %d comparisons\n", as.numeric(difftime(Sys.time(), t0, units = "secs")), length(arms), length(PAIRS)))
