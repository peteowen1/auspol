# Defector exit reason vs our miss (docs/reviews/defector-overcarry-2026-10-14.md, part 5, pre-registered).
# Joins the coded exit reasons (external/reference/defectors/defector-exit-reasons.csv, hand-coded from
# pre-polling-day sources) to output/defector-holders.csv on election, seat and name.
#   Rscript scripts/diag_defector_reason.R
suppressMessages(library(data.table))
R <- fread(file.path("external", "reference", "defectors", "defector-exit-reasons.csv"))
M <- fread(file.path("output", "defector-holders.csv"))
cat(sprintf("DFR0 %d coded rows (%s); %d defector cases\n", nrow(R),
            paste(sprintf("%s %d", names(table(R$reason)), as.integer(table(R$reason))), collapse = ", "), nrow(M)))
late <- R[reason != "unclear" & !(as.Date(substr(source_date, 1, 10)) < as.Date(polling_day))]
if (nrow(late)) stop("DFR0! source dated on/after polling day: ", paste(late$case_id, collapse = ", "))
X <- merge(M, R[, list(election, seat, name, reason, confidence)], by = c("election", "seat", "name"))
X[, was_mp := as.logical(was_mp)]
if (nrow(X) != nrow(M)) stop(sprintf("DFR1! joined %d of %d cases", nrow(X), nrow(M)))
cat("\nOver-call = final predicted share - actual, points (positive = we gave the defector too much). Retention = actual / previous share.\n")
print(X[, list(n = .N, over_mean = round(mean(over), 1), over_se = round(sd(over) / sqrt(.N), 1),
               retention_median = round(median(ret), 2), old_over_mean = round(mean(old_over), 1)), by = reason][order(reason)])
# Amendment 1 (review part 5): the primary test is on SITTING MEMBERS; all 18 losing candidates came back unclear.
cat("\nSitting members only:\n")
print(X[was_mp == TRUE, list(n = .N, over_mean = round(mean(over), 1), over_se = round(sd(over) / sqrt(.N), 1),
                             retention_median = round(median(ret), 2)), by = reason][order(reason)])
s <- X[was_mp == TRUE & reason == "scandal", over]; p <- X[was_mp == TRUE & reason == "principled", over]
if (length(s) >= 2 && length(p) >= 2) {
  d <- mean(s) - mean(p); se <- sqrt(var(s) / length(s) + var(p) / length(p))
  cat(sprintf("\nDFR2 PRIMARY: scandal minus principled over-call %+.1f (SE %.1f, %.1f SE; n %d vs %d) => %s\n",
              d, se, d / se, length(s), length(p), if (d / se >= 2) "PASSES" else "FAILS"))
}
print(X[order(reason, -over), list(election, seat, name, reason, confidence, prior = round(prior, 1), pred = round(pred, 1),
                                    act = round(act, 1), over = round(over, 1))], nrows = 60)
