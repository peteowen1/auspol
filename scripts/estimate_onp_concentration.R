# Estimate SD = a * statewide^k for One Nation's district concentration,
# EXCLUDING the election it will be used to predict.
# Against docs/plans/prereg-onp-concentration-transport.md
#
# k = 0 is SD-constant, k = 1 is CV-constant. Scoping showed SD rises with the
# statewide level (+0.499) while CV falls (-0.519), so both endpoints are wrong
# and the truth is between them.
#
# Emits CN* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
PREF <- election_data_path()
HOLD_OUT <- "ecsa-2026-sa-firstprefs.csv"
MIN_STATEWIDE <- 1        # below this the party is noise, not a contestant

fs <- list.files(PREF, pattern = "firstprefs\\.csv$", full.names = TRUE)
rows <- list()
for (f in fs) {
  d <- fread(f, showProgress = FALSE)
  if (!all(c("seat", "party", "votes") %in% names(d))) next
  # SPLIT BY ELECTION. aec-fed-firstprefs.csv pools seven federal elections in
  # one file, so treating a file as an election pooled 2007-2025 into a single
  # row and produced statewide 16.47 with SD 0.96 -- impossible for real
  # division-level data, and it was the second-largest level in the fit.
  d[, .elec := if ("election" %in% names(d)) as.character(election) else basename(f)]
  for (e in unique(d$.elec)) {
    de <- d[.elec == e]
    de[, tot := sum(votes), by = seat]
    de[, pc := 100 * votes / tot]
    o <- de[party == "ONP"]
    if (nrow(o) < 10) next
    seats <- unique(de$seat)
    v <- rep(0, length(seats)); names(v) <- seats
    v[o$seat] <- o$pc
    sw <- 100 * sum(o$votes) / sum(de[!duplicated(paste(seat, party)), votes])
    rows[[length(rows) + 1L]] <- data.table(
      file = if (e == basename(f)) basename(f) else paste0(basename(f), ":", e),
      statewide = sw, sd_pts = stats::sd(v), cv = stats::sd(v) / mean(v))
  }
}
R <- rbindlist(rows)[statewide >= MIN_STATEWIDE]
R[, held_out := file == HOLD_OUT]

cat("=== One Nation concentration by election ===\n")
print(R[order(-statewide), .(file, statewide = round(statewide, 2),
                             sd_pts = round(sd_pts, 2), cv = round(cv, 3), held_out)])

fit_set <- R[held_out == FALSE]
cat(sprintf("\nCN1  fitting on %d elections, holding out %s\n", nrow(fit_set), HOLD_OUT))
stopifnot(nrow(fit_set) >= 5)

m <- stats::lm(log(sd_pts) ~ log(statewide), data = fit_set)
k <- unname(stats::coef(m)[["log(statewide)"]])
a <- exp(unname(stats::coef(m)[["(Intercept)"]]))
cat(sprintf("CN2  SD = %.4f * statewide^%.4f   (R2 %.3f)\n", a, k,
            summary(m)$r.squared))
cat(sprintf("CN2  k = %.3f   (0 = SD-constant, 1 = CV-constant)\n", k))

# R2 of the plan: k outside [0,1] means the functional form is wrong.
if (k < 0 || k > 1) {
  cat("CN2  REFUSAL R2: k is outside [0, 1]; the functional form does not hold.\n")
}

ho <- R[held_out == TRUE]
pred <- a * ho$statewide^k
cat(sprintf("\nCN3  held-out %s: statewide %.2f\n", HOLD_OUT, ho$statewide))
cat(sprintf("CN3  PREDICTED SD %.2f   (actual %.2f, ratio %.2f)\n",
            pred, ho$sd_pts, pred / ho$sd_pts))

# R3 of the plan: report the extrapolation distance explicitly.
cat(sprintf("\nCN4  R3 extrapolation check: fitted statewide range %.2f to %.2f;\n",
            min(fit_set$statewide), max(fit_set$statewide)))
if (ho$statewide > max(fit_set$statewide)) {
  cat(sprintf("     held-out level %.2f is ABOVE that range -- this is an\n",
              ho$statewide))
  cat("     EXTRAPOLATION and the result is provisional, per R3.\n")
} else {
  cat("     held-out level is inside the fitted range -- interpolation.\n")
}

cat(sprintf("\nCN5  run the arm with:  AUSPOL_ONP_CONC_SD=%.2f\n", pred))
