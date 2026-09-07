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
fed <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)
fed_share <- function(y) share_of(fed[election == sprintf("fed%d", y)])
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
SPEC <- list(
  list(region = "fed", years = c(2007, 2010, 2013, 2016, 2019, 2022, 2025),
       get = fed_share),
  list(region = "vic", years = c(2014, 2018, 2022),
       get = function(y) state_share(sprintf("vec-%d-vic-firstprefs.csv", y))),
  list(region = "nsw", years = c(2019, 2023),
       get = function(y) state_share(sprintf("nswec-%d-nsw-firstprefs.csv", y))),
  list(region = "sa", years = c(2022, 2026),
       get = function(y) state_share(sprintf("ecsa-%d-sa-firstprefs.csv", y))))

PAIRS <- list()
for (S in SPEC) {
  ys <- S$years
  for (n in seq_along(ys)[-1]) {
    a <- tryCatch(S$get(ys[n - 1]), error = function(e) NULL)
    b <- tryCatch(S$get(ys[n]), error = function(e) NULL)
    if (is.null(a) || is.null(b)) {
      cat(sprintf("CV0! %s%d -> %s%d: a first-preference file is missing; pair skipped
",
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
LAMBDA <- 0.5
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
if (any(REGION == "wa") && sum(REGION != "wa") >= 3L) {
  noWA <- stats::cor(D[REGION != "wa", , drop = FALSE])
  flip <- which(sign(noWA) != sign(CO) & abs(CO) > 0.15 & abs(noWA) > 0.15,
                arr.ind = TRUE)
  flip <- flip[flip[, 1] < flip[, 2], , drop = FALSE]
  if (nrow(flip)) {
    cat(sprintf("
CVR1! %d correlation(s) change sign when WA is excluded:
", nrow(flip)))
    for (r in seq_len(nrow(flip))) {
      i1 <- flip[r, 1]; i2 <- flip[r, 2]
      cat(sprintf("      %s/%s: %+.2f with WA, %+.2f without
",
                  PARTIES[i1], PARTIES[i2], CO[i1, i2], noWA[i1, i2]))
    }
    cat("CVR1! Refusal 1 of the pre-registration applies: investigate before shipping.
")
  } else {
    cat("
CVR1  no correlation above 0.15 changes sign when WA is excluded.
")
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
