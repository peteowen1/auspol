# The first Victorian 2026 forecast with the candidate data in

Overnight 2026-09-14/15, from Pete's instruction: get the Wikipedia candidate
list in and see what a properly-correct draft looks like against AE Forecasts.

## The headline

Expected seats, sum of per-seat win probabilities. AEF's NAT folded into LNP to
match our single Coalition class.

| party | AEF | ours | diff |
|---|--:|--:|--:|
| LNP | 41.63 | 32.86 | **−8.77** |
| ALP | 28.12 | 34.09 | **+5.97** |
| ONP | 9.00 | 14.51 | **+5.52** |
| GRN | 4.60 | 5.32 | +0.72 |
| IND | 4.38 | **0.22** | **−4.16** |

**19 of 87 seats called differently.** We are more bullish on Labor and One
Nation, less on the Coalition, and we give independents almost nothing.

Seats where One Nation is favourite: **AEF 0, ours 7.**

## What the candidate list changed

379 candidacies across all 88 districts, 67 sitting members, 62 matched to
prior Victorian winners. It unblocked three things that had been falling back:

| | before | after |
|---|--:|--:|
| `DS2` seat-classes with a returning candidate | 0 of 356 | **87** |
| `DS2o` taking the candidate's own previous share | 0 | **22** |
| `DS3` surge-v2 hazard | flat fallback | **30 of 87 seats** |

`DS2` was inert for a reason worth recording: Wikipedia writes "Nina Taylor",
every other Victorian row is "TAYLOR, Nina", and `surname_of()` splits on the
comma and otherwise takes the FIRST token. The same person therefore had
opposite keys in the two elections. Fixing it moved Labor 29.66 → 34.09, so
personal-vote effects had been worth 4.4 seats and were silently absent.

That is the **fourth** distinct name-format trap in one session, after the
blank `surname` column, the sa2018/sa2022 order flip and the Mac/Mc casing.

## What to treat with suspicion

**The independent gap.** 0.22 against AEF's 4.38 is the known teal under-call,
untouched by any of this, and it is the largest proportional disagreement in
the table.

**One Nation at 14.51.** Nearly double AEF. Two things pull in opposite
directions and neither settles it:

- AEF's failure mode on a surging minor party is under-calling. In sa2026 they
  called 1 of the 4 seats One Nation actually won, at 0.405, and gave it a
  plurality nowhere. Here they again make it favourite in zero seats.
- Our own override was measured worse on One Nation than the no-override arm
  in sa2026 — 4 of 4 correct off, 1 of 4 on — on evidence from the only
  election in the corpus where One Nation has won a seat.

**The candidate list is ~52% complete** (379 against vic2022's 731) and
nominations do not close until November. `DS3` reads 57 seats as "absent → 0".
Measured: turning surge-v2 off moves One Nation 17.75 → 17.34, so that
incompleteness is worth **0.41 seats**, not the difference with AEF. Worth
re-checking after nominations close.

## What shipped against a worse backtest, deliberately

`AUSPOL_HISTORIC_ELECTED_BACKFILL` is now 1. The isolated A/B says it costs
0.0141 pooled primary RMSE and is worse in 5 of 6 jurisdictions.

The backtest cannot see the other side of that trade: vic2026 is the target
and never a training pair, so the 62 returning members can only move the live
forecast. Holding real information out of the election being forecast to
protect a 0.014 number on elections already decided is the wrong way round.
The number is recorded beside the flag so the decision stays visible.

## Still open

- The teal/independent under-call — the biggest single gap against AEF.
- sa2026 One Nation: every arm still calls 0 or 1 of the 4 actual seats.
- Nominations close in November; refetch the list and re-measure `DS3` then.
