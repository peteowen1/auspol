# Is the stronghold overestimate REAL, or regression to the mean?
#
# Our model overestimates a major party where it starts high and underestimates
# where it starts low -- MacKillop (LNP base 67.0) is +23.1, Ngadjuri (46.8) is
# +8.0, Narungga (30.1) is -9.4. That is the shape of mean reversion, and
# a coefficient of -0.343 (4.56 SE) was measured today.
#
# BUT regressing a change on its own baseline yields a negative slope from
# MEASUREMENT NOISE ALONE: any transient component in the baseline appears in
# the change with the opposite sign. So the naive coefficient cannot be trusted.
#
# THE INSTRUMENT. Use the party's share TWO elections back. Its transient noise
# is not shared with the change being predicted, so if a substantial negative
# slope survives, the effect is real. If it collapses, the -0.343 was an
# artefact and this whole direction is finished.
#
# Emits SR* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
P <- election_data_path()
PARTIES <- c("ALP", "LNP")

# federal gives seven elections, so five usable triples; Victoria adds one
FED <- c("fed2007","fed2010","fed2013","fed2016","fed2019","fed2022","fed2025")
fp <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)

shares <- function(e) {
  d <- fp[election == e, .(votes = sum(votes)), by = .(seat, party)]
  d[, tot := sum(votes), by = seat]
  d[, pc := 100 * votes / tot]
  sw <- d[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  list(seat = dcast(d, seat ~ party, value.var = "pc", fill = 0), state = sw)
}

rows <- list()
for (i in 3:length(FED)) {
  e0 <- FED[i-2]; e1 <- FED[i-1]; e2 <- FED[i]
  s0 <- shares(e0); s1 <- shares(e1); s2 <- shares(e2)
  for (p in PARTIES) {
    for (S in list(s0, s1, s2)) if (!p %in% names(S$seat)) S$seat[[p]] <- 0
    j <- Reduce(function(a, b) merge(a, b, by = "seat"), list(
      s0$seat[, .(seat, b0 = get(p))],
      s1$seat[, .(seat, b1 = get(p))],
      s2$seat[, .(seat, b2 = get(p))]))
    if (nrow(j) < 40) next
    st0 <- if (p %in% names(s0$state)) s0$state[[p]] else 0
    st1 <- if (p %in% names(s1$state)) s1$state[[p]] else 0
    st2 <- if (p %in% names(s2$state)) s2$state[[p]] else 0
    rows[[length(rows)+1L]] <- data.table(
      pair = paste0(e1, "->", e2), party = p, seat = j$seat,
      # outcome: how much this seat's swing beat the statewide swing
      y = (j$b2 - j$b1) - (st2 - st1),
      # naive predictor: over-index at t-1, which shares noise with y
      x_naive = j$b1 - st1,
      # INSTRUMENT: over-index at t-2, whose noise does NOT enter y
      x_inst  = j$b0 - st0)
  }
}
D <- rbindlist(rows)
D <- D[is.finite(y) & is.finite(x_naive) & is.finite(x_inst)]
cat(sprintf("SR1  %d (seat, party) rows across %d pairs\n", nrow(D), uniqueN(D$pair)))
stopifnot(nrow(D) > 200)

cluster_se <- function(form, data, cluster) {
  m <- stats::lm(form, data = data)
  X <- stats::model.matrix(m); u <- stats::residuals(m)
  bread <- solve(crossprod(X))
  g <- split(seq_len(nrow(X)), cluster)
  meat <- Reduce(`+`, lapply(g, function(i) tcrossprod(crossprod(X[i,,drop=FALSE], u[i]))))
  G <- length(g); N <- nrow(X); K <- ncol(X)
  V <- bread %*% meat %*% bread * (G/(G-1)) * ((N-1)/(N-K))
  list(b = stats::coef(m), se = sqrt(diag(V)), G = G)
}
rep1 <- function(f, term, lbl) {
  b <- f$b[[term]]; s <- f$se[[term]]
  cat(sprintf("     %-42s %+8.4f  SE %6.4f  ratio %+6.2f\n", lbl, b, s, b/s))
  b
}

cat("\nSR2  THE NAIVE COEFFICIENT -- shares noise with the outcome\n")
bn <- rep1(cluster_se(y ~ x_naive, D, D$pair), "x_naive", "swing deviation on OWN base (t-1)")

cat("\nSR3  THE INSTRUMENT -- base two elections back, noise NOT shared\n")
bi <- rep1(cluster_se(y ~ x_inst, D, D$pair), "x_inst", "swing deviation on base (t-2)")

cat("\nSR4  how much of the naive slope survives?\n")
cat(sprintf("     naive %.4f | instrument %.4f | survives %.0f%%\n",
            bn, bi, 100*bi/bn))
cat("     If the instrument collapses toward zero, the naive slope was\n")
cat("     largely measurement noise. If it holds, the effect is real.\n")

cat("\nSR5  per pair, instrument only\n")
per <- D[, {
  if (.N >= 40 && stats::var(x_inst) > 0)
    .(n = .N, coef = round(stats::coef(stats::lm(y ~ x_inst))[["x_inst"]], 4))
  else .(n = .N, coef = NA_real_)
}, by = .(pair, party)][!is.na(coef)]
print(per)
cat(sprintf("SR5  negative in %d of %d pair-party cells\n",
            sum(per$coef < 0), nrow(per)))

cat("\nSR6  SIZED ON THE SEATS THAT MATTER\n")
for (nm in c("MacKillop", "Ngadjuri", "Hammond", "Narungga")) {
  base <- c(MacKillop = 67.0, Ngadjuri = 46.8, Hammond = 43.7, Narungga = 30.1)[[nm]]
  over <- base - 36.15                      # SA 2022 statewide LNP
  cat(sprintf("     %-10s LNP base %.1f, over-index %+6.1f -> extra move %+6.1f pts\n",
              nm, base, over, bi * over))
}
