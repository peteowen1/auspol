# C1 refused: one test passes, the other could not be measured at all

2026-08-27. Scores `docs/plans/prereg-salience-separates-new-candidates.md`
(`05a7c7a`), written before nsw2023 and sa2026 salience existed.

**C1 fails as pre-registered.** Its refusal clause reads: *"If it works on
nsw2023 but not sa2026, or the reverse. Two elections; one carrying the result is
indistinguishable from chance."* That is what happened.

## Result

| election | new candidates | winners | AUC (bar 0.80) | median pctile (bar 85) | guard (bar 4) |
|---|--:|--:|---|---|---|
| fed2022 — *fitting, not decisive* | 303 | 9 | 0.979 PASS | 98 PASS | 3.4 PASS |
| **nsw2023** | 162 | 5 | **0.894 PASS** | **96 PASS** | 24.8 FAIL |
| **sa2026** | 93 | 4 | **0.517 FAIL** | 52 FAIL | 20.5 FAIL |

## sa2026 is unmeasurable, not negative — and that is decidable from the input

| election | rows | distinct `jump` values | zero |
|---|--:|--:|--:|
| fed2022 | 364 | 69 | 67% |
| fed2025 | 388 | 74 | 66% |
| nsw2023 | 206 | 34 | 85% |
| **sa2026** | **109** | **6** | **95%** |

**104 of 109 South Australian candidates are exactly zero, including all four
winners.** Six distinct values cannot rank 109 candidates; an AUC computed on
that is tie-breaking noise, and 0.517 is what noise looks like.

This is established from the input distribution **before** looking at the
criterion, which is the test `CLAUDE.md` requires before a measurement may be set
aside: the incapability does not depend on which way the result went.

**Cause.** The four elections share one 2021–2026 Trends window so they would be
directly comparable. But the window's maximum is set by federal campaigns —
fed2022 tops out at 92.22 — and South Australian state candidates against that
scale fall below Google's publishing threshold and floor to zero. The design
that removed the cross-election scale problem created a resolution problem in
its place.

## The nsw2023 guard failure is degenerate, and is also an instrument fault

The guard counts non-winners above the *winners' minimum* jump. Philip Donato
won Orange with a jump of **0.00**, so the minimum is zero and all 124 candidates
at zero tie above it. The guard cannot discriminate when any winner scores zero.

Note also that Donato is one of the NSW Shooters-to-independent seats — a
returning member whose party class changed. He is correctly a new *class*
candidate and is genuinely invisible to a name-search signal, which is a real
limitation rather than a bug.

## What actually holds

**nsw2023 passes the primary and the secondary out of sample**: AUC 0.894 over 5
winners in 162 new candidates, median winner at the 96th percentile. Kiama,
Balmain and Wakehurst rank at the top; Orange does not.

That is one election, and one election is what the refusal clause exists to
reject. It is evidence, not a result.

## The remedy, which the criterion never precluded

**The primary is a WITHIN-election AUC, and a rank statistic needs no
cross-election comparability at all.** The single shared window was built for the
regression form that this criterion replaced. So each election can be fetched in
its own window and its own geography, at full resolution, without touching the
criterion.

That is not a criterion change made after seeing a result — the criterion is
unchanged and still binding. It is a fetch that stops destroying the resolution
the criterion needs.

## Status

- C1 **refused** on the pre-registered clause.
- nsw2023 stands as a passing out-of-sample test.
- sa2026 to be **re-fetched per election** and re-scored against the same
  criterion, unchanged.
- The three-way candidate split that arm C called for remains unbuilt and
  unjustified until a second election passes.
