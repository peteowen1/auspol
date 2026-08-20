# Does the One Nation ORDERING rule hold on South Australia 2026?
#
# WHAT THIS IS AND IS NOT. fit_seats_full.R allocates One Nation's statewide
# vote across seats in two separable steps:
#
#   ORDERING  rank districts by their transposed federal One Nation vote
#   SHAPE     `sa_ratio`, the sorted district-to-mean ratios, applied by rank
#
# The SHAPE is fitted on South Australia 2026 itself (line 195), so no test on
# South Australia can validate it -- using SA's own shape to predict SA would
# reproduce the answer by construction. That test is not attempted here and
# cannot be run anywhere: Victoria 2026 is its first out-of-sample exposure.
#
# The ORDERING uses only federal booth data transposed onto state districts, so
# it CAN be tested on South Australia without circularity, and this does.
#
# NO MODEL CHANGE FOLLOWS FROM THIS. It is a replication of the measurement in
# docs/reviews/onp-allocation-sa-2026-08-17.md on a second election, using the
# same three arms and the same two metrics, chosen before the numbers were seen
# because they are simply the ones that test already used:
#
#   Spearman correlation against the actual ordering
#   allocation MAE -- mean |allocated - actual| in points of first preference
#
# Benchmarks from NSW 2023: federal ordering +0.814 Spearman and 1.594 MAE,
# Greens-share proxy +0.331 and 3.287, uniform allocation 2.595. The old proxy
# was WORSE than uniform, which is why it was replaced.
#
# Emits OS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
fed <- fread(file.path(P, "federal-transposed-to-state.csv"), showProgress = FALSE)
act <- fread(file.path(P, "ecsa-2026-sa-firstprefs.csv"), showProgress = FALSE)

# Actual One Nation share of each district's formal vote, 2026.
tot <- act[, .(all = sum(votes)), by = seat]
onp <- merge(act[party == "ONP", .(seat, v = votes)], tot, by = "seat", all.y = TRUE)
onp[is.na(v), v := 0]
onp[, actual := 100 * v / all]

fo <- fed[region == "sa" & cycle == 2026L & party == "ONP", .(seat, fed_onp = pct)]
gr <- act[party == "GRN", .(seat, grn = votes)]
gr <- merge(tot, gr, by = "seat", all.x = TRUE)
gr[is.na(grn), grn := 0][, grn_pct := 100 * grn / all]

d <- merge(merge(onp[, .(seat, actual)], fo, by = "seat"),
           gr[, .(seat, grn_pct)], by = "seat")
if (nrow(d) != 47L) {
  stop("Only ", nrow(d), " of 47 districts have all three measures. Missing a ",
       "transposed federal figure means scripts/transpose_federal_to_state.R ",
       "has not been run with the SA jobs.")
}
cat(sprintf("\nOS1  %d districts | actual ONP %.1f%%..%.1f%%, mean %.2f%%\n",
            nrow(d), min(d$actual), max(d$actual), mean(d$actual)))
cat(sprintf("OS1  transposed federal ONP %.1f%%..%.1f%%, mean %.2f%%\n",
            min(d$fed_onp), max(d$fed_onp), mean(d$fed_onp)))

# The allocation, reproduced as fit_seats_full.R does it: order the districts by
# the rule, then lay the SHAPE over that order. The shape here is SA's own,
# which is why only the ORDERING is under test -- every arm gets the same shape,
# so the comparison is between orderings alone and the shape cancels.
shape <- sort(d$actual / mean(d$actual))
allocate <- function(rank_by) {
  ord <- order(rank_by)
  out <- numeric(nrow(d))
  for (r in seq_along(ord)) {
    q <- (r - 1) / (length(ord) - 1)
    pos <- q * (length(shape) - 1)
    lo <- floor(pos) + 1; hi <- min(lo + 1, length(shape))
    out[ord[r]] <- shape[lo] + (pos - (lo - 1)) * (shape[hi] - shape[lo])
  }
  out * mean(d$actual)
}

arms <- list(
  federal = d$fed_onp,
  greens  = d$grn_pct,           # the rule this replaced: high Greens = low ONP
  uniform = NULL)
res <- rbindlist(lapply(names(arms), function(nm) {
  if (nm == "uniform") {
    alloc <- rep(mean(d$actual), nrow(d)); rho <- NA_real_
  } else {
    by <- if (nm == "greens") -arms[[nm]] else arms[[nm]]
    alloc <- allocate(by)
    rho <- stats::cor(by, d$actual, method = "spearman")
  }
  data.table(arm = nm, spearman = rho, mae = mean(abs(alloc - d$actual)))
}))
cat("\nOS2  ordering rules on SA 2026\n")
print(res[, .(arm, spearman = round(spearman, 3), mae = round(mae, 3))])

cat("\nOS3  the same measures on NSW 2023, from docs/reviews/onp-allocation-sa-2026-08-17.md\n")
cat("OS3    federal +0.814 / 1.594 | greens +0.331 / 3.287 | uniform  --  / 2.595\n")

fed_rho <- res[arm == "federal", spearman]
cat(sprintf("\nOS4  federal ordering reaches %+.3f here against %+.3f on NSW 2023\n",
            fed_rho, 0.814))
if (res[arm == "federal", mae] < res[arm == "uniform", mae]) {
  cat("OS4  and it beats a uniform allocation, as it must to be worth having.\n")
} else {
  cat("OS4  BUT IT DOES NOT BEAT A UNIFORM ALLOCATION on this election, which is\n")
  cat("OS4  the failure the Greens-share rule was retired for.\n")
}

# Where the ordering fails is more useful than that it does: One Nation won four
# seats, and whether the rule ranks those highly decides whether the allocation
# can ever give them a winning share.
won <- c("Hammond", "MacKillop", "Narungga", "Ngadjuri")
d[, rank_fed := rank(-fed_onp)][, rank_actual := rank(-actual)]
cat("\nOS5  the four seats One Nation actually won, of 47\n")
print(d[seat %in% won, .(seat, actual = round(actual, 1),
                         fed_onp = round(fed_onp, 1),
                         rank_by_rule = rank_fed, rank_actual)][order(rank_actual)])
fwrite(d, file.path("output", "onp-ordering-sa2026.csv"))
