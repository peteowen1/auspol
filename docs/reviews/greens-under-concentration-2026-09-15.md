# RETRACTED: the Greens "under-concentration" was a selection artefact

**2026-09-15, same day. The finding below is WRONG. It is kept in full rather
than deleted, because the way it fooled me is the reusable part.**

## What the retraction rests on

The claim was: the mean GRN primary error in the ten seats where the Greens
polled highest, minus the error elsewhere, is positive in 22 of 23 elections
(mean +2.95). True as arithmetic, worthless as evidence.

**Those ten seats were selected by their ACTUAL result.** A seat lands in that
group partly because it got a positive error, so the group's mean error is
positive by construction -- regression to the mean, selected on the outcome.
It is the identical trap I had caught earlier the same day in the worst-seat
tables (`aef7-worst-seats-2026-09-15.md`) and then walked straight into here.

| selection | mean gap | elections positive |
|---|--:|--:|
| top 10 by **actual** share (what was done) | +2.95 | 22 of 23 |
| top 10 by **predicted** share (sound) | **+0.41** | **13 of 23** |
| **placebo: errors shuffled within election, no signal whatever** | **+2.28** | **23 of 23** |

The placebo reproduces four fifths of the effect out of pure noise. Selected on
a quantity known before the outcome, the Greens gap is +0.41 in 13 of 23.

## The evidence that should have stopped it earlier

The spread calibration was already available and said the opposite. Slope of
(actual - mean) on (predicted - mean) across seats, per election:

| class | mean slope | median | elections above 1 |
|---|--:|--:|--:|
| ALP | 1.026 | 1.008 | 12/23 |
| **GRN** | **1.011** | **0.998** | **11/23** |
| LNP | 0.982 | 0.982 | 10/23 |
| IND | 0.958 | 0.927 | 9/23 |

A real under-concentration would put the Greens slope well above 1. It is
1.011 -- perfectly calibrated spread, indistinguishable from the majors. I ran
this only because I paused to check whether the effect was Greens-specific
before writing the pre-registration. Without that pause a plan would have been
committed on an artefact.

## What survives

- **The eight group-D seats are real and expensive.** Ryan, Brisbane,
  Griffith, Melbourne, Richmond, South Brisbane and the rest carry 9.5% of the
  AEF-7's seat log loss. That is a sum over named seats with no selection
  inference in it.
- **The Greens' cost is real**: 18 wins given a mean win probability of 0.572,
  5.1% of pooled log loss from 1.6% of seats, 8 of 18 winners under a coin
  flip. Prahran 2014 at 0.013 is a genuine bad call.
- **What does NOT survive is the explanation.** "The model systematically
  under-concentrates the Greens" is unsupported, and so is everything resting
  on it: the lag story about fed2025, the One Nation analogy, and the proposed
  correction. Group D still needs a diagnosis.

## The rule this earns

**Never select a subgroup by the outcome and then report that subgroup's mean
error.** The selector must be something known before the result -- the
prediction, the prior vote, a demographic -- or the finding is guaranteed
before any data is seen. Where selection on the outcome is unavoidable, run the
shuffled placebo first: here it took one minute and returned +2.28 of the
+2.95.

---

# The original claim, left unedited below

# The Greens are under-concentrated in 22 of 23 elections

2026-09-15. Found while working group D of the AEF-7 triage
(`aef7-worst-seats-2026-09-15.md`), which was labelled "Greens inner-city
cluster" and assumed to be a seat-correlation story. It is not. It is a
concentration failure, and it is the most systematic error in the corpus.

## The measurement

For each election, the mean GRN primary error in the ten seats where the
Greens actually polled highest, minus the mean error everywhere else. Positive
means we put too little of their vote in their own best seats.

| pair | gap | pair | gap |
|---|--:|---|--:|
| qld2020 | +5.73 | fed2016 | +2.86 |
| fed2013 | +5.54 | vic2022 | +3.00 |
| vic2014 | +5.33 | wa2017 | +2.77 |
| wa2008 | +5.07 | fed2007 | +2.69 |
| fed2022 | +4.60 | wa2025 | +2.35 |
| nsw2023 | +4.44 | wa2001 | +1.73 |
| fed2010 | +4.39 | vic2018 | +1.23 |
| sa2022 | +4.20 | fed2019 | +1.14 |
| wa2005 | +4.18 | nsw2019 | +0.82 |
| wa2013 | +3.76 | qld2024 | +0.63 |
| wa2021 | +3.69 | sa2026 | +0.61 |
| | | **fed2025** | **-2.90** |

**Positive in 22 of 23, mean +2.95.** Under a sign test that is p about
2 x 10^-6. This is not a tendency; it is a property of the model.

## The statewide level is fine -- only the distribution is wrong

Mean GRN primary, actual against predicted, per election: the errors run
-0.39 to +0.90 with a mean of +0.13. We know how many Greens votes there will
be. We do not know where they are.

That makes this the same shape as the One Nation problem in South Australia --
a party that polls near its statewide number while concentrating it in a few
seats -- except ONP's version showed up in one election and this one shows up
in twenty-two.

## It is UPSTREAM, in base_pred

| | mean gap | elections positive |
|---|--:|--:|
| `xgb_pred` (what ships) | +2.95 | 22 of 23 |
| `base_pred` (before the override) | +2.68 | 21 of 23 |

The XGBoost override makes it slightly worse but does not cause it. The failure
is in the fundamental seat projection, which is where any fix has to go -- a
post-hoc patch on the override would be treating the smaller half.

## What it costs

Across the AEF-7 the Greens won 18 seats and were given a mean win probability
of **0.572**. They account for **5.1% of pooled seat log loss from 1.6% of the
seats** -- 3.2x their weight. Eight of the eighteen winners were given under a
coin flip:

| seat | our probability | log-loss cost |
|---|--:|--:|
| Prahran (vic2014) | **0.013** | 4.35 |
| Ryan (fed2022) | 0.058 | 2.85 |
| Brisbane (fed2022) | 0.150 | 1.90 |
| Griffith (fed2022) | 0.275 | 1.29 |
| Melbourne (fed2025) | 0.286 | 1.25 |
| Richmond (vic2022) | 0.304 | 1.19 |
| Brunswick | 0.353 | 1.04 |

## fed2025 is the exception, and it is the interesting one

fed2025 is the only election where the gap is NEGATIVE (-2.90): we put too
MUCH in the Greens' best seats. It is also the election where they went
backwards in exactly those seats, losing Brisbane, Griffith and Ryan. Our
predictions there were 35.4, 40.1 and 46.9 against actuals of 25.9, 31.7 and
39.5.

So the model is not simply biased low on Greens concentration. It **lags**: it
under-concentrates while they are climbing and over-concentrates once they
have peaked. A fix that only adds concentration would have made fed2025 worse,
and any correction has to be fitted leave-one-election-out so it cannot assume
the direction of travel.

## What exists already, and does not cover this

`AUSPOL_ONP_CONC_SD` ships a One Nation seat-concentration mechanism
(`estimate_onp_concentration.R`, a curve `SD = a * statewide^k`). It is wired
into `backtest_candidate_sa.R` **alone** and applies to ONP **alone**. There is
no Greens equivalent anywhere, and `R/concentration_order.R` has no GRN path.

## What this does NOT establish

- **That the ONP mechanism generalises.** It was fitted for a party with a
  different geography and validated on one election.
- **Whether the fix belongs in `base_pred` or as a seat-level reallocation.**
  The measurement locates the failure upstream; it does not choose the remedy.
- **Anything about Victoria 2026 yet.** The Greens hold four Victorian lower
  house seats and are competitive in several more, so this is directly relevant
  to the live target -- unlike the state-swing work, which was federal-only --
  but no Victorian number has been computed here.
- **That correlation plays no part.** Ryan, Brisbane and Griffith did move
  together. The point is that under-concentration explains the level of the
  miss and correlation would only explain its clustering.
