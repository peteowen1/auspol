# Does allowing for an independent who has not yet appeared actually help?
#
# Against docs/plans/prereg-independent-emergence.md, committed before this ran.
# The decision rule and refusals E1-E5 are there and are NOT restated here.
#
# Three arms on the same 88 NSW seats:
#   A  the published candidate model
#   B  A, with each seat's independent share drawn per simulation from the
#      fitted predictive distribution (scripts/fit_independent_emergence.R)
#   S  A's probabilities shrunk toward uniform by ONE temperature, fitted
#      leave-one-seat-out. This is E1, and it is the arm that matters: any
#      change making an overconfident model less extreme improves Brier, so B
#      has to beat a dumb temperature to have earned anything.
#
# Emits SE* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

N_SIMS <- 20000
SEED   <- 42
SMOOTH <- 0.15
P      <- election_data_path()
eps    <- 1e-6

tx <- fread(file.path(P, "nswec-nsw-transfers.csv"))
tx19 <- tx[election == "nsw2019"]
stopifnot(nrow(tx19) > 0, !any(tx19$election == "nsw2023"))
fm <- build_flow_matrix(tx19, min_n = 3L)

f19 <- fread(file.path(P, "nswec-2019-nsw-firstprefs.csv"))
f23 <- fread(file.path(P, "nswec-2023-nsw-firstprefs.csv"))
win <- fread(file.path(P, "nswec-nsw-winners.csv"))[election == "nsw2023"]

w19 <- dcast(f19, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(w19[, -1, with = FALSE]); rownames(mat) <- w19$seat
mat <- 100 * mat / rowSums(mat)
state19 <- f19[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
state23 <- f23[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

parties <- colnames(mat)
shares <- mat
for (p in parties) {
  if (!p %in% names(state23)) next
  shares[, p] <- pmax(0, mat[, p] + (state23[[p]] - state19[[p]]))
}
shares <- 100 * shares / rowSums(shares)
common <- intersect(rownames(shares), win$seat)
shares <- shares[common, , drop = FALSE]
truth <- setNames(win$winner, win$seat)[common]
cat(sprintf("\nSE0  %d seats, flow matrix from %s\n", length(common),
            paste(unique(tx19$election), collapse = ", ")))

seats <- as.data.table(load_seats(2023, "nsw"))[, .(seat, margin, incumbent)]
sp <- seat_swing_spread(as.data.table(load_seats(2023, "nsw")),
                        unname(state23[["ALP"]] - state19[["ALP"]]))
psd <- setNames(rep(1.5, length(parties)), parties)

run_arm <- function(sh, label) {
  set.seed(SEED)
  s <- simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = sp$sd_within,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED)
  wp <- as.data.table(s$win_prob)
  wp[, arm := label][]
}

# ---- arm A ------------------------------------------------------------------
A <- run_arm(shares, "A")

# ---- arm B: independent share drawn from the fitted distribution ------------
fit <- readRDS("output/independent-emergence-fit.rds")
# PERCENTAGES, not votes. `w19` is the raw vote count, and the model was fitted
# on shares -- feeding it counts put nonmajor_prev in at ~30,000 instead of ~15,
# which drove every seat to the 80% cap and handed independents every seat. It
# was obvious only because the result was absurd (accuracy 0.10); a smaller unit
# error would have produced a plausible wrong answer. Derived from the same
# share_of() the fitting script uses so the two cannot drift apart.
prev_pct <- f19[, .(v = sum(votes)), by = .(seat, party)]
prev_pct[, pct := 100 * v / sum(v), by = seat]
prev <- dcast(prev_pct, seat ~ party, value.var = "pct", fill = 0)
prev[, other_nonmajor_prev := OTH + OTH_RIGHT]   # v2: disjoint from ind_prev
stopifnot(max(prev$other_nonmajor_prev) <= 100, max(prev$IND) <= 100)
feat <- merge(prev[, .(seat, other_nonmajor_prev, ind_prev = IND)], seats, by = "seat")
feat[, `:=`(abs_margin = abs(margin),
            coalition_held = as.integer(incumbent %in% c("LNP", "LIB", "NAT")), y = 0)]
feat <- feat[match(common, seat)]
stopifnot(identical(feat$seat, common))
X <- stats::model.matrix(fit$form, data = feat)
mu <- as.vector(X %*% fit$b); sg <- exp(pmin(as.vector(X %*% fit$g), 5))

# One independent share per seat per simulation. simulate_seat_contests() takes
# a single share matrix, so the draw is applied as a per-seat MEAN shift plus the
# simulator's own noise would double-count; instead the arm is run as an
# ensemble: R independent draws of the whole share matrix, each simulated with a
# proportionally smaller number of runs, then pooled.
R <- 40
per <- N_SIMS %/% R
set.seed(SEED)
acc <- NULL
for (r in seq_len(R)) {
  ind_draw <- expm1(mu + sg * stats::rt(length(mu), df = fit$nu))
  ind_draw <- pmin(pmax(ind_draw, 0), 80)
  if (r == 1L) {
    cat(sprintf("SE1b draw 1 independent shares: median %.1f%%, p90 %.1f%%, max %.1f%%, at cap %d
",
                stats::median(ind_draw), stats::quantile(ind_draw, 0.9),
                max(ind_draw), sum(ind_draw >= 79.9)))
  }
  sh <- shares
  # The drawn value IS the seat's independent share; everything else keeps its
  # relative size and the row is renormalised. Replacing rather than adding is
  # deliberate: the model predicts the NEXT election's independent vote, not an
  # increment on the last one.
  other <- setdiff(colnames(sh), "IND")
  rest <- rowSums(sh[, other, drop = FALSE])
  scale_to <- pmax(0, 100 - ind_draw) / pmax(rest, 1e-9)
  for (p in other) sh[, p] <- sh[, p] * scale_to
  sh[, "IND"] <- ind_draw
  sh <- 100 * sh / rowSums(sh)
  s <- simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = sp$sd_within,
                              n_sims = per, smooth = SMOOTH, seed = SEED + r)
  w <- as.data.table(s$win_prob)[, .(seat, party, n = prob * per)]
  acc <- if (is.null(acc)) w else rbind(acc, w)
}
B <- acc[, .(prob = sum(n) / (R * per)), by = .(seat, party)][, arm := "B"][]

score <- function(wp, label) {
  pa <- merge(data.table(seat = common, actual = unname(truth)),
              wp[, .(seat, party, prob)],
              by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]
  pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
  m <- merge(pa, pr, by = "seat")
  m[, arm := label][]
}
sA <- score(A, "A"); sB <- score(B, "B")

# ---- arm S: E1's control, one temperature fitted leave-one-seat-out ---------
# Temperature scaling on the full probability vector, so it is the fairest
# possible version of "just make it less confident".
temp_apply <- function(wp, Temp) {
  x <- copy(wp)
  x[, lp := log(pmax(prob, eps)) / Temp]
  x[, prob_t := exp(lp - max(lp)), by = seat]
  x[, prob_t := prob_t / sum(prob_t), by = seat]
  x[, .(seat, party, prob = prob_t)]
}
nll_T <- function(Temp, wp, hold) {
  t2 <- temp_apply(wp[seat %in% hold], Temp)
  m <- merge(data.table(seat = hold, actual = unname(truth[hold])), t2,
             by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  m[is.na(prob), prob := eps]
  -sum(log(pmax(m$prob, eps)))
}
Ts <- vapply(common, function(s) {
  tr <- setdiff(common, s)
  stats::optimize(function(t) nll_T(t, A, tr), interval = c(0.5, 20))$minimum
}, numeric(1))
S <- rbindlist(lapply(seq_along(common), function(i)
  temp_apply(A[seat == common[i]], Ts[i])))
sS <- score(S, "S")
cat(sprintf("SE1  E1 control: leave-one-out temperature %.2f to %.2f (median %.2f)\n",
            min(Ts), max(Ts), stats::median(Ts)))

report <- function(s) {
  z <- data.frame(y = as.integer(s$pred == s$actual),
                  lo = stats::qlogis(pmin(pmax(s$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
  data.table(arm = s$arm[1], accuracy = mean(s$pred == s$actual),
             brier = mean((1 - s$prob)^2),
             logscore = -mean(log(pmax(s$prob, eps))), slope = sl)
}
tab <- rbindlist(lapply(list(sA, sB, sS), report))
cat("\nSE2  the three arms\n"); print(tab)

pair <- function(x, y, nm) {
  d <- merge(x[, .(seat, bx = (1 - prob)^2)], y[, .(seat, by = (1 - prob)^2)], by = "seat")
  dif <- d$by - d$bx
  se <- stats::sd(dif) / sqrt(length(dif))
  cat(sprintf("SE3  %s: Brier change %+.4f, paired SE %.4f -> %.2f SE\n",
              nm, mean(dif), se, mean(dif) / se))
  mean(dif) / se
}
sig_B <- pair(sA, sB, "B vs A")
sig_S <- pair(sA, sS, "S vs A (the control)")
pair(sS, sB, "B vs S  <- E1: B must beat the dumb temperature")

cat(sprintf("\nSE4  E5 accuracy check: A %d seats, B %d, S %d (refuse if B is >2 below A)\n",
            sum(sA$pred == sA$actual), sum(sB$pred == sB$actual), sum(sS$pred == sS$actual)))
cat("\nSE5  what B says about the five seats A missed worst\n")
worst <- sA[order(prob)][1:5, seat]
print(merge(sA[seat %in% worst, .(seat, actual, A = round(prob, 3))],
            sB[seat %in% worst, .(seat, B = round(prob, 3))], by = "seat")[order(-B)])
fwrite(rbind(sA, sB, sS), file.path("output", "independent-emergence-scores.csv"))
cat("\nWrote output/independent-emergence-scores.csv\n")
