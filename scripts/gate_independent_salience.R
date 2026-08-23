# GATE: does campaign salience separate a breakout independent from a token one?
#
# Fixed BEFORE any query was run, and before any distribution was looked at:
#
#   CRITERION    AUC of the challenger/incumbent search ratio for predicting a
#                breakout (>= 20% of first preferences).
#   PASS         AUC >= 0.75
#   FAIL         AUC <= 0.65
#   INCONCLUSIVE in between -- that needs more candidacies, not a new threshold.
#
#   EXCLUSION    candidacies where the independent IS the sitting member. That is
#                incumbency, not emergence, and the ratio would be 1.0 by
#                construction. Five refused attempts show the model already
#                handles sitting independents; the open question is emergence.
#
# WHY AN ANCHOR TERM. Google Trends normalises 0-100 WITHIN each query, so a
# candidate scoring 100 in one query and a different candidate scoring 100 in
# another are not comparable. Every query pairs the challenger with the sitting
# member, and the RATIO between them is what carries across queries. Getting
# this wrong would not error -- it would silently compare incomparable numbers.
#
# WHY THIS RATHER THAN SEAT HISTORY. reviews/independent-signal-2026-08-23.md:
# every teal seat already had an independent standing, so Goldstein 2022
# (1.3% -> 35.3%) is identical to a seat where a 1.3% independent stays at 1.3%
# on every feature the five refused models used. Only a contemporaneous,
# candidate-level observation can separate them.
#
# EVERY RESPONSE IS CACHED to external/reference/trends, one file per candidacy.
# gtrendsR scrapes Google's unofficial widget endpoint and has had no functional
# commits in a year, so it may break without warning. The cache means a break --
# or a throttle mid-run -- loses nothing already collected, and swapping the
# transport later costs none of the data.
#
# Emits GS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(gtrendsR))

CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
N_EACH <- as.integer(Sys.getenv("AUSPOL_GATE_N", "10"))
SLEEP  <- as.numeric(Sys.getenv("AUSPOL_GATE_SLEEP", "9"))

m <- fread("output/ind-candidacies.csv", showProgress = FALSE)
before <- nrow(m)
m <- m[name != sitting]            # the exclusion, applied before sampling
cat(sprintf("\nGS0  %d candidacies, %d after excluding sitting independents\n",
            before, nrow(m)))
set.seed(42)
pick <- rbind(m[breakout == TRUE][sample(.N, min(N_EACH, .N))],
              m[breakout == FALSE][sample(.N, min(N_EACH, .N))])
cat(sprintf("GS1  sampled %d (%d breakout, %d not), seed 42\n",
            nrow(pick), sum(pick$breakout), sum(!pick$breakout)))

# The ten weeks before polling day, ending STRICTLY before it, so nothing after
# the election can reach the feature.
POLL <- c("2019" = "2019-05-18", "2022" = "2022-05-21", "2025" = "2025-05-03")

grab <- function(challenger, incumbent, year) {
  key <- gsub("[^A-Za-z0-9]", "_", sprintf("%d-%s-%s", year, challenger, incumbent))
  f <- file.path(CACHE, paste0(key, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  to <- as.Date(POLL[[as.character(year)]]) - 1
  from <- to - 70
  r <- tryCatch(gtrends(keyword = c(challenger, incumbent), geo = "AU",
                        time = paste(from, to), onlyInterest = TRUE),
                error = function(e) NULL)
  out <- if (is.null(r) || is.null(r$interest_over_time)) NULL else {
    d <- as.data.frame(r$interest_over_time)
    # "<1" is Google's low-volume marker and reads as NA; it means near-zero,
    # not missing, so treating it as NA would drop exactly the token candidates
    # this gate exists to identify.
    d$hits <- suppressWarnings(as.numeric(gsub("<", "", d$hits)))
    d$hits[is.na(d$hits)] <- 0
    a <- tapply(d$hits, d$keyword, mean, na.rm = TRUE)
    if (!all(c(challenger, incumbent) %in% names(a))) NULL else
      list(chal = unname(a[[challenger]]), inc = unname(a[[incumbent]]))
  }
  if (!is.null(out)) saveRDS(out, f)
  out
}

rows <- list(); miss <- 0L
for (i in seq_len(nrow(pick))) {
  p <- pick[i]
  r <- grab(p$name, p$sitting, p$year)
  if (is.null(r)) { miss <- miss + 1L; Sys.sleep(SLEEP); next }
  rows[[length(rows) + 1L]] <- data.table(
    year = p$year, seat = p$seat, name = p$name, sitting = p$sitting,
    pct = p$pct, breakout = p$breakout, chal = r$chal, inc = r$inc,
    ratio = r$chal / max(r$inc, 0.1))
  cat(sprintf("GS2  %d %-15s %-20s %5.1f%%  ratio %6.3f%s\n", p$year, p$seat,
              p$name, p$pct, r$chal / max(r$inc, 0.1),
              if (p$breakout) "   <- breakout" else ""))
  flush.console(); Sys.sleep(SLEEP)
}
R <- rbindlist(rows)
cat(sprintf("\nGS3  %d of %d retrieved, %d unavailable or throttled\n",
            nrow(R), nrow(pick), miss))

# A throttled run must not read as a negative result. This repo's most common
# failure is absence of evidence presented as measurement.
if (nrow(R) < 8L || uniqueN(R$breakout) < 2L) {
  cat("GS3  NOT ENOUGH DATA TO DECIDE -- this is throttling, not a finding.\n")
} else {
  a <- R[breakout == TRUE, ratio]; b <- R[breakout == FALSE, ratio]
  auc <- mean(outer(a, b, ">") + 0.5 * outer(a, b, "=="))
  cat(sprintf("\nGS4  breakout ratio median %.3f (n=%d), non-breakout %.3f (n=%d)\n",
              stats::median(a), length(a), stats::median(b), length(b)))
  cat(sprintf("GS4  AUC %.3f  ->  %s\n", auc,
      if (auc >= 0.75) "PASS -- the signal separates" else
      if (auc <= 0.65) "FAIL -- it does not" else
      "INCONCLUSIVE -- more candidacies, not a new threshold"))
  fwrite(R, "output/ind-salience-gate.csv")
}
