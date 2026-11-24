# Do pollsters' PUBLISHED two-party figures carry information beyond last-election preference flows?
# Kevin Bonham, 24 Nov 2026: Victoria is 55-45 to the Coalition on previous-election-style flows but 57.5-42.5 on the
# two-party figures pollsters release. Our model uses past flows only. This asks, election by election:
#   computed  = Labor two-party from each final-month poll's primaries with the flows recorded at EARLIER elections
#   published = the two-party figure the same polls released
#   actual    = the result
# and whether (published - computed) predicts (actual - computed).
# Run from the repo root:  Rscript docs/reviews/early-vote-scouts-2026-11-24/flows_published_tpp.R
options(auspol.root = normalizePath(".")); suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
fl <- as.data.table(load_preference_flows()); cy <- as.data.table(load_election_cycles()); pri <- as.data.table(load_prior_results())
WINDOW <- 28L
rows <- list(); polls_used <- list()
for (rg in c("fed", "vic", "wa", "sa", "qld", "nsw")) {
  p <- suppressMessages(as.data.table(invisible(utils::capture.output(pp <- load_polls(rg))) -> .x)); p <- as.data.table(pp)
  minors <- setdiff(intersect(names(p), c("GRN", "ONP", "UAP", "DEM", "OTH")), character(0))
  cyr <- cy[cy$region == rg & cy$end < Sys.Date() & cy$year >= 2004][order(year)]
  for (i in seq_len(nrow(cyr))) {
    yy <- cyr$year[i]; ed <- cyr$end[i]
    # actual Labor two-party: the NEXT cycle's recorded previous result
    nxt <- pri[pri$region == rg & pri$party == "@TPP" & pri$year > yy][order(year)]
    if (!nrow(nxt)) next
    actual <- nxt$prev1[1]
    # flows recorded at elections BEFORE this one (never its own row)
    before <- fl[fl$region == rg & fl$year < yy][order(party, -year)]
    f0 <- before[!duplicated(before$party)]
    if (!nrow(f0) || any(f0$exhaust > 0, na.rm = TRUE)) next          # full-preferential elections only
    w <- p[p$date > ed - WINDOW & p$date <= ed & !is.na(p$tpp_published) & !is.na(p$ALP) & !is.na(p$LNP)]
    if (nrow(w) < 2) next
    fo <- function(k) { v <- f0$flow_alp[f0$party == k]; if (length(v)) v else f0$flow_alp[f0$party == "OTH"] }
    comp <- vapply(seq_len(nrow(w)), function(j) {
      s <- vapply(minors, function(k) { v <- w[[k]][j]; if (is.na(v)) 0 else v }, 0)
      tot <- w$ALP[j] + w$LNP[j] + sum(s)
      100 * (w$ALP[j] + sum(s * vapply(minors, fo, 0) / 100)) / tot
    }, 0)
    rows[[length(rows) + 1L]] <- data.table(election = paste0(rg, yy), end = ed, polls = nrow(w), actual = actual,
      published = mean(w$tpp_published), computed = mean(comp), flows_from = paste(sprintf("%s %.0f (%d)", f0$party, f0$flow_alp, f0$year), collapse = ", "))
  }
}
R <- rbindlist(rows)[order(end)]
R[, `:=`(gap = published - computed, err_pub = published - actual, err_comp = computed - actual, surprise = actual - computed)]
cat(sprintf("Elections with 2+ final-%d-day polls carrying a published two-party figure, full-preferential, 2004 on: %d\n", WINDOW, nrow(R)))
cat("All figures are Labor's two-party share in points. gap = published minus computed; err = poll figure minus the result (0 is perfect).\n")
print(R[, .(election, polls, actual = round(actual, 1), published = round(published, 1), computed = round(computed, 1), gap = round(gap, 1),
            err_pub = round(err_pub, 1), err_comp = round(err_comp, 1))], nrows = 100)
cat(sprintf("\nMean absolute error: published %.2f, computed from past flows %.2f (n = %d elections). Published closer in %d of %d.\n",
            mean(abs(R$err_pub)), mean(abs(R$err_comp)), nrow(R), sum(abs(R$err_pub) < abs(R$err_comp)), nrow(R)))
cat(sprintf("RMSE: published %.2f, computed %.2f\n", sqrt(mean(R$err_pub^2)), sqrt(mean(R$err_comp^2))))
m <- lm(surprise ~ gap, R); cf <- summary(m)$coef
cat(sprintf("Does the gap predict the surprise? actual - computed = %.2f + %.2f x gap (slope SE %.2f, n = %d, r = %.2f). Slope 1 = pollsters' figure fully right, 0 = no information.\n",
            cf[1, 1], cf[2, 1], cf[2, 2], nrow(R), cor(R$gap, R$surprise)))
big <- R[abs(gap) >= 1]
cat(sprintf("Elections where the two differed by 1 point or more: %d. In those, the result fell on the published side of the computed figure in %d.\n",
            nrow(big), sum(sign(big$surprise) == sign(big$gap))))
print(big[, .(election, gap = round(gap, 1), surprise = round(surprise, 1))])
rec <- R[end >= as.Date("2016-01-01")]
cat(sprintf("\nSince 2016 only (n = %d): MAE published %.2f, computed %.2f; slope %.2f\n", nrow(rec), mean(abs(rec$err_pub)), mean(abs(rec$err_comp)),
            if (nrow(rec) > 3) coef(lm(surprise ~ gap, rec))[2] else NA))
# this election
v <- as.data.table(load_polls("vic")); v <- v[v$date >= as.Date("2026-10-15")]
f26 <- fl[fl$region == "vic" & fl$year < 2026][order(party, -year)]; f26 <- f26[!duplicated(f26$party)]
cat("\nVICTORIA 2026, polls since 15 Oct on disk (local poll clone; newest poll", format(max(v$date)), "):\n")
print(v[, .(date, firm, published_alp_2pp = tpp_published, ALP, LNP, GRN, ONP, OTH)])
cat(sprintf("mean published Labor two-party %.1f over %d polls that released one; flows recorded before 2026: %s\n", mean(v$tpp_published, na.rm = TRUE), sum(!is.na(v$tpp_published)),
            paste(sprintf("%s %.1f (%d)", f26$party, f26$flow_alp, f26$year), collapse = ", ")))
