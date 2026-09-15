# The AEF-7 election by election, and what the worst seats have in common

2026-09-15, at Pete's request: *"how does each election do on seat logloss --
whats the worst 10 seats in each election - can you see a pattern for any of
them?"*

All seven now measurable per-seat, which they were not this morning -- `nsw`,
`vic` and `wa` gained the per-seat probability table in `98cee76`.

## Seat log loss by election

Lower is better. `worst10 share` is how much of that election's total log loss
comes from its own ten worst seats.

| pair | seats | seat log loss | accuracy | worst10 share |
|---|--:|--:|--:|--:|
| sa2026 | 47 | **0.3577** | 87.2% | **84.2%** |
| qld2024 | 93 | 0.3106 | 87.1% | 62.9% |
| nsw2023 | 88 | 0.2694 | 87.5% | 69.9% |
| fed2022 | 151 | 0.2629 | 88.7% | 48.1% |
| fed2025 | 150 | 0.2600 | 88.7% | 45.4% |
| vic2022 | 78 | 0.2494 | 88.5% | 64.2% |
| wa2025 | 53 | 0.2027 | 86.8% | 81.5% |

**Accuracy is nearly identical everywhere (86.8-88.7%) while log loss ranges
0.20 to 0.36.** The difference between our best and worst election is not how
many seats we call right; it is how badly we are wrong on the ones we miss.

And the concentration is extreme. In sa2026 **ten seats carry 84% of the
election's entire log loss**, in wa2025 81%. Fixing the average seat would
achieve almost nothing in either.

## What does NOT hold up

Two patterns looked obvious in the worst-seat tables and did not survive a
check. Both are recorded because the check is the point.

**1. "We under-predict the winner's primary in the bad seats" is SELECTION.**
Worst-10 primary error runs +1.89 to +9.93, which looks damning until you
compare it with the same statistic over all seats:

| pair | worst10 winner err | ALL-seat winner err |
|---|--:|--:|
| fed2022 | +9.93 | +0.55 |
| fed2025 | +6.16 | -0.39 |
| nsw2023 | +9.02 | **+3.96** |
| qld2024 | +1.89 | +0.10 |
| sa2026 | +4.64 | **+1.88** |
| vic2022 | +4.61 | +0.47 |
| wa2025 | +2.28 | +0.15 |

The worst seats are BY CONSTRUCTION the ones where the winner beat our
prediction, so a positive error there is guaranteed. Five of the seven
elections have an all-seat error under 0.6 and the apparent pattern vanishes.

**2. "The worst seats line up behind one party" is mostly the base rate.**
ALP being 8 of fed2025's worst 10 means little when ALP won 63% of the chamber.
Against each modal party's own share of all seats:

| pair | modal party | worst 10 | base rate | binomial p |
|---|---|--:|--:|--:|
| sa2026 | ONP | 4/10 | 9% | **0.007** |
| nsw2023 | ALP | 7/10 | 50% | 0.172 |
| fed2025 | ALP | 8/10 | 63% | 0.214 |
| qld2024 | LNP | 7/10 | 56% | 0.286 |
| vic2022 | ALP | 6/10 | 62% | 0.671 |
| fed2022 | ALP | 4/10 | 51% | 0.844 |
| wa2025 | ALP | 6/10 | 77% | 0.946 |

Six of seven are indistinguishable from chance.

## What DOES hold up

**1. sa2026 is a One Nation problem and nothing else.** ONP took 4 of the ten
worst seats against a 9% base rate, p = 0.007 -- the only significant
concentration in the corpus. Narungga, Hammond and MacKillop are all ONP wins
we gave 0.138, 0.161 and 0.163, and in each we favoured IND or LNP. The primary
errors are +8.0, +4.0 and +11.5. This is the same failure already traced in
`prereg-education-residual-correction`: a concentration miss, not a level miss.

**2. nsw2023 carries a genuine systematic bias, not selection.** Its all-seat
winner error is **+3.96**, six times the next-largest, and it splits by class:
ALP **+1.91**, LNP **-1.09** over 88 seats. We shaded Labor down and the
Coalition up across the whole election. Wakehurst is the extreme -- an
independent won on 35.9% where we predicted 13.7%, a **22.2-point** miss.

**3. The failure mode differs by election, and it is visible in who we
favoured.** In nsw2023, 8 of the 10 worst seats were LNP-favoured at 0.65-0.93
and lost. In qld2024, 6 of 10 were ALP-favoured and lost to LNP. In fed2022 the
misses are teal and Greens seats -- Ryan, Brisbane, Griffith, North Sydney,
Fowler -- where a non-major won and we had the Coalition or Labor at 0.61-0.86.
These are three different problems wearing the same log-loss number.

## The one thing every bad seat shares

Not a party and not a direction: **a confident call that was wrong.** Across
the 70 worst seats the median probability we gave the actual winner is under
0.25 while the favourite sat at 0.6-0.99. Accuracy is unchanged election to
election; what varies is how much probability we put on the wrong side.

That is consistent with the seat-correlation point Pete made and parked -- if
seat errors within an election were independent, confident misses would be
rarer than they are -- but this analysis does not establish it, and it should
not be quoted as though it did. The evidence for that sits in
`seat-correlation-gap-2026-09-15.md`.

## Not established

- **Why nsw2023 shades Labor down.** The bias is measured, not explained.
- **Whether sa2026's ONP concentration generalises.** One election.
- **Anything causal from the worst-seat tables.** Selection dominates them, as
  the two failed patterns above show.


---

## Addendum, same day: group D's LABEL is unexplained

Group D was called "Greens inner-city cluster" and I proposed an
under-concentration diagnosis for it. **That diagnosis was retracted** --
`greens-under-concentration-2026-09-15.md` -- because it rested on selecting
the top seats by their ACTUAL result, which guarantees a positive mean error.
A shuffled placebo reproduced +2.28 of the +2.95, and the Greens' spread
calibration is 1.011, indistinguishable from the majors.

The eight seats and their 9.5% of pooled log loss are unaffected: that is a sum
over named seats. What has no support is any account of WHY they are missed.
Group D is an observation awaiting a diagnosis, not a diagnosed group.
