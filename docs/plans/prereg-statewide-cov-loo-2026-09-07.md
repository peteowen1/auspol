# Pre-registration: the statewide covariance, leave-one-election-out and widened

Written and committed **before** any arm was run, 2026-09-07.

## What is wrong now

`scripts/estimate_statewide_cov.R` builds ONE correlation matrix of statewide
first-preference changes and writes it to `output/statewide-cov.rds`. Every
harness reads that one matrix, and `fit_seats_full.R` publishes with it. Two
separate defects:

**C1 — it is fitted in sample.** The matrix is estimated from ten election
pairs and then used to score those same pairs. Scoring nsw2023 uses a
correlation matrix that saw nsw2023's own statewide swing. `fit_mp_slope.R`
already solves exactly this shape by fitting leave-one-election-out and writing
one row per target; this file never got the same treatment.

**C2 — it uses ten of twenty-two available pairs.** The list is hardcoded: six
federal, two Victorian, one New South Wales, one South Australian. Absent are
both Queensland pairs, all seven Western Australian pairs, nsw2019, vic2014, and
the seventh federal pair (fed2004 → fed2007). The first-preference files for
every one of them are on disk.

## The two changes are judged differently, and that is deliberate

**C1 ships regardless of the metric.** Removing leakage should be expected to
make backtest numbers WORSE, because the leaked numbers were optimistically
biased. A correctness fix that is refused for making a contaminated benchmark
look worse is not a decision, it is the leak defending itself. So C1 has no
metric bar. What it has is a *reporting* obligation: state the size of the move
and say plainly that the previous figures were flattered by it.

**C2 is judged on the metric**, because using more data is a choice and more
data is not automatically better here — the added pairs are mostly Western
Australian, which is one jurisdiction with an unusual party system, and pooling
them could make the matrix describe WA rather than Australia.

## Criterion for C2

Primary: **pooled seat log loss across all 22 pairs**, at `eps = 1e-6`, the
floor every harness uses. This is a general change — it alters the correlation
of statewide draws for every party in every seat — so under this repo's own
rule the election-wide metric is primary and slices are the guard.

Secondary, as do-no-harm guards:
- pooled seat-share RMSE,
- per-jurisdiction log loss, all six,
- the ONP column, which refusal V3 of the original plan already records as
  resting on South Australia 2026 and little else.

**Decision rule.** C2 is adopted if pooled log loss does not worsen by more than
0.002 AND no jurisdiction worsens by more than 0.01. It is adopted on a tie,
because using the data we have is the better default when the evidence is
indifferent.

### Sizing the criterion before running it

Pooled log loss over 2,050 seat-elections clustered on 22 pairs. Per-pair log
loss ranges 0.079 to 0.873, so the between-pair spread is large, but the
comparison is PAIRED — the same seats, same seed, one input changed — so the
relevant spread is of the per-pair *difference*, not of the level. A correlation
matrix shrunk at lambda 0.5 moves the statewide draw's shape, not its scale, so
the expected effect is small: of order 0.001-0.005. The 0.002 bar is therefore
set where a real effect could plausibly sit, and is a bar on HARM rather than on
benefit, which is the right shape for a change whose justification is
completeness rather than performance.

## Refusal section — what would disqualify a winner

Named in advance, per the rule that a criterion which cannot say what a bad win
looks like is not ready:

1. **If the widened matrix is dominated by Western Australia.** Seven of the
   twelve added pairs are WA. If the correlation between any two parties changes
   sign when WA is excluded, the matrix is describing one jurisdiction and C2 is
   refused however the pooled metric moves.
2. **If ONP's column moves materially.** V3 already records it as one election's
   worth of information. Queensland 2017 and 2020 both carry real One Nation
   votes and are a genuine addition; Western Australia's are not. If cor(ONP,
   LNP) moves by more than 0.25 and the move is not attributable to Queensland,
   refuse and investigate.
3. **If a jurisdiction improves only because its own pair left the fit.** Under
   C1 every pair is now scored against a matrix that excludes it, so an
   improvement concentrated in the pairs that were previously in the fit is the
   leak unwinding, not the widening working. Report C1 and C2 separately for
   this reason, never as one number.

## What the criterion cannot see

- Whether the correlation is stable over TIME. All 22 pairs are pooled
  regardless of era, and Australian party structure in 2001 is not that of 2025.
  A per-era matrix is not attempted here and is not ruled out.
- Whether a correlation of statewide *changes* is the right object at all. The
  simulator draws a deviation from a projected level, and this measures how
  realised changes co-moved historically. Those are related, not identical.

## Order of work

1. Commit this file.
2. Implement C1 alone, measure, report.
3. Implement C2 on top, measure against the C1 baseline, apply the rule above.
