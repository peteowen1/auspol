# Score the three-mechanism independent model across six federal pairs.
#
# Against docs/plans/prereg-independent-federal.md, committed before this ran.
# Arms, metrics, decision rule and refusals E1-E5, G1, H1-H3, J1-J3 are there.
#
# Every parameter applied to an election was fitted WITHOUT that election
# (leave-one-election-out), and every flow matrix comes from the PREVIOUS
# election, asserted below. Truth is the AEC's Elected column.
#
# Emits FS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

N_SIMS <- 4000; SEED <- 42; SMOOTH <- 0.15; eps <- 1e-6
R_ENS <- 40; PER <- N_SIMS %/% R_ENS
P <- election_data_path()
FIT <- readRDS("output/independent-federal-fit.rds")
YRS <- c(2007, 2010, 2013, 2016, 2019, 2022, 2025)

fp <- fread(file.path(P, "aec-fed-firstprefs.csv"))
tx <- fread(file.path(P, "aec-fed-transfers.csv"))
win <- fread(file.path(P, "aec-fed-winners.csv"))
pairs <- fread("output/federal-pairs.csv")

all_scores <- list()
for (i in seq_len(length(YRS) - 1L)) {
  prev_el <- sprintf("fed%d", YRS[i]); tgt_el <- sprintf("fed%d", YRS[i + 1L])
  pr <- pairs[target == tgt_el]
  # LEAKAGE GUARDS. Both are asserted rather than trusted.
  txp <- tx[election == prev_el]
  stopifnot(nrow(txp) > 0, !any(txp$election == tgt_el))
  fit <- FIT$loo[[tgt_el]]
  stopifnot(!is.null(fit))
  fm <- build_flow_matrix(txp, min_n = 3L)

  a <- fp[election == prev_el]; b <- fp[election == tgt_el]
  aw <- dcast(a, seat ~ party, value.var = "votes", fill = 0)
  mat <- as.matrix(aw[, -1, with = FALSE]); rownames(mat) <- aw$seat
  mat <- 100 * mat / rowSums(mat)
  s_prev <- a[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  s_tgt  <- b[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

  parties <- colnames(mat); shares <- mat
  for (p in parties) if (p %in% names(s_tgt) && p %in% names(s_prev))
    shares[, p] <- pmax(0, mat[, p] + (s_tgt[[p]] - s_prev[[p]]))
  shares <- 100 * shares / rowSums(shares)
  keep <- intersect(rownames(shares), pr$seat)
  shares <- shares[keep, , drop = FALSE]
  truth <- setNames(win[election == tgt_el, winner], win[election == tgt_el, seat])[keep]

  feat <- pr[match(keep, seat)]
  stopifnot(identical(feat$seat, keep))
  sitting <- feat$ind_prev >= fit$cut
  X <- stats::model.matrix(fit$form, data = feat[, y := 0][])
  mu2 <- as.vector(X %*% fit$route2$b)
  sg2 <- exp(pmin(as.vector(X %*% fit$route2$g), 5))
  psd <- setNames(rep(1.5, length(parties)), parties)

  simulate_one <- function(sh, n, seed) {
    as.data.table(simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 3.5,
                                         n_sims = n, smooth = SMOOTH,
                                         seed = seed)$win_prob)
  }
  A <- simulate_one(shares, N_SIMS, SEED)

  set.seed(SEED + i)
  acc <- NULL
  for (r in seq_len(R_ENS)) {
    ind_draw <- numeric(length(keep))
    ind_draw[!sitting] <- expm1(mu2[!sitting] +
      sg2[!sitting] * stats::rt(sum(!sitting), df = fit$route2$nu))
    if (any(sitting)) {
      idx <- which(sitting)
      stands <- stats::runif(length(idx)) < fit$recontest
      lp <- fit$route1$a + fit$route1$b * log1p(feat$ind_prev[idx]) +
        stats::rnorm(length(idx), 0, fit$route1$s)
      ind_draw[idx] <- ifelse(stands, expm1(lp), 0)
    }
    ind_draw <- pmin(pmax(ind_draw, 0), 80)
    sh <- shares
    other <- setdiff(colnames(sh), "IND")
    rest <- rowSums(sh[, other, drop = FALSE])
    sc <- pmax(0, 100 - ind_draw) / pmax(rest, 1e-9)
    for (p in other) sh[, p] <- sh[, p] * sc
    sh[, "IND"] <- ind_draw
    sh <- 100 * sh / rowSums(sh)
    w <- simulate_one(sh, PER, SEED + 1000 * i + r)[, .(seat, party, n = prob * PER)]
    acc <- if (is.null(acc)) w else rbind(acc, w)
  }
  B <- acc[, .(prob = sum(n) / (R_ENS * PER)), by = .(seat, party)]

  sc <- function(wp, label) {
    pa <- merge(data.table(seat = keep, actual = unname(truth)),
                wp[, .(seat, party, prob)],
                by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
    pa[is.na(prob), prob := 0]
    pd <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
    merge(pa, pd, by = "seat")[, `:=`(arm = label, target = tgt_el)][]
  }
  all_scores[[length(all_scores) + 1L]] <- rbind(sc(A, "A"), sc(B, "B"))
  cat(sprintf("FS1  %s: %d divisions scored\n", tgt_el, length(keep)))
}

S <- rbindlist(all_scores)

# ---- arm S: one temperature, fitted leave-one-ELECTION-out ------------------
Aall <- S[arm == "A"]
tfit <- function(hold) {
  tr <- Aall[target != hold]
  f <- function(Temp) {
    p <- pmax(tr$prob, eps)^(1 / Temp)
    # Renormalising needs the full vector per seat; the winner's share of the
    # tempered mass is approximated by its own tempered probability against the
    # tempered total, which for a two-horse seat is exact and elsewhere close.
    -sum(log(pmax(p / (p + (1 - pmax(tr$prob, eps))^(1 / Temp)), eps)))
  }
  stats::optimize(f, interval = c(0.5, 20))$minimum
}
Ts <- vapply(unique(S$target), tfit, numeric(1))
names(Ts) <- unique(S$target)
Sarm <- copy(Aall)
Sarm[, Temp := Ts[target]]
Sarm[, prob := {
  p <- pmax(prob, eps)^(1 / Temp); q <- (1 - pmax(prob, eps))^(1 / Temp); p / (p + q)
}]
Sarm[, `:=`(arm = "S", pred_p = pmax(pred_p, eps)^(1 / Temp) /
              (pmax(pred_p, eps)^(1 / Temp) + (1 - pmax(pred_p, eps))^(1 / Temp)))]
S <- rbind(S, Sarm[, names(S), with = FALSE])
cat(sprintf("\nFS2  E1 control temperature by held-out election: %s\n",
            paste(sprintf("%s %.2f", names(Ts), Ts), collapse = ", ")))

report <- function(d, lab) {
  z <- data.frame(y = as.integer(d$pred == d$actual),
                  lo = stats::qlogis(pmin(pmax(d$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
  data.table(arm = lab, n = nrow(d), accuracy = round(mean(d$pred == d$actual), 4),
             brier = round(mean((1 - d$prob)^2), 4),
             logscore = round(-mean(log(pmax(d$prob, eps))), 4), slope = round(sl, 3))
}
cat("\nFS3  the three arms, pooled over 886 division-pairs\n")
print(rbindlist(lapply(c("A", "B", "S"), function(a) report(S[arm == a], a))))

pair_se <- function(x, y, nm) {
  d <- merge(S[arm == x, .(seat, target, bx = (1 - prob)^2)],
             S[arm == y, .(seat, target, by = (1 - prob)^2)], by = c("seat", "target"))
  dif <- d$by - d$bx; se <- stats::sd(dif) / sqrt(length(dif))
  cat(sprintf("FS4  %s: Brier %+.4f, SE %.4f -> %.2f SE\n", nm, mean(dif), se, mean(dif) / se))
  mean(dif) / se
}
bA <- pair_se("A", "B", "B vs A  (bar is 2 SE)")
pair_se("A", "S", "S vs A  (control)   ")
bS <- pair_se("S", "B", "B vs S  (E1)        ")
# SIGN MATTERS AND AN EARLIER VERSION OF THIS DROPPED IT. `pair_se("A","B")`
# returns (B - A), so a POSITIVE value means arm B has the HIGHER Brier and is
# therefore WORSE. Taking abs() and testing > 2 printed "ADOPT" for a change
# that degrades the forecast by 2.5 SE. Adoption requires the difference to be
# negative AND larger than 2 SE.
verdict <- if (bA < -2) "ADOPT" else if (bA > 2) "REFUSE -- arm B is WORSE" else "KEEP A"
cat(sprintf("
FS5  adoption: B vs A is %+.2f SE (negative = B better) -> %s
",
            bA, verdict))
cat(sprintf("FS5  E1: B vs the temperature is %+.2f SE (negative = B better)
", bS))

cat("\nFS6  J2 -- by election, so 2022 cannot carry the result alone\n")
print(S[, .(brier = round(mean((1 - prob)^2), 4),
            acc = round(mean(pred == actual), 3)), by = .(target, arm)][order(target, arm)])
fwrite(S, file.path("output", "independent-federal-scores.csv"))
cat("\nWrote output/independent-federal-scores.csv\n")
