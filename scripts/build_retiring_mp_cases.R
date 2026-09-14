# Retiring-major-party-winner cases, across the whole 23-pair corpus: how
# much of the departing MP's personal vote survives to their successor, and
# whether TENURE (consecutive terms served) predicts it.
#
# WHY. Working the AEF worst-seats table (Parramatta, Monaro, Heathcote,
# Riverstone, Braddon, Richmond, Morwell -- 2026-09-13), the common shape
# was a SENIOR retiring member (a Deputy Premier, a shadow minister, two
# ministers) whose successor's primary collapsed by far more than the flat
# retirement discount assumes. Ministerial/leadership status isn't in this
# corpus at all and would need real hand-curated research; TENURE is a
# purely data-derived proxy already available, and Pete's call was to let
# xgboost decide whether it helps rather than pre-filter it out by
# correlation alone.
#
# A REAL BUG, FOUND AND FIXED BUILDING THIS. The first version merged a
# retiring MP's seat against the target election's results by normalised
# seat NAME alone. Seats that don't survive a redistribution under the same
# name (WA and Victoria redistrict heavily) matched nothing, and the merge's
# `is.na() -> 0` fallback read "this seat doesn't exist any more" as "the
# party got zero votes here" -- an implausible outcome for a major party
# that genuinely never happens, and every one of the worst "retention"
# cases before the fix showed exactly this, an unmistakable tell. Fixed by
# requiring the seat to appear in the target election under the same
# normalised name before it counts as a genuine retention case; a vanished
# seat is a redistricting event, not a retirement one.
#
# THE FINDING, post-fix: 343 genuine cases across 22 pairs (up from a
# contaminated 419, which included the phantom-zero seats). Mean retention
# 0.918 (was 0.751, contaminated). Tenure DOES predict retention, modestly
# but significantly: r = -0.111, p = 0.039 -- 2-term retirees keep ~96.5% of
# their vote on average, 3+ term retirees keep only ~89-90%. The naive
# correlation on the CONTAMINATED corpus found nothing (r=0.068, p=0.16),
# which would have wrongly killed this feature before it was ever tried.
#
# Emits BM* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
pairs <- all_election_pairs()
MAJ <- c("ALP", "LNP", "NAT")
PAIR_CHAIN <- setNames(sapply(pairs, function(p) p$prev), sapply(pairs, function(p) p$election))

cases <- rbindlist(lapply(pairs, function(pr) {
  PT <- C[election == pr$prev]
  NT <- C[election == pr$election]
  if (!nrow(PT) || !nrow(NT)) return(NULL)
  PT[, k := match_key(surname_of(surname, name), given_of(given, name), "initial")]
  NT[, k := match_key(surname_of(surname, name), given_of(given, name), "initial")]
  PT[, sn := normalise_seat(seat)]
  NT[, sn := normalise_seat(seat)]
  winners <- PT[elected %in% TRUE & party %in% MAJ]
  if (!nrow(winners)) return(NULL)
  now_keys <- unique(NT[, .(sn, k)])
  winners[, retired := !paste(sn, k) %in% paste(now_keys$sn, now_keys$k)]
  ret <- winners[retired == TRUE]
  # THE FIX (see header): only seats confirmed to exist under the same
  # normalised name in the target election. A vanished seat is a
  # redistricting event (WA/VIC rename heavily), not a retirement one, and
  # merging past it silently read "seat gone" as "party got 0 votes".
  ret <- ret[sn %in% unique(NT$sn)]
  if (!nrow(ret)) return(NULL)
  newshare <- NT[, .(new_share = sum(pcv, na.rm = TRUE)), by = .(sn, party)]
  m <- merge(ret[, .(seat, sn, party, k, prior_pcv = pcv)], newshare,
             by = c("sn", "party"), all.x = TRUE)
  m[is.na(new_share), new_share := 0] # genuine: party fielded nobody here
  m[, pair := pr$election]
  m[]
}), fill = TRUE)

cat(sprintf("BM1  %d genuine retiring-major-winner cases (seat confirmed to still exist), %d pairs\n",
            nrow(cases), uniqueN(cases$pair)))

# TENURE: consecutive elections this exact person won this exact seat,
# walking backwards through the pair chain. Known before the target
# election (it is a fact about the past), so it is leakage-free.
tenure_of <- function(seat_norm, key, start_election) {
  n <- 1L; el <- start_election
  repeat {
    prev_el <- if (el %in% names(PAIR_CHAIN)) PAIR_CHAIN[[el]] else NA_character_
    if (is.na(prev_el)) break
    PT <- C[election == prev_el]
    if (!nrow(PT)) break
    PT2 <- copy(PT)
    PT2[, k2 := match_key(surname_of(surname, name), given_of(given, name), "initial")]
    PT2[, sn2 := normalise_seat(seat)]
    hit <- PT2[sn2 == seat_norm & k2 == key & elected %in% TRUE]
    if (!nrow(hit)) break
    n <- n + 1L; el <- prev_el
  }
  n
}
cases[, tenure := mapply(tenure_of, sn, k, pair)]
cases[, retention := pmin(3, new_share / prior_pcv)]

cat(sprintf("BM2  mean retention %.3f, median %.3f, n=%d\n",
            mean(cases$retention), median(cases$retention), nrow(cases)))
cat(sprintf("BM2  tenure distribution: %s\n",
            paste(names(table(cases$tenure)), table(cases$tenure), sep = "=", collapse = " ")))
cases[, tbucket := fifelse(tenure <= 2, "2 terms", fifelse(tenure <= 3, "3 terms", "4+ terms"))]
print(cases[, .(n = .N, mean_prior_pcv = round(mean(prior_pcv), 1),
               mean_retention = round(mean(retention), 3)), by = tbucket][order(tbucket)])
ct <- cor.test(cases$tenure, cases$retention)
cat(sprintf("BM3  correlation tenure vs retention: r=%.3f, p=%.4f, n=%d\n",
            unname(ct$estimate), ct$p.value, nrow(cases)))

fwrite(cases[, .(pair, seat, sn, party, k, prior_pcv, new_share, tenure, retention)],
       "output/retiring-mp-cases.csv")
cat("\nBM9  wrote output/retiring-mp-cases.csv\n")
