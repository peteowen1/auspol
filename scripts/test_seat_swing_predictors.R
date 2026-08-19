# Do the seat-file fields load_seats() ignores predict seat swing?
#
# Against docs/plans/prereg-seat-swing-predictors.md, committed before anything
# was measured. The criterion, the 0.10 bar and the four refusals are in the
# plan and are NOT restated here so they cannot drift.
#
# Predictors come from the file written BEFORE an election; the outcome is that
# election's actual per-seat two-party swing, which sits in the file written for
# the FOLLOWING cycle as fPreviousTppSwing.
#
# Emits SW* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

ADOPT_BY <- 0.10

seat_file <- function(f) {
  path <- anchor_data_path(file.path("..", "..", "analysis", "seats", f))
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  blocks <- strsplit(txt, "#", fixed = TRUE)[[1]]
  blocks <- blocks[nzchar(trimws(blocks))]
  rbindlist(lapply(blocks, function(b) {
    lines <- strsplit(b, "\n", fixed = TRUE)[[1]]
    nm <- trimws(lines[1])
    kv <- lines[grepl("=", lines, fixed = TRUE)]
    keys <- sub("=.*$", "", kv); vals <- sub("^[^=]*=", "", kv)
    get1 <- function(k) {
      hit <- vals[keys == k]
      if (!length(hit)) NA_character_ else trimws(hit[1])
    }
    data.table(
      seat = nm,
      incumbent = get1("sIncumbent"),
      fed_swing = suppressWarnings(as.numeric(get1("fTransposedFederalSwing"))),
      retirement = !is.na(get1("bRetirement")),
      soph_cand = !is.na(get1("bSophomoreCandidate")),
      soph_party = !is.na(get1("bSophomoreParty")),
      prev_swing = suppressWarnings(as.numeric(get1("fPreviousTppSwing"))))
  }), fill = TRUE)
}

build <- function(before, after, label) {
  b <- seat_file(before); a <- seat_file(after)
  d <- merge(b[, .(seat, incumbent, fed_swing, retirement, soph_cand, soph_party)],
             a[, .(seat, actual_swing = prev_swing)], by = "seat")
  d <- d[is.finite(fed_swing) & is.finite(actual_swing)]
  # Swing is reported toward Labor. Express every predictor from the INCUMBENT
  # party's point of view so a coefficient means the same thing in both states:
  # retirement should hurt the incumbent wherever they sit.
  d[, alp_inc := incumbent == "ALP"]
  d[, election := label]
  d[]
}

vic <- build("2022vic.txt", "2026vic.txt", "vic2022")
nsw <- build("2023nsw.txt", "2027nsw.txt", "nsw2023")
dt <- rbind(vic, nsw)
cat(sprintf("\nSW1  seats with predictors and outcome: vic %d, nsw %d, total %d\n",
            nrow(vic), nrow(nsw), nrow(dt)))
cat(sprintf("SW1  actual swing: mean %+.2f, sd %.2f\n",
            mean(dt$actual_swing), stats::sd(dt$actual_swing)))

# The baseline is what the model does now: every seat gets the statewide swing,
# so the predicted DEVIATION is zero. Centre within each election, since the
# statewide swing differs between them and is not what is being predicted.
dt[, dev := actual_swing - mean(actual_swing), by = "election"]
cat(sprintf("SW1  baseline (uniform swing) MAE: %.3f\n", mean(abs(dt$dev))))

# Incumbent-facing predictors: flip sign where the Coalition holds the seat, so
# a positive coefficient always means "helps the incumbent".
dt[, ret_i  := fifelse(alp_inc,  as.numeric(retirement), -as.numeric(retirement))]
dt[, soc_i  := fifelse(alp_inc,  as.numeric(soph_cand),  -as.numeric(soph_cand))]
dt[, sop_i  := fifelse(alp_inc,  as.numeric(soph_party), -as.numeric(soph_party))]
dt[, fed_c  := fed_swing - mean(fed_swing), by = "election"]

FORM <- dev ~ fed_c + ret_i + soc_i + sop_i

cat("\nSW2  fitted on ALL seats, for the coefficient signs only\n")
m_all <- stats::lm(FORM, data = dt)
print(round(summary(m_all)$coefficients, 4))

# Leave-one-election-out, which is the pre-registered criterion.
res <- rbindlist(lapply(unique(dt$election), function(e) {
  tr <- dt[election != e]; te <- dt[election == e]
  m <- stats::lm(FORM, data = tr)
  p <- stats::predict(m, newdata = te)
  data.table(election = e, n = nrow(te),
             mae_base = mean(abs(te$dev)),
             mae_model = mean(abs(te$dev - p)))
}))
res[, gain := mae_base - mae_model]
cat("\nSW3  leave-one-election-out (the criterion)\n")
print(res)

pooled_base <- mean(abs(dt$dev))
pooled_model <- {
  p <- unlist(lapply(unique(dt$election), function(e) {
    tr <- dt[election != e]; te <- dt[election == e]
    abs(te$dev - stats::predict(stats::lm(FORM, data = tr), newdata = te))
  }))
  mean(p)
}
pooled_gain <- pooled_base - pooled_model
cat(sprintf("SW3  pooled: baseline %.3f, model %.3f, gain %+.3f (adopt above %.2f)\n",
            pooled_base, pooled_model, pooled_gain, ADOPT_BY))

# R1: the gain must not reverse between the two held-out elections.
r1 <- all(res$gain > 0)
cat(sprintf("\nSW4  R1 gain positive in BOTH held-out elections: %s (%s)\n",
            if (r1) "yes" else "NO -- REFUSE",
            paste(sprintf("%s %+.3f", res$election, res$gain), collapse = ", ")))

# R2: signs. Positive = helps the incumbent.
co <- stats::coef(m_all)
signs <- c(fed_c = unname(co[["fed_c"]]) > 0, ret_i = unname(co[["ret_i"]]) < 0,
           soc_i = unname(co[["soc_i"]]) > 0, sop_i = unname(co[["sop_i"]]) > 0)
cat("SW4  R2 expected signs (fed +, retirement -, sophomores +):\n")
print(signs)
r2 <- all(signs)
cat(sprintf("SW4  R2: %s\n", if (r2) "all as expected" else "A SIGN IS BACKWARDS -- REFUSE"))

# R3: residual spread must shrink.
sd_base <- stats::sd(dt$dev)
sd_res <- stats::sd(stats::resid(m_all))
cat(sprintf("SW4  R3 residual sd %.3f -> %.3f: %s\n", sd_base, sd_res,
            if (sd_res < sd_base) "shrinks" else "DOES NOT SHRINK -- REFUSE"))
r3 <- sd_res < sd_base

verdict <- if (!r1) "REFUSE (R1: gain reverses between elections)" else
  if (!r2) "REFUSE (R2: a coefficient sign is backwards)" else
  if (!r3) "REFUSE (R3: residual spread does not shrink)" else
  if (pooled_gain > ADOPT_BY) "ADOPT" else
  sprintf("do not adopt: gain %+.3f does not clear %.2f", pooled_gain, ADOPT_BY)
cat(sprintf("\nSW5  verdict: %s\n", verdict))

fwrite(dt, file.path("output", "seat-swing-predictors.csv"))
cat("\nWrote output/seat-swing-predictors.csv\n")
