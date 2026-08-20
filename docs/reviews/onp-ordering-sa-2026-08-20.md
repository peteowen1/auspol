# The One Nation ordering rule replicates on South Australia. The shape still cannot be tested anywhere.

Run 2026-08-20. **No model change** — this is a replication of an existing
measurement on a second election.

## The allocation has two halves and only one is testable

`fit_seats_full.R` spreads One Nation's statewide vote across seats in two
separable steps:

- **ORDERING** — rank districts by their transposed federal One Nation vote.
- **SHAPE** — `sa_ratio`, the sorted district-to-mean ratios, applied by rank.

**The shape is fitted on South Australia 2026 itself** (line 195:
`sa_ratio <- sort(sa_fp$pct / mean(sa_fp$pct))`). So no South Australian test
can validate it — using SA's own shape to predict SA reproduces the answer by
construction. That was the test proposed before this one, and it cannot be run
here or anywhere: **Victoria 2026 is the shape's first out-of-sample exposure.**

The ordering uses only federal booth data, so it can be tested without
circularity. Every arm below gets the same shape, so the shape cancels and the
comparison is between orderings alone.

## The result

47 districts, actual One Nation share 9.1% to 37.5%, mean 22.98%.

| ordering | Spearman | allocation MAE |
|---|---:|---:|
| **federal — the live rule** | **+0.939** | **1.874** |
| Greens share — retired 2026-08-20 | +0.779 | 3.942 |
| uniform allocation | — | 6.424 |

Against the NSW 2023 figures the rule was adopted on — federal +0.814 / 1.594,
Greens +0.331 / 3.287, uniform 2.595 — **the ordering replicates and improves**,
cutting allocation error by 71% against uniform.

That matters more here than on NSW. NSW 2023 had One Nation on a low base; South
Australia 2026 is the only completed election where it contested at the level
Victoria is forecasting, and it is where an ordering rule could most easily have
fallen apart.

## It finds the seats that decide the seat count

One Nation won four of 47. Ranked by the rule, out of 47:

| seat | actual ONP | transposed federal | rank by rule | actual rank |
|---|---:|---:|---:|---:|
| Narungga | 37.5% | 8.7% | **6** | 1 |
| MacKillop | 35.3% | 7.2% | **15** | 2 |
| Ngadjuri | 34.9% | 10.6% | **1** | 3 |
| Hammond | 27.4% | 7.8% | **10** | 15 |

All four in the top third. The rule does not rank them perfectly — MacKillop at
15 against an actual 2 is the worst — but it puts every one of them where the
allocation will hand them a share well above the statewide mean, which is the
only thing that lets them be won in simulation.

## What this says about yesterday's South Australian backtest

`scripts/backtest_candidate_sa.R` gave One Nation **0.000** probability in all
four seats and 0.0 expected seats against an actual 4. **That was the harness,
not the model.** Every backtest in this repo allocates a statewide movement
uniformly; the production model does not, and on this evidence its ordering
would have placed those four seats near the top of the One Nation distribution
rather than at its mean.

The backtest figure therefore bounds the model *without* its allocation and
should not be quoted as the published model's performance — which is what the
script's header already says, and this is the measurement behind that claim.

## One thing that changed direction

On NSW 2023 the retired Greens-share proxy was **worse than uniform** (3.287
against 2.595), which is the finding that retired it. On South Australia it is
clearly **better** than uniform (3.942 against 6.424) while still far worse than
the federal rule.

So the proxy is not worthless everywhere; it was worthless on the election it
was measured on. That does not reopen the decision — the federal rule beats it
on both elections, by 0.16 and 2.07 points of MAE — but "worse than uniform" was
a property of one election and is quoted as if it were general.

## What is still not known

- **The shape.** One election, no possible validation, and it carries the
  difference between One Nation winning four seats and forty.
- **Whether the ordering transfers to Victoria.** It is validated on NSW 2023
  and SA 2026, neither of which is Victoria, and Victorian federal One Nation
  polled 5.3% against a state forecast near 21% — so the ordering is being read
  off a much smaller signal than either test had.
