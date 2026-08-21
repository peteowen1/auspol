# Backtest the candidate-level seat model on the federal corpus.
#
# WHY. Every feature decision made on this model has rested on
# backtest_candidate_vic.R and backtest_candidate_nsw.R -- 166 seats across TWO
# elections. The repo holds seven federal elections with first preferences,
# transfers and declared winners, which is SIX consecutive pairs at ~150
# divisions each. That data has never been pointed at the seat model.
#
# The consequence showed up on 2026-08-20: the seat-swing port came back
# "positive but short of the bar" on an election-clustered standard error with
# ONE degree of freedom. That is not a finding about the port, it is a finding
# about the sample. Six clusters is still small; it is three times what every
# decision so far has had.
#
# NOTHING LEAKS. Each pair swings from the EARLIER election's district first
# preferences, uses the EARLIER election's flow matrix, and is scored against
# the AEC's declared winners for the later one.
#
# WHAT THIS CANNOT TEST. `seat_swing_adjustment()` needs `fed_swing` -- how a
# seat swung at the preceding FEDERAL election -- which is a state-model
# predictor with no federal analogue. The federal seat files carry it for ZERO
# seats, confirmed. So this harness does not test the seat-swing port; it tests
# the model the port would be added to.
#
# Emits BF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# ---- Queensland flows, date-filtered ---------------------------------------
# Against docs/plans/prereg-qld-flows.md. Queensland 2020 and 2024 add 750
# exclusion events and take One Nation's from 18 to 198. They may only be used
# to predict an election held AFTER them, so the filter takes the predicted
# election's own date and admits nothing later.
#
# Q1 makes the five elections that predate both a CONTROL: their arms must come
# out byte-identical. Silently admitting a later election there would be the
# leak this whole design exists to make visible.
FED_DATE <- c("2010"="2010-08-21","2013"="2013-09-07","2016"="2016-07-02",
              "2019"="2019-05-18","2022"="2022-05-21","2025"="2025-05-03")
QLD_DATES <- c(qld2020 = "2020-10-31", qld2024 = "2024-10-26")
add_qld <- function(tx, before) {
  if (!identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1")) return(tx)
  f <- file.path(election_data_path(), "ecq-qld-transfers.csv")
  if (!file.exists(f)) stop("Run scripts/fetch_preferences_qld.R first.")
  ok <- names(QLD_DATES)[as.Date(QLD_DATES) < as.Date(before)]
  if (!length(ok)) {
    cat(sprintf("QF5  no Queensland election precedes %s; unchanged (control)
",
                as.character(before)))
    return(tx)
  }
  q <- data.table::fread(f, showProgress = FALSE)[election %in% ok]
  cat(sprintf("QF5  +%s for %s: %d exclusion events added
",
              paste(ok, collapse = "+"), as.character(before),
              data.table::uniqueN(q[, paste(election, seat, round)])))
  data.table::rbindlist(list(tx, q), fill = TRUE)
}

# ARM B of docs/plans/prereg-calibration.md. A multiplier on the per-seat
# spread, so the simulation carries more genuine seat-level uncertainty. Default
# 1 reproduces the published behaviour exactly; the run prints what it applied,
# because CLAUDE.md records an experiment whose edit never ran and whose
# byte-identical output read as "this input does not matter".
SEAT_SD_MULT <- as.numeric(Sys.getenv("AUSPOL_SEAT_SD_MULT", "1"))
if (SEAT_SD_MULT != 1) cat(sprintf("CAL  seat_sd multiplier %.2f applied
", SEAT_SD_MULT))

# OUTPUT FILENAME CARRIES THE CONFIG, and it must. These harnesses used to write
# to one fixed name, so running an experimental arm SILENTLY OVERWROTE the
# baseline it was meant to be compared against. That happened on 2026-08-21: a
# seat_sd sweep overwrote backtest-fed.csv and backtest-vic.csv, and the
# resulting comparison showed a difference of EXACTLY +0.0000 for all six
# federal elections because both arms were the same file. It read as "this
# input does not matter", which is the failure mode CLAUDE.md already records
# for an experiment that never ran.
#
# A default run still writes the plain name, so nothing downstream changes.
# N_SIMS is settable so the federal harness -- six pairs at ~150 divisions --
# can be swept across arms in minutes rather than an hour. Monte Carlo error at
# 5,000 draws is far below the log-score differences under test.
#
# THE ARMS OF ONE ELECTION MUST SHARE IT. A paired comparison between arms is
# valid at any n_sims, but only if both arms of the SAME election used the same
# one; the tag below records it in the filename so a mismatched pair cannot be
# compared by accident.
N_SIMS <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))


# ARM B/C of docs/plans/prereg-statewide-covariance.md. AUSPOL_PARTY_COR=shrunk
# correlates the parties' statewide deviations instead of drawing them
# independently. Empty (the default) reproduces the previous behaviour exactly.
PARTY_COR <- NULL
if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", ""))) {
  .co <- readRDS("output/statewide-cov.rds")
  PARTY_COR <- if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) .co$cor else .co$cor_shrunk
  cat(sprintf("COV  party correlation ON (%s): cor(ONP,LNP) = %+.2f
",
              Sys.getenv("AUSPOL_PARTY_COR"), PARTY_COR["ONP", "LNP"]))
}

CAL_TAG <- paste0(
  if (SEAT_SD_MULT != 1) sprintf("-m%s", format(SEAT_SD_MULT, nsmall = 1)) else "",
  if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")) "-port" else "",
  if (N_SIMS != 20000L) sprintf("-n%d", N_SIMS) else "",
  if (!is.null(PARTY_COR)) "-cor" else "",
  if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1")) "-qld" else "")

SEED <- 42; SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()

PAIRS <- list(
  list(from = 2007, to = 2010), list(from = 2010, to = 2013),
  list(from = 2013, to = 2016), list(from = 2016, to = 2019),
  list(from = 2019, to = 2022), list(from = 2022, to = 2025))

FP  <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)
TX  <- fread(file.path(P, "aec-fed-transfers.csv"), showProgress = FALSE)
WIN <- fread(file.path(P, "aec-fed-winners.csv"), showProgress = FALSE)

# The federal files are already in this repo's party classes, so no
# classify_party() call is needed -- confirmed against the value sets. The
# Coalition fold is kept anyway because a future refetch could reintroduce
# LIB/NAT/CLP and the failure would be silent: those seats would simply never
# match a predicted party.
coal <- function(x) fifelse(x %in% c("NAT", "LIB", "LNP", "CLP"), "LNP", x)

# Per-seat idiosyncratic spread. Taken from the seat file of the election being
# predicted where one exists (2019, 2022, 2025); the earlier pairs have no
# federal seat file, so they use the MEDIAN of those that do rather than a
# number invented here. It is a variance parameter, not a prediction, and it is
# reported per pair so a pair running on the fallback is visible.
spread_for <- function(yr, swing) {
  s <- tryCatch(as.data.table(load_seats(yr, "fed")), error = function(e) NULL)
  if (is.null(s)) return(NA_real_)
  tryCatch(seat_swing_spread(s, swing)$sd_within, error = function(e) NA_real_)
}

out_all <- list(); seat_sds <- c()
for (K in PAIRS) {
  ea <- sprintf("fed%d", K$from); eb <- sprintf("fed%d", K$to)
  fa <- FP[election == ea, .(votes = sum(votes)), by = .(seat, party)]
  fb <- FP[election == eb, .(votes = sum(votes)), by = .(seat, party)]
  tx <- TX[election == ea]
  # LEAKAGE GUARD, asserted on the filtered result AND on its size: an empty
  # table trivially satisfies an all() check, which is the guard-that-cannot-
  # fail pattern CLAUDE.md records.
  stopifnot(nrow(tx) > 100L, all(tx$election == ea))
  tx <- add_qld(tx, FED_DATE[[as.character(K$to)]])
  fm <- build_flow_matrix(tx, min_n = 3L)

  win <- WIN[election == eb, .(seat, winner = coal(winner))]
  stopifnot(nrow(win) > 100L)

  wide <- dcast(fa, seat ~ party, value.var = "votes", fill = 0)
  mat <- as.matrix(wide[, -1, with = FALSE]); rownames(mat) <- wide$seat
  mat <- 100 * mat / rowSums(mat)
  st_a <- fa[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  st_b <- fb[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

  parties <- colnames(mat); shares <- mat
  for (p in parties) if (p %in% names(st_b) && p %in% names(st_a)) {
    shares[, p] <- pmax(0, mat[, p] + (st_b[[p]] - st_a[[p]]))
  }
  shares <- 100 * shares / rowSums(shares)
  keep <- intersect(rownames(shares), win$seat)
  shares <- shares[keep, , drop = FALSE]
  truth <- setNames(win$winner, win$seat)[keep]

  cat(sprintf("\nBF1  federal %d -> %d: %d divisions scored\n",
              K$from, K$to, length(keep)))
  dropped <- setdiff(win$seat, rownames(mat))
  if (length(dropped)) {
    cat(sprintf("BF1  %d divisions have no %d baseline and are not scored: %s\n",
                length(dropped), K$from, paste(sort(dropped), collapse = ", ")))
  }
  # Redistributions rename and create divisions every cycle -- eight appeared
  # between 2016 and 2019 alone. A floor well below the chamber size allows for
  # that; falling under it means the NAMES stopped matching, not that the
  # chamber changed.
  if (length(keep) < 110L) {
    stop("Only ", length(keep), " divisions could be scored for ", eb,
         ". Redistribution churn has never exceeded a handful, so this means ",
         "the division names stopped matching.")
  }

  sd_w <- spread_for(K$to, unname(st_b[["ALP"]] - st_a[["ALP"]]))
  seat_sds <- c(seat_sds, sd_w)
  out_all[[length(out_all) + 1L]] <- list(K = K, shares = shares, fm = fm,
                                          truth = truth, keep = keep,
                                          parties = parties, sd_w = sd_w)
}

fallback <- stats::median(seat_sds, na.rm = TRUE)
if (!is.finite(fallback)) {
  stop("No federal seat file yielded a within-region seat-swing spread, so ",
       "there is no measured value to fall back on and one would have to be ",
       "invented here.")
}
cat(sprintf("\nBF2  seat_sd per pair: %s | fallback (median) %.3f\n",
            paste(sprintf("%.2f", seat_sds), collapse = ", "), fallback))

res_all <- list(); tot_all <- list()
for (X in out_all) {
  K <- X$K
  sd_w <- if (is.finite(X$sd_w)) X$sd_w else fallback
  psd <- setNames(rep(1.5, length(X$parties)), X$parties)
  set.seed(SEED)
  sim <- simulate_seat_contests(X$shares, X$fm, party_sd = psd, seat_sd = sd_w * SEAT_SD_MULT,
                                n_sims = N_SIMS, smooth = SMOOTH, seed = SEED, party_cor = PARTY_COR)
  wp <- as.data.table(sim$win_prob)

  pa <- merge(data.table(seat = X$keep, actual = unname(X$truth)),
              wp[, .(seat, party, prob)],
              by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]
  pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
  res <- merge(pa, pr, by = "seat")
  stopifnot(nrow(res) == length(X$keep))
  res[, pair := sprintf("fed%d", K$to)]

  z <- data.frame(y = as.integer(res$pred == res$actual),
                  lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
  cat(sprintf("BF3  fed%d: accuracy %d/%d (%.1f%%) | Brier %.4f | log %.4f | slope %.3f%s\n",
              K$to, sum(res$pred == res$actual), nrow(res),
              100 * mean(res$pred == res$actual), mean((1 - res$prob)^2),
              -mean(log(pmax(res$prob, eps))), sl,
              if (is.finite(X$sd_w)) "" else "  [seat_sd fallback]"))
  # Seat TOTALS, not just per-seat probabilities. A covariance between
  # parties' statewide votes moves the joint distribution far more than any
  # single seat's marginal, so the criterion in
  # docs/plans/prereg-statewide-covariance.md is the total and it needs the
  # simulation's own totals matrix.
  tot_all[[length(tot_all) + 1L]] <- data.table::data.table(
    pair = sprintf("fed%d", K$to), as.data.table(sim$totals))
  res_all[[length(res_all) + 1L]] <- res
}

R <- rbindlist(res_all)
cat(sprintf("\nBF4  pooled over %d division-elections across %d elections: accuracy %.1f%%, Brier %.4f\n",
            nrow(R), uniqueN(R$pair), 100 * mean(R$pred == R$actual),
            mean((1 - R$prob)^2)))
cat("BF4  for comparison the two state backtests together hold 166 seats and 2 elections.\n")
per <- R[, .(n = .N, accuracy = round(100 * mean(pred == actual), 1),
             brier = round(mean((1 - prob)^2), 4)), by = pair]
print(per)
fwrite(R, file.path("output", sprintf("backtest-fed%s.csv", CAL_TAG)))
fwrite(rbindlist(tot_all, fill = TRUE), file.path("output", sprintf("backtest-fed-totals%s.csv", CAL_TAG)))
cat(sprintf("BF5  wrote output/backtest-fed.csv\n"))
