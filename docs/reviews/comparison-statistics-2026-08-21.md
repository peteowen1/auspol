# We were comparing a simulated median against a winner-count. They are not the same number.

Written 2026-08-21. **No model change.** This corrects how every external
comparison in this repo has been stated, including
[external-comparison-2026-08-19.md](external-comparison-2026-08-19.md).

## The error

YouGov's MRP reports **one winner per seat**. Counting them gives Labor 29,
Coalition 39, One Nation 17, Greens 3.

Our model reports a **distribution over seat totals**, and we have been quoting
its **median**.

Those are different statistics, and for a party that is competitive-but-behind
in many seats they differ enormously. A party second favourite in twenty-five
seats wins none of them on a winner-count while expecting several across a
simulation.

## The three numbers our model produces

| party | modal-winner count | expected seats | simulated median | YouGov |
|---|---:|---:|---:|---:|
| ALP | **46** | 38.8 | 40 | **29** |
| LNP | **35** | 38.5 | 37 | **39** |
| ONP | **2** | 5.3 | 5 | **17** |
| GRN | **4** | 4.2 | 4 | **3** |
| IND | 0 | 0.2 | 0 | — |

**Only the first column is comparable with YouGov.** The other two have no
published counterpart, because YouGov does not publish per-seat probabilities —
their file carries `seat, winner, runner_up, tpp, status` and nothing else.

## Why the columns disagree, which is the useful part

- **One Nation is second favourite in 25 of 87 seats.** Those contribute to the
  expected count and the median and nothing to a winner-count. Hence 2 against
  5.3.
- **Labor's modal count OVERSHOOTS its expected count**, 46 against 38.8,
  because a winner-count hands over the whole seat wherever a party is
  marginally ahead, and Labor is marginally ahead in many.

A winner-count is a biased estimator of a seat total in both directions at once:
it over-credits the narrowly-ahead and gives nothing to the narrowly-behind.
That is a criticism of the statistic, not of YouGov — but it is a reason to
compare like with like rather than to argue about which is better.

## The correction, and it goes against us

| | as previously stated | like-for-like |
|---|---|---|
| One Nation | ours 5 vs YouGov 17 | **ours 2 vs 17** |
| Labor | ours 40 vs YouGov 29 | **ours 46 vs 29** |

**The median flattered us on both parties where we disagree.** It made One
Nation look three times closer and cut the Labor gap from 17 seats to 11.
Nothing was chosen to produce that; it is what using the wrong statistic
happened to do, in the direction that made our forecast look better.

The disagreement is therefore **larger** than this repo has been reporting, not
smaller.

## What stays true

- **The Coalition agreement is real** and survives the correction: 35 against 39
  on a like-for-like basis, and 39 sits at the 43rd percentile of our simulated
  distribution.
- **The Greens agreement is real**: 4 against 3.
- **One Nation remains the irreconcilable disagreement**, and more so. Their 17
  sits outside our 90% band of 1-11, at a simulated probability of **0.3%**.

## The rule this should have followed

State the statistic before the number. Every external comparison here must say
whether it is a winner-count, an expected value, or a quantile of a simulated
distribution, and must compare the same one on both sides. Where the other
forecaster publishes only a point estimate, ours must be reduced to a
point estimate too, and the richer statistics reported separately rather than
placed in the same column.
