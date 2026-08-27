# Scores docs/plans/prereg-salience-separates-new-candidates.md (05a7c7a),
# written before nsw2023 and sa2026 salience existed.
#
# THE QUESTION, which arm C defined. Candidate identity splits three ways and
# the model pools two of them: a new candidate who will poll nothing and a new
# candidate who will WIN are indistinguishable from the corpus, because neither
# has a prior vote in the seat. Dai Le had 0.0%. Pooling them is why conditional
# slopes hurt every emergence election they touched.
#
# So: within the NEW-candidate population only, does salience rank the winners
# to the top?
#
# Emits SN* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

FIT  <- "fed2022"            # selected the framing; cannot test it
TEST <- c("nsw2023", "sa2026")
PREV <- c(fed2022 = "fed2019", fed2025 = "fed2022",
          nsw2023 = "nsw2019", sa2026 = "sa2022")

S <- fread("output/salience-v5.csv", showProgress = FALSE)
S[, elected := elected %in% TRUE]

# NEW = nobody of this class in this seat stood before. Uses candidate_returns(),
# which matches on surname plus first initial and normalises the seat name --
# vic2018 and vic2022 spell seats differently and an exact join matched zero.
S[, newc := NA]
for (el in intersect(names(PREV), unique(S$election))) {
  r <- tryCatch(candidate_returns(PREV[[el]], el), error = function(e) NULL)
  if (is.null(r)) { cat(sprintf("SN0! no candidate history for %s\n", el)); next }
  nk <- function(a, b) paste(gsub("[^a-z0-9]", "", tolower(a)), b)
  ix <- which(S$election == el)
  m <- match(nk(S$seat[ix], S$party[ix]), nk(r$seat, r$party))
  S[ix, newc := ifelse(is.na(m), TRUE, !r$same[m])]
}
cat(sprintf("SN1  %d rows | elections present: %s\n", nrow(S),
            paste(sort(unique(S$election)), collapse = ", ")))

auc_of <- function(x) {
  n1 <- sum(x$elected); n0 <- nrow(x) - n1
  if (!n1 || !n0) return(NA_real_)
  rk <- rank(x$jump)
  (sum(rk[which(x$elected)]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
report <- function(el, tag) {
  x <- S[election == el & newc == TRUE]
  if (!nrow(x)) { cat(sprintf("SN2  %-8s NOT FETCHED\n", el)); return(invisible(NULL)) }
  a <- auc_of(x); w <- x[elected == TRUE]
  if (!nrow(w)) {
    cat(sprintf("SN2  %-8s %3d new candidates, ZERO winners -- no contrast, cannot score\n",
                el, nrow(x))); return(invisible(NULL))
  }
  pct <- 100 * rank(x$jump)[which(x$elected)] / nrow(x)
  # GUARD, same units and same population as the primary.
  thr <- min(w$jump); above <- x[jump >= thr]
  fp <- nrow(above) - nrow(w)
  cat(sprintf("\nSN2  %-8s [%s] %3d new candidates | %d winners\n", el, tag, nrow(x), nrow(w)))
  cat(sprintf("     PRIMARY  AUC %.3f (bar 0.80) -> %s\n", a,
              if (is.na(a)) "n/a" else if (a >= 0.80) "PASS" else "FAIL"))
  cat(sprintf("     SECOND   median winner percentile %.0f (bar 85) -> %s\n",
              median(pct), if (median(pct) >= 85) "PASS" else "FAIL"))
  cat(sprintf("     GUARD    %d non-winners above the winners' minimum jump, %.1f per winner (bar 4) -> %s\n",
              fp, fp / nrow(w), if (fp / nrow(w) <= 4) "PASS" else "FAIL"))
  print(w[order(-jump), .(seat, who = keyword, party, prev = round(prev_party, 1),
                          jump = round(jump, 2), pcv = round(pcv, 1),
                          pctile = round(100 * rank(x$jump)[which(x$elected)][order(-w$jump)]))],
        row.names = FALSE)
  invisible(list(el = el, auc = a, n = nrow(x), w = nrow(w)))
}
cat("\n=== FITTING ELECTION, reported and NOT decisive ===")
report(FIT, "fit")
cat("\n\n=== THE TEST ===")
for (el in TEST) report(el, "held out")

# REFUSAL: One Nation is a PARTY emergence, not a personal one. A personal-name
# signal detecting it is likelier leakage than skill, so sa2026 is scored again
# without them.
x <- S[election == "sa2026" & newc == TRUE]
if (nrow(x) && any(x$elected)) {
  y <- x[!(elected & party == "ONP")]
  cat(sprintf("\nSN3  sa2026 EXCLUDING the One Nation winners: %d winners left | AUC %s\n",
              sum(y$elected), if (any(y$elected)) sprintf("%.3f", auc_of(y)) else "none -- result rests entirely on ONP"))
}
