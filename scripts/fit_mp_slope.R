# Fit the sitting-member slope tier, LEAVE-ONE-ELECTION-OUT.
#
# WHY THIS EXISTS. The tier's values (0.954 for a returning MEMBER, 0.800 for a
# returning also-ran) were hard-coded into R/dev_slope.R on 2026-09-04 from an
# ad-hoc fit that was never committed. Two things follow from that, both bad:
#
#   1. The fit pooled 531 returning non-major candidacies "across 10 election
#      pairs" and the tier was then SCORED on fed2025 -- one of those pairs. A
#      hyperparameter fitted on the election it is measured on is leakage, which
#      CLAUDE.md lists as a recurring hazard here (three instances, one
#      introduced while fixing another). The reported fed2025 gain
#      0.3663 -> 0.3597 is therefore partly in-sample and cannot be read as an
#      out-of-sample result.
#   2. With no script, the number could not be re-derived, re-checked, or
#      excluded-and-refitted. docs/CONSTANTS.md asks whether each constant can
#      come from data; this one can, and now does.
#
# What this prints, in order:
#   MP1  the pooled fit (what was published), for comparison only
#   MP2  the leave-one-election-out fit: for every target election, the slopes
#        refitted with that election's own pair REMOVED
#   MP3  the spread of the LOO slopes, which is the honest uncertainty
#
# The LOO slopes are what a harness should use. A single pooled pair of numbers
# applied to every election cannot be out-of-sample for any of them.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

MAJ  <- c("ALP", "LNP")
CAND <- fread("output/candidacies.csv", showProgress = FALSE)

# Every consecutive pair within a jurisdiction. Built from what is on disk
# rather than a hand-kept list, so a newly fetched election joins the fit
# without anyone remembering to add it.
CAND[, juris := sub("[0-9]+$", "", election)]
CAND[, yr := as.integer(sub("^[a-z]+", "", election))]
pairs <- rbindlist(lapply(split(unique(CAND[, .(juris, yr, election)]), by = "juris"), function(d) {
  d <- d[order(yr)]
  if (nrow(d) < 2L) return(NULL)
  data.table(from = d$election[-nrow(d)], to = d$election[-1])
}))
cat(sprintf("MP0  %d election pairs across %d jurisdictions\n",
            nrow(pairs), uniqueN(CAND$juris)))

# ---- build the panel -------------------------------------------------------
# One row per (pair, seat, class) where the class returns. dev is the seat's
# share MINUS that election's own statewide level for the class, which is the
# quantity dev_slope() actually multiplies -- fitting on raw shares would fit a
# different model from the one that ships.
cls_share <- CAND[, .(votes = sum(votes, na.rm = TRUE)), by = .(election, seat, party)]
cls_share[, share := 100 * votes / sum(votes), by = .(election, seat)]
statewide <- CAND[, .(votes = sum(votes, na.rm = TRUE)), by = .(election, party)]
statewide[, level := 100 * votes / sum(votes), by = election]

# COVERAGE, not presence: a pair whose candidate_returns() throws is NAMED and
# the run stops, so a jurisdiction-specific matching bug cannot quietly shrink
# the panel behind a plausible MP0/MP1 line.
.pair_fail <- character(0)
panel <- rbindlist(lapply(seq_len(nrow(pairs)), function(i) {
  a <- pairs$from[i]; b <- pairs$to[i]
  r <- tryCatch(candidate_returns(a, b), error = function(e) {
    .pair_fail <<- c(.pair_fail, sprintf("%s->%s (%s)", a, b, conditionMessage(e))); NULL })
  if (is.null(r)) return(NULL)
  setDT(r)
  # Non-majors only: the tier exists to stop an entrenched independent being
  # shrunk toward a ~5% statewide average, and majors never take this path.
  r <- r[!party %in% MAJ & same %in% TRUE]
  if (!nrow(r)) return(NULL)
  now <- cls_share[election == b, .(seat, party, share_now = share)]
  # normalise_seat() on BOTH sides: vic2018 stores seats lower-case and vic2022
  # titlecase, the exact mismatch candidate_returns() was built to absorb and
  # that a verification script reintroduced once by not reusing it.
  prv <- cls_share[election == a, .(seat, party, share_prev = share)]
  now[, .s := normalise_seat(seat)]; prv[, .s := normalise_seat(seat)]
  r[, .s := normalise_seat(seat)]
  x <- merge(r[, .(.s, party, same_mp)], now[, .(.s, party, share_now)],
             by = c(".s", "party"))
  x <- merge(x, prv[, .(.s, party, share_prev)], by = c(".s", "party"))
  if (!nrow(x)) return(NULL)
  la <- statewide[election == a, .(party, lvl_prev = level)]
  lb <- statewide[election == b, .(party, lvl_now  = level)]
  x <- merge(merge(x, la, by = "party"), lb, by = "party")
  x[, `:=`(pair = paste0(a, "->", b), target = b,
           dev_prev = share_prev - lvl_prev, dev_now = share_now - lvl_now)]
  x[]
}), fill = TRUE)

cat(sprintf("MP0p %d of %d pairs contributed rows%s\n",
            length(unique(panel$target)), nrow(pairs),
            if (length(.pair_fail)) paste0("; FAILED: ", paste(.pair_fail, collapse = "; ")) else ""))
if (length(.pair_fail)) stop("candidate_returns() failed for ", length(.pair_fail), " pair(s); see MP0p")
# NAME THE MISSING PAIRS, do not just count them.
#
# This line printed "22 of 23 pairs contributed rows" for an unknown length of
# time and carried on. The missing one was sa2018->sa2022, and because that pair
# silently produced no MP slopes, sa2022 could not be scored by its harness at
# all -- while its fallback-path log loss (0.9409, the worst in the corpus) went
# on being pooled into the headline figure as though it measured the model.
#
# `.pair_fail` above only catches a pair whose candidate_returns() THROWS. This
# pair did not throw: it returned 219 rows that all failed the downstream
# "non-major AND returning" filter, because every sa2018 surname was being
# parsed as a first name. The guard was built for the failure someone imagined
# and the real one walked straight past it.
#
# A count is not an identity. Two lines, and the next instance announces itself.
.missing <- setdiff(pairs$to, unique(panel$target))
if (length(.missing)) {
  cat(sprintf("MP0p! NO ROWS for %d target(s): %s\n",
              length(.missing), paste(.missing, collapse = ", ")))
  # STOP, do not warn. The first version of this check only printed, and the
  # review gate was right that this reproduces the very failure it patches: the
  # OLD line printed "22 of 23 pairs contributed rows" and was ignored for an
  # unknown length of time, because a diagnostic buried in a wall of Rscript
  # output does not force anyone to look. Making the replacement another print
  # protects only the person who immediately reruns the affected harness, and
  # nobody did that last time -- the gap was found by a coincidental audit
  # months later, after its fallback-path log loss had been pooled into the
  # headline figure all along.
  #
  # The six harnesses DO each stop() when their own target is missing, so the
  # gap is eventually loud. But "eventually, if someone runs that exact pair" is
  # what let sa2022 sit outside the model. This script already hard-fails on a
  # coverage gap two lines above (stopifnot on dev_prev/dev_now); this is the
  # same class of guarantee.
  #
  # If a target legitimately has no returning non-majors, that is a real finding
  # about the data and should be handled deliberately -- by fixing the upstream
  # parse, or by removing the pair -- not by shipping a table with a hole in it.
  stop("fit_mp_slope: ", length(.missing), " target(s) produced no slopes (",
       paste(.missing, collapse = ", "),
       "). A harness run against them will refuse to start. Fix the upstream ",
       "candidate matching rather than writing an incomplete table.")
}
stopifnot(nrow(panel) > 0)
# COVERAGE, not presence: a column can be there, typed and empty. CLAUDE.md
# records 4.98M silently-discarded values from exactly that.
stopifnot(all(is.finite(panel$dev_prev)), all(is.finite(panel$dev_now)))
cat(sprintf("MP0  panel: %d returning non-major seat-classes, %d pairs\n",
            nrow(panel), uniqueN(panel$pair)))

# Slope through the origin on deviations, matching dev_slope()'s own form:
#   projected = level_now + slope * (x - level_prev)
fit <- function(d) if (nrow(d) < 3L) NA_real_ else
  unname(coef(lm(dev_now ~ 0 + dev_prev, data = d))[1])

pooled_mp  <- fit(panel[same_mp %in% TRUE])
pooled_not <- fit(panel[!(same_mp %in% TRUE)])
cat(sprintf("\nMP1  pooled (IN-SAMPLE, what shipped): member %.3f (n=%d) | also-ran %.3f (n=%d)\n",
            pooled_mp, sum(panel$same_mp %in% TRUE),
            pooled_not, sum(!(panel$same_mp %in% TRUE))))

cat("\nMP2  leave-one-election-out\n")
loo <- rbindlist(lapply(sort(unique(panel$target)), function(t) {
  d <- panel[target != t]
  data.table(target = t, n_held_out = panel[target == t, .N],
             n_mp_held_out = panel[target == t & same_mp %in% TRUE, .N],
             member = fit(d[same_mp %in% TRUE]), also_ran = fit(d[!(same_mp %in% TRUE)]))
}))
loo[, gap := member - also_ran]
print(loo)

cat(sprintf("\nMP3  LOO member slope: mean %.3f, sd %.3f, range %.3f-%.3f\n",
            mean(loo$member, na.rm = TRUE), sd(loo$member, na.rm = TRUE),
            min(loo$member, na.rm = TRUE), max(loo$member, na.rm = TRUE)))
cat(sprintf("MP3  LOO also-ran slope: mean %.3f, sd %.3f, range %.3f-%.3f\n",
            mean(loo$also_ran, na.rm = TRUE), sd(loo$also_ran, na.rm = TRUE),
            min(loo$also_ran, na.rm = TRUE), max(loo$also_ran, na.rm = TRUE)))
cat(sprintf("MP3  gap (member - also-ran): mean %.3f, sd %.3f, negative in %d of %d\n",
            mean(loo$gap, na.rm = TRUE), sd(loo$gap, na.rm = TRUE),
            sum(loo$gap < 0, na.rm = TRUE), sum(is.finite(loo$gap))))

# ---- per class ------------------------------------------------------------
# The shipped tier is per class -- IND 0.954, OTH_RIGHT 0.954, GRN 0.994,
# ONP 0.610 -- so the pooled numbers above cannot validate it. GRN at 0.994 and
# ONP at 0.610 are 0.38 apart and neither was ever printed with its n; a slope
# fitted on a handful of seat-classes is noise wearing three decimal places.
cat("
MP5  per class (pooled, with n -- read the n before the slope)
")
byc <- panel[, .(n_member = sum(same_mp %in% TRUE), n_also = sum(!(same_mp %in% TRUE)),
                 member = fit(.SD[same_mp %in% TRUE]),
                 also_ran = fit(.SD[!(same_mp %in% TRUE)])), by = party]
byc <- byc[order(-n_member)]
byc[, shipped := c(IND = 0.954, OTH_RIGHT = 0.954, GRN = 0.994, ONP = 0.610)[party]]
print(byc)

# The same, held out: does each class's member slope survive dropping any one
# election? A class whose slope swings wildly across folds has no business
# carrying three decimal places into the forecast.
cat("
MP6  per-class member slope, leave-one-election-out spread
")
loc <- rbindlist(lapply(unique(panel[same_mp %in% TRUE]$party), function(cl) {
  v <- vapply(sort(unique(panel$target)), function(t)
    fit(panel[target != t & party == cl & same_mp %in% TRUE]), numeric(1))
  data.table(party = cl, n = panel[party == cl & same_mp %in% TRUE, .N],
             loo_mean = mean(v, na.rm = TRUE), loo_sd = sd(v, na.rm = TRUE),
             loo_min = suppressWarnings(min(v, na.rm = TRUE)),
             loo_max = suppressWarnings(max(v, na.rm = TRUE)))
}))
print(loc[order(-n)])

# ---- the table a harness should actually read ------------------------------
# One row per (target election, class): the slopes fitted with that target's own
# pair REMOVED. A harness predicting fed2025 looks up target == "fed2025" and
# gets values that never saw fed2025, which is the only way this constant can be
# used in a backtest without leaking. A single pooled number cannot do that, and
# the pooled number is how the leak got in.
#
# Classes with too few members to fit are written as NA rather than filled from
# the also-ran pool: ONP's shipped 0.610 was exactly that fill, presented as a
# measurement of zero observations. NA makes the caller fall back explicitly.
MIN_N <- 8L
# NEVER a bare column-name symbol inside `[`. The first version of this block
# wrote panel[target != target[i] & party == party[i]] and both symbols on BOTH
# sides resolved to PANEL's columns, not the grid's -- data.table scopes the
# subsetted table's columns into the whole `i` expression. It returned the same
# slope for every class, which is what made it visible; the same shape has
# silently returned wrong-but-plausible subsets six times in this repo. The
# loop variables are copied into differently-named plain vectors first.
g_targets <- sort(unique(panel$target))
g_classes <- sort(unique(panel[same_mp %in% TRUE]$party))
grid <- rbindlist(lapply(g_targets, function(tg) rbindlist(lapply(g_classes, function(cl) {
  d  <- panel[panel$target != tg & panel$party == cl, ]
  dm <- d[d$same_mp %in% TRUE, ]
  data.table(target = tg, party = cl, n_member = nrow(dm),
             member   = if (nrow(dm) >= MIN_N) fit(dm) else NA_real_,
             also_ran = fit(d[!(d$same_mp %in% TRUE), ]))
}))))
# Prove the held-out election really left: if any fold used every row, the
# subset did not filter and the whole table is in-sample.
stopifnot(all(vapply(g_targets, function(tg) sum(panel$target != tg) < nrow(panel), logical(1))))
cat(sprintf("
MP7  leak-free lookup table (min n=%d for a member slope)
", MIN_N))
print(dcast(grid, target ~ party, value.var = "member"))

fwrite(loo, "output/mp-slope-loo.csv")
fwrite(byc, "output/mp-slope-by-class.csv")
fwrite(grid, "output/mp-slope-by-target.csv")
cat("\nMP4  wrote output/mp-slope-loo.csv\n")
