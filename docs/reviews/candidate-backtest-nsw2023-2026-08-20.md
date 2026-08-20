# The published seat model, scored for the first time: calibrated everywhere except new independents

Run 2026-08-20 against
[../plans/prereg-candidate-model-backtest.md](../plans/prereg-candidate-model-backtest.md)
(redesigned section), committed before this ran. `scripts/backtest_candidate_nsw.R`,
output `output/backtest-nsw2023.csv`.

**The candidate-level model produces every seat number on the page and had never
been scored against a result.** This is the first time.

## The setup, and why nothing leaks

NSW 2019 to 2023: a different state from the live forecast, and a change of
government rather than a landslide hold.

| | source | knowable before 25 Mar 2023? |
|---|---|---|
| margins, incumbency, predictors | `load_seats(2023, "nsw")` | yes |
| seat primaries to swing from | `nswec-2019-nsw-firstprefs.csv` | yes |
| transfer matrix | **`nsw2019` transfers only**, asserted in code | yes |
| truth | the NSWEC's own **ELECTED** rows | n/a |

Truth deliberately does **not** come from running the actual votes through our
own `distribute_preferences()`. That would put the same flow matrix on both
sides, so any systematic flaw in it would cancel and the model would score
better than it deserves — the leakage shape this repo keeps finding, where the
check shares its error with the thing being checked. The commission's
declaration is independent of anything this package computes, and it reproduces
the published results exactly (2019: Coalition 48, Labor 36, Greens 3, SFF 3,
Ind 3; 2023: Labor 45, Coalition 36, Ind 9, Greens 3).

**88 of 93 seats scored.** The five omitted — Badgerys Creek, Kellyville,
Leppington, Wahroonga, Winston Hills — are the 2021 redistribution's new or
renamed districts, which have no 2019 first preferences to swing from.

## The headline

| | all 88 seats | **excluding the 9 an independent won** |
|---|---:|---:|
| winner accuracy | 80.7% (71/88) | **86.1%** |
| Brier, on the party that won | 0.1468 | **0.0934** |
| **calibration slope** | **0.541** | **0.962** |

A slope of 1 is calibrated; below 1 is overconfident. **On its own terms the
model looks materially overconfident — and essentially all of that comes from
one thing.** Strip out the seats independents won and the slope is 0.962, as
close to calibrated as the two-party model's 1.113.

The reliability curve shows where it breaks:

| our probability | n | predicted | observed |
|---|---:|---:|---:|
| 0.60–0.70 | 6 | 0.632 | 0.500 |
| 0.70–0.80 | 6 | 0.742 | 0.500 |
| **0.80–0.90** | 7 | 0.845 | **0.143** |
| 0.90–0.95 | 8 | 0.920 | 0.750 |
| 0.95–1.00 | 60 | 0.996 | 0.967 |

The top bin — 60 of 88 seats — is nearly exact. The 0.80–0.90 bin is a disaster
on seven seats.

## It is new independents, precisely

Independents won **9** of the 88, and the model gave them a mean probability of
**0.362**, which splits sharply:

| seat | we said | our p | actual | p we gave the winner |
|---|---|---:|---|---:|
| Kiama | LNP | 0.864 | IND | **0.000** |
| Wakehurst | LNP | 1.000 | IND | **0.000** |
| Murray | OTH_RIGHT | 0.842 | IND | **0.000** |
| Orange | OTH_RIGHT | 0.978 | IND | **0.000** |
| Barwon | ALP | 0.635 | IND | 0.002 |

Four of the nine independent wins the model called correctly. **Those are seats
an independent already held in 2019**, so there was a first-preference base to
swing from. The five it missed are *gains* — a new independent, starting from
whatever the previous one polled, which is near zero.

That is not a tuning problem. It is the projection's structure: every party's
seat share is its own 2019 share plus the statewide swing, so a candidate with
no 2019 vote cannot acquire one. The defect was already recorded here as
"independents cannot win"; **this is the first time it has been costed.** It is
worth 5.4 points of winner accuracy, 0.053 of Brier, and the entire difference
between a calibrated model and an overconfident one.

## What it means for Victoria 2026

Our Victorian forecast gives independents **0.00 expected seats**. NSW 2023
elected nine, five of them gains. YouGov's Victorian MRP has an independent
winning South-West Coast and running second in Benambra, Hawthorn, Kew and
Mornington.

Any seat where a serious independent is running who did not run in 2022 is one
this model **cannot** call — and it will express that as high confidence in
somebody else rather than as uncertainty.

## The seat-swing port is BLOCKED, on a criterion I mis-specified

The point of this exercise was to test whether `seat_swing_adjustment()` — worth
0.0371 MAE to the two-party model — improves the candidate model. It could not
be tested.

Refusal C6 required the coefficients, refitted excluding the scored election, to
stay within half their value. Refitted on Victoria 2022 alone:

| term | shipped (both) | Victoria only | relative change |
|---|---:|---:|---:|
| `fed_c` | 0.7077 | 0.6961 | 0.02 |
| `ret_i` | −1.3955 | −1.2205 | 0.13 |
| `soc_i` | **2.5587** | **1.1730** | **0.54** |
| `sop_i` | 1.6090 | 1.3413 | 0.17 |

No signs flip and three of four are stable. `soc_i` moves 0.54 and trips the bar.

**The bar is wrong, and it is my fourth criterion to fail the same way.**
`soc_i` had t = 3.0 in the full fit, so its standard error is about 0.85 and a
shift of 1.39 is **about 1.6 SE** — comfortably inside noise. I wrote "write
tolerances in standard errors" into `CLAUDE.md` yesterday, after two criteria
failed exactly like this, and then wrote C6 in relative units.

Recorded as blocked rather than overridden. Re-running under a properly-sized
rule is a decision to take deliberately, not one to slip into after seeing which
way it goes.

## What this does and does not establish

- **It does establish** that the published model's probabilities mean what they
  say on major-party and Greens contests — slope 0.962 over 79 seats — which was
  entirely unknown this morning.
- **It does not vindicate the Victorian numbers.** One election, one state, and
  NSW's One Nation polled 1.8%, so the allocation driving our biggest Victorian
  disagreement is untested here.
- **It does not test the One Nation allocation at all.** NSW One Nation has a
  real 2019 base and is swung like any other party; the Victoria-specific
  Greens-ordering and SA quantile map never run.
