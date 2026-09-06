# Builds the widened C3 test population, per docs/plans/prereg-salience-c3-v3.md.
#
# Two changes from the amended (nsw2023/sa2026-only) design, both load-bearing
# and both proven safe/necessary before this script existed:
#
#   1. THE SALIENCE FEATURE IS A WITHIN-ELECTION PERCENTILE, not raw jump.
#      fetch_salience_v6.R's own header says the criterion "never needed
#      cross-election scale... a rank statistic is invariant to it" -- but the
#      emergence-gate model used raw log1p(jump), which is NOT invariant to
#      the different anchor (a different PM/Premier per era) each batch is
#      normalised against. A percentile is invariant by construction, which is
#      what makes testing across eras and regions honest rather than assumed.
#   2. THE EMERGENCE POPULATION IS RECOMPUTED BY PERSON, ACROSS EVERY ELECTION
#      WITH SALIENCE DATA, not just nsw2023/sa2026. Party-CLASS prior vote
#      (used by the amendment) silently counts a returning member who switched
#      label as a fresh emergence -- the exact trap this session already found
#      once (analyse_incumbent_transfer.R). Matched by NAME here instead.
#
# "Base" (uniform swing) is the SAME formula test_salience_gate.R already used
# for federal, generalised to REGION rather than reinvented: this candidate's
# own prior vote in this seat, plus that party class's statewide movement in
# that region between the two elections. Not the full dev_slope() machinery
# the published harnesses use -- this is deliberately the same simple baseline
# every criterion in this thread (C1 of the original document, C1 of the
# precision-v2 replacement) has already been scored against, so results stay
# comparable across the whole thread.
#
# Emits BW* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

MAJ  <- c("ALP", "LNP", "NAT")
GATE <- 15
ns   <- function(x) gsub("[^a-z0-9]", "", tolower(x))

C <- fread("output/candidacies.csv", showProgress = FALSE)
S <- fread("output/salience-v6.csv", showProgress = FALSE)

# Within-election percentile, computed once over the whole salience corpus so
# every election's ranking is independent of every other's -- the property
# that makes it comparable across eras and regions.
S[, xp := rank(jump, ties.method = "average") / .N, by = election]

PAIRS <- list(
  list(cur = "fed2010",  prev = "fed2007",  region = "fed"),
  list(cur = "fed2013",  prev = "fed2010",  region = "fed"),
  list(cur = "fed2016",  prev = "fed2013",  region = "fed"),
  list(cur = "fed2019",  prev = "fed2016",  region = "fed"),
  list(cur = "nsw2023",  prev = "nsw2019",  region = "nsw"),
  list(cur = "sa2026",   prev = "sa2022",   region = "sa"),
  list(cur = "vic2022",  prev = "vic2018",  region = "vic"),
  list(cur = "wa2008",   prev = "wa2005",   region = "wa")
)

statewide <- function(rg, yr) {
  d <- C[region == rg & year == yr, .(v = sum(votes)), by = party]
  setNames(100 * d$v / sum(d$v), d$party)
}

build_one <- function(p) {
  cur <- p$cur; prev <- p$prev; rg <- p$region
  D <- C[election == cur, .(seat, name, given, surname, party, pcv, elected)]
  D[, k := ns(seat)]; D[, nk := ns(name)]

  sa_ <- statewide(rg, C[election == prev, year[1]])
  sb_ <- statewide(rg, C[election == cur,  year[1]])
  mv <- vapply(D$party, function(pt)
    (if (pt %in% names(sb_)) sb_[[pt]] else 0) - (if (pt %in% names(sa_)) sa_[[pt]] else 0), 0)

  wprevwin <- C[election == prev & elected == TRUE, .(prev_seat = seat, prev_winner = name)]
  wprevwin[, k := ns(prev_seat)]

  ownprev <- unique(C[election == prev, .(prev_seat2 = seat, name, own_prev_pcv = pcv)],
                    by = c("prev_seat2", "name"))
  ownprev[, k := ns(prev_seat2)]; ownprev[, nk := ns(name)]

  D <- merge(D, wprevwin[, .(k, prev_winner)], by = "k", all.x = TRUE)
  D <- merge(D, ownprev[, .(k, nk, own_prev_pcv)], by = c("k", "nk"), all.x = TRUE)
  D[is.na(own_prev_pcv), own_prev_pcv := 0]
  D[, base := pmax(0, own_prev_pcv + mv)]
  D[, gated := own_prev_pcv < GATE]
  D[, new_person := is.na(prev_winner) | ns(name) != ns(prev_winner)]
  D[, emergence := elected == TRUE & !party %in% MAJ & gated & new_person]

  # MATCHED BY PERSON (search_form(), the same key fetch_salience_v6.R built
  # the corpus with), not by (seat, party) alone -- that fanned out and
  # multiplied rows whenever a seat had two candidates of the same class,
  # which is how sa2026 first came back with 9 "emergences" instead of the
  # correct 6. Re-run and caught by the row-count check below.
  D[, kw := search_form(given, surname, name)]
  sal <- S[election == cur, .(seat, keyword, xp)]
  sal[, k := ns(seat)]
  D <- merge(D, sal[, .(k, keyword, xp)], by.x = c("k", "kw"), by.y = c("k", "keyword"),
            all.x = TRUE)

  D[, election := cur]; D[, region := rg]
  out <- D[!party %in% MAJ, .(election, region, seat, name, party, pcv, elected,
                              own_prev_pcv, base, gated, xp, emergence)]
  # Every merge above is a LEFT join on D, so row count must never grow. A
  # grown count means a join key was not unique on the right-hand side -- the
  # exact bug class already found twice while building this (own_prev_pcv,
  # then salience) -- and a silently-fanned-out population is worse than an
  # error, because it looks like a bigger, better-powered test.
  n_nonmajor <- C[election == cur & !party %in% MAJ, .N]
  if (nrow(out) != n_nonmajor) {
    stop("BW! ", cur, ": built ", nrow(out), " rows from ", n_nonmajor,
         " source non-major candidacies -- a join fanned out. Fix before trusting this run.")
  }
  out
}

POP <- rbindlist(lapply(PAIRS, build_one), fill = TRUE)

cat(sprintf("BW1  %d non-major rows across %d election-pairs\n", nrow(POP), length(PAIRS)))
cat(sprintf("BW1  gated: %d | salience coverage on gated rows: %d (%.1f%%)\n",
            sum(POP$gated), sum(POP$gated & !is.na(POP$xp)),
            100 * mean(!is.na(POP[gated == TRUE]$xp))))
cat(sprintf("BW1  emergences: %d across %d election clusters\n",
            sum(POP$emergence), uniqueN(POP[emergence == TRUE]$election)))
print(POP[, .(rows = .N, gated = sum(gated), emergences = sum(emergence)), by = election][order(election)])

miss_xp <- POP[gated == TRUE & emergence == TRUE & is.na(xp)]
if (nrow(miss_xp)) {
  cat(sprintf("BW! %d emergence(s) have no salience coverage -- excluded from the test, named here:\n",
              nrow(miss_xp)))
  print(miss_xp[, .(election, seat, name, party)])
}

fwrite(POP, "output/c3-widened-population.csv")
cat("\nBW9  wrote output/c3-widened-population.csv\n")
