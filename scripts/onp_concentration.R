# How concentrated is a One Nation vote, and is South Australia 2026 typical?
#
# WHY. docs/reviews/onp-conversion-2026-08-21.md left the Victorian forecast
# resting on ONE number: how concentrated One Nation's vote is across seats.
# That decides how many seats it leads, and leading is most of winning. The
# model takes its concentration from South Australia 2026 -- a coefficient of
# variation of 0.327 -- which is one election.
#
# The federal corpus holds One Nation's district-level vote for seven elections
# across every state. That cannot settle Victoria, but it can say whether SA
# 2026 is an ordinary amount of concentration or an unusual one.
#
# THE LIMIT, STATED FIRST. Federal One Nation polls 5-10% where Victoria is
# forecast near 20%. Concentration need not be scale-free: a party at 6% can be
# concentrated in a way a party at 22% cannot, simply because the ceiling binds.
# So this is a second reading of the same quantity at a DIFFERENT level, not a
# replication.
#
# Emits OC* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
fp <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)

# Division -> state, from the AEC polling place file, which names both.
pp <- fread(file.path("external", "reference", "aec", "booths", "pp-fed2022.csv"),
            skip = 1L, showProgress = FALSE)
st <- unique(pp[, .(seat = DivisionNm, state = State)])

d <- merge(fp, st, by = "seat")
d[, pct := 100 * votes / sum(votes), by = .(election, seat)]

cv <- function(x) if (mean(x) > 0) stats::sd(x) / mean(x) else NA_real_

out <- d[, {
  onp <- .SD[party == "ONP"]
  seats <- uniqueN(.SD$seat)
  contested <- nrow(onp)
  # Across CONTESTED divisions only. Including a division One Nation did not
  # contest as a zero measures its contest rate, not the shape of its support,
  # and the two get conflated constantly.
  .(seats = seats, contested = contested,
    statewide = if (contested) sum(onp$votes) / sum(.SD$votes) * 100 else 0,
    cv = if (contested >= 5) cv(onp$pct) else NA_real_)
}, by = .(election, state)]

out <- out[contested >= 5 & statewide >= 3]
setorder(out, -statewide)
cat("\nOC1  One Nation's district-level spread, federal, where it contested 5+\n")
cat("OC1  divisions in a state and polled 3%+ there\n")
print(out[, .(election, state, seats, contested,
              statewide = round(statewide, 1), cv = round(cv, 3))])

cat(sprintf("\nOC2  federal CV: median %.3f across %d state-elections, range %.3f-%.3f\n",
            stats::median(out$cv, na.rm = TRUE), nrow(out),
            min(out$cv, na.rm = TRUE), max(out$cv, na.rm = TRUE)))

# South Australia 2026, the election the model's shape is taken from.
sa <- fread(file.path(P, "ecsa-2026-sa-firstprefs.csv"), showProgress = FALSE)
sa[, pct := 100 * votes / sum(votes), by = seat]
sa_onp <- sa[party == "ONP"]
sa_cv <- cv(sa_onp$pct)
cat(sprintf("\nOC3  South Australia 2026: statewide %.1f%%, %d of 47 districts, CV %.3f\n",
            100 * sum(sa_onp$votes) / sum(sa$votes), nrow(sa_onp), sa_cv))
cat(sprintf("OC3  the model uses %.3f, taken from this election.\n", 0.327))

lo <- stats::quantile(out$cv, 0.10, na.rm = TRUE)
hi <- stats::quantile(out$cv, 0.90, na.rm = TRUE)
cat(sprintf("\nOC4  is SA 2026 an ordinary amount of concentration?\n"))
cat(sprintf("OC4  federal 10th-90th percentile: %.3f to %.3f; SA sits at %.3f -> %s\n",
            lo, hi, sa_cv,
            if (sa_cv >= lo && sa_cv <= hi) "INSIDE, ordinary" else "OUTSIDE, unusual"))

# Does concentration depend on the level? If it does, a reading at 6% cannot
# be carried to 22% and this whole comparison is weaker than it looks.
if (sum(!is.na(out$cv)) >= 5) {
  ct <- stats::cor.test(out$statewide, out$cv, method = "spearman", exact = FALSE)
  cat(sprintf("\nOC5  does concentration fall as the vote rises? Spearman %+.2f (p %.3f)\n",
              ct$estimate, ct$p.value))
  if (ct$p.value < 0.05 && ct$estimate < 0) {
    cat("OC5  YES -- so a CV measured at 5-10% OVERSTATES what to expect at 20%+,\n")
    cat("OC5  and the federal readings are an upper bound rather than a like-for-like.\n")
  } else {
    cat("OC5  no clear relationship at this sample, so the federal readings are\n")
    cat("OC5  usable as a rough comparator rather than a corrected one.\n")
  }
}
fwrite(out, file.path("output", "onp-concentration.csv"))
