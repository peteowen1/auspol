# Does the old party keep more than the model leaves it when its member defects?
# (docs/reviews/defector-overcarry-2026-10-14.md, part 4). Reads output/defector-holders.csv
# (scripts/diag_defector_holders.R). `prior` is the defector's previous share under the old party's label.
#   combined = defector now + old party now, as a share of `prior`: above 1 means the pair grew.
#   old_over = our old-party share minus actual (negative = we left the old party too little).
#   Rscript scripts/diag_defector_oldparty.R
suppressMessages(library(data.table))
M <- fread(file.path("output", "defector-holders.csv"))
M <- M[is.finite(old_act) & is.finite(old_pred)]
cat(sprintf("DFP0 %d cases with the old party's row predicted and actual\n", nrow(M)))
M[, `:=`(combined_act = (act + old_act) / prior, combined_pred = (pred + old_pred) / prior)]
g <- function(x, lab) cat(sprintf("DFP1 %-18s n=%2d | actual combined/prior median %.2f (>1 in %d) | predicted median %.2f | old party over-call mean %+.1f (SE %.1f), median %+.1f | defector over-call mean %+.1f\n",
  lab, nrow(x), median(x$combined_act), sum(x$combined_act > 1), median(x$combined_pred), mean(x$old_over), sd(x$old_over) / sqrt(nrow(x)), median(x$old_over), mean(x$over)))
g(M, "all"); g(M[was_mp == TRUE], "sitting members"); g(M[was_mp == FALSE], "losing candidates")
for (r in sort(unique(M$region))) g(M[region == r], r)
print(M[order(old_over), list(election, seat, name, prior = round(prior, 1), def_pred = round(pred, 1), def_act = round(act, 1),
                              old_pred = round(old_pred, 1), old_act = round(old_act, 1), old_over = round(old_over, 1),
                              comb_act = round(combined_act, 2), comb_pred = round(combined_pred, 2))], nrows = 60)
