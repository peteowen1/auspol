# How AE Forecasts and theswingison handle seat-level detail, and where we could beat both

2026-08-16. Pete asked whether both references already solve the "who contests
a seat" problem, and where we could improve. They do, differently, and each
has a weakness the other does not.

I over-called this earlier as "blocked on data". It is not. The data is public;
we have not acquired it.

## AE Forecasts

**Method.** Per-seat judgement, recorded as data:

- `sRunningParties` — which parties contest each seat
- `sMinorViability` — a score for a viable minor, e.g. `IND,1.00`, in 9 of 88
  Victorian seats in 2022
- `seat-types.csv` — a three-level seat classification (0/1/2), his demographic
  proxy
- A Stan **regional swing model** on transformed vote share, expressing each
  region's polling as a deviation from the overall swing

**Critique.**

1. **Viability is authored, not derived.** Someone decides an independent is
   viable in Kew and not in Bendigo. That is domain expertise, and it does not
   update between elections or respond to a new party's rise.
2. **The live file has none of it.** His 2026 Victorian file carries zero
   `sRunningParties` and zero `sMinorViability`, where 2022 has both. The
   method's inputs exist for elections already held.
3. **The regional model needs regional polls.** It works on poll breakdowns by
   region, and `region-polls-fed.csv` is the only such file — federal. Most
   state elections, Victoria included, cannot run it.
4. **Three seat types is a very coarse demography**, and by his own labelling
   only "barely" demographic.

## theswingison

**Method.** Derived from booth-level data:

- **Booth regression plus Australian Election Study data, per seat** — the
  serious answer to seat-level composition, and the thing neither we nor AE
  Forecasts has
- A **12-rule elimination-aware preference hierarchy**, keyed on who has been
  excluded and who remains, with a confidence tier per rule
- Uniform swing for the seat estimates themselves

**Critique.**

1. **The 12 rules are hand-authored.** They encode real knowledge — who
   preferences whom once a candidate is eliminated — but no election can update
   them. Same failure mode as AE's viability scores, one level up.
2. **Uniform swing, despite having the demographics.** It does the hard work of
   booth regression and then applies a statewide swing to every seat. The
   demographic model informs the composition, not the movement.
3. **Its poll aggregation is materially weaker than ours** and this is not a
   close call: a Gaussian kernel average that **deliberately does not remove
   house effects**, plus an outlier rule that penalises a poll for disagreeing
   with local consensus — herding by construction, in a model whose own output
   is then used to judge pollsters.
4. **Confidence tiers, not probabilities.** It is a swing explorer answering
   "what if the vote moved like this", not "what will happen".

## Where we could beat both

The two weaknesses are complementary, and the same fix addresses both:

| | AE Forecasts | theswingison | Ours could be |
|---|---|---|---|
| Who contests | authored per seat | implied by booth data | **derived, and updating** |
| Preference distribution | one national flow per party | 12 authored rules | **fitted from booth results** |
| Seat composition | 3-level type | booth regression + AES | booth regression, validated |
| Poll aggregation | Bayesian latent state | kernel, no house effects | **already the strongest** |

**The unlock is booth-level results**, and they are public: the VEC publishes
first preferences and two-candidate-preferred for every polling booth, and
booths map onto census geography. That gives, without any new modelling
insight:

- **Seat-level first preferences**, which is what our model lacks and what
  makes One Nation's zero seats structural rather than estimated
- **Observed preference flows by seat**, which is what would let a preference
  simulator be *fitted* rather than hand-ruled — the improvement on
  theswingison
- **A viability estimate that derives from vote share**, rather than being
  typed in — the improvement on AE Forecasts

## What is cheap and available today

`seat-types.csv` is already in the anchor's data, covers Victorian seats, and
**we do not read it**. It is coarse — three levels — but it is the difference
between no demographic signal and some.

Sized honestly first, as everything else has been: the measured decomposition
says the statewide vote dominates the seat count (sd 10.87 from the projection
alone against 3.96 from all seat and regional variation). So per-seat
demographics will not sharpen the seat count much. **Its value is
representational** — letting the model produce outcomes it currently cannot,
namely a One Nation or independent seat win — not accuracy on outcomes it
already handles.

That distinction should decide how much effort this gets. It is the difference
between a better number and a number that can be wrong in fewer ways.
