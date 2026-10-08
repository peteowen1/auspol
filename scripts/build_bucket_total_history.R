# Per past election: the unpolled bucket's total as the POLLS leave it, as the
# per-candidate model sums it, and as it actually came out. Read by
# bucket_total_blend() to fit, time-forward, how far to move from the poll
# total toward the candidate total. docs/plans/prereg-bucket-total-blend-2026-09-28.md.
#
# Inputs: an audit run with AUSPOL_BUCKET_TOTAL=cand (its BKT1 lines print both
# totals at the point the forecast uses them) and the matching switch-off audit
# (its in_bucket rows give the actual bucket).
#   AUSPOL_BT_LOG   default output/audit-v44bt.log
#   AUSPOL_BT_BASE  default output/statewide-forecast-audit-v44base.csv
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
lf <- Sys.getenv("AUSPOL_BT_LOG", "output/audit-v44bt.log")
bf <- Sys.getenv("AUSPOL_BT_BASE", "output/statewide-forecast-audit-v44base.csv")
L <- grep("^(BKT1|BT1)  ", readLines(lf, warn = FALSE), value = TRUE)
if (!length(L)) stop("no BKT1 lines in ", lf, "; run the audit with AUSPOL_BUCKET_TOTAL=cand")
H <- data.table(pair = sub("^(BKT1|BT1)  ([a-z]+[0-9]{4}):.*", "\\2", L),
                cand_total = as.numeric(sub(".*candidate model ([0-9.]+) .*", "\\1", L)),
                poll_total = as.numeric(sub(".*polls left ([0-9.]+)\\).*", "\\1", L)))
if (anyNA(H) || anyDuplicated(H$pair)) stop("cannot parse the BKT1 lines cleanly")
B <- fread(bf, showProgress = FALSE)
if (any(as.character(B$others_scale) != "0")) stop(bf, " is not a switch-off run")
act <- B[in_bucket == TRUE, .(actual = sum(actual)), by = pair]
lost <- setdiff(H$pair, act$pair)
if (length(lost)) stop("no actual bucket total for pair(s): ", paste(lost, collapse = ", "))
H <- merge(H, act, by = "pair")
H[, date := as.Date(unname(election_dates()[pair]))]
if (anyNA(H$date)) stop("undated pair in the history")
setorder(H, date)
fwrite(H, "output/bucket-total-history.csv")
cat(sprintf("BH1  wrote output/bucket-total-history.csv: %d pairs %s to %s | mean |poll - actual| %.2f, |cand - actual| %.2f\n",
            nrow(H), min(H$date), max(H$date), H[, mean(abs(poll_total - actual))], H[, mean(abs(cand_total - actual))]))
