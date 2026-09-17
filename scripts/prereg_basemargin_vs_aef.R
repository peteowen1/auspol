# Where does the CURRENT set of output/backtest-*.csv files (one arm) still
# lose to AEF, on the 7 AEF-comparable pairs? Reuses output/aef-seat-scores.csv
# (AEF's own win pick + probability) already on disk. Prints a worst-seats
# table; writes nothing. Usage: Rscript scripts/prereg_basemargin_vs_aef.R <label>
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

ARGS <- commandArgs(trailingOnly = TRUE)
LABEL <- if (length(ARGS)) ARGS[1] else "(unlabelled)"
eps <- 1e-6
MAP <- data.table(
  pair = c("fed2022","nsw2023","vic2022","qld2024","fed2025","wa2025","sa2026"),
  aef_code = c("2022fed","2023nsw","2022vic","2024qld","2025fed","2025wa","2026sa")
)

OUT <- "output"
files <- list.files(OUT, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
files <- grep("-totals|allprobs|-seatsd|-diag|-ourtcp|-sharedetail", files, value = TRUE, invert = TRUE)
rows <- rbindlist(lapply(files, function(f) {
  d <- tryCatch(fread(f, showProgress = FALSE), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL)
  pcol <- if ("prob" %in% names(d)) "prob" else if ("p" %in% names(d)) "p" else NA_character_
  if (is.na(pcol) || !all(c("pred", "actual", "seat") %in% names(d))) return(NULL)
  if (!"pair" %in% names(d)) {
    m <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
    if (!length(m)) return(NULL)
    d[, pair := m]
  }
  d[, .(file = f, mtime = file.mtime(f), pair = as.character(pair), seat = as.character(seat),
        actual = as.character(actual), our_pred = as.character(pred),
        our_p = pmin(pmax(get(pcol), eps), 1))]
}), fill = TRUE)
pick <- rows[, .(mtime = max(mtime)), by = pair]
rows <- merge(rows, pick, by = c("pair", "mtime"))
keep <- rows[, .(file = file[1]), by = pair]
rows <- merge(rows, keep, by = c("pair", "file"))
rows <- rows[pair %in% MAP$pair]

aef_scores <- fread(file.path(OUT, "aef-seat-scores.csv"), showProgress = FALSE)
setnames(aef_scores, c("actual", "pred"), c("aef_actual", "pred"))
rows <- merge(rows, MAP, by = "pair")
m <- merge(rows, aef_scores, by.x = c("aef_code", "seat"), by.y = c("election", "seat"))
m[, aef_p := pmin(pmax(prob, eps), 1)]
m[, delta := (-log(our_p)) - (-log(aef_p))]  # positive = we are worse than AEF on this seat

cat(sprintf("=== %s vs AEF, 7 AEF-comparable pairs, %d matched seats ===\n", LABEL, nrow(m)))
cat(sprintf("Pooled log loss: ours %.4f | AEF %.4f | delta %+.4f\n",
            -mean(log(m$our_p)), -mean(log(m$aef_p)), mean(m$delta)))

cat("\n=== Worst 15 seats where we are most behind AEF ===\n")
setorder(m, -delta)
print(m[1:15, .(pair, seat, actual, our_pred, our_p = round(our_p,3), aef_pred = pred, aef_p = round(aef_p,3),
                delta = round(delta,2))])

cat("\n=== Count of seats where delta > 1.0 (a real, not marginal, loss to AEF), by pair ===\n")
print(m[delta > 1.0, .N, by = pair][order(-N)])

cat(sprintf("\nTotal seats with delta > 1.0: %d of %d (%.1f%%)\n",
            sum(m$delta > 1.0), nrow(m), 100*mean(m$delta > 1.0)))
