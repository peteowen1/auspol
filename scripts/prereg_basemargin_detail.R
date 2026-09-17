# Detailed pooling for docs/plans/prereg-xgb-base-margin-2026-09-17.md's
# guard backtest -- IND-specific log loss, AEF7 subset, and the
# sa2026/wa2021-excluded pooled figure, none of which scripts/pool_backtests.R
# reports on its own (it pools seat-elections, not by party class or subset).
# Run AFTER scripts/pool_backtests.R, against the SAME output/backtest-*.csv
# files currently on disk for one arm. Writes nothing; prints only.
# Usage: Rscript scripts/prereg_basemargin_detail.R <label>
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

ARGS <- commandArgs(trailingOnly = TRUE)
LABEL <- if (length(ARGS)) ARGS[1] else "(unlabelled)"
EPS <- 1e-6
AEF7 <- c("fed2022", "fed2025", "nsw2023", "qld2024", "sa2026", "vic2022", "wa2025")

OUT <- "output"
files <- list.files(OUT, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
files <- grep("-totals|allprobs|-seatsd|-diag|-ourtcp|-sharedetail", files, value = TRUE, invert = TRUE)

rows <- rbindlist(lapply(files, function(f) {
  d <- tryCatch(fread(f, showProgress = FALSE), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL)
  pcol <- if ("prob" %in% names(d)) "prob" else if ("p" %in% names(d)) "p" else NA_character_
  if (is.na(pcol) || !all(c("pred", "actual") %in% names(d))) return(NULL)
  if (!"pair" %in% names(d)) {
    m <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
    if (!length(m)) return(NULL)
    d[, pair := m]
  }
  d[, .(file = f, mtime = file.mtime(f), pair = as.character(pair),
        seat = if ("seat" %in% names(d)) as.character(seat) else NA_character_,
        actual = as.character(actual), pred = as.character(pred),
        p = pmin(pmax(get(pcol), EPS), 1))]
}), fill = TRUE)
if (!nrow(rows)) stop("no readable backtest files in ", OUT)

# newest file per pair, same rule as pool_backtests.R
pick <- rows[, .(mtime = max(mtime)), by = pair]
rows <- merge(rows, pick, by = c("pair", "mtime"))
keep <- rows[, .(file = file[1]), by = pair]
rows <- merge(rows, keep, by = c("pair", "file"))

cat(sprintf("=== %s ===\n", LABEL))
cat(sprintf("pairs present: %d, seat-elections: %d\n", uniqueN(rows$pair), nrow(rows)))
cat(sprintf("POOLED, all pairs: log loss %.4f | Brier %.4f | accuracy %.4f\n",
            -mean(log(rows$p)), mean((1 - rows$p)^2), mean(rows$pred == rows$actual)))

r7 <- rows[pair %in% AEF7]
cat(sprintf("POOLED, AEF7 only (n=%d): log loss %.4f | Brier %.4f | accuracy %.4f\n",
            nrow(r7), -mean(log(r7$p)), mean((1 - r7$p)^2), mean(r7$pred == r7$actual)))

rx <- rows[!pair %in% c("sa2026", "wa2021")]
cat(sprintf("POOLED, EXCLUDING sa2026+wa2021 (n=%d): log loss %.4f (vs %.4f for all pairs)\n",
            nrow(rx), -mean(log(rx$p)), -mean(log(rows$p))))

cat("\n=== log loss by pair the party that ACTUALLY WON belonged to (IND row = seats IND won) ===\n")
print(rows[, .(n = .N, logloss = round(-mean(log(p)), 4), accuracy = round(mean(pred == actual), 4)),
           by = .(actual)][order(-n)])

cat("\n=== nsw2023 / vic2022 / wa2025 individually (the three AEF7 pairs that got worse at primary level) ===\n")
print(rows[pair %in% c("nsw2023", "vic2022", "wa2025"),
           .(n = .N, logloss = round(-mean(log(p)), 4), accuracy = round(mean(pred == actual), 4)), by = pair])

cat("\n=== per pair, full table ===\n")
print(rows[, .(n = .N, logloss = round(-mean(log(p)), 4), accuracy = round(mean(pred == actual), 4),
               mtime = format(max(mtime), "%H:%M:%S")), by = pair][order(pair)])
