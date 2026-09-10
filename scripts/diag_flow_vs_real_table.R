# Score the xgb flow model against the table the SIMULATOR ACTUALLY USES.
#
# scripts/diag_flow_by_evidence.R said xgb beats the table at every evidence
# level, including 8.4% better on cells with 100+ historical events -- which
# flatly contradicts the two seat walkthroughs, where the table held a strong
# local signal (wa2001 ALP|IND+LNP: table IND 90.8 vs xgb 72.8, and IND won).
#
# Both can be true, because they are not comparing the same table.
#
#   `base_pred` in the oof file = 0.85 * cond_rate + 0.15 * uniform, where
#   cond_rate is pooled over EVERY OTHER ELECTION (leave-one-election-out).
#
#   The harness = build_flow_matrix(TX[election == PREV]), the conditional
#   rates from the SINGLE IMMEDIATELY PRECEDING election, same jurisdiction.
#
# The second carries "what happened in this state last time"; the first washes
# it out across 25 elections and three decades. The xgb model's own features
# are the pooled kind, so it cannot represent recency or locality at all -- and
# every published comparison of "xgb vs the table" has been scored against the
# wrong table.
#
# This scores all three against the truth on the target election's own flows.
#
# Emits DR* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

PAIRS <- list(
  list(el = "fed2016", prev = "fed2013", file = "aec-fed-transfers.csv"),
  list(el = "fed2013", prev = "fed2010", file = "aec-fed-transfers.csv"),
  list(el = "fed2022", prev = "fed2019", file = "aec-fed-transfers.csv"),
  list(el = "fed2025", prev = "fed2022", file = "aec-fed-transfers.csv"),
  list(el = "nsw2023", prev = "nsw2019", file = "nswec-nsw-transfers.csv"),
  list(el = "qld2024", prev = "qld2020", file = "ecq-qld-transfers.csv"),
  list(el = "wa2017",  prev = "wa2013",  file = "waec-wa-transfers.csv"),
  list(el = "wa2021",  prev = "wa2017",  file = "waec-wa-transfers.csv")
)

OOF <- fread("output/xgb-flows-v1-oof-predictions.csv", showProgress = FALSE)
EL <- election_data_path()
rmse <- function(a, b) sqrt(mean((a - b)^2, na.rm = TRUE))

res <- rbindlist(lapply(PAIRS, function(P) {
  O <- OOF[election == P$el]
  if (!nrow(O)) return(NULL)
  tx <- fread(file.path(EL, P$file), showProgress = FALSE)[election == P$prev]
  if (!nrow(tx)) { cat(sprintf("DR0! %s: no %s transfers -- skipped\n", P$el, P$prev)); return(NULL) }
  fm <- build_flow_matrix(tx, min_n = 3L)
  # The harness's own value for each row, by the key the simulator would look
  # up. NA where the table has no entry -- that is the fallback case and is
  # counted separately rather than silently imputed, because imputing it is
  # what would make the table look artificially good or bad.
  ky <- paste0(O$from, "|", O$surv)
  O[, tbl := vapply(seq_len(.N), function(i) {
    v <- fm$conditional[[ky[i]]]
    if (is.null(v) || !(O$to[i] %in% names(v))) NA_real_ else unname(v[[O$to[i]]]) / 100
  }, numeric(1))]
  has <- !is.na(O$tbl)
  data.table(
    election = P$el, rows = nrow(O), covered = sum(has),
    # scored ONLY on rows the real table can answer, so all three are
    # predicting the identical set
    real_table = rmse(O$tbl[has], O$y[has]),
    pooled_base = rmse(O$base_pred[has], O$y[has]),
    xgb = rmse(O$xgb_pred[has], O$y[has]))
}))

res[, `:=`(xgb_beats_real = real_table - xgb, xgb_beats_pooled = pooled_base - xgb)]
cat("\nDR1  RMSE against the truth, on the rows the REAL harness table can answer. LOWER IS BETTER.\n")
cat("     real_table = build_flow_matrix(previous election). pooled_base = the oof file's base_pred.\n")
cat("     Positive xgb_beats_* means xgb is better than that baseline.\n")
print(res[, .(election, rows, covered,
              real_table = round(real_table, 4), pooled_base = round(pooled_base, 4),
              xgb = round(xgb, 4), xgb_beats_real = round(xgb_beats_real, 4),
              xgb_beats_pooled = round(xgb_beats_pooled, 4))])

cat(sprintf("\nDR2  xgb beats the REAL table in %d of %d elections; beats the pooled base in %d of %d\n",
            sum(res$xgb_beats_real > 0), nrow(res),
            sum(res$xgb_beats_pooled > 0), nrow(res)))
cat(sprintf("DR2  mean RMSE: real_table %.4f | pooled_base %.4f | xgb %.4f\n",
            mean(res$real_table), mean(res$pooled_base), mean(res$xgb)))
cat("DR2  If real_table beats xgb while pooled_base does not, the flow model is losing a\n")
cat("     RECENCY/LOCALITY signal it has no feature for -- not losing to the lookup in general.\n")
