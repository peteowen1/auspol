# The PREVIOUS election's early in-person vote share by seat, for every election
# whose predecessor publishes votes by type. Read by R/demographic_residual.R
# when AUSPOL_DEMO_RESID_EARLY is on (plans/prereg-early-share-labor-2026-11-24.md).
#
# Run:  Rscript scripts/early_vote_panel.R && Rscript scripts/build_prev_early_share.R
# Out:  output/prev-early-share.csv  (pair, seat, prev_el, prev_early)
#
# LEAKAGE: the value for election X comes only from the election BEFORE X in the
# same jurisdiction, a counted result that was public years ahead of X. "Before"
# is the immediately preceding election in the candidate corpus, so an election
# whose predecessor has no vote-type split (sa2026, qld2020) gets no rows rather
# than an older election's value.
suppressPackageStartupMessages(library(data.table))
seat <- fread("output/early-vote/panel-seat.csv", encoding = "UTF-8")
cand <- fread("output/candidacies.csv", encoding = "UTF-8", select = c("election", "seat"))
el <- unique(cand[, .(election)])
el[, `:=`(juris = sub("[0-9]+$", "", election), year = as.integer(sub("^[a-z]+", "", election)))]
setorder(el, juris, year)
el[, prev_el := shift(election), by = juris]
el <- el[!is.na(prev_el) & prev_el %in% seat$election]
seats <- unique(cand[election %in% el$election, .(pair = election, seat)])
seats <- merge(seats, el[, .(pair = election, prev_el)], by = "pair")
out <- merge(seats, seat[, .(prev_el = election, seat, prev_early = round(100 * early_sh, 3))], by = c("prev_el", "seat"))
setcolorder(out, c("pair", "seat", "prev_el", "prev_early")); setorder(out, pair, seat)
cov <- merge(seats[, .(seats = .N), by = pair], out[, .(with_value = .N, mean_early = round(mean(prev_early), 1)), by = pair], by = "pair", all.x = TRUE)
cat("PES1 previous election's early share: seats with a value / seats in the election, and the mean (% of formal votes):\n")
print(merge(cov, el[, .(pair = election, prev_el)], by = "pair")[order(pair)])
stopifnot(nrow(out) > 1500, !anyNA(out$prev_early), all(out$prev_early > 0 & out$prev_early < 100),
          "vic2026" %in% out$pair, out[pair == "vic2026", .N] >= 80, !anyDuplicated(out[, .(pair, seat)]))
fwrite(out, "output/prev-early-share.csv")
cat(sprintf("PES2 wrote output/prev-early-share.csv: %d rows, %d elections\n", nrow(out), uniqueN(out$pair)))
