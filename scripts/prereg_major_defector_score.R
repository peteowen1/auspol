# Score AUSPOL_DEFECT_CONSERVE=1 (shipped) vs =0 against the 33-case fixed
# evaluation set from docs/plans/prereg-major-defector-conserve-2026-09-17.md.
# Reads the sharedetail files collected under output/_prereg_major/ (one per
# harness/pair-group per condition, all built with AUSPOL_XGB_PRIMARY=0 so
# pred_share is genuine base_pred, not the xgb challenger's prediction).
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

# Rebuild the exact same 33-case fixed set as the sizing step.
cases <- rbindlist(lapply(PAIRS, function(pr) {
  PREVT <- C[C$election == pr$prev]
  NOWT  <- C[C$election == pr$election]
  if (!nrow(PREVT) || !nrow(NOWT)) return(NULL)
  if (!"elected" %in% names(PREVT)) return(NULL)
  PREVT <- copy(PREVT)[, `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
  NOWT  <- copy(NOWT)[,  `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
  a <- PREVT[nzchar(.k) & party %in% MAJ,
             .(.s, .k, prior_pcv = pcv, prior_party = party, was_mp = elected %in% TRUE)][
               , .SD[which.max(prior_pcv)], by = .(.s, .k)]
  b <- NOWT[nzchar(.k) & !party %in% MAJ, .(.s, .k, target_pcv = pcv, party)][
    , .SD[which.max(target_pcv)], by = .(.s, .k)]
  m <- merge(a, b, by = c(".s", ".k"))
  if (!nrow(m)) return(NULL)
  old_now <- NOWT[party %in% MAJ, .(old_now_pcv = sum(pcv, na.rm = TRUE), n_old_now = .N), by = .(.s, party)]
  setnames(old_now, "party", "prior_party")
  m <- merge(m, old_now, by = c(".s", "prior_party"), all.x = TRUE)
  m[is.na(old_now_pcv), `:=`(old_now_pcv = 0, n_old_now = 0)]
  m[, .(pair = pr$election, seat = .s, prior_party, new_party = party,
        was_mp, prior_pcv, target_pcv, old_now_pcv, n_old_now)]
}), fill = TRUE)
cases <- cases[n_old_now > 0]
cat(sprintf("M1  fixed evaluation set: %d cases across %d pairs\n", nrow(cases), uniqueN(cases$pair)))

SD_DIR <- file.path("output", "_prereg_major")
load_sd <- function(files) {
  rbindlist(lapply(files, function(f) {
    d <- fread(file.path(SD_DIR, f), showProgress = FALSE)
    if (!"pair" %in% names(d)) {
      # single-pair harness files sometimes omit `pair` -- infer from filename
      pr <- regmatches(f, regexpr("(fed|nsw|qld|sa|vic|wa)[0-9]{4}", f))
      if (!length(pr)) stop("cannot infer pair from filename: ", f)
      d[, pair := pr]
    }
    d[, .(pair = as.character(pair), seat = normalise_seat(seat), party, pred_share)]
  }), fill = TRUE)
}

SD1 <- load_sd(c("fed_conserve1_sharedetail.csv", "nsw_conserve1_sharedetail.csv",
                  "qld2024_conserve1_sharedetail.csv", "qld2020_conserve1_sharedetail.csv",
                  "sa2026_conserve1_sharedetail.csv", "sa2022_conserve1_sharedetail.csv",
                  "vic_conserve1_sharedetail.csv", "wa_conserve1_sharedetail.csv"))
SD0 <- load_sd(c("fed_conserve0_sharedetail.csv", "nsw_conserve0_sharedetail.csv",
                  "qld2024_conserve0_sharedetail.csv", "qld2020_conserve0_sharedetail.csv",
                  "sa2026_conserve0_sharedetail.csv", "sa2022_conserve0_sharedetail.csv",
                  "vic_conserve0_sharedetail.csv", "wa_conserve0_sharedetail.csv"))
cat(sprintf("M2  loaded %d conserve=1 rows, %d conserve=0 rows\n", nrow(SD1), nrow(SD0)))

score <- function(SD, label) {
  m <- merge(cases, SD, by.x = c("pair", "seat", "prior_party"), by.y = c("pair", "seat", "party"), all.x = TRUE)
  missing <- m[is.na(pred_share)]
  if (nrow(missing)) {
    cat(sprintf("M3! %s: %d of %d cases have NO matching sharedetail row (dropped, not zero-filled):\n",
                label, nrow(missing), nrow(m)))
    print(missing[, .(pair, seat, prior_party)])
  }
  scored <- m[!is.na(pred_share)]
  scored[, resid := old_now_pcv - pred_share]
  list(rmse = sqrt(mean(scored$resid^2)), n = nrow(scored), n_missing = nrow(missing), cases = scored)
}

R1 <- score(SD1, "conserve=1 (shipped)")
R0 <- score(SD0, "conserve=0 (non-conserving)")

cat(sprintf("\nM4  RMSE, base_pred layer, fixed %d-case set: conserve=1 (shipped) = %.4f (n=%d/%d) | conserve=0 = %.4f (n=%d/%d)\n",
            nrow(cases), R1$rmse, R1$n, nrow(cases), R0$rmse, R0$n, nrow(cases)))
pct <- 100 * (R1$rmse - R0$rmse) / R1$rmse
cat(sprintf("M5  primary bar: conserve=0 must beat conserve=1 by >= 5%% (target RMSE <= %.4f). Actual: %.2f%% -- %s\n",
            R1$rmse * 0.95, pct, if (pct >= 5) "CLEARS the bar" else "does not clear"))

cat("\nM6  by subgroup (sitting-member vs losing-candidate), RMSE:\n")
for (grp in c(TRUE, FALSE)) {
  r1g <- sqrt(mean(R1$cases[was_mp == grp]$resid^2))
  r0g <- sqrt(mean(R0$cases[was_mp == grp]$resid^2))
  cat(sprintf("  was_mp=%s (n=%d): conserve=1 RMSE=%.4f, conserve=0 RMSE=%.4f, delta=%+.2f%%\n",
              grp, sum(R1$cases$was_mp == grp), r1g, r0g, 100 * (r1g - r0g) / r1g))
}

cat("\nM7  concentration check (only meaningful if M5 clears): per-case squared-error reduction\n")
mm <- merge(R1$cases[, .(pair, seat, prior_party, resid1 = resid)],
            R0$cases[, .(pair, seat, prior_party, resid0 = resid)],
            by = c("pair", "seat", "prior_party"))
mm[, se_reduction := resid1^2 - resid0^2]
setorder(mm, -se_reduction)
n_improved <- sum(mm$se_reduction > 0)
total_reduction <- sum(mm$se_reduction)
top5 <- sum(head(mm$se_reduction, 5))
cat(sprintf("  %d/%d cases individually improved; top-5 cases account for %s%% of total SE reduction\n",
            n_improved, nrow(mm),
            if (total_reduction != 0) sprintf("%.1f", 100 * top5 / total_reduction) else "NA (no net reduction)"))
cat("\n  worst-to-best movers (top 8):\n")
print(mm[order(-se_reduction)][1:min(8, .N), .(pair, seat, prior_party, resid1 = round(resid1,1),
                                                 resid0 = round(resid0,1), se_reduction = round(se_reduction,1))])

cat("\nM8  pooled primary RMSE guard (all rows, both conditions):\n")
for (nm in c("fed", "nsw", "qld2024", "qld2020", "sa2026", "sa2022", "vic", "wa")) {
  f1 <- file.path(SD_DIR, sprintf("%s_conserve1_sharedetail.csv", nm))
  f0 <- file.path(SD_DIR, sprintf("%s_conserve0_sharedetail.csv", nm))
  if (!file.exists(f1) || !file.exists(f0)) next
  d1 <- fread(f1, showProgress = FALSE); d0 <- fread(f0, showProgress = FALSE)
  rmse1 <- sqrt(mean((d1$pred_share - d1$actual_share)^2, na.rm = TRUE))
  rmse0 <- sqrt(mean((d0$pred_share - d0$actual_share)^2, na.rm = TRUE))
  cat(sprintf("  %-8s: conserve=1 pooled RMSE=%.4f (n=%d) | conserve=0 pooled RMSE=%.4f (n=%d) | delta=%+.4f\n",
              nm, rmse1, nrow(d1), rmse0, nrow(d0), rmse0 - rmse1))
}

cat("\nM9  DONE.\n")
