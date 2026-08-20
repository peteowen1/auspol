# Seat by seat against YouGov: we agree on 70%, and where we differ we are certain

Run 2026-08-20. `scripts/parse_yougov.py`, `scripts/compare_yougov_seats.R`.
Output `output/yougov-comparison.csv`.

**This compares published OUTPUTS. Neither forecast has been scored against a
result** — the election is 100 days away.

YouGov's table is extracted from their PDF into `external/reference/`, which is
gitignored. Their numbers are not committed here; only this comparison is.

## The extraction is right

Parsed independently, then checked against totals YouGov state in prose:

| | parsed | they state |
|---|---:|---:|
| Coalition | 39 | 39 |
| Labor | 29 | 29 |
| One Nation | 17 | 17 |
| Greens | 3 | 3 |

The Liberal/National split also matches (31/8), and all 88 seat names match ours
exactly. `compare_yougov_seats.R` re-runs this check and refuses to continue if
it fails, so a future parse regression cannot quietly reach a comparison.

## Headline

**Same winner in 62 of 88 seats (70%).** The 26 disagreements:

| we say | they say | seats |
|---|---|---:|
| ALP | ONP | 11 |
| ALP | LNP | 8 |
| LNP | ONP | 5 |
| GRN | ALP | 2 |

Our mean probability for **their** pick is **0.664** overall — but that splits
hard: **0.887** where we agree and **0.131** where we disagree.

**We are not hedging.** Where the two models differ, we mostly say their answer
is unlikely, rather than calling it close.

## The One Nation gap is one-sided

Of the 17 seats YouGov gives One Nation, we give the party the win in **one**
(Melton, 0.572). Our expected seats across all 17 is **1.89**.

And the reverse set is empty: **there is no seat we give One Nation that YouGov
does not.** Our 3 seats are a subset of their 17, not a different theory about
which seats. The disagreement is purely about how far the party's support
converts, not about where it is strongest.

## The part that should worry us

Three of their One Nation wins are seats where **our model gives One Nation a
probability of 0.000**:

| seat | their winner | their 2pp | our winner | our P(their pick) |
|---|---|---:|---|---:|
| Lowan | One Nation | 50.3 | LNP | **0.000** |
| Ovens Valley | One Nation | 50.7 | LNP | **0.000** |
| Bendigo West | One Nation | 51.5 | ALP | **0.000** |

They call these near coin-flips. We call them certainties, in the other
direction. Two more of the same shape sit just above: Thomastown (0.006),
Bass (0.005), Macedon (0.002).

**A probability of 0.000 on an outcome a serious MRP model puts at 50.3% is a
claim we have not earned.** It is exactly the anchor-check failure this
project's own discipline is written to catch: a number that looks fine in
aggregate and is indefensible on one row.

This does not say YouGov is right. It says our **minor-party seat-level
uncertainty is too tight**, which is a different and more tractable problem than
the primary-vote gap. Note the calibration we do have — slope 1.113, Brier
0.0583 — scores the **two-party** model on classic seats. **The candidate-level
model, which produces every number above, has never been backtested.**

## Where we are more confident than them, and right to be

Their closest calls include seats we consider settled, in their direction:
Murray Plains (their 50.9, our LNP 1.000), Euroa (51.0, our LNP 1.000), Lara
(50.9, our ALP 0.999), Brunswick (50.8, our GRN 1.000). So the confidence is not
uniformly ours — on the classic and Green contests we agree with their winner
while being far more certain of it.

## What this changes

Nothing published. Two things follow for the queue:

1. **Backtest the candidate model.** It is the published model, it produces
   every seat number, and its probabilities have never been scored. The
   0.000-versus-50.3% rows are the argument.
2. **Minor-party seat-level spread is the suspect**, not the statewide primary.
   Our statewide One Nation figure (20.2 against their 24) is a real
   disagreement, but the seat gap is 17-versus-3 on a subset we already agree
   is their best ground — that is a conversion problem, not a level problem.
