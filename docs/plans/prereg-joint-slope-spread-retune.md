# Pre-registration: retune deviation slopes and spread together

2026-08-27, written before any arm below has been run.

## Why jointly, and not either alone

`docs/reviews/dev-slopes-refused-2026-08-27.md` refused per-class deviation
slopes on a measured null — Brier better in 3 of 8 election-pairs and worse in
5, calibration better in about two thirds, paired t +0.48 (p 0.64). The
diagnosis was that **`party_sd`, `seat_sd` and `shrink` were all fitted with
uniform swing's bias present and absorbed part of it**, so moving the point
estimate without retuning the spread breaks a compensation doing real work.

A second finding, `8212a6c`, says the slopes themselves were mis-specified. A
single IND slope of 0.618 averages two populations that behave nothing alike:

| class | same person stands again | that person is gone | t |
|---|--:|--:|--:|
| IND | **0.907** (R² 0.79) | 0.326 (R² 0.09) | 12.3 |
| OTH_RIGHT | 0.891 | 0.325 | 15.4 |
| GRN | 0.994 | 0.880 | 4.5 |
| ONP | 0.610 | 0.545 | 0.7 |

So the refused arm was a blend that is wrong for every individual seat. This
tests the conditional form, and it tests it against a spread free to move.

## The three slope arms

| arm | definition |
|---|---|
| **U** | all slopes 1.000 — uniform swing, today's published model |
| **P** | pooled per-class slopes, region-held-out — the arm already refused |
| **C** | conditional: per-class **and** split by whether the same candidate stands |

Arm C needs `stood_before()` over `output/candidate-ids.csv`. Both P and C use
slopes estimated with the scored region **held out**, per `ebbf98f`; no election
contributes to the slope used to predict it.

## Two stages, both fixed here

**Stage 1 — slopes, spread held at today's values** (`party_sd` 1.5,
`shrink` 0.10). Three arms × five harnesses.

Decision rule, in this order:
1. Arm C must beat arm U on **calibration** (mean |slope − 1| across pairs) by
   at least **0.419**, and
2. must not lose to U on **Brier** by more than **0.0089**.
3. If C fails either, stage 2 does not run and the whole thing is refused.

Sized from the 15 pairs measured on 2026-08-27, clustered on **harness** (5
clusters — WA's 7 pairs share one commission, one redistribution regime and one
flow matrix, so they are not 7 independent draws): Brier SE 0.0032 → MDE 0.0089;
calibration SE 0.150 → MDE 0.419.

**Stage 2 — spread, on the winning slope arm only.** Five settings, no more:

| | party_sd | shrink |
|---|--:|--:|
| S0 | 1.5 | 0.10 |
| S1 | 2.0 | 0.10 |
| S2 | 2.5 | 0.10 |
| S3 | 1.5 | 0.00 |
| S4 | 1.5 | 0.20 |

Winner must beat **U at S0** — today's published model — on Brier by at least
0.0089 **and** on calibration by at least 0.419. Beating the stage-1 winner is
not the bar; the incumbent is what ships.

## Dry-run: verdicts fixed before running

Required by `CLAUDE.md` after C2 of the salience pre-registration scored win/lose
for a vote-share model and had to be thrown away.

| case | expected | why it tests the criterion |
|---|---|---|
| Arm U at S0 | **byte-identical** to the current published output | if not, the harness changed and no comparison below means anything |
| Zali Steggall, Warringah 2022 (same person, prior 43.5, actual 44.8) | arm C projects near 44, closer than arm P | the same-candidate slope must protect a sitting independent |
| Zoe Daniel, Goldstein 2025 (same person, prior 34.5, actual 30.7) | arm C within ~4 points | persistence must not become blind optimism |
| Dai Le, Fowler 2022 (prior 0.0, actual 29.5) | **all three arms fail her** | no slope reaches 29.5 from 0.0; if an arm "fixes" her, it is leaking |

If the scoring code disagrees with any row, the code is wrong, not the case.

## Refusal — what disqualifies a winner

- **If arm C wins only through `seat_sd`/`party_sd`.** Then it is a spread
  retune wearing a slope's name. Report arm U at the winning spread setting
  alongside; if that alone captures the gain, ship *that* and say so.
- **If Brier improves while calibration worsens**, or vice versa. The refused
  arm did exactly this, and a single headline number would have hidden it. Both
  criteria must move the right way.
- **If any party's Victoria 2026 median seat count moves by more than 3.** Stop
  and report rather than ship. Not a veto — the Queensland-flows change cleared
  a similar gate on Pete's judgement — but the decision goes to a person.
- **If the gain reverses on any single harness by more than the MDE.** A change
  that helps four elections and badly hurts one is a finding, not a win.
- **If arm C beats P but neither beats U.** Then conditioning improved a bad
  idea and the honest report is that uniform swing survives.

## What the criteria cannot see

- **Five clusters.** Every tolerance here rests on them.
- **The conditional slopes rest on 17 pairs, but only 149 IND seat-observations
  where the same person stood.** The 0.907 is the least-supported number in the
  design.
- **Western Australia has no given names**, so `stood_before()` there matches on
  surname within a seat. Two different candidates sharing a surname in one WA
  seat across elections would read as persistence. WA is 7 of 17 pairs.
- **Nothing here touches emergence.** Dai Le stays broken under every arm; that
  is salience's job and it is separately unresolved.
- **`vic2022` has no winners file**, so the live target's most recent election
  contributes nothing.
