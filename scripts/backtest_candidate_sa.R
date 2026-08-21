# Backtest the candidate-level seat model on South Australia 2022 -> 2026.
#
# WHY THIS PAIR MATTERS MORE THAN ITS 47 SEATS. Every other backtest is a
# two-major contest. South Australia 2026 is the only completed election where
# One Nation contested at the level Victoria is forecasting -- 22.87% of the
# statewide primary against Victoria's projected ~21% -- and it elected four
# One Nation members while the Liberal vote fell from 36.15% to 19.03%.
#
# So this is the only place the model can be scored on the thing that is
# actually in doubt: whether it can call seats when a third party displaces a
# major.
#
# THE FLOW MATRIX COMES FROM ANOTHER JURISDICTION, which no other harness here
# does. ECSA publishes a full distribution of preferences for 2026 and NOT for
# 2022, so there is no South Australian matrix predating the election being
# predicted. Federal 2025 is used: full preferential like South Australia, held
# in May 2025 and therefore before the March 2026 poll, and the largest transfer
# corpus available at 2,606 exclusion events.
#
# That is a real difference from the Victorian and NSW harnesses and it is NOT
# a workaround -- it is the situation the live Victorian forecast is in, since
# no Victorian election has ever seen One Nation transfer a meaningful number of
# votes. If the model degrades badly here, that matters more than the sample
# size suggests.
#
# NOTHING LEAKS. First preferences from 2022, flow matrix from federal 2025,
# scored against ECSA's declared 2026 winners.
#
# ---------------------------------------------------------------------------
# READ THIS BEFORE QUOTING THE ONE NATION NUMBER.
#
# This harness allocates a party's statewide movement to districts UNIFORMLY:
# every seat gets the same shift. So does backtest_candidate_vic.R,
# backtest_candidate_nsw.R and backtest_candidate_fed.R.
#
# `fit_seats_full.R` -- the model that publishes -- does NOT. It has a
# dedicated One Nation allocation: seats are ORDERED by the transposed federal
# One Nation vote and the statewide total is spread across them to hit a target
# coefficient of variation of 0.327, concentrating the vote where that party is
# actually strong.
#
# That step is the entire reason One Nation can win a seat in the published
# Victorian forecast, and NO BACKTEST IN THIS REPO IMPLEMENTS IT. So a One
# Nation result here is a bound on the model WITHOUT its allocation, and must
# not be reported as the published model's performance.
#
# The gap matters in exactly one direction. One Nation's South Australian vote
# was concentrated -- 37.7% in Narungga and 35.1% in MacKillop against 22.87%
# statewide -- which is what a uniform shift cannot produce and what the
# allocation exists to produce.
#
# The useful consequence: SA 2026 is the only completed election that can test
# that allocation out of sample, and it never has been.
# ---------------------------------------------------------------------------
#
# Emits BS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

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
  if (!is.null(PARTY_COR)) "-cor" else "")

N_SIMS <- 20000; SEED <- 42; SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()
FLOW_FROM <- "fed2025"

need <- c("ecsa-2022-sa-firstprefs.csv", "ecsa-2026-sa-firstprefs.csv",
          "ecsa-sa-winners.csv", "aec-fed-transfers.csv")
miss <- need[!file.exists(file.path(P, need))]
if (length(miss)) {
  stop("Missing ", paste(miss, collapse = ", "), ". Run ",
       "scripts/fetch_sa2022_and_winners.R and scripts/fetch_preferences_fed.R.")
}

fa <- fread(file.path(P, "ecsa-2022-sa-firstprefs.csv"), showProgress = FALSE)
fb <- fread(file.path(P, "ecsa-2026-sa-firstprefs.csv"), showProgress = FALSE)
win <- fread(file.path(P, "ecsa-sa-winners.csv"),
             showProgress = FALSE)[election == "sa2026", .(seat, winner)]
tx <- fread(file.path(P, "aec-fed-transfers.csv"),
            showProgress = FALSE)[election == FLOW_FROM]
# Guard on the row count as well as the id: all() over an empty table is TRUE,
# which is the guard-that-cannot-fail pattern CLAUDE.md records.
stopifnot(nrow(tx) > 100L, all(tx$election == FLOW_FROM))
fm <- build_flow_matrix(tx, min_n = 3L)
cat(sprintf("\nBS1  flow matrix from %s: %d exclusions\n",
            FLOW_FROM, uniqueN(tx[, paste(seat, round)])))

wide <- dcast(fa, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(wide[, -1, with = FALSE]); rownames(mat) <- wide$seat
mat <- 100 * mat / rowSums(mat)
st_a <- fa[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
st_b <- fb[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

parties <- colnames(mat); shares <- mat
for (p in parties) if (p %in% names(st_b) && p %in% names(st_a)) {
  shares[, p] <- pmax(0, mat[, p] + (st_b[[p]] - st_a[[p]]))
}
# One Nation stood in 19 of 47 districts in 2022 and all 47 in 2026, so 28
# districts have a ZERO baseline for the party that went on to make the final
# two in 32 of them. Adding the statewide shift to a zero baseline is the only
# thing that can be done without inventing a district-level distribution -- but
# it means the model enters those seats assuming One Nation polls its statewide
# average there. That is recorded because it is the single biggest source of
# error here, not because it can be fixed.
absent22 <- setdiff(names(st_b)[st_b > 1], names(st_a)[st_a > 1])
zero_base <- sum(mat[, "ONP"] == 0)
cat(sprintf("BS1  districts with no 2022 One Nation vote to swing from: %d of %d\n",
            zero_base, nrow(mat)))
if (length(absent22)) {
  cat(sprintf("BS1  parties polling >1%% in 2026 but not 2022: %s\n",
              paste(absent22, collapse = ", ")))
}
shares <- 100 * shares / rowSums(shares)

# FROME WAS RENAMED NGADJURI at the 2025 South Australian redistribution, and
# it is the only name that differs between the two polls. It is MAPPED rather
# than dropped, which is the opposite of what backtest_candidate_vic.R does with
# Eureka -- so the reason has to be better than convenience.
#
# It is: One Nation WON Ngadjuri. Dropping the seat would remove one of its four
# wins from a 47-seat test whose entire purpose is scoring how the model handles
# a One Nation surge, and would do so in the direction that flatters the model.
# Excluding a seat is not neutral when the exclusion is correlated with the
# outcome under test.
#
# What is NOT verified is whether the boundaries moved materially as well as the
# name. If they did, this seat carries more error than the rest, and it is named
# here so nobody has to rediscover which one it is.
RENAMES <- c(Frome = "Ngadjuri")
idx <- match(rownames(shares), names(RENAMES))
rownames(shares)[!is.na(idx)] <- unname(RENAMES[idx[!is.na(idx)]])
cat(sprintf("BS1  renamed for the 2025 redistribution: %s\n",
            paste(sprintf("%s -> %s", names(RENAMES), RENAMES), collapse = ", ")))

keep <- intersect(rownames(shares), win$seat)
shares <- shares[keep, , drop = FALSE]
truth <- setNames(win$winner, win$seat)[keep]
if (length(keep) != 47L) {
  stop("Only ", length(keep), " of 47 districts matched between the 2022 first ",
       "preferences and the 2026 winners after applying the rename map. ",
       "Unmatched: ",
       paste(setdiff(win$seat, rownames(shares)), collapse = ", "))
}

# ---- seat-swing port, third testable election ------------------------------
# Against docs/plans/prereg-seat-swing-port-round2.md, which had TWO elections
# and a clustered standard error on one degree of freedom. South Australia is
# the third: 2026sa.txt carries fed_swing for all 47 seats. The federal corpus
# cannot help -- its seat files carry fed_swing for zero seats, because "how
# this seat swung at the preceding federal election" has no federal analogue.
#
# Same block as the Victorian and NSW harnesses, unchanged in substance
# (refusal P4).
PORT <- identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")
if (PORT) {
  sf_to <- as.data.table(load_seats(2026L, "sa"))
  idx_p <- match(rownames(shares), sf_to$seat)
  adj <- rep(0, nrow(shares))
  adj[!is.na(idx_p)] <- seat_swing_adjustment(sf_to[idx_p[!is.na(idx_p)]])
  if (anyNA(idx_p)) {
    cat(sprintf("BS1c %d seats have no match in the seat file and get no adjustment: %s\n",
                sum(is.na(idx_p)), paste(rownames(shares)[is.na(idx_p)], collapse = ", ")))
  }
  adj <- adj - mean(adj)
  stopifnot(all(is.finite(adj)))
  cat(sprintf("BS1c seat-swing port ON: adjustment mean %+.3f sd %.3f range %+.2f..%+.2f\n",
              mean(adj), stats::sd(adj), min(adj), max(adj)))
  shares[, "ALP"] <- pmax(0, shares[, "ALP"] + adj)
  shares[, "LNP"] <- pmax(0, shares[, "LNP"] - adj)
  shares <- 100 * shares / rowSums(shares)
}

# Per-seat spread from the seat file of the election being predicted.
sp <- seat_swing_spread(as.data.table(load_seats(2026L, "sa")),
                        unname(st_b[["ALP"]] - st_a[["ALP"]]))
psd <- setNames(rep(1.5, length(parties)), parties)
set.seed(SEED)
sim <- simulate_seat_contests(shares, fm, party_sd = psd, seat_sd = sp$sd_within * SEAT_SD_MULT,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED, party_cor = PARTY_COR)
wp <- as.data.table(sim$win_prob)

pa <- merge(data.table(seat = keep, actual = unname(truth)),
            wp[, .(seat, party, prob)],
            by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
pa[is.na(prob), prob := 0]
pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
res <- merge(pa, pr, by = "seat")
stopifnot(nrow(res) == length(keep))
res[, pair := "sa2026"]

z <- data.frame(y = as.integer(res$pred == res$actual),
                lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
sl <- if (length(unique(z$y)) > 1)
  stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
cat(sprintf("\nBS2  accuracy %d/%d (%.1f%%) | Brier %.4f | log %.4f | slope %.3f\n",
            sum(res$pred == res$actual), nrow(res),
            100 * mean(res$pred == res$actual), mean((1 - res$prob)^2),
            -mean(log(pmax(res$prob, eps))), sl))

# The question this election exists to answer.
cat("\nBS3  ONE NATION, the reason this pair is worth 47 seats\n")
onp_true <- res[actual == "ONP"]
cat(sprintf("BS3  seats One Nation actually won: %d | our mean probability there: %.3f\n",
            nrow(onp_true), if (nrow(onp_true)) mean(onp_true$prob) else NA_real_))
if (nrow(onp_true)) {
  print(onp_true[, .(seat, we_said = pred, our_p = round(pred_p, 3),
                     gave_ONP = round(prob, 3))][order(-gave_ONP)])
}
onp_pred <- res[pred == "ONP"]
cat(sprintf("BS3  seats we called for One Nation: %d\n", nrow(onp_pred)))
exp_onp <- wp[party == "ONP", sum(prob)]
cat(sprintf("BS3  expected One Nation seats across the simulation: %.1f (actual 4)\n",
            exp_onp))

cat("\nBS4  misses, worst first\n")
print(head(res[pred != actual][order(prob),
                               .(seat, we_said = pred, our_p = round(pred_p, 3),
                                 actual, gave_winner = round(prob, 3))], 10))
fwrite(res, file.path("output", sprintf("backtest-sa%s.csv", CAL_TAG)))
fwrite(data.table(pair = "sa2026", as.data.table(sim$totals)), file.path("output", sprintf("backtest-sa-totals%s.csv", CAL_TAG)))
cat("\nBS5  wrote output/backtest-sa.csv\n")
