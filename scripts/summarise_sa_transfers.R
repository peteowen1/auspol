# Conditional preference transfer rates for SA 2026, on all 47 districts.
#
# THIS SCRIPT IS A CORRECTION, NOT AN ACQUISITION, and the distinction cost me
# an afternoon. docs/reviews/onp-allocation-sa-2026-08-17.md reports its
# transfer matrix from 16 districts and 97 exclusion events, and names getting
# more as "the real blocker on the rebuild". I went and got it -- and
# scripts/fetch_preferences_sa.R had already got it on 2026-08-19, from the
# same undocumented ECSA API, into external/elections/ecsa-2026-sa-transfers.csv
# with 47 districts, 294 events, and a FINER party taxonomy than mine (it keeps
# IND and OTH_RIGHT separate where I collapsed both into OTH).
#
# What survives is narrow: that review's matrix section is dated 2026-08-18 and
# the 47-district file landed 2026-08-19, so its published rates are computed
# from the smaller sample and were never recomputed. This recomputes them from
# the canonical file.
#
# Emits TR* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

f <- file.path(election_data_path(), "ecsa-2026-sa-transfers.csv")
if (!file.exists(f)) stop("Run scripts/fetch_preferences_sa.R first.")
tr <- fread(f, showProgress = FALSE)
# The canonical file is already in this repo's party classes and is long, one
# row per (seat, round, from, to). No id mapping and no collapse is needed --
# both of which I wrote before finding this file.
cat(sprintf("
TR0  %s: %d districts, %d exclusion events
", basename(f),
            uniqueN(tr$seat), uniqueN(tr[, paste(seat, round)])))

# Survivors: who was still standing for that transfer, which is the whole
# point -- the review's own numbers move by 30 points across configurations.
# Reconstructed from the file itself: a party still receiving votes in a later
# round of the same seat was still in the count.
tr[, from_class := from][, to_class := to]
still <- tr[, .(surv = paste(sort(unique(to)), collapse = "|")),
            by = .(seat, round)]
long <- merge(tr, still, by = c("seat", "round"))
long[, votes := as.numeric(votes)]

ev <- long[, .(votes = sum(votes)), by = .(seat, round, from_class, surv, to_class)]
cells <- ev[, .(events = uniqueN(paste(seat, round))), by = .(from_class, surv)]
cat(sprintf("\nTR2  after collapsing to model classes: %d cells from %d events\n",
            nrow(cells), uniqueN(ev[, paste(seat, round)])))
cat(sprintf("TR2  cells with 5+ events: %d | singletons: %d\n",
            sum(cells$events >= 5), sum(cells$events == 1)))

# ---- the anchor check ------------------------------------------------------
# Liberal exclusions, restricted to what went to Labor or One Nation.
lnp <- ev[from_class == "LNP" & to_class %in% c("ALP", "ONP"),
          .(votes = sum(votes)), by = to_class]
share_onp <- 100 * lnp[to_class == "ONP", votes] / sum(lnp$votes)
cat(sprintf("\nTR3  ANCHOR -- of LNP preferences reaching Labor or One Nation, %.1f%% went to ONP\n",
            share_onp))
cat("TR3  the review reports 62.7%% from its 16 districts.\n")
if (abs(share_onp - 62.7) > 8) {
  stop("This extraction gives ", round(share_onp, 1), "% against the review's ",
       "62.7%. The two disagree by more than sampling can explain; one of them ",
       "is wrong and neither should be used.")
}
cat("TR3  consistent.\n")

# ---- the rates worth having ------------------------------------------------
rate <- ev[, .(votes = sum(votes)), by = .(from_class, surv, to_class)]
rate[, pct := 100 * votes / sum(votes), by = .(from_class, surv)]
rate <- merge(rate, cells, by = c("from_class", "surv"))
cat("\nTR4  transfer rates, cells with 5 or more events, ordered by size\n")
big <- rate[events >= 5][order(-events, from_class, surv, -pct)]
print(big[, .(from = from_class, survivors = surv, events, to = to_class,
              pct = round(pct, 1))], nrows = 40)

cat("\nTR5  what the model assumes, against what these say\n")
cat("TR5  the model applies ONE flow-to-Labor per party regardless of who else\n")
cat("TR5  is standing. Below is that quantity per survivor set, so the spread\n")
cat("TR5  is visible rather than averaged away.\n")
alp <- rate[to_class == "ALP" & events >= 3][order(from_class, -events)]
print(alp[, .(from = from_class, survivors = surv, events,
              to_ALP_pct = round(pct, 1))], nrows = 40)
fwrite(rate, file.path("output", "sa2026-transfer-rates.csv"))
cat(sprintf("\nTR6  wrote output/sa2026-transfer-rates.csv (%d rows)\n", nrow(rate)))
