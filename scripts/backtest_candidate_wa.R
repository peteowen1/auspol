# Backtest the candidate-level seat model on Western Australia, 1996 -> 2025.
#
# WHY THIS EXISTS. Every parameter decision in this repo has been made on ten
# election pairs, and most of them on four. That is why `party_sd` came back
# VOID rather than adopted or refused -- two of its three pre-registered
# criteria had no power to resolve anything -- and why a Victorian calibration
# slope of 2.272 with an SE of 0.765 was briefly mistaken for a finding.
#
# WA adds SEVEN consecutive pairs at ~58 seats, roughly 400 scored
# seat-elections, from data that was already sitting in external/elections. It
# is the single largest increase in cluster count available, and clusters are
# what every criterion here has been starved of.
#
# NOTHING LEAKS. Each pair swings from the EARLIER election's district first
# preferences, uses a flow matrix built from transfers at or before the earlier
# election, and is scored against the WAEC's declared winners for the later one.
# `seat_sd` comes from the PREVIOUS pair's realised swing spread, never from the
# pair being predicted -- see SEAT_SD below, which is the one place a backtest
# of this shape usually leaks.
#
# WA HAS NO SEAT FILE. The Victorian and NSW harnesses call
# seat_swing_spread(load_seats(...)) and there is no WA equivalent, so the
# spread is measured from history instead. That is a real difference and is
# stated rather than hidden.
#
# Emits BW* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# LEVEL-DEPENDENT SEAT VARIANCE, off by default. AUSPOL_LEVEL_SD="1.10,8.67"
# makes the per-seat deviation sd = a + b*sqrt(p(1-p)) instead of a flat
# seat_sd. Pre-registered in docs/plans/prereg-level-dependent-variance.md;
# unset reproduces the published model exactly.
.level_sd <- local({
  # ADOPTED 2026-08-27. Default ON at the fitted values; AUSPOL_LEVEL_SD="off"
  # reproduces the flat seat_sd exactly. See
  # docs/reviews/level-variance-2026-08-27.md -- federal seats called 99%+ and
  # LOST fall from 23 to 12 over 886 seat-elections, and Brier and log loss
  # improve in every subset on both federal and NSW.
  raw <- Sys.getenv("AUSPOL_LEVEL_SD", "1.10,8.67")
  if (identical(tolower(raw), "off") || !nzchar(raw)) NULL else {
    v <- suppressWarnings(as.numeric(strsplit(raw, ",")[[1]]))
    if (length(v) != 2L || !all(is.finite(v)))
      stop("AUSPOL_LEVEL_SD must be two finite numbers, e.g. 1.10,8.67")
    v
  }
})
cat(sprintf("LV1  level_sd: %s
", if (is.null(.level_sd)) "OFF (flat seat_sd)" else
            sprintf("a=%.2f b=%.2f", .level_sd[1], .level_sd[2])))


P <- election_data_path()
eps <- 1e-6

SEAT_SD_MULT <- as.numeric(Sys.getenv("AUSPOL_SEAT_SD_MULT", "1"))
N_SIMS  <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))
SHRINK  <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0"))
SMOOTH  <- as.numeric(Sys.getenv("AUSPOL_SMOOTH", "0.15"))
FB_SMOOTH <- as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0"))
FLOW_SD   <- as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0"))
PARTY_SD  <- as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5"))
SURGE_H   <- as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0"))
SEED <- 20260825L
stopifnot(is.finite(SHRINK), SHRINK >= 0, SHRINK < 1)

CAL_TAG <- paste0(
  if (N_SIMS != 20000L) sprintf("-n%d", N_SIMS) else "",
  if (!is.null(.level_sd)) sprintf("-lv%s", gsub("[.]", "", paste(format(.level_sd, nsmall=2), collapse="_"))) else "",
  if (SHRINK != 0) sprintf("-sh%s", sub("0[.]", "", format(SHRINK, nsmall = 2))) else "",
  if (PARTY_SD != 1.5) sprintf("-psd%s", sub("[.]", "", format(PARTY_SD, nsmall = 2))) else "",
  if (FB_SMOOTH != 0) sprintf("-fb%s", sub("0[.]", "", format(FB_SMOOTH, nsmall = 2))) else "",
  if (FLOW_SD != 0) sprintf("-fsd%s", sub("[.]", "", format(FLOW_SD, nsmall = 1))) else "",
  if (SURGE_H > 0) "-surge" else "")

cat(sprintf("BW0  n_sims %d | shrink %.2f | party_sd %.2f | fb %.2f | flow_sd %.2f | surge %.4f\n",
            N_SIMS, SHRINK, PARTY_SD, FB_SMOOTH, FLOW_SD, SURGE_H))

# Polling day per election, which is what decides which external flow sources a
# pair may see. Hand-entered and asserted against their own keys, the same
# treatment backtest_candidate_fed.R gives FED_DATE.
WA_DATE <- c("1996" = "1996-12-14", "2001" = "2001-02-10", "2005" = "2005-02-26",
             "2008" = "2008-09-06", "2013" = "2013-03-09", "2017" = "2017-03-11",
             "2021" = "2021-03-13", "2025" = "2025-03-08")
stopifnot(names(WA_DATE) == format(as.Date(WA_DATE), "%Y"))

YEARS <- c(1996, 2001, 2005, 2008, 2013, 2017, 2021, 2025)
PAIRS <- Map(function(a, b) list(from = a, to = b),
             YEARS[-length(YEARS)], YEARS[-1])

share_of <- function(y) {
  f <- file.path(P, sprintf("waec-%d-wa-firstprefs.csv", y))
  if (!file.exists(f)) return(NULL)
  d <- fread(f, showProgress = FALSE)
  d[, .(votes = sum(votes)), by = .(seat, party)]
}

TX  <- fread(file.path(P, "waec-wa-transfers.csv"), showProgress = FALSE)
WIN <- fread(file.path(P, "waec-wa-winners.csv"), showProgress = FALSE)

# wa2001's transfers are excluded upstream by fetch_preferences_wa.R
# (TRANSFERS_EXCLUDED). Recording it here too, because a pair whose flow matrix
# silently falls back to a pooled rate looks exactly like one that used a real
# matrix, and this harness scores seven pairs where a single quiet fallback
# would be easy to miss.
if ("wa2001" %in% TX$election)
  cat("BW0  note: wa2001 transfers ARE present in the file\n") else
  cat("BW0  note: wa2001 transfers are ABSENT (excluded upstream); that pair uses pooled flows\n")

res_all <- list()
prev_spread <- NA_real_

for (K in PAIRS) {
  fa <- share_of(K$from); fb <- share_of(K$to)
  if (is.null(fa) || is.null(fb)) {
    cat(sprintf("BW1  wa%d->%d: missing first preferences; skipped\n", K$from, K$to)); next
  }
  el_from <- sprintf("wa%d", K$from); el_to <- sprintf("wa%d", K$to)

  tx <- TX[election == el_from]
  # LEAKAGE GUARD asserted on the SOURCE, not on the filtered copy: a table
  # already filtered to one election trivially contains only that election, so
  # asserting on it proves nothing. This checks the pair's date against every
  # election the pooled source can add.
  tx <- pool_configured_flows(tx, WA_DATE[[as.character(K$to)]])
  fm <- if (nrow(tx)) build_flow_matrix(tx, min_n = 3L) else NULL
  if (is.null(fm))
    cat(sprintf("BW1  wa%d->%d: NO transfers for %s; flows fall back to uniform\n",
                K$from, K$to, el_from))

  # statewide shares, and the uniform swing they imply
  wide <- function(d) {
    m <- dcast(d, seat ~ party, value.var = "votes", fill = 0)
    mm <- as.matrix(m[, -1]); rownames(mm) <- m$seat
    100 * mm / rowSums(mm)
  }
  A <- wide(fa); B <- wide(fb)
  sa <- fa[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  sb <- fb[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

  parties <- union(colnames(A), names(sb))
  mat <- matrix(0, nrow = nrow(A), ncol = length(parties),
                dimnames = list(rownames(A), parties))
  mat[, colnames(A)] <- A
  DEV_SLOPE <- dev_slopes_for(parties)
  cat(sprintf("BW1d  dev slopes: %s%s
",
              if (all(DEV_SLOPE == 1)) "all 1.000 (uniform swing)" else
                paste(sprintf("%s=%.3f", names(DEV_SLOPE), DEV_SLOPE), collapse=" "),
              if (length(attr(DEV_SLOPE, "absent")))
                paste0(" | not contested here: ",
                       paste(attr(DEV_SLOPE, "absent"), collapse=",")) else ""))
  for (p in parties) {
    from_pc <- if (p %in% names(sa)) sa[[p]] else 0
    to_pc   <- if (p %in% names(sb)) sb[[p]] else 0
    mat[, p] <- dev_slope(mat[, p], from_pc, to_pc, DEV_SLOPE[[p]])
  }
  shares <- 100 * mat / rowSums(mat)

  truth <- WIN[election == el_to, setNames(winner, seat)]
  keep <- intersect(rownames(shares), names(truth))
  cover <- length(keep) / nrow(shares)
  # WA REDISTRIBUTES HARD, so seat names do not survive between elections: the
  # 2008 one-vote-one-value reform leaves only 38 of 57 names from 2005, and
  # 2001->2005 keeps 46 of 57. Winners coverage WITHIN each election is a clean
  # 57/57 or 59/59 -- verified -- so this is name churn across the pair, not
  # missing data.
  #
  # Aborting the run for one bad pair loses the six good ones, so report and
  # continue, the same shape as the NL3 gate. The coverage is printed per pair
  # AND written into the output, because a pair scored on two thirds of its
  # chamber is not comparable with one scored on all of it, and a reader who
  # cannot see that will pool them.
  cat(sprintf("BW1  wa%d->%d: %d of %d seats matched (%.0f%% coverage)%s\n",
              K$from, K$to, length(keep), nrow(shares), 100 * cover,
              if (cover < 0.8) "  <- REDUCED, redistribution" else ""))
  if (cover < 0.55) {
    cat(sprintf("BW1  wa%d->%d: below 55%%, pair SKIPPED\n", K$from, K$to)); next
  }
  shares <- shares[keep, , drop = FALSE]

  # SEAT SPREAD WITHOUT LEAKING. WA has no seat file, so the within-state spread
  # of seat swings is measured from the PREVIOUS pair -- knowable before the
  # election being predicted. The first pair has no predecessor and uses the
  # repo's default of 3.5, which is stated in the output rather than buried.
  sd_used <- if (is.na(prev_spread)) 3.5 else prev_spread
  psd <- setNames(rep(PARTY_SD, ncol(shares)), colnames(shares))

  sim <- simulate_seat_contests(level_sd = .level_sd, shares, fm, party_sd = psd,
                                seat_sd = sd_used * SEAT_SD_MULT,
                                n_sims = N_SIMS, smooth = SMOOTH, seed = SEED,
                                shrink = SHRINK, fallback_smooth = FB_SMOOTH,
                                flow_sd = FLOW_SD, surge_h = SURGE_H)
  wp <- as.data.table(sim$win_prob)

  pa <- merge(data.table(seat = keep, actual = unname(truth[keep])),
              wp[, .(seat, party, prob)],
              by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]
  pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
  r <- merge(pa, pr, by = "seat")
  r[, `:=`(pair = el_to, coverage = round(cover, 3))]
  res_all[[el_to]] <- r

  z <- data.frame(y = as.integer(r$pred == r$actual),
                  lo = qlogis(pmin(pmax(r$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z$y)) > 1)
    coef(glm(y ~ lo, data = z, family = binomial()))[["lo"]] else NA_real_
  cat(sprintf("BW2  %s: accuracy %d/%d (%.1f%%) | Brier %.4f | log %.4f | slope %.3f | seat_sd %.2f\n",
              el_to, sum(r$pred == r$actual), nrow(r),
              100 * mean(r$pred == r$actual), mean((1 - r$prob)^2),
              -mean(log(pmax(r$prob, eps))), sl, sd_used))

  # Spread for the NEXT pair: the realised sd of each seat's ALP swing here.
  if ("ALP" %in% colnames(A) && "ALP" %in% colnames(B)) {
    common <- intersect(rownames(A), rownames(B))
    if (length(common) > 10) {
      sw <- B[common, "ALP"] - A[common, "ALP"]
      prev_spread <- sd(sw - mean(sw))
    }
  }
}

if (!length(res_all)) stop("no WA pair produced a result")
R <- rbindlist(res_all)
fwrite(R, file.path("output", sprintf("backtest-wa%s.csv", CAL_TAG)))
cat(sprintf("\nBW4  pooled over %d seat-elections across %d pairs: accuracy %.1f%%, Brier %.4f\n",
            nrow(R), uniqueN(R$pair), 100 * mean(R$pred == R$actual),
            mean((1 - R$prob)^2)))
cat(sprintf("BW5  wrote output/backtest-wa%s.csv\n", CAL_TAG))
