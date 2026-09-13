# How do statewide party votes move TOGETHER between elections?
#
# Against docs/plans/prereg-statewide-covariance.md. Arm B needs the covariance
# of statewide first-preference CHANGES; this estimates it from the ten election
# pairs the corpus holds -- six federal, two Victorian, one NSW, one South
# Australian.
#
# WHY IT IS NEEDED. simulate_seat_contests() draws each party's statewide
# deviation independently, so a simulation where One Nation runs hot is equally
# likely to pair with a strong Coalition as a weak one. Votes come from
# somewhere, and this measures where.
#
# THE HONEST LIMIT, recorded as refusal V3 before any of this ran: One Nation is
# near zero and unmoving in nine of the ten pairs. Its column of this matrix is
# informed by South Australia 2026 and essentially nothing else, however many
# elections the other columns rest on.
#
# Emits CV* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
PARTIES <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH", "OTH_RIGHT")

share_of <- function(dt) {
  # ASSERT COVERAGE, NOT JUST PRESENCE. A MISSING file already throws (caught
  # by the per-pair tryCatch below and reported as "CV0! <pair>: <message>").
  # A file that reads successfully but is CORRUPT -- truncated to a header
  # row, or filtered to zero rows by an upstream election-label mismatch --
  # does not: `s` comes back with 0 rows, `m <- intersect(..., PARTIES)` is
  # character(0), `out[m] <- ...` on an empty index is a silent no-op, and this
  # function returns all-zero shares with no error at all. That bypasses the
  # tryCatch entirely, so the pair is never skipped -- it enters PAIRS with a
  # bogus zero row, and the ONLY thing that eventually catches it is CV2's row-
  # sum check, dozens of lines later, reporting "first preferences do not sum
  # to the same total" rather than naming the actual corrupt file. Found by the
  # review gate on 2026-09-13, same class CLAUDE.md already records: "a
  # truncated download... parsed to zero rows and dropped a seat... silently."
  if (!nrow(dt)) stop("no rows -- the source file may be corrupt, truncated, ",
                      "or filtered by an election label that does not exist")
  s <- dt[, .(v = sum(votes)), by = party]
  out <- setNames(rep(0, length(PARTIES)), PARTIES)
  m <- intersect(s$party, PARTIES)
  out[m] <- 100 * s$v[match(m, s$party)] / sum(s$v)
  out
}

# C2 of docs/plans/prereg-statewide-cov-loo-2026-09-07.md: EVERY pair the corpus
# holds, not the ten this list used to name. The first-preference files for all
# of them were already on disk; the list simply had not been revisited as the
# harnesses grew from ten scored pairs to twenty-two.
#
# A file-driven table rather than four hand-written blocks, so adding an
# election is one row and cannot be half-done.
# LAZY AND PROTECTED, matching how state_share() already behaves -- and this
# is the actual bug behind the scheduled "Forecast refresh" workflow failing
# every night since 2026-09-03. Every state file below is read INSIDE
# state_share(), called per-pair from within the tryCatch loop further down,
# so a missing NSW/VIC/QLD/SA file already degrades to "CV0! <pair>: skipped"
# for that one pair. `fed` used to be read EAGERLY here, unconditionally,
# before that loop starts -- so a missing federal file threw an UNCAUGHT
# top-level error and crashed the whole script, halting run_all.R (this stage
# has no target = FALSE) before fit_seats_full.R, fit_scorecard.R or
# build_page.R ever ran.
#
# .github/workflows/forecast.yaml deliberately does not fetch
# aec-fed-firstprefs.csv in CI (fetch_preferences_fed.R is one of the four
# fetchers excluded there, because fetch_preferences_nsw.R cannot run from a
# GitHub runner's IP and "it has to be all four or none" per that file's own
# comment) -- so this file has been absent on every scheduled run since that
# decision, and nothing ever told this script to tolerate it the way
# fit_seats_full.R already tolerates its own missing external data.
#
# Read once, lazily, on first use, and let a read failure surface as a normal
# per-pair error the existing loop already catches -- same shape as
# state_share(), just memoised so six federal pairs don't each reopen the file.
.fed <- NULL
fed_share <- function(y) {
  if (is.null(.fed)) {
    .fed <<- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)
  }
  share_of(.fed[election == sprintf("fed%d", y)])
}
state_share <- function(f) share_of(fread(file.path(P, f), showProgress = FALSE))

# C2 WAS REFUSED BY ITS OWN REFUSAL CLAUSE, 2026-09-07. The widened set -- all
# 21 pairs the corpus holds -- was built and measured, and refusal 1 of
# docs/plans/prereg-statewide-cov-loo-2026-09-07.md fired: cor(ALP, IND) is
# -0.16 with Western Australia in the fit and +0.43 without it. A correlation
# that CHANGES SIGN on one jurisdiction is describing that jurisdiction, and
# independents are the class this model cares most about. Seven of the twelve
# pairs C2 would have added are WA, whose Assembly has almost no independents
# and whose statewide Labor swings are enormous (+12 in 2017, +18 in 2021, -18
# in 2025), so a near-zero unmoving IND column paired with huge ALP moves
# manufactures a negative correlation.
#
# The refusal was written before the run and it is honoured here rather than
# rewritten, which is the whole point of writing it first.
#
# WHAT IS NOT SETTLED. Widening to the non-WA pairs alone -- fed2007, nsw2019,
# vic2014 and the two Queensland pairs -- is a DIFFERENT change that refusal 1
# does not implicate, and it needs its own pre-registration rather than being
# smuggled in on the back of this one. It is the obvious next experiment.
#
# The file-driven table below is kept because it is a better shape than four
# hand-written blocks, and it reproduces exactly the ten pairs this file has
# always used.
# FIFTEEN PAIRS, and Western Australia's six are absent ON PURPOSE.
# docs/plans/prereg-statewide-cov-widen-nonwa-2026-09-07.md. The previous
# widening tried all 21 and its refusal clause fired: cor(ALP, IND) is -0.16
# with WA in the fit and +0.43 without. WA's Assembly has almost no independents
# and its statewide Labor swings are enormous (+12 in 2017, +18 in 2021, -18 in
# 2025), so a flat IND column against very large ALP moves manufactures a
# correlation about nothing. WA seats are still SCORED; only its pairs are kept
# out of this one estimate.
SPEC <- list(
  list(region = "fed", years = c(2004, 2007, 2010, 2013, 2016, 2019, 2022, 2025),
       get = fed_share),
  list(region = "vic", years = c(2010, 2014, 2018, 2022),
       get = function(y) state_share(sprintf("vec-%d-vic-firstprefs.csv", y))),
  list(region = "nsw", years = c(2015, 2019, 2023),
       get = function(y) state_share(sprintf("nswec-%d-nsw-firstprefs.csv", y))),
  list(region = "sa", years = c(2022, 2026),
       get = function(y) state_share(sprintf("ecsa-%d-sa-firstprefs.csv", y))),
  # The valuable addition: Queensland carries real One Nation votes (13.73% in
  # 2017, 7.12% in 2020) where that column has rested on South Australia alone.
  list(region = "qld", years = c(2017, 2020, 2024),
       get = function(y) state_share(sprintf("ecq-%d-qld-firstprefs.csv", y))))

PAIRS <- list()
for (S in SPEC) {
  ys <- S$years
  for (n in seq_along(ys)[-1]) {
    # NAMES THE ACTUAL ERROR, not just "missing" -- a bare tryCatch(error =
    # function(e) NULL) here used to catch EVERY error class (a corrupt or
    # truncated file, a schema change inside share_of(), an fread parse
    # failure) and report all of them as the same "file is missing" line,
    # discarding conditionMessage(e) entirely. A malformed file and an
    # absent one are different problems and this pipeline feeds a
    # pre-registered refusal check (R1/CVR1) -- a pair silently dropped for
    # the wrong reason should not read the same as one genuinely unavailable.
    a <- tryCatch(S$get(ys[n - 1]), error = function(e) {
      cat(sprintf("CV0! %s%d: %s\n", S$region, ys[n - 1], conditionMessage(e))); NULL
    })
    b <- tryCatch(S$get(ys[n]), error = function(e) {
      cat(sprintf("CV0! %s%d: %s\n", S$region, ys[n], conditionMessage(e))); NULL
    })
    if (is.null(a) || is.null(b)) {
      cat(sprintf("CV0! %s%d -> %s%d: pair skipped\n",
                  S$region, ys[n - 1], S$region, ys[n]))
      next
    }
    PAIRS[[length(PAIRS) + 1L]] <- list(name = sprintf("%s%d", S$region, ys[n]),
                                        region = S$region, a = a, b = b)
  }
}
cat(sprintf("CV0  %d election pairs across %d jurisdictions
",
            length(PAIRS), length(unique(vapply(PAIRS, function(p) p$region, character(1))))))
REGION <- vapply(PAIRS, function(p) p$region, character(1))

D <- t(vapply(PAIRS, function(p) p$b - p$a, numeric(length(PARTIES))))
rownames(D) <- vapply(PAIRS, function(p) p$name, character(1))
colnames(D) <- PARTIES
cat(sprintf("\nCV1  statewide first-preference CHANGE, %d election pairs\n", nrow(D)))
print(round(D, 2))

# TOO FEW PAIRS TO FIT ANYTHING -- write the safe fallback and stop here,
# rather than let cor()/the leave-one-out loop below reach a degenerate input.
#
# Found 2026-09-13, review-gating the fix that made a MISSING federal file
# degrade gracefully instead of crashing (see the fed_share() comment above).
# That fix was verified against a LOCAL reproduction that removed only the
# federal file -- but this machine also holds a full historical cache
# (vic2010/2014/2018, sa2022, qld2017) from earlier development work that CI
# has never fetched, so the "8 clean pairs" that test produced was not the
# real CI condition. .github/workflows/forecast.yaml's fetch step actually
# gets fed(0), nsw(0), vic2022-only(0 pairs, every SPEC pair needs a second
# endpoint), sa2026-only(0 pairs, same reason), qld2020+qld2024(1 pair) -- ONE
# total pair, not eight. The leave-one-out loop below removes each pair's own
# row for that pair's own target, so with one pair it removes the only row,
# `nrow(Dm) < 3L` fires, and stop() runs UNCAUGHT at the top level -- the
# exact failure class the fed_share() fix exists to close, just moved a few
# lines down. Caught by the review gate before this was trusted on inspection.
#
# fit_seats_full.R's OWN prerequisite data (vic2022/sa2026 transfers) IS
# fetched in CI, so it reaches statewide_cor(), which hard-stop()s if
# output/statewide-cov.rds does not exist at all (R/statewide_cor.R:43-46) --
# so simply skipping without writing the file only moves the crash there
# instead. The file must always be written, even in the degenerate case.
#
# THE SAFE FALLBACK IS INDEPENDENCE: the identity matrix, cor = 0 off the
# diagonal. That is precisely what this file's own opening comment names as
# the behaviour BEFORE this feature existed -- "simulate_seat_contests() draws
# each party's statewide deviation independently" -- so falling back to it
# when there is not enough data to estimate anything is not a guess, it is
# reverting to the documented prior state.
#
# statewide_cor(target = NULL) -- what fit_seats_full.R's LIVE forecast call
# actually uses (scripts/fit_seats_full.R:920) -- never reads `by_target` at
# all (R/statewide_cor.R:65-70), so an empty list is safe there. A BACKTEST
# call with a real target falls through to the "target is not in the fit"
# branch (R/statewide_cor.R:86-89) and gets the same identity matrix, correctly
# labelled -- also safe, just uninformative, which is the honest state of
# affairs when there is nothing to inform it.
#
# Threshold matches the leave-one-out loop's own requirement below (each
# target needs >= 3 pairs remaining after removing its own row, so >= 4 total
# to run that loop at all) rather than inventing a separate number.
#
# LAMBDA moved up from beside SH below -- it is a fixed constant, not
# data-dependent, and this fallback branch needs it before that point.
LAMBDA <- 0.5
MIN_PAIRS <- 4L
if (nrow(D) < MIN_PAIRS) {
  cat(sprintf("\nCV1! only %d election pair(s), below the %d needed for a leave-one-out fit\n",
              nrow(D), MIN_PAIRS))
  cat("CV1! writing the INDEPENDENCE fallback (identity matrix, no correlation\n")
  cat("CV1! assumed) rather than fitting a correlation degenerate input cannot\n")
  cat("CV1! support -- this is the documented pre-feature behaviour, not a guess.\n")
  ID <- diag(length(PARTIES)); dimnames(ID) <- list(PARTIES, PARTIES)
  saveRDS(list(change = D, cor = ID, cor_shrunk = ID, by_target = list(),
               lambda = LAMBDA, parties = PARTIES, degraded = TRUE,
               degraded_reason = sprintf("only %d pair(s) available", nrow(D))),
          file.path("output", "statewide-cov.rds"))
  cat("\nCV7  wrote output/statewide-cov.rds (DEGRADED: independence assumed)\n")
  quit(save = "no", status = 0)
}

# Each row should sum to about zero: shares that rise must come from shares that
# fall. A row that does not is a party class missing from one side of the pair.
rs <- rowSums(D)
cat(sprintf("\nCV2  row sums (should be ~0): %s\n",
            paste(sprintf("%+.2f", rs), collapse = ", ")))
if (max(abs(rs)) > 0.5) {
  stop("Election pair(s) ", paste(rownames(D)[abs(rs) > 0.5], collapse = ", "),
       " have first preferences that do not sum to the same total on both ",
       "sides, so a party class is missing from one of them and the change is ",
       "not a change.")
}

CO <- stats::cor(D)
cat("\nCV3  correlation of statewide changes\n")
print(round(CO, 2))
cat(sprintf("\nCV3  the pair that matters for One Nation: cor(ONP, LNP) = %+.2f\n",
            CO["ONP", "LNP"]))
cat(sprintf("CV3  and cor(ONP, ALP) = %+.2f\n", CO["ONP", "ALP"]))
cat("CV3  V3 applies: nine of ten pairs have One Nation near zero, so its\n")
cat("CV3  column is South Australia 2026 and little else.\n")

# How much of One Nation's column is one election? Refuse to let that be
# invisible: recompute without South Australia and print both.
noSA <- stats::cor(D[rownames(D) != "sa2026", ])
cat(sprintf("\nCV4  without SA 2026: cor(ONP, LNP) = %+.2f (from %+.2f)\n",
            noSA["ONP", "LNP"], CO["ONP", "LNP"]))
cat(sprintf("CV4  One Nation's change without SA: %s\n",
            paste(sprintf("%+.2f", D[rownames(D) != "sa2026", "ONP"]), collapse = ", ")))

# Shrunk toward the diagonal at a weight FIXED IN ADVANCE by the plan, not tuned.
SH <- LAMBDA * CO + (1 - LAMBDA) * diag(nrow(CO))
dimnames(SH) <- dimnames(CO)
cat(sprintf("\nCV5  shrunk toward independence at lambda = %.2f (pre-registered)\n", LAMBDA))
print(round(SH, 2))

# ---- REFUSAL CHECKS FOR C2, run rather than remembered ----------------------
# docs/plans/prereg-statewide-cov-loo-2026-09-07.md names two things that would
# disqualify the widening however the pooled metric moves. They are computed
# here so the answer is in the log rather than in someone's head.
#
# R1: is the matrix describing Western Australia rather than Australia? Seven of
# the twelve pairs added by C2 are WA, so a correlation that CHANGES SIGN when
# WA is removed is a correlation about one jurisdiction.
# Refusal 1 of the current plan tests QUEENSLAND, which is what this widening
# leans on, by the same rule that refused the Western Australian one.
.excl <- if (any(REGION == "wa")) "wa" else "qld"
if (any(REGION == .excl) && sum(REGION != .excl) >= 3L) {
  noWA <- stats::cor(D[REGION != .excl, , drop = FALSE])
  flip <- which(sign(noWA) != sign(CO) & abs(CO) > 0.15 & abs(noWA) > 0.15,
                arr.ind = TRUE)
  flip <- flip[flip[, 1] < flip[, 2], , drop = FALSE]
  if (nrow(flip)) {
    cat(sprintf("
CVR1! %d correlation(s) change sign when %s is excluded:
", nrow(flip), toupper(.excl)))
    for (r in seq_len(nrow(flip))) {
      i1 <- flip[r, 1]; i2 <- flip[r, 2]
      cat(sprintf("      %s/%s: %+.2f with %s, %+.2f without
",
                  PARTIES[i1], PARTIES[i2], CO[i1, i2], toupper(.excl), noWA[i1, i2]))
    }
    cat("CVR1! Refusal 1 of the pre-registration applies: investigate before shipping.
")
  } else {
    cat(sprintf("
CVR1  no correlation above 0.15 changes sign when %s is excluded.
", toupper(.excl)))
  }
}

# ---- LEAVE ONE ELECTION OUT ------------------------------------------------
# C1 of docs/plans/prereg-statewide-cov-loo-2026-09-07.md. Until 2026-09-07 this
# file wrote ONE matrix and every harness scored against it, including the pairs
# that were in the fit -- so scoring nsw2023 used a correlation that had seen
# nsw2023's own statewide swing. fit_mp_slope.R already solves this shape by
# writing one row per target; this is the same idea.
#
# THE LIVE FORECAST IS DIFFERENT AND KEEPS THE FULL MATRIX. fit_seats_full.R
# predicts an election that has not happened, so no pair in this fit is the one
# being predicted and there is nothing to leave out. Withholding data from it
# would be superstition rather than hygiene. `cor_shrunk` stays the all-pairs
# matrix for that reason, and `by_target` is what a BACKTEST reads.
shrink_to_diag <- function(m) {
  out <- LAMBDA * m + (1 - LAMBDA) * diag(nrow(m))
  dimnames(out) <- dimnames(m)
  out
}
by_target <- lapply(stats::setNames(nm = rownames(D)), function(t) {
  Dm <- D[rownames(D) != t, , drop = FALSE]
  if (nrow(Dm) < 3L)
    stop("Leaving out ", t, " leaves only ", nrow(Dm), " pairs, too few for a ",
         "correlation over ", length(PARTIES), " parties.")
  cm <- stats::cor(Dm)
  list(cor = cm, cor_shrunk = shrink_to_diag(cm), n_pairs = nrow(Dm))
})
cat(sprintf("
CV6  leave-one-election-out: %d matrices, each on %d pairs
",
            length(by_target), nrow(D) - 1L))
mv <- vapply(names(by_target), function(t)
  max(abs(by_target[[t]]$cor_shrunk - SH)), numeric(1))
cat(sprintf("CV6  max |move| in a target's own shrunk matrix: %.3f (%s); median %.3f
",
            max(mv), names(which.max(mv)), stats::median(mv)))

saveRDS(list(change = D, cor = CO, cor_shrunk = SH, by_target = by_target,
             lambda = LAMBDA, parties = PARTIES),
        file.path("output", "statewide-cov.rds"))
cat("
CV7  wrote output/statewide-cov.rds
")
