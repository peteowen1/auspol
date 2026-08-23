# What does AE Forecasts actually achieve, on the metrics we score ourselves on?
#
# WHY THIS EXISTS. docs/ANCHOR-MODEL.md has always said our accuracy has never
# been tested against either reference. It could not be: we had their CODE but
# not their forecasts. Their site publishes eight archived elections through a
# REST API, and scripts/fetch_aeforecasts.R now downloads the final forecast and
# the official result for each.
#
# THE COMPARISON IS NOT YET APPLES TO APPLES, AND THIS SCRIPT DOES NOT PRETEND
# IT IS. Their number is a genuine pre-election forecast: it knew polls and
# nothing else. Our backtest takes each election's ACTUAL statewide result and
# swings it across seats, which is strictly more information than any forecaster
# has. So our figures are advantaged and must not be reported beside theirs as
# though they were the same test. What this script establishes is the BAR --
# what a real forecast achieves on real elections. Closing the gap in method is
# separate work, recorded in docs/NEXT-STEPS.md.
#
# Emits AE* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

RAW <- file.path("external", "reference", "aef")
CODES <- c("2022vic","2022fed","2022sa","2023nsw","2024qld","2025wa","2025fed","2026sa")
EPS <- 1e-6

# Their party indices are integers, and NEGATIVE ones are generic candidates of
# that type -- a nameless independent rather than a named one. Both map to the
# same class for scoring, or an independent who was forecast generically would
# count as a different party from the one who won.
aef_party <- function(pairs) {
  v <- vapply(pairs, function(p) as.character(p[[2]]), character(1))
  k <- vapply(pairs, function(p) as.integer(p[[1]]), integer(1))
  stats::setNames(v, as.character(k))
}

score_one <- function(code) {
  fs <- file.path(RAW, sprintf("%s-summary.json", code))
  fr <- file.path(RAW, sprintf("%s-results.json", code))
  if (!file.exists(fs) || !file.exists(fr)) return(NULL)
  j <- fromJSON(fs, simplifyVector = FALSE)$report
  R <- fromJSON(fr, simplifyVector = FALSE)$results

  # partyAbbr arrives as flat [index, abbrev] pairs
  pa <- j$partyAbbr
  lookup <- aef_party(pa)
  seats <- unlist(j$seatNames)
  wf <- j$seatPartyWinFrequencies

  rows <- list()
  for (i in seq_along(seats)) {
    nm <- seats[i]
    truth <- R$seats[[nm]]
    if (is.null(truth) || is.null(truth$tcp) || length(truth$tcp) < 1) next
    actual <- names(truth$tcp)[which.max(unlist(truth$tcp))]
    p <- wf[[i]]
    if (!length(p)) next
    idx <- vapply(p, function(x) as.character(x[[1]]), character(1))
    pct <- vapply(p, function(x) as.numeric(x[[2]]), numeric(1))
    cls <- unname(lookup[idx])
    keep <- !is.na(cls)
    if (!any(keep)) next
    # a class can appear twice (named and generic); its probability is the sum
    agg <- tapply(pct[keep], cls[keep], sum)
    prob_actual <- if (actual %in% names(agg)) unname(agg[[actual]]) / 100 else 0
    pred <- names(agg)[which.max(agg)]
    rows[[length(rows) + 1L]] <- data.table(
      election = code, seat = nm, actual = actual, pred = pred,
      pred_p = unname(max(agg)) / 100, prob = prob_actual)
  }
  if (!length(rows)) return(NULL)
  out <- rbindlist(rows)
  out[, `:=`(tpp_actual = R$overall$tpp %||% NA_real_)]
  out
}

all <- rbindlist(lapply(CODES, score_one), fill = TRUE)
stopifnot(nrow(all) > 0)

cat("\nAE1  AE Forecasts, final pre-election forecast, scored on the official result\n")
per <- all[, .(seats = .N,
               accuracy = round(100 * mean(pred == actual), 1),
               brier = round(mean((1 - prob)^2), 4),
               logloss = round(-mean(log(pmax(prob, EPS))), 4)), by = election]
setorder(per, election); print(per)
cat(sprintf("AE1  pooled %d seat-elections across %d elections: accuracy %.1f%%, Brier %.4f, log %.4f\n",
            nrow(all), uniqueN(all$election), 100 * mean(all$pred == all$actual),
            mean((1 - all$prob)^2), -mean(log(pmax(all$prob, EPS)))))

cat("\nAE2  calibration slope (1.0 = calibrated; below 1 = over-confident)\n")
sl <- all[, {
  z <- data.frame(y = as.integer(pred == actual),
                  lo = stats::qlogis(pmin(pmax(pred_p, EPS), 1 - EPS)))
  s <- if (length(unique(z$y)) > 1)
    suppressWarnings(stats::coef(stats::glm(y ~ lo, data = z,
      family = stats::binomial()))[["lo"]]) else NA_real_
  .(slope = round(s, 2))}, by = election]
setorder(sl, election); print(sl)
zz <- data.frame(y = as.integer(all$pred == all$actual),
                 lo = stats::qlogis(pmin(pmax(all$pred_p, EPS), 1 - EPS)))
cat(sprintf("AE2  pooled slope %.2f\n", suppressWarnings(stats::coef(stats::glm(
  y ~ lo, data = zz, family = stats::binomial()))[["lo"]])))

fwrite(all, file.path("output", "aef-seat-scores.csv"))
cat(sprintf("\nAE3  wrote output/aef-seat-scores.csv (%d rows)\n", nrow(all)))
