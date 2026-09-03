# jump_pctile: significant a fourth time, and stronger, now that majors are in scope

2026-09-04. Reruns `scripts/analyse_incumbent_transfer.R` (unchanged since
`f5a0851`) against `output/salience-v6.csv` as it stands today -- 22 elections,
majors included -- rather than the 20-election, non-majors-only file the
script last ran against. Closes both items `NEXT-STEPS.md` left open from
2026-08-28: `jump_pctile`'s three-time significance flip, and the
`switched_party` sign-flip in the n=311 both-years subsample.

**This is not a mechanical repeat of the same measurement.** The majors fetch
that finished on 2026-08-28 changed the population `jump_pctile` ranks
against -- every candidate's percentile is `rank(jump)/.N` within their own
election's salience batch, and that batch now includes ALP/LNP/NAT where it
previously did not. So this run is new evidence on materially improved data,
not a repeat that happens to agree.

## Coverage roughly doubled

| | before (2026-08-28) | now |
|---|--:|--:|
| LEVEL model n | 311 | **486** |
| DELTA (both-years) model n | not reported this large | **366** |

## jump_pctile, both models

| model | coefficient | t | p |
|---|--:|--:|--:|
| LEVEL (own_prev_pcv + tpp_swing + party_swing + switched_party + jump_pctile) | 4.637 | 4.32 | **1.93e-05** |
| DELTA (+ jump_delta) | 7.999 | 4.97 | **1.02e-06** |

Previously reported (2026-08-28, n=311): t = 3.53, p = 0.005. The effect is
now an order of magnitude more significant, both because n rose and because
the ranking population itself changed -- a candidate's percentile among
"everyone Trends was fetched for" is a different, more complete quantity now
that majors set the top of the scale (Albanese's jump of 18.03 in fed2025
dwarfs anything a minor party candidate scored, so minor-party percentiles
compress downward and the ones that remain high are more informative).

**`jump_pctile` is significant a fourth time, on the largest and most complete
sample yet, in the expected direction (more salience -> larger vote-share
gain).**

## The n=311 switched_party discrepancy is resolved, not just re-measured

2026-08-28 flagged: `switched_party` strongly negative (-6.5 to -7.2, p<2e-16)
in the full n=599/587 samples but **not significant and sign-flipped** in the
n=311 both-years-salience subsample (p=0.244) -- and left it "not yet
investigated whether that's sample composition or noise."

The same subsample, now at n=366 (nearly double, from the majors fetch): the
coefficient is **-10.693, t=-9.18, p<2e-16** -- correctly signed, highly
significant, and *larger in magnitude* than the full-sample estimate (-6.547).

**Verdict: sample composition, not a real reversal.** n=311 was underpowered
for a subgroup effect this large relative to its own noise -- the pattern this
repo's constants doctrine already names (a criterion's MDE has to be checked
against n before trusting a null). Confirmed independently by the raw
effect-size table on the full minor/IND population:

| switched_party | n | mean delta | sd |
|---|--:|--:|--:|
| FALSE | 534 | +0.29 | 4.27 |
| TRUE | 65 | **-8.68** | 17.97 |

A minor-party or independent incumbent who changes party affiliation loses
about 9 points on average, with wide variance -- consistent with the
regression coefficient in every specification.

## One new thing, weakly significant, not chased further tonight

`jump_delta` (this election's salience percentile minus last election's) is
**negative** in the DELTA model: -3.010, t=-2.16, p=0.032. At face value that
says an incumbent whose relative salience *rose* since last time tends to gain
*less* -- the opposite of the naive expectation. Borderline significance (p
just under 0.05) and a mechanism not yet examined (regression to the mean in
percentile terms is a live candidate explanation, since a candidate already
near the top has less room to rise). Flagged for whoever picks this thread up
next; not pursued further here because tonight's queue has two more items.

## What this does and does not license

This is diagnostic regression work on the candidate transfer population, not
a pre-registered change to the published model -- no criterion was set in
advance because none was being tested; the question was "does a prior finding
replicate," which it did. It does not touch `simulate_seat_contests()` or any
shipped constant. The natural next step, if this is worth acting on, is its
own pre-registration: whether/how to wire person-level salience into the
candidate-level seat model, which `docs/plans/plan-wire-salience-into-forecast.md`
already exists to scope.
