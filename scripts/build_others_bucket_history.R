# The unpolled "others" bucket per past election: its day-before forecast and
# its counted result. Read by others_bucket_scale() (R/others_bucket.R) to fit,
# time-forward, how much the polls overstate the classes they do not track.
# docs/plans/prereg-others-bucket-size-2026-09-27.md.
#
# Built from a statewide audit run with AUSPOL_OTHERS_SCALE OFF: a history
# taken from a corrected run would fit the correction to its own output.
#
#   AUSPOL_AUDIT_TAG=-x Rscript scripts/audit_statewide_forecast.R   (switch off)
#   AUSPOL_AUDIT_TAG=-x Rscript scripts/build_others_bucket_history.R
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
src <- sprintf("output/statewide-forecast-audit%s.csv", Sys.getenv("AUSPOL_AUDIT_TAG", ""))
A <- fread(src, showProgress = FALSE)
cat(sprintf("BOB0  read %s: %d rows, %d pairs\n", src, nrow(A), uniqueN(A$pair)))
if (!all(c("in_bucket", "others_scale") %in% names(A)))
  stop(src, " predates the in_bucket/others_scale columns; rerun the audit.")
if (any(as.character(A$others_scale) != "0"))
  stop(src, " was run with AUSPOL_OTHERS_SCALE on. The history must come from ",
       "the uncorrected forecast, or the correction is fitted to itself.")
H <- A[in_bucket == TRUE, .(bucket_fc = sum(forecast), bucket_act = sum(actual),
                            classes = paste(cls, collapse = ";")), by = pair]
dts <- election_dates()
H[, date := as.Date(unname(dts[pair]))]
if (anyNA(H$date)) stop("No election date for: ", paste(H[is.na(date), pair], collapse = ", "))
if (H[, any(!is.finite(bucket_fc) | !is.finite(bucket_act) | bucket_fc <= 0 | bucket_act <= 0)])
  stop("A non-positive or missing bucket value; a log ratio cannot be taken.")
setorder(H, date)
fwrite(H, "output/others-bucket-history.csv")
cat(sprintf("BOB1  wrote output/others-bucket-history.csv: %d elections %s to %s; bucket over-forecast in %d; mean forecast-actual %+.2f\n",
            nrow(H), min(H$date), max(H$date), H[, sum(bucket_fc > bucket_act)], H[, mean(bucket_fc - bucket_act)]))
