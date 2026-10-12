# Screen for docs/plans/prereg-federal-breakdowns-in-blend-2026-10-12.md: federal polls' state breakdowns in the
# recent-poll blend. Day-before level (shipped recipe: trend from output/level-recent.csv + 20-day decay blend,
# k refitted time-forward under each arm) against the actual, per arm. Read-only.
# Run: powershell.exe -Command 'Rscript "scripts/screen_fed_breakdowns.R"'
# Data.table NSE: masks are built outside [...]; no local shares a column name used inside brackets.
t0 <- Sys.time()
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
suppressMessages(library(data.table))
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
stopifnot(identical(level_recent_mode(), "decay"))
tab <- fread(out_path("level-recent.csv"), showProgress = FALSE)
eds <- election_dates()
TARGETS <- c("vic2022", "nsw2023", "qld2024", "wa2025", "sa2026")
RGRID <- c(0.05, 0.1, 0.15, 0.25, 0.5, 1)
ELS <- setdiff(unique(tab$election), c("vic2026", "nsw2027"))

levels_under <- function(r, ghl = 90) {
  Sys.setenv(AUSPOL_LEVEL_FED_R = format(r), AUSPOL_LEVEL_FED_GAP_HL = format(ghl))
  on.exit(Sys.setenv(AUSPOL_LEVEL_FED_R = "0", AUSPOL_LEVEL_FED_GAP_HL = "90"), add = TRUE)
  rbindlist(lapply(ELS, function(e) {
    d <- tab[tab$election == e]; lv <- setNames(d$trend, d$cls)
    if (any(!is.finite(lv[c("ALP", "LNP", "GRN")]))) return(NULL)
    lv <- c(lv[c("ALP", "LNP", "GRN")], OTH = 100 - sum(lv[c("ALP", "LNP", "GRN")]))
    invisible(capture.output(res <- level_recent_apply(lv, e, d$region[1], as.Date(unname(eds[e])), code = "FQ", tab = tab)))
    data.table(e = e, k = c("ALP", "LNP", "GRN"), lev = unname(res[c("ALP", "LNP", "GRN")]),
               actual = d$actual[match(c("ALP", "LNP", "GRN"), d$cls)])
  }))
}
base <- levels_under(0)
cat(sprintf("FQ0 shipped (r = 0): %d cells / %d elections; applies AUSPOL_LEVEL_RECENT=%s HL=%s\n", nrow(base), uniqueN(base$e),
            level_recent_mode(), Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE")))
cat(sprintf("FQ0 shipped all-cell RMSE %.3f (scripts/diag_level_mde.R gave 2.315 for the same recipe: r = 0 must match)\n",
            sqrt(mean((base$lev - base$actual)^2))))
fp0 <- .lr_fed_polls()
cat(sprintf("FQ0 federal breakdowns used: %d polls (results and duplicates dropped), %d states, %s to %s\n",
            nrow(fp0), uniqueN(fp0$st), min(fp0$end), max(fp0$end)))
arms <- list(); for (r in RGRID) arms[[paste0("r", r)]] <- levels_under(r)
arms[["r0.15_gap180"]] <- levels_under(0.15, 180)
cat(sprintf("FQ1 %d arms computed, %.0f s\n", length(arms), as.numeric(Sys.time() - t0, units = "secs")))

rmse <- function(x, a) sqrt(mean((x - a)^2))
jk <- function(a, b, act, el) {
  full <- rmse(a, act) - rmse(b, act); u <- unique(el); G <- length(u)
  th <- vapply(u, function(x) { m <- el != x; rmse(a[m], act[m]) - rmse(b[m], act[m]) }, 0)
  c(diff = full, se = sqrt((G - 1) / G * sum((th - mean(th))^2)))
}
tmask <- base$e %in% TARGETS
for (nm in names(arms)) {
  A <- arms[[nm]]; stopifnot(identical(A$e, base$e), identical(A$k, base$k))
  other <- max(abs(A$lev[!tmask] - base$lev[!tmask]))
  moved <- unique(A$e[!tmask][abs(A$lev[!tmask] - base$lev[!tmask]) > 0])
  cat(sprintf("FQ2 %-13s other elections max |change| %.6f%s\n", nm, other, if (length(moved)) paste0(" (", paste(moved, collapse = ","), ")") else ""))
}

# F2: r per target from the EARLIER targets only, shrunk toward 0.15 by 3 pseudo-elections
pick <- rbindlist(lapply(TARGETS, function(x) {
  past <- TARGETS[as.Date(unname(eds[TARGETS])) < as.Date(unname(eds[x]))]   # results known before x's polling day
  stopifnot(all(as.Date(unname(eds[past])) < as.Date(unname(eds[x]))))
  m <- length(past)
  if (!m) return(data.table(e = x, m = 0L, r_hat = NA_real_, r = 0.15))
  sse <- vapply(c(0, RGRID), function(r) {
    A <- if (r == 0) base else arms[[paste0("r", r)]]; mm <- A$e %in% past; sum((A$lev[mm] - A$actual[mm])^2) }, 0)
  rh <- c(0, RGRID)[which.min(sse)]
  data.table(e = x, m = m, r_hat = rh, r = (m * rh + 3 * 0.15) / (m + 3))
}))
cat("FQ3 F2 r per target (time-forward, shrunk to 0.15 by 3 pseudo-elections):\n"); print(pick)
# F2's level: interpolate between the two grid arms around its shrunk r (linear in r between grid points)
grid_lev <- function(e0, r) {
  g <- c(0, RGRID); lv <- sapply(g, function(rr) { A <- if (rr == 0) base else arms[[paste0("r", rr)]]; A$lev[A$e == e0] })
  apply(lv, 1, function(v) approx(g, v, xout = r)$y)
}
F2 <- copy(base); for (x in TARGETS) F2$lev[F2$e == x] <- grid_lev(x, pick$r[pick$e == x])

B <- base[tmask]
cat(sprintf("\nFQ4 targeted cells %d (%d elections). Day-before level RMSE vs actual (points, lower better):\n", nrow(B), uniqueN(B$e)))
cat(sprintf("     shipped (r = 0)   %.3f\n", rmse(B$lev, B$actual)))
show <- c(list(F1 = arms[["r0.15"]], F2 = F2), arms)
for (nm in names(show)) {
  A <- show[[nm]][tmask]; r <- jk(A$lev, B$lev, B$actual, B$e)
  cat(sprintf("     %-13s %.3f  vs shipped %+.3f (SE %.3f)%s\n", nm, rmse(A$lev, A$actual), r["diff"], r["se"],
              if (nm %in% c("F1", "F2")) if (r["diff"] <= r["se"]) "  non-inferior: PASS" else "  FAIL" else ""))
}
cat("\nFQ5 per election and class (shipped -> F1 -> F2, actual):\n")
P <- data.table(e = B$e, k = B$k, shipped = round(B$lev, 2), F1 = round(arms[["r0.15"]]$lev[tmask], 2), F2 = round(F2$lev[tmask], 2), actual = round(B$actual, 2))
print(P)
cat(sprintf("\nFQ6 dry run vic2022: max |F1 - shipped| %.2f, max |F2 - shipped| %.2f (prereg: <= 0.6)\n",
            max(abs(P$F1 - P$shipped)[P$e == "vic2022"]), max(abs(P$F2 - P$shipped)[P$e == "vic2022"])))

# live vic2026 and nsw2027: the decayed recent-poll mean (blend weight is ~1, so this is the level)
for (lv in c("vic2026", "nsw2027")) {
  st <- sub("[0-9]{4}$", "", lv); ed <- as.Date(unname(eds[lv])); cs <- .lr_prev_date(lv)
  off <- level_recent_decay_avg(st, ed, 20, cs, as_at = Sys.Date())
  Sys.setenv(AUSPOL_LEVEL_FED_R = "0.15"); on1 <- level_recent_decay_avg(st, ed, 20, cs, as_at = Sys.Date()); Sys.setenv(AUSPOL_LEVEL_FED_R = "0")
  cat(sprintf("FQ7 live %s recent-poll mean, off -> F1 (r 0.15): %s | n_eff %.2f -> %.2f\n", lv,
              paste(sprintf("%s %.1f -> %.1f", names(off$avg), off$avg, on1$avg), collapse = ", "), off$n_eff, on1$n_eff))
}
cat(sprintf("FQ9 done in %.0f s\n", as.numeric(Sys.time() - t0, units = "secs")))
