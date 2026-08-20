# What two-candidate-preferred does OUR model give One Nation in the seats
# YouGov awards it, against the party they have losing?
#
# The win probability alone cannot separate two very different failures. If our
# central One Nation TCP in those seats is ~35% against their ~50%, a
# probability near zero is CONSISTENT and the disagreement is about the central
# estimate. If our TCP is ~47% and we still say zero, the central estimates
# nearly agree and our SPREAD is far too tight. Those need opposite fixes.
#
# This is the deterministic central case: our projected seat primaries put
# through the same exclusion and the same flow matrix the simulation uses, with
# no noise. Emits OT* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

PREF <- election_data_path()
SMOOTH <- 0.15
tx <- fread(file.path(PREF, "vec-2022-vic-transfers.csv"), showProgress = FALSE)
fm <- build_flow_matrix(tx, min_n = 3L)

sh <- fread("output/seat-shares-vic-2026.csv")
yg <- fread("external/reference/yougov-seats.csv")
yg[, yg_win := fifelse(winner %in% c("Liberal", "National", "Coalition"), "LNP",
              fifelse(winner == "Labor", "ALP",
              fifelse(winner == "One Nation", "ONP",
              fifelse(winner == "Greens", "GRN", "IND"))))]
yg[, yg_run := fifelse(runner_up %in% c("Liberal", "National", "Coalition"), "LNP",
              fifelse(runner_up == "Labor", "ALP",
              fifelse(runner_up == "One Nation", "ONP",
              fifelse(runner_up == "Greens", "GRN", "IND"))))]

parties <- setdiff(names(sh), "seat")
rows <- list()
for (i in seq_len(nrow(sh))) {
  v <- unlist(sh[i, ..parties]); v <- v[is.finite(v) & v > 0]
  r <- distribute_preferences(v, conditional = fm$conditional,
                              pooled = fm$pooled, smooth = SMOOTH)
  fs <- r$final_shares
  rows[[length(rows) + 1L]] <- data.table(
    seat = sh$seat[i], our_win = r$winner,
    a = names(fs)[1], a_pct = as.numeric(fs)[1],
    b = names(fs)[2], b_pct = as.numeric(fs)[2],
    onp_fp = if ("ONP" %in% names(v)) unname(v[["ONP"]]) else 0)
}
ours <- rbindlist(rows)
ours[, `:=`(tot = a_pct + b_pct)]
# ONP's own two-candidate-preferred, when it survives to the final two.
ours[, onp_tcp := fifelse(a == "ONP", 100 * a_pct / tot,
                  fifelse(b == "ONP", 100 * b_pct / tot, NA_real_))]
ours[, made_final := !is.na(onp_tcp)]

m <- merge(ours, yg[, .(seat, yg_win, yg_run, yg_tpp = tpp)], by = "seat")
wp <- fread("output/seat-probs-vic-2026.csv")
m <- merge(m, wp[party == "ONP", .(seat, p_onp = prob)], by = "seat", all.x = TRUE)
m[is.na(p_onp), p_onp := 0]

on <- m[yg_win == "ONP"][order(-onp_tcp, -p_onp)]
cat(sprintf("\nOT1  the %d seats YouGov gives One Nation\n", nrow(on)))
cat("     'our ONP TCP' is One Nation's two-candidate-preferred in OUR central case;\n")
cat("     NA means One Nation does not survive to the final two at all.\n\n")
print(on[, .(seat, yg_tpp, our_final = paste(a, "v", b),
             our_onp_fp = round(onp_fp, 1),
             our_onp_tcp = round(onp_tcp, 1),
             our_p_onp = round(p_onp, 3))])

cat(sprintf("\nOT2  One Nation reaches the final two in %d of those %d seats\n",
            sum(on$made_final), nrow(on)))
if (any(on$made_final)) {
  cat(sprintf("OT2  where it does: our TCP mean %.1f%% (range %.1f-%.1f) vs YouGov's %.1f%% mean\n",
              mean(on$onp_tcp, na.rm = TRUE), min(on$onp_tcp, na.rm = TRUE),
              max(on$onp_tcp, na.rm = TRUE), mean(on$yg_tpp)))
}
cat("\nOT3  the three seats where we say 0.000\n")
z <- m[yg_win == "ONP" & p_onp < 0.001][order(seat)]
print(z[, .(seat, yg_tpp, our_final = paste(a, "v", b),
            our_onp_fp = round(onp_fp, 1), our_onp_tcp = round(onp_tcp, 1))])

cat("\nOT4  diagnosis\n")
gap <- on[made_final == TRUE, mean(yg_tpp - onp_tcp)]
cat(sprintf("     mean gap (YouGov TCP - ours), where comparable: %+.1f points\n", gap))
cat("     A large gap means the CENTRAL estimate differs and a low probability is\n")
cat("     consistent. A small gap with near-zero probabilities means the SPREAD is\n")
cat("     too tight. These need opposite fixes.\n")
fwrite(m[order(seat)], file.path("output", "onp-tcp-comparison.csv"))
cat("\nWrote output/onp-tcp-comparison.csv\n")
