# Does splitting the independent vote into three mechanisms beat one -- and
# does it beat a dumb temperature?
#
# Against docs/plans/prereg-independent-two-mechanism.md, committed before this
# ran. The decision rule and refusals E1-E5, G1 and H1-H3 are there.
#
# H3 is the one that ends this line of work if it fails: v2 reached 1.01 SE on
# Brier and 0.65 SE against the control. If three mechanisms do not clearly beat
# that, splitting them did not help either and the honest conclusion is that
# none of this clears a temperature.
#
# Emits TS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

N_SIMS <- 20000; SEED <- 42; SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()
fit <- readRDS("output/independent-two-mechanism-fit.rds")

tx19 <- fread(file.path(P, "nswec-nsw-transfers.csv"))[election == "nsw2019"]
stopifnot(nrow(tx19) > 0, !any(tx19$election == "nsw2023"))
fm <- build_flow_matrix(tx19, min_n = 3L)

f19 <- fread(file.path(P, "nswec-2019-nsw-firstprefs.csv"))
f23 <- fread(file.path(P, "nswec-2023-nsw-firstprefs.csv"))
win <- fread(file.path(P, "nswec-nsw-winners.csv"))[election == "nsw2023"]

w19 <- dcast(f19, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(w19[, -1, with = FALSE]); rownames(mat) <- w19$seat
mat <- 100 * mat / rowSums(mat)
s19 <- f19[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
s23 <- f23[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

parties <- colnames(mat); shares <- mat
for (p in parties) if (p %in% names(s23)) shares[, p] <- pmax(0, mat[, p] + (s23[[p]] - s19[[p]]))
shares <- 100 * shares / rowSums(shares)
common <- intersect(rownames(shares), win$seat)
shares <- shares[common, , drop = FALSE]
truth <- setNames(win$winner, win$seat)[common]

seats <- as.data.table(load_seats(2023, "nsw"))[, .(seat, margin, incumbent)]
sp <- seat_swing_spread(as.data.table(load_seats(2023, "nsw")),
                        unname(s23[["ALP"]] - s19[["ALP"]]))
psd <- setNames(rep(1.5, length(parties)), parties)
cat(sprintf("\nTS0  %d seats, flow matrix from nsw2019\n", length(common)))

# ---- features and routing, from the seat's OWN previous first preferences ---
pp <- f19[, .(v = sum(votes)), by = .(seat, party)]
pp[, pct := 100 * v / sum(v), by = seat]
pw <- dcast(pp, seat ~ party, value.var = "pct", fill = 0)
pw[, other_nonmajor_prev := OTH + OTH_RIGHT]
feat <- merge(pw[, .(seat, other_nonmajor_prev, ind_prev = IND)], seats, by = "seat")
feat[, `:=`(abs_margin = abs(margin),
            coalition_held = as.integer(incumbent %in% c("LNP", "LIB", "NAT")), y = 0)]
feat <- feat[match(common, seat)]
stopifnot(identical(feat$seat, common), max(feat$other_nonmajor_prev) <= 100)
sitting <- feat$ind_prev >= fit$cut
cat(sprintf("TS0  routed: %d sitting independent, %d emergence\n",
            sum(sitting), sum(!sitting)))

X <- stats::model.matrix(fit$form, data = feat)
mu2 <- as.vector(X %*% fit$route2$b); sg2 <- exp(pmin(as.vector(X %*% fit$route2$g), 5))

run_arm <- function(sh) {
  set.seed(SEED)
  as.data.table(simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = sp$sd_within,
                                       n_sims = N_SIMS, smooth = SMOOTH, seed = SEED)$win_prob)
}
A <- run_arm(shares)

# ---- arm B: three mechanisms ------------------------------------------------
R <- 40; per <- N_SIMS %/% R
set.seed(SEED)
acc <- NULL
for (r in seq_len(R)) {
  ind_draw <- numeric(length(common))
  # Route 2: emergence, for seats with little or no independent history.
  ind_draw[!sitting] <- expm1(mu2[!sitting] +
                                sg2[!sitting] * stats::rt(sum(!sitting), df = fit$route2$nu))
  # Route 1: a sitting independent recontests with probability `recontest`, and
  # if they do, their vote is centred on log1p(previous) with the FITTED slope.
  # Route 3 is the else branch: they do not stand and the vote is zero.
  if (any(sitting) && !is.null(fit$route1)) {
    idx <- which(sitting)
    stands <- stats::runif(length(idx)) < fit$recontest
    lp <- fit$route1$a + fit$route1$b * log1p(feat$ind_prev[idx]) +
      stats::rnorm(length(idx), 0, fit$route1$s)
    ind_draw[idx] <- ifelse(stands, expm1(lp), 0)
  }
  ind_draw <- pmin(pmax(ind_draw, 0), 80)
  if (r == 1L) {
    cat(sprintf("TS1  draw 1: sitting seats median %.1f%%, emergence seats median %.1f%%, max %.1f%%\n",
                stats::median(ind_draw[sitting]), stats::median(ind_draw[!sitting]),
                max(ind_draw)))
  }
  sh <- shares
  other <- setdiff(colnames(sh), "IND")
  rest <- rowSums(sh[, other, drop = FALSE])
  sc <- pmax(0, 100 - ind_draw) / pmax(rest, 1e-9)
  for (p in other) sh[, p] <- sh[, p] * sc
  sh[, "IND"] <- ind_draw
  sh <- 100 * sh / rowSums(sh)
  w <- as.data.table(simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = sp$sd_within,
                                            n_sims = per, smooth = SMOOTH,
                                            seed = SEED + r)$win_prob)[, .(seat, party, n = prob * per)]
  acc <- if (is.null(acc)) w else rbind(acc, w)
}
B <- acc[, .(prob = sum(n) / (R * per)), by = .(seat, party)]

score <- function(wp, label) {
  pa <- merge(data.table(seat = common, actual = unname(truth)), wp[, .(seat, party, prob)],
              by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]
  pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
  merge(pa, pr, by = "seat")[, arm := label][]
}
sA <- score(A, "A"); sB <- score(B, "B")

# ---- arm S: the E1 control --------------------------------------------------
temp_apply <- function(wp, Temp) {
  x <- copy(wp); x[, lp := log(pmax(prob, eps)) / Temp]
  x[, pt := exp(lp - max(lp)), by = seat]; x[, pt := pt / sum(pt), by = seat]
  x[, .(seat, party, prob = pt)]
}
nll_T <- function(Temp, wp, hold) {
  t2 <- temp_apply(wp[seat %in% hold], Temp)
  m <- merge(data.table(seat = hold, actual = unname(truth[hold])), t2,
             by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  m[is.na(prob), prob := eps]; -sum(log(pmax(m$prob, eps)))
}
Ts <- vapply(common, function(s)
  stats::optimize(function(t) nll_T(t, A, setdiff(common, s)), interval = c(0.5, 20))$minimum,
  numeric(1))
S <- rbindlist(lapply(seq_along(common), function(i) temp_apply(A[seat == common[i]], Ts[i])))
sS <- score(S, "S")

report <- function(s) {
  z <- data.frame(y = as.integer(s$pred == s$actual),
                  lo = stats::qlogis(pmin(pmax(s$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
  data.table(arm = s$arm[1], accuracy = mean(s$pred == s$actual), brier = mean((1 - s$prob)^2),
             logscore = -mean(log(pmax(s$prob, eps))), slope = sl)
}
cat("\nTS2  the three arms\n"); print(rbindlist(lapply(list(sA, sB, sS), report)))

pair <- function(x, y, nm) {
  d <- merge(x[, .(seat, bx = (1 - prob)^2)], y[, .(seat, by = (1 - prob)^2)], by = "seat")
  dif <- d$by - d$bx; se <- stats::sd(dif) / sqrt(length(dif))
  cat(sprintf("TS3  %s: Brier %+.4f, SE %.4f -> %.2f SE\n", nm, mean(dif), se, mean(dif) / se))
  mean(dif) / se
}
bA <- pair(sA, sB, "B vs A            (needs > 2 SE)")
pair(sA, sS, "S vs A  (control)")
bS <- pair(sS, sB, "B vs S  (E1)      ")
cat(sprintf("\nTS4  H3: v2 reached 1.01 SE on Brier and 0.65 SE against the control.\n"))
cat(sprintf("TS4  v3 reaches %.2f SE and %.2f SE. %s\n", abs(bA), abs(bS),
            if (abs(bA) > 2) "Clears the bar." else
              "Does NOT clear the bar -- per H3 this line of work stops."))

g1 <- merge(sB[, .(seat, actual, B = prob)], feat[, .(seat, ind_prev)], by = "seat")
g1 <- g1[ind_prev >= fit$cut & actual == "IND"]
cat(sprintf("\nTS5  G1: seats with a sitting independent (>=%d%%) who won again: %d\n",
            fit$cut, nrow(g1)))
print(merge(g1, sA[, .(seat, A = prob)], by = "seat")[order(B),
      .(seat, ind_prev = round(ind_prev, 1), A = round(A, 3), B = round(B, 3))])
cat(sprintf("TS5  below the 0.80 bar: %d of %d -> %s\n", sum(g1$B < 0.8), nrow(g1),
            if (any(g1$B < 0.8)) "FAIL" else "PASS"))
cat(sprintf("\nTS6  E5 accuracy: A %d, B %d, S %d\n",
            sum(sA$pred == sA$actual), sum(sB$pred == sB$actual), sum(sS$pred == sS$actual)))
fwrite(rbind(sA, sB, sS), file.path("output", "independent-two-mechanism-scores.csv"))
cat("\nWrote output/independent-two-mechanism-scores.csv\n")
