# Re-validate the ADOPTED seat-swing predictors on five elections, not two.
#
# Against docs/plans/prereg-seat-swing-revalidation.md, committed before this
# ran. The decision rule and refusals K1-K4 are there.
#
# seat_swing_adjustment() is live in simulate_seats(). It was validated on two
# elections. Today the independent model improved by 1.46 SE on one election and
# got 2.52 SE WORSE on six, so two elections establishes nothing.
#
# fed_swing is empty in every federal seat file -- correctly, there is no
# separate federal swing at a federal election -- so the primary model uses the
# three predictors present everywhere and fed_swing is reported on the two state
# elections only.
#
# Emits RS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# (before year, before region, after year, after region, label, is_federal)
ELECTIONS <- list(
  list(2022, "vic", 2026, "vic", "vic2022", FALSE),
  list(2023, "nsw", 2027, "nsw", "nsw2023", FALSE),
  list(2019, "fed", 2022, "fed", "fed2019", TRUE),
  list(2022, "fed", 2025, "fed", "fed2022", TRUE),
  list(2025, "fed", 2028, "fed", "fed2025", TRUE))

build <- function(E) {
  b <- as.data.table(load_seats(E[[1]], E[[2]]))
  a <- as.data.table(load_seats(E[[3]], E[[4]]))
  d <- merge(b[, .(seat, incumbent, fed_swing, retirement, soph_cand, soph_party)],
             a[, .(seat, actual_swing = prev_swing)], by = "seat")
  # Seats present in one file and not the other vanish through this inner join.
  # Reported per election, because a pooled seat count hides a one-to-three seat
  # loss -- North Sydney and Higgins both drop from the 2022->2025 pair.
  lost <- setdiff(b$seat, a$seat)
  n_before <- nrow(d)
  d <- d[is.finite(actual_swing)]
  if (length(lost) || nrow(d) < n_before) {
    cat(sprintf("     %-8s %d seats: %d unmatched (%s), %d with no recorded swing
",
                E[[5]], nrow(d), length(lost),
                if (length(lost)) paste(sort(lost), collapse = ", ") else "none",
                n_before - nrow(d)))
  }
  d[, `:=`(alp_inc = incumbent == "ALP", election = E[[5]], federal = E[[6]])]
  d[]
}
dt <- rbindlist(lapply(ELECTIONS, build), fill = TRUE)

# Deviation from the election's own statewide swing -- what a uniform-swing
# model predicts as zero, and what the adjustment is trying to explain.
dt[, dev := actual_swing - mean(actual_swing), by = "election"]
# Incumbent-facing, so a positive coefficient always means "helps the incumbent"
# regardless of which side holds the seat.
dt[, ret_i := fifelse(alp_inc, as.numeric(retirement), -as.numeric(retirement))]
dt[, soc_i := fifelse(alp_inc, as.numeric(soph_cand),  -as.numeric(soph_cand))]
dt[, sop_i := fifelse(alp_inc, as.numeric(soph_party), -as.numeric(soph_party))]

cat(sprintf("\nRS1  %d seats across %d elections\n", nrow(dt), uniqueN(dt$election)))
print(dt[, .(seats = .N, sd_dev = round(stats::sd(dev), 2),
             baseline_mae = round(mean(abs(dev)), 3)), by = election])

FORM <- dev ~ ret_i + soc_i + sop_i

# ---- K1/K2: the pooled fit, all three predictors, signs checked -------------
m <- stats::lm(FORM, data = dt)
co <- summary(m)$coefficients
cat("\nRS2  pooled fit, all five elections (K1: all three kept regardless of t)\n")
print(round(co, 4))
signs_ok <- co["ret_i", 1] < 0 && co["soc_i", 1] > 0
cat(sprintf("RS2  K2 signs: retirement hurts the incumbent %s, sophomore gains %s -> %s\n",
            if (co["ret_i", 1] < 0) "YES" else "NO",
            if (co["soc_i", 1] > 0) "YES" else "NO",
            if (signs_ok) "PASS" else "FAIL -- the original finding was noise"))

# ---- leave-one-election-out ------------------------------------------------
res <- rbindlist(lapply(unique(dt$election), function(e) {
  tr <- dt[election != e]; te <- dt[election == e]
  fit <- stats::lm(FORM, data = tr)
  pred <- stats::predict(fit, newdata = te)
  data.table(election = e, federal = te$federal[1], n = nrow(te),
             mae_uniform = mean(abs(te$dev)),
             mae_model = mean(abs(te$dev - pred)))
}))
res[, gain := mae_uniform - mae_model]
cat("\nRS3  leave-one-election-out (positive gain = the adjustment helps)\n")
print(res[, .(election, federal, n, uniform = round(mae_uniform, 3),
              model = round(mae_model, 3), gain = round(gain, 4))])
pooled_u <- sum(res$mae_uniform * res$n) / sum(res$n)
pooled_m <- sum(res$mae_model * res$n) / sum(res$n)
cat(sprintf("RS3  pooled: uniform %.4f, model %.4f, gain %+.4f\n",
            pooled_u, pooled_m, pooled_u - pooled_m))
cat(sprintf("RS3  positive in %d of %d elections (rule needs 3 of 5)\n",
            sum(res$gain > 0), nrow(res)))
cat(sprintf("RS3  original two-election gain was +0.0371\n"))

# ---- K3: federal and state reported apart ----------------------------------
cat("\nRS4  K3 -- federal and state are not assumed interchangeable\n")
for (f in c(FALSE, TRUE)) {
  r <- res[federal == f]
  cat(sprintf("     %-7s %d elections, %d seats, pooled gain %+.4f\n",
              if (f) "federal" else "state", nrow(r), sum(r$n),
              sum(r$mae_uniform * r$n) / sum(r$n) - sum(r$mae_model * r$n) / sum(r$n)))
}

# ---- K4: settle C6 ----------------------------------------------------------
cat("\nRS5  K4 -- coefficient stability, in standard errors\n")
full <- stats::coef(m)
st <- rbindlist(lapply(unique(dt$election), function(e) {
  f <- stats::lm(FORM, data = dt[election != e])
  cf <- stats::coef(f); se <- summary(f)$coefficients[, 2]
  data.table(held_out = e, term = names(cf), value = cf,
             shift_se = abs(cf - full[names(cf)]) / se)
}))
w <- dcast(st[term != "(Intercept)"], term ~ held_out, value.var = "value")
cat("     coefficient by held-out election\n"); print(w)
mx <- st[term != "(Intercept)", .(max_shift_se = round(max(shift_se), 2)), by = term]
cat("     largest shift from the pooled value, in that fit's own SE\n"); print(mx)
cat(sprintf("RS5  C6 asked whether soph_cand is stable. Largest shift %.2f SE -> %s\n",
            mx[term == "soc_i", max_shift_se],
            if (mx[term == "soc_i", max_shift_se] < 2) "STABLE, C6 is answered"
            else "UNSTABLE, C6 stands"))

# ---- fed_swing, state elections only, no claim made -------------------------
sub <- dt[federal == FALSE & is.finite(fed_swing)]
if (nrow(sub)) {
  sub[, fed_c := fed_swing - mean(fed_swing), by = "election"]
  m4 <- stats::lm(dev ~ fed_c + ret_i + soc_i + sop_i, data = sub)
  cat("\nRS6  fed_swing, on the two STATE elections only -- reported, not tested\n")
  print(round(summary(m4)$coefficients, 4))
}

verdict <- if (pooled_u - pooled_m <= 0) {
  "WITHDRAW -- held-out MAE is worse than uniform swing"
} else if (sum(res$gain > 0) >= 3) {
  "KEEP as adopted"
} else "UNRESOLVED -- gain is concentrated in too few elections"
cat(sprintf("\nRS7  verdict: %s\n", verdict))
fwrite(res, file.path("output", "seat-swing-revalidation.csv"))
