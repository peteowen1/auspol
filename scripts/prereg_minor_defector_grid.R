# Execution of docs/plans/prereg-minor-defector-rate-2026-09-17.md.
# Not committed as part of the pre-registration itself -- this is the
# scoring script that runs it, kept on disk for review.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread(file.path("output", "candidacies.csv"), showProgress = FALSE)
MAJ <- c("ALP", "LNP", "NAT")
PAIRS <- all_election_pairs()

kk <- function(d) match_key(surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
                                        if ("name" %in% names(d)) d$name else NA_character_),
                             given_of(if ("given" %in% names(d)) d$given else NA_character_,
                                      if ("name" %in% names(d)) d$name else NA_character_),
                             "initial")

# Build the FIXED 33-case evaluation set at prev_pcv >= 5, same identity-
# matching logic fit_minor_defector_discount() itself uses, across ALL 21
# pairs (no target excluded -- this just enumerates cases, it does not fit
# a rate).
build_cases <- function(floor) {
  rbindlist(lapply(PAIRS, function(pr) {
    PREVT <- C[C$election == pr$prev]
    NOWT  <- C[C$election == pr$election]
    if (!nrow(PREVT) || !nrow(NOWT)) return(NULL)
    PREVT <- copy(PREVT)[, `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
    NOWT  <- copy(NOWT)[,  `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
    a <- PREVT[nzchar(.k) & !party %in% MAJ & pcv >= floor,
               .(.s, .k, prior_pcv = pcv, prior_party = party)][
                 , .SD[which.max(prior_pcv)], by = .(.s, .k)]
    b <- NOWT[nzchar(.k) & !party %in% MAJ, .(.s, .k, target_pcv = pcv, party)][
      , .SD[which.max(target_pcv)], by = .(.s, .k)]
    m <- merge(a, b, by = c(".s", ".k"))
    m <- m[prior_party != party]
    if (!nrow(m)) return(NULL)
    m[, .(target_election = pr$election, seat = .s, key = .k,
          prior_pcv, target_pcv, prior_party, party)]
  }), fill = TRUE)
}

CASES <- build_cases(5)
cat(sprintf("P1  fixed evaluation set: %d cases across %d target elections (floor prev_pcv>=5)\n",
            nrow(CASES), uniqueN(CASES$target_election)))
if (nrow(CASES) != 33) {
  cat("P1! pre-registration's construction gave 33 cases on 2026-09-16's corpus snapshot;\n")
  cat(sprintf("    this run's output/candidacies.csv gives %d -- corpus has moved since (Victorian\n",
              nrow(CASES)))
  cat("    data, identity-matching fixes shipped this session). Proceeding on CURRENT data, not\n")
  cat("    forcing the old count -- the pre-registration fixes the METHOD, not a frozen row count.\n")
}

ARMS <- data.table(arm = c("A", "B", "C", "D"),
                    min_prior = c(10, 5, 10, 5),
                    agg = c("median", "median", "geomean", "geomean"))

targets <- sort(unique(CASES$target_election))

# Leave-target-out rate for every arm x every target election IN THE FULL
# CORPUS, not just the ones with a scored case -- this is what "per-pair
# rate stability across the leave-target-out folds" means in the refusal
# conditions, matching how arm A's own 0.30-0.34 cluster was described over
# the whole corpus. Pair count printed dynamically below, not hardcoded --
# it was 21 when the pre-registration was drafted and is 23 now.
all_targets <- sort(unique(vapply(PAIRS, `[[`, character(1), "election")))
rate_table <- rbindlist(lapply(seq_len(nrow(ARMS)), function(i) {
  arm <- ARMS[i]
  rbindlist(lapply(all_targets, function(te) {
    fit <- fit_minor_defector_discount(te, corpus = C, min_prior = arm$min_prior, agg = arm$agg)
    data.table(arm = arm$arm, target_election = te, discount = fit$discount, n = fit$n)
  }))
}))

cat(sprintf("\nP2  per-pair leave-target-out rates by arm (all %d pairs):\n", length(all_targets)))
print(rate_table[!is.na(discount), .(mean = round(mean(discount), 4), median = round(median(discount), 4),
                                       sd = round(sd(discount), 4), min = round(min(discount), 4),
                                       max = round(max(discount), 4), n_folds = .N), by = arm][order(arm)])

na_rates <- rate_table[is.na(discount)]
if (nrow(na_rates)) {
  cat(sprintf("\nP2! %d (arm,target) cells returned NULL discount (below min_n=5):\n", nrow(na_rates)))
  print(na_rates[, .(arm, target_election, n)])
}

# Score each of the 33 fixed cases using its OWN target election's rate,
# per arm. A case whose target election has no fitted rate for some arm
# (below min_n) is dropped from that arm's RMSE with a count printed --
# refuse to silently treat a missing rate as 0 or 1.
score_arm <- function(arm_name) {
  r <- rate_table[arm == arm_name, .(target_election, discount)]
  cs <- merge(CASES, r, by = "target_election", all.x = TRUE)
  dropped <- cs[is.na(discount)]
  scored <- cs[!is.na(discount)]
  scored[, pred := prior_pcv * discount]
  scored[, resid := target_pcv - pred]
  list(rmse = sqrt(mean(scored$resid^2)), n_scored = nrow(scored),
       n_dropped = nrow(dropped), cases = scored)
}

RESULTS <- lapply(ARMS$arm, score_arm)
names(RESULTS) <- ARMS$arm

cat("\nP3  fixed 33-case evaluation, RMSE per arm:\n")
for (a in ARMS$arm) {
  cat(sprintf("  arm %s (min_prior=%s, agg=%s): RMSE=%.4f  (scored %d/%d cases)\n",
              a, ARMS[arm == a]$min_prior, ARMS[arm == a]$agg,
              RESULTS[[a]]$rmse, RESULTS[[a]]$n_scored, nrow(CASES)))
}

rmseA <- RESULTS[["A"]]$rmse
cat(sprintf("\nP4  primary bar: beat arm A (RMSE %.4f) by >= 5%% (target <= %.4f)\n",
            rmseA, rmseA * 0.95))
for (a in c("B", "C", "D")) {
  pct <- 100 * (rmseA - RESULTS[[a]]$rmse) / rmseA
  cat(sprintf("  arm %s: RMSE %.4f, %.2f%% vs A -- %s\n",
              a, RESULTS[[a]]$rmse, pct, if (pct >= 5) "CLEARS the bar" else "does not clear"))
}

# Refusal condition: gain carried by fewer than 5 of 33 cases. For any arm
# that cleared the primary bar, check how many cases individually improved
# (|resid| smaller under the arm than under A) and how much of the total
# squared-error reduction the top 5 most-improved cases account for.
check_concentration <- function(arm_name) {
  a_cases <- RESULTS[["A"]]$cases[, .(key, seat, target_election, resid_A = resid)]
  x_cases <- RESULTS[[arm_name]]$cases[, .(key, seat, target_election, resid_X = resid)]
  m <- merge(a_cases, x_cases, by = c("key", "seat", "target_election"))
  m[, se_reduction := resid_A^2 - resid_X^2]
  m <- m[order(-se_reduction)]
  n_improved <- sum(m$se_reduction > 0)
  total_reduction <- sum(m$se_reduction)
  top5_reduction <- sum(head(m$se_reduction, 5))
  list(n_improved = n_improved, n_cases = nrow(m),
       top5_share = if (total_reduction > 0) top5_reduction / total_reduction else NA_real_,
       table = m)
}

cat("\nP5  refusal check -- gain concentration (only meaningful for an arm that cleared P4):\n")
for (a in c("B", "C", "D")) {
  cc <- check_concentration(a)
  cat(sprintf("  arm %s: %d/%d cases individually improved; top-5 cases account for %s%% of total SE reduction\n",
              a, cc$n_improved, cc$n_cases,
              if (is.na(cc$top5_share)) "NA (no net reduction)" else sprintf("%.1f", 100 * cc$top5_share)))
}

# Refusal condition: winning arm's per-pair rate spread wider than A's.
cat(sprintf("\nP6  stability check -- sd of per-pair rate across %d folds, arm vs A:\n",
            length(all_targets)))
sdA <- rate_table[arm == "A" & !is.na(discount), sd(discount)]
for (a in c("B", "C", "D")) {
  sdX <- rate_table[arm == a & !is.na(discount), sd(discount)]
  cat(sprintf("  arm %s: sd=%.4f vs A's sd=%.4f -- %s\n",
              a, sdX, sdA, if (sdX > sdA) "WIDER than A (refusal condition)" else "not wider than A"))
}

cat("\nP7  DONE. No guard-check backtest run unless an arm clears P4 AND passes P5/P6 --\n")
cat("    see console output above to determine whether that happened.\n")
