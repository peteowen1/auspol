options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
P <- election_data_path()

tx <- fread(file.path(P, "aec-fed-transfers.csv"), showProgress = FALSE)[election == "fed2025"]
fm <- build_flow_matrix(tx, min_n = 3L)

# our projected Ngadjuri primaries (2022 Frome + uniform SA statewide swing)
v <- c(ONP = 31.3, LNP = 29.7, ALP = 23.1, GRN = 1.3)
v <- 100 * v / sum(v)
cat("=== OUR PROJECTED PRIMARIES (renormalised) ===\n")
print(round(v, 1))
cat("\n=== ACTUAL 2026 PRIMARIES ===\n")
act <- c(ONP = 34.9, ALP = 29.5, LNP = 25.3, GRN = 4.7)
print(round(100 * act / sum(act), 1))

rate <- function(from, surv, smooth = 0.15, fb = 0) {
  key <- paste0(from, "|", paste(sort(surv), collapse = "+"))
  r <- fm$conditional[[key]]
  src <- "CONDITIONAL CELL"
  if (is.null(r)) { r <- fm$pooled[[from]]; src <- "POOLED FALLBACK"; smooth <- max(smooth, fb) }
  w <- r[surv]; w[is.na(w)] <- 0
  tot <- sum(w); u <- 1 / length(surv)
  p <- if (tot <= 0) rep(u, length(surv)) else (1 - smooth) * (w / tot) + smooth * u
  names(p) <- surv
  list(p = p, src = src, smooth = smooth)
}

cat("\n\n=== OUR COUNT, step by step ===\n")
alive <- names(sort(v, decreasing = TRUE))
cur <- v
while (length(alive) > 2) {
  lo <- alive[which.min(cur[alive])]
  surv <- setdiff(alive, lo)
  r <- rate(lo, surv, fb = 0.60)
  cat(sprintf("\nexclude %-4s (%.1f%%)  [%s, smooth %.2f]\n", lo, cur[lo], r$src, r$smooth))
  cat("   rates: ", paste(sprintf("%s %.1f%%", names(r$p), 100 * r$p), collapse = "  "), "\n")
  cur[surv] <- cur[surv] + cur[lo] * r$p
  cur[lo] <- 0
  alive <- surv
  cat("   after: ", paste(sprintf("%s %.1f", alive, cur[alive]), collapse = "  "), "\n")
}
cat(sprintf("\n>>> OUR WINNER: %s (%.1f vs %.1f)\n",
            alive[which.max(cur[alive])], max(cur[alive]), min(cur[alive])))

cat("\n\n=== WHAT ACTUALLY HAPPENED (ECSA transfer file, Ngadjuri) ===\n")
sa <- fread(file.path(P, "ecsa-2026-sa-transfers.csv"), showProgress = FALSE)
ng <- sa[seat %in% c("Ngadjuri", "Frome")]
if (nrow(ng)) {
  for (rd in sort(unique(ng$round))) {
    d <- ng[round == rd]
    tot <- sum(d$votes)
    cat(sprintf("\nround %s: exclude %s (%d votes)\n", rd, unique(d$from)[1], tot))
    cat("   went: ", paste(sprintf("%s %.1f%%", d$to, 100 * d$votes / tot), collapse = "  "), "\n")
  }
} else cat("  (no Ngadjuri/Frome rows in the transfer file)\n")

cat("\n\n=== THE COMPARISON THAT MATTERS ===\n")
cat("our exclusion order vs the real one, and the rate each used\n")
